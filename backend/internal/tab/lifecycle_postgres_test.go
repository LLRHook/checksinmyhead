//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testidentity"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"math"
	"os"
	"reflect"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestPostgresLifecyclePaidEconomicsAndRetry(t *testing.T) {
	db := authorizationPostgres(t)
	dst := models.Tab{Name: "Trip", AccessToken: "tab"}
	saveAuthFixture(t, db, &dst)
	b := models.Bill{TabID: &dst.ID, AccessToken: "bill", Name: "Two items", Subtotal: 10, Tax: 1, Total: 11,
		Items:        []models.BillItem{{Name: "First", Price: 5, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}, {Name: "Second", Price: 5}},
		PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 5, TaxShare: 1, Total: 6, Paid: true, Items: []models.ItemDetail{{Name: "First", Amount: 5}}}}}
	saveAuthFixture(t, db, &b)
	testidentity.Ready(t, db, &b, "Sam")
	r := authorizationRouter(db)
	h := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/tabs/:id/finalize", h.FinalizeTab)
	r.PATCH("/api/tabs/:id/bills/:billId/items/:itemId", h.UpdateBillItemAssignments)
	before := authSnapshot(t, db)
	edit := referenceAuthRequest(t, db, r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/items/%d", dst.ID, b.ID, b.Items[1].ID), `{"assignments":[{"person_name":"Sam","percentage":100}]}`, "tab", "")
	if edit.Code != 409 {
		t.Errorf("paid 6 -> 5.50 edit must be 409, got %d", edit.Code)
	}
	if authSnapshot(t, db) != before {
		t.Error("paid economics rejection must roll back children and timestamps")
	}
	first := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", "tab", "")
	retry := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", "tab", "")
	if first.Code != 200 || retry.Code != 200 {
		t.Errorf("finalize/retry status %d/%d; want 200/200", first.Code, retry.Code)
	}
	if first.Body.String() != retry.Body.String() {
		t.Error("retry must return the stored snapshot")
	}
}

