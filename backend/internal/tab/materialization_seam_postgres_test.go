//go:build integration

package tab

import (
	"backend/pkg/models"
	"testing"

	"gorm.io/gorm"
)

func TestPostgresMaterializationGroupedFidelity(t *testing.T) {
	db := authorizationPostgres(t)
	_, _, want, _ := seedMaterialization(t, db)
	got := append([]models.Bill(nil), want...)
	// Include sparse bills and a non-ID bill order. No contiguity or global cap premise.
	got = append(got[1:], got[0], models.Bill{ID: 900})
	expected := []models.Bill{want[1], want[0], {ID: 900}}
	for i := range got {
		got[i].ParticipantRows = nil
		got[i].PersonShares = nil
	}
	if err := db.Transaction(func(tx *gorm.DB) error {
		flat, err := loadFinalizationRows(tx, got)
		if err != nil {
			return err
		}
		assertMaterializationValues(t, got, expected)
		if len(flat) != 8 || flat[0].ID != 10 || flat[7].ID != 17 {
			t.Fatal("complete temporary rows/order lost")
		}
		// Temporary GORM structs must be distinct, and grouping copies their values.
		// Nested nullable/JSON fields retain their existing GORM ownership semantics.
		flat[0].ID = 999
		flat[0].Label = "temporary row mutation"
		assertMaterializationValues(t, got, expected)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresMaterializationEmptyRows(t *testing.T) {
	db := authorizationPostgres(t)
	for _, rows := range []int{0, 1} {
		bills := make([]models.Bill, rows)
		if rows == 1 {
			bills[0].ID = 900
		}
		if err := db.Transaction(func(tx *gorm.DB) error {
			participants, err := loadFinalizationRows(tx, bills)
			if err != nil {
				return err
			}
			if len(participants) != 0 {
				t.Fatal("empty scope acquired rows")
			}
			for _, b := range bills {
				if b.ParticipantRows != nil || b.PersonShares != nil {
					t.Fatal("empty associations changed nil to allocated empty")
				}
			}
			return nil
		}); err != nil {
			t.Fatal(err)
		}
	}
}
