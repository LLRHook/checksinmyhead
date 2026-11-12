package receipt

import (
	"bytes"
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// All gates have idempotent release and bounded joins registered before work starts.
func proofGate(t *testing.T) (chan struct{}, func()) {
	t.Helper()
	ch := make(chan struct{})
	var o sync.Once
	f := func() { o.Do(func() { close(ch) }) }
	t.Cleanup(f)
	return ch, f
}
func proofWait(t *testing.T, ch <-chan struct{}, name string) {
	t.Helper()
	select {
	case <-ch:
	case <-time.After(2 * time.Second):
		t.Fatalf("fixture setup: %s", name)
	}
}
func proofService(t *testing.T) *Service {
	t.Helper()
	return configuredService(t, "1")
}
func proofHandler(t *testing.T, s *Service, ctx context.Context) (*Handler, <-chan struct{}) {
	t.Helper()
	h, r := receiptRouter(t, s)
	b, ct := multipartImage(t, false)
	req := httptest.NewRequest("POST", "/parse", bytes.NewReader(b)).WithContext(ctx)
	req.Header.Set("Content-Type", ct)
	req.RemoteAddr = "192.0.2.211:9"
	done := make(chan struct{})
	go func() { defer close(done); r.ServeHTTP(httptest.NewRecorder(), req) }()
	t.Cleanup(func() { proofWait(t, done, "handler cleanup") })
	return h, done
}
func proofHeld(t *testing.T, h *Handler, done <-chan struct{}, what string) {
	t.Helper()
	early := false
	select {
	case <-done:
		early = true
	case <-time.After(120 * time.Millisecond):
	}
	h.admission.mu.Lock()
	n := h.admission.inflight
	h.admission.mu.Unlock()
	t.Logf("ownership: %s returned=%v inflight=%d", what, early, n)
	if early || n != 1 {
		t.Errorf("Parse/permit escaped held %s", what)
	}
}

func TestOwnershipDialJoin(t *testing.T) {
	s := proofService(t)
	entered := make(chan struct{})
	release, free := proofGate(t)
	exited := make(chan struct{})
	var canceled atomic.Bool
	s.transport.dialContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		defer close(exited)
		close(entered)
		select {
		case <-ctx.Done():
			canceled.Store(true)
		case <-release:
		}
		<-release
		return nil, errors.New("synthetic dial cleanup")
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	h, done := proofHandler(t, s, ctx)
	defer func() { free(); proofWait(t, exited, "dial exit"); proofWait(t, done, "handler exit") }()
	proofWait(t, entered, "dial start")
	cancel()
	proofHeld(t, h, done, "dial")
	free()
	proofWait(t, exited, "dial exit")
	proofWait(t, done, "handler exit")
	t.Logf("proof: caller cancellation reached dial=%v", canceled.Load())
}

type proofCloseConn struct {
	net.Conn
	entered chan struct{}
	release <-chan struct{}
	once    sync.Once
}

func (c *proofCloseConn) Close() error {
	var e error
	c.once.Do(func() { e = c.Conn.Close(); close(c.entered); <-c.release })
	return e
}
func TestOwnershipTLSJoin(t *testing.T) {
	s := proofService(t)
	l, e := net.Listen("tcp", "127.0.0.1:0")
	if e != nil {
		t.Fatal(e)
	}
	defer l.Close()
	accepted := make(chan net.Conn, 1)
	serverDone := make(chan struct{})
	go func() {
		defer close(serverDone)
		c, e := l.Accept()
		if e == nil {
			accepted <- c
		}
	}()
	rawStart := make(chan struct{})
	closing := make(chan struct{})
	release, free := proofGate(t)
	var raw net.Conn
	s.transport.dialContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		c, e := (&net.Dialer{}).DialContext(ctx, "tcp", l.Addr().String())
		if e != nil {
			return nil, e
		}
		raw = c
		close(rawStart)
		return &proofCloseConn{Conn: c, entered: closing, release: release}, nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	h, done := proofHandler(t, s, ctx)
	var peer net.Conn
	defer func() {
		free()
		if peer != nil {
			peer.Close()
		}
		if raw != nil {
			raw.Close()
		}
		l.Close()
		proofWait(t, serverDone, "TLS server exit")
		proofWait(t, done, "TLS handler exit")
	}()
	proofWait(t, rawStart, "TLS raw connected")
	select {
	case peer = <-accepted:
	case <-time.After(2 * time.Second):
		t.Fatal("TLS accept setup")
	}
	// Observe a real TLS ClientHello before cancellation: TCP establishment
	// alone is insufficient evidence of a stalled handshake.
	_ = peer.SetReadDeadline(time.Now().Add(2 * time.Second))
	var record [5]byte
	if _, e := io.ReadFull(peer, record[:]); e != nil || record[0] != 22 {
		t.Fatalf("fixture setup: no TLS ClientHello: %v", e)
	}
	_ = peer.SetReadDeadline(time.Time{})
	cancel()
	proofHeld(t, h, done, "TLS handshake/close")
	peer.Close()
	free()
	proofWait(t, closing, "TLS close")
	proofWait(t, done, "TLS handler exit")
}

// A real verified TLS fixture; header/framing are stdlib or literal wire bytes.
func proofTLS(t *testing.T, handler http.HandlerFunc) (*Service, *httptest.Server, *tls.Config) {
	t.Helper()
	return tlsServiceWithSlots(t, handler, "1")
}

type proofFinalConn struct {
	net.Conn
	wrote   *atomic.Bool
	entered chan struct{}
	release <-chan struct{}
	once    sync.Once
	writes  *atomic.Int32
}

func (c *proofFinalConn) Write(p []byte) (int, error) {
	n, e := c.Conn.Write(p)
	k := c.writes.Add(1)
	if c.wrote.Load() {
		c.once.Do(func() { close(c.entered); <-c.release })
	}
	_ = k
	return n, e
}

func TestOwnershipFinalFlush(t *testing.T) {
	for _, status := range []int{200, 429} {
		t.Run(fmt.Sprint(status), func(t *testing.T) {
			arrived := make(chan struct{})
			s, server, config := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				io.Copy(io.Discard, r.Body)
				body := ""
				if status == 200 {
					body = envelope(validReceipt)
				}
				w.Header().Set("Content-Length", fmt.Sprint(len(body)))
				w.WriteHeader(status)
				io.WriteString(w, body)
				w.(http.Flusher).Flush()
				close(arrived)
			})
			var wrote atomic.Bool
			var writes atomic.Int32
			entered := make(chan struct{})
			release, free := proofGate(t)
			s.transport.connectTLS = func(ctx context.Context, _, _ string) (net.Conn, error) {
				c, e := (&tls.Dialer{Config: config}).DialContext(ctx, "tcp", server.Listener.Addr().String())
				if e != nil {
					return nil, e
				}
				return &proofFinalConn{Conn: c, wrote: &wrote, entered: entered, release: release, writes: &writes}, nil
			}
			ctx := httptraceContext(context.Background(), &wrote)
			done := make(chan struct{})
			var err error
			go func() { defer close(done); _, err = s.Parse(ctx, []byte("small fixture"), "image/jpeg") }()
			defer func() { free(); proofWait(t, done, "final flush cleanup") }()
			proofWait(t, entered, "socket final flush AFTER WroteRequest")
			proofWait(t, arrived, "response while flush held")
			early := false
			select {
			case <-done:
				early = true
			case <-time.After(180 * time.Millisecond):
			}
			t.Logf("ownership: final flush status=%d returned=%v writes=%d WroteRequest=%v", status, early, writes.Load(), wrote.Load())
			free()
			proofWait(t, done, "final flush exit")
			if early {
				t.Error("Parse escaped actual final socket Flush after WroteRequest")
			}
			if status == 200 && err != nil {
				t.Error(err)
			}
			if status == 429 {
				requireCode(t, err, ErrRateLimited)
			}
		})
	}
}

