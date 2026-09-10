package currency

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestGetRateSameCurrency(t *testing.T) {
	s := &Service{cache: make(map[string]Rate)}
	rate, err := s.GetRate("usd", "USD")
	if err != nil || rate.Value != 1 || rate.From != "USD" || rate.To != "USD" {
		t.Fatalf("unexpected same-currency rate: %+v, %v", rate, err)
	}
}

func TestGetRateUsesFreshCache(t *testing.T) {
	s := &Service{cache: map[string]Rate{"PEN:USD": {
		From: "PEN", To: "USD", Value: 0.27, Source: "test", UpdatedAt: time.Now(),
	}}}
	rate, err := s.GetRate("PEN", "USD")
	if err != nil || rate.Value != 0.27 {
		t.Fatalf("expected cached rate, got %+v, %v", rate, err)
	}
}

func TestGetRateProviderResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"result":"success","conversion_rate":0.27}`))
	}))
	defer server.Close()

	s := &Service{apiKey: "test", httpClient: server.Client(), baseURL: server.URL, cache: make(map[string]Rate)}
	rate, err := s.GetRate("PEN", "USD")
	if err != nil || rate.Value != 0.27 || rate.Source != "exchangerate-api" {
		t.Fatalf("unexpected provider rate: %+v, %v", rate, err)
	}
}
