package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"gorm.io/gorm"
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
			control := authRequest(r, "POST", "/api/bills", `{"name":"Positive bill","subtotal":10,"total":10}`, "", "")
			if control.Code != 201 {
				t.Fatalf("clean tab counterpart: %d", control.Code)
			}
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
			var target map[string]any
			var forbiddenID uint
			switch child {
			case "participant":
				target = map[string]any{"name": "Private"}
				body["participants"] = []any{target}
				forbiddenID = victim.Participants[0].ID
			case "item":
				target = map[string]any{"name": "Private", "price": 10}
				body["items"] = []any{target}
				forbiddenID = victim.Items[0].ID
			case "assignment":
				target = map[string]any{"person_name": "Private", "percentage": 100}
				body["items"] = []any{map[string]any{"name": "Private", "price": 10, "assignments": []any{target}}}
				forbiddenID = victim.Items[0].Assignments[0].ID
			case "share":
				target = map[string]any{"person_name": "Private", "subtotal": 10, "total": 10, "items": []any{map[string]any{"name": "Private", "amount": 10, "is_shared": false}}}
				body["person_shares"] = []any{target}
				body["items"] = []any{map[string]any{"name": "Private", "price": 10, "assignments": []any{map[string]any{"person_name": "Private", "percentage": 100}}}}
				forbiddenID = victim.PersonShares[0].ID
			}
			cleanData, err := json.Marshal(body)
			if err != nil {
				t.Fatal(err)
			}
			control := authRequest(r, "POST", "/api/bills", string(cleanData), "", "")
			if control.Code != 201 {
				t.Fatalf("clean %s counterpart: got %d, want 201", child, control.Code)
			}
			target["id"] = forbiddenID
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
				body := map[string]any{"name": "Positive", "subtotal": 10, "total": 10}
				cleanData, _ := json.Marshal(body)
				control := authRequest(r, "POST", "/api/bills", string(cleanData), "", "")
				if control.Code != 201 {
					t.Fatalf("clean %s counterpart: %d", tc.name, control.Code)
				}
				before := authSnapshot(t, db)
				body[tc.field] = value
				data, _ := json.Marshal(body)
				w := authRequest(r, "POST", "/api/bills", string(data), "", "")
				if w.Code != 400 || before != authSnapshot(t, db) {
					t.Fatalf("status=%d; privileged write accepted", w.Code)
				}
			})
		}
	}
	for _, tc := range []struct{ name, body, clean string }{
		{"person_fk", `"participants":[{"name":"Alex","bill_id":0}]`, `"participants":[{"name":"Alex"}]`},
		{"item_fk", `"items":[{"name":"Dinner","price":10,"bill_id":null}]`, `"items":[{"name":"Dinner","price":10}]`},
		{"item_time", `"items":[{"name":"Dinner","price":10,"created_at":null}]`, `"items":[{"name":"Dinner","price":10}]`},
		{"assignment_fk", `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100,"bill_item_id":0}]}]`, `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100}]}]`},
		{"assignment_time", `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100,"updated_at":null}]}]`, `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100}]}]`},
		// History summaries are valid with zero component projections.
		{"share_fk", `"person_shares":[{"person_name":"Alex","total":10,"bill_id":0}]`, `"person_shares":[{"person_name":"Alex","total":10}]`},
		{"share_paid", `"person_shares":[{"person_name":"Alex","total":10,"paid":false}]`, `"person_shares":[{"person_name":"Alex","total":10}]`},
		{"share_item_id", `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100}]}],"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"items":[{"name":"Dinner","amount":10,"is_shared":false,"id":0}]}]`, `"items":[{"name":"Dinner","price":10,"assignments":[{"person_name":"Alex","percentage":100}]}],"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"items":[{"name":"Dinner","amount":10,"is_shared":false}]}]`},
		{"payment_id", `"payment_methods":[{"name":"Venmo","identifier":"@synthetic","id":null}]`, `"payment_methods":[{"name":"Venmo","identifier":"@synthetic"}]`},
	} {
		t.Run(tc.name, func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db)
			victim := models.Bill{Name: "Private victim", AccessToken: "private-victim-token", Subtotal: 10, Total: 10, PaymentMethods: []models.PaymentMethod{{Name: "Venmo", Identifier: "@private-victim"}}}
			saveAuthFixture(t, db, &victim)
			control := authRequest(r, "POST", "/api/bills", `{"name":"Positive","subtotal":10,"total":10,`+tc.clean+`}`, "", "")
			if control.Code != 201 {
				t.Fatalf("clean %s counterpart: %d %s", tc.name, control.Code, control.Body.String())
			}
			before := authSnapshot(t, db)
			w := authRequest(r, "POST", "/api/bills", `{"name":"Positive","subtotal":10,"total":10,`+tc.body+`}`, "", "")
			if w.Code != 400 || before != authSnapshot(t, db) {
				t.Fatalf("status=%d; nested privileged write accepted", w.Code)
			}
			for _, private := range []string{victim.Name, victim.AccessToken, "@private-victim"} {
				if strings.Contains(w.Body.String(), private) {
					t.Fatal("rejection discloses victim content")
				}
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
			var request struct {
				PersonShares []models.PersonShare `json:"person_shares"`
				Participants []models.Person      `json:"participants"`
			}
			if err := json.Unmarshal(fixture.Request, &request); err != nil {
				t.Fatal(err)
			}
			if len(got.PersonShares) != len(request.PersonShares) {
				t.Fatalf("people=%d want=%d", len(got.PersonShares), len(request.PersonShares))
			}
			expectedByName := map[string]models.PersonShare{}
			for _, share := range request.PersonShares {
				expectedByName[share.PersonName] = share
			}
			for _, participant := range request.Participants {
				if _, exists := expectedByName[participant.Name]; !exists {
					t.Fatalf("fixture missing expected participant %s", participant.Name)
				}
			}
			for _, share := range got.PersonShares {
				expected, exists := expectedByName[share.PersonName]
				if !exists {
					t.Fatalf("unexpected person %s", share.PersonName)
				}
				// Preserve server component rounding and deterministic name ties;
				// mobile projections can differ by one cent, especially tip remainders.
				switch fixture.Case {
				case "fractional_tip":
					if share.PersonName == "Alex" {
						expected.TipShare = 6.18
						expected.Total = 61.18
					}
					if share.PersonName == "Sam" {
						expected.TipShare = 6.17
						expected.Total = 61.17
					}
				case "fractional":
					if share.PersonName == "Alex" {
						expected.Subtotal = .83
						expected.TaxShare = .08
						expected.Total = 1.06
					}
					if share.PersonName == "Sam" {
						expected.Subtotal = 1.17
						expected.TaxShare = .12
						expected.Total = 1.50
					}
				case "history_no_items", "history_unassigned":
					expected.Subtotal = 50
					expected.TaxShare = 5
					expected.TipShare = 9
				}
				for _, component := range []struct {
					name      string
					got, want float64
				}{{"subtotal", share.Subtotal, expected.Subtotal}, {"tax", share.TaxShare, expected.TaxShare}, {"tip", share.TipShare, expected.TipShare}, {"total", share.Total, expected.Total}} {
					if math.Abs(component.got-component.want) > 1e-9 {
						t.Errorf("%s %s=%v want=%v", share.PersonName, component.name, component.got, component.want)
					}
				}
				if len(share.Items) != len(expected.Items) {
					t.Fatalf("%s detail count=%d want=%d", share.PersonName, len(share.Items), len(expected.Items))
				}
				for i, item := range share.Items {
					want := expected.Items[i]
					if item.Name != want.Name || item.IsShared != want.IsShared || math.Abs(item.Amount-want.Amount) > 1e-9 {
						t.Errorf("%s item %d=%+v want=%+v", share.PersonName, i, item, want)
					}
				}
				delete(expectedByName, share.PersonName)
			}
			if len(expectedByName) != 0 {
				t.Fatalf("missing people: %+v", expectedByName)
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

func assertCreationMoneyBoundary(t *testing.T, db *gorm.DB) {
	t.Helper()
	r := authorizationRouter(db)
	for _, tc := range []struct {
		name                        string
		subtotal, tax, total, price float64
	}{
		{"cent_amplification", .01, 1, 1.01, .02},
		{"near_zero", 1e-12, 1, 1.000000000001, 1e-6},
		{"zero_denominator", 0, 1, 1, .005},
	} {
		t.Run(tc.name, func(t *testing.T) {
			// The matching receipt/item control succeeds before the inconsistent item is
			// submitted. All values remain small; this never runs the extreme-loop input.
			body := map[string]any{"name": "Synthetic money", "lazy_mode": true, "subtotal": tc.subtotal, "tax": tc.tax, "total": tc.total, "items": []any{map[string]any{"name": "Item", "price": tc.subtotal, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 100}}}}}
			cleanData, err := json.Marshal(body)
			if err != nil {
				t.Fatal(err)
			}
			control := authRequest(r, "POST", "/api/bills", string(cleanData), "", "")
			if control.Code != 201 {
				t.Fatalf("valid money control: %d %s", control.Code, control.Body.String())
			}
			before := authSnapshot(t, db)
			body["items"].([]any)[0].(map[string]any)["price"] = tc.price
			data, err := json.Marshal(body)
			if err != nil {
				t.Fatal(err)
			}
			w := authRequest(r, "POST", "/api/bills", string(data), "", "")
			if w.Code != 400 || before != authSnapshot(t, db) {
				t.Fatalf("unsafe money: status=%d; state must be unchanged", w.Code)
			}
		})
	}
}

func TestAuthorizationCreationMoneyBoundary(t *testing.T) {
	assertCreationMoneyBoundary(t, authorizationDB(t))
}

func assertUnsafeShareCalculationRollsBack(t *testing.T, db *gorm.DB) {
	t.Helper()
	for _, attached := range []bool{false, true} {
		t.Run(fmt.Sprint(attached), func(t *testing.T) {
			// A synthetic legacy row with inconsistent amounts must not lose old shares
			// or partially save new assignments if recalculation fails.
			b := models.Bill{Name: "Legacy synthetic", AccessToken: fmt.Sprint("legacy-", attached), LazyMode: true, Subtotal: 1e-12, Tax: 1, Total: 1,
				Items:        []models.BillItem{{Name: "Legacy item", Price: .02}},
				PersonShares: []models.PersonShare{{PersonName: "Existing", Subtotal: 1, Total: 1}},
			}
			var dst models.Tab
			if attached {
				dst = models.Tab{Name: "Synthetic tab", AccessToken: "rollback-tab"}
				saveAuthFixture(t, db, &dst)
				b.TabID = &dst.ID
			}
			saveAuthFixture(t, db, &b)
			before := authSnapshot(t, db)
			assignments := []models.ItemAssignment{{PersonName: "New claim", Percentage: 100}}
			var err error
			if attached {
				err = NewTabRepository(db).UpdateBillItemAssignments(dst.ID, b.ID, b.Items[0].ID, assignments, nil)
			} else {
				err = billpkg.NewBillRepository(db).UpdateItemAssignments(b.ID, b.Items[0].ID, assignments, nil)
			}
			if !errors.Is(err, billpkg.ErrInvalidCreation) {
				t.Fatalf("expected calculation error, got %v", err)
			}
			if before != authSnapshot(t, db) {
				t.Fatal("calculation error did not roll back assignments/shares")
			}
		})
	}
}

func TestAuthorizationUnsafeShareCalculationRollsBack(t *testing.T) {
	assertUnsafeShareCalculationRollsBack(t, authorizationDB(t))
}
