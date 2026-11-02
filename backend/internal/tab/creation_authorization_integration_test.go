package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"strings"
	"testing"
)

func TestAuthorizationPublicCreateCannotChooseVictimTab(t *testing.T) {
	for _, finalized := range []bool{false, true} {
		t.Run(fmt.Sprint(finalized), func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db)
			victim := models.Tab{Name: "Victim tab", AccessToken: "victim", Finalized: finalized}
			saveAuthFixture(t, db, &victim)
			before := authSnapshot(t, db)
			w := authRequest(r, "POST", "/api/bills", fmt.Sprintf(`{"name":"Positive bill","subtotal":10,"total":10,"tab_id":%d}`, victim.ID), "", "")
			if w.Code != 400 {
				t.Errorf("public tab injection: got %d, want 400", w.Code)
			}
			if before != authSnapshot(t, db) {
				t.Error("public create changed victim/child rows")
			}
		})
	}
}

func TestAuthorizationNestedIDsCannotReparentVictimChildren(t *testing.T) {
	for _, child := range []string{"participant", "item", "assignment", "share"} {
		t.Run(child, func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db)
			victim := models.Bill{Name: "Victim", AccessToken: "victim", Subtotal: 10, Total: 10, Participants: []models.Person{{Name: "Private"}}, Items: []models.BillItem{{Name: "Private", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Private", Percentage: 100}}}}, PersonShares: []models.PersonShare{{PersonName: "Private", Subtotal: 10, Total: 10, Paid: true}}}
			saveAuthFixture(t, db, &victim)
			body := map[string]any{"name": "Valid positive", "subtotal": 10, "total": 10}
			switch child {
			case "participant":
				body["participants"] = []any{map[string]any{"id": victim.Participants[0].ID, "name": "Private"}}
			case "item":
				body["items"] = []any{map[string]any{"id": victim.Items[0].ID, "name": "Private", "price": 10}}
			case "assignment":
				body["items"] = []any{map[string]any{"name": "Private", "price": 10, "assignments": []any{map[string]any{"id": victim.Items[0].Assignments[0].ID, "person_name": "Private", "percentage": 100}}}}
			case "share":
				body["person_shares"] = []any{map[string]any{"id": victim.PersonShares[0].ID, "person_name": "Private", "subtotal": 10, "total": 10}}
			}
			original, err := billpkg.NewBillRepository(db).GetById(victim.ID)
			if err != nil {
				t.Fatal(err)
			}
			originalJSON, _ := json.Marshal(original)
			before := authSnapshot(t, db)
			data, _ := json.Marshal(body)
			w := authRequest(r, "POST", "/api/bills", string(data), "", "")
			if w.Code != 400 {
				t.Errorf("%s injection: got %d, want 400", child, w.Code)
			}
			if before != authSnapshot(t, db) {
				t.Error("nested identity injection changed parent/child ownership/content")
			}
			remaining, err := billpkg.NewBillRepository(db).GetById(victim.ID)
			if err != nil {
				t.Fatal(err)
			}
			remainingJSON, _ := json.Marshal(remaining)
			if string(originalJSON) != string(remainingJSON) {
				t.Error("original victim graph changed")
			}
			var item models.BillItem
			var assignment models.ItemAssignment
			var share models.PersonShare
			db.First(&item, victim.Items[0].ID)
			db.First(&assignment, victim.Items[0].Assignments[0].ID)
			db.First(&share, victim.PersonShares[0].ID)
			if item.BillID != victim.ID || assignment.BillItemID != victim.Items[0].ID || share.BillID != victim.ID {
				t.Errorf("existing child was reparented: original_bill=%d item_bill=%d original_item=%d assignment_item=%d share_bill=%d", victim.ID, item.BillID, victim.Items[0].ID, assignment.BillItemID, share.BillID)
			}
			var links int64
			db.Table("bill_participants").Where("person_id = ?", victim.Participants[0].ID).Count(&links)
			if links != 1 {
				t.Errorf("existing participant gained unauthorized parent links: %d", links)
			}
			if bytes.Contains(w.Body.Bytes(), []byte("Private")) {
				t.Error("error discloses victim content")
			}
		})
	}
}

func TestAuthorizationPublicCreateRejectsPrivilegedFieldsIndividually(t *testing.T) {
	cases := []struct{ name, field string }{
		{"tab", "tab_id"}, {"added", "added_by_member_id"}, {"payer", "paid_by_member_id"}, {"id", "id"},
		{"token", "access_token"}, {"date", "date"}, {"created", "created_at"}, {"updated", "updated_at"},
		{"usd_rate", "usd_exchange_rate"}, {"usd_total", "usd_total"}, {"display_total", "display_total"}, {"rate", "exchange_rate"}, {"source", "exchange_rate_source"}, {"quote_date", "exchange_rate_date"},
		{"tab_graph", "tab"}, {"unknown", "surprise"}, {"paid", "paid"},
	}
	for _, tc := range cases {
		for _, value := range []any{nil, 0, "forged"} {
			t.Run(tc.name+"/"+fmt.Sprint(value), func(t *testing.T) {
				db := authorizationDB(t)
				r := authorizationRouter(db)
				before := authSnapshot(t, db)
				body := map[string]any{"name": "Positive", "subtotal": 10, "total": 10, tc.field: value}
				data, _ := json.Marshal(body)
				w := authRequest(r, "POST", "/api/bills", string(data), "", "")
				if w.Code != 400 || before != authSnapshot(t, db) {
					t.Fatalf("status=%d; privileged write accepted", w.Code)
				}
			})
		}
	}
	for _, tc := range []struct{ name, body string }{
		{"person_fk", `"participants":[{"name":"Alex","bill_id":0}]`},
		{"item_fk", `"items":[{"name":"Dinner","price":10,"bill_id":null}]`},
		{"item_time", `"items":[{"name":"Dinner","price":10,"created_at":null}]`},
		{"assignment_fk", `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100,"bill_item_id":0}]}]`},
		{"assignment_time", `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100,"updated_at":null}]}]`},
		{"share_fk", `"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"bill_id":0}]`},
		{"share_paid", `"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"paid":false}]`},
		{"share_item_id", `"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"items":[{"name":"Dinner","amount":10,"is_shared":false,"id":0}]}]`},
		{"payment_id", `"payment_methods":[{"name":"Venmo","identifier":"@synthetic","id":null}]`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			db := authorizationDB(t)
			before := authSnapshot(t, db)
			w := authRequest(authorizationRouter(db), "POST", "/api/bills", `{"name":"Positive","subtotal":10,"total":10,`+tc.body+`}`, "", "")
			if w.Code != 400 || before != authSnapshot(t, db) {
				t.Fatalf("status=%d; nested privileged write accepted", w.Code)
			}
		})
	}
}

