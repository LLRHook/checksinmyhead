package bill

import (
	"bytes"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

// These three baseline functions retain the 04e1 implementation. Only their
// symbols/signature are renamed; they never call the proposed decoding owner.
func baselineAssignmentObjectFields(data []byte, value any) (map[string]json.RawMessage, error) {
	d := json.NewDecoder(bytes.NewReader(data))
	d.DisallowUnknownFields()
	if err := d.Decode(value); err != nil {
		return nil, err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return nil, err
	}
	return fields, nil
}

func baselineAssignmentFieldPresent(fields map[string]json.RawMessage, name string) bool {
	for key := range fields {
		if strings.EqualFold(key, name) {
			return true
		}
	}
	return false
}

func baselineAssignmentDecode(v *createAssignment, data []byte) error {
	type plain createAssignment
	var p plain
	fields, err := baselineAssignmentObjectFields(data, &p)
	if err != nil {
		return err
	}
	*v = createAssignment(p)
	v.RefPresent = baselineAssignmentFieldPresent(fields, "participant_ref")
	v.NamePresent = baselineAssignmentFieldPresent(fields, "person_name")
	return nil
}

func sameAssignmentDecode(a, b createAssignment) bool {
	if a.RefPresent != b.RefPresent || a.NamePresent != b.NamePresent || a.PersonName != b.PersonName ||
		math.Float64bits(a.Percentage) != math.Float64bits(b.Percentage) || (a.ParticipantRef == nil) != (b.ParticipantRef == nil) {
		return false
	}
	return a.ParticipantRef == nil || *a.ParticipantRef == *b.ParticipantRef
}

func assignmentDecodeReference(v createAssignment) string {
	if v.ParticipantRef == nil {
		return ""
	}
	return *v.ParticipantRef
}

func compareAssignmentDecodeStep(t *testing.T, data []byte, got, want *createAssignment) {
	t.Helper()
	beforeGot, beforeWant := *got, *want
	beforeGotRef, beforeWantRef := assignmentDecodeReference(*got), assignmentDecodeReference(*want)
	gotErr := got.UnmarshalJSON(data)
	wantErr := baselineAssignmentDecode(want, data)
	if (gotErr == nil) != (wantErr == nil) {
		t.Fatalf("assignment error acceptance differs: got=%v baseline=%v input=%q", gotErr, wantErr, data)
	}
	if !sameAssignmentDecode(*got, *want) {
		t.Fatalf("assignment values or presence differ: got=%+v baseline=%+v input=%q", *got, *want, data)
	}
	if gotErr != nil && (!sameAssignmentDecode(*got, beforeGot) || got.ParticipantRef != beforeGot.ParticipantRef || assignmentDecodeReference(*got) != beforeGotRef) {
		t.Fatalf("assignment receiver changed on rejection: input=%q", data)
	}
	if wantErr != nil && (!sameAssignmentDecode(*want, beforeWant) || want.ParticipantRef != beforeWant.ParticipantRef || assignmentDecodeReference(*want) != beforeWantRef) {
		t.Fatalf("baseline receiver changed on rejection: input=%q", data)
	}
}

func TestCreateAssignmentDecodeDifferential(t *testing.T) {
	cases := []struct{ name, input string }{
		{"absent", `{}`},
		{"root_null", `null`},
		{"name_null", `{"person_name":null}`},
		{"name_empty", `{"person_name":""}`},
		{"ref_null", `{"participant_ref":null}`},
		{"ref_empty", `{"participant_ref":""}`},
		{"both_null", `{"person_name":null,"participant_ref":null,"percentage":null}`},
		{"full_values", `{"person_name":"Alex","participant_ref":"p0","percentage":12.5}`},
		{"folded_keys", `{"PERSON_NAME":"Alex","PARTICIPANT_REF":"p0","PERCENTAGE":100}`},
		{"escaped_keys", `{"person_\u006eame":"Alex","participant_\u0072ef":"p0"}`},
		{"unicode_folded_key", `{"perſon_name":"Alex"}`},
		{"name_value_then_null", `{"person_name":"Alex","person_name":null}`},
		{"name_null_then_value", `{"person_name":null,"person_name":"Alex"}`},
		{"name_value_then_empty", `{"person_name":"Alex","person_name":""}`},
		{"ref_value_then_null", `{"participant_ref":"p0","participant_ref":null}`},
		{"ref_null_then_value", `{"participant_ref":null,"participant_ref":"p0"}`},
		{"ref_value_then_empty", `{"participant_ref":"p0","participant_ref":""}`},
		{"folded_duplicate_name", `{"PERSON_NAME":"Alex","person_name":null,"perſon_name":"Blair"}`},
		{"folded_duplicate_ref", `{"PARTICIPANT_REF":"p0","participant_ref":null}`},
		{"percentage_value_then_null", `{"percentage":12.5,"percentage":null}`},
		{"percentage_null_then_value", `{"percentage":null,"PERCENTAGE":12.5}`},
		{"percentage_negative_zero", `{"percentage":-0}`},
		{"percentage_negative", `{"percentage":-12.5}`},
		{"percentage_subnormal", `{"percentage":5e-324}`},
		{"percentage_underflow", `{"percentage":-1e-999}`},
		{"percentage_max_finite", `{"percentage":1.7976931348623157e308}`},
		{"percentage_overflow", `{"percentage":1e309}`},
		{"wrong_name_type", `{"person_name":true}`},
		{"wrong_ref_type", `{"participant_ref":100}`},
		{"wrong_percentage_type", `{"percentage":"100"}`},
		{"wrong_name_before_valid", `{"person_name":100,"person_name":"Alex"}`},
		{"wrong_name_after_valid", `{"person_name":"Alex","person_name":[]}`},
		{"wrong_ref_before_valid", `{"participant_ref":false,"participant_ref":"p0"}`},
		{"wrong_ref_after_valid", `{"participant_ref":"p0","participant_ref":{}}`},
		{"wrong_percentage_before_valid", `{"percentage":false,"percentage":100}`},
		{"wrong_percentage_after_valid", `{"percentage":100,"percentage":[]}`},
		{"unknown_null", `{"ignored":null}`},
		{"unknown_after_valid", `{"person_name":"Alex","ignored":{}}`},
		{"hidden_ref_flag", `{"RefPresent":true}`},
		{"hidden_name_flag", `{"NamePresent":true}`},
		{"untagged_name_alias", `{"PersonName":"Alex"}`},
		{"invalid_utf8_value", "{\"person_name\":\"\xff\"}"},
		{"unpaired_surrogate", `{"person_name":"\ud800"}`},
		{"root_array", `[]`},
		{"root_string", `"Alex"`},
		{"root_number", `100`},
		{"root_boolean", `true`},
		{"empty_input", ``},
		{"truncated_object", `{"person_name":"Alex"`},
		{"truncated_value", `{"participant_ref":`},
		{"malformed_separator", `{"person_name":"Alex",}`},
		{"trailing_document", `{} {}`},
		{"trailing_null", `null null`},
		{"trailing_garbage", `{"percentage":100}x`},
		{"non_json_whitespace", "{}\v"},
		{"trailing_whitespace", " {\"percentage\":100}\r\n\t "},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var zeroGot, zeroWant createAssignment
			compareAssignmentDecodeStep(t, []byte(tc.input), &zeroGot, &zeroWant)
			gotRef, wantRef := "old-ref", "old-ref"
			got := createAssignment{RefPresent: true, NamePresent: true, PersonName: "Old", ParticipantRef: &gotRef, Percentage: math.Copysign(0, -1)}
			want := createAssignment{RefPresent: true, NamePresent: true, PersonName: "Old", ParticipantRef: &wantRef, Percentage: math.Copysign(0, -1)}
			compareAssignmentDecodeStep(t, []byte(tc.input), &got, &want)
		})
	}
}

