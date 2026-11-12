package safehttp

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDecodeJSONPostgresText(t *testing.T) {
	type nested struct {
		Name *string `json:"name"`
	}
	type request struct {
		Name   string         `json:"name"`
		People []nested       `json:"people"`
		Map    map[string]any `json:"map"`
		Any    any            `json:"any"`
	}
	for _, tc := range []struct {
		name, body string
		reject     bool
		want       string
	}{
		{"nul", `{"name":"a\u0000b"}`, true, ""},
		{"map_nul", `{"map":{"key":"a\u0000b"}}`, true, ""},
		{"any_nul", `{"any":"a\u0000b"}`, true, ""},
		{"nested_nul", `{"people":[{"name":"a\u0000b"}]}`, true, ""},
		{"other_controls", `{"name":"a\u0001\b\t\n\f\r\u001fb"}`, false, "a\x01\b\t\n\f\r\x1fb"},
		{"unicode", `{"name":"Σς界😀"}`, false, "Σς界😀"},
		{"null", `{"people":[{"name":null}]}`, false, ""},
		{"ignored_nul", `{"ignored":"a\u0000b","name":"kept"}`, false, "kept"},
		{"invalid_utf8_replaced", "{\"name\":\"a\xffb\"}", false, "a\ufffdb"},
		{"unpaired_surrogate_replaced", `{"name":"a\ud800b"}`, false, "a\ufffdb"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			for _, decode := range []func(http.ResponseWriter, *http.Request, any, int64, bool) error{DecodeJSON, DecodeJSONStream} {
				var got request
				r := httptest.NewRequest("POST", "/", strings.NewReader(tc.body))
				err := decode(httptest.NewRecorder(), r, &got, 4096, false)
				if (err != nil) != tc.reject {
					t.Fatalf("rejected=%v, want %v", err != nil, tc.reject)
				}
				if !tc.reject && got.Name != tc.want {
					t.Fatalf("name=%q, want %q", got.Name, tc.want)
				}
			}
		})
	}
}
