//go:build integration

package main

import (
	"backend/pkg/models"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"gorm.io/gorm"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func identityJSON(t *testing.T, v any) string {
	t.Helper()
	b, e := json.Marshal(v)
	if e != nil {
		t.Fatal(e)
	}
	return string(b)
}
func identityRequest(t *testing.T, r http.Handler, method, path, body, token, member, key string, version int, status int) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if member != "" {
		req.Header.Set("X-Member-Token", member)
	}
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	if version != 0 {
		req.Header.Set("X-Billington-Identity-Version", fmt.Sprint(version))
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != status {
		t.Fatalf("%s %s: status%d want%d body%s", method, path, w.Code, status, w.Body)
	}
	return w
}

type identityReceipt struct {
	ID    uint   `json:"bill_id"`
	Token string `json:"access_token"`
	Map   []struct {
		Ref string `json:"client_ref"`
		ID  uint   `json:"participant_id"`
	} `json:"participant_map"`
}

func identityCreate(t *testing.T, r http.Handler, labels []string, lazy bool, key string) identityReceipt {
	t.Helper()
	people, items := []any{}, []any{}
	for i, label := range labels {
		ref := fmt.Sprint("ref_", i)
		people = append(people, map[string]any{"client_ref": ref, "name": label})
		items = append(items, map[string]any{"name": fmt.Sprint("Item", i), "price": 1, "assignments": []any{map[string]any{"participant_ref": ref, "percentage": 100}}})
	}
	body := identityJSON(t, map[string]any{"name": "Reference receipt", "subtotal": len(labels), "total": len(labels), "lazy_mode": lazy, "participants": people, "items": items})
	w := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 201)
	var result identityReceipt
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	if result.ID == 0 || result.Token == "" || len(result.Map) != len(labels) {
		t.Fatal("missing exact original participant map")
	}
	return result
}
func identityStored(t *testing.T, g *gorm.DB, id uint) models.Bill {
	t.Helper()
	var b models.Bill
	if err := g.Session(&gorm.Session{SkipHooks: true}).Preload("ParticipantRows").Preload("Items.Assignments").Preload("PersonShares").First(&b, id).Error; err != nil {
		t.Fatal(err)
	}
	return b
}
func identitySnapshot(t *testing.T, g *gorm.DB) string {
	t.Helper()
	var value string
	if err := g.Raw(`SELECT jsonb_build_object('people',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM people x),'items',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM bill_items x),'members',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM tab_members x),'bills',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM bills x),'participants',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM bill_participants x),'assignments',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM item_assignments x),'shares',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM person_shares x),'snapshots',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM tab_settlements x),'tabs',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY id),'[]') FROM tabs x))::text`).Scan(&value).Error; err != nil {
		t.Fatal(err)
	}
	return value
}

type identityTab struct {
	ID       uint   `json:"tab_id"`
	Token    string `json:"access_token"`
	Member   string `json:"member_token"`
	MemberID uint   `json:"member_id"`
}

func identityNewTab(t *testing.T, r http.Handler, name string) identityTab {
	t.Helper()
	w := identityRequest(t, r, "POST", "/api/tabs", identityJSON(t, map[string]any{"name": "Reference trip", "creator_display_name": name}), "", "", "", 2, 201)
	var result identityTab
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	return result
}
func identityJoin(t *testing.T, r http.Handler, tab identityTab, label string) (uint, string) {
	t.Helper()
	w := identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/join", tab.ID), identityJSON(t, map[string]any{"display_name": label}), tab.Token, "", "", 2, 201)
	var result struct {
		ID    uint   `json:"member_id"`
		Token string `json:"member_token"`
	}
	if e := json.Unmarshal(w.Body.Bytes(), &result); e != nil {
		t.Fatal(e)
	}
	return result.ID, result.Token
}
func identityAttach(t *testing.T, r http.Handler, tab identityTab, b identityReceipt, revision int64) {
	t.Helper()
	identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/bills", tab.ID), identityJSON(t, map[string]any{"bill_id": b.ID, "bill_token": b.Token, "expected_revision": revision}), tab.Token, tab.Member, "", 2, 200)
}
func identityParticipantPath(tab identityTab, b identityReceipt, pid uint) string {
	return fmt.Sprintf("/api/tabs/%d/bills/%d/participants/%d", tab.ID, b.ID, pid)
}

