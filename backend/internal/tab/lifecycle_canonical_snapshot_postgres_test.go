//go:build integration

package tab

import (
	"backend/internal/testidentity"
	"backend/pkg/models"
	"encoding/json"
	"reflect"
	"strconv"
	"strings"
	"testing"

	"gorm.io/gorm"
)

// Keep this oracle independent of lifecycleSnapshot and its query construction.
// Only the table-row array order may differ; every record is still to_jsonb(r).
const snapshotOrderLegacySQL = `SELECT jsonb_build_object(
 'tabs',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM tabs r),
 'tab_members',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM tab_members r),
 'bills',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM bills r),
 'people',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM people r),
 'bill_participants',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM bill_participants r),
 'bill_items',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM bill_items r),
 'item_assignments',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM item_assignments r),
 'person_shares',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM person_shares r),
 'tab_settlements',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') FROM tab_settlements r)
)::text`

var snapshotOrderTables = []struct{ table, field string }{
	{"tabs", "name"}, {"tab_members", "display_name"}, {"bills", "name"},
	{"people", "name"}, {"bill_participants", "label"}, {"bill_items", "name"},
	{"item_assignments", "person_name"}, {"person_shares", "person_name"},
	{"tab_settlements", "person_name"},
}

// Raw row strings preserve every JSON value, number lexeme, null, and nested
// array order. Int64 parsing is only for the exact PostgreSQL bigint row key.
// Duplicate IDs fail instead of silently replacing a record in this map.
type snapshotOrderState map[string]map[int64]string

func snapshotOrderCanonical(t *testing.T, raw string, ordered bool) snapshotOrderState {
	t.Helper()
	var document map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &document); err != nil {
		t.Fatal(err)
	}
	if len(document) != len(snapshotOrderTables) {
		t.Fatal("snapshot must contain exactly the nine lifecycle tables")
	}
	state := snapshotOrderState{}
	for _, spec := range snapshotOrderTables {
		array, exists := document[spec.table]
		if !exists || strings.TrimSpace(string(array)) == "null" {
			t.Fatalf("%s missing or null instead of a row array", spec.table)
		}
		var records []json.RawMessage
		if err := json.Unmarshal(array, &records); err != nil {
			t.Fatal(err)
		}
		if len(records) == 0 && strings.TrimSpace(string(array)) != "[]" {
			t.Fatalf("%s must coalesce empty rows to []", spec.table)
		}
		state[spec.table] = map[int64]string{}
		var previous int64
		for i, record := range records {
			var fields map[string]json.RawMessage
			if err := json.Unmarshal(record, &fields); err != nil {
				t.Fatal(err)
			}
			id, err := strconv.ParseInt(string(fields["id"]), 10, 64)
			if err != nil {
				t.Fatalf("%s has no exact bigint id: %v", spec.table, err)
			}
			if _, duplicate := state[spec.table][id]; duplicate || ordered && i > 0 && id <= previous {
				t.Fatalf("%s has duplicate IDs or is not ordered by numeric id", spec.table)
			}
			state[spec.table][id], previous = string(record), id
		}
	}
	return state
}

func snapshotOrderCapture(t *testing.T, db *gorm.DB) (string, snapshotOrderState) {
	t.Helper()
	got := lifecycleSnapshot(t, db)
	var legacy string
	if err := db.Raw(snapshotOrderLegacySQL).Scan(&legacy).Error; err != nil {
		t.Fatal(err)
	}
	state := snapshotOrderCanonical(t, got, true)
	if !reflect.DeepEqual(state, snapshotOrderCanonical(t, legacy, false)) {
		t.Fatal("id ordering changed full rows, columns, or JSON values")
	}
	return got, state
}

func snapshotOrderField(t *testing.T, state snapshotOrderState, table string, id int64, column string) json.RawMessage {
	t.Helper()
	var fields map[string]json.RawMessage
	if err := json.Unmarshal([]byte(state[table][id]), &fields); err != nil {
		t.Fatal(err)
	}
	value, exists := fields[column]
	if !exists {
		t.Fatalf("%s[%d] omitted column %s", table, id, column)
	}
	return value
}

