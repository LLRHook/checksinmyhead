package receipt

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// Production constructor, endpoint, redirect policy, pooling and TLS verification.
// Only the socket target and local CA differ. No inherited provider key is read.
func tlsService(t *testing.T, handler http.HandlerFunc) (*Service, *httptest.Server) {
	t.Helper()
	server := httptest.NewTLSServer(handler)
	t.Cleanup(server.Close)
	t.Setenv("ANTHROPIC_API_KEY", "synthetic-local-fixture")
	t.Setenv("OCR_MAX_INFLIGHT", "")
	s, err := NewService()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Close)
	roots := x509.NewCertPool()
	roots.AddCert(server.Certificate())
	s.transport.TLSClientConfig = &tls.Config{RootCAs: roots, ServerName: "example.com", MinVersion: tls.VersionTLS12}
	s.transport.DialContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
	}
	return s, server
}

func requireCode(t *testing.T, err error, want ParseErrorCode) {
	t.Helper()
	var p *ParseError
	if !errors.As(err, &p) || p.Code != want || len(err.Error()) > 80 || errors.Unwrap(err) != nil {
		t.Fatalf("finite code wanted %s got %v", want, err)
	}
}

func TestProviderWirePolicy(t *testing.T) {
	for _, status := range []int{301, 302, 303, 307, 308, 400, 401, 403, 413, 429, 500, 529} {
		t.Run(fmt.Sprint(status), func(t *testing.T) {
			var posts atomic.Int32
			finished := make(chan struct{}, 1)
			s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
				posts.Add(1)
				defer func() { finished <- struct{}{} }()
				if r.Method != "POST" || r.ProtoMajor != 1 || r.Host != "api.anthropic.com" || r.Header.Get("x-api-key") != "synthetic-local-fixture" {
					t.Error("fixed wire contract")
				}
				if r.Header.Get("Idempotency-Key") != "" || r.Header.Get("Authorization") != "" {
					t.Error("forwarded header")
				}
				_, _ = io.Copy(io.Discard, r.Body)
				w.Header().Set("Location", "https://synthetic-private-location.invalid/key")
				w.Header().Set("Retry-After", "120")
				w.WriteHeader(status)
				w.(http.Flusher).Flush()
				<-r.Context().Done()
			})
			ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
			defer cancel()
			start := time.Now()
			_, err := s.Parse(ctx, []byte("fixture"), "image/jpeg")
			code := ErrProviderDown
			switch status {
			case 400:
				code = ErrInvalidRequest
			case 401, 403:
				code = ErrAuthFailed
			case 413:
				code = ErrImageTooLarge
			case 429:
				code = ErrRateLimited
			case 529:
				code = ErrOverloaded
			}
			requireCode(t, err, code)
			if time.Since(start) > 250*time.Millisecond || posts.Load() != 1 {
				t.Fatal("followed redirect or drained stalled error body")
			}
			select {
			case <-finished:
			case <-time.After(time.Second):
				t.Fatal("response body not closed")
			}
		})
	}
	t.Run("success_reuses_bounded_transport", func(t *testing.T) {
		var posts, connections atomic.Int32
		s, server := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			posts.Add(1)
			_, _ = io.Copy(io.Discard, r.Body)
			_, _ = io.WriteString(w, envelope(validReceipt))
		})
		// Count socket connections independently of requests.
		dial := s.transport.DialContext
		s.transport.DialContext = func(ctx context.Context, n, a string) (net.Conn, error) { connections.Add(1); return dial(ctx, n, a) }
		for i := 0; i < 2; i++ {
			r, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
			if err != nil || len(r.Items) != 2 {
				t.Fatal(err)
			}
		}
		_ = server
		if posts.Load() != 2 || connections.Load() != 1 || s.transport.MaxConnsPerHost != 2 || s.transport.Protocols.HTTP2() || !s.transport.Protocols.HTTP1() || s.transport.TLSClientConfig.InsecureSkipVerify {
			t.Fatal("pool/protocol contract")
		}
	})
	t.Run("stale_after_post_is_not_replayed", func(t *testing.T) {
		var posts, connections atomic.Int32
		s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			n := posts.Add(1)
			_, _ = io.Copy(io.Discard, r.Body)
			if n == 2 {
				c, _, err := w.(http.Hijacker).Hijack()
				if err == nil {
					_ = c.Close()
				}
				return
			}
			_, _ = io.WriteString(w, envelope(validReceipt))
		})
		dial := s.transport.DialContext
		s.transport.DialContext = func(ctx context.Context, n, a string) (net.Conn, error) { connections.Add(1); return dial(ctx, n, a) }
		if _, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); err != nil {
			t.Fatal(err)
		}
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrProviderDown)
		if posts.Load() != 2 || connections.Load() != 1 {
			t.Fatalf("replayed: wire=%d sockets=%d", posts.Load(), connections.Load())
		}
		// A separate manual retry is a new user operation and may succeed.
		if _, err = s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); err != nil {
			t.Fatal(err)
		}
		if posts.Load() != 3 {
			t.Fatal("manual retry")
		}
	})
	t.Run("precancel_zero_posts", func(t *testing.T) {
		var posts atomic.Int32
		s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) { posts.Add(1) })
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		_, err := s.Parse(ctx, []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrProviderDown)
		if posts.Load() != 0 {
			t.Fatal("canceled work sent")
		}
	})
	for _, late := range []bool{false, true} {
		t.Run(fmt.Sprintf("cancel_headers_%v", late), func(t *testing.T) {
			arrived := make(chan struct{})
			finished := make(chan struct{})
			s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
				defer close(finished)
				_, _ = io.Copy(io.Discard, r.Body)
				if late {
					w.WriteHeader(200)
					w.(http.Flusher).Flush()
				}
				close(arrived)
				<-r.Context().Done()
			})
			ctx, cancel := context.WithCancel(context.Background())
			done := make(chan error, 1)
			go func() { _, err := s.Parse(ctx, []byte("fixture"), "image/jpeg"); done <- err }()
			<-arrived
			start := time.Now()
			cancel()
			select {
			case err := <-done:
				requireCode(t, err, ErrProviderDown)
			case <-time.After(time.Second):
				t.Fatal("network cancel blocked")
			}
			if time.Since(start) > 250*time.Millisecond {
				t.Fatal("late cancellation")
			}
			select {
			case <-finished:
			case <-time.After(time.Second):
				t.Fatal("network request leaked")
			}
		})
	}
}

