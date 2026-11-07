package bill

import (
	"backend/pkg/models"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
)

type roundedShare struct {
	key       string
	cents     int64
	lastClaim time.Time
}

// Check the rounded value before converting: float64(MaxInt64) is already 2^63.
func roundedCents(amount float64) (int64, error) {
	cents := math.Round(amount * 100)
	if !finite(cents) || cents < float64(math.MinInt64) || cents >= float64(math.MaxInt64) {
		return 0, ErrInvalidCreation
	}
	return int64(cents), nil
}

func addCents(a, b int64) (int64, error) {
	if (b > 0 && a > math.MaxInt64-b) || (b < 0 && a < math.MinInt64-b) {
		return 0, ErrInvalidCreation
	}
	return a + b, nil
}

func allocateRoundedCents(raw map[string]float64, lastClaimByPerson map[string]time.Time) (map[string]float64, error) {
	return allocateRoundedCentsOrdered(raw, lastClaimByPerson, nil)
}
func allocateRoundedCentsOrdered(raw map[string]float64, lastClaimByPerson map[string]time.Time, order map[string]allocationTie) (map[string]float64, error) {
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
		baseCents, err := roundedCents(amount)
		if err != nil {
			return nil, err
		}
		rawTotal += amount
		if !finite(rawTotal) {
			return nil, ErrInvalidCreation
		}
		allocated, err = addCents(allocated, baseCents)
		if err != nil {
			return nil, err
		}
		shares = append(shares, roundedShare{key: key, cents: baseCents, lastClaim: lastClaimByPerson[key]})
	}
	if len(shares) == 0 {
		return map[string]float64{}, nil
	}
	target, err := roundedCents(rawTotal)
	if err != nil {
		return nil, err
	}
	// Subtraction is checked separately so even MinInt64 is never negated.
	if (allocated > 0 && target < math.MinInt64+allocated) || (allocated < 0 && target > math.MaxInt64+allocated) {
		return nil, ErrInvalidCreation
	}
	remaining := target - allocated
	sort.Slice(shares, func(i, j int) bool {
		if shares[i].lastClaim.Equal(shares[j].lastClaim) {
			a, aok := order[shares[i].key]
			b, bok := order[shares[j].key]
			if aok && bok {
				if a.label != b.label {
					return a.label < b.label
				}
				if a.ordinal != b.ordinal {
					return a.ordinal < b.ordinal
				}
			}
			return shares[i].key < shares[j].key
		}
		return shares[i].lastClaim.After(shares[j].lastClaim)
	})
	if err := distributeRemainder(shares, remaining); err != nil {
		return nil, err
	}
	result := make(map[string]float64, len(shares))
	for _, share := range shares {
		result[share.key] = float64(share.cents) / 100
	}
	return result, nil
}

// Cycle in the already sorted claim/name order. Negative adjustments skip zero
// balances. Whole rounds are collapsed so work never depends on the cent count.
func distributeRemainder(shares []roundedShare, remaining int64) error {
	if len(shares) == 0 {
		if remaining != 0 {
			return ErrInvalidCreation
		}
		return nil
	}
	if remaining < 0 {
		if remaining == math.MinInt64 {
			return ErrInvalidCreation
		}
		levels := make([]int64, 0, len(shares))
		var available int64
		for _, s := range shares {
			if s.cents < 0 {
				return ErrInvalidCreation
			}
			var err error
			available, err = addCents(available, s.cents)
			if err != nil {
				return err
			}
			if s.cents > 0 {
				levels = append(levels, s.cents)
			}
		}
		debt := -remaining
		if debt > available {
			return ErrInvalidCreation
		}
		sort.Slice(levels, func(i, j int) bool { return levels[i] < levels[j] })
		var rounds int64
		active := int64(len(levels))
		for _, next := range levels {
			step := next - rounds
			if step > debt/active {
				rounds += debt / active
				debt %= active
				break
			}
			debt -= step * active
			rounds = next
			active--
			if debt == 0 {
				break
			}
		}
		for i := range shares {
			before := shares[i].cents
			shares[i].cents -= min(before, rounds)
			if before > rounds && debt > 0 {
				shares[i].cents--
				debt--
			}
		}
		return nil
	}
	count := int64(len(shares))
	each, residual := remaining/count, remaining%count
	for i := range shares {
		delta := each
		if residual > 0 && int64(i) < residual {
			delta++
		}
		cents, err := addCents(shares[i].cents, delta)
		if err != nil {
			return err
		}
		shares[i].cents = cents
	}
	return nil
}

// shareCalculation retains the unrounded accounting and positional breakdowns.
// Creation validates its client projection and receipt limits against these same
// values before the shared allocator is allowed to convert anything to cents.
type shareCalculation struct {
	source       *models.Bill
	order        map[string]allocationTie
	participants map[string]models.BillParticipant

	keys                      []string
	subtotals, taxes, tips    map[string]float64
	details                   map[string][]models.ItemDetail
	names                     map[string]string
	lastClaims                map[string]time.Time
	subtotal, tax, tip, total float64
}

