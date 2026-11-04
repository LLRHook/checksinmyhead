package safehttp

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"
)

func shortPolicy() ServerPolicy {
	return ServerPolicy{100 * time.Millisecond, 160 * time.Millisecond, 160 * time.Millisecond, 120 * time.Millisecond, 300 * time.Millisecond, 32 << 10}
}
func tcpServer(t *testing.T, h http.Handler, p ServerPolicy) (string, context.CancelFunc, <-chan error) {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- serve(ctx, l, h, p); close(done) }()
	t.Cleanup(func() {
		cancel()
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			t.Error("server did not stop")
		}
	})
	return l.Addr().String(), cancel, done
}
func tcpDial(t *testing.T, address string) net.Conn {
	t.Helper()
	c, err := net.DialTimeout("tcp", address, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.Close() })
	_ = c.SetDeadline(time.Now().Add(3 * time.Second))
	return c
}
func TestA1ServerPolicy(t *testing.T) {
	p := DefaultServerPolicy()
	s := newServer(context.Background(), ":0", http.NotFoundHandler(), p)
	if p.ReadHeader != 5*time.Second || p.Read != 20*time.Second || p.Write != 50*time.Second || p.Idle != 60*time.Second || p.Shutdown != 25*time.Second || p.MaxHeaderBytes != 32<<10 {
		t.Fatal("approved policy changed")
	}
	if s.ReadHeaderTimeout != p.ReadHeader || s.ReadTimeout != p.Read || s.WriteTimeout != p.Write || s.IdleTimeout != p.Idle || s.MaxHeaderBytes != p.MaxHeaderBytes || s.BaseContext == nil || s.ErrorLog == nil {
		t.Fatal("server constructor omitted policy")
	}
}
func TestA1ServerTCP(t *testing.T) {
	t.Run("slow_headers", func(t *testing.T) {
		var hit atomic.Bool
		p := shortPolicy()
		p.Read = 5 * time.Second
		a, _, _ := tcpServer(t, http.HandlerFunc(func(http.ResponseWriter, *http.Request) { hit.Store(true) }), p)
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET / HTTP/1.1\r\nHost: fixture\r\nX-Slow: ")
		b := make([]byte, 1)
		_, err := c.Read(b)
		if err == nil {
			t.Error("incomplete headers received response")
		}
		if n, ok := err.(net.Error); ok && n.Timeout() {
			t.Error("header deadline absent")
		}
		if hit.Load() {
			t.Error("incomplete request dispatched")
		}
	})
	for _, chunks := range []bool{false, true} {
		t.Run(fmt.Sprintf("slow_body_chunked_%v", chunks), func(t *testing.T) {
			read := make(chan error, 1)
			a, _, _ := tcpServer(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				_, err := io.ReadAll(r.Body)
				read <- err
				w.WriteHeader(400)
			}), shortPolicy())
			c := tcpDial(t, a)
			if chunks {
				fmt.Fprint(c, "POST / HTTP/1.1\r\nHost: fixture\r\nTransfer-Encoding: chunked\r\n\r\n10\r\nx")
			} else {
				fmt.Fprint(c, "POST / HTTP/1.1\r\nHost: fixture\r\nContent-Length: 16\r\n\r\nx")
			}
			select {
			case err := <-read:
				if err == nil {
					t.Error("partial body accepted")
				}
				var n net.Error
				if !errors.As(err, &n) || !n.Timeout() {
					t.Errorf("body error category %T", err)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("read deadline absent")
			}
		})
	}
	t.Run("oversized_headers", func(t *testing.T) {
		a, _, _ := tcpServer(t, http.NotFoundHandler(), shortPolicy())
		c := tcpDial(t, a)
		fmt.Fprintf(c, "GET / HTTP/1.1\r\nHost: fixture\r\nX-Large: %s\r\n\r\n", strings.Repeat("x", 40<<10))
		response, err := http.ReadResponse(bufio.NewReader(c), nil)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		if response.StatusCode != 431 {
			t.Errorf("status=%d", response.StatusCode)
		}
	})
	t.Run("idle_keepalive", func(t *testing.T) {
		p := shortPolicy()
		p.Read = 5 * time.Second
		a, _, _ := tcpServer(t, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "ok") }), p)
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET / HTTP/1.1\r\nHost: fixture\r\n\r\n")
		b := bufio.NewReader(c)
		res, err := http.ReadResponse(b, nil)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, res.Body)
		res.Body.Close()
		_, err = b.ReadByte()
		if err == nil {
			t.Error("unexpected idle data")
		}
		if n, ok := err.(net.Error); ok && n.Timeout() {
			t.Error("idle deadline absent")
		}
	})
	t.Run("write_deadline", func(t *testing.T) {
		wrote := make(chan error, 1)
		p := shortPolicy()
		a, _, _ := tcpServer(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Wait well beyond injected deadline; no exact-duration assertion.
			<-time.After(4 * p.Write)
			fmt.Fprint(w, "late")
			wrote <- http.NewResponseController(w).Flush()
		}), p)
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET / HTTP/1.1\r\nHost: fixture\r\n\r\n")
		select {
		case err := <-wrote:
			if err == nil {
				t.Error("write deadline absent")
			}
		case <-time.After(2 * time.Second):
			t.Fatal("write observation missing")
		}
		res, err := http.ReadResponse(bufio.NewReader(c), nil)
		if err == nil {
			res.Body.Close()
			t.Error("late response completed")
		}
	})
	t.Run("normal_json_html_health", func(t *testing.T) {
		a, _, _ := tcpServer(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/html" {
				w.Header().Set("Content-Type", "text/html")
				fmt.Fprint(w, "<p>ok</p>")
			} else {
				w.Header().Set("Content-Type", "application/json")
				fmt.Fprint(w, `{"status":"ok"}`)
			}
		}), shortPolicy())
		cl := &http.Client{Timeout: time.Second}
		defer cl.CloseIdleConnections()
		for _, path := range []string{"/json", "/html", "/health"} {
			res, err := cl.Get("http://" + a + path)
			if err != nil {
				t.Fatal(err)
			}
			b, _ := io.ReadAll(res.Body)
			res.Body.Close()
			if res.StatusCode != 200 || !bytes.Contains(b, []byte("ok")) {
				t.Error("ordinary request failed")
			}
		}
	})
}
func TestA1ServerShutdown(t *testing.T) {
	t.Run("cancel_and_graceful_success", func(t *testing.T) {
		entered := make(chan struct{})
		canceled := make(chan struct{})
		a, cancel, done := tcpServer(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			close(entered)
			<-r.Context().Done()
			close(canceled)
			fmt.Fprint(w, "canceled")
		}), shortPolicy())
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET / HTTP/1.1\r\nHost: fixture\r\n\r\n")
		<-entered
		cancel()
		select {
		case <-canceled:
		case <-time.After(time.Second):
			t.Fatal("BaseContext did not cancel")
		}
		res, err := http.ReadResponse(bufio.NewReader(c), nil)
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(res.Body)
		res.Body.Close()
		if string(b) != "canceled" {
			t.Error("graceful response lost")
		}
		select {
		case err := <-done:
			if err != nil {
				t.Errorf("normal shutdown %v", err)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("shutdown blocked")
		}
	})
	t.Run("forced_close", func(t *testing.T) {
		entered, release, finished := make(chan struct{}), make(chan struct{}), make(chan struct{})
		defer close(release)
		a, cancel, done := tcpServer(t, http.HandlerFunc(func(http.ResponseWriter, *http.Request) { close(entered); <-release; close(finished) }), shortPolicy())
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET / HTTP/1.1\r\nHost: fixture\r\n\r\n")
		<-entered
		cancel()
		select {
		case err := <-done:
			if !errors.Is(err, errShutdown) {
				t.Errorf("expected finite timeout got %v", err)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("no bounded shutdown")
		}
		b := make([]byte, 1)
		_, err := c.Read(b)
		if err == nil {
			t.Error("active connection not closed")
		}
		if n, ok := err.(net.Error); ok && n.Timeout() {
			t.Error("Close absent")
		}
	})
	t.Run("finite_bind_failure", func(t *testing.T) {
		if err := Serve(context.Background(), "private-invalid-address", http.NotFoundHandler()); err != errListen || strings.Contains(err.Error(), "private") {
			t.Error("raw bind diagnostic")
		}
	})
	t.Run("finite_serve_failure", func(t *testing.T) {
		l, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			t.Fatal(err)
		}
		l.Close()
		if err := serve(context.Background(), l, http.NotFoundHandler(), shortPolicy()); err != errServe {
			t.Error("serve failure hidden or raw")
		}
	})
}