func TestProviderReadBounds(t *testing.T) {
	for _, tc := range []struct {
		name     string
		body     []byte
		encoding string
		declared int64
		want     ParseErrorCode
	}{
		{"plain_success", []byte(envelope(validReceipt)), "", 0, ""},
		{"declared_small", []byte(envelope(validReceipt)), "", 1, ErrBadResponse},
		{"truncated", []byte(`{"content":`), "", 100, ErrBadResponse},
		{"cap_plus_one", bytes.Repeat([]byte(" "), maxResponseSize+1), "", 0, ErrBadResponse},
		{"text_plus_one", []byte(envelope(strings.Repeat("x", maxTextSize+1))), "", 0, ErrBadResponse},
		{"gzip_expanded", bytes.Repeat([]byte(" "), maxResponseSize+1), "gzip", 0, ErrBadResponse},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
				_, _ = io.Copy(io.Discard, r.Body)
				if tc.declared > 0 {
					w.Header().Set("Content-Length", fmt.Sprint(tc.declared))
				}
				if tc.encoding == "gzip" {
					w.Header().Set("Content-Encoding", "gzip")
					z := gzip.NewWriter(w)
					_, _ = z.Write(tc.body)
					_ = z.Close()
				} else {
					_, _ = w.Write(tc.body)
				}
			})
			_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
			if tc.want == "" {
				if err != nil {
					t.Fatal(err)
				}
			} else {
				requireCode(t, err, tc.want)
			}
		})
	}
	t.Run("response_header_cap", func(t *testing.T) {
		s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			_, _ = io.Copy(io.Discard, r.Body)
			w.Header().Set("Synthetic", strings.Repeat("x", 40<<10))
			w.WriteHeader(429)
		})
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrProviderDown)
	})
	t.Run("cap_plus_one_actual_reads", func(t *testing.T) {
		body := &countingBody{Reader: strings.NewReader(strings.Repeat("x", maxResponseSize+10000))}
		s := fixtureService(t, "")
		s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
			if r.GetBody != nil || r.ContentLength <= 0 {
				t.Fatal("replayable request")
			}
			return &http.Response{StatusCode: 200, Header: make(http.Header), Body: body, Request: r}, nil
		})
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrBadResponse)
		if body.read != maxResponseSize+1 || !body.closed {
			t.Fatalf("read=%d closed=%v", body.read, body.closed)
		}
	})
}

