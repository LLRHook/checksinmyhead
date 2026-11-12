//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testidentity"
	"backend/pkg/models"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/gorm"
	"strings"
	"sync/atomic"
	"testing"
)

func TestPostgresJSONTextValidation(t *testing.T) {
	db := authorizationPostgres(t)
	r := lifecycleRouter(db)
	bh := billpkg.NewBillHandler(billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{}))
	th := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/bills/:id/participants", bh.CreateParticipant)
	r.PATCH("/api/bills/:id/participants/:participantId", bh.RenameParticipant)
	r.POST("/api/tabs/:id/bills/:billId/participants", th.CreateParticipant)
	r.PATCH("/api/tabs/:id/bills/:billId/participants/:participantId", th.RenameParticipant)
	r.PATCH("/api/tabs/:id/members/me", th.RenameMemberSelf)
	tab := models.Tab{Name: "Synthetic", AccessToken: "l9-tab"}
	saveAuthFixture(t, db, &tab)
	member := models.TabMember{TabID: tab.ID, DisplayName: "Alex", MemberToken: "l9-member", Role: "creator"}
	saveAuthFixture(t, db, &member)
	b := models.Bill{Name: "Synthetic", AccessToken: "l9-bill", LazyMode: true, Subtotal: 10, Total: 10, Items: []models.BillItem{{Name: "Meal", Price: 10}}}
	saveAuthFixture(t, db, &b)
	testidentity.Ready(t, db, &b, "Alex")
	p := testidentity.Participant(t, db, b.ID, "Alex")
	attached := models.Bill{Name: "Attached", AccessToken: "l9-source", TabID: &tab.ID, Subtotal: 10, Total: 10, Items: []models.BillItem{{Name: "Meal", Price: 10}}}
	saveAuthFixture(t, db, &attached)
	testidentity.Ready(t, db, &attached, "Alex")
	ap := testidentity.Participant(t, db, attached.ID, "Alex")
	revision := *testidentity.Revision(t, db, b.ID)
	ar := *testidentity.Revision(t, db, attached.ID)
	cases := []struct {
		name, method, path, body, token, member string
		version                                 int
	}{
		{"bill_name", "POST", "/api/bills", `{"name":"a\u0000b","subtotal":10,"total":10}`, "", "", 1},
		{"person_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"participants":[{"name":"a\u0000b"}]}`, "", "", 1},
		{"item_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"items":[{"name":"a\u0000b","price":10}]}`, "", "", 1},
		{"assignment_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"items":[{"name":"Meal","price":10,"assignments":[{"person_name":"a\u0000b","percentage":100}]}]}`, "", "", 1},
		{"share_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"person_shares":[{"person_name":"a\u0000b","total":10}]}`, "", "", 1},
		{"share_item_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"items":[{"name":"a\u0000b","price":10,"assignments":[{"person_name":"Alex","percentage":100}]}],"person_shares":[{"person_name":"Alex","subtotal":10,"total":10,"items":[{"name":"a\u0000b","amount":10}]}]}`, "", "", 1},
		{"payment_name", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"payment_methods":[{"name":"a\u0000b","identifier":"handle"}]}`, "", "", 1},
		{"payment_identifier", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"payment_methods":[{"name":"Venmo","identifier":"a\u0000b"}]}`, "", "", 1},
		{"reference_label", "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"participants":[{"name":"a\u0000b","client_ref":"a"}]}`, "", "", 2},
		{"tab_name", "POST", "/api/tabs", `{"name":"a\u0000b"}`, "", "", 2},
		{"tab_description", "POST", "/api/tabs", `{"name":"Trip","description":"a\u0000b"}`, "", "", 2},
		{"tab_creator", "POST", "/api/tabs", `{"name":"Trip","creator_display_name":"a\u0000b"}`, "", "", 2},
		{"tab_currency", "POST", "/api/tabs", `{"name":"Trip","display_currency":"a\u0000b"}`, "", "", 2},
		{"settings_name", "PATCH", fmt.Sprintf("/api/tabs/%d", tab.ID), `{"name":"a\u0000b"}`, "l9-tab", "l9-member", 2},
		{"settings_description", "PATCH", fmt.Sprintf("/api/tabs/%d", tab.ID), `{"description":"a\u0000b"}`, "l9-tab", "l9-member", 2},
		{"settings_currency", "PATCH", fmt.Sprintf("/api/tabs/%d", tab.ID), `{"display_currency":"a\u0000b"}`, "l9-tab", "l9-member", 2},
		{"join_name", "POST", fmt.Sprintf("/api/tabs/%d/join", tab.ID), `{"display_name":"a\u0000b"}`, "l9-tab", "", 2},
		{"member_name", "PATCH", fmt.Sprintf("/api/tabs/%d/members/me", tab.ID), `{"display_name":"a\u0000b"}`, "l9-tab", "l9-member", 2},
		{"participant_create", "POST", fmt.Sprintf("/api/bills/%d/participants", b.ID), fmt.Sprintf(`{"name":"a\u0000b","client_ref":"new","expected_revision":%d}`, revision), "l9-bill", "", 2},
		{"participant_rename", "PATCH", fmt.Sprintf("/api/bills/%d/participants/%d", b.ID, p.ID), fmt.Sprintf(`{"name":"a\u0000b","expected_revision":%d}`, revision), "l9-bill", "", 2},
		{"attached_participant_create", "POST", fmt.Sprintf("/api/tabs/%d/bills/%d/participants", tab.ID, attached.ID), fmt.Sprintf(`{"name":"a\u0000b","client_ref":"new","expected_revision":%d}`, ar), "l9-tab", "l9-member", 2},
		{"attached_participant_rename", "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/participants/%d", tab.ID, attached.ID, ap.ID), fmt.Sprintf(`{"name":"a\u0000b","expected_revision":%d}`, ar), "l9-tab", "l9-member", 2},
		{"single_assignment", "PATCH", fmt.Sprintf("/api/bills/%d/items/%d/assignments", b.ID, b.Items[0].ID), `{"assignments":[{"person_name":"a\u0000b","percentage":100}]}`, "l9-bill", "", 1},
		{"batch_assignment", "PATCH", fmt.Sprintf("/api/bills/%d/assignments", b.ID), fmt.Sprintf(`{"updates":[{"item_id":%d,"assignments":[{"person_name":"Alex","percentage":50},{"person_name":"a\u0000b","percentage":50}]}]}`, b.Items[0].ID), "l9-bill", "", 1},
		{"attached_single_assignment", "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/items/%d", tab.ID, attached.ID, attached.Items[0].ID), `{"assignments":[{"person_name":"a\u0000b","percentage":100}]}`, "l9-tab", "l9-member", 1},
		{"attached_batch_assignment", "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/assignments", tab.ID, attached.ID), fmt.Sprintf(`{"updates":[{"item_id":%d,"assignments":[{"person_name":"a\u0000b","percentage":100}]}]}`, attached.Items[0].ID), "l9-tab", "l9-member", 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if tc.name == "share_item_name" {
				// Matching receipt and projection history is otherwise valid.
				valid := strings.ReplaceAll(tc.body, `\u0000`, "x")
				w := versionAuthRequest(r, tc.method, tc.path, valid, tc.token, tc.member, tc.version)
				if w.Code != 201 {
					t.Fatalf("valid share history: status=%d body=%s", w.Code, w.Body.String())
				}
			}
			before := lifecycleSnapshot(t, db)
			w := versionAuthRequest(r, tc.method, tc.path, tc.body, tc.token, tc.member, tc.version)
			var body map[string]any
			if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			message := body["error"]
			if w.Code != 400 || (message != "invalid bill content" && message != "bad request" && message != "invalid mutation") || len(body) > 2 {
				t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
			}
			if code, ok := body["code"]; ok && code != "invalid_mutation" {
				t.Fatalf("unexpected code %v", code)
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("invalid text changed persisted state")
			}
		})
	}
}

