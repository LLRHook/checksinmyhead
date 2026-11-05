//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testpostgres"
	"backend/migrations"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"runtime"
	"sort"
	"sync/atomic"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func authorizationPostgres(t *testing.T) *gorm.DB {
	t.Helper()
	sql := testpostgres.Open(t)
	if _, err := migrations.Run(context.Background(), sql, migrations.Apply); err != nil {
		t.Fatal(err)
	}
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: sql}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	return db
}

func waitForPostgresLocks(t *testing.T, db *gorm.DB, count int64) {
	t.Helper()
	// Observe PostgreSQL's actual lock-wait state, not scheduler timing/sleeps.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for ctx.Err() == nil {
		var waiting int64
		err := db.WithContext(ctx).Raw("SELECT count(*) FROM pg_stat_activity WHERE application_name = current_setting('application_name') AND wait_event_type = 'Lock'").Scan(&waiting).Error
		if err != nil {
			t.Fatal(err)
		}
		if waiting >= count {
			return
		}
		runtime.Gosched()
	}
	t.Fatal("worker did not reach the PostgreSQL lock barrier")
}

func receiveAuthResult(t *testing.T, ch <-chan error) error {
	t.Helper()
	select {
	case err := <-ch:
		return err
	case <-time.After(15 * time.Second):
		t.Fatal("transaction did not finish")
		return nil
	}
}

func seedPostgresAttachment(t *testing.T, db *gorm.DB) (models.Tab, models.Tab, models.Bill) {
	a := models.Tab{Name: "A", AccessToken: "a"}
	saveAuthFixture(t, db, &a)
	b := models.Tab{Name: "B", AccessToken: "b"}
	saveAuthFixture(t, db, &b)
	source := models.Bill{Name: "Source", AccessToken: "source", Subtotal: 10, Total: 10}
	saveAuthFixture(t, db, &source)
	return a, b, source
}

func TestPostgresCompetingDestinationsAndSameTargetRetry(t *testing.T) {
	db := authorizationPostgres(t)
	a, b, source := seedPostgresAttachment(t, db)
	hold := db.Begin()
	t.Cleanup(func() { hold.Rollback() })
	if err := hold.Exec("SELECT id FROM bills WHERE id = ? FOR UPDATE", source.ID).Error; err != nil {
		t.Fatal(err)
	}
	first, second := make(chan error, 1), make(chan error, 1)
	repo := NewTabRepository(db)
	go func() {
		first <- repo.AttachBill(context.Background(), AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source"})
	}()
	go func() {
		second <- repo.AttachBill(context.Background(), AttachBillCommand{TabID: b.ID, TabToken: "b", BillID: source.ID, BillToken: "source"})
	}()
	waitForPostgresLocks(t, db, 2)
	if err := hold.Commit().Error; err != nil {
		t.Fatal(err)
	}
	e1, e2 := receiveAuthResult(t, first), receiveAuthResult(t, second)
	if !((e1 == nil && errors.Is(e2, ErrSourceUnavailable)) || (e2 == nil && errors.Is(e1, ErrSourceUnavailable))) {
		t.Fatalf("results: %v / %v", e1, e2)
	}
	var got models.Bill
	if err := db.First(&got, source.ID).Error; err != nil {
		t.Fatal(err)
	}
	if got.TabID == nil {
		t.Fatal("no winning association")
	}

	// A second member waits behind the first transaction and must not replace its attribution.
	member1 := models.TabMember{TabID: a.ID, DisplayName: "First", MemberToken: "first"}
	saveAuthFixture(t, db, &member1)
	member2 := models.TabMember{TabID: a.ID, DisplayName: "Second", MemberToken: "second"}
	saveAuthFixture(t, db, &member2)
	retrySource := models.Bill{Name: "Retry", AccessToken: "retry-source", Subtotal: 10, Total: 10}
	saveAuthFixture(t, db, &retrySource)
	owner := db.Begin()
	t.Cleanup(func() { owner.Rollback() })
	cmd := AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: retrySource.ID, BillToken: "retry-source", MemberToken: "first"}
	if err := NewTabRepository(owner).AttachBill(context.Background(), cmd); err != nil {
		t.Fatal(err)
	}
	var original models.Bill
	if err := owner.First(&original, retrySource.ID).Error; err != nil {
		t.Fatal(err)
	}
	result := make(chan error, 1)
	cmd.MemberToken = "second"
	go func() { result <- repo.AttachBill(context.Background(), cmd) }()
	waitForPostgresLocks(t, db, 1)
	if err := owner.Commit().Error; err != nil {
		t.Fatal(err)
	}
	if err := receiveAuthResult(t, result); err != nil {
		t.Fatal(err)
	}
	var retried models.Bill
	if err := db.First(&retried, retrySource.ID).Error; err != nil {
		t.Fatal(err)
	}
	if retried.AddedByMemberID == nil || *retried.AddedByMemberID != member1.ID || retried.PaidByMemberID == nil || *retried.PaidByMemberID != member1.ID || !retried.UpdatedAt.Equal(original.UpdatedAt) {
		t.Fatal("concurrent retry rewrote attribution/timestamp")
	}
}

