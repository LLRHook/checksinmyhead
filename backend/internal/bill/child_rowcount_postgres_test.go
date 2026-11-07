//go:build integration

package bill

import (
	"context"
	"strings"
	"testing"
)

func TestPostgresReplaySuppressedChildRowsCannotAcknowledgePartialGraph(t *testing.T) {
	for _, table := range []string{"people", "bill_participants", "bill_items", "item_assignments", "person_shares", "bill_items_partial", "item_assignments_partial"} {
		t.Run(table, func(t *testing.T) {
			db, g := replayPG(t)
			actualTable := strings.TrimSuffix(table, "_partial")
			function := `CREATE FUNCTION suppress_creation() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RETURN NULL; END$$`
			if table == "bill_items_partial" {
				function = `CREATE FUNCTION suppress_creation() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.price=4 THEN RETURN NULL; END IF; RETURN NEW; END$$`
			}
			if table == "item_assignments_partial" {
				function = `CREATE FUNCTION suppress_creation() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN IF NEW.bill_item_id%2=0 THEN RETURN NULL; END IF; RETURN NEW; END$$`
			}
			replayExec(t, db, function)
			replayExec(t, db, "CREATE TRIGGER suppress_creation BEFORE INSERT ON "+actualTable+" FOR EACH ROW EXECUTE FUNCTION suppress_creation()")
			r, err := (&billRepository{db: g}).Create(context.Background(), replayInsert(t, "First", "token"))
			if err == nil || r.Result.BillID != 0 || r.Result.AccessToken != "" {
				t.Fatal("suppressed child row acknowledged a partial graph")
			}
			replayGraph(t, db, 0)
			replayExec(t, db, "DROP TRIGGER suppress_creation ON "+actualTable)
			if _, err := (&billRepository{db: g}).Create(context.Background(), replayInsert(t, "First", "recovered-token")); err != nil {
				t.Fatal("same-key recovery after suppressed rows", err)
			}
			replayGraph(t, db, 1)
		})
	}
}
