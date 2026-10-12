package bill

import (
	"backend/pkg/models"
	"math"
	"sort"
	"strings"
	"time"
)

type roundedShare struct {
	key       string
	cents     int64
	lastClaim time.Time
}

func allocateRoundedCents(raw map[string]float64, lastClaimByPerson map[string]time.Time) map[string]float64 {
	shares := make([]roundedShare, 0, len(raw))
	var rawTotal float64
	var allocated int64
	keys := make([]string, 0, len(raw))
	for key := range raw {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		amount := raw[key]
		rawTotal += amount
		baseCents := int64(math.Round(amount * 100))
		shares = append(shares, roundedShare{
			key: key, cents: baseCents, lastClaim: lastClaimByPerson[key],
		})
		allocated += baseCents
	}
	if len(shares) == 0 {
		return map[string]float64{}
	}

	remaining := int64(math.Round(rawTotal*100)) - allocated
	sort.Slice(shares, func(i, j int) bool {
		if shares[i].lastClaim.Equal(shares[j].lastClaim) {
			return shares[i].key < shares[j].key
		}
		return shares[i].lastClaim.After(shares[j].lastClaim)
	})
	for index := int64(0); index < absInt64(remaining); index++ {
		if remaining > 0 {
			shares[index%int64(len(shares))].cents++
		} else if remaining < 0 {
			shares[index%int64(len(shares))].cents--
		}
	}
	result := make(map[string]float64, len(shares))
	for _, share := range shares {
		result[share.key] = float64(share.cents) / 100
	}
	return result
}

func absInt64(value int64) int64 {
	if value < 0 {
		return -value
	}
	return value
}

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
	lastClaimByPerson := make(map[string]time.Time)
	for _, item := range bill.Items {
		for _, assignment := range item.Assignments {
			personName := strings.TrimSpace(assignment.PersonName)
			if personName == "" || assignment.Percentage <= 0 {
				continue
			}
			key := strings.ToLower(personName)
			personItemTotals[key] += item.Price * assignment.Percentage / 100
			if assignment.CreatedAt.After(lastClaimByPerson[key]) {
				lastClaimByPerson[key] = assignment.CreatedAt
			}
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

	subtotalShares := allocateRoundedCents(personItemTotals, lastClaimByPerson)
	taxRaw := make(map[string]float64, len(keys))
	tipRaw := make(map[string]float64, len(keys))
	for _, key := range keys {
		proportion := 0.0
		if proportionBase > 0 {
			proportion = personItemTotals[key] / proportionBase
		}
		taxRaw[key] = bill.Tax * proportion
		tipRaw[key] = bill.TipAmount * proportion
	}
	taxShares := allocateRoundedCents(taxRaw, lastClaimByPerson)
	tipShares := allocateRoundedCents(tipRaw, lastClaimByPerson)

	shares := make([]models.PersonShare, 0, len(keys))
	for _, key := range keys {
		subtotal := subtotalShares[key]
		taxShare := taxShares[key]
		tipShare := tipShares[key]
		shares = append(shares, models.PersonShare{
			BillID: bill.ID, PersonName: personDisplayNames[key],
			Subtotal: subtotal, TaxShare: taxShare, TipShare: tipShare,
			Total: math.Round((subtotal+taxShare+tipShare)*100) / 100,
		})
	}
	return shares
}
