//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"database/sql"
	"errors"
	"runtime"
	"testing"
	"time"
)

func pendingSQL(payload string) []Step {
	steps, _ := Registry()
	return append(steps, Step{Version: 3, Name: "0003_test_only.sql", ValidationChecksum: receiptRecognizerChecksum, Checksum: checksum(payload), Epoch: CompatibilityEpoch, SQL: payload})
}
func waitActivity(t *testing.T, db *sql.DB, predicate string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for ctx.Err() == nil {
		var found bool
		err := db.QueryRowContext(ctx, "SELECT EXISTS(SELECT FROM pg_stat_activity WHERE application_name=current_setting('application_name') AND "+predicate+")").Scan(&found)
		if err != nil {
			t.Fatal(err)
		}
		if found {
			return
		}
		runtime.Gosched()
	}
	t.Fatal("worker did not reach observed PostgreSQL barrier")
}
func receive(t *testing.T, result <-chan error) error {
	t.Helper()
	select {
	case err := <-result:
		return err
	case <-time.After(15 * time.Second):
		t.Fatal("migration did not finish")
		return nil
	}
}
func heldMigrationLock(t *testing.T, db *sql.DB) *sql.Tx {
	t.Helper()
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { tx.Rollback() })
	var schema string
	if err = tx.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec("SELECT pg_advisory_xact_lock($1)", lockKey(schema)); err != nil {
		t.Fatal(err)
	}
	return tx
}

func TestPostgresAtomicPendingFailures(t *testing.T) {
	for name, sql := range map[string]string{
		"ddl":    "CREATE TABLE rollback_marker(id bigint);CREATE TABLE bills(id bigint)",
		"dml":    "CREATE TABLE rollback_marker(id bigint);UPDATE bills SET total=NULL WHERE id=101",
		"ledger": "CREATE TABLE rollback_marker(id bigint);UPDATE bills SET name='must roll back';ALTER TABLE schema_migrations ADD CONSTRAINT reject_pending CHECK(version<3)",
		"commit": "CREATE TABLE rollback_marker(id bigint REFERENCES bills(id) DEFERRABLE INITIALLY DEFERRED);UPDATE bills SET name='must roll back';INSERT INTO rollback_marker VALUES(99999999)",
	} {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			frozenLegacy(t, db)
			seedLegacy(t, db)
			apply(t, db)
			before := snapshot(t, db)
			s, err := run(context.Background(), db, Apply, pendingSQL(sql))
			if err == nil || s != nil {
				t.Fatal("failed pending batch accepted")
			}
			var migrationError *Error
			if !errors.As(err, &migrationError) {
				t.Fatal("missing typed failure")
			}
			expected := map[string]string{"ddl": "pending apply", "dml": "pending apply", "ledger": "ledger insert", "commit": "commit"}[name]
			if migrationError.stage != expected {
				t.Fatalf("failure stage %s want %s", migrationError.stage, expected)
			}
			if before != snapshot(t, db) || scalar(t, db, "SELECT count(*) FROM schema_migrations") != 2 || scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='rollback_marker'") != 0 {
				t.Fatal("partial DDL/DML/ledger survived rollback")
			}
			repaired := pendingSQL("CREATE TABLE rollback_marker(id bigint);UPDATE bills SET name='applied once' WHERE id=101")
			for i := 0; i < 2; i++ {
				if _, err = run(context.Background(), db, Apply, repaired); err != nil {
					t.Fatal(err)
				}
			}
			if scalar(t, db, "SELECT count(*) FROM schema_migrations WHERE version=3") != 1 {
				t.Fatal("retry applied twice")
			}
		})
	}
	for _, legacy := range []bool{false, true} {
		name := "fresh"
		if legacy {
			name = "legacy"
		}
		t.Run(name+"_whole_batch", func(t *testing.T) {
			db := testpostgres.Open(t)
			before := ""
			if legacy {
				frozenLegacy(t, db)
				seedLegacy(t, db)
				before = snapshot(t, db)
			}
			_, err := run(context.Background(), db, Apply, pendingSQL("CREATE TABLE rollback_marker(id bigint);SELECT 1/0"))
			if err == nil {
				t.Fatal("failing batch succeeded")
			}
			if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname IN ('schema_migrations','rollback_marker')") != 0 {
				t.Fatal("partial ledger/DDL survived")
			}
			if legacy {
				if before != snapshot(t, db) {
					t.Fatal("legacy adoption rewrote data")
				}
			} else if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace") != 0 {
				t.Fatal("baseline leaked out of failed batch")
			}
			apply(t, db)
			apply(t, db)
		})
	}
}

func TestPostgresConcurrentStartersRereadAfterLock(t *testing.T) {
	db := testpostgres.Open(t)
	hold := heldMigrationLock(t, db)
	result := make(chan error, 2)
	for i := 0; i < 2; i++ {
		go func() { _, err := Run(context.Background(), db, Apply); result <- err }()
	}
	// Before the winner can create the ledger, BOTH real starter sessions must be
	// blocked on our transaction's advisory lock. Names alone are not evidence.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	for {
		var waiting int
		if err := db.QueryRowContext(ctx, "SELECT count(*) FROM pg_stat_activity WHERE application_name=current_setting('application_name') AND wait_event_type='Lock' AND wait_event='advisory'").Scan(&waiting); err != nil {
			t.Fatal(err)
		}
		if waiting == 2 {
			break
		}
		if ctx.Err() != nil {
			t.Fatal("two lock waiters not observed")
		}
		runtime.Gosched()
	}
	if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='schema_migrations'") != 0 {
		t.Fatal("starter inspected/created ledger before lock")
	}
	if err := hold.Commit(); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if err := receive(t, result); err != nil {
			t.Fatal(err)
		}
	}
	if scalar(t, db, "SELECT count(*) FROM schema_migrations") != 2 {
		t.Fatal("competing starters duplicated history")
	}
}