type countingBody struct {
	io.Reader
	read   int
	closed bool
}

func (b *countingBody) Read(p []byte) (int, error) {
	n, e := b.Reader.Read(p)
	b.read += n
	return n, e
}
func (b *countingBody) Close() error { b.closed = true; return nil }

func TestRetryAfter(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 500000000, time.UTC)
	for _, tc := range []struct {
		input string
		want  int
	}{{"", 60}, {"bad", 60}, {"0", 1}, {"1", 1}, {"86400", 86400}, {"86401", 0}, {strings.Repeat("9", 30), 0}, {strings.Repeat("x", 129), 60}, {now.Add(10 * time.Second).Format(http.TimeFormat), 10}, {now.Add(25 * time.Hour).Format(http.TimeFormat), 0}, {now.Add(-time.Hour).Format(http.TimeFormat), 1}} {
		t.Run(fmt.Sprintf("%d_%d", len(tc.input), tc.want), func(t *testing.T) {
			if n := retryAfter(tc.input, now); n != tc.want {
				t.Fatalf("retry=%d want=%d", n, tc.want)
			}
		})
	}
}

func TestProviderRequestContract(t *testing.T) {
	s := fixtureService(t, envelope(validReceipt))
	s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		var v messagesRequest
		if err := json.NewDecoder(r.Body).Decode(&v); err != nil {
			t.Fatal(err)
		}
		if v.MaxTokens != 4096 || v.Model != anthropicModel || v.Messages[0].Content[1].Text != receiptPrompt || r.GetBody != nil {
			t.Fatal("provider contract changed")
		}
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(envelope(validReceipt))), Request: r}, nil
	})
	_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	if err != nil {
		t.Fatal(err)
	}
}

