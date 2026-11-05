//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"
)

func TestPostgresIdentity0003DefaultsRemainLegacy(t *testing.T) {
	db := testpostgres.Open(t)
	apply(t, db)
	seedLegacy(t, db)
	if scalar(t, db, "SELECT count(*) FROM bills WHERE identity_version=1 AND identity_state='legacy_review' AND identity_revision=0 AND creation_response_version IS NULL AND creation_response IS NULL") != 3 {
		t.Fatal("default application writes must remain graph1/review without response2")
	}
	if scalar(t, db, "SELECT count(*) FROM bill_participants WHERE id IS NOT NULL AND identity_version=1 AND label='' AND allocation_label='' AND ordinal IS NULL AND member_id IS NULL AND pending_member_id IS NULL AND last_binding_member_id IS NULL") != 1 {
		t.Fatal("new legacy join inferred an identity")
	}
}

// Preserve original rows and ledger timestamps through actual legacy/prefix1/2
// upgrade, then compare the COMPLETE new rows on retries (including structural IDs).
func TestPostgresIdentity0003UpgradePreservation(t *testing.T) {
	for _, prefix := range []int{0, 1, 2} {
		t.Run(fmt.Sprintf("prefix%d", prefix), func(t *testing.T) {
			db := testpostgres.Open(t)
			steps, err := Registry()
			if err != nil {
				t.Fatal(err)
			}
			if prefix == 0 {
				frozenLegacy(t, db)
			} else if _, err := run(context.Background(), db, Apply, steps[:prefix]); err != nil {
				t.Fatal(err)
			}
			seedLegacy(t, db)
			execSQL(t, db, `INSERT INTO people(id,name) VALUES (82,''),(83,repeat('界',40)),(84,'Alex');
    INSERT INTO bill_participants(bill_id,person_id) VALUES (101,84),(101,83),(101,82);
    INSERT INTO tab_settlements(id,tab_id,person_name,amount,paid,created_at) VALUES (132,41,'',0,false,'2025-01-01Z'),(133,41,'Alex',0,false,'2025-01-01Z')`)
			before := snapshot(t, db)
			history := catalogSafetyHistory(t, db)
			apply(t, db)
			if before != snapshot(t, db) {
				t.Fatal("0003 rewrote original values")
			}
			if prefix > 0 {
				var old string
				if err := db.QueryRow("SELECT jsonb_agg(to_jsonb(x) ORDER BY version)::text FROM schema_migrations x WHERE version<=$1", prefix).Scan(&old); err != nil {
					t.Fatal(err)
				}
				if old != history {
					t.Fatal("0003 rewrote applied history")
				}
			}
			if scalar(t, db, `SELECT count(*) FROM bill_participants p JOIN people person ON p.person_id=person.id JOIN bills b ON b.id=p.bill_id WHERE p.label=person.name AND p.allocation_label=person.name AND p.tab_id=b.tab_id AND p.identity_version=1 AND p.client_ref IS NULL AND p.member_id IS NULL AND p.pending_member_id IS NULL AND p.last_binding_member_id IS NULL`) != 4 {
				t.Fatal("structural backfill inferred/truncated identity")
			}
			if scalar(t, db, `SELECT count(*) FROM (SELECT ordinal,person_id,row_number() OVER (PARTITION BY bill_id ORDER BY person_id)-1 expected FROM bill_participants) p WHERE ordinal=expected`) != 4 {
				t.Fatal("structural ordinal order")
			}
			if scalar(t, db, `SELECT count(*) FROM item_assignments a JOIN bill_items i ON i.id=a.bill_item_id WHERE a.bill_id=i.bill_id AND a.participant_id IS NULL AND a.identity_version=1`) != 1 {
				t.Fatal("child backfill")
			}
			if scalar(t, db, `SELECT count(*) FROM person_shares WHERE identity_version=1 AND participant_id IS NULL`) != 1 || scalar(t, db, `SELECT count(*) FROM tab_settlements WHERE snapshot_version=1 AND member_id IS NULL AND participant_id IS NULL`) != 3 {
				t.Fatal("legacy references inferred")
			}
			whole := identityRows(t, db)
			for _, mode := range []Mode{Apply, Verify} {
				if _, err := Run(context.Background(), db, mode); err != nil {
					t.Fatal(err)
				}
				if whole != identityRows(t, db) {
					t.Fatal("retry changed complete rows/ledger")
				}
			}
			if scalar(t, db, "SELECT count(DISTINCT id) FROM bill_participants") != 4 || scalar(t, db, "SELECT last_value FROM bills_id_seq") != 501 {
				t.Fatal("identity/old sequence preservation")
			}
		})
	}
}

