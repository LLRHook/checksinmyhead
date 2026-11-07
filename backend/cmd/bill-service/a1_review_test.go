package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"backend/pkg/models"
	"backend/pkg/safehttp"
	"github.com/gin-gonic/gin"
)

// Use the production router and actual net/http transport, with the approved
// server deadlines. A recorder cannot observe net/http's post-handler draining.
func reviewServer(t *testing.T, h http.Handler, tls bool) (*httptest.Server, <-chan struct{}) {
	t.Helper()
	s := httptest.NewUnstartedServer(h)
	p := safehttp.DefaultServerPolicy()
	s.Config.ReadHeaderTimeout, s.Config.ReadTimeout = p.ReadHeader, p.Read
	s.Config.WriteTimeout, s.Config.IdleTimeout = p.Write, p.Idle
	s.Config.MaxHeaderBytes = p.MaxHeaderBytes
	closed := make(chan struct{}, 16)
	s.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateClosed {
			closed <- struct{}{}
		}
	}
	if tls {
		s.EnableHTTP2 = true
		s.StartTLS()
	} else {
		s.Start()
	}
	t.Cleanup(s.Close)
	return s, closed
}

func TestA1ReviewRejectedBodyTCP(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	for _, tc := range []struct {
		name, headers, body string
		status              int
		saturated           bool
	}{
		{"known_oversized", "Content-Length: 20000\r\n", "", 413, false},
		{"known_oversized_expect", "Content-Length: 20000\r\nExpect: 100-continue\r\n", "", 413, false},
		{"malformed_fixed", "Content-Length: 100\r\n", "!", 400, false},
		{"malformed_chunked", "Transfer-Encoding: chunked\r\n", "1\r\n!\r\n", 400, false},
		{"second_document_fixed", "Content-Length: 100\r\n", "{} {", 400, false},
		{"oversized_chunked", "Transfer-Encoding: chunked\r\n", "4001\r\n{}" + strings.Repeat(" ", (16<<10)-1) + "\r\n", 413, false},
		{"saturated_fixed", "Content-Length: 100\r\n", "", 503, true},
		{"saturated_chunked", "Transfer-Encoding: chunked\r\n", "", 503, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tabs := &a1Tabs{}
			r := a1Router(t, tabs)
			s, closed := reviewServer(t, r, false)
			if tc.saturated {
				entered, release := make(chan struct{}, 8), make(chan struct{})
				var once sync.Once
				var wg sync.WaitGroup
				unblock := func() { once.Do(func() { close(release) }) }
				tabs.create = func(ctx context.Context, _ *models.Tab, _ string) (*models.TabMember, error) {
					entered <- struct{}{}
					select {
					case <-release:
					case <-ctx.Done():
					}
					return nil, nil
				}
				t.Cleanup(func() { unblock(); wg.Wait() })
				for i := 0; i < 8; i++ {
					wg.Add(1)
					go func() {
						defer wg.Done()
						r.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/api/tabs", strings.NewReader(`{}`)))
					}()
				}
				for i := 0; i < 8; i++ {
					select {
					case <-entered:
					case <-time.After(3 * time.Second):
						t.Fatal("eight admitted controls did not enter")
					}
				}
			}
			conn, err := net.DialTimeout("tcp", s.Listener.Addr().String(), time.Second)
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { conn.Close() })
			// Less than the production 20s read deadline, but no millisecond
			// performance assertion. The missing body is never completed.
			if err := conn.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
				t.Fatal(err)
			}
			_, err = fmt.Fprintf(conn, "POST /api/tabs HTTP/1.1\r\nHost: fixture\r\nOrigin: https://billingtonapp.vercel.app\r\nContent-Type: text/plain\r\n%s\r\n%s", tc.headers, tc.body)
			if err != nil {
				t.Fatal(err)
			}
			reader := bufio.NewReader(conn)
			res, err := http.ReadResponse(reader, nil)
			if err != nil {
				t.Fatalf("rejection was not delivered before missing body: %v", err)
			}
			body, err := io.ReadAll(res.Body)
			res.Body.Close()
			if err != nil || res.StatusCode != tc.status || !strings.Contains(string(body), `"error"`) {
				t.Fatalf("status=%d body=%q error=%v", res.StatusCode, body, err)
			}
			if !res.Close {
				t.Error("rejected unread HTTP/1 body allowed connection reuse")
			}
			if tc.saturated && (res.Header.Get("Retry-After") != "1" || !strings.Contains(res.Header.Get("Access-Control-Expose-Headers"), "Retry-After")) {
				t.Error("saturation lost Retry-After/CORS")
			}
			// Response delivery alone misses a stall in finishRequest/body.Close.
			select {
			case <-closed:
			case <-time.After(2 * time.Second):
				t.Fatal("transport cleanup waited for the rejected body's remainder")
			}
			if _, err := reader.ReadByte(); err != io.EOF && !errors.Is(err, syscall.ECONNRESET) {
				t.Errorf("connection did not close after finite response: %v", err)
			}
			wantCalls := int32(0)
			if tc.saturated {
				wantCalls = 8
			}
			if tabs.calls.Load() != wantCalls {
				t.Errorf("rejected request reached service: calls=%d want=%d", tabs.calls.Load(), wantCalls)
			}
		})
	}
}

