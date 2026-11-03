package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"math"
	"sort"
	"strings"
	"time"
)

// FrozenUSDShareCents validates persisted accounting without normalizing or
// rewriting its evidence. Known legacy USD identity is interpreted in memory.
func FrozenUSDShareCents(b models.Bill) ([]int64, error) {
	result := make([]int64, len(b.PersonShares))
	code := strings.ToUpper(strings.TrimSpace(b.CurrencyCode))
	rate, frozen := b.USDExchangeRate, b.USDTotal
	if !finite(b.Total) || b.Total < 0 {
		return nil, mutation.Review
	}
	native, err := roundedCents(b.Total)
	if err != nil {
		return nil, mutation.Review
	}
	if code == "" || code == "USD" {
		if rate != 0 && rate != 1 {
			return nil, mutation.Review
		}
		rate = 1
		if frozen == 0 {
			frozen = float64(native) / 100
		}
	} else {
		if !currencyCodePattern.MatchString(code) || !finite(rate) || rate <= 0 || strings.TrimSpace(b.ExchangeRateSource) == "" {
			return nil, mutation.Review
		}
		if _, err := time.Parse("2006-01-02", b.ExchangeRateDate); err != nil {
			return nil, mutation.Review
		}
	}
	frozenCents, err := roundedCents(frozen)
	if err != nil || frozen < 0 {
		return nil, mutation.Review
	}
	expected, err := roundedCents(b.Total * rate)
	if err != nil || expected != frozenCents {
		return nil, mutation.Review
	}
	total := 0.0
	for _, s := range b.PersonShares {
		for _, v := range []float64{s.Subtotal, s.TaxShare, s.TipShare, s.Total} {
			if !finite(v) || v < 0 {
				return nil, mutation.Review
			}
			if _, err := roundedCents(v); err != nil {
				return nil, mutation.Review
			}
		}
		for _, item := range s.Items {
			if !finite(item.Amount) {
				return nil, mutation.Review
			}
			if _, err := roundedCents(item.Amount); err != nil {
				return nil, mutation.Review
			}
		}
		total += s.Total
		if !finite(total) {
			return nil, mutation.Review
		}
	}
	if total == 0 {
		return result, nil
	}
	target, err := roundedCents(total * rate)
	if err != nil {
		return nil, mutation.Review
	}
	if math.Abs(total-b.Total) < 0.005 {
		target = frozenCents
	}
	// Retain the established full/partial rule; never scale an unclaimed receipt.
	if total > b.Total+0.005 {
		return nil, mutation.Review
	}
	type remainder struct {
		index    int
		fraction float64
		name     string
	}
	order := make([]remainder, len(result))
	var allocated int64
	for i, s := range b.PersonShares {
		intermediate := float64(target) * s.Total
		if !finite(intermediate) {
			return nil, mutation.Review
		}
		exact := intermediate / total
		if !finite(exact) || exact < 0 || exact >= float64(math.MaxInt64) {
			return nil, mutation.Review
		}
		result[i] = int64(exact)
		allocated, err = addCents(allocated, result[i])
		if err != nil {
			return nil, mutation.Review
		}
		order[i] = remainder{i, exact - float64(result[i]), s.PersonName}
	}
	sort.SliceStable(order, func(i, j int) bool {
		if order[i].fraction != order[j].fraction {
			return order[i].fraction > order[j].fraction
		}
		if order[i].name != order[j].name {
			return order[i].name < order[j].name
		}
		return order[i].index < order[j].index
	})
	shares := make([]roundedShare, len(order))
	for i, r := range order {
		shares[i].cents = result[r.index]
	}
	if err := distributeRemainder(shares, target-allocated); err != nil {
		return nil, mutation.Review
	}
	for i, r := range order {
		if shares[i].cents < 0 {
			return nil, mutation.Review
		}
		result[r.index] = shares[i].cents
	}
	return result, nil
}

func AddObligationCents(a, b int64) (int64, error) {
	sum, err := addCents(a, b)
	if err != nil {
		return 0, mutation.Review
	}
	return sum, nil
}

// ObligationDollars refuses a value the persisted float column cannot round-trip
// to the checked cents. A successful snapshot must remain replayable.
func ObligationDollars(cents int64) (float64, error) {
	amount := float64(cents) / 100
	roundTrip, err := roundedCents(amount)
	if err != nil || roundTrip != cents {
		return 0, mutation.Review
	}
	return amount, nil
}
