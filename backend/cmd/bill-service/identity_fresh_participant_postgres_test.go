//go:build integration

package main

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"testing"
)

// A member who adds themselves to an attached receipt gets an unbound row. No
// request field and no call of their own can confirm it: confirmation is the
// recorded request plus a creator (or source) decision. This is the supported
// contract; atomic self-confirmation does not exist.
func TestPostgresIdentity0003FreshParticipantIsUnboundUntilApproved(t *testing.T) {
	_, g, r, _, _ := replayRouter(t)
	trip := identityNewTab(t, r, "Creator")
	memberID, member := identityJoin(t, r, trip, "Alex")
	_, other := identityJoin(t, r, trip, "Alex")
	receipt := identityCreate(t, r, []string{"Guest"}, true, "")
	identityAttach(t, r, trip, receipt, 0)
	path := fmt.Sprintf("/api/tabs/%d/bills/%d/participants", trip.ID, receipt.ID)
	type view struct {
		Participant struct {
			ID      uint   `json:"participant_id"`
			State   string `json:"binding_state"`
			Member  *uint  `json:"member_id"`
			Pending *uint  `json:"pending_member_id"`
		} `json:"participant"`
		Revision int64 `json:"identity_revision"`
	}
	read := func(w *httptest.ResponseRecorder) view {
		t.Helper()
		var v view
		if err := json.Unmarshal(w.Body.Bytes(), &v); err != nil || v.Participant.ID == 0 {
			t.Fatalf("participant response: %v %s", err, w.Body)
		}
		return v
	}

	before := identitySnapshot(t, g)
	for _, body := range []string{
		fmt.Sprintf(`{"client_ref":"me","name":"Alex","expected_revision":1,"member_id":%d}`, memberID),
		`{"client_ref":"me","name":"Alex","expected_revision":1,"bind_self":true}`,
		`{"client_ref":"me","name":"Alex","expected_revision":1,"binding_state":"confirmed"}`,
	} {
		identityRequest(t, r, "POST", path, body, trip.Token, member, "", 2, 400)
	}
	if identitySnapshot(t, g) != before {
		t.Fatal("rejected self-confirming create changed state")
	}

	made := read(identityRequest(t, r, "POST", path, `{"client_ref":"me","name":"Alex","expected_revision":1}`, trip.Token, member, "", 2, 200))
	if made.Participant.State != "unbound" || made.Participant.Member != nil || made.Participant.Pending != nil || made.Revision != 2 {
		t.Fatalf("fresh participant was not created unbound: %+v", made)
	}
	own := identityParticipantPath(trip, receipt, made.Participant.ID)
	approve := func(revision int64, id uint) string {
		return identityJSON(t, map[string]any{"expected_revision": revision, "request_revision": revision, "member_id": id, "decision": "approve"})
	}
	// Neither the member nor a same-name member can decide a binding.
	before = identitySnapshot(t, g)
	identityRequest(t, r, "PUT", own+"/binding", approve(2, memberID), trip.Token, member, "", 2, 403)
	identityRequest(t, r, "PUT", own+"/binding", approve(2, memberID), trip.Token, other, "", 2, 403)
	if identitySnapshot(t, g) != before {
		t.Fatal("member decision changed state")
	}

	requested := read(identityRequest(t, r, "POST", own+"/binding-request", `{"expected_revision":2}`, trip.Token, member, "", 2, 200))
	if requested.Participant.State != "pending" || requested.Participant.Member != nil || requested.Participant.Pending == nil || *requested.Participant.Pending != memberID {
		t.Fatalf("request did not stay pending: %+v", requested)
	}
	identityRequest(t, r, "PUT", own+"/binding", approve(3, memberID), trip.Token, member, "", 2, 403)
	confirmed := read(identityRequest(t, r, "PUT", own+"/binding", approve(3, memberID), trip.Token, trip.Member, "", 2, 200))
	if confirmed.Participant.State != "confirmed" || confirmed.Participant.Member == nil || *confirmed.Participant.Member != memberID || confirmed.Revision != 4 {
		t.Fatalf("creator approval did not confirm the requester: %+v", confirmed)
	}

	// The creator has no shortcut either: the same three recorded steps apply.
	mine := read(identityRequest(t, r, "POST", path, `{"client_ref":"creator","name":"Creator","expected_revision":4}`, trip.Token, trip.Member, "", 2, 200))
	if mine.Participant.State != "unbound" {
		t.Fatalf("creator create was not unbound: %+v", mine)
	}
	creatorPath := identityParticipantPath(trip, receipt, mine.Participant.ID)
	identityRequest(t, r, "PUT", creatorPath+"/binding", approve(5, trip.MemberID), trip.Token, trip.Member, "", 2, 409)
	identityRequest(t, r, "POST", creatorPath+"/binding-request", `{"expected_revision":5}`, trip.Token, trip.Member, "", 2, 200)
	self := read(identityRequest(t, r, "PUT", creatorPath+"/binding", approve(6, trip.MemberID), trip.Token, trip.Member, "", 2, 200))
	if self.Participant.State != "confirmed" || self.Participant.Member == nil || *self.Participant.Member != trip.MemberID {
		t.Fatalf("creator self approval failed: %+v", self)
	}
	stored := identityStored(t, g, receipt.ID)
	kinds := map[uint]string{}
	for _, p := range stored.ParticipantRows {
		if p.ApprovalKind != nil {
			kinds[p.ID] = *p.ApprovalKind
		}
	}
	if len(kinds) != 2 || kinds[made.Participant.ID] != "creator" || kinds[mine.Participant.ID] != "creator" {
		t.Fatalf("stored approval evidence: %v", kinds)
	}
}
