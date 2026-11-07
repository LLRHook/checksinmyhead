//go:build integration

package main

import (
	"backend/pkg/models"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestPostgresIdentityBReviewSettlementWireStatus(t *testing.T) {
	for _, kind := range []string{"active_empty", "valid_reference", "valid_legacy_duplicate_blank", "missing_finalized", "mixed", "fractional"} {
		t.Run(kind, func(t *testing.T) {
			_, g, r, _, _ := replayRouter(t)
			trip := identityNewTab(t, r, "Creator")
			if kind != "active_empty" {
				b := identityCreate(t, r, []string{"Alex", "Bea"}, false, "")
				identityAttach(t, r, trip, b, 0)
				identityRequest(t, r, http.MethodPost, fmt.Sprintf("/api/tabs/%d/finalize", trip.ID), "", trip.Token, trip.Member, "", 2, 200)
				switch kind {
				case "valid_legacy_duplicate_blank":
					if err := g.Exec("UPDATE tab_settlements SET snapshot_version=1,member_id=NULL,participant_id=NULL,person_name='' WHERE tab_id=?", trip.ID).Error; err != nil {
						t.Fatal(err)
					}
				case "missing_finalized":
					if err := g.Where("tab_id=?", trip.ID).Delete(&models.TabSettlement{}).Error; err != nil {
						t.Fatal(err)
					}
				case "mixed":
					if err := g.Exec("UPDATE tab_settlements SET snapshot_version=1,member_id=NULL,participant_id=NULL WHERE id=(SELECT min(id) FROM tab_settlements WHERE tab_id=?)", trip.ID).Error; err != nil {
						t.Fatal(err)
					}
				case "fractional":
					if err := g.Exec("UPDATE tab_settlements SET amount=0.001 WHERE tab_id=?", trip.ID).Error; err != nil {
						t.Fatal(err)
					}
				}
			}
			before := identitySnapshot(t, g)
			path := fmt.Sprintf("/api/tabs/%d/settlements", trip.ID)
			want, status := "ready", 200
			if kind == "valid_legacy_duplicate_blank" {
				want = "legacy_identity_review_required"
			}
			if kind == "missing_finalized" || kind == "mixed" || kind == "fractional" {
				want = "identity_review_required"
				status = 409
			}
			modern := identityRequest(t, r, http.MethodGet, path, "", trip.Token, trip.Member, "", 2, 200)
			if !strings.Contains(modern.Body.String(), want) {
				t.Fatal("wire2 history review status lost")
			}
			for _, v := range []int{0, 1} {
				legacy := identityRequest(t, r, http.MethodGet, path, "", trip.Token, trip.Member, "", v, status)
				if status == 409 && !strings.Contains(legacy.Body.String(), "client_upgrade_required") {
					t.Fatal("wire1 review response is not actionable")
				}
				if status == 200 {
					var rows []models.TabSettlement
					if err := json.Unmarshal(legacy.Body.Bytes(), &rows); err != nil {
						t.Fatal("valid wire1 array changed shape")
					}
					if kind != "active_empty" && len(rows) != 2 {
						t.Fatal("valid raw snapshot rows lost")
					}
				}
			}
			if identitySnapshot(t, g) != before {
				t.Fatal("history read changed stored rows")
			}
		})
	}
}

func TestPostgresIdentityBReviewMalformedMemberJoin(t *testing.T) {
	for _, query := range []string{"?m=%ZZ", "?%6d=%ZZ", "?m=known&x=%ZZ"} {
		t.Run(query, func(t *testing.T) {
			_, g, r, _, _ := replayRouter(t)
			trip := identityNewTab(t, r, "Creator")
			var before, after int64
			if err := g.Model(&models.TabMember{}).Where("tab_id=?", trip.ID).Count(&before).Error; err != nil {
				t.Fatal(err)
			}
			req := httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/tabs/%d/join%s", trip.ID, query), strings.NewReader(identityJSON(t, map[string]any{"display_name": "Alex"})))
			req.Header.Set("Authorization", "Bearer "+trip.Token)
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("X-Billington-Identity-Version", "2")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if err := g.Model(&models.TabMember{}).Where("tab_id=?", trip.ID).Count(&after).Error; err != nil {
				t.Fatal(err)
			}
			if w.Code != 403 || after != before || strings.Contains(w.Body.String(), "member_token") {
				t.Fatalf("malformed supplied proof minted membership: status=%d count_delta=%d", w.Code, after-before)
			}
		})
	}
	t.Run("ordinary_join_and_header_retry", func(t *testing.T) {
		_, g, r, _, _ := replayRouter(t)
		trip := identityNewTab(t, r, "Creator")
		path := fmt.Sprintf("/api/tabs/%d/join", trip.ID)
		w := identityRequest(t, r, http.MethodPost, path, identityJSON(t, map[string]any{"display_name": "Alex"}), trip.Token, "", "", 2, 201)
		var joined map[string]any
		if err := json.Unmarshal(w.Body.Bytes(), &joined); err != nil {
			t.Fatal(err)
		}
		token, ok := joined["member_token"].(string)
		if !ok || token == "" {
			t.Fatal("healthy join missing credential")
		}
		before := identitySnapshot(t, g)
		retry := identityRequest(t, r, http.MethodPost, path+"?m=%ZZ", "", trip.Token, token, "", 2, 200)
		if !strings.Contains(retry.Body.String(), token) || identitySnapshot(t, g) != before {
			t.Fatal("valid header retry lost precedence or duplicated member")
		}
	})
}

func TestPostgresIdentityBReviewBillAllocationRead(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	b := identityCreate(t, r, []string{"Alex"}, false, "")
	stored := identityStored(t, g, b.ID)
	if err := g.Model(&models.PersonShare{}).Where("id=?", stored.PersonShares[0].ID).UpdateColumn("total", 20).Error; err != nil {
		t.Fatal(err)
	}
	before := identitySnapshot(t, g)
	path := fmt.Sprintf("/api/bills/%d", b.ID)
	modern := identityRequest(t, r, http.MethodGet, path, "", b.Token, "", "", 2, 200)
	var v map[string]any
	if err := json.Unmarshal(modern.Body.Bytes(), &v); err != nil {
		t.Fatal(err)
	}
	if v["accounting_review_status"] != "accounting_review_required" || v["total"] != float64(1) {
		t.Fatal("invalid allocation labelled available or valid receipt changed")
	}
	identityRequest(t, r, http.MethodGet, path, "", b.Token, "", "", 1, 409)
	if identitySnapshot(t, g) != before {
		t.Fatal("raw read repaired stored financial evidence")
	}
}