func identityRows(t *testing.T, db *sql.DB) string {
	t.Helper()
	var rows []string
	for _, table := range []string{"tabs", "tab_members", "bills", "bill_items", "people", "bill_participants", "item_assignments", "person_shares", "tab_settlements", "schema_migrations"} {
		var s string
		if err := db.QueryRow("SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]')::text FROM " + table + " x").Scan(&s); err != nil {
			t.Fatal(err)
		}
		rows = append(rows, s)
	}
	return strings.Join(rows, "\n")
}
func identityFixture(t *testing.T) *sql.DB {
	t.Helper()
	db := testpostgres.Open(t)
	apply(t, db)
	seedLegacy(t, db)
	execSQL(t, db, `INSERT INTO tab_members(id,tab_id,display_name) VALUES (73,41,'Alex'),(74,41,'Alex'),(75,42,'Alex');
 INSERT INTO bills(id,tab_id,name,subtotal,tax,tip_amount,total,date) VALUES (104,42,'Other',1,0,0,1,now());
 INSERT INTO people(id,name) VALUES (201,''),(202,'Alex'),(203,'Alex'),(204,'Alex');
 INSERT INTO bill_participants(id,bill_id,person_id,label,allocation_label,identity_version,ordinal,client_ref,tab_id) VALUES
 (601,101,201,'','Alex',2,10,'p1',41),(602,101,202,'Alex','Alex',2,11,'p2',41),
 (603,104,203,'Alex','Alex',2,10,'p1',42),(604,102,204,'Alex','Alex',2,10,'p1',41);
 UPDATE item_assignments SET bill_id=101 WHERE id=111`)
	return db
}
func identityReject(t *testing.T, db *sql.DB, sql, state string) {
	t.Helper()
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	_, err = tx.Exec(sql)
	var violation interface{ SQLState() string }
	if !errors.As(err, &violation) || violation.SQLState() != state {
		t.Fatalf("want SQLSTATE %s, got %v", state, err)
	}
}

const identityReceipt = "last_binding_member_id=73,last_binding_request_revision=1,last_binding_decision='reject',last_binding_actor_member_id=74,last_binding_actor_kind='source',last_binding_result_revision=2,last_binding_decided_at='2026-11-05Z'"
const identityPending = "pending_member_id=73,requested_at='2026-11-05Z',pending_request_revision=3"
const identityBinding = "member_id=73,approved_by_member_id=74,approval_kind='creator',approved_at='2026-11-05Z'"