func lifecycleRouter(db *gorm.DB) *gin.Engine {
	r := authorizationRouter(db)
	h := NewTabHandler(NewTabService(NewTabRepository(db)))
	b := billpkg.NewBillHandler(billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{}))
	r.POST("/api/tabs/:id/finalize", h.FinalizeTab)
	r.PATCH("/api/tabs/:id", h.UpdateTab)
	r.POST("/api/tabs/:id/join", h.JoinTab)
	r.DELETE("/api/tabs/:id/members/me", h.LeaveTab)
	r.GET("/api/tabs/:id/settlements", h.GetSettlements)
	r.PATCH("/api/tabs/:id/settlements/:settlementId", h.UpdateSettlement)
	r.PATCH("/api/tabs/:id/bills/:billId/items/:itemId", h.UpdateBillItemAssignments)
	r.PATCH("/api/tabs/:id/bills/:billId/assignments", h.UpdateBillItemAssignmentsBatch)
	r.PATCH("/api/tabs/:id/bills/:billId/shares/:shareId", h.UpdateBillPersonSharePaid)
	r.PATCH("/api/bills/:id/shares/:shareId", b.UpdatePersonSharePaid)
	return r
}
func seedLifecycle(t *testing.T, db *gorm.DB) (models.Tab, models.Bill, TabAccess) {
	t.Helper()
	dst := models.Tab{Name: "Trip", AccessToken: "tab"}
	saveAuthFixture(t, db, &dst)
	b := models.Bill{TabID: &dst.ID, AccessToken: "source", Name: "Receipt", Subtotal: 10, Total: 10,
		Items:        []models.BillItem{{Name: "First", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}},
		PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 10, Total: 10, Items: []models.ItemDetail{{Name: "First", Amount: 10}}}}}
	saveAuthFixture(t, db, &b)
	return dst, b, TabAccess{TabID: dst.ID, TabToken: dst.AccessToken}
}
func lifecycleSnapshot(t *testing.T, db *gorm.DB) string {
	t.Helper()
	tables := []string{"tabs", "tab_members", "bills", "people", "bill_participants", "bill_items", "item_assignments", "person_shares", "tab_settlements"}
	parts := make([]string, 0, len(tables))
	for _, table := range tables {
		parts = append(parts, "'"+table+"',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id),'[]') FROM "+table+" r)")
	}
	var result string
	if err := db.Raw("SELECT jsonb_build_object(" + strings.Join(parts, ",") + ")::text").Scan(&result).Error; err != nil {
		t.Fatal(err)
	}
	return result
}
func mustFinalize(t *testing.T, db *gorm.DB, a TabAccess) []models.TabSettlement {
	t.Helper()
	rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{a})
	if err != nil {
		t.Fatal(err)
	}
	return rows
}
func TestPostgresLifecycleConcurrentFinalizersAndPaidReplay(t *testing.T) {
	db := authorizationPostgres(t)
	dst, b, a := seedReferenceLifecycle(t, db)
	hold := db.Begin()
	t.Cleanup(func() { hold.Rollback() })
	if err := hold.Exec("SELECT id FROM tabs WHERE id = ? FOR UPDATE", dst.ID).Error; err != nil {
		t.Fatal(err)
	}
	type result struct {
		rows []models.TabSettlement
		err  error
	}
	ch := make(chan result, 2)
	for i := 0; i < 2; i++ {
		go func() {
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{a})
			ch <- result{rows, err}
		}()
	}
	waitForPostgresLocks(t, db, 2)
	if err := hold.Commit().Error; err != nil {
		t.Fatal(err)
	}
	first, second := <-ch, <-ch
	if first.err != nil || second.err != nil || !reflect.DeepEqual(first.rows, second.rows) {
		t.Fatalf("concurrent results differ: %+v / %+v", first, second)
	}
	r := lifecycleRouter(db)
	path := fmt.Sprintf("/api/tabs/%d/finalize", dst.ID)
	// Discarding this successful response models the lost-response retry boundary.
	if got := authRequest(r, "POST", path, "", a.TabToken, ""); got.Code != 200 {
		t.Fatal(got.Code)
	}
	if err := NewTabRepository(db).UpdateSettlementPaid(context.Background(), SettlementPaidCommand{Access: a, SettlementID: first.rows[0].ID, Paid: true}); err != nil {
		t.Fatal(err)
	}
	if err := billpkg.NewBillRepository(db).UpdatePersonSharePaid(context.Background(), billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: true}); err != nil {
		t.Fatal(err)
	}
	before := lifecycleSnapshot(t, db)
	rows := mustFinalize(t, db, a)
	if !rows[0].Paid || rows[0].ID != first.rows[0].ID || !rows[0].CreatedAt.Equal(first.rows[0].CreatedAt) {
		t.Fatal("retry replaced paid snapshot")
	}
	if lifecycleSnapshot(t, db) != before {
		t.Fatal("retry wrote accounting or timestamps")
	}
	var count int64
	db.Model(&models.TabSettlement{}).Count(&count)
	if count != 1 {
		t.Fatalf("duplicate results %d", count)
	}
}
func TestPostgresLifecycleFailuresRollBackAndRetry(t *testing.T) {
	for _, stage := range []string{"insert", "second_batch", "update", "deferred_commit"} {
		t.Run(stage, func(t *testing.T) {
			db := authorizationPostgres(t)
			_, _, a := seedReferenceLifecycle(t, db)
			if stage == "second_batch" {
				for billIndex := 0; billIndex < 6; billIndex++ {
					b := models.Bill{TabID: &a.TabID, AccessToken: fmt.Sprint("batch-", billIndex), Name: "Batch", Total: 100, Subtotal: 100}
					for i := 0; i < 100; i++ {
						b.PersonShares = append(b.PersonShares, models.PersonShare{PersonName: fmt.Sprintf("Person %d-%d", billIndex, i), Subtotal: 1, Total: 1})
					}
					saveAuthFixture(t, db, &b)
					testidentity.Ready(t, db, &b)
				}
			}
			before := lifecycleSnapshot(t, db)
			setup, cleanup := "", ""
			switch stage {
			case "insert":
				setup = "ALTER TABLE tab_settlements ADD CONSTRAINT reject_insert CHECK (amount < 0)"
				cleanup = "ALTER TABLE tab_settlements DROP CONSTRAINT reject_insert"
			case "second_batch":
				setup = "ALTER TABLE tab_settlements ADD CONSTRAINT reject_insert CHECK (id < 501)"
				cleanup = "ALTER TABLE tab_settlements DROP CONSTRAINT reject_insert"
			case "update":
				setup = "ALTER TABLE tabs ADD CONSTRAINT reject_finalize CHECK (NOT finalized)"
				cleanup = "ALTER TABLE tabs DROP CONSTRAINT reject_finalize"
			case "deferred_commit":
				if err := db.Exec("CREATE FUNCTION fail_commit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic-private-commit'; END $$").Error; err != nil {
					t.Fatal(err)
				}
				setup = "CREATE CONSTRAINT TRIGGER reject_commit AFTER INSERT ON tab_settlements DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION fail_commit()"
				cleanup = "DROP TRIGGER reject_commit ON tab_settlements"
			}
			if err := db.Exec(setup).Error; err != nil {
				t.Fatal(err)
			}
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{a})
			if err == nil || rows != nil {
				t.Fatalf("%s returned success before commit: %v", stage, err)
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("failure partially committed parent/children/money/flags/times")
			}
			response := authRequest(lifecycleRouter(db), "POST", fmt.Sprintf("/api/tabs/%d/finalize", a.TabID), "", a.TabToken, "")
			if response.Code != 500 {
				t.Fatalf("database failure HTTP status %d", response.Code)
			}
			for _, private := range []string{"synthetic-private-commit", "reject_insert", "reject_finalize", "tab_settlements", "SQLSTATE"} {
				if strings.Contains(response.Body.String(), private) {
					t.Fatal("finalize leaked database details")
				}
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("HTTP failure partially committed")
			}

			if err := db.Exec(cleanup).Error; err != nil {
				t.Fatal(err)
			}
			mustFinalize(t, db, a)
			after := lifecycleSnapshot(t, db)
			mustFinalize(t, db, a)
			if lifecycleSnapshot(t, db) != after {
				t.Fatal("retry rewrote persisted result")
			}
		})
	}
}
func TestPostgresLifecycleLegacyContainmentAndAccountingEvidence(t *testing.T) {
	for _, kind := range []string{"active_orphan", "finalized_missing", "finalized_duplicate", "duplicate_members", "duplicate_shares", "invalid_foreign", "nonfinite", "overflow", "no_bills", "no_allocation", "zero_participant", "foreign_zero", "legacy_usd"} {
		t.Run(kind, func(t *testing.T) {
			db := authorizationPostgres(t)
			dst, b, a := seedLifecycle(t, db)
			var want error = mutation.Review
			switch kind {
			case "duplicate_members", "invalid_foreign", "nonfinite", "overflow", "zero_participant", "foreign_zero", "legacy_usd":
				testidentity.Ready(t, db, &b)
			}
			switch kind {
			case "active_orphan":
				saveAuthFixture(t, db, &models.TabSettlement{TabID: dst.ID, PersonName: "Alex", Amount: 10})
			case "finalized_missing", "finalized_duplicate":
				if kind == "finalized_duplicate" {
					want = nil
				}
				now := time.Now()
				db.Model(&dst).Updates(map[string]any{"finalized": true, "finalized_at": now})
				if kind == "finalized_duplicate" {
					saveAuthFixture(t, db, &[]models.TabSettlement{{TabID: dst.ID, PersonName: "Alex", Amount: 5}, {TabID: dst.ID, PersonName: "alex", Amount: 5}})
				}
			case "duplicate_members":
				saveAuthFixture(t, db, &[]models.TabMember{{TabID: dst.ID, DisplayName: "Alex", MemberToken: "creator", Role: "creator"}, {TabID: dst.ID, DisplayName: "alex", MemberToken: "other"}})
				a.MemberToken = "creator"
				want = nil
			case "duplicate_shares":
				want = billpkg.ErrIdentityReview
				saveAuthFixture(t, db, &models.PersonShare{BillID: b.ID, PersonName: "alex", Total: 0})
			case "invalid_foreign":
				db.Model(&models.Bill{}).Where("id = ?", b.ID).Updates(map[string]any{"currency_code": "EUR", "usd_exchange_rate": 1.25, "usd_total": 12.50})
			case "nonfinite":
				db.Model(&models.PersonShare{}).Where("bill_id = ?", b.ID).Update("total", math.NaN())
			case "overflow":
				db.Model(&models.PersonShare{}).Where("bill_id = ?", b.ID).Update("total", float64(math.MaxInt64))
			case "no_bills":
				db.Delete(&b)
				want = mutation.NoBills
			case "no_allocation":
				db.Where("bill_id = ?", b.ID).Delete(&models.PersonShare{})
				want = mutation.NoAllocation
			case "zero_participant", "foreign_zero":
				db.Model(&models.Bill{}).Where("id = ?", b.ID).Updates(map[string]any{"total": 0, "usd_total": 0})
				db.Model(&models.PersonShare{}).Where("bill_id = ?", b.ID).Updates(map[string]any{"subtotal": 0, "total": 0})
				want = nil
				if kind == "foreign_zero" {
					db.Model(&models.Bill{}).Where("id = ?", b.ID).Updates(map[string]any{"total": .001, "currency_code": "EUR", "usd_exchange_rate": 1.25, "exchange_rate_source": "fixture", "exchange_rate_date": "2026-11-03"})
					db.Model(&models.PersonShare{}).Where("bill_id = ?", b.ID).Update("total", .001)
				}
			case "legacy_usd":
				db.Model(&models.Bill{}).Where("id = ?", b.ID).Updates(map[string]any{"usd_total": 0, "usd_exchange_rate": 0, "exchange_rate_source": ""})
				want = nil
			}
			before := lifecycleSnapshot(t, db)
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{a})
			if kind == "invalid_foreign" || kind == "nonfinite" || kind == "overflow" {
				var failure *mutation.Failure
				if !errors.As(err, &failure) || failure.Code != "accounting_review_required" {
					t.Fatal("bad financial evidence did not reach the checked money guard")
				}
			}
			if !errors.Is(err, want) {
				t.Fatalf("%s: got %v want %v", kind, err, want)
			}
			if want != nil {
				if lifecycleSnapshot(t, db) != before {
					t.Fatal("containment changed legacy state")
				}
				read := referenceAuthRequest(t, db, lifecycleRouter(db), "GET", fmt.Sprintf("/api/tabs/%d/settlements", dst.ID), "", "tab", "")
				if read.Code != 200 {
					t.Fatal("authorized historical read blocked")
				}
			} else {
				expected := 1
				if kind == "finalized_duplicate" {
					expected = 2
				}
				if len(rows) != expected {
					t.Fatal("zero/legacy share omitted")
				}
				if kind == "finalized_duplicate" {
					if lifecycleSnapshot(t, db) != before {
						t.Fatal("legacy duplicate retry rewrote exact rows")
					}
					if err := NewTabRepository(db).UpdateSettlementPaid(context.Background(), SettlementPaidCommand{Access: a, SettlementID: rows[0].ID, Paid: true}); err != nil {
						t.Fatal(err)
					}
					var exact []models.TabSettlement
					db.Where("tab_id = ?", dst.ID).Order("id ASC").Find(&exact)
					for _, row := range exact {
						if row.Paid != (row.ID == rows[0].ID) {
							t.Fatal("legacy paid marker selected by duplicate label")
						}
					}
				}
			}
		})
	}
}

