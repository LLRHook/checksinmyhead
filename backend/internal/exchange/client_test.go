package exchange

import (
	"backend/internal/currency"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

var quoteNow = time.Date(2026, 11, 3, 23, 59, 0, 0, time.FixedZone("west", -5*3600)) // UTC Nov 4
func testClient(t *testing.T, handler http.HandlerFunc) *Client {
	t.Helper()
	s := httptest.NewServer(handler)
	t.Cleanup(s.Close)
	c := NewClient(s.URL)
	c.now = func() time.Time { return quoteNow }
	return c
}
func TestLatestValidatesExactPairDayRate(t *testing.T) {
	for _, date := range []string{"2026-11-04", "2026-11-03", "2026-10-28", "2026-11-05"} {
		t.Run(date, func(t *testing.T) {
			var calls atomic.Int32
			c := testClient(t, func(w http.ResponseWriter, r *http.Request) {
				calls.Add(1)
				if r.URL.Path != "/rate/PEN/USD" || r.URL.RawQuery != "" || r.Header.Get("Accept") != "application/json" {
					t.Errorf("unexpected request %s", r.URL)
				}
				fmt.Fprintf(w, `{"date":%q,"base":"PEN","quote":"USD","rate":0.27391825}`, date)
			})
			for i := 0; i < 2; i++ {
				q, err := c.Latest(context.Background(), " pen ", "usd")
				if err != nil || q.Base != "PEN" || q.Quote != "USD" || q.Date != date || q.Rate != .27391825 || q.Source != "frankfurter-v2-blended" {
					t.Fatalf("quote=%+v err=%v", q, err)
				}
			}
			if calls.Load() != 2 {
				t.Fatalf("application cache or retry calls=%d", calls.Load())
			}
		})
	}
}
func TestLatestRejectsUntrustedResponses(t *testing.T) {
	valid := `{"date":"2026-11-04","base":"EUR","quote":"USD","rate":1.25}`
	cases := map[string]string{
		"wrong_base": strings.Replace(valid, `"EUR"`, `"GBP"`, 1), "wrong_quote": strings.Replace(valid, `"USD"`, `"EUR"`, 1),
		"lowercase_pair": strings.Replace(valid, `"EUR"`, `"eur"`, 1), "missing_date": strings.Replace(valid, `"2026-11-04"`, `""`, 1),
		"bad_day": strings.Replace(valid, "2026-11-04", "2026-02-30", 1), "unpadded_day": strings.Replace(valid, "2026-11-04", "2026-11-4", 1),
		"timestamp": strings.Replace(valid, "2026-11-04", "2026-11-04T00:00:00Z", 1), "too_old": strings.Replace(valid, "2026-11-04", "2026-10-27", 1),
		"too_future": strings.Replace(valid, "2026-11-04", "2026-11-06", 1), "zero": strings.Replace(valid, "1.25", "0", 1),
		"negative": strings.Replace(valid, "1.25", "-1", 1), "nan": strings.Replace(valid, "1.25", "NaN", 1), "inf": strings.Replace(valid, "1.25", "1e999", 1),
		"string_rate": strings.Replace(valid, "1.25", `"1.25"`, 1), "null_rate": strings.Replace(valid, "1.25", "null", 1), "missing_rate": `{"date":"2026-11-04","base":"EUR","quote":"USD"}`,
		"null": "null", "empty": "", "array": "[" + valid + "]", "multiple": valid + valid, "trailing": valid + " broken",
		"source_spoof":   strings.TrimSuffix(valid, "}") + `,"source":"invented"}`,
		"duplicate_rate": strings.TrimSuffix(valid, "}") + `,"rate":2}`,
		"duplicate_pair": strings.TrimSuffix(valid, "}") + `,"base":"EUR"}`,
		"field_case":     strings.Replace(valid, `"base"`, `"BASE"`, 1), "oversized": valid + strings.Repeat(" ", maxResponseBytes),
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			var calls atomic.Int32
			c := testClient(t, func(w http.ResponseWriter, r *http.Request) { calls.Add(1); fmt.Fprint(w, body) })
			if q, err := c.Latest(context.Background(), "EUR", "USD"); err == nil || q.Rate != 0 {
				t.Fatalf("accepted %+v err=%v", q, err)
			}
			if calls.Load() != 1 {
				t.Fatalf("calls=%d", calls.Load())
			}
		})
	}
}
func TestLatestIdentityAndInvalidCodesDoNotCallUpstream(t *testing.T) {
	c := testClient(t, func(http.ResponseWriter, *http.Request) { t.Error("unexpected upstream call") })
	q, err := c.Latest(context.Background(), "USD", "usd")
	if err != nil || q.Rate != 1 || q.Date != "" {
		t.Fatalf("identity %+v %v", q, err)
	}
	for _, code := range []string{"", "EU", "EURO", "EU1", "../USD", "ÄBC"} {
		if _, err := c.Latest(context.Background(), code, "USD"); err == nil {
			t.Fatalf("accepted %q", code)
		}
	}
}
func TestLatestStatusRetryAfterNoRetries(t *testing.T) {
	for _, status := range []int{302, 400, 404, 422, 429, 500, 503} {
		for _, after := range []string{"120", "Wed, 04 Nov 2026 12:00:00 GMT", "not-a-date", "999999999999999999999999", "-1", strings.Repeat("x", 200)} {
			t.Run(fmt.Sprintf("%d_%s", status, after[:min(len(after), 12)]), func(t *testing.T) {
				var calls atomic.Int32
				c := testClient(t, func(w http.ResponseWriter, r *http.Request) {
					calls.Add(1)
					w.Header().Set("Retry-After", after)
					w.Header().Set("Location", "/redirect")
					w.WriteHeader(status)
					fmt.Fprint(w, strings.Repeat("synthetic-private-error", 10000))
				})
				_, err := c.Latest(context.Background(), "EUR", "USD")
				var failure *currency.UnavailableError
				if !errors.As(err, &failure) || len(err.Error()) > 100 || strings.Contains(err.Error(), "private") || calls.Load() != 1 {
					t.Fatalf("unsafe failure %v calls=%d", err, calls.Load())
				}
				want := ""
				if (status == 429 || status == 503) && (after == "120" || strings.HasPrefix(after, "Wed,")) {
					want = after
				}
				if failure.RetryAfter != want {
					t.Fatalf("Retry-After=%q want=%q", failure.RetryAfter, want)
				}
			})
		}
	}
}
func TestLatestCancellationAndDeadline(t *testing.T) {
	t.Run("already_cancelled", func(t *testing.T) {
		c := testClient(t, func(http.ResponseWriter, *http.Request) { t.Error("called after cancellation") })
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		_, err := c.Latest(ctx, "EUR", "USD")
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("lost cancellation %v", err)
		}
	})
	for _, headers := range []bool{false, true} {
		t.Run(fmt.Sprint("slow_body_", headers), func(t *testing.T) {
			var calls atomic.Int32
			cancelled := make(chan struct{})
			c := testClient(t, func(w http.ResponseWriter, r *http.Request) {
				calls.Add(1)
				if headers {
					fmt.Fprint(w, `{"date":`)
					w.(http.Flusher).Flush()
				}
				<-r.Context().Done()
				close(cancelled)
			})
			ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
			defer cancel()
			started := time.Now()
			_, err := c.Latest(ctx, "EUR", "USD")
			if !errors.Is(err, context.DeadlineExceeded) || time.Since(started) > time.Second || calls.Load() != 1 {
				t.Fatalf("deadline err=%v calls=%d elapsed=%s", err, calls.Load(), time.Since(started))
			}
			select {
			case <-cancelled:
			case <-time.After(time.Second):
				t.Fatal("upstream did not see cancellation")
			}
		})
	}
	t.Run("default_budget", func(t *testing.T) {
		c := NewClient("http://synthetic.invalid")
		c.http.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
			deadline, ok := r.Context().Deadline()
			if !ok || time.Until(deadline) > 5*time.Second {
				t.Fatal("missing 5s bound")
			}
			return nil, io.ErrUnexpectedEOF
		})
		_, err := c.Latest(context.Background(), "EUR", "USD")
		if err == nil || len(err.Error()) > 100 {
			t.Fatalf("transport err=%v", err)
		}
	})
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