func TestPostgresIdentity0003CreationAndExactReplay(t *testing.T) {
	_, g, r, calls, _ := replayRouter(t)
	t.Run("wire1_miss_graph2_response1", func(t *testing.T) {
		body := `{"name":"Union","subtotal":1,"total":1,"participants":[{"name":"Roster"}],"items":[{"name":"Unit","price":1,"assignments":[{"person_name":"Claim","percentage":100}]}],"person_shares":[{"person_name":"Projection","total":0,"items":[]}]}`
		key := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32))
		w := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 1, 201)
		var fields map[string]any
		json.Unmarshal(w.Body.Bytes(), &fields)
		if len(fields) != 8 {
			t.Fatal("wire1 response shape changed")
		}
		id := uint(fields["bill_id"].(float64))
		stored := identityStored(t, g, id)
		if stored.IdentityVersion != 2 || stored.IdentityState != "ready" || stored.IdentityRevision != 0 || stored.CreationResponse != nil || stored.CreationResponseVersion != nil || len(stored.ParticipantRows) != 3 {
			t.Fatalf("wire1 miss did not construct the complete ready union: %+v", stored)
		}
		for _, p := range stored.ParticipantRows {
			if p.ClientRef != nil || p.MemberID != nil || p.IdentityVersion != 2 {
				t.Fatal("wire1 fabricated ref/binding")
			}
		}
		before := identitySnapshot(t, g)
		retry := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 1, 201)
		if retry.Body.String() != w.Body.String() || identitySnapshot(t, g) != before {
			t.Fatal("format1 replay rewrote current graph")
		}
		// The same historical fingerprint may still address a legacy graph1.
		for _, sql := range []string{"UPDATE item_assignments SET identity_version=1,participant_id=NULL WHERE bill_id = ?", "UPDATE person_shares SET identity_version=1,participant_id=NULL WHERE bill_id = ?", "UPDATE bill_participants SET identity_version=1 WHERE bill_id = ?", "UPDATE bills SET identity_version=1,identity_state='legacy_review' WHERE id = ?"} {
			if e := g.Exec(sql, id).Error; e != nil {
				t.Fatal(e)
			}
		}
		before = identitySnapshot(t, g)
		identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 1, 201)
		if identitySnapshot(t, g) != before {
			t.Fatal("legacy format1 hit was promoted")
		}
	})
	t.Run("wire2_exact_original_after_rename_and_url_change", func(t *testing.T) {
		key := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))
		t.Setenv("APP_DOMAIN", "https://original.example")
		body := `{"name":"Duplicate labels","subtotal":2,"total":2,"participants":[{"client_ref":"a","name":"Alex"},{"client_ref":"b","name":"Alex"},{"client_ref":"zero","name":""}],"items":[{"name":"Unit","price":2,"assignments":[{"participant_ref":"a","percentage":50},{"participant_ref":"b","percentage":50}]}]}`
		first := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 201)
		var receipt identityReceipt
		json.Unmarshal(first.Body.Bytes(), &receipt)
		if len(receipt.Map) != 3 || receipt.Map[0].Ref != "a" || receipt.Map[1].Ref != "b" || receipt.Map[2].Ref != "zero" {
			t.Fatal("map lost original input order")
		}
		stored := identityStored(t, g, receipt.ID)
		if string(stored.CreationResponse) != first.Body.String() || stored.CreationResponseVersion == nil || *stored.CreationResponseVersion != 2 || len(stored.PersonShares) != 3 {
			t.Fatal("response2 or zero graph was not persisted")
		}
		identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/participants/%d", receipt.ID, receipt.Map[0].ID), `{"name":"Renamed","expected_revision":0}`, receipt.Token, "", "", 2, 200)
		before := identitySnapshot(t, g)
		t.Setenv("APP_DOMAIN", "https://changed.example")
		retry := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 201)
		if retry.Body.String() != first.Body.String() || identitySnapshot(t, g) != before {
			t.Fatal("replay rebuilt mutable graph/URL")
		}
		read := identityRequest(t, r, "GET", fmt.Sprintf("/api/bills/%d", receipt.ID), "", receipt.Token, "", "", 2, 200)
		if !strings.Contains(read.Body.String(), `"label":"Renamed"`) || strings.Contains(read.Body.String(), receipt.Token) || strings.Contains(read.Body.String(), "creation_response") {
			t.Fatal("current projection stale or disclosed private receipt")
		}
		identityRequest(t, r, "GET", fmt.Sprintf("/api/bills/%d", receipt.ID), "", receipt.Token, "", "", 1, 409)
		identityRequest(t, r, "POST", "/api/bills", `{"name":"Duplicate labels","subtotal":2,"total":2}`, "", "", key, 1, 409)
		if e := g.Model(&models.Bill{}).Where("id = ?", receipt.ID).UpdateColumns(map[string]any{"creation_response": []byte("corrupt")}).Error; e != nil {
			t.Fatal(e)
		}
		identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 503)
	})
	t.Run("unkeyed_wire2_persists_original", func(t *testing.T) {
		receipt := identityCreate(t, r, []string{"", "Alex", "Alex"}, false, "")
		b := identityStored(t, g, receipt.ID)
		if b.CreationKeyDigest != nil || b.CreationResponseVersion == nil || len(b.CreationResponse) == 0 {
			t.Fatal("unkeyed response was not durable")
		}
	})
	if calls.Load() != 0 {
		t.Fatal("native USD invoked a provider")
	}
}