type proofDrainConn struct {
	exited chan struct{}
	net.Conn
	reads   atomic.Int32
	entered chan struct{}
	release <-chan struct{}
	once    sync.Once
}

func (c *proofDrainConn) Read(p []byte) (int, error) {
	k := c.reads.Add(1)
	n, e := c.Conn.Read(p)
	if k > 1 {
		c.once.Do(func() { defer close(c.exited); close(c.entered); <-c.release })
	}
	return n, e
}
func TestOwnershipNon200NoNativeDrain(t *testing.T) {
	held := make(chan struct{})
	release, free := proofGate(t)
	serverExit := make(chan struct{})
	s, server, config := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		defer close(serverExit)
		io.Copy(io.Discard, r.Body)
		w.WriteHeader(429)
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	})
	var wrapped *proofDrainConn
	ready := make(chan struct{})
	s.transport.connectTLS = func(ctx context.Context, _, _ string) (net.Conn, error) {
		c, e := (&tls.Dialer{Config: config}).DialContext(ctx, "tcp", server.Listener.Addr().String())
		if e != nil {
			return nil, e
		}
		wrapped = &proofDrainConn{Conn: c, entered: held, release: release, exited: make(chan struct{})}
		close(ready)
		return wrapped, nil
	}
	done := make(chan struct{})
	var err error
	go func() {
		defer close(done)
		ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
		defer cancel()
		_, err = s.Parse(ctx, []byte("fixture"), "image/jpeg")
	}()
	defer func() {
		free()
		proofWait(t, done, "drain parse cleanup")
		proofWait(t, serverExit, "drain server cleanup")
	}()
	proofWait(t, ready, "drain connection")
	drained := false
	select {
	case <-held:
		drained = true
	case <-time.After(150 * time.Millisecond):
	}
	early := false
	select {
	case <-done:
		early = true
	case <-time.After(100 * time.Millisecond):
	}
	t.Logf("ownership: non200 extra native read=%v Parse returned=%v reads=%d", drained, early, wrapped.reads.Load())
	free()
	proofWait(t, done, "drain parse")
	if drained {
		proofWait(t, wrapped.exited, "native drain Read exit")
	}
	if wrapped.reads.Load() > 1 {
		t.Error("non200 attempted arbitrary native body Read")
	}
	requireCode(t, err, ErrRateLimited)
	if drained {
		t.Error("non200 initiated arbitrary native post-Close body read")
	}
}