func TestPostgresIdentity0003NullSafeGroups(t *testing.T) {
	db := identityFixture(t)
	for _, group := range []struct{ name, assignments string }{{"pending", identityPending}, {"binding", identityBinding}, {"receipt", identityReceipt}} {
		parts := splitAssignments(group.assignments)
		for mask := 1; mask < (1<<len(parts))-1; mask++ {
			t.Run(fmt.Sprintf("%s/partial_%d", group.name, mask), func(t *testing.T) {
				var assignments []string
				for i, p := range parts {
					if mask&(1<<i) != 0 {
						assignments = append(assignments, p)
					}
				}
				identityReject(t, db, "UPDATE bill_participants SET "+strings.Join(assignments, ",")+" WHERE id=601", "23514")
			})
		}
		for _, scope := range []string{"identity_version=1", "tab_id=NULL"} {
			t.Run(group.name+"/"+scope, func(t *testing.T) {
				identityReject(t, db, "UPDATE bill_participants SET "+group.assignments+","+scope+" WHERE id=601", "23514")
			})
		}
	}
	for name, assign := range map[string]string{
		"pending_zero":         "pending_member_id=73,requested_at=now(),pending_request_revision=0",
		"pending_negative":     "pending_member_id=73,requested_at=now(),pending_request_revision=-1",
		"receipt_zero":         "last_binding_member_id=73,last_binding_request_revision=0,last_binding_decision='approve',last_binding_actor_member_id=74,last_binding_actor_kind='creator',last_binding_result_revision=2,last_binding_decided_at=now()",
		"receipt_equal":        "last_binding_member_id=73,last_binding_request_revision=2,last_binding_decision='approve',last_binding_actor_member_id=74,last_binding_actor_kind='creator',last_binding_result_revision=2,last_binding_decided_at=now()",
		"receipt_reversed":     "last_binding_member_id=73,last_binding_request_revision=3,last_binding_decision='approve',last_binding_actor_member_id=74,last_binding_actor_kind='creator',last_binding_result_revision=2,last_binding_decided_at=now()",
		"receipt_bad_decision": strings.Replace(identityReceipt, "'reject'", "'unknown'", 1),
		"receipt_bad_actor":    strings.Replace(identityReceipt, "'source'", "'unknown'", 1),
		"binding_bad_kind":     strings.Replace(identityBinding, "'creator'", "'unknown'", 1),
		"bound_and_pending":    identityBinding + "," + identityPending,
	} {
		t.Run(name, func(t *testing.T) {
			identityReject(t, db, "UPDATE bill_participants SET "+assign+" WHERE id=601", "23514")
		})
	}
	// A fresh pending generation coexists with retained last receipt; neither SQL
	// nor triggers invent a cross-table bill revision check. B must validate locked.
	execSQL(t, db, "UPDATE bill_participants SET "+identityReceipt+","+identityPending+" WHERE id=601")
	if scalar(t, db, "SELECT count(*) FROM bill_participants WHERE id=601 AND pending_request_revision=3 AND last_binding_result_revision=2") != 1 {
		t.Fatal("receipt lost when pending")
	}
	execSQL(t, db, "UPDATE bill_participants SET pending_member_id=NULL,requested_at=NULL,pending_request_revision=NULL WHERE id=601")
	for _, id := range []int{73, 74} {
		t.Run(fmt.Sprintf("retained_member_%d", id), func(t *testing.T) {
			identityReject(t, db, fmt.Sprintf("DELETE FROM tab_members WHERE id=%d", id), "23503")
			identityReject(t, db, fmt.Sprintf("UPDATE tab_members SET id=id+10000 WHERE id=%d", id), "23503")
		})
	}
}
func TestPostgresIdentity0003VersionLabelsResponse(t *testing.T) {
	db := identityFixture(t)
	for name, assign := range map[string]string{"version0": "identity_version=0", "version3": "identity_version=3", "wrong1": "identity_state='ready'", "wrong2": "identity_version=2", "unknown_state": "identity_state='other'", "negative_revision": "identity_revision=-1", "response_version_only": "creation_response_version=2", "response_body_only": "creation_response=decode('01','hex')", "response_unknown": "creation_response_version=3,creation_response=decode('01','hex')", "response_old": "creation_response_version=1,creation_response=decode('01','hex')", "response_empty": "creation_response_version=2,creation_response=''::bytea", "response_large": "creation_response_version=2,creation_response=decode(repeat('ab',65537),'hex')"} {
		t.Run("bill/"+name, func(t *testing.T) { identityReject(t, db, "UPDATE bills SET "+assign+" WHERE id=101", "23514") })
	}
	for _, n := range []int{1, 65536} {
		execSQL(t, db, "UPDATE bills SET creation_response_version=2,creation_response=decode(repeat('ab',$1),'hex') WHERE id=101", n)
	}
	execSQL(t, db, "UPDATE bills SET creation_response_version=NULL,creation_response=NULL,identity_version=2,identity_state='ready',identity_revision=9223372036854775807 WHERE id=101")
	for name, assign := range map[string]string{"version0": "identity_version=0", "version3": "identity_version=3", "missing_ordinal": "ordinal=NULL", "negative_ordinal": "ordinal=-1", "long_label": "label=repeat('界',31)", "long_allocation": "allocation_label=repeat('界',31)", "empty_ref": "client_ref=''", "nonascii_ref": "client_ref='é'", "space_ref": "client_ref='a b'", "newline_ref": "client_ref=E'a\\n'", "punctuation_ref": "client_ref='a.'"} {
		t.Run("participant/"+name, func(t *testing.T) {
			identityReject(t, db, "UPDATE bill_participants SET "+assign+" WHERE id=601", "23514")
		})
	}
	identityReject(t, db, "UPDATE bill_participants SET client_ref=repeat('x',65) WHERE id=601", "22001")
	execSQL(t, db, "UPDATE bill_participants SET label=repeat('界',30),allocation_label='',client_ref=repeat('Z',62)||'_-' WHERE id=601")
	execSQL(t, db, "UPDATE bill_participants SET label='',allocation_label='' WHERE id IN(601,602)")
	execSQL(t, db, "UPDATE bill_participants SET label=repeat('界',100),allocation_label=repeat('界',100) WHERE identity_version=1")
	if scalar(t, db, "SELECT count(*) FROM bills WHERE id=101 AND creation_key_digest IS NULL AND identity_revision=9223372036854775807") != 1 {
		t.Fatal("response conflated graph/fingerprint or revision auto-mutated")
	}
}
func TestPostgresIdentity0003ScopedReferencesAndUniqueness(t *testing.T) {
	db := identityFixture(t)
	bad := map[string]string{
		"participant_tab":             "UPDATE bill_participants SET tab_id=42 WHERE id=601",
		"pending_tab":                 "UPDATE bill_participants SET " + strings.Replace(identityPending, "=73", "=75", 1) + " WHERE id=601",
		"binding_member_tab":          "UPDATE bill_participants SET " + strings.Replace(identityBinding, "=73", "=75", 1) + " WHERE id=601",
		"binding_actor_tab":           "UPDATE bill_participants SET " + strings.Replace(identityBinding, "=74", "=75", 1) + " WHERE id=601",
		"receipt_member_tab":          "UPDATE bill_participants SET " + strings.Replace(identityReceipt, "=73", "=75", 1) + " WHERE id=601",
		"receipt_actor_tab":           "UPDATE bill_participants SET " + strings.Replace(identityReceipt, "=74", "=75", 1) + " WHERE id=601",
		"assignment_item_bill":        "UPDATE item_assignments SET identity_version=2,participant_id=604,bill_id=102 WHERE id=111",
		"assignment_participant_bill": "UPDATE item_assignments SET identity_version=2,participant_id=604 WHERE id=111",
		"share_participant_bill":      "UPDATE person_shares SET identity_version=2,participant_id=604 WHERE id=121",
		"settlement_member_tab":       "UPDATE tab_settlements SET snapshot_version=2,member_id=75 WHERE id=131",
		"settlement_participant_tab":  "UPDATE tab_settlements SET snapshot_version=2,participant_id=603 WHERE id=131",
	}
	for name, sql := range bad {
		t.Run(name, func(t *testing.T) { identityReject(t, db, sql, "23503") })
	}
	for name, sql := range map[string]string{
		"assignment_v1_ref":     "UPDATE item_assignments SET participant_id=601 WHERE id=111",
		"assignment_v2_no_ref":  "UPDATE item_assignments SET identity_version=2 WHERE id=111",
		"assignment_v2_no_bill": "UPDATE item_assignments SET identity_version=2,participant_id=601,bill_id=NULL WHERE id=111",
		"assignment_version":    "UPDATE item_assignments SET identity_version=3 WHERE id=111",
		"share_v1_ref":          "UPDATE person_shares SET participant_id=601 WHERE id=121",
		"share_v2_no_ref":       "UPDATE person_shares SET identity_version=2 WHERE id=121",
		"share_version":         "UPDATE person_shares SET identity_version=0 WHERE id=121",
		"snapshot_v1_ref":       "UPDATE tab_settlements SET member_id=73 WHERE id=131",
		"snapshot_v2_no_ref":    "UPDATE tab_settlements SET snapshot_version=2 WHERE id=131",
		"snapshot_v2_two_refs":  "UPDATE tab_settlements SET snapshot_version=2,member_id=73,participant_id=601 WHERE id=131",
		"snapshot_version":      "UPDATE tab_settlements SET snapshot_version=3 WHERE id=131",
	} {
		t.Run(name, func(t *testing.T) { identityReject(t, db, sql, "23514") })
	}
	for name, sql := range map[string]string{
		"client_ref":        "UPDATE bill_participants SET client_ref='p1' WHERE id=602",
		"ordinal":           "UPDATE bill_participants SET ordinal=10 WHERE id=602",
		"id":                "UPDATE bill_participants SET id=601 WHERE id=602",
		"pending":           "UPDATE bill_participants SET " + identityPending + " WHERE id IN(601,602)",
		"member":            "UPDATE bill_participants SET " + identityBinding + " WHERE id IN(601,602)",
		"assignment":        "INSERT INTO item_assignments(bill_item_id,person_name,percentage,identity_version,participant_id,bill_id) VALUES(91,'',10,2,601,101),(91,'',10,2,601,101)",
		"share":             "INSERT INTO person_shares(bill_id,person_name,subtotal,tax_share,tip_share,total,identity_version,participant_id) VALUES(101,'',0,0,0,0,2,601),(101,'',0,0,0,0,2,601)",
		"settlement_member": "INSERT INTO tab_settlements(tab_id,person_name,amount,snapshot_version,member_id) VALUES(41,'',0,2,73),(41,'',0,2,73)",
		"settlement_guest":  "INSERT INTO tab_settlements(tab_id,person_name,amount,snapshot_version,participant_id) VALUES(41,'',0,2,601),(41,'',0,2,601)",
	} {
		t.Run("unique/"+name, func(t *testing.T) { identityReject(t, db, sql, "23505") })
	}
	// Identical labels and client refs in different bills are legal. Tagged member
	// and guest IDs are separate, and empty/duplicate snapshot labels stay legal.
	execSQL(t, db, "UPDATE bill_participants SET "+identityBinding+" WHERE id IN(601,604)")
	execSQL(t, db, `UPDATE item_assignments SET identity_version=2,participant_id=601 WHERE id=111;
 UPDATE person_shares SET identity_version=2,participant_id=601 WHERE id=121;
 INSERT INTO tab_settlements(tab_id,person_name,amount,snapshot_version,member_id,participant_id) VALUES(41,'',0,2,73,NULL),(41,'',0,2,NULL,601),(41,'',0,2,NULL,602)`)
	for name, sql := range map[string]string{"participant": "DELETE FROM bill_participants WHERE id=601", "participant_update": "UPDATE bill_participants SET id=999 WHERE id=601", "item": "UPDATE bill_items SET id=999 WHERE id=91", "member": "DELETE FROM tab_members WHERE id=73"} {
		t.Run("restrict/"+name, func(t *testing.T) { identityReject(t, db, sql, "23503") })
	}
}