func TestPostgresIdentity0003BindingAuthorityAndRetry(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	trip := identityNewTab(t, r, "Creator")
	victimID, victim := identityJoin(t, r, trip, "Alex")
	_, impostor := identityJoin(t, r, trip, "Alex")
	receipt := identityCreate(t, r, []string{"Alex", ""}, true, "")
	identityAttach(t, r, trip, receipt, 0)
	pid := receipt.Map[0].ID
	path := identityParticipantPath(trip, receipt, pid)
	b := identityStored(t, g, receipt.ID)
	share := b.PersonShares[0]
	for _, s := range b.PersonShares {
		if s.ParticipantID != nil && *s.ParticipantID == pid {
			share = s
		}
	}
	paidPath := fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d/paid", trip.ID, receipt.ID, share.ID)
	for _, flag := range []bool{false, true} {
		identityRequest(t, r, "PATCH", paidPath, identityJSON(t, map[string]any{"paid": flag}), trip.Token, impostor, "", 2, 403)
	}
	identityRequest(t, r, "POST", path+"/binding-request", `{"expected_revision":1}`, trip.Token, victim, "", 2, 200)
	before := identitySnapshot(t, g)
	identityRequest(t, r, "POST", path+"/binding-request", `{"expected_revision":1}`, trip.Token, victim, "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("pending-generation retry changed evidence")
	}
	identityRequest(t, r, "PATCH", paidPath, `{"paid":true}`, trip.Token, victim, "", 2, 403)
	identityRequest(t, r, "POST", path+"/binding-request", `{"expected_revision":2}`, trip.Token, impostor, "", 2, 409)
	decision := identityJSON(t, map[string]any{"expected_revision": 2, "request_revision": 2, "member_id": victimID, "decision": "approve"})
	identityRequest(t, r, "PUT", path+"/binding", decision, trip.Token, trip.Member, "", 2, 200)
	identityRequest(t, r, "PATCH", paidPath, `{"paid":true}`, trip.Token, victim, "", 2, 200)
	before = identitySnapshot(t, g)
	identityRequest(t, r, "PUT", path+"/binding", decision, trip.Token, trip.Member, "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("exact paid decision retry rewrote receipt")
	}
	identityRequest(t, r, "PATCH", paidPath, `{"paid":true}`, trip.Token, impostor, "", 2, 403)
	identityRequest(t, r, "PATCH", paidPath, `{"paid":true}`, trip.Token, trip.Member, "", 2, 403)
	old := identityStored(t, g, receipt.ID)
	identityRequest(t, r, "PATCH", path, `{"name":"Receipt label changed","expected_revision":3}`, trip.Token, victim, "", 2, 200)
	current := identityStored(t, g, receipt.ID)
	if current.IdentityRevision != 4 || len(current.PersonShares) != len(old.PersonShares) {
		t.Fatal("rename changed economics/revision")
	}
	for i, s := range current.PersonShares {
		if s.ID != old.PersonShares[i].ID || s.Paid != old.PersonShares[i].Paid || s.Total != old.PersonShares[i].Total {
			t.Fatal("rename moved paid economics")
		}
	}
	identityRequest(t, r, "PUT", path+"/binding", decision, trip.Token, trip.Member, "", 2, 409)
	identityRequest(t, r, "GET", fmt.Sprintf("/api/tabs/%d", trip.ID), "", trip.Token, "wrong-member", "", 2, 403)
	finalize := identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), `{"display_name":"New member label"}`, trip.Token, victim, "", 2, 200)
	retry := identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
	if retry.Body.String() != finalize.Body.String() {
		t.Fatal("member rename changed frozen snapshot")
	}
	identityRequest(t, r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), "", trip.Token, victim, "", 2, 409)
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", receipt.ID, share.ID), `{"paid":false}`, receipt.Token, "", "", 2, 200)
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", receipt.ID, share.ID), `{"paid":true}`, trip.Token, "", "", 2, 403)
	// Same-tab recovery is fully reauthorized even after finalization and revision changes.
	identityAttach(t, r, trip, receipt, 0)
	identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/bills", trip.ID), identityJSON(t, map[string]any{"bill_id": receipt.ID, "bill_token": receipt.Token, "expected_revision": 0}), trip.Token, "wrong-member", "", 2, 403)
}

