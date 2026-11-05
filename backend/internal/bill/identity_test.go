package bill

import (
	"backend/pkg/models"
	"encoding/hex"
	"encoding/json"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestIdentity0003Fingerprint2Golden(t *testing.T) {
	data, err := os.ReadFile("testdata/creation-v2.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors []struct{ Name, Body, BytesHex, SHA256 string }
	var raw []map[string]string
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatal(err)
	}
	for _, v := range raw {
		vectors = append(vectors, struct{ Name, Body, BytesHex, SHA256 string }{v["name"], v["body"], v["bytes_hex"], v["sha256"]})
	}
	for _, v := range vectors {
		t.Run(v.Name, func(t *testing.T) {
			req := httptest.NewRequest("POST", "/", strings.NewReader(v.Body))
			req.Header.Set("X-Billington-Identity-Version", "2")
			b, err := decodeCreateBill(httptest.NewRecorder(), req)
			if err != nil {
				t.Fatal(err)
			}
			if err := normalizeCreation(b); err != nil {
				t.Fatal(err)
			}
			digest := creationFingerprint(b)
			if hex.EncodeToString(creationEncoding(b)) != v.BytesHex || hex.EncodeToString(digest[:]) != v.SHA256 {
				t.Fatal("frozen format2 reference/float/order encoding drift")
			}
			b.ID = 999
			b.IdentityVersion = 2
			b.IdentityRevision = 100
			for i := range b.Participants {
				b.Participants[i].ID = uint(700 + i)
			}
			if creationFingerprint(b) != digest {
				t.Fatal("storage identity/revision entered the document fingerprint")
			}
		})
	}
}

func TestIdentity0003RenameStableMoneyKeys(t *testing.T) {
	first, second := uint(1), uint(2)
	billID := uint(1)
	zero, one := int64(0), int64(1)
	stamp := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	b := models.Bill{ID: billID, IdentityVersion: 2, IdentityState: "ready", Subtotal: .01, Total: .01, CurrencyCode: "USD", USDExchangeRate: 1, USDTotal: .01, ExchangeRateSource: "native-usd", ParticipantRows: []models.BillParticipant{{ID: first, BillID: billID, IdentityVersion: 2, Label: "Z", AllocationLabel: "Z", Ordinal: &zero}, {ID: second, BillID: billID, IdentityVersion: 2, Label: "A", AllocationLabel: "A", Ordinal: &one}}, Items: []models.BillItem{{ID: 1, BillID: billID, Name: "Cent", Price: .01, Assignments: []models.ItemAssignment{{ID: 1, BillItemID: 1, BillID: &billID, IdentityVersion: 2, ParticipantID: &first, PersonName: "Z", Percentage: 50, CreatedAt: stamp}, {ID: 2, BillItemID: 1, BillID: &billID, IdentityVersion: 2, ParticipantID: &second, PersonName: "A", Percentage: 50, CreatedAt: stamp}}}}}
	before, err := BuildPersonShares(&b)
	if err != nil {
		t.Fatal(err)
	}
	amounts := map[uint]float64{}
	for _, s := range before {
		amounts[*s.ParticipantID] = s.Total
	}
	if amounts[first] != .01 || amounts[second] != 0 {
		t.Fatal("local tie contract changed")
	}
	b.PersonShares = []models.PersonShare{{ID: 1, BillID: billID, IdentityVersion: 2, ParticipantID: &first, PersonName: "Z", Total: .005}, {ID: 2, BillID: billID, IdentityVersion: 2, ParticipantID: &second, PersonName: "A", Total: .005}}
	usd, err := FrozenUSDShareCents(b)
	if err != nil || !reflect.DeepEqual(usd, []int64{0, 1}) {
		t.Fatal("frozen USD raw allocation-label tie changed")
	}
	b.ParticipantRows[0].Label = "A"
	b.ParticipantRows[1].Label = "Z"
	after, err := BuildPersonShares(&b)
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range after {
		if s.Total != amounts[*s.ParticipantID] {
			t.Fatal("rename changed local penny allocation")
		}
	}
	next, err := FrozenUSDShareCents(b)
	if err != nil || !reflect.DeepEqual(usd, next) {
		t.Fatal("rename changed frozen USD pennies")
	}
}
