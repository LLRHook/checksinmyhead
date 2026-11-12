package receipt

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/netip"
	"sync/atomic"
	"testing"
)

// One client request makes at most one provider request. A provider failure
// comes back as a finite, recoverable response; a later scan is a new request
// the user chose to make, charged to the same peer quota. Peer-quota denials
// never reach the provider.
func TestHandlerFailuresMakeOneProviderAttempt(t *testing.T) {
	body, contentType := multipartImage(t, false)
	for _, tc := range []struct {
		name               string
		status             int
		retryAfter, answer string
		wantStatus         int
		wantCode           ParseErrorCode
		wantRetry          string
	}{
		{"provider_quota", 429, "7", `{"error":{"type":"rate_limit_error","message":"synthetic-private"}}`, 429, ErrRateLimited, "7"},
		{"provider_overloaded", 529, "3", "", 503, ErrOverloaded, "3"},
		{"provider_error", 500, "", "", 503, ErrProviderDown, "60"},
		{"provider_credit_or_key", 401, "9", "", 503, ErrAuthFailed, ""},
		{"provider_rejects_request", 400, "", "", 422, ErrInvalidRequest, ""},
		{"unusable_success", 200, "", `{"content":[]}`, 422, ErrBadResponse, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var posts atomic.Int32
			s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
				posts.Add(1)
				_, _ = io.Copy(io.Discard, r.Body)
				if tc.retryAfter != "" {
					w.Header().Set("Retry-After", tc.retryAfter)
				}
				w.WriteHeader(tc.status)
				_, _ = io.WriteString(w, tc.answer)
			})
			h, router := receiptRouter(t, s)
			for attempt := int32(1); attempt <= 2; attempt++ {
				out := uploadRequest(router, body, contentType, "192.0.2.7:44", context.Background())
				var public struct{ Error, Code string }
				if err := json.Unmarshal(out.Body.Bytes(), &public); err != nil || out.Code != tc.wantStatus || public.Code != string(tc.wantCode) || public.Error == "" ||
					out.Header().Get("Retry-After") != tc.wantRetry || len(out.Body.Bytes()) > 256 {
					t.Fatalf("status=%d retry=%q body=%s", out.Code, out.Header().Get("Retry-After"), out.Body)
				}
				if posts.Load() != attempt {
					t.Fatalf("client request %d made provider requests=%d", attempt, posts.Load())
				}
			}
			h.admission.mu.Lock()
			charged, inflight := h.admission.peers[netip.MustParseAddr("192.0.2.7")].n, h.admission.inflight
			h.admission.mu.Unlock()
			if charged != 2 || inflight != 0 {
				t.Fatalf("charged=%d inflight=%d", charged, inflight)
			}
		})
	}
	t.Run("peer_quota", func(t *testing.T) {
		var posts atomic.Int32
		s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			posts.Add(1)
			_, _ = io.Copy(io.Discard, r.Body)
			w.WriteHeader(500)
		})
		_, router := receiptRouter(t, s)
		for range 10 {
			if out := uploadRequest(router, body, contentType, "192.0.2.8:44", context.Background()); out.Code != 503 {
				t.Fatalf("admitted status=%d", out.Code)
			}
		}
		for range 5 {
			out := uploadRequest(router, body, contentType, "192.0.2.8:44", context.Background())
			var public struct{ Code string }
			if json.Unmarshal(out.Body.Bytes(), &public) != nil || out.Code != 429 || public.Code != string(ErrRateLimited) || out.Header().Get("Retry-After") == "" {
				t.Fatalf("status=%d retry=%q body=%s", out.Code, out.Header().Get("Retry-After"), out.Body)
			}
		}
		if posts.Load() != 10 {
			t.Fatalf("provider requests=%d for 10 admitted and 5 denied scans", posts.Load())
		}
		if out := uploadRequest(router, body, contentType, "192.0.2.9:44", context.Background()); out.Code != 503 || posts.Load() != 11 {
			t.Fatalf("another peer status=%d provider requests=%d", out.Code, posts.Load())
		}
	})
}
