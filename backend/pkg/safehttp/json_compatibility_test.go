package safehttp

import (
	"bytes"
	"encoding/json"
	"reflect"
	"testing"
)

type compatibilityElement struct {
	Name       string   `json:"name"`
	Percentage float64  `json:"percentage"`
	Nested     []string `json:"nested"`
}

func TestBoundedArrayStdlibCompatibility(t *testing.T) {
	// UnmarshalJSON receives exactly one validated value. Compare bounded valid-
	// count inputs with the prior streaming stdlib contract in both strict modes.
	inputs := []struct{ name, data string }{
		{"null", `null`}, {"empty", `[]`}, {"null_element", `[null]`},
		{"fields", `[{"name":"Alex","percentage":1,"nested":["x","y"]}]`},
		{"case_escape_duplicate", `[{"NAME":"old","na\u006de":"new","percentage":1,"PERCENTAGE":2}]`},
		{"null_after_value", `[{"name":"kept","name":null,"percentage":1,"percentage":null}]`},
		{"unknown", `[{"ignored":{"deep":[{},{},{}]},"name":"Alex"}]`},
		{"strings", `[{"name":"a,b[\"\\]{}\u0000\ufeff界"},{"name":"<b> x </b>"}]`},
		{"invalid_surrogate", `[{"name":"\ud800"}]`},
		{"invalid_utf8", string([]byte{'[', '{', '"', 'n', 'a', 'm', 'e', '"', ':', '"', 0xff, '"', '}', ']'})},
		{"max_float", `[{"percentage":1.7976931348623157e308}]`},
		{"overflow", `[{"percentage":1e309}]`}, {"wrong_type", `[{"name":3}]`},
		{"not_array", `{}`}, {"truncated", `[{"name":"x"}`},
	}
	for _, strict := range []bool{false, true} {
		label := "ignored"
		if strict {
			label = "strict"
		}
		t.Run(label, func(t *testing.T) {
			for _, tc := range inputs {
				t.Run(tc.name, func(t *testing.T) {
					var want []compatibilityElement
					d := json.NewDecoder(bytes.NewReader([]byte(tc.data)))
					if strict {
						d.DisallowUnknownFields()
					}
					referenceErr := d.Decode(&want)
					got, err := decodeArray[compatibilityElement]([]byte(tc.data), 2, strict)
					if (err != nil) != (referenceErr != nil) {
						t.Fatalf("error mismatch %v vs %v", err, referenceErr)
					}
					if err == nil && !reflect.DeepEqual(got, want) {
						t.Fatalf("got %#v want %#v", got, want)
					}
				})
			}
		})
	}
}
