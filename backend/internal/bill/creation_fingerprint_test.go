package bill

import (
	"encoding/hex"
	"encoding/json"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestCreationFingerprintFrozenGoldenBytes(t *testing.T) {
	var vectors []struct{ Name, Body, BytesHex, SHA256 string }
	data, err := os.ReadFile("testdata/creation-v1.json")
	if err != nil {
		t.Fatal(err)
	}
	// Explicit wire keys keep the fixture independent of Go field naming.
	var raw []map[string]string
	if err = json.Unmarshal(data, &raw); err != nil {
		t.Fatal(err)
	}
	for _, v := range raw {
		vectors = append(vectors, struct{ Name, Body, BytesHex, SHA256 string }{v["name"], v["body"], v["bytes_hex"], v["sha256"]})
	}
	for _, v := range vectors {
		t.Run(v.Name, func(t *testing.T) {
			b, err := decodeCreateBill(httptest.NewRecorder(), httptest.NewRequest("POST", "/", strings.NewReader(v.Body)))
			if err != nil {
				t.Fatal(err)
			}
			if err = normalizeCreation(b); err != nil {
				t.Fatal(err)
			}
			digest := creationFingerprint(b)
			if hex.EncodeToString(creationEncoding(b)) != v.BytesHex || hex.EncodeToString(digest[:]) != v.SHA256 {
				t.Fatal("frozen format1 bytes/digest changed")
			}
		})
	}
}
func TestCreationFingerprintDecodedCompatibilityAndOrder(t *testing.T) {
	fingerprint := func(body string) string {
		t.Helper()
		b, err := decodeCreateBill(httptest.NewRecorder(), httptest.NewRequest("POST", "/", strings.NewReader(body)))
		if err != nil {
			t.Fatal(err)
		}
		if err = normalizeCreation(b); err != nil {
			t.Fatal(err)
		}
		v := creationFingerprint(b)
		return hex.EncodeToString(v[:])
	}
	base := fingerprint(`{"name":"Receipt","subtotal":0,"total":0}`)
	for _, body := range []string{
		`{"name":"discarded","NAME":" <b>Receipt</b> ","subtotal":0,"total":-0,"tax":null,"tip_amount":null,"tip_percentage":null,"currency_code":null,"display_currency":null,"participants":null,"items":null,"person_shares":null,"payment_methods":null}`,
		`{"name":"Receipt","subtotal":-0,"total":0,"currency_code":" usd ","display_currency":"USD","participants":[],"items":[],"person_shares":[],"payment_methods":[]}`,
	} {
		if fingerprint(body) != base {
			t.Fatal("decoded defaults/null/case/duplicate/-0 semantics changed")
		}
	}
	first := `{"name":"é","subtotal":3,"total":3,"items":[{"name":"Repeated","price":1},{"name":"Repeated","price":2}]}`
	second := strings.Replace(first, `"price":1},{"name":"Repeated","price":2`, `"price":2},{"name":"Repeated","price":1`, 1)
	if fingerprint(first) == fingerprint(second) {
		t.Fatal("ordered repeated lines collapsed")
	}
	if fingerprint(first) == fingerprint(strings.Replace(first, "é", "e\u0301", 1)) {
		t.Fatal("Unicode normalization changed attempted identity")
	}
}