func TestPostgresLifecycleCompetingWritersBothArrivalOrders(t *testing.T) {
	for _, op := range []string{"single", "batch", "attach", "source_paid", "tab_paid", "leave", "settings", "join"} {
		for _, finalizeFirst := range []bool{false, true} {
			for _, rollbackOwner := range []bool{false, true} {
				t.Run(fmt.Sprintf("%s/finalize_first=%t/rollback=%t", op, finalizeFirst, rollbackOwner), func(t *testing.T) {
					db := authorizationPostgres(t)
					dst, b, a := seedReferenceLifecycle(t, db)
					creator := models.TabMember{TabID: dst.ID, DisplayName: "Creator", MemberToken: "creator", Role: "creator"}
					alex := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "alex", Role: "member"}
					saveAuthFixture(t, db, &creator)
					saveAuthFixture(t, db, &alex)
					if op == "tab_paid" {
						bindReferenceFixture(t, db, b, "Alex", alex, creator)
					}
					a.MemberToken = "creator"
					source := models.Bill{Name: "Added", AccessToken: "added", Total: 2, Subtotal: 2, PersonShares: []models.PersonShare{{PersonName: "Sam", Subtotal: 2, Total: 2}}}
					saveAuthFixture(t, db, &source)
					testidentity.Ready(t, db, &source)
					operate := func(conn *gorm.DB) error {
						repo := NewTabRepository(conn)
						switch op {
						case "single", "batch":
							r := lifecycleRouter(conn)
							path := fmt.Sprintf("/api/tabs/%d/bills/%d/items/%d", dst.ID, b.ID, b.Items[0].ID)
							body := `{"assignments":[{"person_name":"Alex","percentage":50},{"person_name":"Sam","percentage":50}]}`
							if op == "batch" {
								path = fmt.Sprintf("/api/tabs/%d/bills/%d/assignments", dst.ID, b.ID)
								body = fmt.Sprintf(`{"updates":[{"item_id":%d,"assignments":[{"person_name":"Alex","percentage":50},{"person_name":"Sam","percentage":50}]}]}`, b.Items[0].ID)
							}
							got := referenceAuthRequest(t, conn, r, "PATCH", path, body, "tab", "creator")
							if got.Code == 400 {
								return ErrTabFinalized
							}
							if got.Code != 200 {
								return fmt.Errorf("assignment status %d: %s", got.Code, got.Body.String())
							}
							return nil
						case "attach":
							return repo.AttachBill(context.Background(), AttachBillCommand{TabID: dst.ID, TabToken: "tab", MemberToken: "creator", BillID: source.ID, BillToken: "added"})
						case "source_paid":
							return billpkg.NewBillRepository(conn).UpdatePersonSharePaid(context.Background(), billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: true})
						case "tab_paid":
							return repo.UpdateBillPersonSharePaid(context.Background(), SharePaidCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: "alex"}, BillID: b.ID, ShareID: b.PersonShares[0].ID, Paid: true})
						case "leave":
							return repo.Leave(context.Background(), LeaveCommand{TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: "alex"}})
						case "settings":
							name := "Updated"
							return repo.Update(context.Background(), SettingsCommand{Access: a, Name: &name})
						case "join":
							_, _, err := repo.Join(context.Background(), JoinCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab"}, DisplayName: "New"})
							return err
						}
						return errors.New("unknown operation")
					}
					owner := db.Begin()
					t.Cleanup(func() { owner.Rollback() })
					if finalizeFirst {
						mustFinalize(t, owner, a)
					} else {
						if err := operate(owner); err != nil {
							t.Fatal(err)
						}
					}
					result := make(chan error, 1)
					go func() {
						if finalizeFirst {
							result <- operate(db)
						} else {
							_, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{a})
							result <- err
						}
					}()
					waitForPostgresLocks(t, db, 1)
					before := lifecycleSnapshot(t, owner)
					if rollbackOwner {
						if err := owner.Rollback().Error; err != nil {
							t.Fatal(err)
						}
					} else {
						if err := owner.Commit().Error; err != nil {
							t.Fatal(err)
						}
					}
					err := receiveAuthResult(t, result)
					rejected := finalizeFirst && !rollbackOwner && (op == "single" || op == "batch" || op == "attach" || op == "settings")
					if rejected {
						if !errors.Is(err, ErrTabFinalized) {
							t.Fatalf("edit after finalize accepted: %v", err)
						}
						if lifecycleSnapshot(t, db) != before {
							t.Fatal("rejected writer changed state")
						}
					} else if err != nil {
						t.Fatal(err)
					}
					rows := mustFinalize(t, db, a)
					total := 0.0
					for _, s := range rows {
						total += s.Amount
					}
					want := 10.0
					if op == "attach" && finalizeFirst == rollbackOwner {
						want = 12
					}
					if total != want {
						t.Fatalf("gross snapshot total %v want %v", total, want)
					}
					if (op == "single" || op == "batch") && finalizeFirst == rollbackOwner && len(rows) != 2 {
						t.Fatal("edit-first allocation omitted")
					}
				})
			}
		}
	}
}