func TestPostgresIdentity0003ReferenceClaimsAndParticipantRecovery(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	receipt := identityCreate(t, r, []string{"Alex", "Alex", ""}, true, "")
	b := identityStored(t, g, receipt.ID)
	pid := receipt.Map[0].ID
	other := receipt.Map[1].ID
	item := b.Items[0]
	path := fmt.Sprintf("/api/bills/%d/items/%d/assignments", receipt.ID, item.ID)
	identityRequest(t, r, "PATCH", path, identityJSON(t, map[string]any{"expected_revision": 0, "assignments": []any{map[string]any{"participant_id": pid, "percentage": 50}, map[string]any{"participant_id": other, "percentage": 50}}}), receipt.Token, "", "", 2, 200)
	updated := identityStored(t, g, receipt.ID)
	if updated.IdentityRevision != 1 {
		t.Fatal("claim did not increment exactly once")
	}
	before := identitySnapshot(t, g)
	identityRequest(t, r, "PATCH", path, identityJSON(t, map[string]any{"expected_revision": 1, "assignments": []any{map[string]any{"participant_id": pid, "percentage": 50}, map[string]any{"participant_id": other, "percentage": 50}}}), receipt.Token, "", "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("allocation no-op wrote dates or revision")
	}
	for _, body := range []string{fmt.Sprintf(`{"expected_revision":1,"assignments":[{"participant_id":%d,"person_name":"Alex","percentage":100}]}`, pid), fmt.Sprintf(`{"expected_revision":1,"assignments":[{"participant_id":%d,"percentage":50},{"participant_id":%d,"percentage":50}]}`, pid, pid)} {
		identityRequest(t, r, "PATCH", path, body, receipt.Token, "", "", 2, 400)
	}
	identityRequest(t, r, "PATCH", path, `{"expected_revision":1,"assignments":[{"participant_id":999999,"percentage":100}]}`, receipt.Token, "", "", 2, 404)
	identityRequest(t, r, "PATCH", path, `{"assignments":[{"person_name":"Alex","percentage":100}]}`, receipt.Token, "", "", 1, 409)
	if identitySnapshot(t, g) != before {
		t.Fatal("rejected claims changed graph")
	}
	createPath := fmt.Sprintf("/api/bills/%d/participants", receipt.ID)
	made := identityRequest(t, r, "POST", createPath, `{"client_ref":"new","name":"","expected_revision":1}`, receipt.Token, "", "", 2, 200)
	var participant struct {
		P struct {
			ID uint `json:"participant_id"`
		} `json:"participant"`
	}
	json.Unmarshal(made.Body.Bytes(), &participant)
	renamePath := fmt.Sprintf("%s/%d", createPath, participant.P.ID)
	identityRequest(t, r, "PATCH", renamePath, `{"name":"Now named","expected_revision":2}`, receipt.Token, "", "", 2, 200)
	before = identitySnapshot(t, g)
	recovery := identityRequest(t, r, "POST", createPath, `{"client_ref":"new","name":"","expected_revision":1}`, receipt.Token, "", "", 2, 200)
	if !strings.Contains(recovery.Body.String(), `"label":"Now named"`) || identitySnapshot(t, g) != before {
		t.Fatal("create recovery reset current label or graph")
	}
	identityRequest(t, r, "POST", createPath, `{"client_ref":"new","name":"Different original","expected_revision":3}`, receipt.Token, "", "", 2, 409)
	identityRequest(t, r, "PATCH", renamePath, `{"name":"Now named","expected_revision":2}`, receipt.Token, "", "", 2, 200)
}

