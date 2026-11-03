package currency

import (
	"encoding/json"
	"os"
	"regexp"
	"strings"
	"testing"
)

func TestReceiptPolicyMatchesBothMobileSelectors(t *testing.T) {
	data, err := os.ReadFile("testdata/receipts.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixtures []struct {
		Code string  `json:"code"`
		Rate float64 `json:"usd_rate"`
	}
	if err := json.Unmarshal(data, &fixtures); err != nil {
		t.Fatal(err)
	}
	codes := map[string]bool{}
	for _, f := range fixtures {
		if codes[f.Code] || !ReceiptSupported(f.Code) || f.Rate <= 0 {
			t.Fatalf("invalid fixture %+v", f)
		}
		codes[f.Code] = true
	}
	if len(codes) != 12 {
		t.Fatalf("policy fixture size=%d", len(codes))
	}
	for _, code := range []string{"ZAR", "ZZZ", "eur", "", "US", "US1", "USDD"} {
		if ReceiptSupported(code) {
			t.Fatalf("unapproved receipt currency %q", code)
		}
	}
	for _, file := range []struct{ path, marker string }{
		{"../../../mobile/lib/screens/quick_split/bill_entry/models/bill_data.dart", "static const supportedCurrencies = <String, String>{"},
		{"../../../mobile/lib/screens/tabs/tab_detail_screen.dart", "const currencies = {"},
	} {
		data, err := os.ReadFile(file.path)
		if err != nil {
			t.Fatal(err)
		}
		_, tail, ok := strings.Cut(string(data), file.marker)
		if !ok {
			t.Fatalf("missing selector %s", file.path)
		}
		body, _, ok := strings.Cut(tail, "};")
		if !ok {
			t.Fatal("unterminated selector")
		}
		matches := regexp.MustCompile(`'([A-Z]{3})':`).FindAllStringSubmatch(body, -1)
		actual := map[string]bool{}
		for _, m := range matches {
			if !codes[m[1]] {
				t.Fatalf("selector drift %s: %s", file.path, m[1])
			}
			actual[m[1]] = true
		}
		if len(actual) != len(codes) {
			t.Fatalf("selector %s has %d currencies, want %d", file.path, len(actual), len(codes))
		}
	}
}