func TestPostgresLifecycleAuthorityChangesWhileWaiting(t *testing.T) {
	for _, op := range []string{"finalize", "assignment", "paid", "settings", "settlement", "leave", "join"} {
		t.Run(op, func(t *testing.T) {
			db := authorizationPostgres(t)
			dst, b, a := seedReferenceLifecycle(t, db)
			m := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "member", Role: "creator"}
			saveAuthFixture(t, db, &m)
			a.MemberToken = "member"
			if op == "settlement" {
				mustFinalize(t, db, a)
			}
			hold := db.Begin()
			t.Cleanup(func() { hold.Rollback() })
			if err := hold.Exec("SELECT id FROM tabs WHERE id = ? FOR UPDATE", dst.ID).Error; err != nil {
				t.Fatal(err)
			}
			// Revocation is committed while the parsed capability waits for the root lock.
			if err := hold.Delete(&m).Error; err != nil {
				t.Fatal(err)
			}
			ch := make(chan error, 1)
			go func() {
				repo := NewTabRepository(db)
				switch op {
				case "finalize":
					_, err := repo.FinalizeOnce(context.Background(), FinalizeCommand{a})
					ch <- err
				case "assignment":
					ch <- repo.UpdateBillItemAssignmentsBatch(context.Background(), referenceTabCommand(t, db, AssignmentCommand{Access: a, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{}}}}))
				case "paid":
					ch <- repo.UpdateBillPersonSharePaid(context.Background(), SharePaidCommand{Access: a, BillID: b.ID, ShareID: b.PersonShares[0].ID, Paid: true})
				case "settings":
					name := "Change"
					ch <- repo.Update(context.Background(), SettingsCommand{Access: a, Name: &name})
				case "settlement":
					ch <- repo.UpdateSettlementPaid(context.Background(), SettlementPaidCommand{Access: a, SettlementID: 1, Paid: true})
				case "leave":
					ch <- repo.Leave(context.Background(), LeaveCommand{a})
				case "join":
					_, _, err := repo.Join(context.Background(), JoinCommand{Access: a, DisplayName: "Replacement"})
					ch <- err
				}
			}()
			waitForPostgresLocks(t, db, 1)
			before := lifecycleSnapshot(t, hold)
			if err := hold.Commit().Error; err != nil {
				t.Fatal(err)
			}
			if err := receiveAuthResult(t, ch); !errors.Is(err, mutation.Forbidden) {
				t.Fatalf("stale authority used: %v", err)
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("revoked caller wrote state")
			}
		})
	}
}

