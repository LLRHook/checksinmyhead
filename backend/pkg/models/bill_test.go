package models

import "testing"

func TestItemAssignmentTotalIsValid(t *testing.T) {
	tests := []struct {
		name  string
		total float64
		valid bool
	}{
		{name: "exactly one hundred", total: 100, valid: true},
		{name: "floating point noise", total: 100 + 5e-10, valid: true},
		{name: "real overclaim", total: 100.0001, valid: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := ItemAssignmentTotalIsValid(test.total); got != test.valid {
				t.Fatalf("ItemAssignmentTotalIsValid(%v) = %v, want %v", test.total, got, test.valid)
			}
		})
	}
}
