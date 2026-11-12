//go:build integration

package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"encoding/json"
	"fmt"
	"testing"
)

func TestPostgresPaidParticipantAdditionConflict(t *testing.T) {
	db := authorizationPostgres(t)
	r := lifecycleRouter(db)
	bh := billpkg.NewBillHandler(billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{}))
	r.POST("/api/bills/:id/participants", bh.CreateParticipant)
	r.PATCH("/api/bills/:id/participants/:participantId", bh.RenameParticipant)
	th := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/tabs/:id/bills/:billId/participants", th.CreateParticipant)
	create := versionAuthRequest(r, "POST", "/api/bills", `{"name":"Meal","subtotal":10,"total":10,"participants":[{"client_ref":"a","name":"Alex"}],"items":[{"name":"Meal","price":10,"assignments":[{"participant_ref":"a","percentage":100}]}]}`, "", "", 2)
	if create.Code != 201 {
		t.Fatalf("create=%d %s", create.Code, create.Body.String())
	}
	var created struct {
		BillID uint   `json:"bill_id"`
		Token  string `json:"access_token"`
	}
	if err := json.Unmarshal(create.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	path := fmt.Sprintf("/api/bills/%d/participants", created.BillID)
	body := `{"client_ref":"b","name":"Sam","expected_revision":0}`
	add := versionAuthRequest(r, "POST", path, body, created.Token, "", 2)
	if add.Code != 200 {
		t.Fatalf("unpaid addition=%d %s", add.Code, add.Body.String())
	}
	var added struct {
		Participant struct {
			ID uint `json:"participant_id"`
		} `json:"participant"`
	}
	if err := json.Unmarshal(add.Body.Bytes(), &added); err != nil {
		t.Fatal(err)
	}
	b, err := billpkg.NewBillRepository(db).GetById(created.BillID)
	if err != nil {
		t.Fatal(err)
	}
	if len(b.PersonShares) != 1 {
		t.Fatal("expected allocated share")
	}
	paid := versionAuthRequest(r, "PATCH", fmt.Sprintf("/api/bills/%d/shares/%d", b.ID, b.PersonShares[0].ID), `{"paid":true}`, created.Token, "", 2)
	if paid.Code != 200 {
		t.Fatalf("mark paid=%d %s", paid.Code, paid.Body.String())
	}
	before := lifecycleSnapshot(t, db)
	for attempt := 0; attempt < 2; attempt++ {
		blocked := versionAuthRequest(r, "POST", path, `{"client_ref":"c","name":"Pat","expected_revision":1}`, created.Token, "", 2)
		var failure map[string]string
		if err := json.Unmarshal(blocked.Body.Bytes(), &failure); err != nil {
			t.Fatal(err)
		}
		if blocked.Code != 409 || failure["code"] != "participants_locked_paid" || failure["error"] != "participants cannot be added after a share is paid" {
			t.Fatalf("paid addition=%d %s", blocked.Code, blocked.Body.String())
		}
		if lifecycleSnapshot(t, db) != before {
			t.Fatal("failed addition changed state")
		}
	}
	retry := versionAuthRequest(r, "POST", path, body, created.Token, "", 2)
	if retry.Code != 200 || retry.Body.String() != add.Body.String() {
		t.Fatalf("paid exact retry changed: %d %s", retry.Code, retry.Body.String())
	}
	if lifecycleSnapshot(t, db) != before {
		t.Fatal("exact retry changed state")
	}
	stale := versionAuthRequest(r, "POST", path, `{"client_ref":"c","name":"Pat","expected_revision":0}`, created.Token, "", 2)
	if stale.Code != 409 || !json.Valid(stale.Body.Bytes()) {
		t.Fatal("stale request no longer conflicts")
	}
	var failure map[string]string
	if err := json.Unmarshal(stale.Body.Bytes(), &failure); err != nil || failure["code"] != "identity_revision_conflict" {
		t.Fatal("stale conflict changed")
	}
	rename := versionAuthRequest(r, "PATCH", fmt.Sprintf("%s/%d", path, added.Participant.ID), `{"name":"Renamed","expected_revision":1}`, created.Token, "", 2)
	if rename.Code != 200 {
		t.Fatalf("paid label rename=%d %s", rename.Code, rename.Body.String())
	}

	// The shared transition reports the same non-retryable conflict after attachment.
	tab := models.Tab{Name: "Trip", AccessToken: "l9-paid-tab"}
	saveAuthFixture(t, db, &tab)
	attach := versionAuthRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", tab.ID), fmt.Sprintf(`{"bill_id":%d,"bill_token":%q,"expected_revision":2}`, b.ID, created.Token), "l9-paid-tab", "", 2)
	if attach.Code != 200 {
		t.Fatalf("paid attachment=%d %s", attach.Code, attach.Body.String())
	}
	before = lifecycleSnapshot(t, db)
	attached := versionAuthRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills/%d/participants", tab.ID, b.ID), `{"client_ref":"c","name":"Pat","expected_revision":3}`, "l9-paid-tab", "", 2)
	if err := json.Unmarshal(attached.Body.Bytes(), &failure); err != nil || attached.Code != 409 || failure["code"] != "participants_locked_paid" {
		t.Fatalf("attached paid addition=%d %s", attached.Code, attached.Body.String())
	}
	if lifecycleSnapshot(t, db) != before {
		t.Fatal("attached rejection changed state")
	}
}