func TestPostgresLifecycleSourcePaidDiscoveryAndStaleShareRaces(t *testing.T) {
	for _, race := range []string{"attach", "recreate"} {
		t.Run(race, func(t *testing.T) {
			db := authorizationPostgres(t)
			dst, b, a := seedReferenceLifecycle(t, db)
			if race == "attach" {
				// Synthetic initial standalone premise: move the unbound scoped
				// fixture rows before its parent, respecting the immediate RESTRICT FK.
				if err := db.Model(&models.BillParticipant{}).Where("bill_id = ?", b.ID).UpdateColumn("tab_id", nil).Error; err != nil {
					t.Fatal(err)
				}
				if err := db.Model(&models.Bill{}).Where("id = ?", b.ID).Update("tab_id", nil).Error; err != nil {
					t.Fatal(err)
				}
			}
			type discoveryKey struct{}
			reached, resume := make(chan struct{}), make(chan struct{})
			var once atomic.Bool
			if err := db.Callback().Query().After("gorm:query").Register("test:discovery", func(tx *gorm.DB) {
				if tx.Statement.Context.Value(discoveryKey{}) == true && tx.Statement.Table == "bills" && once.CompareAndSwap(false, true) {
					close(reached)
					<-resume
				}
			}); err != nil {
				t.Fatal(err)
			}
			var released sync.Once
			t.Cleanup(func() { released.Do(func() { close(resume) }) })
			result := make(chan error, 1)
			go func() {
				ctx := context.WithValue(context.Background(), discoveryKey{}, true)
				result <- billpkg.NewBillRepository(db).UpdatePersonSharePaid(ctx, billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: true})
			}()
			select {
			case <-reached:
			case <-time.After(10 * time.Second):
				t.Fatal("no discovery barrier")
			}
			if race == "attach" {
				if err := NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: dst.ID, TabToken: "tab", BillID: b.ID, BillToken: "source"}); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := NewTabRepository(db).UpdateBillItemAssignmentsBatch(context.Background(), referenceTabCommand(t, db, AssignmentCommand{Access: a, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}, {PersonName: "Sam", Percentage: 50}}}}})); err != nil {
					t.Fatal(err)
				}
			}
			before := lifecycleSnapshot(t, db)
			released.Do(func() { close(resume) })
			err := receiveAuthResult(t, result)
			if race == "recreate" {
				if !errors.Is(err, billpkg.ErrPersonShareNotFound) {
					t.Fatalf("stale share selected successor: %v", err)
				}
				if lifecycleSnapshot(t, db) != before {
					t.Fatal("stale paid wrote successor")
				}
			} else {
				if err != nil {
					t.Fatal(err)
				}
				var got models.PersonShare
				if err := db.First(&got, b.PersonShares[0].ID).Error; err != nil || !got.Paid {
					t.Fatalf("paid failed after attach: %v", err)
				}
			}
		})
	}
}