func TestPostgresIdentity0003LegacyHistoryAndUnavailableNet(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	trip := identityNewTab(t, r, "")
	now := time.Date(2026, 11, 5, 1, 2, 3, 0, time.UTC)
	if e := g.Model(&models.Tab{}).Where("id = ?", trip.ID).Updates(map[string]any{"finalized": true, "finalized_at": now}).Error; e != nil {
		t.Fatal(e)
	}
	rows := []models.TabSettlement{{TabID: trip.ID, PersonName: "", Amount: 0, CreatedAt: now}, {TabID: trip.ID, PersonName: "Alex", Amount: 2, CreatedAt: now}, {TabID: trip.ID, PersonName: "Alex", Amount: 3, CreatedAt: now}}
	if e := g.Create(&rows).Error; e != nil {
		t.Fatal(e)
	}
	path := fmt.Sprintf("/api/tabs/%d/settlements", trip.ID)
	history := identityRequest(t, r, "GET", path, "", trip.Token, "", "", 2, 200)
	if !strings.Contains(history.Body.String(), `"identity_review_status":"legacy_identity_review_required"`) || strings.Contains(history.Body.String(), `"kind":"member"`) {
		t.Fatal("legacy labels inferred ownership")
	}
	first := identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, "", "", 1, 200)
	before := identitySnapshot(t, g)
	retry := identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, "", "", 1, 200)
	if first.Body.String() != retry.Body.String() || identitySnapshot(t, g) != before {
		t.Fatal("legacy retry regrouped raw rows")
	}
	identityRequest(t, r, "PATCH", fmt.Sprintf("%s/%d", path, rows[1].ID), `{"paid":true}`, trip.Token, "", "", 2, 200)
	var stored []models.TabSettlement
	g.Order("id ASC").Find(&stored)
	if len(stored) != 3 || stored[0].Paid || !stored[1].Paid || stored[2].Paid {
		t.Fatal("legacy exact-row marking selected by label")
	}
	active := identityNewTab(t, r, "")
	legacy := models.Bill{TabID: &active.ID, Name: "Unresolved legacy", AccessToken: "synthetic-source", Total: 10, Subtotal: 10, PersonShares: []models.PersonShare{{PersonName: "Alex", Total: 10, Subtotal: 10}}}
	if e := g.Create(&legacy).Error; e != nil {
		t.Fatal(e)
	}
	raw := identityRequest(t, r, "GET", fmt.Sprintf("/api/tabs/%d", active.ID), "", active.Token, "", "", 2, 200)
	if !strings.Contains(raw.Body.String(), `"net_balances":null`) || !strings.Contains(raw.Body.String(), `"net_balance_status":"identity_review_required"`) || !strings.Contains(raw.Body.String(), `"name":"Unresolved legacy"`) {
		t.Fatal("unresolved bill was skipped or forged zero debt")
	}
	identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", active.ID), "", active.Token, "", "", 2, 409)
	if e := g.Model(&models.Bill{}).Where("id = ?", legacy.ID).Updates(map[string]any{"currency_code": "EUR", "usd_exchange_rate": 1.25, "usd_total": 12.5, "exchange_rate_source": ""}).Error; e != nil {
		t.Fatal(e)
	}
	raw = identityRequest(t, r, "GET", fmt.Sprintf("/api/tabs/%d", active.ID), "", active.Token, "", "", 2, 200)
	if !strings.Contains(raw.Body.String(), `"total_amount":null`) || !strings.Contains(raw.Body.String(), `"total_status":"accounting_review_required"`) {
		t.Fatal("unsafe valuation advertised a numeric total")
	}
}

func TestPostgresIdentity0003Response2AtomicGuards(t *testing.T) {
	for _, fault := range []string{"response_zero", "response_multiple", "deferred_commit", "people", "bill_participants", "bill_items", "item_assignments", "person_shares", "participant_one"} {
		t.Run(fault, func(t *testing.T) {
			_, g, r, calls, _ := replayRouter(t)
			body := `{"name":"Atomic refs","subtotal":2,"total":2,"participants":[{"client_ref":"a","name":"Alex"},{"client_ref":"b","name":"Alex"}],"items":[{"name":"Line","price":2,"assignments":[{"participant_ref":"a","percentage":50},{"participant_ref":"b","percentage":50}]}]}`
			key := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{9}, 32))
			before := identitySnapshot(t, g)
			cleanup := ""
			switch fault {
			case "response_multiple":
				if err := g.Callback().Update().After("gorm:update").Register("test:identity_response_rows", func(tx *gorm.DB) {
					if values, ok := tx.Statement.Dest.(map[string]any); ok && values["creation_response"] != nil {
						tx.RowsAffected = 2
					}
				}); err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { g.Callback().Update().Remove("test:identity_response_rows") })
			case "response_zero":
				if err := g.Exec(`CREATE FUNCTION block_response() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.creation_response_version=2 THEN RETURN NULL; END IF; RETURN NEW; END $$`).Error; err != nil {
					t.Fatal(err)
				}
				if err := g.Exec(`CREATE TRIGGER block_response BEFORE UPDATE ON bills FOR EACH ROW EXECUTE FUNCTION block_response()`).Error; err != nil {
					t.Fatal(err)
				}
				cleanup = "DROP TRIGGER block_response ON bills"
			case "deferred_commit":
				if err := g.Exec(`CREATE FUNCTION block_commit() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic-private-identity-commit'; END $$`).Error; err != nil {
					t.Fatal(err)
				}
				if err := g.Exec(`CREATE CONSTRAINT TRIGGER block_commit AFTER INSERT ON bills DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION block_commit()`).Error; err != nil {
					t.Fatal(err)
				}
				cleanup = "DROP TRIGGER block_commit ON bills"
			default:
				table := fault
				condition := "true"
				if fault == "participant_one" {
					table = "bill_participants"
					condition = "NEW.client_ref = 'b'"
				}
				if err := g.Exec("CREATE FUNCTION block_child() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF " + condition + " THEN RETURN NULL; END IF; RETURN NEW; END $$").Error; err != nil {
					t.Fatal(err)
				}
				if err := g.Exec("CREATE TRIGGER block_child BEFORE INSERT ON " + table + " FOR EACH ROW EXECUTE FUNCTION block_child()").Error; err != nil {
					t.Fatal(err)
				}
				cleanup = "DROP TRIGGER block_child ON " + table
			}
			failed := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 503)
			if identitySnapshot(t, g) != before || strings.Contains(failed.Body.String(), "synthetic-private") || strings.Contains(failed.Body.String(), "participant_map") {
				t.Fatal("partial graph/receipt acknowledged or database details leaked")
			}
			if fault == "response_multiple" {
				if err := g.Callback().Update().Remove("test:identity_response_rows"); err != nil {
					t.Fatal(err)
				}
			} else {
				if err := g.Exec(cleanup).Error; err != nil {
					t.Fatal(err)
				}
			}
			first := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 201)
			retry := identityRequest(t, r, "POST", "/api/bills", body, "", "", key, 2, 201)
			if first.Body.String() != retry.Body.String() {
				t.Fatal("same-key recovery did not retain exact original receipt")
			}
			var receipt identityReceipt
			if err := json.Unmarshal(first.Body.Bytes(), &receipt); err != nil {
				t.Fatal(err)
			}
			stored := identityStored(t, g, receipt.ID)
			if string(stored.CreationResponse) != first.Body.String() || len(stored.ParticipantRows) != 2 || len(stored.PersonShares) != 2 || calls.Load() != 0 {
				t.Fatal("healthy recovery lacks one complete persisted graph/receipt")
			}
		})
	}
}