func TestOwnershipUnsolicitedLogTaint(t *testing.T) {
	const taint = "SYNTHETIC_PRIVATE_RECEIPT_billington_ocr_native_design"
	var buffer bytes.Buffer
	old := log.Writer()
	oldFlags := log.Flags()
	oldPrefix := log.Prefix()
	var mu sync.Mutex
	capture := &proofLog{mu: &mu, b: &buffer, seen: make(chan struct{}), taint: taint}
	log.SetOutput(capture)
	log.SetFlags(0)
	log.SetPrefix("")
	defer func() { log.SetOutput(old); log.SetFlags(oldFlags); log.SetPrefix(oldPrefix) }()
	var posts atomic.Int32
	s, _, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		posts.Add(1)
		io.Copy(io.Discard, r.Body)
		c, b, e := w.(http.Hijacker).Hijack()
		if e != nil {
			return
		}
		defer c.Close()
		body := envelope(validReceipt)
		fmt.Fprintf(b, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s%s", len(body), body, taint)
		b.Flush()
	})
	_, err := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-capture.seen:
	case <-time.After(150 * time.Millisecond):
	}
	s.Close()
	mu.Lock()
	leaked := strings.Contains(buffer.String(), taint)
	mu.Unlock()
	t.Logf("proof: synthetic unsolicited log taint=%v wire POSTs=%d", leaked, posts.Load())
	if leaked {
		t.Error("native provider bytes escaped finite log policy")
	}
}

type proofLog struct {
	mu    *sync.Mutex
	b     *bytes.Buffer
	seen  chan struct{}
	taint string
	once  sync.Once
}

func (l *proofLog) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	n, e := l.b.Write(p)
	if bytes.Contains(p, []byte(l.taint)) {
		l.once.Do(func() { close(l.seen) })
	}
	return n, e
}

func TestOwnershipHealthyReuse(t *testing.T) {
	var posts, dials atomic.Int32
	s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		posts.Add(1)
		io.Copy(io.Discard, r.Body)
		io.WriteString(w, envelope(validReceipt))
	})
	s.transport.dialContext = func(ctx context.Context, _, _ string) (net.Conn, error) {
		dials.Add(1)
		return (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
	}
	for i := 0; i < 2; i++ {
		got, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		if e != nil || got == nil || len(got.Items) != 2 {
			t.Fatalf("valid control: %v", e)
		}
	}
	if posts.Load() != 2 || dials.Load() != 1 {
		t.Fatalf("real reuse: POSTs=%d dials=%d", posts.Load(), dials.Load())
	}
	t.Logf("proof: healthy wire POSTs=%d TLS connections=%d", posts.Load(), dials.Load())
}
