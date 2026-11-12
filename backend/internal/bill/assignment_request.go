package bill

import (
	"backend/pkg/safehttp"
	"bytes"
	"encoding/json/jsontext"
	"strconv"
	"strings"
	"unicode/utf8"
)

// AssignmentInputs and AssignmentUpdateInputs retain the content-only wire1
// contract: unknown fields are ignored and cannot become stored privileges.
type AssignmentInput struct {
	PersonName string  `json:"person_name"`
	Percentage float64 `json:"percentage"`
}
type AssignmentInputs []AssignmentInput
type AssignmentUpdateInput struct {
	ItemID            uint             `json:"item_id"`
	ExpectedUpdatedAt *string          `json:"expected_updated_at"`
	Assignments       AssignmentInputs `json:"assignments"`
}
type AssignmentUpdateInputs []AssignmentUpdateInput

// Both collections bind from the decoder (safehttp.DecodeJSONStream), not from a
// buffered copy of the document. Updates stop at element 501. Each assignment
// array is read once as a complete value the decoder has already validated.
func (v *AssignmentUpdateInputs) UnmarshalJSONFrom(dec *jsontext.Decoder) error {
	values, err := safehttp.DecodeArrayFrom[AssignmentUpdateInput](dec, 500)
	*v = values
	return err
}
func (v *AssignmentInputs) UnmarshalJSONFrom(dec *jsontext.Decoder) error {
	raw, err := dec.ReadValue()
	if err != nil {
		return err
	}
	values, canonical := canonicalAssignments(raw)
	if !canonical {
		values, err = safehttp.DecodeArray[AssignmentInput](raw, 100)
		// The plain binder cannot admit NUL: escapes/control bytes fall back.
		// Validate the stdlib fallback here, before returning decoded inputs.
		for _, value := range values {
			if strings.ContainsRune(value.PersonName, 0) {
				values, err = nil, safehttp.ErrInvalidJSON
				break
			}
		}
	}
	*v = values
	return err
}

const (
	personNameMember = `"person_name"`
	percentageMember = `"percentage"`
)

// canonicalAssignments binds the plain shape without a second generic decode:
// a non-empty array of at most 100 objects, each holding exactly one
// "person_name" string and one "percentage" number under those exact names, in
// either order, with optional JSON whitespace. Names must be free of escapes and
// valid UTF-8, so the bytes between the quotes are the value; numbers convert as
// strconv.ParseFloat does in encoding/json (see canonicalNumber).
//
// It reports false, deciding nothing, for every other input: null, empty, other
// kinds, other or repeated or missing names, case variants, escapes, invalid
// UTF-8, null members, out-of-range numbers and excess counts all take the
// stdlib path in safehttp.DecodeArray, which owns their results and errors.
// Everything it accepts is valid JSON on its own account; production input is
// additionally one value already validated by jsontext.Decoder.ReadValue.
// All names of one array share a single allocation of exactly their bytes.
func canonicalAssignments(raw []byte) (AssignmentInputs, bool) {
	if len(raw) < 2 || raw[0] != '[' {
		return nil, false
	}
	var names [100]struct{ start, end int }
	values := make(AssignmentInputs, 0, min(bytes.Count(raw, []byte{'{'}), 100))
	nameBytes := 0
	i := skipJSONSpace(raw, 1)
	for {
		if i >= len(raw) || raw[i] != '{' || len(values) == 100 {
			return nil, false
		}
		i = skipJSONSpace(raw, i+1)
		var value AssignmentInput
		var name struct{ start, end int }
		var hasName, hasPercentage bool
		for member := 0; member < 2; member++ {
			if member == 1 {
				if i >= len(raw) || raw[i] != ',' {
					return nil, false
				}
				i = skipJSONSpace(raw, i+1)
			}
			switch {
			case !hasName && hasJSONMember(raw, i, personNameMember):
				i = skipJSONColon(raw, i+len(personNameMember))
				if i >= len(raw) || raw[i] != '"' {
					return nil, false
				}
				start := i + 1
				length := bytes.IndexByte(raw[start:], '"')
				if length < 0 {
					return nil, false
				}
				// A backslash rules out an escaped quote before this one.
				var union byte
				for _, c := range raw[start : start+length] {
					if c < ' ' || c == '\\' {
						return nil, false
					}
					union |= c
				}
				if union >= utf8.RuneSelf && !utf8.Valid(raw[start:start+length]) {
					return nil, false
				}
				name.start, name.end, hasName = start, start+length, true
				i = start + length + 1
			case !hasPercentage && hasJSONMember(raw, i, percentageMember):
				var ok bool
				if value.Percentage, i, ok = canonicalNumber(raw, skipJSONColon(raw, i+len(percentageMember))); !ok {
					return nil, false
				}
				hasPercentage = true
			default:
				return nil, false
			}
			i = skipJSONSpace(raw, i)
		}
		if i >= len(raw) || raw[i] != '}' {
			return nil, false
		}
		names[len(values)] = name
		nameBytes += name.end - name.start
		values = append(values, value)
		i = skipJSONSpace(raw, i+1)
		if i >= len(raw) {
			return nil, false
		}
		if raw[i] == ']' {
			if i+1 != len(raw) {
				return nil, false
			}
			break
		}
		if raw[i] != ',' {
			return nil, false
		}
		i = skipJSONSpace(raw, i+1)
	}
	var joined strings.Builder
	joined.Grow(nameBytes)
	for _, name := range names[:len(values)] {
		joined.Write(raw[name.start:name.end])
	}
	text, offset := joined.String(), 0
	for k, name := range names[:len(values)] {
		values[k].PersonName = text[offset : offset+name.end-name.start]
		offset += name.end - name.start
	}
	return values, true
}
func hasJSONMember(raw []byte, i int, member string) bool {
	return len(raw)-i >= len(member) && string(raw[i:i+len(member)]) == member
}
func skipJSONSpace(raw []byte, i int) int {
	for i < len(raw) && raw[i] <= ' ' && (raw[i] == ' ' || raw[i] == '\n' || raw[i] == '\t' || raw[i] == '\r') {
		i++
	}
	return i
}

