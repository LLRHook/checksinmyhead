package bill

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"backend/pkg/security"
	"encoding/json"
	"errors"
	"io"
	"math"
	"net/http"
	"sort"
	"strings"
	"unicode/utf8"
)

const createBodyLimit = 1 << 20
const maxMoney = 1e9
const moneyTolerance = .01 + 1e-7

var ErrInvalidCreation = errors.New("invalid standalone bill content")

// CreateBillRequest is the public content contract. No request type embeds a
// persistence model: identity, ownership, paid state and quote metadata are not input.
type CreateBillRequest struct {
	Name            *string         `json:"name"`
	LazyMode        bool            `json:"lazy_mode"`
	Subtotal        *float64        `json:"subtotal"`
	Tax             float64         `json:"tax"`
	TipAmount       float64         `json:"tip_amount"`
	TipPercentage   float64         `json:"tip_percentage"`
	Total           *float64        `json:"total"`
	CurrencyCode    string          `json:"currency_code"`
	DisplayCurrency string          `json:"display_currency"`
	Participants    []createPerson  `json:"participants"`
	Items           []createItem    `json:"items"`
	PersonShares    []createShare   `json:"person_shares"`
	PaymentMethods  []createPayment `json:"payment_methods"`
}
type createPerson struct {
	Name string `json:"name"`
}
type createItem struct {
	Name        string             `json:"name"`
	Price       *float64           `json:"price"`
	Assignments []createAssignment `json:"assignments"`
}
type createAssignment struct {
	PersonName string  `json:"person_name"`
	Percentage float64 `json:"percentage"`
}
type createShare struct {
	PersonName string         `json:"person_name"`
	Items      []createDetail `json:"items"`
	Subtotal   float64        `json:"subtotal"`
	TaxShare   float64        `json:"tax_share"`
	TipShare   float64        `json:"tip_share"`
	Total      float64        `json:"total"`
}
type createDetail struct {
	Name     string  `json:"name"`
	Amount   float64 `json:"amount"`
	IsShared bool    `json:"is_shared"`
}
type createPayment struct {
	Name       string `json:"name"`
	Identifier string `json:"identifier"`
}

func decodeCreateBill(w http.ResponseWriter, r *http.Request) (*models.Bill, error) {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, createBodyLimit))
	decoder.DisallowUnknownFields()
	var request CreateBillRequest
	if err := decoder.Decode(&request); err != nil {
		return nil, ErrInvalidCreation
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return nil, ErrInvalidCreation
	}
	if request.Name == nil || request.Subtotal == nil || request.Total == nil {
		return nil, ErrInvalidCreation
	}
	b := &models.Bill{Name: *request.Name, LazyMode: request.LazyMode, Subtotal: *request.Subtotal,
		Tax: request.Tax, TipAmount: request.TipAmount, TipPercentage: request.TipPercentage, Total: *request.Total,
		CurrencyCode: request.CurrencyCode, DisplayCurrency: request.DisplayCurrency}
	for _, p := range request.Participants {
		b.Participants = append(b.Participants, models.Person{Name: p.Name})
	}
	for _, item := range request.Items {
		if item.Price == nil {
			return nil, ErrInvalidCreation
		}
		next := models.BillItem{Name: item.Name, Price: *item.Price}
		for _, a := range item.Assignments {
			next.Assignments = append(next.Assignments, models.ItemAssignment{PersonName: a.PersonName, Percentage: a.Percentage})
		}
		b.Items = append(b.Items, next)
	}
	for _, s := range request.PersonShares {
		next := models.PersonShare{PersonName: s.PersonName, Subtotal: s.Subtotal, TaxShare: s.TaxShare, TipShare: s.TipShare, Total: s.Total, Items: []models.ItemDetail{}}
		for _, item := range s.Items {
			next.Items = append(next.Items, models.ItemDetail{Name: item.Name, Amount: item.Amount, IsShared: item.IsShared})
		}
		b.PersonShares = append(b.PersonShares, next)
	}
	for _, p := range request.PaymentMethods {
		b.PaymentMethods = append(b.PaymentMethods, models.PaymentMethod{Name: p.Name, Identifier: p.Identifier})
	}
	return b, nil
}