func TestAuthorizationActualMobileCreationFixtures(t *testing.T) {
	data, err := os.ReadFile("../../../mobile/test/fixtures/bill_creation_contracts.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixtures []struct {
		Case    string          `json:"case"`
		Request json.RawMessage `json:"request"`
	}
	if err := json.Unmarshal(data, &fixtures); err != nil {
		t.Fatal(err)
	}
	if len(fixtures) != 10 {
		t.Fatalf("fixture selection=%d", len(fixtures))
	}
	for _, fixture := range fixtures {
		t.Run(fixture.Case, func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db)
			w := authRequest(r, "POST", "/api/bills", string(fixture.Request), "", "")
			if w.Code != 201 {
				t.Fatalf("actual builder rejected: %d %s", w.Code, w.Body.String())
			}
			var created struct {
				BillID uint   `json:"bill_id"`
				Token  string `json:"access_token"`
			}
			if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil {
				t.Fatal(err)
			}
			got, err := billpkg.NewBillRepository(db).GetById(created.BillID)
			if err != nil {
				t.Fatal(err)
			}
			if got.TabID != nil || got.AccessToken == "" || got.AccessToken != created.Token || got.Date.IsZero() {
				t.Fatal("not a fresh standalone bill")
			}
			var sum float64
			for _, s := range got.PersonShares {
				if s.Items == nil || s.Paid {
					t.Fatal("share breakdown/state invalid")
				}
				sum += s.Total
			}
			expected := got.Total
			switch fixture.Case {
			case "lazy_empty":
				expected = 0
			case "lazy_partial":
				expected = 32
			}
			if math.Abs(sum-expected) > .010001 {
				t.Fatalf("share total=%v expected=%v", sum, expected)
			}
			dst := models.Tab{Name: "Destination", AccessToken: "destination"}
			saveAuthFixture(t, db, &dst)
			body := fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, created.BillID, created.Token)
			attach := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), body, "destination", "")
			if attach.Code != 200 {
				t.Fatalf("attach: %d %s", attach.Code, attach.Body.String())
			}
			for _, path := range []string{fmt.Sprintf("/api/tabs/%d", dst.ID), fmt.Sprintf("/api/bills/%d", created.BillID)} {
				read := authRequest(r, "GET", path, "", "destination", "")
				if read.Code != 200 || strings.Contains(read.Body.String(), created.Token) {
					t.Fatal("authorized read failed or disclosed source token")
				}
			}
			other := models.Bill{Name: "Unrelated", AccessToken: "unrelated", Subtotal: 1, Total: 1}
			saveAuthFixture(t, db, &other)
			if w := authRequest(r, "GET", fmt.Sprintf("/api/bills/%d", other.ID), "", "destination", ""); w.Code != 403 || strings.Contains(w.Body.String(), "Unrelated") {
				t.Fatal("destination accessed unrelated standalone")
			}
		})
	}
}