type lockedOutput struct {
	sync.Mutex
	bytes.Buffer
}

func (b *lockedOutput) Write(p []byte) (int, error) {
	b.Lock()
	defer b.Unlock()
	return b.Buffer.Write(p)
}
func (b *lockedOutput) String() string { b.Lock(); defer b.Unlock(); return b.Buffer.String() }
func TestA1RecoveryTCP(t *testing.T) {
	old := gin.Mode()
	gin.SetMode(gin.TestMode)
	defer gin.SetMode(old)
	var output lockedOutput
	previous := log.Writer()
	log.SetOutput(&output)
	defer log.SetOutput(previous)
	for _, tc := range []struct {
		name    string
		value   any
		partial bool
	}{
		{"partial", "A1_SECRET_PARTIAL", true}, {"abort", http.ErrAbortHandler, false}, {"epipe", &net.OpError{Op: "write", Err: &os.SyscallError{Syscall: "write", Err: syscall.EPIPE}}, false},
		{"reset", &net.OpError{Op: "write", Err: syscall.ECONNRESET}, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r, err := NewRouter("")
			if err != nil {
				t.Fatal(err)
			}
			r.GET("/probe/:private", func(c *gin.Context) {
				if tc.partial {
					c.String(202, "partial")
					c.Writer.Flush()
				}
				panic(tc.value)
			})
			a, _, _ := tcpServer(t, r, shortPolicy())
			c := tcpDial(t, a)
			fmt.Fprint(c, "GET /probe/A1_SECRET_ROUTE?t=A1_SECRET_QUERY HTTP/1.1\r\nHost: fixture\r\n\r\n")
			raw, err := io.ReadAll(c)
			if n, ok := err.(net.Error); ok && n.Timeout() {
				t.Fatal("abort kept socket open")
			}
			if bytes.Contains(raw, []byte("500")) || bytes.Contains(raw, []byte("A1_SECRET")) {
				t.Error("abort appended false500/private value")
			}
			if !tc.partial && len(raw) != 0 {
				t.Error("abort produced an HTTP response")
			}
			if tc.partial && (!bytes.Contains(raw, []byte("202")) || !bytes.Contains(raw, []byte("partial"))) {
				t.Error("partial response missing")
			}
		})
	}

	t.Run("kernel_reset_cancels_handler", func(t *testing.T) {
		r, err := NewRouter("")
		if err != nil {
			t.Fatal(err)
		}
		entered, returned := make(chan struct{}), make(chan struct{})
		r.GET("/reset", JSONMutation, func(c *gin.Context) { close(entered); <-c.Request.Context().Done(); panic("A1_SECRET_KERNEL_RESET") })
		h := http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) { defer close(returned); r.ServeHTTP(w, req) })
		a, _, _ := tcpServer(t, h, shortPolicy())
		conn := tcpDial(t, a)
		fmt.Fprint(conn, "GET /reset HTTP/1.1\r\nHost: fixture\r\n\r\n")
		<-entered
		if err := conn.(*net.TCPConn).SetLinger(0); err != nil {
			t.Fatal(err)
		}
		conn.Close()
		select {
		case <-returned:
		case <-time.After(2 * time.Second):
			t.Fatal("kernel reset did not cancel and release handler")
		}
		if len(jsonMutations) != 0 {
			t.Error("reset leaked mutation slot")
		}
	})
	t.Run("standard_fallback_secrecy", func(t *testing.T) {
		a, _, _ := tcpServer(t, http.HandlerFunc(func(http.ResponseWriter, *http.Request) { panic("A1_SECRET_FALLBACK") }), shortPolicy())
		c := tcpDial(t, a)
		fmt.Fprint(c, "GET /?t=A1_SECRET_QUERY HTTP/1.1\r\nHost: fixture\r\n\r\n")
		io.ReadAll(c)
	})
	got := output.String()
	if strings.Contains(got, "A1_SECRET") || strings.Contains(got, "goroutine ") || strings.Contains(got, "panic serving") {
		t.Error("raw fallback or panic diagnostic")
	}
	if !strings.Contains(got, "event=http_server category=transport route=other") || !strings.Contains(got, "event=http_recovery category=abort route=other") {
		t.Error("finite diagnostic controls absent")
	}
}
