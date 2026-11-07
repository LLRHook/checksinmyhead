//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testidentity"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"errors"
	"fmt"
	"testing"

	"gorm.io/gorm"
)

func TestPostgresIdentity0003BindingCompetingWriters(t *testing.T) {
	for _, op := range []string{"source_paid", "tab_paid", "claim", "rename", "finalize", "leave"} {
		for _, bindingFirst := range []bool{false, true} {
			for _, rollback := range []bool{false, true} {
				t.Run(fmt.Sprintf("%s/binding_first=%t/rollback=%t", op, bindingFirst, rollback), func(t *testing.T) {
					db := authorizationPostgres(t)
					dst, b, access := seedReferenceLifecycle(t, db)
					creator := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "creator", Role: "creator"}
					target := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "target", Role: "member"}
					saveAuthFixture(t, db, &creator)
					saveAuthFixture(t, db, &target)
					access.MemberToken = creator.MemberToken
					p := testidentity.Participant(t, db, b.ID, "Alex")
					zero, one := int64(0), int64(1)
					change := func(conn *gorm.DB, c billpkg.ParticipantChange, token string) error {
						_, err := (&tabRepository{db: conn}).ChangeParticipant(context.Background(), ParticipantCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: token}, BillID: b.ID, Change: c})
						return err
					}
					if err := change(db, billpkg.ParticipantChange{Operation: "request", ParticipantID: p.ID, ExpectedRevision: &zero}, target.MemberToken); err != nil {
						t.Fatal(err)
					}
					bind := func(conn *gorm.DB) error {
						return change(conn, billpkg.ParticipantChange{Operation: "decision", ParticipantID: p.ID, ExpectedRevision: &one, RequestRevision: &one, MemberID: &target.ID, Decision: "approve"}, creator.MemberToken)
					}
					claim := referenceTabCommand(t, db, AssignmentCommand{Access: access, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}, {PersonName: "Sam", Percentage: 50}}}}, ExpectedRevision: &one})
					other := func(conn *gorm.DB) error {
						repo := &tabRepository{db: conn}
						switch op {
						case "source_paid":
							return billpkg.NewBillRepository(conn).UpdatePersonSharePaid(context.Background(), billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: true})
						case "tab_paid":
							return repo.UpdateBillPersonSharePaid(context.Background(), SharePaidCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: target.MemberToken}, BillID: b.ID, ShareID: b.PersonShares[0].ID, Paid: true})
						case "claim":
							return repo.UpdateBillItemAssignmentsBatch(context.Background(), claim)
						case "rename":
							label := "Renamed"
							return change(conn, billpkg.ParticipantChange{Operation: "rename", ParticipantID: p.ID, ExpectedRevision: &one, Name: &label}, creator.MemberToken)
						case "finalize":
							_, err := repo.FinalizeOnce(context.Background(), FinalizeCommand{Access: access})
							return err
						case "leave":
							return repo.Leave(context.Background(), LeaveCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: target.MemberToken}})
						}
						panic("unreachable operation")
					}
					owner := db.Begin()
					t.Cleanup(func() { owner.Rollback() })
					// Keep the root lock even when the first operation is refused.
					if err := owner.Exec("SELECT id FROM tabs WHERE id = ? FOR UPDATE", dst.ID).Error; err != nil {
						t.Fatal(err)
					}
					first, second := other, bind
					if bindingFirst {
						first, second = bind, other
					}
					firstErr := first(owner)
					if !bindingFirst && op == "tab_paid" {
						if !errors.Is(firstErr, mutation.Forbidden) {
							t.Fatalf("pending paid authority: %v", firstErr)
						}
					} else if !bindingFirst && op == "leave" {
						if !errors.Is(firstErr, mutation.Referenced) {
							t.Fatalf("pending leave guard: %v", firstErr)
						}
					} else if firstErr != nil {
						t.Fatal(firstErr)
					}
					ch := make(chan error, 1)
					go func() { ch <- second(db) }()
					waitForPostgresLocks(t, db, 1)
					before := lifecycleSnapshot(t, owner)
					if rollback {
						if err := owner.Rollback().Error; err != nil {
							t.Fatal(err)
						}
					} else if err := owner.Commit().Error; err != nil {
						t.Fatal(err)
					}
					err := receiveAuthResult(t, ch)
					var want error
					if bindingFirst {
						if op == "leave" {
							want = mutation.Referenced
						}
						if rollback && op == "tab_paid" {
							want = mutation.Forbidden
						}
						if !rollback && (op == "claim" || op == "rename") {
							want = billpkg.ErrRevision
						}
					} else if !rollback {
						if op == "claim" || op == "rename" || op == "source_paid" {
							want = billpkg.ErrRevision
						}
						if op == "finalize" {
							want = mutation.Finalized
						}
					}
					if want != nil {
						if !errors.Is(err, want) {
							t.Fatalf("waiting operation got %v want %v", err, want)
						}
						if !rollback && lifecycleSnapshot(t, db) != before {
							t.Fatal("refused waiter changed committed state")
						}
					} else if err != nil {
						t.Fatal(err)
					}
					var current models.BillParticipant
					if err := db.Where("id = ? AND bill_id = ?", p.ID, b.ID).Take(&current).Error; err != nil {
						t.Fatal(err)
					}
					bound := bindingFirst && !rollback || !bindingFirst && (rollback || op == "tab_paid" || op == "leave")
					if (current.MemberID != nil) != bound || bound && *current.MemberID != target.ID {
						t.Fatal("binding lost or invented after lock/rollback")
					}
					rows := mustFinalize(t, db, access)
					total := 0.0
					for _, row := range rows {
						total += row.Amount
						if row.SnapshotVersion != 2 {
							t.Fatal("nonreference snapshot")
						}
					}
					if total != 10 {
						t.Fatal("race changed gross allocated cents")
					}
				})
			}
		}
	}
}

