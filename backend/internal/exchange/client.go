package exchange

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const defaultBaseURL = "https://api.frankfurter.dev/v2"
const maxResponseBytes = 64 << 10

// Client reads Frankfurter v2 daily blended pairs without an application cache.
// Its HTTP transport retains normal connection pooling.
type Client struct {
	baseURL string
	http    *http.Client
	now     func() time.Time
}

func NewClient(baseURL string) *Client {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = defaultBaseURL
	}
	return &Client{baseURL: strings.TrimRight(baseURL, "/"), now: time.Now, http: &http.Client{
		Timeout:       currency.OperationTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}
}

func (c *Client) Latest(ctx context.Context, base, quote string) (models.ExchangeRateQuote, error) {
	base, quote = currency.Normalize(base), currency.Normalize(quote)
	if !currency.ValidCode(base) || !currency.ValidCode(quote) {
		return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
	}
	ctx, cancel := context.WithTimeout(ctx, currency.OperationTimeout)
	defer cancel()
	if err := ctx.Err(); err != nil {
		return models.ExchangeRateQuote{}, &currency.UnavailableError{Cause: err}
	}
	if base == quote {
		return models.ExchangeRateQuote{Base: base, Quote: quote, Rate: 1, Source: "same_currency"}, nil
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/rate/"+base+"/"+quote, nil)
	if err != nil {
		return models.ExchangeRateQuote{}, &currency.UnavailableError{}
	}
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return models.ExchangeRateQuote{}, &currency.UnavailableError{Cause: ctx.Err()}
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		failure := &currency.UnavailableError{}
		if resp.StatusCode == 429 || resp.StatusCode == 503 {
			failure.RetryAfter = retryAfter(resp.Header.Get("Retry-After"))
		}
		return models.ExchangeRateQuote{}, failure
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return models.ExchangeRateQuote{}, &currency.UnavailableError{Cause: ctx.Err()}
	}
	if len(data) > maxResponseBytes {
		return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
	}
	// The pair route returns exactly one object, never the /rates array. Decode
	// only documented wire fields; provenance comes from this selected adapter.
	var wire struct {
		Date  string  `json:"date"`
		Base  string  `json:"base"`
		Quote string  `json:"quote"`
		Rate  float64 `json:"rate"`
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	token, err := decoder.Token()
	if err != nil || token != json.Delim('{') {
		return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
	}
	seen := make(map[string]bool, 4)
	for decoder.More() {
		token, err := decoder.Token()
		if err != nil {
			return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
		}
		key, ok := token.(string)
		if !ok || seen[key] {
			return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
		}
		seen[key] = true
		switch key {
		case "date":
			err = decoder.Decode(&wire.Date)
		case "base":
			err = decoder.Decode(&wire.Base)
		case "quote":
			err = decoder.Decode(&wire.Quote)
		case "rate":
			err = decoder.Decode(&wire.Rate)
		default:
			return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
		}
		if err != nil {
			return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
		}
	}
	if token, err := decoder.Token(); err != nil || token != json.Delim('}') || len(seen) != 4 {
		return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return models.ExchangeRateQuote{}, currency.ErrInvalidQuote
	}
	result := models.ExchangeRateQuote{Date: wire.Date, Base: wire.Base, Quote: wire.Quote, Rate: wire.Rate, Source: "frankfurter-v2-blended"}
	if err := currency.ValidateQuote(result, base, quote, c.now()); err != nil {
		return models.ExchangeRateQuote{}, err
	}
	return result, nil
}

func retryAfter(value string) string {
	if len(value) > 128 {
		return ""
	}
	value = strings.TrimSpace(value)
	if seconds, err := strconv.ParseUint(value, 10, 32); err == nil {
		return strconv.FormatUint(seconds, 10)
	}
	if date, err := http.ParseTime(value); err == nil {
		return date.UTC().Format(http.TimeFormat)
	}
	return ""
}
