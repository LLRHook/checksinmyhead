//go:build integration

package tab

import (
	"backend/pkg/models"
	"testing"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func TestPostgresFinalizationRowsSerializerOracle(t *testing.T) {
	db := authorizationPostgres(t)
	_, _, bills, _ := seedMaterialization(t, db)
	ids := []uint{bills[1].ID, bills[0].ID}
	for _, tc := range []struct {
		name string
		json any
	}{
		{"sql_null", nil},
		{"json_null", "null"},
		{"empty_array", "[]"},
		{"unknown_unicode_fields", `[{"name":"Raw 🧾\n\"","amount":0.25,"is_shared":true,"unknown":{"preserved_in_database":true}}]`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			// The original schema permits paid=NULL. No schema or historical row
			// normalization is needed to retain GORM's established false result.
			if err := db.Exec("UPDATE person_shares SET items=CAST(? AS jsonb),paid=NULL WHERE id=?", tc.json, 30).Error; err != nil {
				t.Fatal(err)
			}
			if err := db.Transaction(func(tx *gorm.DB) error {
				var oracleP []models.BillParticipant
				var oracleS []models.PersonShare
				if err := tx.Select(models.ParticipantColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&oracleP).Error; err != nil {
					return err
				}
				if err := tx.Select(models.ShareColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&oracleS).Error; err != nil {
					return err
				}
				p, err := readFinalizationParticipants(tx, ids)
				if err != nil {
					return err
				}
				s, err := readFinalizationShares(tx, ids)
				if err != nil {
					return err
				}
				assertMaterializationValues(t, materializationRows[models.BillParticipant](&p), oracleP)
				assertMaterializationValues(t, materializationRows[models.PersonShare](&s), oracleS)
				if s[0].ID != 30 || s[0].Paid {
					t.Fatal("nullable paid result changed")
				}
				if (tc.name == "sql_null" || tc.name == "json_null") && s[0].Items != nil {
					t.Fatal("NULL became allocated empty")
				}
				if tc.name == "empty_array" && (s[0].Items == nil || len(s[0].Items) != 0) {
					t.Fatal("allocated empty array became nil")
				}
				return nil
			}); err != nil {
				t.Fatal(err)
			}
		})
	}
}
