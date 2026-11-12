package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"encoding/json"
	"fmt"
	"math"
	"math/rand/v2"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

// The baseline types retain the buffered decode this change replaced: the whole
// document through safehttp.DecodeJSON, each collection through UnmarshalJSON
// and safehttp.DecodeArray. They never call the streaming owner.
type baselineAssignmentInputs []AssignmentInput
type baselineUpdateInput struct {
	ItemID            uint                     `json:"item_id"`
	ExpectedUpdatedAt *string                  `json:"expected_updated_at"`
	Assignments       baselineAssignmentInputs `json:"assignments"`
}
type baselineUpdateInputs []baselineUpdateInput

func (v *baselineAssignmentInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeArray[AssignmentInput](data, 100)
	*v = values
	return err
}
func (v *baselineUpdateInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeArray[baselineUpdateInput](data, 500)
	*v = values
	return err
}

func sameAssignmentInputs(got AssignmentInputs, want baselineAssignmentInputs) bool {
	if (got == nil) != (want == nil) || len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i].PersonName != want[i].PersonName || math.Float64bits(got[i].Percentage) != math.Float64bits(want[i].Percentage) {
			return false
		}
	}
	return true
}
func sameUpdateInputs(got AssignmentUpdateInputs, want baselineUpdateInputs) bool {
	if (got == nil) != (want == nil) || len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i].ItemID != want[i].ItemID || (got[i].ExpectedUpdatedAt == nil) != (want[i].ExpectedUpdatedAt == nil) ||
			(got[i].ExpectedUpdatedAt != nil && *got[i].ExpectedUpdatedAt != *want[i].ExpectedUpdatedAt) || !sameAssignmentInputs(got[i].Assignments, want[i].Assignments) {
			return false
		}
	}
	return true
}

// compareAssignmentBodies decodes one request body as both route shapes with the
// streaming owner and with the baseline, and requires the same acceptance and,
// when accepted, the same values (including nil against empty and float bits).
func compareAssignmentBodies(t *testing.T, body string) (accepted bool) {
	t.Helper()
	var batch struct {
		Updates AssignmentUpdateInputs `json:"updates"`
	}
	var batchWant struct {
		Updates baselineUpdateInputs `json:"updates"`
	}
	request := func() *http.Request { return httptest.NewRequest("PATCH", "/", strings.NewReader(body)) }
	err := safehttp.DecodeJSONStream(httptest.NewRecorder(), request(), &batch, safehttp.MutationBodyLimit, false)
	wantErr := safehttp.DecodeJSON(httptest.NewRecorder(), request(), &batchWant, safehttp.MutationBodyLimit, false)
	if err != wantErr {
		t.Fatalf("batch error differs: stream=%v baseline=%v input=%q", err, wantErr, body)
	}
	if err == nil && !sameUpdateInputs(batch.Updates, batchWant.Updates) {
		t.Fatalf("batch values differ: stream=%+v baseline=%+v input=%q", batch.Updates, batchWant.Updates, body)
	}
	var single struct {
		ExpectedUpdatedAt *string          `json:"expected_updated_at"`
		Assignments       AssignmentInputs `json:"assignments"`
	}
	var singleWant struct {
		ExpectedUpdatedAt *string                  `json:"expected_updated_at"`
		Assignments       baselineAssignmentInputs `json:"assignments"`
	}
	singleErr := safehttp.DecodeJSONStream(httptest.NewRecorder(), request(), &single, safehttp.MutationBodyLimit, false)
	singleWantErr := safehttp.DecodeJSON(httptest.NewRecorder(), request(), &singleWant, safehttp.MutationBodyLimit, false)
	if singleErr != singleWantErr {
		t.Fatalf("single error differs: stream=%v baseline=%v input=%q", singleErr, singleWantErr, body)
	}
	if singleErr == nil && ((single.ExpectedUpdatedAt == nil) != (singleWant.ExpectedUpdatedAt == nil) ||
		(single.ExpectedUpdatedAt != nil && *single.ExpectedUpdatedAt != *singleWant.ExpectedUpdatedAt) || !sameAssignmentInputs(single.Assignments, singleWant.Assignments)) {
		t.Fatalf("single values differ: stream=%+v baseline=%+v input=%q", single, singleWant, body)
	}
	return err == nil
}