func TestAuthorizationCreateTabIgnoresAssociationGraphs(t *testing.T) {
	db := authorizationDB(t)
	r := authorizationRouter(db)
	victim := models.Bill{Name: "Victim", Subtotal: 10, Total: 10, AccessToken: "victim"}
	saveAuthFixture(t, db, &victim)
	w := authRequest(r, "POST", "/api/tabs", fmt.Sprintf(`{"name":"New","bills":[{"id":%d}],"members":[{"id":1,"member_token":"forged"}]}`, victim.ID), "", "")
	if w.Code != 201 {
		t.Fatal(w.Code)
	}
	got, err := billpkg.NewBillRepository(db).GetById(victim.ID)
	if err != nil {
		t.Fatal(err)
	}
	var count int64
	db.Model(&models.TabMember{}).Count(&count)
	if got.TabID != nil || count != 0 {
		t.Fatal("tab create associated an existing graph")
	}
}

func TestAuthorizationForeignCreationFreezesQuoteOrPersistsNothing(t *testing.T) {
	for _, fail := range []bool{false, true} {
		t.Run(fmt.Sprint(fail), func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db, authorizationQuote{fail: fail})
			before := authSnapshot(t, db)
			w := authRequest(r, "POST", "/api/bills", `{"name":"Foreign","subtotal":100,"tax":10,"tip_amount":18,"total":128,"currency_code":"EUR"}`, "", "")
			if fail {
				if w.Code != 503 || before != authSnapshot(t, db) {
					t.Fatalf("failed quote wrote state: %d", w.Code)
				}
				return
			}
			if w.Code != 201 {
				t.Fatalf("foreign creation: %d %s", w.Code, w.Body.String())
			}
			var b models.Bill
			if err := db.First(&b).Error; err != nil {
				t.Fatal(err)
			}
			if b.Total != 128 || b.CurrencyCode != "EUR" || b.USDExchangeRate != 1.2 || b.USDTotal != 153.6 || b.ExchangeRateDate != "2026-11-02" || b.ExchangeRateSource != "synthetic" {
				t.Fatal("quote/native accounting changed")
			}
		})
	}
}

type authorizationQuote struct{ fail bool }

func (p authorizationQuote) LatestUSD(context.Context, string) (models.ExchangeRateQuote, error) {
	if p.fail {
		return models.ExchangeRateQuote{}, errors.New("synthetic provider unavailable")
	}
	return models.ExchangeRateQuote{Base: "EUR", Quote: "USD", Rate: 1.2, Date: "2026-11-02", Source: "synthetic"}, nil
}