func TestPostgresIdentity0003BindingGenerationReceiptAndCurrentProof(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	trip := identityNewTab(t, r, "Creator")
	firstID, firstToken := identityJoin(t, r, trip, "Alex")
	secondID, secondToken := identityJoin(t, r, trip, "Alex")
	receipt := identityCreate(t, r, []string{"Alex", "Guest"}, false, "")
	identityAttach(t, r, trip, receipt, 0)
	pid := receipt.Map[0].ID
	path := identityParticipantPath(trip, receipt, pid)
	identityRequest(t, r, "POST", path+"/binding-request", `{"expected_revision":1}`, trip.Token, firstToken, "", 2, 200)
	reject := identityJSON(t, map[string]any{"expected_revision": 2, "request_revision": 2, "member_id": firstID, "decision": "reject"})
	identityRequest(t, r, "PUT", path+"/binding", reject, trip.Token, trip.Member, "", 2, 200)
	before := identitySnapshot(t, g)
	identityRequest(t, r, "PUT", path+"/binding", reject, trip.Token, trip.Member, "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("rejection retry invented or rewrote evidence")
	}
	identityRequest(t, r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), "", trip.Token, firstToken, "", 2, 409)
	identityRequest(t, r, "POST", path+"/binding-request", `{"expected_revision":3}`, trip.Token, secondToken, "", 2, 200)
	identityRequest(t, r, "PUT", path+"/binding", reject, trip.Token, trip.Member, "", 2, 409)
	for _, body := range []string{
		identityJSON(t, map[string]any{"expected_revision": 4, "request_revision": 2, "member_id": secondID, "decision": "approve"}),
		identityJSON(t, map[string]any{"expected_revision": 4, "request_revision": 4, "member_id": firstID, "decision": "approve"}),
	} {
		identityRequest(t, r, "PUT", path+"/binding", body, trip.Token, trip.Member, "", 2, 409)
	}
	identityRequest(t, r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), "", trip.Token, firstToken, "", 2, 409)
	approve := identityJSON(t, map[string]any{"expected_revision": 4, "request_revision": 4, "member_id": secondID, "decision": "approve"})
	identityRequest(t, r, "PUT", path+"/binding", approve, trip.Token, trip.Member, "", 2, 200)
	stored := identityStored(t, g, receipt.ID)
	var shareID uint
	for _, s := range stored.PersonShares {
		if s.ParticipantID != nil && *s.ParticipantID == pid {
			shareID = s.ID
		}
	}
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", receipt.ID, shareID), `{"paid":true}`, receipt.Token, "", "", 2, 200)
	identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
	before = identitySnapshot(t, g)
	identityRequest(t, r, "PUT", path+"/binding", approve, trip.Token, trip.Member, "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("paid/finalized exact receipt retry changed state")
	}
	// Current proof mode can change for the same authenticated actor. It cannot
	// rewrite the original creator kind/time or use the receipt as a credential.
	if err := g.Model(&models.TabMember{}).Where("id = ?", trip.MemberID).UpdateColumn("role", "member").Error; err != nil {
		t.Fatal(err)
	}
	identityRequest(t, r, "PUT", path+"/binding", approve, trip.Token, trip.Member, "", 2, 403)
	withSource := identityJSON(t, map[string]any{"expected_revision": 4, "request_revision": 4, "member_id": secondID, "decision": "approve", "bill_token": receipt.Token})
	identityRequest(t, r, "PUT", path+"/binding", withSource, trip.Token, secondToken, "", 2, 409)
	before = identitySnapshot(t, g)
	identityRequest(t, r, "PUT", path+"/binding", withSource, trip.Token, trip.Member, "", 2, 200)
	if identitySnapshot(t, g) != before {
		t.Fatal("current sufficient source proof rewrote original receipt kind/time")
	}
	identityRequest(t, r, "PUT", path+"/binding", withSource, trip.Token, "invalid-current-proof", "", 2, 403)
	// The old rejected target is releasable only after the bounded receipt has
	// actually been replaced and no current/snapshot reference remains.
	identityRequest(t, r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), "", trip.Token, firstToken, "", 2, 200)
	identityRequest(t, r, "DELETE", fmt.Sprintf("/api/tabs/%d/members/me", trip.ID), "", trip.Token, secondToken, "", 2, 409)
}