// assignmentArrayCases are assignment arrays; each is tried as the value of
// "assignments" in both route shapes. canonical records whether the direct
// binding is expected to own the input or leave it to the stdlib path.
var assignmentArrayCases = []struct {
	name, array string
	canonical   bool
}{
	{"name_first", `[{"person_name":"Alex","percentage":100}]`, true},
	{"percentage_first", `[{"percentage":100,"person_name":"Alex"}]`, true},
	{"two", `[{"person_name":"Alex","percentage":50},{"percentage":50,"person_name":"Blair"}]`, true},
	{"whitespace", " [ \n{ \"person_name\" :\t\"Alex\" , \"percentage\" : 1 }\r\n, {\"percentage\":2 ,\"person_name\":\"B\"} ] ", true},
	{"empty_name", `[{"person_name":"","percentage":1}]`, true},
	{"unicode_name", `[{"person_name":"界 Zoë \u00e9","percentage":1}]`, false},
	{"raw_unicode_name", "[{\"person_name\":\"界 Zoë \ufeffx\",\"percentage\":1}]", true},
	{"markup_name", `[{"person_name":"<b> Alex </b>","percentage":1}]`, true},
	{"punctuation_name", `[{"person_name":"a,b[]{}:'","percentage":1}]`, true},
	{"member_text_in_name", `[{"person_name":"x,\"percentage\":9","percentage":1}]`, false},
	{"delete_control_name", "[{\"person_name\":\"a\x7fb\",\"percentage\":1}]", true},
	{"fraction", `[{"person_name":"A","percentage":33.33}]`, true},
	{"exponent", `[{"person_name":"A","percentage":1e2}]`, true},
	{"signed_exponent", `[{"person_name":"A","percentage":2.5E-1}]`, true},
	{"negative", `[{"person_name":"A","percentage":-12.5}]`, true},
	{"negative_zero", `[{"person_name":"A","percentage":-0}]`, true},
	{"zero", `[{"person_name":"A","percentage":0}]`, true},
	{"zero_fraction", `[{"person_name":"A","percentage":0.0}]`, true},
	{"fifteen_digits", `[{"person_name":"A","percentage":999999999999999}]`, true},
	{"sixteen_digits", `[{"person_name":"A","percentage":9007199254740993}]`, true},
	{"long_integer", `[{"person_name":"A","percentage":123456789012345678901234567890}]`, true},
	{"long_fraction", `[{"person_name":"A","percentage":0.1000000000000000055511151231257827021181583404541015625}]`, true},
	{"subnormal", `[{"person_name":"A","percentage":5e-324}]`, true},
	{"underflow", `[{"person_name":"A","percentage":-1e-999}]`, true},
	{"max_finite", `[{"person_name":"A","percentage":1.7976931348623157e308}]`, true},
	{"overflow", `[{"person_name":"A","percentage":1e309}]`, false},
	{"hundred", "[" + strings.TrimSuffix(strings.Repeat(`{"person_name":"A","percentage":1},`, 100), ",") + "]", true},
	{"hundred_and_one", "[" + strings.TrimSuffix(strings.Repeat(`{"person_name":"A","percentage":1},`, 101), ",") + "]", false},
	{"hundred_and_one_empty", "[" + strings.TrimSuffix(strings.Repeat(`{},`, 101), ",") + "]", false},
	{"null", `null`, false},
	{"empty", `[]`, false},
	{"spaced_empty", `[ ]`, false},
	{"null_element", `[null]`, false},
	{"empty_element", `[{}]`, false},
	{"name_only", `[{"person_name":"Alex"}]`, false},
	{"percentage_only", `[{"percentage":1}]`, false},
	{"folded_names", `[{"PERSON_NAME":"Alex","Percentage":1}]`, false},
	{"unicode_folded_name", `[{"perſon_name":"Alex","percentage":1}]`, false},
	{"escaped_member", `[{"person_\u006eame":"Alex","percentage":1}]`, false},
	{"escaped_value", `[{"person_name":"Al\u0065x","percentage":1}]`, false},
	{"escaped_quote", `[{"person_name":"Al\"ex","percentage":1}]`, false},
	{"escaped_backslash", `[{"person_name":"Al\\","percentage":1}]`, false},
	{"unpaired_surrogate", `[{"person_name":"\ud800","percentage":1}]`, false},
	{"invalid_utf8", "[{\"person_name\":\"\xff\",\"percentage\":1}]", false},
	{"truncated_utf8", "[{\"person_name\":\"\xe7\x95\",\"percentage\":1}]", false},
	{"duplicate_name", `[{"person_name":"old","person_name":"new","percentage":1}]`, false},
	{"duplicate_percentage", `[{"percentage":1,"percentage":2,"person_name":"A"}]`, false},
	{"duplicate_third", `[{"person_name":"A","percentage":1,"percentage":2}]`, false},
	{"two_names", `[{"person_name":"old","person_name":"new"}]`, false},
	{"two_percentages", `[{"percentage":1,"percentage":2}]`, false},
	{"name_then_null", `[{"person_name":"kept","person_name":null,"percentage":1}]`, false},
	{"null_name", `[{"person_name":null,"percentage":1}]`, false},
	{"null_percentage", `[{"person_name":"A","percentage":null}]`, false},
	{"unknown_member", `[{"person_name":"A","percentage":1,"paid":true}]`, false},
	{"unknown_only", `[{"paid":true,"id":7}]`, false},
	{"unknown_graph", `[{"ignored":{"deep":[{},{"person_name":"x"}]},"person_name":"A","percentage":1}]`, false},
	{"wrong_name_type", `[{"person_name":1,"percentage":1}]`, false},
	{"wrong_name_then_valid", `[{"person_name":1,"person_name":"A","percentage":1}]`, false},
	{"wrong_percentage_type", `[{"person_name":"A","percentage":"1"}]`, false},
	{"wrong_percentage_object", `[{"person_name":"A","percentage":{}}]`, false},
	{"wrong_element", `[1]`, false},
	{"wrong_second_element", `[{"person_name":"A","percentage":1},"x"]`, false},
	{"nested_array", `[[{"person_name":"A","percentage":1}]]`, false},
	{"object", `{}`, false},
	{"object_with_members", `{"person_name":"A","percentage":1}`, false},
	{"string", `"[]"`, false},
	{"number", `7`, false},
	{"boolean", `true`, false},
}