// canonicalNumber returns the float64 for the JSON number at i and its end.
// One to fifteen digits without sign, fraction or exponent is an integer below
// 2^53, which float64 holds exactly and strconv.ParseFloat returns unchanged.
// Every other well-formed number goes to strconv.ParseFloat; a range error is
// left to the stdlib path.
func canonicalNumber(raw []byte, i int) (float64, int, bool) {
	integer, end := uint64(0), i
	for end < len(raw) && end-i < 16 && raw[end] >= '0' && raw[end] <= '9' {
		integer = integer*10 + uint64(raw[end]-'0')
		end++
	}
	plain := end == len(raw) || (raw[end] != '.' && raw[end] != 'e' && raw[end] != 'E')
	if digits := end - i; plain && digits >= 1 && digits <= 15 && (digits == 1 || raw[i] != '0') {
		return float64(integer), end, true
	}
	if end = jsonNumberEnd(raw, i); end < 0 {
		return 0, 0, false
	}
	number, err := strconv.ParseFloat(string(raw[i:end]), 64)
	return number, end, err == nil
}

// skipJSONColon returns the index of the member value, or len(raw) when the
// name is not followed by a colon.
func skipJSONColon(raw []byte, i int) int {
	i = skipJSONSpace(raw, i)
	if i >= len(raw) || raw[i] != ':' {
		return len(raw)
	}
	return skipJSONSpace(raw, i+1)
}

// jsonNumberEnd returns the end of the RFC 8259 number starting at i, or -1.
func jsonNumberEnd(raw []byte, i int) int {
	digits := func() bool {
		start := i
		for i < len(raw) && raw[i] >= '0' && raw[i] <= '9' {
			i++
		}
		return i > start
	}
	if i < len(raw) && raw[i] == '-' {
		i++
	}
	if i < len(raw) && raw[i] == '0' {
		i++
	} else if !digits() {
		return -1
	}
	if i < len(raw) && raw[i] == '.' {
		i++
		if !digits() {
			return -1
		}
	}
	if i < len(raw) && (raw[i] == 'e' || raw[i] == 'E') {
		i++
		if i < len(raw) && (raw[i] == '+' || raw[i] == '-') {
			i++
		}
		if !digits() {
			return -1
		}
	}
	return i
}
func AssignmentInputCountsValid(updates AssignmentUpdateInputs) bool {
	if len(updates) == 0 || len(updates) > 500 {
		return false
	}
	count := 0
	for _, u := range updates {
		if len(u.Assignments) > 100 {
			return false
		}
		count += len(u.Assignments)
		if count > 50000 {
			return false
		}
	}
	return true
}

// Wire2 has a separate strict reference DTO at the same decoder owner. It does
// not change wire1 decoding or bind a hydrated persistence model.
type referenceAssignmentInput struct {
	ParticipantID *uint   `json:"participant_id"`
	Percentage    float64 `json:"percentage"`
}
type referenceAssignmentInputs []referenceAssignmentInput
type referenceUpdateInput struct {
	ItemID            uint                      `json:"item_id"`
	ExpectedUpdatedAt *string                   `json:"expected_updated_at"`
	Assignments       referenceAssignmentInputs `json:"assignments"`
}
type referenceUpdateInputs []referenceUpdateInput

func (v *referenceAssignmentInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeStrictArray[referenceAssignmentInput](data, 100)
	*v = values
	return err
}
func (v *referenceUpdateInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeStrictArray[referenceUpdateInput](data, 500)
	*v = values
	return err
}