func TestPostgresTextStorageBoundaries(t *testing.T) {
	db := authorizationPostgres(t)
	sql, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{"a\x00b", "a\xffb"} {
		var text string

		err := sql.QueryRow("SELECT $1::text", value).Scan(&text)
		var pg *pgconn.PgError
		if !errors.As(err, &pg) || pg.Code != "22021" {
			t.Fatal("expected PostgreSQL character_not_in_repertoire for unrepresentable text")
		}
		t.Log("PostgreSQL text rejects unrepresentable input with SQLSTATE 22021")
	}
	// Every other ASCII control, including embedded DEL, is legal UTF-8 text.
	value := "a"
	for c := byte(1); c < 32; c++ {
		value += string(c)
	}
	value += "\x7fb"
	var stored string
	if err := sql.QueryRow("SELECT $1::text", value).Scan(&stored); err != nil || stored != value {
		t.Fatal("legal control characters rejected or changed")
	}
	r := authorizationRouter(db)
	data, _ := json.Marshal(map[string]any{"name": value, "subtotal": 10, "total": 10, "items": []any{map[string]any{"name": value, "price": 10}}, "participants": []any{map[string]any{"name": value[:16]}}, "payment_methods": []any{map[string]any{"name": value, "identifier": value}}})
	w := authRequest(r, "POST", "/api/bills", string(data), "", "")
	if w.Code != 201 {
		t.Fatalf("other controls: %d %s", w.Code, w.Body.String())
	}
	w = authRequest(r, "POST", "/api/bills", "{\"name\":\"a\xffb\",\"subtotal\":10,\"total\":10}", "", "")
	if w.Code != 201 {
		t.Fatalf("stdlib replacement no longer accepted: %d", w.Code)
	}
	var names []string
	if err := db.Table("bills").Order("id").Pluck("name", &names).Error; err != nil {
		t.Fatal(err)
	}
	if len(names) != 2 || names[0] != value || names[1] != "a\ufffdb" {
		t.Fatal("accepted text did not persist unchanged after decoding")
	}
}

