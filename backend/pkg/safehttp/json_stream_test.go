package safehttp

import (
	"bytes"
	"encoding/json"
	"encoding/json/jsontext"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
)

// streamElements binds through DecodeArrayFrom the way production DTOs do.
type streamElements[T any] struct {
	limit  int
	values []T
}

func (v *streamElements[T]) UnmarshalJSONFrom(dec *jsontext.Decoder) error {
	values, err := DecodeArrayFrom[T](dec, v.limit)
	v.values = values
	return err
}

type countingBody struct {
	r     *strings.Reader
	bytes int
}

func (b *countingBody) Read(p []byte) (int, error) {
	n, err := b.r.Read(p)
	b.bytes += n
	return n, err
}
func (*countingBody) Close() error { return nil }

// The streaming entry point keeps every single-document, byte-cap and public
// error result of DecodeJSON (same table as TestA1SingleJSONDocument).
func TestStreamSingleJSONDocument(t *testing.T) {
	for _, tc := range []struct {
		name, body string
		length     int64
		strict     bool
		want       error
	}{
		{"exact", `{"name":"x"}` + strings.Repeat(" ", 52), 64, false, nil},
		{"one_over_declared", `{}` + strings.Repeat(" ", 63), 65, false, ErrJSONTooLarge},
		{"one_over_streamed", `{}` + strings.Repeat(" ", 63), -1, false, ErrJSONTooLarge},
		{"value_over_streamed", `{"name":"` + strings.Repeat("x", 64) + `"}`, -1, false, ErrJSONTooLarge},
		{"strict", `{"unknown":1}`, 13, true, ErrInvalidJSON},
		{"strict_known", `{"NAME":"x"}`, 12, true, nil},
		{"ignored", `{"unknown":[{},{}]}`, 18, false, nil},
		{"null", `null`, 4, false, nil},
		{"empty", ``, 0, false, ErrInvalidJSON},
		{"wrong_kind", `[]`, 2, false, ErrInvalidJSON},
		{"wrong_member_type", `{"name":1}`, 10, false, ErrInvalidJSON},
		{"wrong_member_type_then_valid", `{"name":1,"name":"x"}`, 21, false, ErrInvalidJSON},
		{"truncated", `{"name":`, 8, false, ErrInvalidJSON},
		{"second_scalar", `{} 1`, 4, false, ErrInvalidJSON},
		{"second_array", `{} [` + strings.Repeat("0,", 20) + `0]`, 47, false, ErrInvalidJSON},
		{"trailing_garbage", `{}x`, 3, false, ErrInvalidJSON},
		{"syntax", `!`, 1, false, ErrInvalidJSON},
		{"known_size_precedes_syntax", `!` + strings.Repeat("x", 64), 65, false, ErrJSONTooLarge},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var streamed, buffered struct {
				Name string `json:"name"`
			}
			request := func() (*httptest.ResponseRecorder, *countingBody) {
				return httptest.NewRecorder(), &countingBody{r: strings.NewReader(tc.body)}
			}
			w, body := request()
			r := httptest.NewRequest("POST", "/", body)
			r.ContentLength = tc.length
			err := DecodeJSONStream(w, r, &streamed, 64, tc.strict)
			if err != tc.want {
				t.Fatalf("stream error=%v want=%v", err, tc.want)
			}
			w, body = request()
			r = httptest.NewRequest("POST", "/", body)
			r.ContentLength = tc.length
			if reference := DecodeJSON(w, r, &buffered, 64, tc.strict); reference != err {
				t.Fatalf("stream error=%v buffered error=%v", err, reference)
			}
			if err == nil && streamed != buffered {
				t.Fatalf("stream=%#v buffered=%#v", streamed, buffered)
			}
		})
	}
	t.Run("no_malformed_drain", func(t *testing.T) {
		body := &noDrain{}
		r := httptest.NewRequest("POST", "/", nil)
		r.Body = body
		r.ContentLength = -1
		var v any
		if err := DecodeJSONStream(httptest.NewRecorder(), r, &v, 64, false); err != ErrInvalidJSON || body.reads != 1 {
			t.Errorf("err=%v reads=%d", err, body.reads)
		}
	})
}

