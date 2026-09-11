package exchange

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestLatestUSD_CachesVerifiedDailyQuote(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"date":"2026-08-29","base":"EUR","quote":"USD","rate":1.1652}`)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.now = func() time.Time { return time.Date(2026, 8, 29, 12, 0, 0, 0, time.UTC) }
	first, err := client.LatestUSD(context.Background(), "EUR")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	second, err := client.LatestUSD(context.Background(), "EUR")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if calls.Load() != 1 || first != second || first.Source != "frankfurter-v2-blended" {
		t.Fatalf("expected one cached verified quote, calls=%d first=%+v second=%+v", calls.Load(), first, second)
	}
}

func TestLatestUSD_RetriesTransientFailureOnly(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if calls.Add(1) == 1 {
			http.Error(w, "temporary", http.StatusServiceUnavailable)
			return
		}
		fmt.Fprint(w, `{"date":"2026-08-29","base":"CAD","quote":"USD","rate":0.73}`)
	}))
	defer server.Close()

	quote, err := NewClient(server.URL).LatestUSD(context.Background(), "CAD")
	if err != nil || quote.Rate != 0.73 || calls.Load() != 2 {
		t.Fatalf("expected one retry and a valid quote, calls=%d quote=%+v err=%v", calls.Load(), quote, err)
	}
}

func TestLatestUSD_RejectsMismatchedOrMalformedQuote(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"date":"not-a-date","base":"GBP","quote":"EUR","rate":1.2}`)
	}))
	defer server.Close()

	if _, err := NewClient(server.URL).LatestUSD(context.Background(), "GBP"); err == nil {
		t.Fatal("expected malformed provider quote to be rejected")
	}
}
