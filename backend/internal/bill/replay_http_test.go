package bill

import (
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func creationHTTP(t *testing.T, repo BillRepository, headers http.Header, body string) *httptest.ResponseRecorder {
	t.Helper()
	h := NewBillHandler(NewBillService(repo, &fakeExchangeRateProvider{}))
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(body))
	c.Request.Header = headers
	h.CreateBill(c)
	return w
}

func TestReplayHTTPRejectsEveryMalformedParsedKey(t *testing.T) {
	key := base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	cases := []http.Header{
		{"Idempotency-Key": {}}, {"Idempotency-Key": {""}}, {"Idempotency-Key": {key, key}},
		{"Idempotency-Key": {key}, "idempotency-key": {key}}, {"Idempotency-Key": {key + "," + key}},
		{"Idempotency-Key": {" " + key}}, {"Idempotency-Key": {key + " "}}, {"Idempotency-Key": {key + "="}},
		{"Idempotency-Key": {key[:42] + "B"}}, {"Idempotency-Key": {key[:42] + "é"}}, {"Idempotency-Key": {key[:20] + "\n" + key[21:]}},
	}
	for i, header := range cases {
		t.Run(string(rune('a'+i)), func(t *testing.T) {
			repo := newMockRepo()
			w := creationHTTP(t, repo, header, `{"name":"Receipt","subtotal":10,"total":10}`)
			if w.Code != 400 || len(repo.bills) != 0 {
				t.Fatalf("malformed supplied key accepted: status=%d rows=%d", w.Code, len(repo.bills))
			}
		})
	}
}

func TestCreationResponseCapabilityIsNoStore(t *testing.T) {
	w := creationHTTP(t, newMockRepo(), http.Header{}, `{"name":"Receipt","subtotal":10,"total":10}`)
	if w.Code != 201 || !privateNoStore(w.Header().Get("Cache-Control")) {
		t.Fatalf("creation capability caching: status=%d cache=%q", w.Code, w.Header().Get("Cache-Control"))
	}
}

func privateNoStore(value string) bool {
	directives := map[string]bool{}
	for _, token := range strings.Split(value, ",") {
		directives[strings.TrimSpace(strings.ToLower(token))] = true
	}
	return directives["private"] && directives["no-store"] && !directives["public"]
}
