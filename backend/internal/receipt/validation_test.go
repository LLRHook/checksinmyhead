package receipt

import (
	"fmt"
	"strings"
	"testing"
)

func TestReceiptShapeBounds(t *testing.T) {
	for _, tc := range []struct {
		name, text string
		valid      bool
	}{
		{"items500", `{"items":[` + strings.Repeat(`{"quantity":1},`, 499) + `{"quantity":1}]}`, true},
		{"items501", `{"items":[` + strings.Repeat(`{},`, 500) + `{}]}`, false},
		{"quantity500", `{"items":[{"quantity":500}]}`, true},
		{"quantity_sum", `{"items":[{"quantity":500},{"quantity":0}]}`, false},
		{"quantity_overflow", `{"items":[{"quantity":9223372036854775807},{"quantity":1}]}`, false},
		{"quantity_json_overflow", `{"items":[{"quantity":9223372036854775808}]}`, false},
		{"negative_quantity", `{"items":[{"quantity":-2}]}`, true},
		{"money_limit", `{"items":[{"price":-1000000000}],"total":1000000000}`, true},
		{"money_negative_excess", `{"tax":-1000000001}`, false},
		{"money_nonfinite", `{"total":1e999}`, false},
		{"unicode255", `{"vendor":"` + strings.Repeat("界", 255) + `","items":[{"name":"` + strings.Repeat("界", 255) + `"}]}`, true},
		{"unicode256", `{"items":[{"name":"` + strings.Repeat("界", 256) + `"}]}`, false},
		{"currency3", `{"currency_code":"jPy","currency_symbol":"` + strings.Repeat("界", 16) + `","currency_confidence":0}`, true},
		{"currency_empty", `{"currency_code":""}`, false},
		{"currency_nonascii", `{"currency_code":"U界"}`, false},
		{"symbol17", `{"currency_symbol":"` + strings.Repeat("界", 17) + `"}`, false},
		{"confidence_negative", `{"currency_confidence":-0.01}`, false},
		{"duplicate_items_preflight", `{"items":[` + strings.Repeat(`{},`, 500) + `{}],"items":[]}`, false},
		{"casefold_items_preflight", `{"ITEMS":[` + strings.Repeat(`{},`, 500) + `{}],"items":[]}`, false},
		{"escaped_items_preflight", `{"it\u0065ms":[` + strings.Repeat(`{},`, 500) + `{}]}`, false},
		{"tokens", `{"ignored":[` + strings.Repeat(`[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],`, 511) + `[]]}`, false},
		{"one_document", `{} {}`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r, e := parseResponseText(tc.text)
			if (e == nil) != tc.valid {
				t.Fatalf("valid=%v error=%v", tc.valid, e)
			}
			if e != nil && r != nil {
				t.Fatal("partial parse result")
			}
		})
	}
	for _, n := range []int{16, 17} {
		t.Run(fmt.Sprintf("content%d", n), func(t *testing.T) {
			body := `{"content":[` + strings.Repeat(`{"text":"{}"},`, n-1) + `{"text":"{}"}]}`
			if boundedJSON([]byte(body)) != (n == 16) {
				t.Fatal("content envelope bound")
			}
		})
	}
}