func TestPostgresIdentity0003AttachmentCountRollback(t *testing.T) {
	for _, table := range []string{"bills", "bill_participants"} {
		t.Run(table, func(t *testing.T) {
			db := authorizationPostgres(t)
			dst, _, source := seedPostgresAttachment(t, db)
			testidentity.Ready(t, db, &source, "Alex")
			before := lifecycleSnapshot(t, db)
			if err := db.Exec(`CREATE FUNCTION suppress_location() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$`).Error; err != nil {
				t.Fatal(err)
			}
			if err := db.Exec("CREATE TRIGGER suppress_location BEFORE UPDATE ON " + table + " FOR EACH ROW EXECUTE FUNCTION suppress_location()").Error; err != nil {
				t.Fatal(err)
			}
			command := AttachBillCommand{TabID: dst.ID, TabToken: dst.AccessToken, BillID: source.ID, BillToken: source.AccessToken}
			if err := NewTabRepository(db).AttachBill(context.Background(), command); err == nil {
				t.Fatal("suppressed parent/participant location was acknowledged")
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("suppressed location left a partially attached graph")
			}
			if err := db.Exec("DROP TRIGGER suppress_location ON " + table).Error; err != nil {
				t.Fatal(err)
			}
			if err := NewTabRepository(db).AttachBill(context.Background(), command); err != nil {
				t.Fatal(err)
			}
			var b models.Bill
			var p models.BillParticipant
			if err := db.Session(&gorm.Session{SkipHooks: true}).First(&b, source.ID).Error; err != nil {
				t.Fatal(err)
			}
			if err := db.Where("bill_id = ?", source.ID).Take(&p).Error; err != nil {
				t.Fatal(err)
			}
			if b.TabID == nil || *b.TabID != dst.ID || p.TabID == nil || *p.TabID != dst.ID || b.IdentityRevision != 1 || p.MemberID != nil {
				t.Fatal("healthy attachment omitted scope or invented binding")
			}
		})
	}
}
