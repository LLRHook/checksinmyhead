package currency

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

var ErrUnavailable = errors.New("exchange rate provider unavailable")

type Rate struct {
	From      string    `json:"from"`
	To        string    `json:"to"`
	Value     float64   `json:"rate"`
	Source    string    `json:"source"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Service struct {
	apiKey     string
	httpClient *http.Client
	baseURL    string
	mu         sync.Mutex
	cache      map[string]Rate
}

func NewService() *Service {
	return &Service{
		apiKey:     strings.TrimSpace(os.Getenv("EXCHANGE_RATE_API_KEY")),
		httpClient: &http.Client{Timeout: 8 * time.Second},
		baseURL:    "https://v6.exchangerate-api.com/v6",
		cache:      make(map[string]Rate),
	}
}

func (s *Service) GetRate(from, to string) (Rate, error) {
	from = strings.ToUpper(strings.TrimSpace(from))
	to = strings.ToUpper(strings.TrimSpace(to))
	if len(from) != 3 || len(to) != 3 {
		return Rate{}, fmt.Errorf("currency codes must be ISO 4217 codes")
	}
	if from == to {
		return Rate{From: from, To: to, Value: 1, Source: "same_currency", UpdatedAt: time.Now().UTC()}, nil
	}

	key := from + ":" + to
	s.mu.Lock()
	if cached, ok := s.cache[key]; ok && time.Since(cached.UpdatedAt) < 24*time.Hour {
		s.mu.Unlock()
		return cached, nil
	}
	s.mu.Unlock()

	if s.apiKey == "" {
		return Rate{}, ErrUnavailable
	}
	requestURL := fmt.Sprintf("%s/%s/pair/%s/%s", s.baseURL, s.apiKey, from, to)
	resp, err := s.httpClient.Get(requestURL)
	if err != nil {
		return Rate{}, fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return Rate{}, fmt.Errorf("%w: provider returned %d", ErrUnavailable, resp.StatusCode)
	}

	var payload struct {
		Result         string  `json:"result"`
		ConversionRate float64 `json:"conversion_rate"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil || payload.Result != "success" || payload.ConversionRate <= 0 {
		return Rate{}, ErrUnavailable
	}

	rate := Rate{From: from, To: to, Value: payload.ConversionRate, Source: "exchangerate-api", UpdatedAt: time.Now().UTC()}
	s.mu.Lock()
	s.cache[key] = rate
	s.mu.Unlock()
	return rate, nil
}
