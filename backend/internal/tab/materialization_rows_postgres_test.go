//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"
	"testing"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func seedMaterialization(t *testing.T, db *gorm.DB) (models.Tab, []models.TabMember, []models.Bill, TabAccess) {
	t.Helper()
	tab, roster, bills := materializationFixture()
	saveAuthFixture(t, db, &tab)
	for i := range roster {
		saveAuthFixture(t, db, &roster[i])
	}
	for bi := range bills {
		b := bills[bi]
		b.ParticipantRows = nil
		b.PersonShares = nil
		saveAuthFixture(t, db, &b)
	}
	// Deliberately insert in an order different from both the ID and bill order.
	for pi := 3; pi >= 0; pi-- {
		for bi := 1; bi >= 0; bi-- {
			p := bills[bi].ParticipantRows[pi]
			person := models.Person{ID: p.PersonID, Name: p.Label}
			saveAuthFixture(t, db, &person)
			saveAuthFixture(t, db, &p)
		}
	}
	for pi := 2; pi >= 0; pi-- {
		for bi := 1; bi >= 0; bi-- {
			s := bills[bi].PersonShares[pi]
			saveAuthFixture(t, db, &s)
		}
	}
	// Exercise all three stored nullable JSON shapes, plus ignored unknown JSON fields.
	if err := db.Exec("UPDATE person_shares SET items=NULL WHERE id=30").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec("UPDATE person_shares SET items='null'::jsonb WHERE id=31").Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Exec(`UPDATE person_shares SET items=items || '[{"name":"extra","amount":0,"is_shared":false,"unknown":{"kept_by_storage":true}}]'::jsonb WHERE id=34`).Error; err != nil {
		t.Fatal(err)
	}
	bills[0].PersonShares[2].Items = append(bills[0].PersonShares[2].Items, models.ItemDetail{Name: "extra"})
	return tab, roster, bills, TabAccess{TabID: tab.ID, TabToken: tab.AccessToken, MemberToken: roster[0].MemberToken}
}

// Observe actual GORM destinations, accepting either value or pointer storage.
// No conversion or grouping is reimplemented as the expected-value oracle.
func materializationRows[T any](dest any) []T {
	v := reflect.Indirect(reflect.ValueOf(dest))
	rows := make([]T, 0, v.Len())
	for i := 0; i < v.Len(); i++ {
		x := v.Index(i)
		if x.Kind() == reflect.Pointer {
			x = x.Elem()
		}
		rows = append(rows, x.Interface().(T))
	}
	return rows
}

func assertMaterializationValues(t *testing.T, got, want any) {
	t.Helper()
	// Compare timestamps as exact instants, allowing pgx's database timezone location.
	var equal func(reflect.Value, reflect.Value) bool
	equal = func(a, b reflect.Value) bool {
		if a.Type() != b.Type() {
			return false
		}
		if a.Type() == reflect.TypeOf(time.Time{}) {
			return a.Interface().(time.Time).Equal(b.Interface().(time.Time))
		}
		switch a.Kind() {
		case reflect.Pointer:
			if a.IsNil() || b.IsNil() {
				return a.IsNil() == b.IsNil()
			}
			return equal(a.Elem(), b.Elem())
		case reflect.Struct:
			for i := 0; i < a.NumField(); i++ {
				if !equal(a.Field(i), b.Field(i)) {
					return false
				}
			}
			return true
		case reflect.Slice:
			if a.IsNil() != b.IsNil() || a.Len() != b.Len() {
				return false
			}
			for i := 0; i < a.Len(); i++ {
				if !equal(a.Index(i), b.Index(i)) {
					return false
				}
			}
			return true
		default:
			return reflect.DeepEqual(a.Interface(), b.Interface())
		}
	}
	if !equal(reflect.ValueOf(got), reflect.ValueOf(want)) {
		t.Fatalf("complete row fidelity differs: got %#v want %#v", got, want)
	}
}

