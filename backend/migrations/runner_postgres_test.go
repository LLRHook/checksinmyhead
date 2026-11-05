//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"database/sql"
	_ "embed"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"
)

//go:embed testdata/legacy-f1d62374.sql
var legacySQL string

func execSQL(t *testing.T, db *sql.DB, statement string, args ...any) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if _, err := db.ExecContext(ctx, statement, args...); err != nil {
		t.Fatal("fixture SQL failed:", err)
	}
}
func scalar(t *testing.T, db *sql.DB, q string, args ...any) int {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	var got int
	if err := db.QueryRowContext(ctx, q, args...).Scan(&got); err != nil {
		t.Fatal(err)
	}
	return got
}
func apply(t *testing.T, db *sql.DB) *State {
	t.Helper()
	s, err := Run(context.Background(), db, Apply)
	if err != nil {
		t.Fatal(err)
	}
	return s
}
func frozenLegacy(t *testing.T, db *sql.DB) { t.Helper(); execSQL(t, db, legacySQL) }
func snapshot(t *testing.T, db *sql.DB) string {
	t.Helper()
	// Compare every original value. New migration metadata is verified separately;
	// participant structural IDs must not replace the original composite key.
	added := map[string]string{
		"bills":             "'creation_key_digest','creation_fingerprint','creation_fingerprint_version','display_rate_date','display_rate_source','display_rate_retrieved_at','identity_version','identity_state','identity_revision','creation_response_version','creation_response'",
		"bill_participants": "'id','label','allocation_label','identity_version','ordinal','client_ref','tab_id','member_id','pending_member_id','approved_by_member_id','approval_kind','requested_at','approved_at','pending_request_revision','last_binding_member_id','last_binding_request_revision','last_binding_decision','last_binding_actor_member_id','last_binding_actor_kind','last_binding_result_revision','last_binding_decided_at'",
		"item_assignments":  "'identity_version','participant_id','bill_id'",
		"person_shares":     "'identity_version','participant_id'",
		"tab_settlements":   "'snapshot_version','member_id','participant_id'",
	}
	var result []string
	for _, table := range []string{"tabs", "tab_members", "bills", "bill_items", "people", "bill_participants", "item_assignments", "person_shares", "tab_settlements"} {
		var b string
		if scalar(t, db, "SELECT count(*) FROM pg_class WHERE oid=to_regclass($1)", table) == 0 {
			result = append(result, "absent")
			continue
		}
		if err := db.QueryRow(`SELECT COALESCE(jsonb_agg(value ORDER BY value::text),'[]')::text FROM (SELECT to_jsonb(x)-ARRAY[` + added[table] + `]::text[] AS value FROM ` + table + ` x) original`).Scan(&b); err != nil {
			t.Fatal(err)
		}
		result = append(result, b)
	}
	return strings.Join(result, "\n")
}
func seedLegacy(t *testing.T, db *sql.DB) {
	t.Helper()
	execSQL(t, db, `INSERT INTO tabs(id,name,access_token,finalized,finalized_at) VALUES
 (41,'Frozen trip','synthetic-tab-token',true,'2025-01-01Z'),(42,'Other trip','synthetic-other-token',false,NULL);
 INSERT INTO tab_members(id,tab_id,display_name,member_token,role) VALUES
 (71,41,'Alex','synthetic-member-token','creator'),(72,42,'Alex','synthetic-other-member','member');
 INSERT INTO bills(id,tab_id,added_by_member_id,paid_by_member_id,name,subtotal,tax,tip_amount,total,currency_code,usd_exchange_rate,usd_total,display_currency,display_total,exchange_rate,exchange_rate_source,exchange_rate_date,date,payment_methods,access_token) VALUES
 (101,41,71,NULL,'Legacy null payer',20,2,3,25,'EUR',1.25,31.25,'CAD',40,1.6,'frozen-source','2025-01-01','2025-01-01Z','{"venmo":"synthetic-handle","quote":"quoted '' value"}','synthetic-bill-token'),
 (102,41,71,9999,'Dangling payer',1,0,0,1,'USD',1,1,'USD',NULL,NULL,NULL,NULL,'2025-01-01Z',NULL,'synthetic-dangling-token'),
 (103,41,71,72,'Cross-tab payer',1,0,0,1,'USD',1,1,'USD',NULL,NULL,NULL,NULL,'2025-01-01Z',NULL,'synthetic-cross-token');
 INSERT INTO people(id,name) VALUES (81,'Alex');
 INSERT INTO bill_participants VALUES (101,81);
 INSERT INTO bill_items(id,bill_id,name,price) VALUES (91,101,'Repeated',10),(92,101,'Repeated',10);
 INSERT INTO item_assignments(id,bill_item_id,person_name,percentage) VALUES (111,91,'Alex',100);
 INSERT INTO person_shares(id,bill_id,person_name,items,subtotal,tax_share,tip_share,total,paid)
 VALUES (121,101,'Alex','[{"name":"Repeated","price":10,"quoted":"''"}]',10,2,3,15,true);
 INSERT INTO tab_settlements(id,tab_id,person_name,amount,paid,created_at) VALUES (131,41,'Alex',18.75,true,'2025-01-01Z');
 SELECT setval('bills_id_seq',501,true);`)
}

