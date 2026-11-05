package bill

import "backend/pkg/safehttp"

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