func TestProviderStalledCapAndNon200Reads(t *testing.T) {
	t.Run("streamed_cap_then_stall", func(t *testing.T) {
		done := make(chan struct{})
		s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			defer close(done)
			_, _ = io.Copy(io.Discard, r.Body)
			w.WriteHeader(200)
			_, _ = w.Write(bytes.Repeat([]byte(" "), maxResponseSize+1))
			w.(http.Flusher).Flush()
			<-r.Context().Done()
		})
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		start := time.Now()
		_, err := s.Parse(ctx, []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrBadResponse)
		if time.Since(start) > 500*time.Millisecond {
			t.Fatal("cap waited for body EOF")
		}
		select {
		case <-done:
		case <-time.After(time.Second):
			t.Fatal("oversize response not closed")
		}
	})
	t.Run("non200_zero_reads", func(t *testing.T) {
		body := &countingBody{Reader: strings.NewReader("synthetic-key-location-receipt-error")}
		s := fixtureService(t, "")
		s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
			return &http.Response{StatusCode: 429, Header: http.Header{"Retry-After": []string{"86401"}}, Body: body, Request: r}, nil
		})
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrRateLimited)
		if body.read != 0 || !body.closed || err.(*ParseError).RetryAfter != 0 {
			t.Fatal("error content read or long retry shortened")
		}
	})
	t.Run("transport_taint_finite", func(t *testing.T) {
		s := fixtureService(t, "")
		s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
			return nil, fmt.Errorf("synthetic-key-receipt-private-url")
		})
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrProviderDown)
		if strings.Contains(err.Error(), "synthetic") {
			t.Fatal("raw cause escaped")
		}
	})
	t.Run("success_error_object_finite", func(t *testing.T) {
		s := fixtureService(t, `{"error":{"type":"synthetic-private-type","message":"synthetic-private-key"}}`)
		_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, err, ErrBadResponse)
	})
	t.Run("base64_exact_and_deadline", func(t *testing.T) {
		s := fixtureService(t, "")
		s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
			var req messagesRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				t.Fatal(err)
			}
			image, err := base64.StdEncoding.DecodeString(req.Messages[0].Content[0].Source.Data)
			if err != nil || string(image) != "fixture" {
				t.Fatal("image encoding changed")
			}
			deadline, ok := r.Context().Deadline()
			if !ok || time.Until(deadline) > providerTimeout || time.Until(deadline) < providerTimeout-time.Second {
				t.Fatal("provider deadline")
			}
			return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(envelope(validReceipt))), Request: r}, nil
		})
		if _, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); err != nil {
			t.Fatal(err)
		}
	})
}

// The old excerpt/truncation helper is gone. Its regression name is retained to
// require finite errors for every code, including unknown untrusted codes.
func TestTruncate(t *testing.T) {
	for _, code := range []ParseErrorCode{ErrRateLimited, ErrAuthFailed, ErrInvalidRequest, ErrImageTooLarge, ErrOverloaded, ErrProviderDown, ErrBadResponse, ErrInvalidPeer, ParseErrorCode(strings.Repeat("synthetic-private", 100))} {
		e := &ParseError{Code: code}
		if len(e.Error()) > 80 || strings.Contains(e.Error(), "synthetic") || errors.Unwrap(e) != nil {
			t.Fatal("error excerpt or cause retained")
		}
	}
}

type failWriteConn struct {
	net.Conn
	fail *atomic.Bool
}

func (c *failWriteConn) Write(p []byte) (int, error) {
	if c.fail.Load() {
		return 0, errors.New("synthetic stale socket")
	}
	return c.Conn.Write(p)
}

func TestProviderStaleBeforeWriteDoesNotRetry(t *testing.T) {
	var posts, dials atomic.Int32
	var fail atomic.Bool
	s, server := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
		posts.Add(1)
		_, _ = io.Copy(io.Discard, r.Body)
		_, _ = io.WriteString(w, envelope(validReceipt))
	})
	config := s.transport.TLSClientConfig.Clone()
	s.transport.DialTLSContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		dials.Add(1)
		c, err := (&tls.Dialer{Config: config}).DialContext(ctx, "tcp", server.Listener.Addr().String())
		if err != nil {
			return nil, err
		}
		return &failWriteConn{Conn: c, fail: &fail}, nil
	}
	if _, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); err != nil {
		t.Fatal(err)
	}
	fail.Store(true)
	_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	requireCode(t, err, ErrProviderDown)
	if posts.Load() != 1 || dials.Load() != 1 {
		t.Fatalf("wire retry posts=%d dials=%d", posts.Load(), dials.Load())
	}
}

func TestProviderCallerCancellationSignal(t *testing.T) {
	s := fixtureService(t, "")
	arrived := make(chan context.Context, 1)
	release := make(chan struct{})
	s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		arrived <- r.Context()
		select {
		case <-r.Context().Done():
		case <-release:
		}
		return nil, errors.New("synthetic canceled transport")
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { _, err := s.Parse(ctx, []byte("fixture"), "image/jpeg"); done <- err }()
	observed := <-arrived
	cancel()
	signaled := false
	select {
	case <-observed.Done():
		signaled = true
	case <-time.After(250 * time.Millisecond):
	}
	close(release)
	select {
	case err := <-done:
		requireCode(t, err, ErrProviderDown)
	case <-time.After(time.Second):
		t.Fatal("parse not joined")
	}
	if !signaled {
		t.Fatal("caller cancellation did not reach actual transport")
	}
}