func TestPostgresAttachmentWaitsForCommittedFinalization(t *testing.T) {
	db := authorizationPostgres(t)
	a, _, source := seedPostgresAttachment(t, db)
	tx := db.Begin()
	t.Cleanup(func() { tx.Rollback() })
	if err := tx.Model(&models.Tab{}).Where("id = ?", a.ID).Update("finalized", true).Error; err != nil {
		t.Fatal(err)
	}
	result := make(chan error, 1)
	go func() {
		result <- NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source"})
	}()
	waitForPostgresLocks(t, db, 1)
	if err := tx.Commit().Error; err != nil {
		t.Fatal(err)
	}
	if err := receiveAuthResult(t, result); !errors.Is(err, ErrTabFinalized) {
		t.Fatalf("finalized attachment: %v", err)
	}
	var got models.Bill
	db.First(&got, source.ID)
	if got.TabID != nil {
		t.Fatal("attached after committed finalization")
	}
}

func TestPostgresMembershipWritersUseDestinationLock(t *testing.T) {
	for _, operation := range []string{"create", "delete"} {
		t.Run(operation, func(t *testing.T) {
			db := authorizationPostgres(t)
			a, _, source := seedPostgresAttachment(t, db)
			member := models.TabMember{TabID: a.ID, DisplayName: "Existing", MemberToken: "existing"}
			saveAuthFixture(t, db, &member)
			tx := db.Begin()
			t.Cleanup(func() { tx.Rollback() })
			command := AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source", MemberToken: "existing"}
			if err := NewTabRepository(tx).AttachBill(context.Background(), command); err != nil {
				t.Fatal(err)
			}
			result := make(chan error, 1)
			go func() {
				if operation == "create" {
					_, _, err := NewTabRepository(db).Join(context.Background(), JoinCommand{Access: TabAccess{TabID: a.ID, TabToken: "a"}, DisplayName: "New"})
					result <- err
				} else {
					result <- NewTabRepository(db).Leave(context.Background(), LeaveCommand{Access: TabAccess{TabID: a.ID, TabToken: "a", MemberToken: "existing"}})
				}
			}()
			waitForPostgresLocks(t, db, 1)
			if err := tx.Commit().Error; err != nil {
				t.Fatal(err)
			}
			if err := receiveAuthResult(t, result); (operation == "create" && err != nil) || (operation == "delete" && !errors.Is(err, mutation.Referenced)) {
				t.Fatal(err)
			}
			var got models.Bill
			db.First(&got, source.ID)
			if got.TabID == nil || got.PaidByMemberID == nil || *got.PaidByMemberID != member.ID {
				t.Fatal("membership race corrupted attachment")
			}
		})
	}
}