func TestFrozenLegacyFixture(t *testing.T) {
	if checksum(legacySQL) != "795c6e0fd33232470607cf7279b2411410195fe873b4808c9e31204db46ac0dc" {
		t.Fatal("frozen released fixture changed")
	}
}

func TestPostgresFreshAndLegacyPreservation(t *testing.T) {
	for _, legacy := range []bool{false, true} {
		name := "fresh"
		if legacy {
			name = "legacy"
		}
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			if legacy {
				frozenLegacy(t, db)
				seedLegacy(t, db)
			}
			before := ""
			if legacy {
				before = snapshot(t, db)
			}
			start := time.Now()
			s := apply(t, db)
			t.Logf("startup %s", time.Since(start))
			if !legacy {
				seedLegacy(t, db)
				before = snapshot(t, db)
			}
			var applied string
			if err := db.QueryRow("SELECT applied_at::text FROM schema_migrations WHERE version=1").Scan(&applied); err != nil {
				t.Fatal(err)
			}
			for _, mode := range []Mode{Apply, Verify} {
				repeat, err := Run(context.Background(), db, mode)
				if err != nil {
					t.Fatal(err)
				}
				if err = repeat.Check(context.Background()); err != nil {
					t.Fatal(err)
				}
			}
			var after string
			db.QueryRow("SELECT applied_at::text FROM schema_migrations WHERE version=1").Scan(&after)
			if before != snapshot(t, db) || applied != after || scalar(t, db, "SELECT count(*) FROM schema_migrations") != 3 {
				t.Fatal("adoption/repeat changed history or frozen data")
			}
			if scalar(t, db, "SELECT last_value FROM bills_id_seq") != 501 {
				t.Fatal("adoption reset sequence")
			}
			if err := s.Check(context.Background()); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestPostgresBaselineDefinitions(t *testing.T) {
	cases := map[string]string{
		"partial":              "DROP TABLE bill_participants",
		"type":                 "ALTER TABLE bills ALTER COLUMN total TYPE text",
		"typmod":               "ALTER TABLE bills ALTER COLUMN currency_code TYPE character(4)",
		"nullable":             "ALTER TABLE bills ALTER COLUMN total DROP NOT NULL",
		"default":              "ALTER TABLE bills ALTER COLUMN usd_exchange_rate SET DEFAULT 2",
		"primary":              "ALTER TABLE bill_participants DROP CONSTRAINT bill_participants_pkey;ALTER TABLE bill_participants ADD CONSTRAINT bill_participants_pkey PRIMARY KEY(person_id,bill_id)",
		"foreign":              "ALTER TABLE bill_items DROP CONSTRAINT fk_bills_items;ALTER TABLE bill_items ADD CONSTRAINT fk_bills_items FOREIGN KEY(bill_id) REFERENCES bills(id)",
		"foreign_schema":       "ALTER TABLE bill_items DROP CONSTRAINT fk_bills_items;CREATE TABLE unrelated_bills(id bigint PRIMARY KEY);INSERT INTO unrelated_bills VALUES(101);ALTER TABLE bill_items ADD CONSTRAINT fk_bills_items FOREIGN KEY(bill_id) REFERENCES unrelated_bills(id) ON DELETE CASCADE",
		"index":                "DROP INDEX idx_bills_access_token;CREATE INDEX idx_bills_access_token ON bills(access_token)",
		"index_column":         "DROP INDEX idx_bills_tab_id;CREATE INDEX idx_bills_tab_id ON bills(added_by_member_id)",
		"index_partial":        "DROP INDEX idx_bills_tab_id;CREATE INDEX idx_bills_tab_id ON bills(tab_id) WHERE tab_id>0",
		"index_expression":     "DROP INDEX idx_bills_tab_id;CREATE INDEX idx_bills_tab_id ON bills((tab_id+1))",
		"foreign_deferred":     "ALTER TABLE bill_items ALTER CONSTRAINT fk_bills_items DEFERRABLE INITIALLY DEFERRED",
		"index_opclass":        "DROP INDEX idx_bills_access_token;CREATE UNIQUE INDEX idx_bills_access_token ON bills(access_token varchar_pattern_ops)",
		"index_order":          "DROP INDEX idx_bills_tab_id;CREATE INDEX idx_bills_tab_id ON bills(tab_id DESC)",
		"sequence":             "ALTER SEQUENCE bills_id_seq INCREMENT BY 2",
		"sequence_exact_int64": "ALTER SEQUENCE bills_id_seq MAXVALUE 9223372036854775806",
		"sequence_owner":       "ALTER SEQUENCE bills_id_seq OWNED BY NONE",
		"sequence_default":     "ALTER TABLE bills ALTER COLUMN id SET DEFAULT nextval('tabs_id_seq')",
		"extra_column":         "ALTER TABLE bills ADD COLUMN surprise text",
		"extra_constraint":     "ALTER TABLE bills ADD CONSTRAINT surprise CHECK(total>0)",
		"extra_index":          "CREATE INDEX surprise ON bills(name)",
		"rls":                  "ALTER TABLE bills ENABLE ROW LEVEL SECURITY",
		"wrong_kind":           "DROP TABLE bill_participants;CREATE VIEW bill_participants AS SELECT id AS bill_id,id AS person_id FROM people",
	}
	for name, mutation := range cases {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			frozenLegacy(t, db)
			seedLegacy(t, db)
			execSQL(t, db, mutation)
			before := snapshot(t, db)
			s, err := Run(context.Background(), db, Apply)
			if err == nil || s != nil {
				t.Fatal("wrong schema adopted")
			}
			if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='schema_migrations'") != 0 {
				t.Fatal("failed adoption left ledger")
			}
			if before != snapshot(t, db) {
				t.Fatal("failed adoption changed rows")
			}
		})
	}
	t.Run("unrelated_objects", func(t *testing.T) {
		db := testpostgres.Open(t)
		frozenLegacy(t, db)
		execSQL(t, db, "CREATE TABLE unrelated_extension_table(id text);CREATE INDEX unrelated_extension_index ON unrelated_extension_table(id);CREATE SEQUENCE unrelated_extension_sequence")
		apply(t, db)
	})
	t.Run("unrelated_fresh", func(t *testing.T) {
		db := testpostgres.Open(t)
		execSQL(t, db, "CREATE TABLE unrelated_extension_table(id text)")
		apply(t, db)
	})
	t.Run("harmless_spelling_and_column_order", func(t *testing.T) {
		db := testpostgres.Open(t)
		frozenLegacy(t, db)
		execSQL(t, db, "ALTER TABLE bills ALTER COLUMN usd_exchange_rate SET DEFAULT (((1)));ALTER TABLE people RENAME COLUMN name TO old_name;ALTER TABLE people ADD COLUMN name text NOT NULL;ALTER TABLE people DROP COLUMN old_name")
		apply(t, db)
	})
	t.Run("same_name_foreign_table_in_other_schema", func(t *testing.T) {
		db, other := testpostgres.Open(t), testpostgres.Open(t)
		frozenLegacy(t, db)
		frozenLegacy(t, other)
		var schema string
		if err := other.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
			t.Fatal(err)
		}
		execSQL(t, db, "ALTER TABLE bill_items DROP CONSTRAINT fk_bills_items;ALTER TABLE bill_items ADD CONSTRAINT fk_bills_items FOREIGN KEY(bill_id) REFERENCES "+quote(schema)+".bills(id) ON DELETE CASCADE")
		if state, err := Run(context.Background(), db, Apply); err == nil || state != nil {
			t.Fatal("cross-schema FK adopted")
		}
	})

	t.Run("no_target", func(t *testing.T) {
		db := testpostgres.Open(t)
		execSQL(t, db, "SET search_path TO billington_nonexistent_schema")
		db.SetMaxOpenConns(1)
		if s, err := Run(context.Background(), db, Apply); err == nil || s != nil {
			t.Fatal("missing target accepted")
		}
	})
}