// assignmentBodyCases are whole documents that an array value cannot express.
var assignmentBodyCases = []struct{ name, body string }{
	{"empty_input", ``}, {"whitespace_only", " \n"}, {"root_null", `null`}, {"root_array", `[]`}, {"root_string", `"x"`}, {"root_number", `1`},
	{"empty_object", `{}`}, {"updates_null", `{"updates":null}`}, {"updates_empty", `{"updates":[]}`}, {"updates_object", `{"updates":{}}`},
	{"updates_string", `{"updates":"[]"}`}, {"updates_number", `{"updates":1}`}, {"updates_null_element", `{"updates":[null]}`},
	{"updates_wrong_element", `{"updates":[1]}`}, {"updates_wrong_then_valid", `{"updates":[1,{"item_id":2,"assignments":[]}]}`},
	{"folded_updates", `{"UPDATES":[{"ITEM_ID":2,"Assignments":[{"person_name":"A","percentage":1}]}]}`},
	{"escaped_updates", `{"\u0075pdates":[{"item_\u0069d":2,"assignments":[]}]}`},
	{"unicode_folded_members", `{"updateſ":[{"aſſignmentſ":[{"person_name":"A","percentage":1}],"item_id":3}]}`},
	{"duplicate_updates", `{"updates":[{"item_id":1,"assignments":[]}],"updates":[{"item_id":2,"assignments":[{"person_name":"A","percentage":1}]}]}`},
	{"duplicate_updates_then_null", `{"updates":[{"item_id":1,"assignments":[]}],"updates":null}`},
	{"first_updates_excess", `{"updates":[` + strings.Repeat(`{},`, 500) + `{}],"updates":[]}`},
	{"updates_at_limit", `{"updates":[` + strings.Repeat(`{},`, 499) + `{}]}`},
	{"updates_excess", `{"updates":[` + strings.Repeat(`{},`, 500) + `{}]}`},
	{"updates_excess_malformed_tail", `{"updates":[` + strings.Repeat(`{},`, 500) + `{},!`},
	{"duplicate_item", `{"updates":[{"item_id":1,"ITEM_ID":2,"assignments":[]}]}`},
	{"item_null_after_value", `{"updates":[{"item_id":2,"item_id":null,"assignments":[]}]}`},
	{"item_zero", `{"updates":[{"item_id":0,"assignments":[]}]}`},
	{"item_negative", `{"updates":[{"item_id":-1,"assignments":[]}]}`},
	{"item_fraction", `{"updates":[{"item_id":1.5,"assignments":[]}]}`},
	{"item_integral_fraction", `{"updates":[{"item_id":1.0,"assignments":[]}]}`},
	{"item_exponent", `{"updates":[{"item_id":1e2,"assignments":[]}]}`},
	{"item_string", `{"updates":[{"item_id":"1","assignments":[]}]}`},
	{"item_max", `{"updates":[{"item_id":18446744073709551615,"assignments":[]}]}`},
	{"item_overflow", `{"updates":[{"item_id":18446744073709551616,"assignments":[]}]}`},
	{"expected_string", `{"updates":[{"item_id":1,"expected_updated_at":"2026-11-09T10:00:00Z","assignments":[]}],"expected_updated_at":"top"}`},
	{"expected_null", `{"updates":[{"item_id":1,"expected_updated_at":null,"assignments":[]}],"expected_updated_at":null}`},
	{"expected_value_then_null", `{"updates":[{"item_id":1,"expected_updated_at":"x","expected_updated_at":null,"assignments":[]}]}`},
	{"expected_escaped", `{"updates":[{"item_id":1,"expected_updated_at":"a\u0062\"\\","assignments":[]}],"expected_updated_at":"\ud83d\ude00"}`},
	{"expected_number", `{"updates":[{"item_id":1,"expected_updated_at":1,"assignments":[]}],"expected_updated_at":1}`},
	{"assignments_absent", `{"updates":[{"item_id":1}]}`},
	{"replacement_arrays", `{"updates":[{"item_id":2,"assignments":[{"person_name":"old","percentage":100}],"ASSIGNMENTS":[{"person_name":"New","percentage":1e2}]}],"assignments":[{"person_name":"old","percentage":1}],"Assignments":[]}`},
	{"array_then_null", `{"updates":[{"item_id":2,"assignments":[{"person_name":"A","percentage":1}],"assignments":null}],"assignments":[{"person_name":"A","percentage":1}],"assignments":null}`},
	{"first_array_excess", `{"updates":[{"item_id":2,"assignments":[` + strings.Repeat(`{},`, 100) + `{}],"assignments":[]}],"assignments":[` + strings.Repeat(`{},`, 100) + `{}],"assignments":[]}`},
	{"wrong_array_then_valid", `{"updates":[{"item_id":2,"assignments":{},"assignments":[]}],"assignments":7,"assignments":[]}`},
	{"unknown_members", `{"ignored":[{"updates":[1]}],"updates":[{"item_id":2,"ignored":{"assignments":null},"assignments":[]}],"assignments":[],"z":null}`},
	{"trailing_document", `{"updates":[{"item_id":2,"assignments":[]}]} {}`},
	{"trailing_garbage", `{"updates":[{"item_id":2,"assignments":[]}]}x`},
	{"trailing_whitespace", "{\"updates\":[{\"item_id\":2,\"assignments\":[]}]}\r\n\t "},
	{"leading_whitespace", "\n {\"assignments\":[{\"person_name\":\"A\",\"percentage\":1}],\"updates\":[{\"item_id\":2,\"assignments\":[{\"percentage\":1,\"person_name\":\"A\"}]}]}"},
	{"non_json_whitespace", "{\"updates\":[{\"item_id\":2,\"assignments\":[]}]}\v"},
	{"byte_order_mark", "\ufeff{\"updates\":[{\"item_id\":2,\"assignments\":[]}]}"},
	{"truncated_array", `{"updates":[{"item_id":2,"assignments":[`},
	{"truncated_element", `{"updates":[{"item_id":2,"assignments":[{"person_name":"A","percentage":1}`},
	{"truncated_string", `{"assignments":[{"person_name":"A`},
	{"missing_comma", `{"updates":[{"item_id":2 "assignments":[]}]}`},
	{"trailing_comma", `{"updates":[{"item_id":2,"assignments":[{"person_name":"A","percentage":1},]}],"assignments":[{"person_name":"A","percentage":1,}]}`},
	{"raw_control_in_name", "{\"assignments\":[{\"person_name\":\"a\nb\",\"percentage\":1}],\"updates\":[{\"item_id\":1,\"assignments\":[{\"person_name\":\"a\tb\",\"percentage\":1}]}]}"},
	{"leading_zero", `{"assignments":[{"person_name":"A","percentage":01}],"updates":[{"item_id":1,"assignments":[{"person_name":"A","percentage":00}]}]}`},
	{"plus_sign", `{"assignments":[{"person_name":"A","percentage":+1}]}`},
	{"bare_fraction", `{"assignments":[{"person_name":"A","percentage":.5}]}`},
	{"dangling_fraction", `{"assignments":[{"person_name":"A","percentage":5.}]}`},
	{"dangling_exponent", `{"assignments":[{"person_name":"A","percentage":5e}]}`},
	{"hexadecimal", `{"assignments":[{"person_name":"A","percentage":0x10}]}`},
	{"not_a_number", `{"assignments":[{"person_name":"A","percentage":NaN}]}`},
	{"infinity", `{"assignments":[{"person_name":"A","percentage":Infinity}]}`},
	{"single_quotes", `{"assignments":[{'person_name':'A','percentage':1}]}`},
	{"deep_unknown", `{"ignored":` + strings.Repeat("[", 200) + strings.Repeat("]", 200) + `,"assignments":[{"person_name":"A","percentage":1}]}`},
}

