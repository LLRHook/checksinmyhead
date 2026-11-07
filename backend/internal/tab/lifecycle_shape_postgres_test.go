//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testidentity"
	"backend/internal/testpostgres"
	"backend/migrations"
	"backend/pkg/models"
	"context"
	"fmt"
	"github.com/jackc/pgx/v5"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
)

type lifecycleTrace struct {
	mu            sync.Mutex
	data, control int
	shape         []string
}

func (c *lifecycleTrace) TraceQueryStart(ctx context.Context, _ *pgx.Conn, q pgx.TraceQueryStartData) context.Context {
	c.mu.Lock()
	defer c.mu.Unlock()
	sql := strings.ToLower(strings.TrimSpace(q.SQL))
	kind := strings.Fields(sql)[0]
	switch kind {
	case "begin", "commit", "rollback", "savepoint", "release", "set":
		c.control++
	default:
		c.data++
		c.shape = append(c.shape, q.SQL)
	}
	return ctx
}
func (c *lifecycleTrace) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}
func (c *lifecycleTrace) reset() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = 0
	c.control = 0
	c.shape = nil
}
func (c *lifecycleTrace) counts() (int, int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.data, c.control
}
func lifecycleMeasuredDB(t *testing.T, c *lifecycleTrace) *gorm.DB {
	t.Helper()
	sql := testpostgres.Open(t, c)
	if _, err := migrations.Run(context.Background(), sql, migrations.Apply); err != nil {
		t.Fatal(err)
	}
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: sql}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	return db
}
func TestPostgresLifecycleMeasuredBudgets(t *testing.T) {
	for _, size := range []struct {
		name          string
		bills, people int
		target        time.Duration
	}{{"representative", 10, 8, 200 * time.Millisecond}, {"large", 100, 100, 750 * time.Millisecond}} {
		t.Run(size.name, func(t *testing.T) {
			trace := &lifecycleTrace{}
			db := lifecycleMeasuredDB(t, trace)
			dst := models.Tab{Name: "Measured", AccessToken: "tab"}
			saveAuthFixture(t, db, &dst)
			a := TabAccess{TabID: dst.ID, TabToken: "tab"}
			intended := make([]models.TabMember, size.people)
			for j := range intended {
				intended[j] = models.TabMember{TabID: dst.ID, DisplayName: fmt.Sprintf("Person %03d", j), MemberToken: fmt.Sprintf("intended-%d", j), Role: "member"}
				if j == 0 {
					intended[j].Role = "creator"
				}
				saveAuthFixture(t, db, &intended[j])
			}
			a.MemberToken = intended[0].MemberToken
			for i := 0; i < size.bills; i++ {
				b := models.Bill{TabID: &dst.ID, AccessToken: fmt.Sprint("perf-", i), Name: "Measured", Total: float64(size.people), Subtotal: float64(size.people)}
				for j := 0; j < size.people; j++ {
					b.PersonShares = append(b.PersonShares, models.PersonShare{PersonName: fmt.Sprintf("Person %03d", j), Subtotal: 1, Total: 1})
				}
				saveAuthFixture(t, db, &b)
				testidentity.Ready(t, db, &b)
				for j, p := range b.ParticipantRows {
					testidentity.Bind(t, db, b.ID, p.ID, intended[j].ID, intended[0].ID)
				}
			}
			for run := 1; run <= 3; run++ {
				fresh, retry := []time.Duration{}, []time.Duration{}
				freshMax, retryMax, controls := 0, 0, 0
				for sample := 0; sample < 100; sample++ {
					// Reset only this owned synthetic tab, outside the measured operation.
					if err := db.Where("tab_id = ?", dst.ID).Delete(&models.TabSettlement{}).Error; err != nil {
						t.Fatal(err)
					}
					if err := db.Model(&models.Tab{}).Where("id = ?", dst.ID).Updates(map[string]any{"finalized": false, "finalized_at": nil}).Error; err != nil {
						t.Fatal(err)
					}
					trace.reset()
					start := time.Now()
					rows := mustFinalize(t, db, a)
					fresh = append(fresh, time.Since(start))
					n, tc := trace.counts()
					if n > freshMax {
						freshMax = n
					}
					controls += tc
					if len(rows) != size.people {
						t.Fatal("intended confirmed parties were not grouped by member ID")
					}
					for _, row := range rows {
						if row.MemberID == nil || row.ParticipantID != nil || row.Amount != float64(size.bills) {
							t.Fatal("measured reference snapshot changed per-party cents")
						}
					}
					if sample == 0 && run == 1 {
						t.Logf("fresh SQL shape: %q", trace.shape)
					}
					before := lifecycleSnapshot(t, db)
					trace.reset()
					start = time.Now()
					mustFinalize(t, db, a)
					retry = append(retry, time.Since(start))
					n, tc = trace.counts()
					if n > retryMax {
						retryMax = n
					}
					controls += tc
					for _, q := range trace.shape {
						if !strings.HasPrefix(strings.ToLower(q), "select") {
							t.Fatal("replay issued a write")
						}
					}
					if lifecycleSnapshot(t, db) != before {
						t.Fatal("measured retry changed snapshot")
					}
				}
				sort.Slice(fresh, func(i, j int) bool { return fresh[i] < fresh[j] })
				sort.Slice(retry, func(i, j int) bool { return retry[i] < retry[j] })
				t.Logf("budget run=%d bills=%d shares=%d samples=100 fresh_data=%d retry_data=%d transaction_control_total=%d fresh_p50=%s fresh_p95=%s fresh_max=%s fresh_target=%s fresh_miss=%t retry_p95=%s retry_target=100ms retry_miss=%t lock_wait=uncontended", run, size.bills, size.bills*size.people, freshMax, retryMax, controls, fresh[49], fresh[94], fresh[99], size.target, fresh[94] > size.target, retry[94], retry[94] > 100*time.Millisecond)
				if freshMax > 9 || retryMax > 4 {
					t.Fatal("finalize access shape grew")
				}
			}
		})
	}
	t.Run("paid_attachment_assignment", func(t *testing.T) {
		trace := &lifecycleTrace{}
		db := lifecycleMeasuredDB(t, trace)
		dst, b, a := seedReferenceLifecycle(t, db)
		for run := 1; run <= 3; run++ {
			timings := []time.Duration{}
			maxData := 0
			for sample := 0; sample < 100; sample++ {
				trace.reset()
				start := time.Now()
				err := billpkg.NewBillRepository(db).UpdatePersonSharePaid(context.Background(), billpkg.BillSharePaidCommand{Access: billpkg.BillAccess{BillID: b.ID, BillToken: "source"}, ShareID: b.PersonShares[0].ID, Paid: sample%2 == 0})
				if err != nil {
					t.Fatal(err)
				}
				timings = append(timings, time.Since(start))
				n, _ := trace.counts()
				if n > maxData {
					maxData = n
				}
			}
			sort.Slice(timings, func(i, j int) bool { return timings[i] < timings[j] })
			t.Logf("paid run=%d samples=100 data=%d p95=%s target=100ms miss=%t restart=0 lock_wait=uncontended", run, maxData, timings[94], timings[94] > 100*time.Millisecond)
			if maxData > 6 {
				t.Fatal("paid access shape grew")
			}
		}
		// Measure both authorized payment routes and bounded attachment separately.
		creator := models.TabMember{TabID: dst.ID, DisplayName: "Creator", MemberToken: "creator", Role: "creator"}
		alex := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "alex", Role: "member"}
		saveAuthFixture(t, db, &creator)
		saveAuthFixture(t, db, &alex)
		a.MemberToken = "creator"
		bindReferenceFixture(t, db, b, "Alex", alex, creator)
		for run := 1; run <= 3; run++ {
			paidTimes, attachTimes := []time.Duration{}, []time.Duration{}
			paidData, attachData := 0, 0
			for sample := 0; sample < 100; sample++ {
				trace.reset()
				start := time.Now()
				if err := NewTabRepository(db).UpdateBillPersonSharePaid(context.Background(), SharePaidCommand{Access: TabAccess{TabID: dst.ID, TabToken: "tab", MemberToken: "alex"}, BillID: b.ID, ShareID: b.PersonShares[0].ID, Paid: sample%2 == 0}); err != nil {
					t.Fatal(err)
				}
				paidTimes = append(paidTimes, time.Since(start))
				n, _ := trace.counts()
				if n > paidData {
					paidData = n
				}
				source := models.Bill{Name: "Attach", AccessToken: fmt.Sprintf("attach-%d-%d", run, sample), Total: 1, Subtotal: 1}
				saveAuthFixture(t, db, &source)
				trace.reset()
				start = time.Now()
				if err := NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: dst.ID, TabToken: "tab", MemberToken: "creator", BillID: source.ID, BillToken: source.AccessToken}); err != nil {
					t.Fatal(err)
				}
				attachTimes = append(attachTimes, time.Since(start))
				n, _ = trace.counts()
				if n > attachData {
					attachData = n
				}
			}
			sort.Slice(paidTimes, func(i, j int) bool { return paidTimes[i] < paidTimes[j] })
			sort.Slice(attachTimes, func(i, j int) bool { return attachTimes[i] < attachTimes[j] })
			t.Logf("tab_paid run=%d samples=100 data=%d p95=%s target=100ms miss=%t; attachment samples=100 data=%d p95=%s (no latency target); lock_wait=uncontended", run, paidData, paidTimes[94], paidTimes[94] > 100*time.Millisecond, attachData, attachTimes[94])
			if paidData > 6 || attachData > 4 {
				t.Fatal("paid/attachment shape grew")
			}
		}

		bulk := models.Bill{TabID: &dst.ID, AccessToken: "bulk", Name: "500 items", LazyMode: true, Subtotal: 500, Tax: 50, Total: 550}
		updates := []BillItemAssignmentsUpdate{}
		for i := 0; i < 500; i++ {
			item := models.BillItem{Name: "Repeated", Price: 1}
			for j := 0; j < 10; j++ {
				item.Assignments = append(item.Assignments, models.ItemAssignment{PersonName: fmt.Sprint("Person ", j), Percentage: 10})
			}
			bulk.Items = append(bulk.Items, item)
		}
		shares, err := billpkg.BuildLazyPersonShares(&bulk)
		if err != nil {
			t.Fatal(err)
		}
		bulk.PersonShares = shares
		saveAuthFixture(t, db, &bulk)
		testidentity.Ready(t, db, &bulk)
		for _, item := range bulk.Items {
			next := BillItemAssignmentsUpdate{ItemID: item.ID}
			for _, assignment := range item.Assignments {
				next.Assignments = append(next.Assignments, models.ItemAssignment{ParticipantID: assignment.ParticipantID, Percentage: assignment.Percentage})
			}
			updates = append(updates, next)
		}
		phase := 0
		var previousMax uint
		if err := db.Raw("SELECT max(id) FROM item_assignments WHERE bill_id = ?", bulk.ID).Scan(&previousMax).Error; err != nil {
			t.Fatal(err)
		}
		for run := 1; run <= 3; run++ {
			times := []time.Duration{}
			maxData := 0
			for sample := 0; sample < 100; sample++ {
				// Prepare only command input/observers outside the timer. The production
				// owner still authorizes, loads, locks and rewrites the complete graph.
				for i := range updates {
					updates[i].Assignments[0].Percentage = 9
					updates[i].Assignments[1].Percentage = 11
					if phase%2 == 1 {
						updates[i].Assignments[0].Percentage = 11
						updates[i].Assignments[1].Percentage = 9
					}
				}
				phase++
				expected := *testidentity.Revision(t, db, bulk.ID)
				command := AssignmentCommand{Access: a, BillID: bulk.ID, Updates: updates, ExpectedRevision: &expected}
				trace.reset()
				start := time.Now()
				if err := NewTabRepository(db).UpdateBillItemAssignmentsBatch(context.Background(), command); err != nil {
					t.Fatal(err)
				}
				times = append(times, time.Since(start))
				n, _ := trace.counts()
				if n > maxData {
					maxData = n
				}
				var observed struct {
					Count, Changed   int64
					Minimum, Maximum uint
				}
				chunks := 0
				for _, statement := range trace.shape {
					if strings.HasPrefix(strings.ToLower(strings.TrimSpace(statement)), `insert into "item_assignments"`) {
						chunks++
					}
				}
				if chunks != 5 {
					t.Fatal("measured replacement did not execute five checked assignment chunks")
				}
				if err := db.Raw("SELECT count(*) AS count,min(id) AS minimum,max(id) AS maximum,count(*) FILTER (WHERE percentage<>10) AS changed FROM item_assignments WHERE bill_id = ?", bulk.ID).Scan(&observed).Error; err != nil {
					t.Fatal(err)
				}
				if observed.Count != 5000 || observed.Changed != 1000 || observed.Minimum <= previousMax || *testidentity.Revision(t, db, bulk.ID) != expected+1 {
					t.Fatal("measured allocation did not fully replace 5000 rows and advance once")
				}
				previousMax = observed.Maximum
			}
			sort.Slice(times, func(i, j int) bool { return times[i] < times[j] })
			t.Logf("assignment run=%d samples=100 items=500 allocations=5000 data=%d insert_chunks=5 p95=%s lock_wait=uncontended", run, maxData, times[94])
			if maxData > 19 {
				t.Fatal("assignment exceeded 14 plus 5 bounded chunks")
			}
		}
	})
}
