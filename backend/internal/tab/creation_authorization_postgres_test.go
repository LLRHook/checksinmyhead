//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

// TestPostgresActualMobileCreationFixtures runs the ten actual old-client builder
// bodies, including the signed discount line, through the handler on the migrated schema.
func TestPostgresActualMobileCreationFixtures(t *testing.T) {
	assertActualMobileCreationFixtures(t, authorizationPostgres)
}

// TestPostgresPublicCreateRejectsPrivilegedInput is the reported reproduction on
// real PostgreSQL: a public create naming a victim tab, payer, row identity, paid
// state or a forged derived share is refused with every stored row unchanged.
// One schema serves all cases; each compares the complete nine-table snapshot.
func TestPostgresPublicCreateRejectsPrivilegedInput(t *testing.T) {
	db := authorizationPostgres(t)
	r := authorizationRouter(db)
	active := models.Tab{Name: "Private active tab", AccessToken: "private-active-tab"}
	saveAuthFixture(t, db, &active)
	finalized := models.Tab{Name: "Private finalized tab", AccessToken: "private-finalized-tab", Finalized: true}
	saveAuthFixture(t, db, &finalized)
	member := models.TabMember{TabID: active.ID, DisplayName: "Private member", MemberToken: "private-member-token"}
	saveAuthFixture(t, db, &member)
	victim := models.Bill{Name: "Private victim", AccessToken: "private-victim-token", TabID: &active.ID, Subtotal: 10, Total: 10,
		PaymentMethods: []models.PaymentMethod{{Name: "Venmo", Identifier: "@private-victim"}},
		Items:          []models.BillItem{{Name: "Private item", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Private person", Percentage: 100}}}},
		PersonShares:   []models.PersonShare{{PersonName: "Private person", Subtotal: 10, Total: 10, Paid: true}}}
	saveAuthFixture(t, db, &victim)
	closedVictim := models.Bill{Name: "Private closed victim", AccessToken: "private-closed-token", TabID: &finalized.ID, Subtotal: 10, Total: 10}
	saveAuthFixture(t, db, &closedVictim)
	itemID, assignmentID, shareID := victim.Items[0].ID, victim.Items[0].Assignments[0].ID, victim.PersonShares[0].ID

	body := func(fields string) string {
		if fields != "" {
			fields = "," + fields
		}
		return `{"name":"Synthetic","subtotal":10,"total":10` + fields + `}`
	}
	type rejection struct{ name, clean, forged string }
	cases := []rejection{
		// The review reproduction, then each half alone so neither masks the other.
		{"repro_negative_total_active_tab", body(""), fmt.Sprintf(`{"name":"Synthetic","subtotal":-25,"total":-25,"tab_id":%d}`, active.ID)},
		{"repro_negative_total_finalized_tab", body(""), fmt.Sprintf(`{"name":"Synthetic","subtotal":-25,"total":-25,"tab_id":%d}`, finalized.ID)},
		{"negative_total_alone", body(""), `{"name":"Synthetic","subtotal":-25,"total":-25}`},
		{"negative_total_positive_subtotal", body(""), `{"name":"Synthetic","subtotal":10,"total":-25}`},
		{"positive_active_tab", body(""), body(fmt.Sprintf(`"tab_id":%d`, active.ID))},
		{"positive_finalized_tab", body(""), body(fmt.Sprintf(`"tab_id":%d`, finalized.ID))},
		{"tab_graph", body(""), body(fmt.Sprintf(`"tab":{"id":%d,"access_token":"private-active-tab"}`, active.ID))},
		{"added_by_victim_member", body(""), body(fmt.Sprintf(`"added_by_member_id":%d`, member.ID))},
		{"paid_by_victim_member", body(""), body(fmt.Sprintf(`"paid_by_member_id":%d`, member.ID))},
		{"victim_bill_id", body(""), body(fmt.Sprintf(`"id":%d`, victim.ID))},
		{"victim_bill_token", body(""), body(`"access_token":"private-victim-token"`)},
	}
	for _, field := range []string{"tab_id", "added_by_member_id", "paid_by_member_id", "id", "access_token", "date", "created_at", "updated_at",
		"usd_exchange_rate", "usd_total", "display_total", "exchange_rate", "exchange_rate_source", "exchange_rate_date", "tab", "paid", "surprise"} {
		for _, value := range []string{"null", "0", `"forged"`} {
			cases = append(cases, rejection{field + "/" + strings.Trim(value, `"`), body(""), body(fmt.Sprintf("%q:%s", field, value))})
		}
	}
	item := `"items":[{"name":"Dinner","price":10%s,"assignments":[{"person_name":"Alex","percentage":100%s}]}]`
	share := `,"person_shares":[{"person_name":"Alex","subtotal":10,"total":%s%s,"items":[{"name":"Dinner","amount":10,"is_shared":false%s}]}]`
	graph := body(fmt.Sprintf(item, "", "") + fmt.Sprintf(share, "10", "", ""))
	for _, tc := range []struct{ name, item, assignment, total, share, detail string }{
		{"item_victim_id", fmt.Sprintf(`,"id":%d`, itemID), "", "10", "", ""},
		{"item_victim_bill", fmt.Sprintf(`,"bill_id":%d`, victim.ID), "", "10", "", ""},
		{"item_time", `,"created_at":null`, "", "10", "", ""},
		{"assignment_victim_id", "", fmt.Sprintf(`,"id":%d`, assignmentID), "10", "", ""},
		{"assignment_victim_item", "", fmt.Sprintf(`,"bill_item_id":%d`, itemID), "10", "", ""},
		{"assignment_time", "", `,"updated_at":null`, "10", "", ""},
		{"share_victim_id", "", "", "10", fmt.Sprintf(`,"id":%d`, shareID), ""},
		{"share_victim_bill", "", "", "10", fmt.Sprintf(`,"bill_id":%d`, victim.ID), ""},
		{"share_paid_true", "", "", "10", `,"paid":true`, ""},
		{"share_paid_false", "", "", "10", `,"paid":false`, ""},
		{"share_detail_id", "", "", "10", "", `,"id":0`},
		// A derived share that disagrees with the server's own calculation is not stored.
		{"share_forged_total", "", "", "1", "", ""},
	} {
		cases = append(cases, rejection{tc.name, graph, body(fmt.Sprintf(item, tc.item, tc.assignment) + fmt.Sprintf(share, tc.total, tc.share, tc.detail))})
	}
	cases = append(cases,
		rejection{"participant_id", body(`"participants":[{"name":"Alex"}]`), body(`"participants":[{"name":"Alex","id":1}]`)},
		rejection{"participant_bill", body(`"participants":[{"name":"Alex"}]`), body(fmt.Sprintf(`"participants":[{"name":"Alex","bill_id":%d}]`, victim.ID))},
		rejection{"payment_id", body(`"payment_methods":[{"name":"Venmo","identifier":"@synthetic"}]`), body(`"payment_methods":[{"name":"Venmo","identifier":"@synthetic","id":null}]`)},
	)

	private := []string{"Private", "private-", "@private-victim"}
	controls := map[string]bool{}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// The matching unprivileged body is accepted first, so a refusal below is
			// caused by the privileged field alone.
			if !controls[tc.clean] {
				if w := authRequest(r, "POST", "/api/bills", tc.clean, "", ""); w.Code != 201 {
					t.Fatalf("clean counterpart: %d %s", w.Code, w.Body.String())
				}
				controls[tc.clean] = true
			}
			before := lifecycleSnapshot(t, db)
			w := authRequest(r, "POST", "/api/bills", tc.forged, "", "")
			if w.Code != 400 {
				t.Errorf("privileged create: got %d, want 400", w.Code)
			}
			if lifecycleSnapshot(t, db) != before {
				t.Error("privileged create changed stored rows")
			}
			for _, text := range private {
				if strings.Contains(w.Body.String(), text) {
					t.Errorf("rejection discloses victim content %q", text)
				}
			}
		})
	}

	// Nothing the public route stored is attached, attributed or paid.
	var attached, paid int64
	if err := db.Model(&models.Bill{}).Where("id NOT IN ? AND (tab_id IS NOT NULL OR added_by_member_id IS NOT NULL OR paid_by_member_id IS NOT NULL)", []uint{victim.ID, closedVictim.ID}).Count(&attached).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Model(&models.PersonShare{}).Where("id <> ? AND paid", shareID).Count(&paid).Error; err != nil {
		t.Fatal(err)
	}
	if attached != 0 || paid != 0 {
		t.Fatalf("public creation stored tab ownership or paid state: attached=%d paid=%d", attached, paid)
	}

	t.Run("authorized_attach_only", func(t *testing.T) {
		// Attachment stays the separate, credentialed route: the finalized tab refuses
		// it unchanged, and the active tab accepts it with member attribution.
		w := authRequest(r, "POST", "/api/bills", body(""), "", "")
		var created struct {
			BillID uint   `json:"bill_id"`
			Token  string `json:"access_token"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil || w.Code != 201 || created.Token == "" {
			t.Fatalf("old-client create: %d %s", w.Code, w.Body.String())
		}
		attach := fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, created.BillID, created.Token)
		before := lifecycleSnapshot(t, db)
		if w := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", finalized.ID), attach, finalized.AccessToken, ""); w.Code != 400 {
			t.Errorf("finalized attach: got %d, want 400", w.Code)
		}
		if w := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", active.ID), attach, active.AccessToken, ""); w.Code != 403 {
			t.Errorf("attach without the tab member: got %d, want 403", w.Code)
		}
		if lifecycleSnapshot(t, db) != before {
			t.Fatal("refused attachment changed stored rows")
		}
		if w := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", active.ID), attach, active.AccessToken, member.MemberToken); w.Code != 200 {
			t.Fatalf("authorized attach: %d %s", w.Code, w.Body.String())
		}
		got, err := billpkg.NewBillRepository(db).GetById(created.BillID)
		if err != nil {
			t.Fatal(err)
		}
		if got.TabID == nil || *got.TabID != active.ID || got.AddedByMemberID == nil || *got.AddedByMemberID != member.ID {
			t.Fatal("authorized attach did not record the tab and member")
		}
	})
}