func finite(v float64) bool  { return !math.IsNaN(v) && !math.IsInf(v, 0) }
func money(v float64) bool   { return finite(v) && math.Abs(v) <= maxMoney }
func near(a, b float64) bool { return finite(a) && finite(b) && math.Abs(a-b) <= moneyTolerance }
func cleanName(s string, limit int) (string, error) {
	s = security.SanitizeString(s)
	if s == "" || !utf8.ValidString(s) || utf8.RuneCountInString(s) > limit {
		return "", ErrInvalidCreation
	}
	return s, nil
}
func nameKey(s string) string { return strings.ToLower(s) }

// guardFreshCreation is repeated at the persistence boundary so internal callers
// cannot reparent existing associations or create a bill inside a tab.
func guardFreshCreation(b *models.Bill) error {
	if b == nil || b.ID != 0 || b.TabID != nil || b.Tab != nil || b.AddedByMemberID != nil || b.PaidByMemberID != nil ||
		!b.Date.IsZero() || !b.CreatedAt.IsZero() || !b.UpdatedAt.IsZero() {
		return ErrInvalidCreation
	}
	for _, p := range b.Participants {
		if p.ID != 0 {
			return ErrInvalidCreation
		}
	}
	for _, item := range b.Items {
		if item.ID != 0 || item.BillID != 0 || !item.CreatedAt.IsZero() || !item.UpdatedAt.IsZero() {
			return ErrInvalidCreation
		}
		for _, a := range item.Assignments {
			if a.ID != 0 || a.BillItemID != 0 || !a.CreatedAt.IsZero() || !a.UpdatedAt.IsZero() {
				return ErrInvalidCreation
			}
		}
	}
	for _, s := range b.PersonShares {
		if s.ID != 0 || s.BillID != 0 || s.Paid {
			return ErrInvalidCreation
		}
	}
	return nil
}