func TestPostgresLifecycleHTTPIsolationMembershipAndSettings(t *testing.T) {
	db := authorizationPostgres(t)
	dst, b, a := seedReferenceLifecycle(t, db)
	r := lifecycleRouter(db)
	other := models.Tab{Name: "Other", AccessToken: "other"}
	saveAuthFixture(t, db, &other)
	cross := models.Bill{TabID: &other.ID, AccessToken: "cross", Name: "Cross", Total: 1, Subtotal: 1, Items: []models.BillItem{{Name: "Cross", Price: 1}}}
	saveAuthFixture(t, db, &cross)
	for _, tc := range []struct {
		name, method, path, body, token, member string
		want                                    int
	}{
		{"wrong finalize", "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", "wrong", "", 403},
		{"supplied invalid legacy finalize", "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", "tab", "bad", 403},
		{"supplied invalid legacy assignment", "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/items/%d", dst.ID, b.ID, b.Items[0].ID), `{"assignments":[]}`, "tab", "bad", 403},
		{"mixed scope batch", "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/assignments", dst.ID, b.ID), fmt.Sprintf(`{"updates":[{"item_id":%d,"assignments":[]},{"item_id":%d,"assignments":[]}]}`, b.Items[0].ID, cross.Items[0].ID), "tab", "", 404},
		{"source token cannot claim attached", "PATCH", fmt.Sprintf("/api/bills/%d/items/%d/assignments", b.ID, b.Items[0].ID), `{"assignments":[]}`, "source", "", 400},
		{"tab token cannot pay source", "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", b.ID, b.PersonShares[0].ID), `{"paid":true}`, "tab", "", 403},
		{"invalid join cannot mint replacement", "POST", fmt.Sprintf("/api/tabs/%d/join", dst.ID), `{"display_name":"Replacement"}`, "tab", "invalid", 403},
		{"cross bill in source paid", "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", cross.ID, b.PersonShares[0].ID), `{"paid":true}`, "cross", "", 404},
		{"active settlement mutation", "PATCH", fmt.Sprintf("/api/tabs/%d/settlements/100", dst.ID), `{"paid":true}`, "tab", "", 409},
		{"malformed settings", "PATCH", fmt.Sprintf("/api/tabs/%d", dst.ID), `{"name":`, "tab", "", 400},
		{"oversized settings", "PATCH", fmt.Sprintf("/api/tabs/%d", dst.ID), `{"name":"` + strings.Repeat("x", (4<<20)+1) + `"}`, "tab", "", 400},
	} {
		t.Run(tc.name, func(t *testing.T) {
			before := lifecycleSnapshot(t, db)
			got := referenceAuthRequest(t, db, r, tc.method, tc.path, tc.body, tc.token, tc.member)
			if got.Code != tc.want {
				t.Fatalf("got %d want %d: %s", got.Code, tc.want, got.Body.String())
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("denied mutation changed state")
			}
		})
	}
	creator := models.TabMember{TabID: dst.ID, DisplayName: "Creator", MemberToken: "creator", Role: "creator"}
	member := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "alex", Role: "member"}
	saveAuthFixture(t, db, &creator)
	saveAuthFixture(t, db, &member)
	a.MemberToken = "creator"
	for _, column := range []string{"added_by_member_id", "paid_by_member_id"} {
		t.Run(column, func(t *testing.T) {
			if err := db.Model(&models.Bill{}).Where("id = ?", b.ID).Update(column, member.ID).Error; err != nil {
				t.Fatal(err)
			}
			before := lifecycleSnapshot(t, db)
			got := authRequest(r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", dst.ID), "", "tab", "alex")
			if got.Code != 409 || lifecycleSnapshot(t, db) != before {
				t.Fatal("referenced member removed")
			}
			if err := db.Model(&models.Bill{}).Where("id = ?", b.ID).Update(column, nil).Error; err != nil {
				t.Fatal(err)
			}
		})
	}
	if got := authRequest(r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", dst.ID), "", "tab", "creator"); got.Code != 400 {
		t.Fatal("creator left")
	}
	beforeBill := models.Bill{}
	db.Session(&gorm.Session{SkipHooks: true}).First(&beforeBill, b.ID)
	got := referenceAuthRequest(t, db, r, "PATCH", fmt.Sprintf("/api/tabs/%d", dst.ID), `{"name":"Changed","description":"Note","display_currency":"EUR","finalized":true}`, "tab", "creator")
	if got.Code != 200 {
		t.Fatal(got.Body.String())
	}
	var afterBill models.Bill
	db.Session(&gorm.Session{SkipHooks: true}).First(&afterBill, b.ID)
	if !reflect.DeepEqual(beforeBill, afterBill) {
		t.Fatal("settings rewrote frozen receipt")
	}
	bindReferenceFixture(t, db, b, "Alex", member, creator)
	rows := mustFinalize(t, db, a)
	paymentBefore := lifecycleSnapshot(t, db)
	for _, route := range []struct {
		path, token, member string
		paid                bool
	}{
		{fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d", dst.ID, b.ID, b.PersonShares[0].ID), "tab", "alex", true},
		{fmt.Sprintf("/api/bills/%d/shares/%d", b.ID, b.PersonShares[0].ID), "source", "", false},
	} {
		response := referenceAuthRequest(t, db, r, "PATCH", route.path, fmt.Sprintf(`{"paid":%t}`, route.paid), route.token, route.member)
		if response.Code != 200 {
			t.Fatalf("post-finalize receipt payment %d: %s", response.Code, response.Body.String())
		}
	}
	if lifecycleSnapshot(t, db) != paymentBefore {
		t.Fatal("paid toggles changed money, IDs, quote provenance or timestamps")
	}
	settlementPath := fmt.Sprintf("/api/tabs/%d/settlements/%d", dst.ID, rows[0].ID)
	if response := referenceAuthRequest(t, db, r, "PATCH", settlementPath, `{"paid":true}`, "tab", "alex"); response.Code != 200 {
		t.Fatal("settlement paid route failed")
	}
	paidBefore := lifecycleSnapshot(t, db)
	if response := referenceAuthRequest(t, db, r, "PATCH", settlementPath, `{"paid":true}`, "tab", "alex"); response.Code != 200 || lifecycleSnapshot(t, db) != paidBefore {
		t.Fatal("idempotent settlement payment wrote state")
	}
	retryRows := mustFinalize(t, db, a)
	if !retryRows[0].Paid || retryRows[0].ID != rows[0].ID || lifecycleSnapshot(t, db) != paidBefore {
		t.Fatal("HTTP payment lost on finalize replay")
	}
	got = authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/join", dst.ID), `{"display_name":"New"}`, "tab", "")
	if got.Code != 201 {
		t.Fatal("finalized join blocked")
	}
	var response struct {
		MemberToken string `json:"member_token"`
		MemberID    uint   `json:"member_id"`
	}
	if err := json.Unmarshal(got.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	before := lifecycleSnapshot(t, db)
	retry := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/join", dst.ID), "", "tab", response.MemberToken)
	if retry.Code != 200 || lifecycleSnapshot(t, db) != before {
		t.Fatal("join retry minted member")
	}
	got = referenceAuthRequest(t, db, r, "PATCH", fmt.Sprintf("/api/tabs/%d/settlements/%d", other.ID, rows[0].ID), `{"paid":true}`, "other", "")
	if got.Code != 409 {
		t.Fatal("active other snapshot not contained")
	}
	// A duplicate member label neither revokes the confirmed owner nor grants authority.
	duplicate := models.TabMember{TabID: dst.ID, DisplayName: "alex", MemberToken: "collision", Role: "member"}
	saveAuthFixture(t, db, &duplicate)
	before = lifecycleSnapshot(t, db)
	got = referenceAuthRequest(t, db, r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d", dst.ID, b.ID, b.PersonShares[0].ID), `{"paid":true}`, "tab", "alex")
	if got.Code != 200 {
		t.Fatal("duplicate label revoked the confirmed owner")
	}
	paidNow := lifecycleSnapshot(t, db)
	denied := authRequest(r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d", dst.ID, b.ID, b.PersonShares[0].ID), `{"paid":true}`, "tab", "collision")
	if denied.Code != 403 || lifecycleSnapshot(t, db) != paidNow {
		t.Fatal("same-label member impersonated the confirmed ID")
	}
	_ = before
}

func TestPostgresLifecycleUnchangedShareIDsAndDeadline(t *testing.T) {
	db := authorizationPostgres(t)
	dst, b, a := seedReferenceLifecycle(t, db)
	if err := db.Model(&models.PersonShare{}).Where("id = ?", b.PersonShares[0].ID).Update("paid", true).Error; err != nil {
		t.Fatal(err)
	}
	cmd := AssignmentCommand{Access: a, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}}
	cmd = referenceTabCommand(t, db, cmd)
	if err := NewTabRepository(db).UpdateBillItemAssignmentsBatch(context.Background(), cmd); err != nil {
		t.Fatal(err)
	}
	var share models.PersonShare
	if err := db.First(&share, b.PersonShares[0].ID).Error; err != nil || !share.Paid {
		t.Fatalf("unchanged economics lost ID/flag: %v", err)
	}
	hold := db.Begin()
	t.Cleanup(func() { hold.Rollback() })
	if err := hold.Exec("SELECT id FROM tabs WHERE id = ? FOR UPDATE", dst.ID).Error; err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	ch := make(chan error, 1)
	go func() { _, err := NewTabRepository(db).FinalizeOnce(ctx, FinalizeCommand{a}); ch <- err }()
	waitForPostgresLocks(t, db, 1)
	before := lifecycleSnapshot(t, db)
	if err := receiveAuthResult(t, ch); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("caller deadline ignored: %v", err)
	}
	if lifecycleSnapshot(t, db) != before {
		t.Fatal("timed out finalizer changed state")
	}
	if err := hold.Rollback().Error; err != nil {
		t.Fatal(err)
	}
	mustFinalize(t, db, a)
}

func TestPostgresLifecycleFreshCreatorFailureIsAtomic(t *testing.T) {
	db := authorizationPostgres(t)
	r := lifecycleRouter(db)
	if err := db.Exec("ALTER TABLE tab_members ADD CONSTRAINT reject_creator CHECK (role <> 'creator')").Error; err != nil {
		t.Fatal(err)
	}
	before := lifecycleSnapshot(t, db)
	got := authRequest(r, "POST", "/api/tabs", `{"name":"Fresh","creator_display_name":"Creator"}`, "", "")
	if got.Code != 500 || lifecycleSnapshot(t, db) != before {
		t.Fatalf("failed creator left orphan tab: %d", got.Code)
	}
}

func TestPostgresLifecycleClaimPriorityAndZeroParticipant(t *testing.T) {
	db := authorizationPostgres(t)
	dst := models.Tab{Name: "Rounding", AccessToken: "tab"}
	saveAuthFixture(t, db, &dst)
	old := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	b := models.Bill{TabID: &dst.ID, AccessToken: "round", Name: "One cent", LazyMode: true, Total: .01, Subtotal: .01,
		Items:        []models.BillItem{{Name: "Cent", Price: .01, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100.0 / 3, CreatedAt: old}}}},
		PersonShares: []models.PersonShare{{PersonName: "Alex", Items: []models.ItemDetail{{Name: "Cent", Amount: .01 / 3, IsShared: true}}}, {PersonName: "Birthday", Paid: true, Items: []models.ItemDetail{}}}}
	saveAuthFixture(t, db, &b)
	testidentity.Ready(t, db, &b, "Sam", "Cara")
	cmd := AssignmentCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab"}, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100.0 / 3}, {PersonName: "Sam", Percentage: 100.0 / 3}, {PersonName: "Cara", Percentage: 100.0 / 3}}}}}
	cmd = referenceTabCommand(t, db, cmd)
	if err := NewTabRepository(db).UpdateBillItemAssignmentsBatch(context.Background(), cmd); err != nil {
		t.Fatal(err)
	}
	var shares []models.PersonShare
	if err := db.Where("bill_id = ?", b.ID).Find(&shares).Error; err != nil {
		t.Fatal(err)
	}
	amounts := map[string]float64{}
	for _, s := range shares {
		amounts[s.PersonName] = s.Total
		if s.PersonName == "Birthday" && (s.ID != b.PersonShares[1].ID || !s.Paid) {
			t.Fatal("explicit paid birthday zero lost")
		}
	}
	if len(shares) != 4 || amounts["Cara"] != .01 || amounts["Alex"] != 0 || amounts["Sam"] != 0 {
		t.Fatalf("claim priority changed: %v", amounts)
	}
	var assignment models.ItemAssignment
	if err := db.Where("bill_item_id = ? AND person_name = ?", b.Items[0].ID, "Alex").First(&assignment).Error; err != nil || !assignment.CreatedAt.Equal(old) {
		t.Fatalf("old claim timestamp lost: %v", err)
	}
	rows := mustFinalize(t, db, cmd.Access)
	if len(rows) != 4 {
		t.Fatal("zero participant omitted from snapshot")
	}
}