func TestPostgresMaterializationCompleteRows(t *testing.T) {
	db := authorizationPostgres(t)
	tab, _, bills, access := seedMaterialization(t, db)
	// The existing GORM materializer is an independent database-value oracle.
	var oracleP []models.BillParticipant
	var oracleS []models.PersonShare
	ids := []uint{bills[0].ID, bills[1].ID}
	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Select(models.ParticipantColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&oracleP).Error; err != nil {
			return err
		}
		return tx.Select(models.ShareColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&oracleS).Error
	}); err != nil {
		t.Fatal(err)
	}
	var gotP []models.BillParticipant
	var gotS []models.PersonShare
	reads := []string{}
	callback := "test:materialization_complete"
	if err := db.Callback().Row().After("gorm:row").Register(callback, func(tx *gorm.DB) {
		if tx.Statement.Table != "bill_participants" && tx.Statement.Table != "person_shares" {
			return
		}
		lock, ok := tx.Statement.Clauses["FOR"].Expression.(clause.Locking)
		if !ok || lock.Strength != "UPDATE" {
			return
		}
		reads = append(reads, tx.Statement.SQL.String())
	}); err != nil {
		t.Fatal(err)
	}
	defer db.Callback().Row().Remove(callback)
	if err := db.Transaction(func(tx *gorm.DB) error {
		p, err := readFinalizationParticipants(tx, ids)
		if err != nil {
			return err
		}
		s, err := readFinalizationShares(tx, ids)
		if err != nil {
			return err
		}
		gotP = materializationRows[models.BillParticipant](&p)
		gotS = materializationRows[models.PersonShare](&s)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	assertMaterializationValues(t, gotP, oracleP)
	assertMaterializationValues(t, gotS, oracleS)
	// Discard direct-helper observations. The retained SQL guards below must
	// observe the actual finalization call, with the observer still registered.
	reads = nil
	first, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{access})
	if err != nil || len(first) != 5 {
		t.Fatalf("first finalize rows=%d error=%v", len(first), err)
	}
	var wantP []models.BillParticipant
	var wantS []models.PersonShare
	for _, b := range bills {
		wantP = append(wantP, b.ParticipantRows...)
		wantS = append(wantS, b.PersonShares...)
	}
	sort.Slice(wantP, func(i, j int) bool { return wantP[i].ID < wantP[j].ID })
	sort.Slice(wantS, func(i, j int) bool { return wantS[i].ID < wantS[j].ID })
	assertMaterializationValues(t, gotP, wantP)
	assertMaterializationValues(t, gotS, wantS)
	if len(reads) != 2 || !strings.Contains(reads[0], "ORDER BY id ASC FOR UPDATE") || !strings.Contains(reads[1], "ORDER BY id ASC FOR UPDATE") {
		t.Fatalf("complete locked read sequence changed: %v", reads)
	}
	for i, cols := range []string{models.ParticipantColumns, models.ShareColumns} {
		if strings.Count(reads[i], "SELECT ") != 1 {
			t.Fatal("unexpected materialization subquery")
		}
		if !strings.HasPrefix(strings.ReplaceAll(reads[i], "\"", ""), "SELECT "+cols+" FROM ") {
			t.Fatalf("complete projection changed: %s", reads[i])
		}
	}
	members, guests := 0, 0
	for _, s := range first {
		if s.ViewerMemberID == nil || *s.ViewerMemberID != 7 {
			t.Fatal("viewer proof lost")
		}
		if s.MemberID != nil {
			members++
			if *s.MemberID != 8 || s.Amount != .02 {
				t.Fatal("member/cents grouping changed")
			}
		} else {
			guests++
			if s.Amount != 0 || s.ParticipantID == nil || (s.GuestBillID != 101 && s.GuestBillID != 102) {
				t.Fatal("guest/cents grouping changed")
			}
		}
	}
	if members != 1 || guests != 4 {
		t.Fatal("parties merged by label")
	}
	if err := NewTabRepository(db).UpdateSettlementPaid(context.Background(), SettlementPaidCommand{Access: access, SettlementID: first[0].ID, Paid: true}); err != nil {
		t.Fatal(err)
	}
	first[0].Paid = true
	before := lifecycleSnapshot(t, db)
	retry, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{access})
	if err != nil || !reflect.DeepEqual(first, retry) || lifecycleSnapshot(t, db) != before {
		t.Fatalf("stored retry changed IDs/order/paid/times or wrote history: %v", err)
	}
	var saved models.Tab
	if err := db.First(&saved, tab.ID).Error; err != nil || !saved.Finalized || saved.FinalizedAt == nil {
		t.Fatal("finalization not persisted")
	}
}

