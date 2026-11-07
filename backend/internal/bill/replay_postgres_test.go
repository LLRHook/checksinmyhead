//go:build integration

package bill

import (
	"backend/internal/testpostgres"
	"backend/migrations"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"

	"backend/pkg/models"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"gorm.io/gorm/logger"
)

func replayPG(t *testing.T) (*sql.DB, *gorm.DB) {
	t.Helper()
	db := testpostgres.Open(t)
	if _, err := migrations.Run(context.Background(), db, migrations.Apply); err != nil {
		t.Fatal(err)
	}
	g, err := gorm.Open(postgres.New(postgres.Config{Conn: db}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	return db, g
}
func replayInsert(t *testing.T, name, token string) CreationInsert {
	t.Helper()
	v := &models.Bill{Name: name, Subtotal: 10, Total: 10, CurrencyCode: "USD", Participants: []models.Person{{Name: "Alex"}}, Items: []models.BillItem{{Name: "Repeated", Price: 6, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}, {Name: "Repeated", Price: 4, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}}
	if err := prepareCreation(v); err != nil {
		t.Fatal(err)
	}
	v.USDExchangeRate = 1
	v.USDTotal = 10
	v.ExchangeRateSource = "native-usd"
	v.AccessToken = token
	d := 10.0
	s := "same_currency"
	v.DisplayTotal = &d
	v.DisplayRateSource = &s
	return CreationInsert{Bill: v, Replay: &ReplayIdentity{KeyDigest: [32]byte{7}, Fingerprint: [32]byte{byte(len(name))}, Version: 1}}
}
func replayExec(t *testing.T, db *sql.DB, sql string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, sql); err != nil {
		t.Fatal(err)
	}
}
func replayCount(t *testing.T, db *sql.DB, table string) int {
	t.Helper()
	var n int
	if err := db.QueryRow("SELECT count(*) FROM " + table).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}
func replayGraph(t *testing.T, db *sql.DB, bills int) {
	t.Helper()
	for table, want := range map[string]int{"bills": bills, "people": bills, "bill_participants": bills, "bill_items": 2 * bills, "item_assignments": 2 * bills, "person_shares": bills} {
		if n := replayCount(t, db, table); n != want {
			t.Fatalf("winner-only graph violated: %s=%d want%d", table, n, want)
		}
	}
}
func replayWait(t *testing.T, db *sql.DB, event string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for ctx.Err() == nil {
		var n int
		if err := db.QueryRowContext(ctx, `SELECT count(*) FROM pg_stat_activity WHERE application_name=current_setting('application_name') AND wait_event_type='Lock' AND wait_event=$1`, event).Scan(&n); err != nil {
			t.Fatal(err)
		}
		if n > 0 {
			return
		}
		runtime.Gosched()
	}
	t.Fatal("expected real PostgreSQL lock waiter absent")
}
func replayReceive(t *testing.T, ch <-chan error) error {
	t.Helper()
	select {
	case err := <-ch:
		return err
	case <-time.After(12 * time.Second):
		t.Fatal("bounded creation did not finish")
		return nil
	}
}

func TestPostgresReplayElectionWaitVisibilityBothOrdersAndRollback(t *testing.T) {
	for _, changed := range []bool{false, true} {
		for _, reverse := range []bool{false, true} {
			for _, rollback := range []bool{false, true} {
				t.Run(fmt.Sprintf("changed=%v/reverse=%v/rollback=%v", changed, reverse, rollback), func(t *testing.T) {
					db, g := replayPG(t)
					winner := replayInsert(t, "First", "first-token")
					waiter := replayInsert(t, "First", "waiter-token")
					if changed {
						waiter.Bill.Name = "Changed"
						waiter.Replay.Fingerprint = [32]byte{99}
					}
					if reverse {
						winner, waiter = waiter, winner
					}
					hold := g.Begin(&sql.TxOptions{Isolation: sql.LevelReadCommitted})
					if hold.Error != nil {
						t.Fatal(hold.Error)
					}
					defer hold.Rollback()
					v := cloneCreation(winner.Bill)
					var graphErr error
					v.ParticipantRows, graphErr = creationParticipants(v)
					if graphErr != nil {
						t.Fatal(graphErr)
					}
					v.IdentityVersion, v.IdentityState = 2, "ready"
					v.CreationKeyDigest = winner.Replay.KeyDigest[:]
					v.CreationFingerprint = winner.Replay.Fingerprint[:]
					version := int16(1)
					v.CreationFingerprintVersion = &version
					if err := hold.Omit(clause.Associations).Create(v).Error; err != nil {
						t.Fatal(err)
					}
					var result CreationRecord
					ch := make(chan error, 1)
					go func() {
						var err error
						result, err = (&billRepository{db: g}).Create(context.Background(), waiter)
						ch <- err
					}()
					replayWait(t, db, "transactionid") // the unique-index wait is observed, not inferred
					if rollback {
						if err := hold.Rollback().Error; err != nil {
							t.Fatal(err)
						}
					} else {
						if err := insertCreationChildren(hold, v); err != nil {
							t.Fatal(err)
						}
						if err := hold.Commit().Error; err != nil {
							t.Fatal(err)
						}
					}
					err := replayReceive(t, ch)
					if changed && !rollback {
						if !errors.Is(err, ErrReplayConflict) || result.Result.AccessToken != "" {
							t.Fatalf("conflict secrecy/result: %v %+v", err, result.Result)
						}
					} else {
						if err != nil {
							t.Fatal(err)
						}
						token := winner.Bill.AccessToken
						if rollback {
							token = waiter.Bill.AccessToken
						}
						if result.Result.BillID == 0 || result.Result.AccessToken != token || result.Result.Replayed == rollback {
							t.Fatal("not the acknowledged elected identity")
						}
					}
					replayGraph(t, db, 1)
				})
			}
		}
	}
}
func TestPostgresReplayConcurrentFreshWriters(t *testing.T) {
	db, g := replayPG(t)
	start := make(chan struct{})
	var wg sync.WaitGroup
	results := make(chan CreationRecord, 8)
	errs := make(chan error, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			c := replayInsert(t, "First", fmt.Sprint("token-", i))
			<-start
			r, e := (&billRepository{db: g}).Create(context.Background(), c)
			results <- r
			errs <- e
		}(i)
	}
	close(start)
	wg.Wait()
	close(results)
	close(errs)
	for e := range errs {
		if e != nil {
			t.Fatal(e)
		}
	}
	var id uint
	var token string
	for r := range results {
		if id == 0 {
			id = r.Result.BillID
			token = r.Result.AccessToken
		}
		if r.Result.BillID != id || r.Result.AccessToken != token {
			t.Fatal("concurrent identities diverged")
		}
	}
	replayGraph(t, db, 1)
}
func TestPostgresReplayEveryChildParentAndDeferredCommitFailure(t *testing.T) {
	for _, table := range []string{"bills", "people", "bill_participants", "bill_items", "item_assignments", "person_shares", "deferred_commit"} {
		t.Run(table, func(t *testing.T) {
			db, g := replayPG(t)
			replayExec(t, db, `CREATE FUNCTION reject_creation() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'synthetic child failure'; END$$`)
			if table == "deferred_commit" {
				replayExec(t, db, `CREATE CONSTRAINT TRIGGER reject_creation AFTER INSERT ON bills DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reject_creation()`)
			} else {
				replayExec(t, db, "CREATE TRIGGER reject_creation BEFORE INSERT ON "+table+" FOR EACH ROW EXECUTE FUNCTION reject_creation()")
			}
			r, e := (&billRepository{db: g}).Create(context.Background(), replayInsert(t, "First", "token"))
			if e == nil || r.Result.BillID != 0 || r.Result.AccessToken != "" {
				t.Fatal("failed creation acknowledged")
			}
			if table == "deferred_commit" && !errors.Is(e, ErrCreateUncertain) {
				t.Fatal("commit outcome not finite503 class")
			}
			replayGraph(t, db, 0)
			target := table
			if table == "deferred_commit" {
				target = "bills"
			}
			replayExec(t, db, "DROP TRIGGER reject_creation ON "+target)
			if _, e := (&billRepository{db: g}).Create(context.Background(), replayInsert(t, "First", "recovered")); e != nil {
				t.Fatal(e)
			}
			replayGraph(t, db, 1)
		})
	}
}
func TestPostgresReplayUnrelatedUniqueViolationIsNotSuppressed(t *testing.T) {
	db, g := replayPG(t)
	repo := &billRepository{db: g}
	first := replayInsert(t, "First", "collision")
	if _, err := repo.Create(context.Background(), first); err != nil {
		t.Fatal(err)
	}
	next := replayInsert(t, "First", "collision")
	next.Replay.KeyDigest = [32]byte{8}
	if r, err := repo.Create(context.Background(), next); err == nil || r.Result.BillID != 0 {
		t.Fatal("unrelated unique error suppressed")
	}
	replayGraph(t, db, 1)
}
func TestPostgresReplayCancelDeadlineAndSameKeyRecovery(t *testing.T) {
	for _, deadline := range []bool{false, true} {
		t.Run(fmt.Sprint(deadline), func(t *testing.T) {
			db, g := replayPG(t)
			repo := &billRepository{db: g}
			replayExec(t, db, `CREATE FUNCTION block_creation() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN PERFORM pg_advisory_xact_lock(90020004); RETURN NEW; END$$;CREATE TRIGGER block_creation BEFORE INSERT ON bill_items FOR EACH ROW EXECUTE FUNCTION block_creation()`)
			hold, err := db.Begin()
			if err != nil {
				t.Fatal(err)
			}
			defer hold.Rollback()
			if _, err = hold.Exec("SELECT pg_advisory_xact_lock(90020004)"); err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithCancel(context.Background())
			if deadline {
				cancel()
				ctx, cancel = context.WithTimeout(context.Background(), 500*time.Millisecond)
			}
			defer cancel()
			ch := make(chan error, 1)
			go func() {
				r, e := repo.Create(ctx, replayInsert(t, "First", "token"))
				if r.Result.BillID != 0 {
					e = errors.New("canceled creation acknowledged")
				}
				ch <- e
			}()
			replayWait(t, db, "advisory")
			if !deadline {
				cancel()
			}
			if e := replayReceive(t, ch); e == nil {
				t.Fatal("interrupted create succeeded")
			}
			if err := hold.Rollback(); err != nil {
				t.Fatal(err)
			}
			replayGraph(t, db, 0)
			replayExec(t, db, "DROP TRIGGER block_creation ON bill_items")
			if _, err := repo.Create(context.Background(), replayInsert(t, "First", "recovery")); err != nil {
				t.Fatal(err)
			}
			replayGraph(t, db, 1)
		})
	}
}
func TestPostgresReplayPersistedReturningAndNoHooks(t *testing.T) {
	db, g := replayPG(t)
	replayExec(t, db, `CREATE FUNCTION persisted_token() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN NEW.access_token='actual-persisted-token'; RETURN NEW; END$$;CREATE TRIGGER persisted_token BEFORE INSERT ON bills FOR EACH ROW EXECUTE FUNCTION persisted_token()`)
	c := replayInsert(t, "First", "discard-local-token")
	repo := &billRepository{db: g}
	first, err := repo.Create(context.Background(), c)
	if err != nil {
		t.Fatal(err)
	}
	if first.Result.AccessToken != "actual-persisted-token" {
		t.Fatal("unacknowledged local token returned")
	}
	// An established scalar read must never invoke Bill AfterFind callbacks.
	if err := g.Callback().Query().Before("gorm:after_query").Register("test:no_graph", func(tx *gorm.DB) {
		if _, ok := tx.Statement.Dest.(*models.Bill); ok {
			tx.AddError(errors.New("replay hydrated Bill"))
		}
	}); err != nil {
		t.Fatal(err)
	}
	got, err := repo.LookupCreation(context.Background(), c.Replay.KeyDigest)
	if err != nil || got == nil {
		t.Fatal(err)
	}
	result, err := compareCreation(*got, *c.Replay)
	if err != nil || result.AccessToken != first.Result.AccessToken {
		t.Fatal("scalar persisted identity lost")
	}
	replayExec(t, db, "UPDATE bills SET creation_fingerprint_version=3")
	got, err = repo.LookupCreation(context.Background(), c.Replay.KeyDigest)
	if err != nil {
		t.Fatal(err)
	}
	if result, err := compareCreation(*got, *c.Replay); !errors.Is(err, ErrReplayVersion) || result.AccessToken != "" {
		t.Fatal("unknown version disclosed capability")
	}
}

func TestPostgresReplayMissingWinnerFailsClosed(t *testing.T) {
	_, g := replayPG(t)
	if err := g.Callback().Create().Before("gorm:create").Register("test:zero_parent", func(tx *gorm.DB) {
		if tx.Statement.Table == "bills" {
			tx.Statement.SQL.WriteString("SELECT 1 WHERE false")
		}
	}); err != nil {
		t.Fatal(err)
	}
	r, err := (&billRepository{db: g}).Create(context.Background(), replayInsert(t, "First", "token"))
	if !errors.Is(err, ErrCreateUncertain) || r.Result.AccessToken != "" {
		t.Fatalf("missing winner fallback: %v", err)
	}
}

// Keep SQL/panic/error disclosure checks independent of response equality.
func assertNoReplaySecrets(t *testing.T, body string, values ...string) {
	t.Helper()
	for _, v := range values {
		if v != "" && strings.Contains(body, v) {
			t.Fatal("capability metadata disclosed")
		}
	}
}

func TestPostgresReplayMidBatchFailureRollsBackAll(t *testing.T) {
	db, g := replayPG(t)
	v := &models.Bill{Name: "Maximum", Subtotal: 500, Total: 500}
	for p := 0; p < 100; p++ {
		v.Participants = append(v.Participants, models.Person{Name: fmt.Sprintf("Person%03d", p)})
	}
	for i := 0; i < 500; i++ {
		item := models.BillItem{Name: "Repeated", Price: 1}
		for j := 0; j < 10; j++ {
			item.Assignments = append(item.Assignments, models.ItemAssignment{PersonName: fmt.Sprintf("Person%03d", (i*10+j)%100), Percentage: 10})
		}
		v.Items = append(v.Items, item)
	}
	if err := prepareCreation(v); err != nil {
		t.Fatal(err)
	}
	v.USDExchangeRate = 1
	v.USDTotal = 500
	v.ExchangeRateSource = "native-usd"
	v.AccessToken = "batch-token"
	total := 500.0
	source := "same_currency"
	v.DisplayTotal = &total
	v.DisplayRateSource = &source
	c := CreationInsert{Bill: v, Replay: &ReplayIdentity{KeyDigest: [32]byte{9}, Fingerprint: [32]byte{10}, Version: 1}}
	replayExec(t, db, `CREATE FUNCTION reject_later_batch() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.id>1000 THEN RAISE EXCEPTION 'synthetic later batch'; END IF;RETURN NEW; END$$;CREATE TRIGGER reject_later_batch BEFORE INSERT ON item_assignments FOR EACH ROW EXECUTE FUNCTION reject_later_batch()`)
	if r, err := (&billRepository{db: g}).Create(context.Background(), c); err == nil || r.Result.BillID != 0 {
		t.Fatal("mid-batch failure acknowledged")
	}
	var last int
	if err := db.QueryRow("SELECT last_value FROM item_assignments_id_seq").Scan(&last); err != nil || last < 1001 {
		t.Fatal("failure did not reach third real assignment batch")
	}
	replayGraph(t, db, 0)
	replayExec(t, db, "DROP TRIGGER reject_later_batch ON item_assignments")
	if _, err := (&billRepository{db: g}).Create(context.Background(), c); err != nil {
		t.Fatal(err)
	}
	for table, want := range map[string]int{"bills": 1, "people": 100, "bill_participants": 100, "bill_items": 500, "item_assignments": 5000, "person_shares": 100} {
		if replayCount(t, db, table) != want {
			t.Fatal("maximum graph/recovery not atomic")
		}
	}
}

func TestPostgresReplayRepositoryFreshGuardWithValidServerValuation(t *testing.T) {
	for _, name := range []string{"parent_id", "participant_id", "item_id", "assignment_id", "share_id", "paid", "time", "tab", "attribution", "replay_model"} {
		t.Run(name, func(t *testing.T) {
			db, g := replayPG(t)
			c := replayInsert(t, "First", "token")
			switch name {
			case "parent_id":
				c.Bill.ID = 99
			case "participant_id":
				c.Bill.Participants[0].ID = 99
			case "item_id":
				c.Bill.Items[0].ID = 99
			case "assignment_id":
				c.Bill.Items[0].Assignments[0].ID = 99
			case "share_id":
				c.Bill.PersonShares[0].ID = 99
			case "paid":
				c.Bill.PersonShares[0].Paid = true
			case "time":
				c.Bill.CreatedAt = time.Now()
			case "tab":
				v := uint(99)
				c.Bill.TabID = &v
			case "attribution":
				v := uint(99)
				c.Bill.AddedByMemberID = &v
			case "replay_model":
				c.Bill.CreationFingerprint = []byte{1}
			}
			if r, err := (&billRepository{db: g}).Create(context.Background(), c); !errors.Is(err, ErrInvalidCreation) || r.Result.AccessToken != "" {
				t.Fatal("internal fresh-state guard failed")
			}
			replayGraph(t, db, 0)
		})
	}
}