func TestPostgresIdentity0003FullRosterRecoveryAndRevisionOverflow(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	trip := identityNewTab(t, r, "Creator")
	labels := make([]string, 100)
	for i := range labels {
		labels[i] = fmt.Sprint("Label", i)
	}
	b := identityCreate(t, r, labels, false, "")
	pid := b.Map[0].ID
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/participants/%d", b.ID, pid), `{"name":"Renamed","expected_revision":0}`, b.Token, "", "", 2, 200)
	identityAttach(t, r, trip, b, 1)
	stored := identityStored(t, g, b.ID)
	identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", b.ID, stored.PersonShares[0].ID), `{"paid":true}`, b.Token, "", "", 2, 200)
	identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
	before := identitySnapshot(t, g)
	path := fmt.Sprintf("/api/tabs/%d/bills/%d/participants", trip.ID, b.ID)
	w := identityRequest(t, r, "POST", path, `{"client_ref":"ref_0","name":"Label0","expected_revision":0}`, trip.Token, trip.Member, "", 2, 200)
	if !strings.Contains(w.Body.String(), `"label":"Renamed"`) || !strings.Contains(w.Body.String(), fmt.Sprintf(`"participant_id":%d`, pid)) || identitySnapshot(t, g) != before {
		t.Fatal("full paid/finalized roster recovery recreated or reset original participant")
	}
	identityRequest(t, r, "POST", path, `{"client_ref":"ref_0","name":"Renamed","expected_revision":0}`, trip.Token, trip.Member, "", 2, 409)
	identityRequest(t, r, "POST", path, `{"client_ref":"new","name":"New","expected_revision":2}`, trip.Token, trip.Member, "", 2, 400)
	identityRequest(t, r, "POST", path, `{"client_ref":"ref_0","name":"Label0","expected_revision":0}`, trip.Token, "bad-current-proof", "", 2, 403)
	if identitySnapshot(t, g) != before {
		t.Fatal("rejected recovery changed state")
	}

	edge := identityCreate(t, r, []string{"Edge"}, true, "")
	if err := g.Model(&models.Bill{}).Where("id = ?", edge.ID).UpdateColumn("identity_revision", int64(math.MaxInt64)).Error; err != nil {
		t.Fatal(err)
	}
	stored = identityStored(t, g, edge.ID)
	before = identitySnapshot(t, g)
	claim := fmt.Sprintf(`{"expected_revision":%d,"assignments":[{"participant_id":%d,"percentage":100}]}`, int64(math.MaxInt64), edge.Map[0].ID)
	claimPath := fmt.Sprintf("/api/bills/%d/items/%d/assignments", edge.ID, stored.Items[0].ID)
	identityRequest(t, r, "PATCH", claimPath, claim, edge.Token, "", "", 2, 200)
	renamePath := fmt.Sprintf("/api/bills/%d/participants/%d", edge.ID, edge.Map[0].ID)
	identityRequest(t, r, "PATCH", renamePath, fmt.Sprintf(`{"expected_revision":%d,"name":"Edge"}`, int64(math.MaxInt64)), edge.Token, "", "", 2, 200)
	identityRequest(t, r, "PATCH", claimPath, fmt.Sprintf(`{"expected_revision":%d,"assignments":[]}`, int64(math.MaxInt64)), edge.Token, "", "", 2, 409)
	identityRequest(t, r, "PATCH", renamePath, fmt.Sprintf(`{"expected_revision":%d,"name":"Changed"}`, int64(math.MaxInt64)), edge.Token, "", "", 2, 409)
	identityRequest(t, r, "POST", fmt.Sprintf("/api/bills/%d/participants", edge.ID), fmt.Sprintf(`{"expected_revision":%d,"client_ref":"new","name":"New"}`, int64(math.MaxInt64)), edge.Token, "", "", 2, 409)
	if identitySnapshot(t, g) != before {
		t.Fatal("overflow/no-op paths changed identity, children, or timestamps")
	}
}

