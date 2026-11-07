//go:build integration

package tab

import (
	"backend/internal/testidentity"
	"backend/pkg/models"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"testing"
)

func TestPostgresLifecycleUnicodeShareAmbiguity(t *testing.T) {
	cases := []struct {
		name, actor                      string
		labels                           []string
		target                           int
		finalized, duplicateMember, paid bool
		status                           int
	}{
		{"long_s_first_active", "S", []string{"S", "ſ"}, 0, false, false, true, 403},
		{"long_s_second_active", "S", []string{"S", "ſ"}, 1, false, false, true, 403},
		{"long_s_first_finalized", "S", []string{"S", "ſ"}, 0, true, false, true, 403},
		{"long_s_second_finalized", "S", []string{"S", "ſ"}, 1, true, false, true, 403},
		{"sigma_first_active", "Σ", []string{"Σ", "ς"}, 0, false, false, true, 403},
		{"sigma_second_finalized", "Σ", []string{"Σ", "ς"}, 1, true, false, true, 403},
		{"ambiguous_equal_flag_is_still_checked", "S", []string{"S", "ſ"}, 0, false, false, false, 403},
		{"unique_long_s_active", "S", []string{"ſ"}, 0, false, false, true, 200},
		{"unique_long_s_finalized", "S", []string{"ſ"}, 0, true, false, true, 200},
		{"unique_ascii_with_unrelated_share", "Alex", []string{"Alex", "Sam"}, 0, false, false, true, 200},
		{"different_label_is_not_authorized", "Alex", []string{"Alex", "Sam"}, 1, false, false, true, 403},
		{"folded_member_ambiguity_is_retained", "S", []string{"S"}, 0, false, true, true, 403},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			db := authorizationPostgres(t)
			r := authorizationRouter(db)
			h := NewTabHandler(NewTabService(NewTabRepository(db)))
			r.POST("/api/tabs/:id/finalize", h.FinalizeTab)
			r.POST("/api/tabs/:id/join", h.JoinTab)
			r.PATCH("/api/tabs/:id/bills/:billId/shares/:shareId/paid", h.UpdateBillPersonSharePaid)
			r.POST("/api/tabs/:id/bills/:billId/participants/:participantId/binding-request", h.RequestBinding)
			r.PUT("/api/tabs/:id/bills/:billId/participants/:participantId/binding", h.DecideBinding)
			encode := func(v any) string {
				t.Helper()
				data, err := json.Marshal(v)
				if err != nil {
					t.Fatal(err)
				}
				return string(data)
			}
			require := func(w *httptest.ResponseRecorder, status int) {
				t.Helper()
				if w.Code != status {
					t.Fatalf("fixture HTTP status got %d want %d: %s", w.Code, status, w.Body.String())
				}
			}
			tabResponse := authRequest(r, "POST", "/api/tabs", encode(map[string]any{"name": "Unicode containment fixture", "creator_display_name": tc.actor}), "", "")
			require(tabResponse, 201)
			var tabCreated struct {
				ID       uint   `json:"tab_id"`
				Token    string `json:"access_token"`
				Member   string `json:"member_token"`
				MemberID uint   `json:"member_id"`
			}
			if err := json.Unmarshal(tabResponse.Body.Bytes(), &tabCreated); err != nil || tabCreated.ID == 0 || tabCreated.Token == "" || tabCreated.Member == "" {
				t.Fatal("missing fixture tab credentials")
			}
			participants := []map[string]any{}
			items := []map[string]any{}
			shares := []map[string]any{}
			for i, label := range tc.labels {
				itemName := fmt.Sprintf("Line %d", i+1)
				participants = append(participants, map[string]any{"name": label, "client_ref": fmt.Sprint("p", i)})
				items = append(items, map[string]any{"name": itemName, "price": 10, "assignments": []map[string]any{{"participant_ref": fmt.Sprint("p", i), "percentage": 100}}})
				shares = append(shares, map[string]any{"participant_ref": fmt.Sprint("p", i), "subtotal": 10, "tax_share": 0, "tip_share": 0, "total": 10, "items": []map[string]any{{"name": itemName, "amount": 10, "is_shared": false}}})
			}
			total := 10 * len(tc.labels)
			billResponse := versionAuthRequest(r, "POST", "/api/bills", encode(map[string]any{"name": "Unicode receipt", "subtotal": total, "tax": 0, "tip_amount": 0, "tip_percentage": 0, "total": total, "currency_code": "USD", "participants": participants, "items": items, "person_shares": shares, "payment_methods": []any{}}), "", "", 2)
			require(billResponse, 201)
			var billCreated struct {
				ID    uint   `json:"bill_id"`
				Token string `json:"access_token"`
				Map   []struct {
					ID uint `json:"participant_id"`
				} `json:"participant_map"`
			}
			if err := json.Unmarshal(billResponse.Body.Bytes(), &billCreated); err != nil || billCreated.ID == 0 || billCreated.Token == "" {
				t.Fatal("missing fixture source credentials")
			}
			require(authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", tabCreated.ID), encode(map[string]any{"bill_id": billCreated.ID, "bill_token": billCreated.Token}), tabCreated.Token, tabCreated.Member), 200)
			if tc.duplicateMember {
				require(authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/join", tabCreated.ID), `{"display_name":"ſ"}`, tabCreated.Token, ""), 201)
			}
			ownerID, ownerToken := tabCreated.MemberID, tabCreated.Member
			if tc.status != 200 {
				joined := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/join", tabCreated.ID), `{"display_name":"Confirmed owner"}`, tabCreated.Token, "")
				require(joined, 201)
				var owner struct {
					ID    uint   `json:"member_id"`
					Token string `json:"member_token"`
				}
				if err := json.Unmarshal(joined.Body.Bytes(), &owner); err != nil {
					t.Fatal(err)
				}
				ownerID, ownerToken = owner.ID, owner.Token
			}
			if len(billCreated.Map) != len(tc.labels) {
				t.Fatal("reference map missing")
			}
			pid := billCreated.Map[tc.target].ID
			binding := fmt.Sprintf("/api/tabs/%d/bills/%d/participants/%d", tabCreated.ID, billCreated.ID, pid)
			revision := *testidentity.Revision(t, db, billCreated.ID)
			require(versionAuthRequest(r, "POST", binding+"/binding-request", encode(map[string]any{"expected_revision": revision}), tabCreated.Token, ownerToken, 2), 200)
			require(versionAuthRequest(r, "PUT", binding+"/binding", encode(map[string]any{"expected_revision": revision + 1, "request_revision": revision + 1, "member_id": ownerID, "decision": "approve"}), tabCreated.Token, tabCreated.Member, 2), 200)
			if tc.finalized {
				require(authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", tabCreated.ID), "", tabCreated.Token, tabCreated.Member), 200)
			}
			var selected models.PersonShare
			if err := db.Where("bill_id = ? AND participant_id = ?", billCreated.ID, pid).First(&selected).Error; err != nil {
				t.Fatal(err)
			}
			before := lifecycleSnapshot(t, db)
			w := authRequest(r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d/paid", tabCreated.ID, billCreated.ID, selected.ID), encode(map[string]bool{"paid": tc.paid}), tabCreated.Token, tabCreated.Member)
			t.Logf("UNICODE_CONTAINMENT actor=%q labels=%q selected=%q finalized=%t got=%d want=%d", tc.actor, tc.labels, selected.PersonName, tc.finalized, w.Code, tc.status)
			if w.Code != tc.status {
				t.Errorf("got HTTP %d want %d: %s", w.Code, tc.status, w.Body.String())
			}
			if tc.status >= 400 {
				if lifecycleSnapshot(t, db) != before {
					t.Error("rejected ambiguous/unauthorized paid request changed persistent state")
				}
				// Current confirmed ownership succeeds independently of labels,
				// including the duplicate-Unicode and same-flag cases.
				require(authRequest(r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d/paid", tabCreated.ID, billCreated.ID, selected.ID), encode(map[string]bool{"paid": tc.paid}), tabCreated.Token, ownerToken), 200)
			}
			{
				var rows []models.PersonShare
				if err := db.Where("bill_id = ?", billCreated.ID).Find(&rows).Error; err != nil {
					t.Fatal(err)
				}
				if len(rows) != len(tc.labels) {
					t.Fatal("successful control changed share rows")
				}
				for _, row := range rows {
					if row.Paid != (row.ID == selected.ID && tc.paid) {
						t.Errorf("successful control changed wrong paid row %d", row.ID)
					}
				}
			}
		})
	}
}
