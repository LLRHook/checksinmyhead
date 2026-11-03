package currency

import (
	"backend/pkg/models"
	"context"
	"errors"
	"math"
	"strings"
	"time"
)

const OperationTimeout = 5 * time.Second

// Provider returns an exact, validated current pair. Implementations must propagate
// cancellation and make no retries. Historical persisted quotes never enter it.
type Provider interface {
	Latest(context.Context, string, string) (models.ExchangeRateQuote, error)
}

func Normalize(code string) string { return strings.ToUpper(strings.TrimSpace(code)) }
func ValidCode(code string) bool {
	if len(code) != 3 {
		return false
	}
	for _, c := range code {
		if c < 'A' || c > 'Z' {
			return false
		}
	}
	return true
}

// ReceiptSupported is the product policy, independent of provider-defined display
// pairs. The mobile selectors are checked against this policy by contract fixtures.
func ReceiptSupported(code string) bool {
	switch code {
	case "USD", "EUR", "GBP", "CAD", "JPY", "MXN", "PEN", "AUD", "BRL", "CNY", "INR", "CHF":
		return true
	}
	return false
}

var ErrInvalidQuote = errors.New("invalid exchange rate quote")

// ValidateQuote applies only to new foreign quotes. Date comparisons are UTC
// calendar days, including weekend/holiday lag and next-day publisher allowance.
func ValidateQuote(q models.ExchangeRateQuote, base, quote string, now time.Time) error {
	if q.Base != base || q.Quote != quote || strings.TrimSpace(q.Source) == "" || q.Rate <= 0 || math.IsNaN(q.Rate) || math.IsInf(q.Rate, 0) {
		return ErrInvalidQuote
	}
	day, err := time.Parse(time.DateOnly, q.Date)
	if err != nil || day.Format(time.DateOnly) != q.Date {
		return ErrInvalidQuote
	}
	now = now.UTC()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	if day.Before(today.AddDate(0, 0, -7)) || day.After(today.AddDate(0, 0, 1)) {
		return ErrInvalidQuote
	}
	return nil
}