func TestAssignmentStreamDecodeDifferential(t *testing.T) {
	for _, tc := range assignmentArrayCases {
		t.Run("array/"+tc.name, func(t *testing.T) {
			compareAssignmentBodies(t, `{"updates":[{"item_id":7,"assignments":`+tc.array+`}],"assignments":`+tc.array+`}`)
			compareAssignmentBodies(t, `{"assignments":`+tc.array+`,"expected_updated_at":"x","updates":[{"assignments":`+tc.array+`,"item_id":7},{"item_id":8,"assignments":`+tc.array+`}]}`)
		})
	}
	for _, tc := range assignmentBodyCases {
		t.Run("body/"+tc.name, func(t *testing.T) { compareAssignmentBodies(t, tc.body) })
	}
	t.Run("maximum", func(t *testing.T) {
		var updates []string
		for i := 1; i <= 500; i++ {
			var assignments []string
			for j := 0; j < 100; j++ {
				assignments = append(assignments, fmt.Sprintf(`{"percentage":1,"person_name":"Person%03d"}`, j))
			}
			updates = append(updates, fmt.Sprintf(`{"assignments":[%s],"item_id":%d}`, strings.Join(assignments, ","), i))
		}
		if !compareAssignmentBodies(t, `{"updates":[`+strings.Join(updates, ",")+`]}`) {
			t.Fatal("maximum admitted update was rejected")
		}
	})
}

