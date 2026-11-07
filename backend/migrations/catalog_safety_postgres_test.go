//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"database/sql"
	"errors"
	"testing"
)

func TestCatalogSafetyV2Postgres(t *testing.T) {
	for _, stage := range []string{"adopt", "ledgered_apply", "ledgered_verify"} {
		names := []string{"child", "cross_schema_child", "disabled_child_fk", "replica_child_fk", "disabled_parent_fk", "replica_session"}
		if stage != "adopt" {
			names = append(names, "ledger_child")
		}
		for _, name := range names {
			t.Run(stage+"/"+name, func(t *testing.T) {
				db := testpostgres.Open(t)
				frozenLegacy(t, db)
				seedLegacy(t, db)
				if stage != "adopt" {
					apply(t, db)
				}
				mutateCatalogSafetyFixture(t, db, name)
				before := snapshot(t, db)
				history := catalogSafetyHistory(t, db)
				mode := Apply
				if stage == "ledgered_verify" {
					mode = Verify
				}
				state, err := Run(context.Background(), db, mode)
				if err == nil || state != nil {
					t.Fatal("unsafe effective catalog accepted")
				}
				if before != snapshot(t, db) || history != catalogSafetyHistory(t, db) {
					t.Fatal("rejected catalog changed data or history")
				}
			})
		}
	}
	for _, name := range []string{"always_fk", "unrelated_inheritance"} {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			frozenLegacy(t, db)
			seedLegacy(t, db)
			switch name {
			case "always_fk":
				setCatalogSafetyFKMode(t, db, "ALWAYS")
			case "unrelated_inheritance":
				execSQL(t, db, "CREATE TABLE unrelated_parent(id int);CREATE TABLE unrelated_child() INHERITS(unrelated_parent)")
			}
			if name == "always_fk" {
				_, err := db.Exec("INSERT INTO bill_items(id,bill_id,name,price) VALUES(991,999999,'Synthetic orphan',1)")
				var violation interface{ SQLState() string }
				if !errors.As(err, &violation) || violation.SQLState() != "23503" {
					t.Fatal("enabled FK did not reject the orphan with a foreign-key violation")
				}
			}
			before := snapshot(t, db)
			state, err := Run(context.Background(), db, Apply)
			if err != nil || state == nil {
				t.Fatal("compatible effective catalog rejected")
			}
			if err := state.Check(context.Background()); err != nil {
				t.Fatal("compatible catalog unready")
			}
			if before != snapshot(t, db) {
				t.Fatal("compatible adoption changed rows")
			}
		})
	}
}

func catalogSafetyHistory(t *testing.T, db *sql.DB) string {
	t.Helper()
	if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='schema_migrations'") == 0 {
		return "absent"
	}
	var value string
	if err := db.QueryRow("SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY version),'[]')::text FROM ONLY schema_migrations x").Scan(&value); err != nil {
		t.Fatal(err)
	}
	return value
}

func mutateCatalogSafetyFixture(t *testing.T, db *sql.DB, name string) {
	t.Helper()
	switch name {
	case "child":
		execSQL(t, db, "CREATE TABLE unexpected_items() INHERITS(bill_items)")
	case "cross_schema_child":
		other := testpostgres.Open(t)
		var schema string
		if err := other.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
			t.Fatal(err)
		}
		execSQL(t, db, "CREATE TABLE "+quote(schema)+".unexpected_items() INHERITS(bill_items)")
	case "ledger_child":
		execSQL(t, db, "CREATE TABLE unexpected_history() INHERITS(schema_migrations)")
	case "disabled_child_fk":
		execSQL(t, db, "ALTER TABLE ONLY bill_items DISABLE TRIGGER ALL")
	case "replica_child_fk":
		setCatalogSafetyFKMode(t, db, "REPLICA")
	case "disabled_parent_fk":
		execSQL(t, db, "ALTER TABLE ONLY bills DISABLE TRIGGER ALL")
	case "replica_session":
		db.SetMaxOpenConns(1)
		execSQL(t, db, "SET session_replication_role=replica")
	default:
		t.Fatal("unknown synthetic mutation")
	}
}

func setCatalogSafetyFKMode(t *testing.T, db *sql.DB, mode string) {
	t.Helper()
	if mode != "REPLICA" && mode != "ALWAYS" {
		t.Fatal("unknown test-only trigger mode")
	}
	var name string
	if err := db.QueryRow("SELECT tgname FROM pg_catalog.pg_trigger WHERE tgrelid='bill_items'::regclass AND tgisinternal AND tgconstraint<>0 ORDER BY tgname LIMIT 1").Scan(&name); err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, "ALTER TABLE ONLY bill_items ENABLE "+mode+" TRIGGER "+quote(name))
}
