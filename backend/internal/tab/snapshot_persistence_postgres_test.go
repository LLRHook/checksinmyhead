//go:build integration

package tab

import (
	"backend/internal/testidentity"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"gorm.io/gorm"
)

// Force a precision that the Darwin clock often does not produce. PostgreSQL,
// rather than the application clock or a normalized assertion, owns the result.
func TestPostgresSnapshotPersistedAcknowledgment(t *testing.T) {
	db := authorizationPostgres(t)
	forced := time.Date(2026, 11, 5, 1, 2, 3, 123456789, time.UTC)
	db = db.Session(&gorm.Session{NowFunc: func() time.Time { return forced }})
	dst, _, access := seedReferenceLifecycle(t, db)
	first := mustFinalize(t, db, access)
	var stored []models.TabSettlement
	if err := db.Where("tab_id = ?", dst.ID).Order("amount DESC, id ASC").Find(&stored).Error; err != nil {
		t.Fatal(err)
	}
	if len(stored) != 1 || stored[0].CreatedAt.Nanosecond()%1000 != 0 || stored[0].CreatedAt.Equal(forced) {
		t.Fatal("healthy control did not exercise PostgreSQL timestamp precision")
	}
	bytes := func(rows []models.TabSettlement) string {
		t.Helper()
		body, err := json.Marshal(rows)
		if err != nil {
			t.Fatal(err)
		}
		return string(body)
	}
	if bytes(first) != bytes(stored) {
		t.Fatalf("first acknowledgment is not the persisted snapshot: first=%s stored=%s", bytes(first), bytes(stored))
	}
	if bytes(mustFinalize(t, db, access)) != bytes(stored) {
		t.Fatal("retry changed the persisted snapshot")
	}
	if err := NewTabRepository(db).UpdateSettlementPaid(context.Background(), SettlementPaidCommand{Access: access, SettlementID: stored[0].ID, Paid: true}); err != nil {
		t.Fatal(err)
	}
	stored[0].Paid = true
	if bytes(mustFinalize(t, db, access)) != bytes(stored) {
		t.Fatal("retry lost current paid state or persisted timestamps")
	}
}

func TestPostgresSnapshotSuppressedInsertRollsBack(t *testing.T) {
	for _, mode := range []string{"all", "one"} {
		t.Run(mode, func(t *testing.T) {
			db := authorizationPostgres(t)
			_, b, access := seedReferenceLifecycle(t, db)
			sam := testidentity.Participant(t, db, b.ID, "Sam")
			extra := models.PersonShare{BillID: b.ID, PersonName: "Sam", Total: 0, IdentityVersion: 2, ParticipantID: &sam.ID}
			saveAuthFixture(t, db, &extra)
			before := lifecycleSnapshot(t, db)
			condition := "true"
			if mode == "one" {
				condition = "NEW.person_name = 'Sam'"
			}
			if err := db.Exec(fmt.Sprintf("CREATE FUNCTION suppress_snapshot() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF %s THEN RETURN NULL; END IF; RETURN NEW; END $$", condition)).Error; err != nil {
				t.Fatal(err)
			}
			if err := db.Exec("CREATE TRIGGER suppress_snapshot BEFORE INSERT ON tab_settlements FOR EACH ROW EXECUTE FUNCTION suppress_snapshot()").Error; err != nil {
				t.Fatal(err)
			}
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{access})
			if err == nil || rows != nil {
				t.Fatal("suppressed child insertion was acknowledged")
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("suppression committed a partial snapshot or parent finalization")
			}
			if err := db.Exec("DROP TRIGGER suppress_snapshot ON tab_settlements").Error; err != nil {
				t.Fatal(err)
			}
			if rows := mustFinalize(t, db, access); len(rows) != 2 {
				t.Fatal("healthy control did not persist both allocated participants")
			}
		})
	}
}
