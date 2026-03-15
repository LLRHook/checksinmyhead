package models

// NetBalance represents a directed debt: From owes To the given Amount.
type NetBalance struct {
	From   string  `json:"from"`
	To     string  `json:"to"`
	Amount float64 `json:"amount"`
}