// Element limit+1 is refused before it is bound, and nothing behind it is read:
// the body here continues for a megabyte after the excess element.
func TestStreamArrayStopsAtLimit(t *testing.T) {
	for _, tc := range []struct {
		name, data string
		want       int
		invalid    bool
	}{
		{"at_limit", "[{},{}]", 2, false}, {"over_limit", "[{},{},{}]", 2, true},
		{"over_limit_long_tail", "[{},{},{}" + strings.Repeat(",{}", 1<<18) + "]", 2, true},
		{"empty", "[]", 0, false}, {"null", "null", 0, false},
		{"object", "{}", 0, true}, {"string", `"[]"`, 0, true}, {"number", "1", 0, true}, {"truncated", "[{},", 1, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			a1DecodedElements.Store(0)
			body := &countingBody{r: strings.NewReader(tc.data)}
			r := httptest.NewRequest("POST", "/", body)
			r.ContentLength = -1
			value := streamElements[a1CountedElement]{limit: 2}
			err := DecodeJSONStream(httptest.NewRecorder(), r, &value, 4<<20, false)
			if (err != nil) != tc.invalid || int(a1DecodedElements.Load()) != tc.want {
				t.Fatalf("typed values=%d decodes=%d error=%v", len(value.values), a1DecodedElements.Load(), err)
			}
			if err == nil && len(value.values) != tc.want {
				t.Fatalf("typed values=%d want=%d", len(value.values), tc.want)
			}
			if err != nil && value.values != nil {
				t.Fatalf("rejected array kept %d values", len(value.values))
			}
			if tc.name == "null" && value.values != nil || tc.name == "empty" && (value.values == nil || len(value.values) != 0) {
				t.Fatalf("null/empty result=%#v", value.values)
			}
			if tc.name == "over_limit_long_tail" && body.bytes > 64<<10 {
				t.Fatalf("read %d of %d bytes after the excess element", body.bytes, len(tc.data))
			}
		})
	}
	// A full array that then runs into the byte cap or a syntax error reports
	// that error, as the buffered decoder does, not a count error.
	for _, tc := range []struct {
		name, data string
		want       error
	}{
		{"full_then_byte_cap", "[{},{}" + strings.Repeat(" ", 64) + "]", ErrJSONTooLarge},
		{"full_then_syntax", "[{},{}!", ErrInvalidJSON}, {"full_then_excess", "[{},{},{}]", ErrInvalidJSON},
	} {
		t.Run(tc.name, func(t *testing.T) {
			request := func() *http.Request {
				r := httptest.NewRequest("POST", "/", strings.NewReader(tc.data))
				r.ContentLength = -1
				return r
			}
			value := streamElements[a1CountedElement]{limit: 2}
			var buffered []a1CountedElement
			err, reference := DecodeJSONStream(httptest.NewRecorder(), request(), &value, 64, false), DecodeJSON(httptest.NewRecorder(), request(), &buffered, 64, false)
			if err != tc.want || (tc.name != "full_then_excess" && reference != tc.want) {
				t.Fatalf("stream error=%v buffered error=%v want=%v", err, reference, tc.want)
			}
		})
	}
}

// Same inputs as TestBoundedArrayStdlibCompatibility: the streaming array keeps
// stdlib acceptance and values in both strict modes.
func TestStreamArrayStdlibCompatibility(t *testing.T) {
	inputs := []struct{ name, data string }{
		{"null", `null`}, {"empty", `[]`}, {"null_element", `[null]`}, {"spaced", " [ \n{ \"name\" : \"Alex\" } ,\t{ } ]\r\n"},
		{"fields", `[{"name":"Alex","percentage":1,"nested":["x","y"]}]`},
		{"case_escape_duplicate", `[{"NAME":"old","na\u006de":"new","percentage":1,"PERCENTAGE":2}]`},
		{"null_after_value", `[{"name":"kept","name":null,"percentage":1,"percentage":null}]`},
		{"unknown", `[{"ignored":{"deep":[{},{},{}]},"name":"Alex"}]`},
		{"strings", `[{"name":"a,b[\"\\]{}\u0000\ufeff界"},{"name":"<b> x </b>"}]`},
		{"invalid_surrogate", `[{"name":"\ud800"}]`},
		{"invalid_utf8", string([]byte{'[', '{', '"', 'n', 'a', 'm', 'e', '"', ':', '"', 0xff, '"', '}', ']'})},
		{"max_float", `[{"percentage":1.7976931348623157e308}]`},
		{"overflow", `[{"percentage":1e309}]`}, {"wrong_type", `[{"name":3}]`}, {"wrong_type_then_valid", `[{"name":3},{"name":"x"}]`},
		{"wrong_element", `[1]`}, {"nested_wrong_type", `[{"nested":{}}]`}, {"nested_null", `[{"nested":null}]`},
		{"not_array", `{}`}, {"truncated", `[{"name":"x"}`}, {"trailing_comma", `[{"name":"x"},]`}, {"second_document", `[] []`},
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
					if referenceErr == nil {
						if _, extra := d.Token(); extra == nil || d.More() {
							referenceErr = ErrInvalidJSON
						}
					}
					got := streamElements[compatibilityElement]{limit: 2}
					r := httptest.NewRequest("POST", "/", strings.NewReader(tc.data))
					err := DecodeJSONStream(httptest.NewRecorder(), r, &got, 4<<20, strict)
					if (err != nil) != (referenceErr != nil) {
						t.Fatalf("error mismatch %v vs %v", err, referenceErr)
					}
					if err == nil && !reflect.DeepEqual(got.values, want) {
						t.Fatalf("got %#v want %#v", got.values, want)
					}
				})
			}
		})
	}
}