func TestPostgresHistoryAndCompatibility(t *testing.T) {
	cases := map[string]string{
		"checksum":            "UPDATE schema_migrations SET checksum=repeat('a',64)",
		"recognizer":          "UPDATE schema_migrations SET validation_checksum=repeat('a',64)",
		"epoch":               "UPDATE schema_migrations SET compatibility_epoch=2",
		"name":                "UPDATE schema_migrations SET name='0001_other.sql' WHERE version=1",
		"missing":             "DELETE FROM schema_migrations",
		"gap":                 "INSERT INTO schema_migrations VALUES(5,'0005_later.sql',repeat('a',64),repeat('b',64),1,now())",
		"later_epoch":         "INSERT INTO schema_migrations VALUES(4,'0004_later.sql',repeat('a',64),repeat('b',64),2,now())",
		"later_name":          "INSERT INTO schema_migrations VALUES(4,'garbage',repeat('a',64),repeat('b',64),1,now())",
		"ledger_definition":   "ALTER TABLE schema_migrations DROP CONSTRAINT schema_migrations_pkey",
		"baseline_definition": "ALTER TABLE bills ALTER COLUMN total DROP NOT NULL",
	}
	for name, mutation := range cases {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			s := apply(t, db)
			execSQL(t, db, mutation)
			for _, mode := range []Mode{Apply, Verify} {
				if next, err := Run(context.Background(), db, mode); err == nil || next != nil {
					t.Fatal("invalid history accepted")
				}
			}
			if name != "ledger_definition" && name != "baseline_definition" {
				if err := s.Check(context.Background()); err == nil {
					t.Fatal("invalid history ready")
				}
			}
		})
	}
	t.Run("compatible_additive_prefix", func(t *testing.T) {
		db := testpostgres.Open(t)
		s := apply(t, db)
		execSQL(t, db, "ALTER TABLE bills ADD COLUMN future_receipt_metadata text;INSERT INTO schema_migrations VALUES(4,'0004_future.sql',repeat('a',64),repeat('b',64),1,now())")
		if _, err := Run(context.Background(), db, Verify); err != nil {
			t.Fatal(err)
		}
		apply(t, db)
		if err := s.Check(context.Background()); err != nil {
			t.Fatal(err)
		}
		if scalar(t, db, "SELECT max(version) FROM schema_migrations") != 4 {
			t.Fatal("older binary downgraded ledger")
		}
	})
	t.Run("verify_empty_no_writes", func(t *testing.T) {
		db := testpostgres.Open(t)
		if s, err := Run(context.Background(), db, Verify); err == nil || s != nil {
			t.Fatal("uninitialized verify ready")
		}
		if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace") != 0 {
			t.Fatal("verify wrote schema")
		}
	})
}

func TestPostgresReadinessBoundsAndUnavailable(t *testing.T) {
	db := testpostgres.Open(t)
	s := apply(t, db)
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	if _, err = tx.Exec("LOCK TABLE schema_migrations IN ACCESS EXCLUSIVE MODE"); err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	err = s.Check(context.Background())
	if !errors.Is(err, context.DeadlineExceeded) || time.Since(start) > 3*time.Second {
		t.Fatal("health deadline not enforced", err)
	}
	tx.Rollback()
	db.Close()
	if s.Check(context.Background()) == nil {
		t.Fatal("closed database ready")
	}
	var empty *State
	if empty.Check(context.Background()) == nil {
		t.Fatal("unvalidated startup ready")
	}
}

func TestPostgresErrorsAreSanitized(t *testing.T) {
	db := testpostgres.Open(t)
	frozenLegacy(t, db)
	execSQL(t, db, "ALTER TABLE bills ALTER COLUMN total SET DEFAULT 123456789")
	_, err := Run(context.Background(), db, Apply)
	b, _ := json.Marshal(err)
	if err == nil || strings.Contains(err.Error(), "123456789") || strings.Contains(string(b), "123456789") {
		t.Fatal("catalog details leaked")
	}
}
