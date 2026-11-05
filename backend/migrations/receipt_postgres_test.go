//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"fmt"
	"strings"
	"testing"
)

func TestPostgresReceiptExpansionFromOnePreservesRowOneAndData(t *testing.T) {
	db := testpostgres.Open(t)
	steps, err := Registry()
	if err != nil {
		t.Fatal(err)
	}
	if _, err = run(context.Background(), db, Apply, steps[:1]); err != nil {
		t.Fatal(err)
	}
	seedLegacy(t, db)
	before := snapshot(t, db)
	var row1 string
	if err := db.QueryRow("SELECT to_jsonb(m)::text FROM schema_migrations m WHERE version=1").Scan(&row1); err != nil {
		t.Fatal(err)
	}
	if s, err := Run(context.Background(), db, Verify); s != nil || err == nil {
		t.Fatal("pending required2 verified")
	}
	if _, err = Run(context.Background(), db, Apply); err != nil {
		t.Fatal(err)
	}
	var after string
	if err := db.QueryRow("SELECT to_jsonb(m)::text FROM schema_migrations m WHERE version=1").Scan(&after); err != nil {
		t.Fatal(err)
	}
	if row1 != after || before != snapshot(t, db) || scalar(t, db, "SELECT count(*) FROM schema_migrations") != 3 {
		t.Fatal("expansion rewrote row1/legacy data")
	}
	if scalar(t, db, "SELECT count(*) FROM bills WHERE creation_key_digest IS NOT NULL OR creation_fingerprint IS NOT NULL OR creation_fingerprint_version IS NOT NULL OR display_rate_date IS NOT NULL OR display_rate_source IS NOT NULL OR display_rate_retrieved_at IS NOT NULL") != 0 {
		t.Fatal("metadata backfill")
	}
	// Exact old-prefix behavior is also exercised with retained old binaries by
	// external qualification. This source-only test does not substitute for it.
	if s, err := run(context.Background(), db, Verify, steps[:1]); err != nil || s.Check(context.Background()) != nil {
		t.Fatal("old prefix rejected actual nine additions")
	}
}
func TestPostgresReceiptEveryCatalogAdditionAndEnforcementDrift(t *testing.T) {
	changes := map[string]string{
		"replay_check_missing":      "ALTER TABLE bills DROP CONSTRAINT bills_creation_replay_shape",
		"replay_check_weakened":     "ALTER TABLE bills DROP CONSTRAINT bills_creation_replay_shape;ALTER TABLE bills ADD CONSTRAINT bills_creation_replay_shape CHECK(creation_key_digest IS NULL OR octet_length(creation_key_digest)=32)",
		"replay_check_unvalidated":  "ALTER TABLE bills DROP CONSTRAINT bills_creation_replay_shape;ALTER TABLE bills ADD CONSTRAINT bills_creation_replay_shape CHECK(creation_key_digest IS NULL) NOT VALID",
		"display_check_missing":     "ALTER TABLE bills DROP CONSTRAINT bills_display_rate_shape",
		"display_check_weakened":    "ALTER TABLE bills DROP CONSTRAINT bills_display_rate_shape;ALTER TABLE bills ADD CONSTRAINT bills_display_rate_shape CHECK(display_rate_source IS NULL OR display_total IS NOT NULL)",
		"display_check_unvalidated": "ALTER TABLE bills DROP CONSTRAINT bills_display_rate_shape;ALTER TABLE bills ADD CONSTRAINT bills_display_rate_shape CHECK(display_rate_source IS NULL) NOT VALID",
		"index_missing":             "DROP INDEX idx_bills_creation_key_digest",
		"index_not_unique":          "DROP INDEX idx_bills_creation_key_digest;CREATE INDEX idx_bills_creation_key_digest ON bills(creation_key_digest)",
		"index_wrong_key":           "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills(creation_fingerprint)",
		"index_partial":             "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills(creation_key_digest) WHERE creation_key_digest IS NOT NULL",
		"index_expression":          "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills((encode(creation_key_digest,'hex')))",
		"index_include":             "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills(creation_key_digest) INCLUDE(id)",
		"index_nulls_equal":         "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills(creation_key_digest) NULLS NOT DISTINCT",
		"index_desc":                "DROP INDEX idx_bills_creation_key_digest;CREATE UNIQUE INDEX idx_bills_creation_key_digest ON bills(creation_key_digest DESC)",
		"extra_known_object":        "ALTER TABLE bills ADD COLUMN unapproved text",
	}
	for _, flag := range []string{"indimmediate", "indisvalid", "indisready", "indislive"} {
		changes["index_flag_"+flag] = "UPDATE pg_index SET " + flag + "=false WHERE indexrelid='idx_bills_creation_key_digest'::regclass"
	}
	for _, column := range []string{"creation_key_digest", "creation_fingerprint", "creation_fingerprint_version", "display_rate_date", "display_rate_source", "display_rate_retrieved_at"} {
		changes["column_missing_"+column] = "ALTER TABLE bills DROP COLUMN " + column + " CASCADE"
		// Defaults alone change all six independently, without needing to break CHECKs.
		value := "NULL"
		switch column {
		case "creation_key_digest", "creation_fingerprint":
			value = "decode(repeat('aa',32),'hex')"
		case "creation_fingerprint_version":
			value = "1"
		case "display_rate_date":
			value = "'2026-11-04'"
		case "display_rate_source":
			value = "'synthetic'"
		case "display_rate_retrieved_at":
			value = "now()"
		}
		changes["column_default_"+column] = "ALTER TABLE bills ALTER COLUMN " + column + " SET DEFAULT " + value
	}
	for name, sql := range changes {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			apply(t, db)
			before := snapshot(t, db)
			history := catalogSafetyHistory(t, db)
			execSQL(t, db, sql)
			for _, mode := range []Mode{Apply, Verify} {
				if s, err := Run(context.Background(), db, mode); err == nil || s != nil {
					t.Fatal("weak/partial known0002 catalog accepted")
				}
			}
			if before != snapshot(t, db) || history != catalogSafetyHistory(t, db) {
				t.Fatal("rejected known0002 changed rows/ledger")
			}
		})
	}
}
func TestPostgresReceiptConstraintsEnforcePartialNullAndFiniteShape(t *testing.T) {
	invalid := map[string]string{
		"key_only":                "creation_key_digest=decode(repeat('aa',32),'hex')",
		"fingerprint_only":        "creation_fingerprint=decode(repeat('bb',32),'hex')",
		"version_only":            "creation_fingerprint_version=1",
		"short_digest":            "creation_key_digest=decode('aa','hex'),creation_fingerprint=decode(repeat('bb',32),'hex'),creation_fingerprint_version=1",
		"short_fingerprint":       "creation_key_digest=decode(repeat('aa',32),'hex'),creation_fingerprint=decode('bb','hex'),creation_fingerprint_version=1",
		"zero_version":            "creation_key_digest=decode(repeat('aa',32),'hex'),creation_fingerprint=decode(repeat('bb',32),'hex'),creation_fingerprint_version=0",
		"display_partial_source":  "display_rate_source='synthetic'",
		"display_partial_date":    "display_rate_date='2026-11-04'",
		"display_partial_receipt": "display_rate_retrieved_at=now()",
		"same_wrong_total":        "display_rate_source='same_currency',display_total=99",
		"same_foreign_pair":       "display_rate_source='same_currency',display_total=total,display_currency='EUR'",
		"same_invented_date":      "display_rate_source='same_currency',display_total=total,display_rate_date='2026-11-04'",
		"same_wrong_rate":         "display_rate_source='same_currency',display_total=total,exchange_rate=2",
	}
	foreign := "currency_code='EUR',display_currency='USD',display_total=12,exchange_rate=1.2,display_rate_date='2026-11-04',display_rate_source='synthetic',display_rate_retrieved_at=now()"
	for name, replace := range map[string]string{"zero_rate": "exchange_rate=0", "negative_rate": "exchange_rate=-1", "infinite_rate": "exchange_rate='Infinity'::numeric", "infinite_time": "display_rate_retrieved_at='Infinity'::timestamptz", "space_source": "display_rate_source=' synthetic '", "long_source": "display_rate_source=repeat('x',65)", "bad_lexical_date": "display_rate_date='2026-1-01'"} {
		invalid[name] = foreign + "," + replace
	}
	// Build assignments through a map to replace values (SQL cannot assign a column twice).
	for name, assignments := range invalid {
		t.Run(name, func(t *testing.T) {
			db := testpostgres.Open(t)
			apply(t, db)
			execSQL(t, db, `INSERT INTO bills(name,subtotal,tax,tip_amount,total,date) VALUES('Receipt',10,0,0,10,now())`)
			// For foreign variants the replacement is separated by the last comma.
			if len(assignments) > len(foreign) && assignments[:len(foreign)] == foreign {
				// JSON here is only a finite test-side literal map, never fingerprint input.
				last := assignments[len(foreign)+1:]
				key := last[:strings.IndexByte(last, '=')]
				parts := splitAssignments(foreign)
				for i, p := range parts {
					if p[:strings.IndexByte(p, '=')] == key {
						parts[i] = last
					}
				}
				assignments = strings.Join(parts, ",")
			}
			if _, err := db.Exec("UPDATE bills SET " + assignments); err == nil {
				t.Fatal("invalid metadata accepted by PostgreSQL CHECK")
			}
		})
	}
}
func splitAssignments(s string) []string {
	var out []string
	start := 0
	quoted := false
	depth := 0
	for i, c := range s {
		switch c {
		case '\'':
			quoted = !quoted
		case '(':
			if !quoted {
				depth++
			}
		case ')':
			if !quoted {
				depth--
			}
		case ',':
			if !quoted && depth == 0 {
				out = append(out, s[start:i])
				start = i + 1
			}
		}
	}
	return append(out, s[start:])
}
func TestPostgresReceiptUnknownSuffixDoesNotHideKnownDrift(t *testing.T) {
	db := testpostgres.Open(t)
	apply(t, db)
	execSQL(t, db, fmt.Sprintf("INSERT INTO schema_migrations VALUES(4,'0004_future.sql','%s','%s',1,now())", checksum("future"), checksum("future validation")))
	execSQL(t, db, "DROP INDEX idx_bills_creation_key_digest")
	if s, err := Run(context.Background(), db, Verify); s != nil || err == nil {
		t.Fatal("unknown suffix concealed missing known index")
	}
}