func calculatePersonShares(bill *models.Bill, useReceiptSubtotal bool) (*shareCalculation, error) {
	c := &shareCalculation{source: bill, subtotals: map[string]float64{}, taxes: map[string]float64{}, tips: map[string]float64{}, details: map[string][]models.ItemDetail{}, names: map[string]string{}, lastClaims: map[string]time.Time{}}
	if bill == nil {
		return c, nil
	}
	c.order = allocationOrder(bill)
	c.participants = map[string]models.BillParticipant{}
	for _, p := range bill.ParticipantRows {
		c.participants[strconv.FormatUint(uint64(p.ID), 10)] = p
	}
	for _, value := range []float64{bill.Subtotal, bill.Tax, bill.TipAmount} {
		if !money(value) || value < 0 {
			return nil, ErrInvalidCreation
		}
	}
	for _, item := range bill.Items {
		if !money(item.Price) {
			return nil, ErrInvalidCreation
		}
		for _, assignment := range item.Assignments {
			personName := strings.TrimSpace(assignment.PersonName)
			if (personName == "" && bill.InputVersion != 2 && bill.IdentityVersion != 2) || !finite(assignment.Percentage) || assignment.Percentage <= 0 || assignment.Percentage > 100 {
				return nil, ErrInvalidCreation
			}
			key := assignmentKey(bill, assignment)
			if bill.IdentityVersion == 2 {
				p, ok := c.participants[key]
				if !ok || assignment.IdentityVersion != 2 || assignment.BillID == nil || *assignment.BillID != bill.ID {
					return nil, ErrIdentityReview
				}
				personName = p.Label
			}
			amount := item.Price * assignment.Percentage / 100
			if !money(amount) || !money(c.subtotals[key]+amount) {
				return nil, ErrInvalidCreation
			}
			c.subtotals[key] += amount
			c.details[key] = append(c.details[key], models.ItemDetail{Name: item.Name, Amount: amount, IsShared: assignment.Percentage < 99.99})
			if assignment.CreatedAt.After(c.lastClaims[key]) {
				c.lastClaims[key] = assignment.CreatedAt
			}
			if existing, ok := c.names[key]; !ok || (existing == key && personName != key) {
				c.names[key] = personName
			}
		}
	}
	for key := range c.subtotals {
		c.keys = append(c.keys, key)
	}
	sort.Strings(c.keys)
	for _, key := range c.keys {
		amount := c.subtotals[key]
		if amount < 0 {
			return nil, ErrInvalidCreation
		}
		c.subtotal += amount
	}
	if !money(c.subtotal) {
		return nil, ErrInvalidCreation
	}
	base := c.subtotal
	if useReceiptSubtotal && bill.Subtotal > 0 {
		base = bill.Subtotal
	}
	for _, key := range c.keys {
		ratio := 0.0
		if base > 0 {
			ratio = c.subtotals[key] / base
		}
		if !finite(ratio) {
			return nil, ErrInvalidCreation
		}
		c.taxes[key], c.tips[key] = bill.Tax*ratio, bill.TipAmount*ratio
		obligation := c.subtotals[key] + c.taxes[key] + c.tips[key]
		for _, value := range []float64{c.taxes[key], c.tips[key], obligation} {
			if !money(value) || value < 0 {
				return nil, ErrInvalidCreation
			}
		}
		c.tax += c.taxes[key]
		c.tip += c.tips[key]
		c.total += obligation
	}
	for _, value := range []float64{c.tax, c.tip, c.total} {
		if !money(value) {
			return nil, ErrInvalidCreation
		}
	}
	return c, nil
}

func (c *shareCalculation) rounded(billID uint) ([]models.PersonShare, error) {
	subtotals, err := allocateRoundedCentsOrdered(c.subtotals, c.lastClaims, c.order)
	if err != nil {
		return nil, err
	}
	taxes, err := allocateRoundedCentsOrdered(c.taxes, c.lastClaims, c.order)
	if err != nil {
		return nil, err
	}
	tips, err := allocateRoundedCentsOrdered(c.tips, c.lastClaims, c.order)
	if err != nil {
		return nil, err
	}
	shares := make([]models.PersonShare, 0, len(c.keys))
	var total float64
	for _, key := range c.keys {
		obligation := math.Round((subtotals[key]+taxes[key]+tips[key])*100) / 100
		if !money(obligation) || obligation < 0 {
			return nil, ErrInvalidCreation
		}
		total += obligation
		next := models.PersonShare{BillID: billID, PersonName: c.names[key], Items: c.details[key], Subtotal: subtotals[key], TaxShare: taxes[key], TipShare: tips[key], Total: obligation}
		if c.source != nil && c.source.InputVersion == 2 {
			next.ParticipantRef = key
		}
		if p, ok := c.participants[key]; ok {
			id := p.ID
			next.ParticipantID = &id
			next.IdentityVersion = 2
		}
		shares = append(shares, next)
	}
	if !money(total) {
		return nil, ErrInvalidCreation
	}
	return shares, nil
}

// BuildPersonShares derives the bill's current shares from its item assignments.
// Invalid arithmetic is an error so callers can roll back instead of dropping people.
func BuildPersonShares(bill *models.Bill) ([]models.PersonShare, error) {
	return buildPersonShares(bill, false)
}

// BuildLazyPersonShares apportions tax and tip against the full receipt subtotal.
func BuildLazyPersonShares(bill *models.Bill) ([]models.PersonShare, error) {
	return buildPersonShares(bill, true)
}

func buildPersonShares(bill *models.Bill, useReceiptSubtotal bool) ([]models.PersonShare, error) {
	c, err := calculatePersonShares(bill, useReceiptSubtotal)
	if err != nil {
		return nil, err
	}
	var billID uint
	if bill != nil {
		billID = bill.ID
	}
	return c.rounded(billID)
}