func TestProviderRedirectImmediate(t *testing.T) {
	var posts, gets, keyed atomic.Int32
	s, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			posts.Add(1)
		} else {
			gets.Add(1)
		}
		if r.Header.Get("x-api-key") != "" {
			keyed.Add(1)
		}
		_, _ = io.Copy(io.Discard, r.Body)
		if r.URL.Path == "/redirected" {
			_, _ = io.WriteString(w, envelope(validReceipt))
			return
		}
		w.Header().Set("Location", "https://synthetic-private-location.invalid/redirected")
		w.Header().Set("Content-Length", "0")
		w.WriteHeader(302)
	})
	_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	requireCode(t, err, ErrProviderDown)
	if posts.Load() != 1 || gets.Load() != 0 || keyed.Load() != 1 {
		t.Fatalf("redirect leaked key/wire: posts=%d gets=%d keyed=%d", posts.Load(), gets.Load(), keyed.Load())
	}
}

type heldWriteConn struct {
	net.Conn
	written chan struct{}
	release <-chan struct{}
	once    sync.Once
}

func (c *heldWriteConn) Write(p []byte) (int, error) {
	n, err := c.Conn.Write(p)
	c.once.Do(func() { close(c.written); <-c.release })
	return n, err
}

func TestProviderJoinsEarlyResponseWriter(t *testing.T) {
	arrived := make(chan struct{})
	written := make(chan struct{})
	release := make(chan struct{})
	s, server := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Length", "0")
		w.WriteHeader(401)
		w.(http.Flusher).Flush()
		close(arrived)
	})
	config := s.transport.TLSClientConfig.Clone()
	s.transport.DialTLSContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		c, err := (&tls.Dialer{Config: config}).DialContext(ctx, "tcp", server.Listener.Addr().String())
		if err != nil {
			return nil, err
		}
		return &heldWriteConn{Conn: c, written: written, release: release}, nil
	}
	done := make(chan error, 1)
	go func() {
		_, err := s.Parse(context.Background(), make([]byte, maxReceiptSize), "image/jpeg")
		done <- err
	}()
	select {
	case <-written:
	case <-time.After(time.Second):
		close(release)
		t.Fatal("fixture request did not write")
	}
	select {
	case <-arrived:
	case <-time.After(time.Second):
		close(release)
		t.Fatal("fixture response did not arrive")
	}
	var early error
	returned := false
	select {
	case early = <-done:
		returned = true
	case <-time.After(40 * time.Millisecond):
	}
	// Release and join even on a failed assertion; the intentional held frame is
	// bounded fixture I/O, not a runaway transport goroutine.
	close(release)
	if returned {
		requireCode(t, early, ErrAuthFailed)
		t.Error("Parse returned while actual wire writer was still active")
	} else {
		select {
		case err := <-done:
			requireCode(t, err, ErrAuthFailed)
		case <-time.After(time.Second):
			t.Fatal("writer was not joined")
		}
	}
}

type cancelOnCloseBody struct {
	io.ReadCloser
	cancel context.CancelFunc
}

func (b cancelOnCloseBody) Close() error { b.cancel(); return b.ReadCloser.Close() }

func TestProviderRechecksDeadlineAfterCleanup(t *testing.T) {
	s := fixtureService(t, "")
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: cancelOnCloseBody{ReadCloser: io.NopCloser(strings.NewReader(envelope(validReceipt))), cancel: cancel}, Request: r}, nil
	})
	result, err := s.Parse(ctx, []byte("fixture"), "image/jpeg")
	if result != nil || err == nil {
		t.Fatal("returned successful receipt after cancellation during actual body cleanup")
	}
	requireCode(t, err, ErrProviderDown)
}
