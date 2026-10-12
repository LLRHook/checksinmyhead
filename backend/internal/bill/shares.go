package bill

import (
	"backend/pkg/models"
	"math"
	"sort"
	"strings"
)

// BuildPersonShares derives the bill's current shares from its item assignments.
// It is shared by standalone lazy bills and bills attached to a trip.
func BuildPersonShares(bill *models.Bill) []models.PersonShare {
	return buildPersonShares(bill, false)
}

// BuildLazyPersonShares keeps tax and tip apportioned against the complete
// receipt subtotal, so later item claims do not change an earlier person's due.
func BuildLazyPersonShares(bill *models.Bill) []models.PersonShare {
	return buildPersonShares(bill, true)
}

func buildPersonShares(bill *models.Bill, useReceiptSubtotal bool) []models.PersonShare {
	if bill == nil {
		return nil
	}

	personItemTotals := make(map[string]float64)
	personDisplayNames := make(map[string]string)
	for _, item := range bill.Items {
		for _, assignment := range item.Assignments {
			personName := strings.TrimSpace(assignment.PersonName)
			if personName == "" || assignment.Percentage <= 0 {
				continue
			}
			key := strings.ToLower(personName)
			personItemTotals[key] += item.Price * assignment.Percentage / 100
			if existing, ok := personDisplayNames[key]; !ok || (existing == key && personName != key) {
				personDisplayNames[key] = personName
			}
		}
	}
	if len(personItemTotals) == 0 {
		return nil
	}

	assignedAmount := 0.0
	for _, total := range personItemTotals {
		assignedAmount += total
	}
	proportionBase := assignedAmount
	if useReceiptSubtotal && bill.Subtotal > 0 {
		proportionBase = bill.Subtotal
	}

	keys := make([]string, 0, len(personItemTotals))
	for key := range personItemTotals {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	shares := make([]models.PersonShare, 0, len(keys))
	for _, key := range keys {
		subtotal := math.Round(personItemTotals[key]*100) / 100
		proportion := 0.0
		if proportionBase > 0 {
			proportion = subtotal / proportionBase
		}
		taxShare := math.Round(bill.Tax*proportion*100) / 100
		tipShare := math.Round(bill.TipAmount*proportion*100) / 100
		shares = append(shares, models.PersonShare{
			BillID: bill.ID, PersonName: personDisplayNames[key],
			Subtotal: subtotal, TaxShare: taxShare, TipShare: tipShare,
			Total: math.Round((subtotal+taxShare+tipShare)*100) / 100,
		})
	}
	return shares
}