func TestPostgresNULTokens(t *testing.T) {
	db := authorizationPostgres(t)
	dst, b, _ := seedLifecycle(t, db)
	testidentity.Ready(t, db, &b, "Alex")
	member := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "member", Role: "creator"}
	saveAuthFixture(t, db, &member)
	r := lifecycleRouter(db)
	bh := billpkg.NewBillHandler(billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{}))
	th := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/bills/:id/participants", bh.CreateParticipant)
	r.PATCH("/api/tabs/:id/members/me", th.RenameMemberSelf)
	var queries atomic.Int64
	count := func(*gorm.DB) { queries.Add(1) }
	if err := db.Callback().Query().Before("gorm:query").Register("l15-count-queries", count); err != nil {
		t.Fatal(err)
	}
	if err := db.Callback().Raw().Before("gorm:raw").Register("l15-count-raw", count); err != nil {
		t.Fatal(err)
	}
	if err := db.Callback().Row().Before("gorm:row").Register("l15-count-row", count); err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct{ name, method, path, body, token, member string }{
		{"participant_query", "POST", fmt.Sprintf("/api/bills/%d/participants?t=a%%00b", b.ID), fmt.Sprintf(`{"name":"Pat","client_ref":"new","expected_revision":%d}`, *testidentity.Revision(t, db, b.ID)), "", ""},
		{"paid_query", "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d?t=a%%00b", b.ID, b.PersonShares[0].ID), `{"paid":true}`, "", ""},
		{"both_query", "PATCH", fmt.Sprintf("/api/tabs/%d/members/me?t=a%%00b&m=a%%00b", dst.ID), `{"display_name":"Pat"}`, "", ""},
		{"member_query", "PATCH", fmt.Sprintf("/api/tabs/%d/members/me?m=a%%00b", dst.ID), `{"display_name":"Pat"}`, "tab", ""},
		{"member_header", "PATCH", fmt.Sprintf("/api/tabs/%d/members/me", dst.ID), `{"display_name":"Pat"}`, "tab", "a\x00b"},
		{"access_header", "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", b.ID, b.PersonShares[0].ID), `{"paid":true}`, "a\x00b", ""},
		{"bill_read_member", "GET", fmt.Sprintf("/api/bills/%d?m=a%%00b", b.ID), "", "source", ""},
		{"tab_read_access", "GET", fmt.Sprintf("/api/tabs/%d?t=a%%00b", dst.ID), "", "", ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			before := lifecycleSnapshot(t, db)
			queries.Store(0)
			w := versionAuthRequest(r, tc.method, tc.path, tc.body, tc.token, tc.member, 2)
			if w.Code != 403 {
				t.Fatalf("status=%d body=%s", w.Code, w.Body.String())
			}
			var envelope map[string]string
			if err := json.Unmarshal(w.Body.Bytes(), &envelope); err != nil || envelope["error"] != "access denied" || envelope["code"] != "access_denied" {
				t.Fatalf("unexpected denial envelope: %s", w.Body.String())
			}
			if n := queries.Load(); n != 0 {
				t.Fatalf("NUL proof reached %d database queries", n)
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("invalid token changed state")
			}
			// A normal wrong token still follows the existing denial path.
			path := strings.ReplaceAll(tc.path, "a%00b", "wrong")
			token := strings.ReplaceAll(tc.token, "a\x00b", "wrong")
			member := strings.ReplaceAll(tc.member, "a\x00b", "wrong")
			w = versionAuthRequest(r, tc.method, path, tc.body, token, member, 2)
			if w.Code != 403 {
				t.Fatalf("wrong proof status=%d body=%s", w.Code, w.Body.String())
			}
			if lifecycleSnapshot(t, db) != before {
				t.Fatal("wrong token changed state")
			}
		})
	}
}
