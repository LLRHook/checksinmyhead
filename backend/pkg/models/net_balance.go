package models

// Party is a tagged identity; labels never participate in equality.
type Party struct {
	Kind          string `json:"kind"`
	TabID         uint   `json:"tab_id,omitempty"`
	MemberID      uint   `json:"member_id,omitempty"`
	BillID        uint   `json:"bill_id,omitempty"`
	ParticipantID uint   `json:"participant_id,omitempty"`
	Label         string `json:"label"`
}
type ReferenceNetBalance struct {
	From   Party   `json:"from"`
	To     Party   `json:"to"`
	Amount float64 `json:"amount"`
}

// NetBalance represents a directed debt: From owes To the given Amount.
type NetBalance struct {
	From   string  `json:"from"`
	To     string  `json:"to"`
	Amount float64 `json:"amount"`
}