func TestCreateAssignmentDecodeReceiverSequence(t *testing.T) {
	var got, want createAssignment
	for _, input := range []string{
		`{"person_name":"Alex","participant_ref":"p0","percentage":-0}`,
		`{"person_name":100,"participant_ref":null}`,
		`{}`,
		`{"person_name":null,"participant_ref":null}`,
		`{"participant_ref":"p1","percentage":12.5}`,
		`{"person_name":"Changed","participant_ref":"changed","ignored":null}`,
		`null`,
		`{} {}`,
	} {
		compareAssignmentDecodeStep(t, []byte(input), &got, &want)
	}
}

func TestCreateAssignmentDecodeRequestContracts(t *testing.T) {
	cases := []struct {
		name, version, assignment string
		reject                    bool
	}{
		{"wire1_absent_ref", "", `{"person_name":"Alex","percentage":100}`, false},
		{"wire1_scalar_null_duplicate", "1", `{"person_name":"Alex","person_name":null,"percentage":100}`, false},
		{"wire1_folded_name", "1", `{"perſon_name":"Alex","PERCENTAGE":100}`, false},
		{"wire1_null_ref", "1", `{"person_name":"Alex","participant_ref":null,"percentage":100}`, true},
		{"wire1_empty_ref", "1", `{"person_name":"Alex","participant_ref":"","percentage":100}`, true},
		{"wire1_duplicate_ref_to_null", "1", `{"person_name":"Alex","participant_ref":"p0","PARTICIPANT_REF":null,"percentage":100}`, true},
		{"wire2_absent_name", "2", `{"participant_ref":"p0","percentage":100}`, false},
		{"wire2_pointer_null_duplicate", "2", `{"participant_ref":null,"participant_ref":"p0","percentage":100}`, false},
		{"wire2_folded_ref", "2", `{"PARTICIPANT_REF":"p0","PERCENTAGE":100}`, false},
		{"wire2_null_name", "2", `{"participant_ref":"p0","person_name":null,"percentage":100}`, true},
		{"wire2_empty_name", "2", `{"participant_ref":"p0","person_name":"","percentage":100}`, true},
		{"wire2_duplicate_name_to_null", "2", `{"participant_ref":"p0","person_name":"Alex","PERSON_NAME":null,"percentage":100}`, true},
		{"wire2_missing_ref", "2", `{"percentage":100}`, true},
		{"wire2_null_ref", "2", `{"participant_ref":null,"percentage":100}`, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// A valid assignment object reaches the changed owner before any wire
			// rule rejects it. No malformed outer array/body earns control credit.
			var assignment createAssignment
			if err := assignment.UnmarshalJSON([]byte(tc.assignment)); err != nil || assignment.Percentage != 100 {
				t.Fatalf("assignment-path premise failed: err=%v value=%+v", err, assignment)
			}
			people, canonicalAssignment := `[{"name":"Alex"}]`, `{"person_name":"Alex","percentage":100}`
			version := int16(1)
			if tc.version == "2" {
				version = 2
				people, canonicalAssignment = `[{"name":"Alex","client_ref":"p0"}]`, `{"participant_ref":"p0","percentage":100}`
			}
			body := func(value string) string {
				return `{"name":"Synthetic","subtotal":10,"total":10,"currency_code":"USD","participants":` + people + `,"items":[{"name":"Line","price":10,"assignments":[` + value + `]}]}`
			}
			header := http.Header{}
			if tc.version != "" {
				header.Set("X-Billington-Identity-Version", tc.version)
			}
			repo, provider := newMockRepo(), &fakeExchangeRateProvider{}
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(body(tc.assignment)))
			c.Request.Header = header
			NewBillHandler(NewBillService(repo, provider)).CreateBill(c)
			if tc.reject {
				if w.Code != 400 || w.Body.String() != `{"error":"invalid bill content"}` || len(repo.bills) != 0 || provider.calls != 0 {
					t.Fatalf("wire presence rejection changed: status=%d body=%s rows=%d provider_calls=%d", w.Code, w.Body.String(), len(repo.bills), provider.calls)
				}
				r := httptest.NewRequest("POST", "/api/bills", strings.NewReader(body(tc.assignment)))
				r.Header = header.Clone()
				if value, err := decodeCreateBill(httptest.NewRecorder(), r); value != nil || !errors.Is(err, ErrInvalidCreation) {
					t.Fatalf("wire presence decode rejection changed: value=%+v err=%v", value, err)
				}
				return
			}
			if w.Code != 201 || len(repo.bills) != 1 || repo.bills[1] == nil || repo.bills[1].InputVersion != version || provider.calls != 0 {
				t.Fatalf("healthy wire fixture failed: status=%d body=%s rows=%d provider_calls=%d", w.Code, w.Body.String(), len(repo.bills), provider.calls)
			}
			r := httptest.NewRequest("POST", "/api/bills", strings.NewReader(body(tc.assignment)))
			r.Header = header.Clone()
			got, err := decodeCreateBill(httptest.NewRecorder(), r)
			if err != nil {
				t.Fatal(err)
			}
			r = httptest.NewRequest("POST", "/api/bills", strings.NewReader(body(canonicalAssignment)))
			r.Header = header.Clone()
			want, err := decodeCreateBill(httptest.NewRecorder(), r)
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got, want) || got.InputVersion != version {
				t.Fatal("coupled wire model differs from canonical request")
			}
			if err := normalizeCreation(got); err != nil {
				t.Fatal(err)
			}
			if err := normalizeCreation(want); err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(creationEncoding(got), creationEncoding(want)) || creationFingerprint(got) != creationFingerprint(want) {
				t.Fatal("coupled wire encoding/fingerprint differs from canonical request")
			}
		})
	}
}
