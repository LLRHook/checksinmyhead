package tab

import (
	"backend/pkg/models"
	"math"
	"sort"
	"strings"
)

func roundToCent(value float64) float64 {
	return math.Round(value*100) / 100
}

// buildPersonShares computes person shares from bill item assignments.
// It mirrors the proportional split logic used by the mobile app.
func buildPersonShares(bill *models.Bill) []models.PersonShare {
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

	keys := make([]string, 0, len(personItemTotals))
	for key := range personItemTotals {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	shares := make([]models.PersonShare, 0, len(keys))
	for _, key := range keys {
		subtotal := roundToCent(personItemTotals[key])
		var proportion float64
		if assignedAmount > 0 {
			proportion = subtotal / assignedAmount
		}

		taxShare := roundToCent(bill.Tax * proportion)
		tipShare := roundToCent(bill.TipAmount * proportion)

		shares = append(shares, models.PersonShare{
			BillID:     bill.ID,
			PersonName: personDisplayNames[key],
			Subtotal:   subtotal,
			TaxShare:   taxShare,
			TipShare:   tipShare,
			Total:      roundToCent(subtotal + taxShare + tipShare),
			Paid:       false,
		})
	}

	return shares
}