func TestPostgresLifecycleSnapshotCanonicalRows(t *testing.T) {
	// The existing fixture applies migrations 1/2/3 in a strictly owned schema;
	// absence of the explicit local test DSN fails instead of skipping.
	db := authorizationPostgres(t)
	_, empty := snapshotOrderCapture(t, db)
	for table, rows := range empty {
		if len(rows) != 0 {
			t.Fatalf("%s not empty before fixture setup", table)
		}
	}
	dst, bill, _ := seedReferenceLifecycle(t, db)
	other := models.Tab{Name: "Other snapshot", AccessToken: "snapshot-other"}
	saveAuthFixture(t, db, &other)
	second := models.Bill{TabID: &other.ID, AccessToken: "snapshot-second", Name: "Second", Subtotal: 10, Total: 10,
		Items:        []models.BillItem{{Name: "Second", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Other", Percentage: 100}}}},
		PersonShares: []models.PersonShare{{PersonName: "Other", Subtotal: 10, Total: 10}}}
	saveAuthFixture(t, db, &second)
	testidentity.Ready(t, db, &second, "Guest")
	saveAuthFixture(t, db, &[]models.TabMember{{TabID: dst.ID, DisplayName: "Alex", MemberToken: "snapshot-one"}, {TabID: other.ID, DisplayName: "Other", MemberToken: "snapshot-two"}})
	saveAuthFixture(t, db, &[]models.TabSettlement{{TabID: dst.ID, PersonName: "Alex", Amount: 10}, {TabID: other.ID, PersonName: "Other", Amount: 10}})
	if err := db.Exec("UPDATE tabs SET description = 'before null' WHERE id = ?", dst.ID).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("UPDATE bills SET subtotal = 9007199254740993.123456789123456789, created_at = '2026-11-06T01:02:03.123456Z'::timestamptz WHERE id = ?", bill.ID).Error; err != nil {
		t.Fatal(err)
	}
	seeded, state := snapshotOrderCapture(t, db)
	for table, rows := range state {
		if len(rows) < 2 {
			t.Fatalf("%s fixture needs at least two records", table)
		}
	}
	if string(snapshotOrderField(t, state, "bills", int64(bill.ID), "subtotal")) != "9007199254740993.123456789123456789" {
		t.Fatal("exact stored numeric changed")
	}
	if lifecycleSnapshot(t, db) != seeded {
		t.Fatal("unchanged database produced a different snapshot")
	}

	// These exact bigint IDs are above float64's integer precision and put the
	// legacy text order in the opposite order from numeric id ordering.
	insert := db.Exec("INSERT INTO people(id,name) VALUES (9007199254740993,'Precise'),(10000000000000000,'Larger')")
	if insert.Error != nil || insert.RowsAffected != 2 {
		t.Fatalf("insert control: %v rows=%d", insert.Error, insert.RowsAffected)
	}
	inserted, insertedState := snapshotOrderCapture(t, db)
	if inserted == seeded || len(insertedState["people"]) != len(state["people"])+2 {
		t.Fatal("inserted records disappeared")
	}
	for _, id := range []int64{9007199254740993, 10000000000000000} {
		if string(snapshotOrderField(t, insertedState, "people", id, "id")) != strconv.FormatInt(id, 10) {
			t.Fatal("bigint key lost precision")
		}
	}
	var legacy string
	if err := db.Raw(snapshotOrderLegacySQL).Scan(&legacy).Error; err != nil {
		t.Fatal(err)
	}
	if inserted == legacy {
		t.Fatal("fixture did not expose the intentional row-array order change")
	}
	deleted := db.Exec("DELETE FROM people WHERE id IN (9007199254740993,10000000000000000)")
	if deleted.Error != nil || deleted.RowsAffected != 2 {
		t.Fatalf("delete control: %v rows=%d", deleted.Error, deleted.RowsAffected)
	}
	if restored, _ := snapshotOrderCapture(t, db); restored != seeded {
		t.Fatal("deletion did not restore all original records and values")
	}

	// Unknown additive columns must appear even while NULL, on every record in
	// every table. No model or allowlisted-column projection can satisfy this.
	for _, spec := range snapshotOrderTables {
		if err := db.Exec("ALTER TABLE " + spec.table + " ADD COLUMN snapshot_order_probe jsonb").Error; err != nil {
			t.Fatal(err)
		}
	}
	current, state := snapshotOrderCapture(t, db)
	if current == seeded {
		t.Fatal("added NULL columns were not observable")
	}
	for table, rows := range state {
		for id := range rows {
			if string(snapshotOrderField(t, state, table, id, "snapshot_order_probe")) != "null" {
				t.Fatal("added column must retain SQL NULL as JSON null")
			}
		}
	}
	probe := `{"number":9007199254740993.123456789123456789,"text":"9007199254740993","array":[1,"1",null,true]}`
	for _, spec := range snapshotOrderTables {
		var id int64
		for key := range state[spec.table] {
			if id == 0 || key < id {
				id = key
			}
		}
		change := db.Exec("UPDATE "+spec.table+" SET "+spec.field+" = ? WHERE id = ?", "snapshot changed", id)
		if change.Error != nil || change.RowsAffected != 1 {
			t.Fatalf("%s known-column control: %v rows=%d", spec.table, change.Error, change.RowsAffected)
		}
		next, nextState := snapshotOrderCapture(t, db)
		if next == current || nextState[spec.table][id] == state[spec.table][id] {
			t.Fatalf("%s known-column mutation disappeared", spec.table)
		}
		change = db.Exec("UPDATE "+spec.table+" SET snapshot_order_probe = ?::jsonb WHERE id = ?", probe, id)
		if change.Error != nil || change.RowsAffected != 1 {
			t.Fatalf("%s additive-column control: %v rows=%d", spec.table, change.Error, change.RowsAffected)
		}
		current, state = snapshotOrderCapture(t, db)
		if current == next {
			t.Fatalf("%s additive JSON mutation disappeared", spec.table)
		}
		var stored map[string]json.RawMessage
		if err := json.Unmarshal(snapshotOrderField(t, state, spec.table, id, "snapshot_order_probe"), &stored); err != nil {
			t.Fatal(err)
		}
		var array []json.RawMessage
		if err := json.Unmarshal(stored["array"], &array); err != nil {
			t.Fatal(err)
		}
		if string(stored["number"]) != "9007199254740993.123456789123456789" || string(stored["text"]) != `"9007199254740993"` || len(array) != 4 || string(array[0]) != "1" || string(array[1]) != `"1"` || string(array[2]) != "null" || string(array[3]) != "true" {
			t.Fatal("JSON number/type/value or nested array order changed")
		}
	}
	beforeTime := string(snapshotOrderField(t, state, "bills", int64(bill.ID), "created_at"))
	if err := db.Exec("UPDATE bills SET created_at = created_at + interval '1 microsecond' WHERE id = ?", bill.ID).Error; err != nil {
		t.Fatal(err)
	}
	_, state = snapshotOrderCapture(t, db)
	if string(snapshotOrderField(t, state, "bills", int64(bill.ID), "created_at")) == beforeTime {
		t.Fatal("timestamp mutation disappeared")
	}
	if err := db.Exec("UPDATE tabs SET description = NULL WHERE id = ?", dst.ID).Error; err != nil {
		t.Fatal(err)
	}
	current, state = snapshotOrderCapture(t, db)
	if string(snapshotOrderField(t, state, "tabs", int64(dst.ID), "description")) != "null" {
		t.Fatal("known-column NULL mutation disappeared")
	}
	if lifecycleSnapshot(t, db) != current {
		t.Fatal("unchanged decorated database produced a different snapshot")
	}
}

// The digest is only a cheaper equality witness for repeated measured samples.
// Each class of change the canonical snapshot observes must also change it, and
// restoring the exact prior rows must restore it.
func TestPostgresLifecycleDigestTracksCanonicalSnapshot(t *testing.T) {
	db := authorizationPostgres(t)
	empty := lifecycleDigest(t, db)
	for _, spec := range snapshotOrderTables {
		if !strings.Contains(empty, spec.table+"=0:empty") {
			t.Fatalf("%s is not reported as empty: %s", spec.table, empty)
		}
	}
	dst, bill, _ := seedReferenceLifecycle(t, db)
	saveAuthFixture(t, db, &[]models.TabMember{{TabID: dst.ID, DisplayName: "Alex", MemberToken: "digest-one"}, {TabID: dst.ID, DisplayName: "Sam", MemberToken: "digest-two"}})
	saveAuthFixture(t, db, &[]models.TabSettlement{{TabID: dst.ID, PersonName: "Alex", Amount: 10}, {TabID: dst.ID, PersonName: "Sam", Amount: 10}})
	if err := db.Exec("UPDATE tabs SET description = '' WHERE id = ?", dst.ID).Error; err != nil {
		t.Fatal(err)
	}
	type observed struct{ digest, snapshot string }
	capture := func() observed { return observed{lifecycleDigest(t, db), lifecycleSnapshot(t, db)} }
	// A change is tracked only when both witnesses move; unchanged state must
	// leave both exactly as they were.
	changed := func(label string, before observed) observed {
		t.Helper()
		after := capture()
		if after.snapshot == before.snapshot {
			t.Fatalf("%s: control did not change the canonical snapshot", label)
		}
		if after.digest == before.digest {
			t.Fatalf("%s: digest missed a change the canonical snapshot observed", label)
		}
		return after
	}
	exec := func(label, statement string, args ...any) {
		t.Helper()
		result := db.Exec(statement, args...)
		if result.Error != nil || result.RowsAffected != 1 {
			t.Fatalf("%s: %v rows=%d", label, result.Error, result.RowsAffected)
		}
	}
	seeded := capture()
	if again := capture(); again != seeded || seeded.digest == empty {
		t.Fatal("unchanged seeded database produced a different witness")
	}
	_, state := snapshotOrderCapture(t, db)
	current := seeded
	for _, spec := range snapshotOrderTables {
		if len(state[spec.table]) == 0 {
			t.Fatalf("%s fixture needs a record", spec.table)
		}
		var id int64
		for key := range state[spec.table] {
			if id == 0 || key < id {
				id = key
			}
		}
		var original string
		if err := db.Raw("SELECT "+spec.field+" FROM "+spec.table+" WHERE id = ?", id).Scan(&original).Error; err != nil {
			t.Fatal(err)
		}
		exec(spec.table+" update", "UPDATE "+spec.table+" SET "+spec.field+" = ? WHERE id = ?", "digest changed", id)
		changed(spec.table+" known column", current)
		exec(spec.table+" restore", "UPDATE "+spec.table+" SET "+spec.field+" = ? WHERE id = ?", original, id)
		if restored := capture(); restored != current {
			t.Fatalf("%s: restoring the exact value did not restore both witnesses", spec.table)
		}
	}
	// NULL and empty text are different stored states.
	exec("null", "UPDATE tabs SET description = NULL WHERE id = ?", dst.ID)
	current = changed("NULL versus empty text", current)
	// One microsecond and digits beyond float64 precision remain observable.
	exec("timestamp", "UPDATE bills SET created_at = created_at + interval '1 microsecond' WHERE id = ?", bill.ID)
	current = changed("timestamp microsecond", current)
	exec("numeric", "UPDATE bills SET subtotal = 9007199254740993.123456789123456789 WHERE id = ?", bill.ID)
	current = changed("exact numeric", current)
	exec("numeric digit", "UPDATE bills SET subtotal = 9007199254740993.123456789123456788 WHERE id = ?", bill.ID)
	current = changed("last numeric digit", current)
	// Row presence: insert and delete, including a settlement-only change.
	exec("insert", "INSERT INTO people(id,name) VALUES (9007199254740993,'Precise')")
	inserted := changed("inserted row", current)
	exec("delete", "DELETE FROM people WHERE id = 9007199254740993")
	if restored := capture(); restored != current {
		t.Fatal("deleting the inserted row did not restore both witnesses")
	}
	if inserted.digest == current.digest {
		t.Fatal("insert control was not observed")
	}
	exec("settlement", "DELETE FROM tab_settlements WHERE id = (SELECT min(id) FROM tab_settlements)")
	current = changed("deleted settlement", current)
	// Unknown additive columns are covered while NULL and once populated.
	for _, spec := range snapshotOrderTables {
		if err := db.Exec("ALTER TABLE " + spec.table + " ADD COLUMN digest_probe jsonb").Error; err != nil {
			t.Fatal(err)
		}
		current = changed(spec.table+" additive NULL column", current)
		result := db.Exec("UPDATE " + spec.table + " SET digest_probe = '{\"array\":[1,\"1\",null,true]}'::jsonb WHERE id = (SELECT min(id) FROM " + spec.table + ")")
		if result.Error != nil || result.RowsAffected != 1 {
			t.Fatalf("%s additive value: %v rows=%d", spec.table, result.Error, result.RowsAffected)
		}
		current = changed(spec.table+" additive column value", current)
	}
	if again := capture(); again != current {
		t.Fatal("unchanged decorated database produced a different witness")
	}
}