func TestA1ReviewCompleteBodyKeepAlive(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	tabs := &a1Tabs{}
	s, _ := reviewServer(t, a1Router(t, tabs), false)
	conn, err := net.DialTimeout("tcp", s.Listener.Addr().String(), time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close() })
	conn.SetDeadline(time.Now().Add(2 * time.Second))
	reader := bufio.NewReader(conn)
	for i := 0; i < 2; i++ {
		fmt.Fprint(conn, "POST /api/tabs HTTP/1.1\r\nHost: fixture\r\nContent-Length: 2\r\n\r\n{}")
		res, err := http.ReadResponse(reader, nil)
		if err != nil {
			t.Fatal(err)
		}
		_, readErr := io.Copy(io.Discard, res.Body)
		res.Body.Close()
		if res.StatusCode != 201 || res.Close || readErr != nil {
			t.Fatalf("valid body lost reusable connection: status=%d close=%v error=%v", res.StatusCode, res.Close, readErr)
		}
	}
	if tabs.calls.Load() != 2 {
		t.Error("valid controls did not reach service")
	}
}

func TestA1ReviewRejectedBodyHTTP2(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	s, _ := reviewServer(t, a1Router(t, &a1Tabs{}), true)
	client := s.Client()
	client.Timeout = 3 * time.Second
	reader, writer := io.Pipe()
	t.Cleanup(func() { reader.Close(); writer.Close(); client.CloseIdleConnections() })
	req, err := http.NewRequest("POST", s.URL+"/api/tabs", reader)
	if err != nil {
		t.Fatal(err)
	}
	req.ContentLength = 20000
	res, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_, readErr := io.Copy(io.Discard, res.Body)
	res.Body.Close()
	if readErr != nil || res.ProtoMajor != 2 || res.StatusCode != 413 || res.Header.Get("Connection") != "" {
		t.Fatalf("HTTP/2 rejection changed: proto=%s status=%d error=%v", res.Proto, res.StatusCode, readErr)
	}
	writer.Close()
	res, err = client.Post(s.URL+"/api/tabs", "application/json", strings.NewReader(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	io.Copy(io.Discard, res.Body)
	res.Body.Close()
	if res.ProtoMajor != 2 || res.StatusCode != 201 {
		t.Error("HTTP/2 valid follow-up failed")
	}
}

func TestA1ReviewProxyCanonicalization(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, tc := range []struct {
		name, config, remote string
		xff                  []string
		want                 string
	}{
		{"malformed_left_mapped", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid, ::ffff:198.51.100.2"}, "198.51.100.2"},
		{"empty_left_mapped", "192.0.2.0/24", "192.0.2.1:8", []string{", ::ffff:198.51.100.2"}, "198.51.100.2"},
		{"malformed_left_expanded_mapped", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid, 0:0:0:0:0:ffff:c633:6402"}, "198.51.100.2"},
		{"malformed_left_ipv6", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid, 2001:0db9:0000:0000:0000:0000:0000:0002"}, "2001:db9::2"},
		{"multiple_values", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid", "::ffff:198.51.100.2"}, "198.51.100.2"},
		{"trusted_suffix", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid, ::ffff:198.51.100.2, ::ffff:192.0.2.3"}, "198.51.100.2"},
		{"invalid_zone_left", "192.0.2.0/24", "192.0.2.1:8", []string{"fe80::1%eth0, ::ffff:198.51.100.2"}, "198.51.100.2"},
		{"invalid_right_fallback", "192.0.2.0/24", "192.0.2.1:8", []string{"::ffff:198.51.100.2, invalid"}, "192.0.2.1"},
		{"empty_right_fallback", "192.0.2.0/24", "192.0.2.1:8", []string{"::ffff:198.51.100.2, "}, "192.0.2.1"},
		{"invalid_middle_fallback", "192.0.2.0/24", "192.0.2.1:8", []string{"198.51.100.2, invalid, ::ffff:192.0.2.3"}, "192.0.2.1"},
		{"only_trusted_suffix_fallback", "192.0.2.0/24", "192.0.2.1:8", []string{"invalid, ::ffff:192.0.2.3"}, "192.0.2.1"},
		{"multiple_invalid_right_fallback", "192.0.2.0/24", "192.0.2.1:8", []string{"::ffff:198.51.100.2", "invalid"}, "192.0.2.1"},
		{"trust_none", "", "192.0.2.1:8", []string{"invalid, ::ffff:198.51.100.2"}, "192.0.2.1"},
		{"untrusted_socket", "192.0.2.0/24", "203.0.113.1:8", []string{"invalid, ::ffff:198.51.100.2"}, "203.0.113.1"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("TRUSTED_PROXY_CIDRS", tc.config)
			r := a1Router(t, &a1Tabs{})
			r.GET("/a1/review/ip", func(c *gin.Context) { c.String(200, c.ClientIP()) })
			req := httptest.NewRequest("GET", "/a1/review/ip", nil)
			req.RemoteAddr = tc.remote
			for _, v := range tc.xff {
				req.Header.Add("X-Forwarded-For", v)
			}
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if w.Code != 200 || w.Body.String() != tc.want {
				t.Errorf("status=%d peer=%q want=%q", w.Code, w.Body.String(), tc.want)
			}
		})
	}
}