func TestPostgresLifecycleActualMobileCreationThenFinalize(t *testing.T) {
	data, err := os.ReadFile("../../../mobile/test/fixtures/bill_creation_contracts.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixtures []struct {
		Case    string          `json:"case"`
		Request json.RawMessage `json:"request"`
	}
	if err := json.Unmarshal(data, &fixtures); err != nil {
		t.Fatal(err)
	}
	if len(fixtures) != 10 {
		t.Fatal("fixture selection changed")
	}
	for _, f := range fixtures {
		t.Run(f.Case, func(t *testing.T) {
			db := authorizationPostgres(t)
			r := lifecycleRouter(db)
			created := authRequest(r, "POST", "/api/bills", string(f.Request), "", "")
			if created.Code != 201 {
				t.Fatal(created.Body.String())
			}
			var response struct {
				BillID uint   `json:"bill_id"`
				Token  string `json:"access_token"`
			}
			if err := json.Unmarshal(created.Body.Bytes(), &response); err != nil {
				t.Fatal(err)
			}
			dst := models.Tab{Name: "Mobile contract", AccessToken: "tab"}
			saveAuthFixture(t, db, &dst)
			attached := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, response.BillID, response.Token), "tab", "")
			if attached.Code != 200 {
				t.Fatal(attached.Body.String())
			}
			var b models.Bill
			if err := db.Session(&gorm.Session{SkipHooks: true}).Preload("PersonShares").First(&b, response.BillID).Error; err != nil {
				t.Fatal(err)
			}
			beforeReceipt := b
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{TabAccess{TabID: dst.ID, TabToken: "tab"}})
			if f.Case == "lazy_empty" {
				if !errors.Is(err, mutation.NoAllocation) {
					t.Fatal(err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			var got float64
			for _, row := range rows {
				got += row.Amount
			}
			want := b.USDTotal
			if f.Case == "lazy_partial" {
				want = 32
			}
			if math.Abs(got-want) > .000001 {
				t.Fatalf("gross conservation %v want %v", got, want)
			}
			var after models.Bill
			if err := db.Session(&gorm.Session{SkipHooks: true}).Preload("PersonShares").First(&after, response.BillID).Error; err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(beforeReceipt, after) {
				t.Fatal("finalize rewrote receipt projection or provenance")
			}
		})
	}
}