func TestPostgresMembershipTransitionIsRecheckedByWaitingAttachment(t *testing.T) {
	db := authorizationPostgres(t)
	a, _, source := seedPostgresAttachment(t, db)
	tx := db.Begin()
	t.Cleanup(func() { tx.Rollback() })
	if _, _, err := NewTabRepository(tx).Join(context.Background(), JoinCommand{Access: TabAccess{TabID: a.ID, TabToken: "a"}, DisplayName: "New"}); err != nil {
		t.Fatal(err)
	}
	result := make(chan error, 1)
	go func() {
		result <- NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source"})
	}()
	waitForPostgresLocks(t, db, 1)
	if err := tx.Commit().Error; err != nil {
		t.Fatal(err)
	}
	if err := receiveAuthResult(t, result); !errors.Is(err, ErrDestinationForbidden) {
		t.Fatalf("stale legacy policy: %v", err)
	}
	var got models.Bill
	db.First(&got, source.ID)
	if got.TabID != nil {
		t.Fatal("attached without newly-required membership")
	}
}

func TestPostgresAttachmentAndCreationRollback(t *testing.T) {
	db := authorizationPostgres(t)
	db = db.Session(&gorm.Session{NowFunc: func() time.Time {
		return time.Date(2026, 11, 5, 1, 2, 3, 123456789, time.UTC)
	}})
	a, _, source := seedPostgresAttachment(t, db)
	// Constraint failures occur at actual PostgreSQL writes, inside the transactions.
	var baseline models.Bill
	if err := db.First(&baseline, source.ID).Error; err != nil {
		t.Fatal(err)
	}
	if baseline.UpdatedAt.Equal(source.UpdatedAt) || baseline.UpdatedAt.Nanosecond()%1000 != 0 {
		t.Fatal("healthy control did not exercise persisted seed precision")
	}
	source = baseline
	before := authSnapshot(t, db)
	if err := db.Exec(fmt.Sprintf("ALTER TABLE bills ADD CONSTRAINT reject_attach CHECK (tab_id IS NULL OR tab_id <> %d)", a.ID)).Error; err != nil {
		t.Fatal(err)
	}
	if err := NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source"}); err == nil {
		t.Fatal("expected write failure")
	}
	var got models.Bill
	if err := db.First(&got, source.ID).Error; err != nil {
		t.Fatal(err)
	}
	if got.TabID != nil || got.PaidByMemberID != nil || !got.UpdatedAt.Equal(source.UpdatedAt) {
		t.Fatal("failed attachment partially committed")
	}
	if authSnapshot(t, db) != before {
		t.Fatal("constraint failure changed persisted ownership/content/timestamps")
	}
	if err := db.Exec("ALTER TABLE item_assignments ADD CONSTRAINT reject_child CHECK (percentage < 100)").Error; err != nil {
		t.Fatal(err)
	}
	next := &models.Bill{Name: "Rollback", Subtotal: 10, Total: 10, Participants: []models.Person{{Name: "Alex"}}, Items: []models.BillItem{{Name: "Dinner", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}}
	if _, err := billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{}).CreateBill(context.Background(), billpkg.CreateBillCommand{Content: next}); err == nil {
		t.Fatal("expected child failure")
	}
	for _, table := range []string{"people", "bill_participants", "bill_items", "item_assignments", "person_shares"} {
		var count int64
		if err := db.Table(table).Count(&count).Error; err != nil {
			t.Fatal(err)
		}
		if count != 0 {
			t.Fatalf("creation leaked %s rows: %d", table, count)
		}
	}
	var count int64
	db.Model(&models.Bill{}).Count(&count)
	if count != 1 {
		t.Fatal("creation leaked parent")
	}
	if err := db.Exec("ALTER TABLE bills DROP CONSTRAINT reject_attach").Error; err != nil {
		t.Fatal(err)
	}
	if err := NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: a.ID, TabToken: "a", BillID: source.ID, BillToken: "source"}); err != nil {
		t.Fatal("healthy attachment after removing the constraint:", err)
	}
}

func TestPostgresStaleStandaloneSingleAndBatchClaims(t *testing.T) {
	for _, batch := range []bool{false, true} {
		t.Run(fmt.Sprint(batch), func(t *testing.T) { assertStaleStandaloneClaim(t, authorizationPostgres(t), batch) })
	}
}

type authQueryCounter struct {
	logger.Interface
	count atomic.Int64
}

func (c *authQueryCounter) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	c.count.Add(1)
	c.Interface.Trace(ctx, begin, fc, err)
}