// prepareCreation validates before quoting or writing, then derives fresh shares.
// Legacy projections are evidence of the client's calculation, never stored graphs.
func prepareCreation(b *models.Bill) error {
	if err := guardFreshCreation(b); err != nil {
		return err
	}
	if b.DisplayTotal != nil && !finite(*b.DisplayTotal) {
		return ErrInvalidCreation
	}
	if b.ExchangeRate != nil && (!finite(*b.ExchangeRate) || *b.ExchangeRate <= 0) {
		return ErrInvalidCreation
	}
	var err error
	if b.Name, err = cleanName(b.Name, 255); err != nil {
		return err
	}
	b.CurrencyCode = currency.Normalize(b.CurrencyCode)
	if b.CurrencyCode == "" {
		b.CurrencyCode = "USD"
	}
	b.DisplayCurrency = currency.Normalize(b.DisplayCurrency)
	if b.DisplayCurrency == "" {
		b.DisplayCurrency = b.CurrencyCode
	}
	if !currency.ReceiptSupported(b.CurrencyCode) {
		return ErrInvalidCurrency
	}
	// Provider-defined display pairs are independent of the receipt whitelist.
	if !currency.ValidCode(b.DisplayCurrency) {
		return ErrInvalidCurrency
	}
	for _, v := range []float64{b.Subtotal, b.Tax, b.TipAmount, b.Total, b.TipPercentage} {
		if !money(v) || v < 0 {
			return ErrInvalidCreation
		}
	}
	if !near(b.Total, b.Subtotal+b.Tax+b.TipAmount) || len(b.Items) > 500 || len(b.Participants) > 100 || len(b.PersonShares) > 100 || len(b.PaymentMethods) > 10 {
		return ErrInvalidCreation
	}
	names := map[string]string{}
	participants := map[string]bool{}
	register := func(name string) (string, error) {
		value, e := cleanName(name, 30)
		if e != nil {
			return "", e
		}
		key := nameKey(value)
		if canonical, ok := names[key]; ok {
			return canonical, nil
		}
		names[key] = value
		if len(names) > 100 {
			return "", ErrInvalidCreation
		}
		return value, nil
	}
	for i := range b.Participants {
		p := &b.Participants[i]
		p.Name, err = register(p.Name)
		if err != nil {
			return err
		}
		key := nameKey(p.Name)
		if participants[key] {
			return ErrInvalidCreation
		}
		participants[key] = true
	}
	var itemSum, absoluteSum float64
	assignments := 0
	for i := range b.Items {
		item := &b.Items[i]
		item.Name, err = cleanName(item.Name, 255)
		if err != nil {
			return err
		}
		if !money(item.Price) || len(item.Assignments) > 100 {
			return ErrInvalidCreation
		}
		itemSum += item.Price
		absoluteSum += math.Abs(item.Price)
		if !money(absoluteSum) {
			return ErrInvalidCreation
		}
		var percentage float64
		seen := map[string]bool{}
		for j := range item.Assignments {
			a := &item.Assignments[j]
			assignments++
			if assignments > 5000 || !finite(a.Percentage) || a.Percentage <= 0 || a.Percentage > 100 {
				return ErrInvalidCreation
			}
			a.PersonName, err = register(a.PersonName)
			if err != nil {
				return err
			}
			key := nameKey(a.PersonName)
			if seen[key] {
				return ErrInvalidCreation
			}
			seen[key] = true
			percentage += a.Percentage
		}
		if !models.ItemAssignmentTotalIsValid(percentage) {
			return ErrInvalidCreation
		}
	}
	if len(b.Items) > 0 && !near(itemSum, b.Subtotal) {
		return ErrInvalidCreation
	}
	for i := range b.PaymentMethods {
		p := &b.PaymentMethods[i]
		p.Name, err = cleanName(p.Name, 50)
		if err != nil {
			return err
		}
		p.Identifier = security.SanitizeString(p.Identifier)
		if !utf8.ValidString(p.Identifier) || utf8.RuneCountInString(p.Identifier) > 256 {
			return ErrInvalidCreation
		}
	}
	projections := map[string]models.PersonShare{}
	for _, s := range b.PersonShares {
		s.PersonName, err = register(s.PersonName)
		if err != nil {
			return err
		}
		key := nameKey(s.PersonName)
		if _, ok := projections[key]; ok {
			return ErrInvalidCreation
		}
		for _, v := range []float64{s.Subtotal, s.TaxShare, s.TipShare, s.Total} {
			if !money(v) || v < 0 {
				return ErrInvalidCreation
			}
		}
		if len(s.Items) > 500 {
			return ErrInvalidCreation
		}
		for i := range s.Items {
			s.Items[i].Name, err = cleanName(s.Items[i].Name, 255)
			if err != nil || !money(s.Items[i].Amount) {
				return ErrInvalidCreation
			}
		}
		projections[key] = s
	}
	// Old saved history can have no item history, or item history without assignments.
	// Its builder emits zero detail components with an equal-split total.
	if assignments == 0 && len(projections) > 0 {
		if b.LazyMode {
			return ErrInvalidCreation
		}
		var sum float64
		rawTotals := map[string]float64{}
		for key, s := range projections {
			if len(s.Items) != 0 || !near(s.Subtotal, 0) || !near(s.TaxShare, 0) || !near(s.TipShare, 0) {
				return ErrInvalidCreation
			}
			rawTotals[key] = s.Total
			sum += s.Total
		}
		if !money(sum) || !near(sum, b.Total) {
			return ErrInvalidCreation
		}
		subRaw, taxRaw, tipRaw := map[string]float64{}, map[string]float64{}, map[string]float64{}
		for key, s := range projections {
			ratio := 0.0
			if sum > 0 {
				ratio = s.Total / sum
			}
			subRaw[key] = b.Subtotal * ratio
			taxRaw[key] = b.Tax * ratio
			tipRaw[key] = b.TipAmount * ratio
			for _, value := range []float64{ratio, subRaw[key], taxRaw[key], tipRaw[key]} {
				if !finite(value) {
					return ErrInvalidCreation
				}
			}
		}
		totals, err := allocateRoundedCents(rawTotals, nil)
		if err != nil {
			return err
		}
		subs, err := allocateRoundedCents(subRaw, nil)
		if err != nil {
			return err
		}
		taxes, err := allocateRoundedCents(taxRaw, nil)
		if err != nil {
			return err
		}
		tips, err := allocateRoundedCents(tipRaw, nil)
		if err != nil {
			return err
		}
		b.PersonShares = []models.PersonShare{}
		for _, key := range sortedCreationKeys(names) {
			if _, ok := projections[key]; ok {
				b.PersonShares = append(b.PersonShares, models.PersonShare{PersonName: names[key], Items: []models.ItemDetail{}, Subtotal: subs[key], TaxShare: taxes[key], TipShare: tips[key], Total: totals[key]})
			}
		}
		return nil
	}
	calculation, err := calculatePersonShares(b, b.LazyMode)
	if err != nil {
		return err
	}
	assigned := calculation.subtotal
	// Absolute receipt tolerances must never enlarge a proportional denominator.
	// Retain only relative floating-point noise at this boundary, including near zero.
	if assigned > b.Subtotal+b.Subtotal*1e-9 || calculation.total > b.Total+moneyTolerance {
		return ErrInvalidCreation
	}
	raw, details := calculation.subtotals, calculation.details
	// The upload projection uses the receipt denominator even when saved-history
	// totals use the assigned subtotal. Allow raw fractions and cent-rounded totals.
	denominator := b.Total - b.Tax - b.TipAmount
	totalBase := assigned
	if b.LazyMode {
		totalBase = b.Subtotal
	}
	for key, s := range projections {
		ratio := 0.0
		if denominator > 0 {
			ratio = raw[key] / denominator
		}
		totalRatio := 0.0
		if totalBase > 0 {
			totalRatio = raw[key] / totalBase
		}
		expected := raw[key] + (b.Tax+b.TipAmount)*totalRatio
		if !near(s.Subtotal, raw[key]) || !near(s.TaxShare, b.Tax*ratio) || !near(s.TipShare, b.TipAmount*ratio) || !near(s.Total, expected) {
			return ErrInvalidCreation
		}
		if len(s.Items) != len(details[key]) {
			return ErrInvalidCreation
		}
		for i, d := range s.Items {
			expected := details[key][i]
			if d.Name != expected.Name || d.IsShared != expected.IsShared || !near(d.Amount, expected.Amount) {
				return ErrInvalidCreation
			}
		}
	}
	// Reuse the existing cent allocation contract. Zero-share participants are
	// included explicitly; repeated receipt lines remain distinct by position.
	shares, err := calculation.rounded(0)
	if err != nil {
		return err
	}
	var obligations float64
	for _, share := range shares {
		obligations += share.Total
	}
	if !money(obligations) || obligations > b.Total+moneyTolerance {
		return ErrInvalidCreation
	}
	byName := map[string]models.PersonShare{}
	for _, s := range shares {
		byName[nameKey(s.PersonName)] = s
	}
	b.PersonShares = []models.PersonShare{}
	for _, key := range sortedCreationKeys(names) {
		s, ok := byName[key]
		if !ok {
			s = models.PersonShare{PersonName: names[key]}
		}
		if !money(s.Total) || s.Total < 0 {
			return ErrInvalidCreation
		}
		s.Items = details[key]
		if s.Items == nil {
			s.Items = []models.ItemDetail{}
		}
		b.PersonShares = append(b.PersonShares, s)
	}
	return nil
}

func sortedCreationKeys(names map[string]string) []string {
	keys := make([]string, 0, len(names))
	for key := range names {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}
