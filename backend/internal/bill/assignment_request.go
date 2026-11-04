package bill

import "backend/pkg/safehttp"

// AssignmentInputs and AssignmentUpdateInputs are content-only wire DTOs shared
// by standalone and attached routes. Unknown fields retain the old ignored policy.
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

func (v *AssignmentInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeArray[AssignmentInput](data, 100)
	*v = values
	return err
}
func (v *AssignmentUpdateInputs) UnmarshalJSON(data []byte) error {
	values, err := safehttp.DecodeArray[AssignmentUpdateInput](data, 500)
	*v = values
	return err
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