func TestPostgresLifecycleSourcePaidFirstAgainstAttachmentAndRecreation(t *testing.T) {
	for _, op := range []string{"attach", "recreate"} {
		t.Run(op, func(t *testing.T) {
			db := authorizationPostgres(t)
			dst, b, a := seedReferenceLifecycle(t, db)
			if op == "attach" {
				// Synthetic initial standalone premise: move the unbound scoped
				// fixture rows before its parent, respecting the immediate RESTRICT FK.
				if err := db.Model(&models.BillParticipant{}).Where("bill_id = ?", b.ID).UpdateColumn("tab_id", nil).Error; err != nil {
					t.Fatal(err)
				}
				if err := db.Model(&models.Bill{}).Where("id = ?", b.ID).Update("tab_id", nil).Error; err != nil {
					t.Fatal(err)
				}
			}
			owner := db.Begin()
			t.Cleanup(func() { owner.Rollback() })
			if err := billpkg.NewBillRepository(owner).UpdatePersonSharePaid(context.Background(), billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: true}); err != nil {
				t.Fatal(err)
			}
			var paid models.PersonShare
			if err := owner.First(&paid, b.PersonShares[0].ID).Error; err != nil {
				t.Fatal(err)
			}
			before := lifecycleSnapshot(t, owner)
			ch := make(chan error, 1)
			go func() {
				if op == "attach" {
					ch <- NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: dst.ID, TabToken: "tab", BillID: b.ID, BillToken: "source"})
				} else {
					ch <- NewTabRepository(db).UpdateBillItemAssignmentsBatch(context.Background(), referenceTabCommand(t, db, AssignmentCommand{Access: a, BillID: b.ID, Updates: []BillItemAssignmentsUpdate{{ItemID: b.Items[0].ID, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}, {PersonName: "Sam", Percentage: 50}}}}}))
				}
			}()
			waitForPostgresLocks(t, db, 1)
			if err := owner.Commit().Error; err != nil {
				t.Fatal(err)
			}
			err := receiveAuthResult(t, ch)
			if op == "attach" {
				if err != nil {
					t.Fatal(err)
				}
				var got models.Bill
				if err := db.Session(&gorm.Session{SkipHooks: true}).First(&got, b.ID).Error; err != nil || got.TabID == nil || *got.TabID != dst.ID {
					t.Fatalf("attachment after paid failed: %v", err)
				}
				if got.Total != b.Total || got.CurrencyCode != b.CurrencyCode || got.USDTotal != b.USDTotal || got.USDExchangeRate != b.USDExchangeRate || got.ExchangeRateSource != b.ExchangeRateSource || got.ExchangeRateDate != b.ExchangeRateDate {
					t.Fatal("attachment changed frozen accounting")
				}
			} else {
				if !errors.Is(err, ErrItemAlreadyPaid) {
					t.Fatalf("paid-first assignment succeeded: %v", err)
				}
				if lifecycleSnapshot(t, db) != before {
					t.Fatal("rejected recreation changed state")
				}
			}
			var got models.PersonShare
			if err := db.First(&got, paid.ID).Error; err != nil || !reflect.DeepEqual(got, paid) {
				t.Fatalf("paid-first ID/economic projection changed: %v", err)
			}
		})
	}
}