// The original item FK keeps its CASCADE semantics. A RESTRICT FK added alongside
// it must not be presented as overriding the earlier cascade trigger's deletion.
func TestPostgresIdentity0003OriginalItemCascade(t *testing.T) {
	db := identityFixture(t)
	execSQL(t, db, "UPDATE item_assignments SET identity_version=2,participant_id=601 WHERE id=111")
	execSQL(t, db, "DELETE FROM bill_items WHERE id=91")
	if scalar(t, db, "SELECT count(*) FROM item_assignments WHERE id=111") != 0 {
		t.Fatal("original cascade behavior changed")
	}
	if scalar(t, db, "SELECT count(*) FROM bill_participants WHERE id=601") != 1 {
		t.Fatal("item cascade removed participant")
	}
}

func TestPostgresIdentity0003ExpansionAtomicity(t *testing.T) {
	for _, fault := range []string{"dml", "commit", "cancel"} {
		t.Run(fault, func(t *testing.T) {
			db := testpostgres.Open(t)
			steps, err := Registry()
			if err != nil {
				t.Fatal(err)
			}
			if _, err := run(context.Background(), db, Apply, steps[:2]); err != nil {
				t.Fatal(err)
			}
			seedLegacy(t, db)
			execSQL(t, db, "UPDATE bills SET creation_key_digest=decode(repeat('aa',32),'hex'),creation_fingerprint=decode(repeat('bb',32),'hex'),creation_fingerprint_version=1 WHERE id=101")
			before := identityRows(t, db)
			suffix := map[string]string{"dml": ";UPDATE bills SET total=NULL WHERE id=101", "commit": ";CREATE TABLE identity_failure_marker(id bigint REFERENCES bills(id) DEFERRABLE INITIALLY DEFERRED);INSERT INTO identity_failure_marker VALUES(999999)", "cancel": ";SELECT pg_sleep(30)"}[fault]
			candidate := append([]Step(nil), steps...)
			candidate[2].SQL += suffix
			candidate[2].Checksum = checksum(candidate[2].SQL)
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			result := make(chan error, 1)
			go func() { _, err := run(ctx, db, Apply, candidate); result <- err }()
			if fault == "cancel" {
				waitActivity(t, db, "wait_event='PgSleep'")
				cancel()
			}
			err = receive(t, result)
			if err == nil {
				t.Fatal("failed actual0003 batch succeeded")
			}
			var migrationError *Error
			if !errors.As(err, &migrationError) {
				t.Fatal("typed migration failure lost")
			}
			if fault == "commit" && migrationError.stage != "commit" {
				t.Fatal("did not exercise checked COMMIT", err)
			}
			if fault == "cancel" && !errors.Is(err, context.Canceled) {
				t.Fatal("cancellation type lost", err)
			}
			if before != identityRows(t, db) || scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname IN('bill_participants_id_seq','identity_failure_marker')") != 0 {
				t.Fatal("0003 backfill/DDL/ledger escaped transaction")
			}
			apply(t, db)
			whole := identityRows(t, db)
			apply(t, db)
			if whole != identityRows(t, db) {
				t.Fatal("retry changed full new graph/ledger")
			}
			var digest string
			if err := db.QueryRow("SELECT encode(creation_key_digest,'hex')||encode(creation_fingerprint,'hex')||creation_fingerprint_version::text FROM bills WHERE id=101").Scan(&digest); err != nil || digest != strings.Repeat("aa", 32)+strings.Repeat("bb", 32)+"1" {
				t.Fatal("0003 changed original replay tuple")
			}
		})
	}
}