func TestPostgresMigrationLockDeadline(t *testing.T) {
	db := testpostgres.Open(t)
	hold := heldMigrationLock(t, db)
	defer hold.Rollback()
	result := make(chan error, 1)
	start := time.Now()
	go func() { _, err := Run(context.Background(), db, Apply); result <- err }()
	waitActivity(t, db, "wait_event_type='Lock' AND wait_event='advisory'")
	err := receive(t, result)
	elapsed := time.Since(start)
	if !errors.Is(err, context.DeadlineExceeded) || elapsed < LockTimeout || elapsed > LockTimeout+3*time.Second {
		t.Fatal("5s lock deadline not enforced", err, elapsed)
	}
	if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace") != 0 {
		t.Fatal("timed-out starter wrote before acquiring lock")
	}
}

func TestPostgresInterruptedMigrationReleasesLock(t *testing.T) {
	for _, cancelRequest := range []bool{false, true} {
		name := "terminate_connection"
		if cancelRequest {
			name = "cancel_context"
		}
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			apply(t, db)
			seedLegacy(t, db)
			before := snapshot(t, db)
			steps := pendingSQL("CREATE TABLE interruption_marker(id bigint);UPDATE bills SET name='must roll back';SELECT pg_sleep(30)")
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			result := make(chan error, 1)
			go func() { _, err := run(ctx, db, Apply, steps); result <- err }()
			waitActivity(t, db, "wait_event='PgSleep'")
			if cancelRequest {
				cancel()
			} else {
				var killed bool
				if err := db.QueryRow("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name=current_setting('application_name') AND wait_event='PgSleep'").Scan(&killed); err != nil || !killed {
					t.Fatal("could not terminate owned migration connection", err)
				}
			}
			err := receive(t, result)
			if err == nil {
				t.Fatal("interrupted batch succeeded")
			}
			if cancelRequest && !errors.Is(err, context.Canceled) {
				t.Fatal("cancellation type lost", err)
			}
			// Retry on another real connection must acquire the released transaction lock.
			repaired := pendingSQL("CREATE TABLE interruption_marker(id bigint);UPDATE bills SET name='applied once' WHERE id=101")
			if before != snapshot(t, db) || scalar(t, db, "SELECT count(*) FROM schema_migrations") != 2 || scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='interruption_marker'") != 0 {
				t.Fatal("interrupted transaction leaked writes")
			}
			for i := 0; i < 2; i++ {
				if _, err = run(context.Background(), db, Apply, repaired); err != nil {
					t.Fatal(err)
				}
			}
			if scalar(t, db, "SELECT count(*) FROM schema_migrations WHERE version=3") != 1 {
				t.Fatal("retry applied more than once")
			}
		})
	}
}

func TestPostgresMigrationParentDeadline(t *testing.T) {
	db := testpostgres.Open(t)
	// The same total-deadline path uses the earlier of the caller's deadline and
	// the immutable 60s ceiling. Exercise it promptly, after real pending SQL starts.
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	steps := pendingSQL("CREATE TABLE deadline_marker(id bigint);SELECT pg_sleep(30)")
	result := make(chan error, 1)
	go func() { _, err := run(ctx, db, Apply, steps); result <- err }()
	waitActivity(t, db, "wait_event='PgSleep'")
	if err := receive(t, result); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal("total context deadline lost", err)
	}
	if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace") != 0 {
		t.Fatal("deadline did not roll back whole pending batch")
	}
	apply(t, db)
}

func TestPostgresAllPendingVersionsRollbackTogether(t *testing.T) {
	db := testpostgres.Open(t)
	apply(t, db)
	seedLegacy(t, db)
	before := snapshot(t, db)
	steps := pendingSQL("CREATE TABLE batch_marker(id bigint);UPDATE bills SET name='must roll back'")
	payload := "SELECT 1/0"
	steps = append(steps, Step{Version: 4, Name: "0004_test_only.sql", ValidationChecksum: receiptRecognizerChecksum, Checksum: checksum(payload), Epoch: CompatibilityEpoch, SQL: payload})
	if state, err := run(context.Background(), db, Apply, steps); err == nil || state != nil {
		t.Fatal("failed later step accepted")
	}
	if before != snapshot(t, db) || scalar(t, db, "SELECT count(*) FROM schema_migrations") != 2 || scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='batch_marker'") != 0 {
		t.Fatal("earlier pending version escaped failed batch")
	}
}

func TestPostgresMigrationLockIsSchemaScoped(t *testing.T) {
	first, second := testpostgres.Open(t), testpostgres.Open(t)
	hold := heldMigrationLock(t, first)
	defer hold.Rollback()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := Run(ctx, second, Apply); err != nil {
		t.Fatal("unrelated target schema shared migration lock", err)
	}
}
