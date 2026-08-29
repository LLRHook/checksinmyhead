package exchange

import (
	"backend/pkg/models"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const defaultBaseURL = "https://api.frankfurter.dev/v2"

type cachedQuote struct {
	quote     models.ExchangeRateQuote
	expiresAt time.Time
}

// Client reads daily reference rates from Frankfurter v2. It deliberately
// exposes only the one operation the product needs.
type Client struct {
	baseURL string
	http    *http.Client
	now     func() time.Time
	mu      sync.Mutex
	cache   map[string]cachedQuote
}

func NewClient(baseURL string) *Client {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = defaultBaseURL
	}
	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		http:    &http.Client{Timeout: 4 * time.Second},
		now:     time.Now,
		cache:   make(map[string]cachedQuote),
	}
}

func (c *Client) LatestUSD(ctx context.Context, currency string) (models.ExchangeRateQuote, error) {
	currency = strings.ToUpper(strings.TrimSpace(currency))
	now := c.now().UTC()

	c.mu.Lock()
	if hit, ok := c.cache[currency]; ok && now.Before(hit.expiresAt) {
		c.mu.Unlock()
		return hit.quote, nil
	}
	c.mu.Unlock()

	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		quote, retry, err := c.fetch(ctx, currency)
		if err == nil {
			nextMidnight := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
			c.mu.Lock()
			c.cache[currency] = cachedQuote{quote: quote, expiresAt: nextMidnight}
			c.mu.Unlock()
			return quote, nil
		}
		lastErr = err
		if !retry || attempt == 1 {
			break
		}
		select {
		case <-ctx.Done():
			return models.ExchangeRateQuote{}, ctx.Err()
		case <-time.After(100 * time.Millisecond):
		}
	}
	return models.ExchangeRateQuote{}, lastErr
}

func (c *Client) fetch(ctx context.Context, currency string) (models.ExchangeRateQuote, bool, error) {
	endpoint := fmt.Sprintf("%s/rate/%s/USD", c.baseURL, url.PathEscape(currency))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return models.ExchangeRateQuote{}, false, err
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return models.ExchangeRateQuote{}, true, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		retry := resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500
		return models.ExchangeRateQuote{}, retry, fmt.Errorf("exchange provider returned HTTP %d", resp.StatusCode)
	}

	var quote models.ExchangeRateQuote
	decoder := json.NewDecoder(io.LimitReader(resp.Body, 64<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&quote); err != nil {
		return models.ExchangeRateQuote{}, false, err
	}
	if quote.Base != currency || quote.Quote != "USD" || quote.Date == "" || quote.Rate <= 0 || math.IsNaN(quote.Rate) || math.IsInf(quote.Rate, 0) {
		return models.ExchangeRateQuote{}, false, errors.New("exchange provider returned an invalid quote")
	}
	if _, err := time.Parse("2006-01-02", quote.Date); err != nil {
		return models.ExchangeRateQuote{}, false, errors.New("exchange provider returned an invalid rate date")
	}
	quote.Source = "frankfurter-v2-blended"
	return quote, false, nil
}
