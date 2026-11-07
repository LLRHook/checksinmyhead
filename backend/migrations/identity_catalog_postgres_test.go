//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func TestPostgresIdentity0003EveryCatalogAddition(t *testing.T) {
	var additions catalogObjects
	if err := json.Unmarshal([]byte(identityManifest), &additions); err != nil {
		t.Fatal(err)
	}
	changes := map[string]string{}
	for key := range additions {
		p := strings.Split(key, "/")
		switch p[0] {
		case "column":
			changes[key] = "ALTER TABLE " + quote(p[1]) + " DROP COLUMN " + quote(p[2]) + " CASCADE"
		case "constraint":
			changes[key] = "ALTER TABLE " + quote(p[1]) + " DROP CONSTRAINT " + quote(p[2]) + " CASCADE"
		case "index":
			if _, backing := additions["constraint/"+p[1]+"/"+p[2]]; !backing {
				changes[key] = "DROP INDEX " + quote(p[2])
			}
		case "relation":
			changes[key] = "DROP SEQUENCE bill_participants_id_seq CASCADE"
		case "sequence":
			changes[key] = "ALTER SEQUENCE bill_participants_id_seq INCREMENT BY 2"
		default:
			t.Fatalf("unclassified v3 capture key %s", key)
		}
	}
	for key, sql := range map[string]string{
		"sequence/type":                 "ALTER SEQUENCE bill_participants_id_seq AS integer",
		"sequence/start":                "ALTER SEQUENCE bill_participants_id_seq START WITH 2",
		"sequence/owner":                "ALTER SEQUENCE bill_participants_id_seq OWNED BY NONE",
		"sequence/wrong_owner":          "ALTER SEQUENCE bill_participants_id_seq OWNED BY people.id",
		"sequence/max_exact_int64":      "ALTER SEQUENCE bill_participants_id_seq MAXVALUE 9223372036854775806",
		"sequence/cycle":                "ALTER SEQUENCE bill_participants_id_seq CYCLE",
		"sequence/cache":                "ALTER SEQUENCE bill_participants_id_seq CACHE 2",
		"participant/id_type":           "ALTER TABLE bill_participants ALTER COLUMN id TYPE integer",
		"participant/id_default":        "ALTER TABLE bill_participants ALTER COLUMN id SET DEFAULT nextval('people_id_seq')",
		"participant/id_nullable":       "ALTER TABLE bill_participants ALTER COLUMN id DROP NOT NULL",
		"participant/version_default":   "ALTER TABLE bill_participants ALTER COLUMN identity_version SET DEFAULT 2",
		"participant/label_default":     "ALTER TABLE bill_participants ALTER COLUMN label SET DEFAULT 'changed'",
		"bill/state_default":            "ALTER TABLE bills ALTER COLUMN identity_state SET DEFAULT 'ready'",
		"bill/revision_default":         "ALTER TABLE bills ALTER COLUMN identity_revision SET DEFAULT 1",
		"participant/fk_deferred":       "ALTER TABLE bill_participants ALTER CONSTRAINT bill_participants_receipt_actor_tab_fk DEFERRABLE INITIALLY DEFERRED",
		"participant/fk_action":         "ALTER TABLE bill_participants DROP CONSTRAINT bill_participants_receipt_actor_tab_fk;ALTER TABLE bill_participants ADD CONSTRAINT bill_participants_receipt_actor_tab_fk FOREIGN KEY(last_binding_actor_member_id,tab_id) REFERENCES tab_members(id,tab_id) ON DELETE CASCADE",
		"participant/check_weak":        "ALTER TABLE bill_participants DROP CONSTRAINT bill_participants_receipt_shape;ALTER TABLE bill_participants ADD CONSTRAINT bill_participants_receipt_shape CHECK(last_binding_result_revision IS NULL OR last_binding_result_revision>0)",
		"participant/check_unvalidated": "ALTER TABLE bill_participants DROP CONSTRAINT bill_participants_receipt_shape;ALTER TABLE bill_participants ADD CONSTRAINT bill_participants_receipt_shape CHECK(last_binding_result_revision IS NULL OR last_binding_result_revision>0) NOT VALID",
		"participant/index_weak":        "DROP INDEX idx_bill_participants_client_ref;CREATE INDEX idx_bill_participants_client_ref ON bill_participants(bill_id,client_ref) WHERE client_ref IS NOT NULL",
		"participant/index_predicate":   "DROP INDEX idx_bill_participants_client_ref;CREATE UNIQUE INDEX idx_bill_participants_client_ref ON bill_participants(bill_id,client_ref)",
		"participant/index_wrong_key":   "DROP INDEX idx_bill_participants_client_ref;CREATE UNIQUE INDEX idx_bill_participants_client_ref ON bill_participants(bill_id,label) WHERE client_ref IS NOT NULL",
		"unknown_column":                "ALTER TABLE bill_participants ADD COLUMN unapproved text",
		"internal_fk_disabled":          "ALTER TABLE ONLY bill_participants DISABLE TRIGGER ALL",
		"internal_fk_replica":           "DO $$ DECLARE tr text; BEGIN FOR tr IN SELECT tgname FROM pg_trigger WHERE tgrelid='bill_participants'::regclass AND tgisinternal LOOP EXECUTE format('ALTER TABLE ONLY bill_participants ENABLE REPLICA TRIGGER %I',tr); END LOOP; END $$",
		"inheritance":                   "CREATE TABLE unapproved_participants() INHERITS(bill_participants)",
	} {
		changes[key] = sql
	}
	for name, sql := range changes {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			apply(t, db)
			seedLegacy(t, db)
			execSQL(t, db, sql)
			before := identityRows(t, db)
			for _, mode := range []Mode{Apply, Verify} {
				if s, err := Run(context.Background(), db, mode); err == nil || s != nil {
					t.Fatal("partial/changed v3 catalog accepted")
				}
			}
			if before != identityRows(t, db) {
				t.Fatal("rejection changed rows/history")
			}
		})
	}
}
func TestPostgresIdentity0003KnownPrefixesAndFuture(t *testing.T) {
	steps, err := Registry()
	if err != nil {
		t.Fatal(err)
	}
	for _, prefix := range []int{1, 2, 3} {
		t.Run(string(rune('0'+prefix)), func(t *testing.T) {
			db := testpostgres.Open(t)
			if _, err := run(context.Background(), db, Apply, steps[:prefix]); err != nil {
				t.Fatal(err)
			}
			execSQL(t, db, "ALTER TABLE bills ADD COLUMN unapproved text")
			for _, mode := range []Mode{Apply, Verify} {
				if s, err := run(context.Background(), db, mode, steps[:prefix]); s != nil || err == nil {
					t.Fatal("known prefix ignored extras")
				}
			}
		})
	}
	db := testpostgres.Open(t)
	apply(t, db)
	seedLegacy(t, db)
	for _, prefix := range []int{1, 2, 3} {
		if s, err := run(context.Background(), db, Verify, steps[:prefix]); err != nil || s.Check(context.Background()) != nil {
			t.Fatal("compatible actual known prefix rejected")
		}
	}
	execSQL(t, db, "ALTER TABLE bills ADD COLUMN future_identity_metadata text;INSERT INTO schema_migrations VALUES(4,'0004_future.sql',repeat('a',64),repeat('b',64),1,now())")
	before := identityRows(t, db)
	for _, mode := range []Mode{Apply, Verify} {
		if _, err := Run(context.Background(), db, mode); err != nil {
			t.Fatal(err)
		}
	}
	if before != identityRows(t, db) {
		t.Fatal("future suffix rewritten")
	}
	execSQL(t, db, "ALTER SEQUENCE bill_participants_id_seq OWNED BY NONE")
	if s, err := Run(context.Background(), db, Verify); s != nil || err == nil {
		t.Fatal("unknown suffix hid known sequence drift")
	}
}
func TestPostgresIdentity0003SupplementalDuplicateKeys(t *testing.T) {
	db := testpostgres.Open(t)
	apply(t, db)
	var schema string
	if err := db.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
		t.Fatal(err)
	}
	old := identityCatalogSQL
	defer func() { identityCatalogSQL = old }()
	identityCatalogSQL = catalogSQL
	if _, err := catalog(context.Background(), db, schema); err == nil || err.Error() != "duplicate catalog object" {
		t.Fatal("duplicate supplemental catalog keys accepted", err)
	}
}