func TestPostgresMaterializationReadFailures(t *testing.T) {
	for _, stage := range []string{"participant_query", "share_query", "json_type"} {
		t.Run(stage, func(t *testing.T) {
			db := authorizationPostgres(t)
			_, _, _, access := seedMaterialization(t, db)
			marker := errors.New("synthetic materialization failure")
			cb := "test:materialization_failure"
			if stage == "json_type" {
				if e := db.Exec(`UPDATE person_shares SET items='{}'::jsonb WHERE id=34`).Error; e != nil {
					t.Fatal(e)
				}
			} else {
				table := "bill_participants"
				if stage == "share_query" {
					table = "person_shares"
				}
				if e := db.Callback().Row().Before("gorm:row").Register(cb, func(tx *gorm.DB) {
					if tx.Statement.Table == table {
						tx.AddError(marker)
					}
				}); e != nil {
					t.Fatal(e)
				}
				defer db.Callback().Row().Remove(cb)
			}
			before := lifecycleSnapshot(t, db)
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{access})
			if err == nil || rows != nil || (stage != "json_type" && !errors.Is(err, marker)) || lifecycleSnapshot(t, db) != before {
				t.Fatalf("read error lost or partial transition: rows=%v error=%v", rows, err)
			}
			if stage == "json_type" {
				if e := db.Exec(`UPDATE person_shares SET items='[]'::jsonb WHERE id=34`).Error; e != nil {
					t.Fatal(e)
				}
			} else {
				if e := db.Callback().Row().Remove(cb); e != nil {
					t.Fatal(e)
				}
			}
			if rows := mustFinalize(t, db, access); len(rows) != 5 {
				t.Fatal("healthy recovery lost parties")
			}
		})
	}
}

func TestPostgresMaterializationInvalidEvidence(t *testing.T) {
	for _, kind := range []string{"partial_receipt", "future_pending", "legacy_row", "unused_wrong_tab", "invalid_json_money"} {
		t.Run(kind, func(t *testing.T) {
			db := authorizationPostgres(t)
			_, _, _, access := seedMaterialization(t, db)
			cb := "test:materialization_invalid"
			if e := db.Callback().Row().Before("gorm:row").Register(cb, func(tx *gorm.DB) {
				replacements := map[string]string{}
				columns := ""
				if tx.Statement.Table == "bill_participants" && kind != "invalid_json_money" {
					columns = models.ParticipantColumns
					switch kind {
					case "partial_receipt":
						replacements["last_binding_actor_kind"] = "CASE WHEN id=16 THEN NULL ELSE last_binding_actor_kind END AS last_binding_actor_kind"
					case "future_pending":
						replacements["pending_member_id"] = "CASE WHEN id=16 THEN 9::bigint ELSE pending_member_id END AS pending_member_id"
						replacements["pending_request_revision"] = "CASE WHEN id=16 THEN 17179869189::bigint ELSE pending_request_revision END AS pending_request_revision"
						replacements["requested_at"] = "CASE WHEN id=16 THEN '2026-11-05T00:00:00Z'::timestamptz ELSE requested_at END AS requested_at"
					case "legacy_row":
						replacements["identity_version"] = "CASE WHEN id=16 THEN 1::smallint ELSE identity_version END AS identity_version"
					case "unused_wrong_tab":
						replacements["tab_id"] = "CASE WHEN id=16 THEN 999::bigint ELSE tab_id END AS tab_id"
					}
				}
				if tx.Statement.Table == "person_shares" && kind == "invalid_json_money" {
					columns = models.ShareColumns
					replacements["items"] = `CASE WHEN id=34 THEN items || '[{"name":"invalid","amount":1e300}]'::jsonb ELSE items END AS items`
				}
				if columns != "" {
					selected := strings.Split(columns, ",")
					for i, name := range selected {
						if changed, ok := replacements[name]; ok {
							selected[i] = changed
						}
					}
					tx.Statement.Selects = []string{strings.Join(selected, ",")}
				}
			}); e != nil {
				t.Fatal(e)
			}
			defer db.Callback().Row().Remove(cb)
			before := lifecycleSnapshot(t, db)
			rows, err := NewTabRepository(db).FinalizeOnce(context.Background(), FinalizeCommand{access})
			want := error(billpkg.ErrIdentityReview)
			if kind == "invalid_json_money" {
				want = mutation.Review
			}
			if !errors.Is(err, want) || rows != nil || lifecycleSnapshot(t, db) != before {
				t.Fatalf("invalid complete evidence accepted: kind=%s rows=%v error=%v", kind, rows, err)
			}
			if e := db.Callback().Row().Remove(cb); e != nil {
				t.Fatal(e)
			}
			if rows := mustFinalize(t, db, access); len(rows) != 5 {
				t.Fatal(fmt.Sprint("healthy control failed after ", kind))
			}
		})
	}
}