func TestPostgresCreationAttachmentQueryShapeAndLatency(t *testing.T) {
	db := authorizationPostgres(t)
	for _, items := range []int{1, 100, 500} {
		t.Run(fmt.Sprint(items), func(t *testing.T) {
			dst := models.Tab{Name: fmt.Sprint(items), AccessToken: fmt.Sprint(items)}
			saveAuthFixture(t, db, &dst)
			counter := &authQueryCounter{Interface: logger.Default.LogMode(logger.Silent)}
			measured := db.Session(&gorm.Session{Logger: counter})
			var creates, attaches []time.Duration
			var createQueries, attachQueries int64
			for sample := 0; sample < 10; sample++ {
				next := &models.Bill{Name: "Representative USD", Subtotal: float64(items), Total: float64(items), AccessToken: fmt.Sprintf("perf-%d-%d", items, sample)}
				for i := 0; i < items; i++ {
					item := models.BillItem{Name: "Repeated", Price: 1}
					for person := 0; person < 10; person++ {
						item.Assignments = append(item.Assignments, models.ItemAssignment{PersonName: fmt.Sprintf("Person %d", person), Percentage: 10})
					}
					next.Items = append(next.Items, item)
				}
				counter.count.Store(0)
				start := time.Now()
				requestItems := make([]map[string]any, 0, len(next.Items))
				for _, item := range next.Items {
					as := make([]map[string]any, 0, len(item.Assignments))
					for _, a := range item.Assignments {
						as = append(as, map[string]any{"person_name": a.PersonName, "percentage": a.Percentage})
					}
					requestItems = append(requestItems, map[string]any{"name": item.Name, "price": item.Price, "assignments": as})
				}
				body, _ := json.Marshal(map[string]any{"name": next.Name, "subtotal": next.Subtotal, "total": next.Total, "items": requestItems})
				r := authorizationRouter(measured)
				start = time.Now()
				w := authRequest(r, "POST", "/api/bills", string(body), "", "")
				if w.Code != 201 {
					t.Fatalf("HTTP creation: %d %s", w.Code, w.Body.String())
				}
				var response struct {
					ID    uint   `json:"bill_id"`
					Token string `json:"access_token"`
				}
				if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
					t.Fatal(err)
				}
				next.ID = response.ID
				next.AccessToken = response.Token
				creates = append(creates, time.Since(start))
				cq := counter.count.Load()
				if sample == 0 {
					createQueries = cq
				} else if cq != createQueries {
					t.Fatalf("unstable creation queries %d/%d", cq, createQueries)
				}
				counter.count.Store(0)
				start = time.Now()
				attached := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, next.ID, next.AccessToken), dst.AccessToken, "")
				if attached.Code != 200 {
					t.Fatalf("HTTP attachment: %d %s", attached.Code, attached.Body.String())
				}
				attaches = append(attaches, time.Since(start))
				aq := counter.count.Load()
				if sample == 0 {
					attachQueries = aq
				} else if aq != attachQueries {
					t.Fatalf("unstable attachment queries %d/%d", aq, attachQueries)
				}
			}
			// Five fixed data statements plus one checked INSERT per500 assignments.
			if createQueries > int64(5+(items*10+499)/500) || attachQueries > 5 {
				t.Fatalf("unexpected per-item query growth: create=%d attach=%d", createQueries, attachQueries)
			}
			sort.Slice(creates, func(i, j int) bool { return creates[i] < creates[j] })
			sort.Slice(attaches, func(i, j int) bool { return attaches[i] < attaches[j] })
			t.Logf("items=%d assignments=%d samples=10 create_queries=%d attach_queries=%d create_p50=%s create_max=%s attach_p50=%s attach_max=%s (local race build; no production latency budget claimed)",
				items, items*10, createQueries, attachQueries, creates[4], creates[9], attaches[4], attaches[9])
		})
	}
}

func TestPostgresCreationMoneyBoundary(t *testing.T) {
	assertCreationMoneyBoundary(t, authorizationPostgres(t))
}

func TestPostgresUnsafeShareCalculationRollsBack(t *testing.T) {
	assertUnsafeShareCalculationRollsBack(t, authorizationPostgres(t))
}
