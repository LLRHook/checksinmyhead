package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"math"
	"sort"
	"strings"
)

func grossSettlements(tabID uint, bills []models.Bill) ([]models.TabSettlement, error) {
	if len(bills) == 0 {
		return nil, mutation.NoBills
	}
	totals := map[string]int64{}
	names := map[string]string{}
	for _, b := range bills {
		cents, err := billpkg.FrozenUSDShareCents(b)
		if err != nil {
			return nil, err
		}
		seen := map[string]bool{}
		for i, s := range b.PersonShares {
			key := strings.ToLower(s.PersonName)
			normalized := strings.ToLower(strings.TrimSpace(s.PersonName))
			if normalized == "" || seen[normalized] {
				return nil, mutation.Review
			}
			seen[normalized] = true
			totals[key], err = billpkg.AddObligationCents(totals[key], cents[i])
			if err != nil {
				return nil, err
			}
			if old, ok := names[key]; !ok || (old == key && s.PersonName != key) {
				names[key] = s.PersonName
			}
		}
	}
	if len(totals) == 0 {
		return nil, mutation.NoAllocation
	}
	keys := make([]string, 0, len(totals))
	for key := range totals {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	result := make([]models.TabSettlement, 0, len(keys))
	var aggregate int64
	for _, key := range keys {
		var err error
		aggregate, err = billpkg.AddObligationCents(aggregate, totals[key])
		if err != nil {
			return nil, err
		}
		amount, err := billpkg.ObligationDollars(totals[key])
		if err != nil {
			return nil, err
		}
		result = append(result, models.TabSettlement{TabID: tabID, PersonName: names[key], Amount: amount})
	}
	return result, nil
}

func validStoredSnapshot(t models.Tab, rows []models.TabSettlement) error {
	if !t.Finalized || t.FinalizedAt == nil || t.FinalizedAt.IsZero() || len(rows) == 0 {
		return mutation.Review
	}
	seen := map[string]bool{}
	var aggregate int64
	for _, s := range rows {
		key := strings.ToLower(s.PersonName)
		cents := math.Round(s.Amount * 100)
		if s.ID == 0 || s.TabID != t.ID || s.CreatedAt.IsZero() || strings.TrimSpace(key) == "" || seen[key] || math.IsNaN(cents) || math.IsInf(cents, 0) || cents < 0 || cents >= float64(math.MaxInt64) || math.Abs(s.Amount*100-cents) > 1e-6 {
			return mutation.Review
		}
		seen[key] = true
		var err error
		aggregate, err = billpkg.AddObligationCents(aggregate, int64(cents))
		if err != nil {
			return err
		}
	}
	return nil
}
