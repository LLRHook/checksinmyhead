// Package testidentity supplies explicit synthetic reference fixtures to tests.
// Production binaries do not import it. It never recalculates money or promotes
// application data: callers provide the complete known fixture content.
package testidentity

import (
	"backend/pkg/models"
	"fmt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"strings"
	"testing"
)

func check(t testing.TB, db *gorm.DB) {
	t.Helper()
	if db.Dialector.Name() == "postgres" {
		var row struct{ Database, Schema, User string }
		if err := db.Raw("SELECT current_database() AS database,current_schema() AS schema,current_user AS user").Scan(&row).Error; err != nil {
			t.Fatal(err)
		}
		if row.Database != "billington_test" || row.User != "billington_test" || !strings.HasPrefix(row.Schema, "billington_test_") {
			t.Fatal("reference fixtures require an owned synthetic PostgreSQL schema")
		}
	}
}

// Ready converts only the caller's known synthetic baseline into an explicit
// reference fixture. Calls are visible at each affected test/fixture owner; it is
// never an HTTP request adapter or an automatic production backfill.
func Ready(t testing.TB, db *gorm.DB, b *models.Bill, extra ...string) {
	t.Helper()
	check(t, db)
	if b.ID == 0 {
		t.Fatal("persist synthetic parent before building references")
	}
	original := append([]models.Person(nil), b.Participants...)
	err := db.Transaction(func(tx *gorm.DB) error {
		var stored models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).Preload("Items.Assignments").Preload("PersonShares").First(&stored, b.ID).Error; err != nil {
			return err
		}
		if stored.IdentityVersion == 2 {
			return fmt.Errorf("reference fixture already ready")
		}
		rows := []models.BillParticipant{}
		byName := map[string]int{}
		add := func(label string) {
			key := strings.ToLower(label)
			if _, ok := byName[key]; ok {
				return
			}
			ordinal := int64(len(rows))
			byName[key] = len(rows)
			rows = append(rows, models.BillParticipant{BillID: b.ID, TabID: stored.TabID, IdentityVersion: 2, Label: label, AllocationLabel: label, Ordinal: &ordinal})
		}
		for _, p := range original {
			add(p.Name)
		}
		for _, item := range stored.Items {
			for _, a := range item.Assignments {
				add(a.PersonName)
			}
		}
		for _, s := range stored.PersonShares {
			add(s.PersonName)
			rows[byName[strings.ToLower(s.PersonName)]].AllocationLabel = s.PersonName
		}
		for _, name := range extra {
			add(name)
		}
		people := make([]models.Person, len(rows))
		for i, p := range rows {
			people[i] = models.Person{Name: p.Label}
		}
		if len(people) > 0 {
			result := tx.Create(&people)
			if result.Error != nil {
				return result.Error
			}
			if result.RowsAffected != int64(len(people)) {
				return fmt.Errorf("incomplete synthetic people")
			}
		}
		for i := range rows {
			rows[i].PersonID = people[i].ID
		}
		if len(rows) > 0 {
			result := tx.Create(&rows)
			if result.Error != nil {
				return result.Error
			}
			if result.RowsAffected != int64(len(rows)) {
				return fmt.Errorf("incomplete synthetic participants")
			}
		}
		for i := range stored.Items {
			for j := range stored.Items[i].Assignments {
				a := &stored.Items[i].Assignments[j]
				pid := rows[byName[strings.ToLower(a.PersonName)]].ID
				bid := b.ID
				changed := tx.Model(&models.ItemAssignment{}).Where("id = ?", a.ID).UpdateColumns(map[string]any{"identity_version": 2, "participant_id": pid, "bill_id": bid})
				if changed.Error != nil {
					return changed.Error
				}
				if changed.RowsAffected != 1 {
					return fmt.Errorf("missing synthetic assignment")
				}
				a.IdentityVersion = 2
				a.ParticipantID = &pid
				a.BillID = &bid
			}
		}
		for i := range stored.PersonShares {
			s := &stored.PersonShares[i]
			pid := rows[byName[strings.ToLower(s.PersonName)]].ID
			changed := tx.Model(&models.PersonShare{}).Where("id = ?", s.ID).UpdateColumns(map[string]any{"identity_version": 2, "participant_id": pid})
			if changed.Error != nil {
				return changed.Error
			}
			if changed.RowsAffected != 1 {
				return fmt.Errorf("missing synthetic share")
			}
			s.IdentityVersion = 2
			s.ParticipantID = &pid
		}
		changed := tx.Model(&models.Bill{}).Where("id = ?", b.ID).UpdateColumns(map[string]any{"identity_version": 2, "identity_state": "ready", "identity_revision": 0})
		if changed.Error != nil {
			return changed.Error
		}
		if changed.RowsAffected != 1 {
			return fmt.Errorf("missing synthetic bill")
		}
		stored.IdentityVersion, stored.IdentityState, stored.IdentityRevision = 2, "ready", 0
		stored.ParticipantRows = rows
		stored.Participants = original
		*b = stored
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

func Participant(t testing.TB, db *gorm.DB, billID uint, label string) models.BillParticipant {
	t.Helper()
	var rows []models.BillParticipant
	if err := db.Select(models.ParticipantColumns).Where("bill_id = ?", billID).Order("id ASC").Find(&rows).Error; err != nil {
		t.Fatal(err)
	}
	var found *models.BillParticipant
	for i, p := range rows {
		if strings.EqualFold(p.Label, label) {
			if found != nil {
				t.Fatal("test must select an explicit ID for ambiguous fixture labels")
			}
			found = &rows[i]
		}
	}
	if found == nil {
		t.Fatalf("missing synthetic participant %q in bill%d", label, billID)
	}
	return *found
}
func Revision(t testing.TB, db *gorm.DB, billID uint) *int64 {
	t.Helper()
	var row struct{ IdentityRevision int64 }
	if e := db.Model(&models.Bill{}).Select("identity_revision").Where("id = ?", billID).Take(&row).Error; e != nil {
		t.Fatal(e)
	}
	return &row.IdentityRevision
}
func Assignment(t testing.TB, db *gorm.DB, billID uint, label string, percentage float64) models.ItemAssignment {
	t.Helper()
	p := Participant(t, db, billID, label)
	return models.ItemAssignment{ParticipantID: &p.ID, Percentage: percentage}
}
func Bind(t testing.TB, db *gorm.DB, billID, participantID, memberID, actorID uint) {
	t.Helper()
	check(t, db)
	err := db.Transaction(func(tx *gorm.DB) error {
		var b models.Bill
		if e := tx.Select(models.BillColumns).Session(&gorm.Session{SkipHooks: true}).First(&b, billID).Error; e != nil {
			return e
		}
		if b.TabID == nil || b.IdentityVersion != 2 {
			return fmt.Errorf("binding fixture requires an attached ready bill")
		}
		var actor models.TabMember
		if e := tx.Select(models.MemberColumns).Where("id = ? AND tab_id = ?", actorID, *b.TabID).First(&actor).Error; e != nil {
			return e
		}
		var member models.TabMember
		if e := tx.Select(models.MemberColumns).Where("id = ? AND tab_id = ?", memberID, *b.TabID).First(&member).Error; e != nil {
			return e
		}
		request, result := b.IdentityRevision+1, b.IdentityRevision+2
		kind := "source"
		if actor.Role == "creator" {
			kind = "creator"
		}
		now := tx.NowFunc()
		updated := tx.Model(&models.BillParticipant{}).Where("id = ? AND bill_id = ? AND member_id IS NULL AND pending_member_id IS NULL", participantID, billID).UpdateColumns(map[string]any{"member_id": memberID, "approved_by_member_id": actorID, "approval_kind": kind, "approved_at": now, "last_binding_member_id": memberID, "last_binding_request_revision": request, "last_binding_decision": "approve", "last_binding_actor_member_id": actorID, "last_binding_actor_kind": kind, "last_binding_result_revision": result, "last_binding_decided_at": now})
		if updated.Error != nil {
			return updated.Error
		}
		if updated.RowsAffected != 1 {
			return fmt.Errorf("binding fixture did not select one unbound row")
		}
		return tx.Model(&models.Bill{}).Where("id = ?", billID).UpdateColumn("identity_revision", result).Error
	})
	if err != nil {
		t.Fatal(err)
	}
}

// Save inserts a new, explicitly scoped model without association upserts.
func Save(t testing.TB, db *gorm.DB, v any) {
	t.Helper()
	if err := db.Omit(clause.Associations).Create(v).Error; err != nil {
		t.Fatal(err)
	}
}
