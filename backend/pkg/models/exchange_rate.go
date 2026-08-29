package models

// ExchangeRateQuote is the daily conversion captured for a Bill. Rate is the
// number of quote-currency units for one base-currency unit.
type ExchangeRateQuote struct {
	Date   string  `json:"date"`
	Base   string  `json:"base"`
	Quote  string  `json:"quote"`
	Rate   float64 `json:"rate"`
	Source string  `json:"source"`
}