// The direct binding owns exactly the inputs marked canonical, declines every
// other one, and whatever it accepts equals the stdlib result for those bytes.
func TestAssignmentCanonicalBindingOwnership(t *testing.T) {
	for _, tc := range assignmentArrayCases {
		t.Run(tc.name, func(t *testing.T) {
			raw := []byte(strings.TrimSpace(tc.array))
			got, canonical := canonicalAssignments(raw)
			if canonical != tc.canonical {
				t.Fatalf("canonical=%t want=%t input=%q", canonical, tc.canonical, raw)
			}
			if !canonical {
				if got != nil {
					t.Fatalf("declined input returned values: %+v", got)
				}
				return
			}
			want, err := safehttp.DecodeArray[AssignmentInput](raw, 100)
			if err != nil || !json.Valid(raw) || !sameAssignmentInputs(got, want) {
				t.Fatalf("direct=%+v stdlib=%+v error=%v input=%q", got, want, err, raw)
			}
		})
	}
}

// Seeded documents mix canonical and non-canonical fragments and then damage
// some of them. The generator is deterministic; no failure depends on a seed
// that is not printed with the input.
func TestAssignmentStreamDecodeGenerated(t *testing.T) {
	random := rand.New(rand.NewPCG(20261109, 4507))
	pick := func(values ...string) string { return values[random.IntN(len(values))] }
	space := func() string { return pick("", "", "", "", " ", "\n", "\t", "\r\n ") }
	name := func() string {
		return pick(`"Alex"`, `"Blair"`, `""`, `" x "`, `"界"`, `"Zoë"`, `"<b>A</b>"`, `"a,b]}"`, `"A\u0042"`, `"q\"q"`, `"\\"`, `"\ud800"`, "\"\xff\"", "\"a\x7f\"", `null`, `1`, `true`, `[]`, `{}`,
			strconv.Quote(strings.Repeat("n", random.IntN(40))))
	}
	number := func() string {
		return pick(`1`, `100`, `0`, `-0`, `50`, `33.33`, `1e2`, `2.5E-1`, `1E+2`, `-7`, `999999999999999`, `1000000000000000`, `9007199254740993`, `0.1`, `1e309`, `-1e-999`, `5e-324`, `null`, `"1"`, `true`, `[]`, `{}`,
			strconv.Itoa(random.IntN(1000)), strconv.FormatFloat(random.Float64()*200-50, 'g', -1, 64))
	}
	member := func() string {
		switch random.IntN(12) {
		case 0:
			return pick(`"PERSON_NAME"`, `"Person_Name"`, `"person_\u006eame"`, `"perſon_name"`, `"personname"`, `"person-name"`) + space() + ":" + space() + name()
		case 1:
			return pick(`"PERCENTAGE"`, `"Percentage"`, `"percentag\u0065"`, `"percent"`) + space() + ":" + space() + number()
		case 2:
			return pick(`"paid"`, `"id"`, `"participant_id"`, `""`) + space() + ":" + space() + pick(`true`, `7`, `null`, `{"person_name":"x","percentage":[1]}`, `[{}]`, `"s"`)
		case 3, 4, 5, 6:
			return `"percentage"` + space() + ":" + space() + number()
		default:
			return `"person_name"` + space() + ":" + space() + name()
		}
	}
	element := func() string {
		switch random.IntN(20) {
		case 0:
			return pick(`null`, `{}`, `1`, `"x"`, `[]`, `true`)
		case 1, 2, 3:
			var members []string
			for range random.IntN(5) {
				members = append(members, member())
			}
			return "{" + space() + strings.Join(members, space()+","+space()) + space() + "}"
		case 4, 5:
			return "{" + space() + `"percentage"` + space() + ":" + space() + number() + space() + "," + space() + `"person_name"` + space() + ":" + space() + name() + space() + "}"
		default:
			return "{" + space() + `"person_name"` + space() + ":" + space() + name() + space() + "," + space() + `"percentage"` + space() + ":" + space() + number() + space() + "}"
		}
	}
	array := func() string {
		switch random.IntN(24) {
		case 0:
			return pick(`null`, `[]`, `{}`, `7`, `"x"`, `[ ]`)
		case 1:
			return "[" + strings.TrimSuffix(strings.Repeat(element()+",", 99+random.IntN(4)), ",") + "]"
		}
		var elements []string
		for range 1 + random.IntN(6) {
			elements = append(elements, element())
		}
		return "[" + space() + strings.Join(elements, space()+","+space()) + space() + "]"
	}
	update := func() string {
		members := []string{pick(`"item_id"`, `"item_id"`, `"item_id"`, `"ITEM_ID"`) + ":" + pick(`1`, `2`, `7`, `0`, `-1`, `1.5`, `"1"`, `null`, strconv.Itoa(random.IntN(1000))), pick(`"assignments"`, `"assignments"`, `"assignments"`, `"Assignments"`) + space() + ":" + space() + array()}
		if random.IntN(4) == 0 {
			members = append(members, `"expected_updated_at":`+pick(`"2026-11-09T10:00:00Z"`, `""`, `null`, `1`, `"\u0041"`))
		}
		if random.IntN(6) == 0 {
			members = append(members, pick(`"assignments":`+array(), `"ignored":[{"assignments":[1]}]`, `"item_id":9`))
		}
		random.Shuffle(len(members), func(i, j int) { members[i], members[j] = members[j], members[i] })
		return "{" + strings.Join(members, ",") + "}"
	}
	accepted, canonical := 0, 0
	for i := 0; i < 6000; i++ {
		var updates []string
		for range random.IntN(4) {
			updates = append(updates, update())
		}
		leaf := array()
		if _, ok := canonicalAssignments([]byte(strings.TrimSpace(leaf))); ok {
			canonical++
		}
		body := pick(`{"updates":`, `{"updates":`, `{"UPDATES":`, `{"ignored":1,"updates":`) + space() + "[" + strings.Join(updates, ",") + "]" + `,"assignments":` + leaf + pick(`}`, `}`, `}`, `} `, `}{}`, `,"updates":null}`)
		switch random.IntN(10) {
		case 0:
			body = body[:random.IntN(len(body)+1)]
		case 1:
			damaged := []byte(body)
			damaged[random.IntN(len(damaged))] = `"\{}[],:0x `[random.IntN(11)]
			body = string(damaged)
		case 2:
			at := random.IntN(len(body) + 1)
			body = body[:at] + pick(`,`, `"`, `\`, `]`, `}`, `null`, `0`, " ") + body[at:]
		}
		if compareAssignmentBodies(t, body) {
			accepted++
		}
	}
	if accepted < 1000 || canonical < 300 {
		t.Fatalf("generator lost coverage: accepted=%d canonical=%d of 6000", accepted, canonical)
	}
}

// The direct binding decides nothing for bytes that are not the canonical
// shape, including arbitrary damage: an accepted input is always valid JSON
// with the stdlib result.
func TestAssignmentCanonicalBindingArbitraryBytes(t *testing.T) {
	random := rand.New(rand.NewPCG(4507, 20261109))
	seeds := []string{
		`[{"person_name":"Alex","percentage":100},{"percentage":33.5,"person_name":"界"}]`,
		" [ { \"percentage\" : 1e2 , \"person_name\" : \"B\" } ] ",
		`[{"person_name":"a\\b","percentage":-0.5e-3}]`,
	}
	const alphabet = "\"\\{}[],:.-+eE0123456789 \n\tpersonamctgulx\x00\x1f\x7f\x80\xff"
	accepted := 0
	for i := 0; i < 200000; i++ {
		raw := []byte(seeds[random.IntN(len(seeds))])
		for range 1 + random.IntN(3) {
			switch at := random.IntN(len(raw)); random.IntN(3) {
			case 0:
				raw[at] = alphabet[random.IntN(len(alphabet))]
			case 1:
				raw = append(raw[:at], raw[at+1:]...)
			default:
				raw = append(raw[:at], append([]byte{alphabet[random.IntN(len(alphabet))]}, raw[at:]...)...)
			}
			if len(raw) == 0 {
				break
			}
		}
		got, canonical := canonicalAssignments(raw)
		if !canonical {
			continue
		}
		accepted++
		want, err := safehttp.DecodeArray[AssignmentInput](raw, 100)
		if !json.Valid(raw) || err != nil || !sameAssignmentInputs(got, want) {
			t.Fatalf("direct=%+v stdlib=%+v error=%v valid=%t input=%q", got, want, err, json.Valid(raw), raw)
		}
	}
	if accepted < 2000 {
		t.Fatalf("mutations lost coverage: accepted=%d", accepted)
	}
}

func baselineAssignmentIdentityKey(a models.ItemAssignment) string {
	if a.ParticipantID != nil {
		return strconv.FormatUint(uint64(*a.ParticipantID), 10)
	}
	return strings.ToLower(a.PersonName)
}

// baselineValidateAssignmentUpdates retains the validation this change
// replaced: one map per item and one lowered string per name.
func baselineValidateAssignmentUpdates(updates []ItemAssignmentsUpdate) error {
	if len(updates) == 0 || len(updates) > 500 {
		return mutation.Invalid
	}
	count := 0
	ids := map[uint]bool{}
	for _, u := range updates {
		if u.ItemID == 0 || uint64(u.ItemID) > math.MaxInt64 || ids[u.ItemID] || len(u.Assignments) > 100 {
			return mutation.Invalid
		}
		count += len(u.Assignments)
		if count > 50000 {
			return mutation.Invalid
		}
		ids[u.ItemID] = true
		seen := map[string]bool{}
		total := 0.0
		for _, a := range u.Assignments {
			key := baselineAssignmentIdentityKey(a)
			if (a.ParticipantID == nil && (strings.TrimSpace(key) == "" || len([]rune(key)) > 30)) || (a.ParticipantID != nil && (*a.ParticipantID == 0 || uint64(*a.ParticipantID) > math.MaxInt64 || a.PersonName != "")) || seen[key] || !finite(a.Percentage) || a.Percentage <= 0 || a.Percentage > 100 {
				return mutation.Invalid
			}
			seen[key] = true
			total += a.Percentage
		}
		if !models.ItemAssignmentTotalIsValid(total) {
			return mutation.Invalid
		}
	}
	return nil
}

var assignmentIdentityNames = []string{
	"", " ", "\t\n", "alex", "Alex", "ALEX", " alex ", "aLeX", "Zoë", "ZOË", "zoë", "界", "İ", "i̇", "i", "I", "ı", "K", "k", "K", "ſ", "s", "S", "ß", "SS", "ǅ", "ǆ", "Σ", "σ", "ς",
	"\xff", "A\xff", "a\xff", "\ufeffAlex", "12", "012", "0", "a<b", strings.Repeat("a", 30), strings.Repeat("A", 30), strings.Repeat("a", 31), strings.Repeat("界", 30), strings.Repeat("界", 31),
	strings.Repeat("é", 30), strings.Repeat("É", 30), strings.Repeat("é", 31), strings.Repeat("A", 29) + "界", strings.Repeat("A", 30) + "界", "aaaaaaaaaaaaaaaaaaaaAA", "aaaaaaaaaaaaaaaaaaaaaa",
}

func TestAssignmentIdentityKeyAppendMatches(t *testing.T) {
	for _, name := range assignmentIdentityNames {
		a := models.ItemAssignment{PersonName: name}
		for _, prefix := range []string{"", "kept"} {
			if got := string(appendAssignmentIdentityKey([]byte(prefix), &a)); got != prefix+baselineAssignmentIdentityKey(a) || assignmentIdentityKey(a) != baselineAssignmentIdentityKey(a) {
				t.Fatalf("name=%q prefix=%q key=%q want=%q", name, prefix, got, prefix+baselineAssignmentIdentityKey(a))
			}
		}
	}
	for _, id := range []uint{0, 1, 12, 1 << 31, math.MaxInt64, math.MaxUint64} {
		a := models.ItemAssignment{ParticipantID: &id, PersonName: "Ignored"}
		if got := string(appendAssignmentIdentityKey([]byte("kept"), &a)); got != "kept"+baselineAssignmentIdentityKey(a) {
			t.Fatalf("id=%d key=%q", id, got)
		}
	}
}

func TestAssignmentValidationMatchesBaseline(t *testing.T) {
	random := rand.New(rand.NewPCG(4507, 2))
	percentages := []float64{1, 10, 25, 33.33, 50, 100, 0, -1, 100.0000001, 101, math.NaN(), math.Inf(1), math.Copysign(0, -1), 5e-324}
	ids := []uint{0, 1, 2, 3, 12, 1 << 40, math.MaxInt64, math.MaxInt64 + 1}
	valid, invalid := 0, 0
	for i := 0; i < 20000; i++ {
		var updates []ItemAssignmentsUpdate
		for range random.IntN(4) {
			u := ItemAssignmentsUpdate{ItemID: uint(1 + random.IntN(6)), Assignments: []models.ItemAssignment{}}
			if random.IntN(12) == 0 {
				u.ItemID = ids[random.IntN(len(ids))]
			}
			for range random.IntN(4) {
				a := models.ItemAssignment{Percentage: percentages[random.IntN(4)]}
				if random.IntN(10) == 0 {
					a.Percentage = percentages[random.IntN(len(percentages))]
				}
				switch random.IntN(10) {
				case 0:
					id := ids[random.IntN(len(ids))]
					a.ParticipantID = &id
				case 1:
					id := ids[random.IntN(len(ids))]
					a.ParticipantID, a.PersonName = &id, assignmentIdentityNames[random.IntN(len(assignmentIdentityNames))]
				case 2, 3, 4:
					a.PersonName = assignmentIdentityNames[random.IntN(len(assignmentIdentityNames))]
				default:
					a.PersonName = []string{"alex", "Blair", "casey", "Zoë", "界", "12"}[random.IntN(6)]
				}
				u.Assignments = append(u.Assignments, a)
			}
			updates = append(updates, u)
		}
		got, want := ValidateAssignmentUpdates(updates), baselineValidateAssignmentUpdates(updates)
		if got != want {
			t.Fatalf("validation differs: got=%v baseline=%v updates=%+v", got, want, updates)
		}
		if got == nil {
			valid++
		} else {
			invalid++
		}
	}
	if valid < 1000 || invalid < 1000 {
		t.Fatalf("generator lost coverage: valid=%d invalid=%d", valid, invalid)
	}
	for _, size := range []struct{ updates, assignments int }{{500, 100}, {501, 1}, {1, 101}, {500, 0}} {
		var updates []ItemAssignmentsUpdate
		for i := 1; i <= size.updates; i++ {
			u := ItemAssignmentsUpdate{ItemID: uint(i), Assignments: []models.ItemAssignment{}}
			for j := 0; j < size.assignments; j++ {
				u.Assignments = append(u.Assignments, models.ItemAssignment{PersonName: fmt.Sprintf("Person%03d", j), Percentage: 0.5})
			}
			updates = append(updates, u)
		}
		if got, want := ValidateAssignmentUpdates(updates), baselineValidateAssignmentUpdates(updates); got != want {
			t.Fatalf("size %+v: got=%v baseline=%v", size, got, want)
		}
	}
}