func TestPostgresIdentity0003MalformedReadyGraphAndMixedHistory(t *testing.T) {
	for _, corruption := range []string{"missing_share", "legacy_share", "legacy_assignment", "mixed_snapshot", "missing_snapshot"} {
		t.Run(corruption, func(t *testing.T) {
			_, g, r, _, _ := replayRouter(t)
			trip := identityNewTab(t, r, "Creator")
			b := identityCreate(t, r, []string{"Alex", "Alex"}, false, "")
			identityAttach(t, r, trip, b, 0)
			stored := identityStored(t, g, b.ID)
			if corruption == "mixed_snapshot" || corruption == "missing_snapshot" {
				identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
				if corruption == "mixed_snapshot" {
					if err := g.Exec("UPDATE tab_settlements SET snapshot_version=1,member_id=NULL,participant_id=NULL WHERE id=(SELECT min(id) FROM tab_settlements WHERE tab_id=?)", trip.ID).Error; err != nil {
						t.Fatal(err)
					}
				} else if err := g.Where("tab_id = ?", trip.ID).Delete(&models.TabSettlement{}).Error; err != nil {
					t.Fatal(err)
				}
				before := identitySnapshot(t, g)
				history := identityRequest(t, r, "GET", fmt.Sprintf("/api/tabs/%d/settlements", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
				if !strings.Contains(history.Body.String(), `"identity_review_status":"identity_review_required"`) {
					t.Fatalf("invalid snapshot advertised available history: %s", history.Body)
				}
				identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 409)
				if corruption == "mixed_snapshot" {
					var rows []models.TabSettlement
					if err := g.Where("tab_id = ?", trip.ID).Order("id ASC").Find(&rows).Error; err != nil {
						t.Fatal(err)
					}
					if len(rows) != 2 || !strings.Contains(history.Body.String(), fmt.Sprintf(`"id":%d`, rows[0].ID)) {
						t.Fatal("safe mixed raw history disappeared")
					}
					identityRequest(t, r, "PATCH", fmt.Sprintf("/api/tabs/%d/settlements/%d", trip.ID, rows[0].ID), `{"paid":true}`, trip.Token, trip.Member, "", 2, 409)
				}
				if identitySnapshot(t, g) != before {
					t.Fatal("invalid snapshot was regenerated or marked paid")
				}
				return
			}
			switch corruption {
			case "missing_share":
				if err := g.Delete(&stored.PersonShares[0]).Error; err != nil {
					t.Fatal(err)
				}
			case "legacy_share":
				if err := g.Model(&models.PersonShare{}).Where("id = ?", stored.PersonShares[0].ID).UpdateColumns(map[string]any{"identity_version": 1, "participant_id": nil}).Error; err != nil {
					t.Fatal(err)
				}
			case "legacy_assignment":
				if err := g.Model(&models.ItemAssignment{}).Where("id = ?", stored.Items[0].Assignments[0].ID).UpdateColumns(map[string]any{"identity_version": 1, "participant_id": nil}).Error; err != nil {
					t.Fatal(err)
				}
			}
			before := identitySnapshot(t, g)
			raw := identityRequest(t, r, "GET", fmt.Sprintf("/api/tabs/%d", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
			if !strings.Contains(raw.Body.String(), `"net_balances":null`) || !strings.Contains(raw.Body.String(), `"identity_review_status":"identity_review_required"`) || !strings.Contains(raw.Body.String(), `"total_amount":2`) || !strings.Contains(raw.Body.String(), `"name":"Reference receipt"`) {
				t.Fatalf("inconsistent ready graph was hidden or computed: %s", raw.Body)
			}
			identityRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 409)
			claim := fmt.Sprintf(`{"expected_revision":1,"assignments":[]}`)
			identityRequest(t, r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/items/%d/assignments", trip.ID, b.ID, stored.Items[0].ID), claim, trip.Token, trip.Member, "", 2, 409)
			if identitySnapshot(t, g) != before {
				t.Fatal("malformed current graph was silently repaired or finalized")
			}
		})
	}
}
