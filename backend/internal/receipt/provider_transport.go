package receipt

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/tls"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

var errProviderWire = errors.New("receipt provider transport failed")

const providerHeaderLimit = 32 << 10

// providerTransport is deliberately fixed-origin, HTTP/1.1, one attempt, no proxy.
// The pool owns sockets; a lease owns ALL operation I/O until Body.Close.
// Fields dialContext/tlsConfig/connectTLS are configured before first use only.
// connectTLS is a fixture seam for wrapping an already verified TLS connection.
type providerTransport struct {
	dialContext func(context.Context, string, string) (net.Conn, error)
	tlsConfig   *tls.Config
	connectTLS  func(context.Context, string, string) (net.Conn, error)
	limit       int
	idleTimeout time.Duration
	mu          sync.Mutex
	count       int // dialing + active + idle + closing, not merely checked-out requests
	idle        []*providerIdle
	closed      bool
	active      sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
	wake        chan struct{}
	done        chan struct{}
	closeOnce   sync.Once
}
type providerConn struct {
	wire      net.Conn
	raw       net.Conn
	closeOnce sync.Once
	network   *providerReadCount
}

func (c *providerConn) close() { c.closeOnce.Do(func() { _ = c.raw.Close() }) } // no TLS close_notify Write

type providerReadCount struct {
	net.Conn
	readBytes  atomic.Int64
	writeCalls atomic.Int64
}

func (c *providerReadCount) Read(p []byte) (int, error) {
	n, e := c.Conn.Read(p)
	c.readBytes.Add(int64(n))
	return n, e
}

// TLS Read can synchronously write alerts or KeyUpdate replies. Count all raw
// write attempts as well as reads so an interrupted idle TLS exchange is dirty.
func (c *providerReadCount) Write(p []byte) (int, error) { c.writeCalls.Add(1); return c.Conn.Write(p) }

type providerIdle struct {
	conn        *providerConn
	until       time.Time
	done        chan struct{}
	stop        atomic.Bool
	clean       bool
	start       int64
	startWrites int64
}

func startProviderIdle(c *providerConn, until time.Time) *providerIdle {
	x := &providerIdle{conn: c, until: until, done: make(chan struct{}), start: c.network.readBytes.Load(), startWrites: c.network.writeCalls.Load()}
	go func() {
		defer close(x.done)
		var b [1]byte
		n, e := c.wire.Read(b[:])
		var timeout net.Error
		x.clean = n == 0 && errors.As(e, &timeout) && timeout.Timeout() && x.stop.Load() && c.network.readBytes.Load() == x.start && c.network.writeCalls.Load() == x.startWrites
	}()
	return x
}
func (x *providerIdle) claim() bool {
	x.stop.Store(true)
	_ = x.conn.raw.SetDeadline(time.Now())
	<-x.done
	return x.clean
}
func (x *providerIdle) close() { x.conn.close(); <-x.done }
func newProviderTransport(slots int) *providerTransport {
	ctx, cancel := context.WithCancel(context.Background())
	t := &providerTransport{limit: slots, idleTimeout: time.Minute, dialContext: providerDialContext, tlsConfig: &tls.Config{MinVersion: tls.VersionTLS12, ServerName: "api.anthropic.com", NextProtos: []string{"http/1.1"}}, ctx: ctx, cancel: cancel, wake: make(chan struct{}, 1), done: make(chan struct{})}
	go t.expireIdle()
	return t
}
func (t *providerTransport) notify() {
	select {
	case t.wake <- struct{}{}:
	default:
	}
}

// One timer/worker per service, retaining only bounded idle sockets and expiry.
func (t *providerTransport) expireIdle() {
	defer close(t.done)
	timer := time.NewTimer(time.Hour)
	defer timer.Stop()
	for {
		t.mu.Lock()
		var wait time.Duration = time.Hour
		var stale []*providerIdle
		now := time.Now()
		keep := t.idle[:0]
		for _, idle := range t.idle {
			if !now.Before(idle.until) {
				stale = append(stale, idle)
			} else {
				keep = append(keep, idle)
				d := idle.until.Sub(now)
				if d < wait {
					wait = d
				}
			}
		}
		clear(t.idle[len(keep):])
		t.idle = keep
		closed := t.closed
		t.mu.Unlock()
		for _, x := range stale {
			x.close()
			t.mu.Lock()
			t.count--
			t.mu.Unlock()
		}
		if closed {
			return
		}
		timer.Reset(wait)
		select {
		case <-timer.C:
		case <-t.wake:
			if !timer.Stop() {
				select {
				case <-timer.C:
				default:
				}
			}
		case <-t.ctx.Done():
			return
		}
	}
}
func (t *providerTransport) take() (*providerConn, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		return nil, errProviderWire
	}
	// Expired sockets are closed before their reservations can be used again.
	for len(t.idle) > 0 {
		last := len(t.idle) - 1
		x := t.idle[last]
		t.idle[last] = nil
		t.idle = t.idle[:last]
		if time.Now().Before(x.until) {
			if !x.claim() {
				x.close()
				t.count--
				return nil, errProviderWire
			}
			t.active.Add(1)
			return x.conn, nil
		}
		x.close()
		t.count--
	}
	if t.count >= t.limit {
		return nil, errProviderWire
	}
	t.count++
	t.active.Add(1)
	return nil, nil
}
func (t *providerTransport) put(c *providerConn, reuse bool) {
	t.mu.Lock()
	if reuse && !t.closed {
		t.idle = append(t.idle, startProviderIdle(c, time.Now().Add(t.idleTimeout)))
		t.mu.Unlock()
		t.notify()
		t.active.Done()
		return
	}
	t.mu.Unlock()
	if c != nil {
		c.close()
	}
	t.mu.Lock()
	t.count--
	t.mu.Unlock()
	t.active.Done()
}
func (t *providerTransport) Close() {
	t.closeOnce.Do(func() {
		t.mu.Lock()
		t.closed = true
		idle := t.idle
		t.idle = nil
		t.mu.Unlock()
		t.cancel()
		for _, x := range idle {
			x.close()
			t.mu.Lock()
			t.count--
			t.mu.Unlock()
		}
		<-t.done
		t.active.Wait()
	})
}

// operation owns the cancellation callback AND the actual writer completion.
type providerOperation struct {
	t           *providerTransport
	c           *providerConn
	ctx         context.Context
	cancel      context.CancelFunc
	stopService func() bool
	serviceDone chan struct{}
	stopSocket  func() bool
	socketDone  chan struct{}
	writerDone  chan struct{}
	writeErr    error
	early       atomic.Bool
	once        sync.Once
}

func (o *providerOperation) finish(reuse bool) {
	o.once.Do(func() {
		if !reuse && o.c != nil {
			o.c.close()
		}
		if o.writerDone != nil {
			<-o.writerDone
		}
		if o.stopSocket != nil && !o.stopSocket() {
			<-o.socketDone
			reuse = false
		}
		if !o.stopService() {
			<-o.serviceDone
			reuse = false
		}
		if o.ctx.Err() != nil {
			reuse = false
		}
		if reuse {
			if o.c.raw.SetDeadline(time.Time{}) != nil {
				reuse = false
			}
		}
		o.cancel()
		o.t.put(o.c, reuse)
	})
}
func (t *providerTransport) RoundTrip(r *http.Request) (response *http.Response, err error) {
	// This private transport does not accept arbitrary URLs/methods/streams.
	if r.Method != "POST" || r.URL == nil || r.URL.String() != anthropicEndpoint || r.ContentLength <= 0 || r.GetBody != nil || r.Body == nil || len(r.TransferEncoding) != 0 {
		if r.Body != nil {
			r.Body.Close()
		}
		return nil, errProviderWire
	}
	c, e := t.take()
	if e != nil {
		r.Body.Close()
		return nil, errProviderWire
	}
	ctx, cancel := context.WithCancel(r.Context())
	o := &providerOperation{t: t, c: c, ctx: ctx, cancel: cancel, serviceDone: make(chan struct{})}
	o.stopService = context.AfterFunc(t.ctx, func() { defer close(o.serviceDone); cancel() })
	handed := false
	defer func() {
		if !handed {
			o.finish(false)
		}
		if err != nil {
			err = errProviderWire
		}
	}()
	request := r.Clone(ctx)
	request.Header.Set("Accept-Encoding", "gzip")
	// Never retain a caller/request/body in the pool entry.
	if c == nil {
		if ctx.Err() != nil {
			r.Body.Close()
			return nil, errProviderWire
		}
		if t.connectTLS != nil {
			wire, e := t.connectTLS(ctx, "tcp", "api.anthropic.com:443")
			if e != nil {
				r.Body.Close()
				return nil, errProviderWire
			}
			network := &providerReadCount{Conn: wire}
			c = &providerConn{wire: network, raw: network, network: network}
			o.c = c
		} else {
			dialCtx, dialCancel := context.WithTimeout(ctx, 10*time.Second)
			raw, e := t.dialContext(dialCtx, "tcp", "api.anthropic.com:443")
			dialCancel()
			if e != nil {
				r.Body.Close()
				return nil, errProviderWire
			}
			network := &providerReadCount{Conn: raw}
			c = &providerConn{raw: network, network: network}
			raw = network
			o.c = c
			o.socketDone = make(chan struct{})
			o.stopSocket = context.AfterFunc(ctx, func() { defer close(o.socketDone); c.close() })
			deadline, _ := ctx.Deadline()
			setup := time.Now().Add(10 * time.Second)
			if deadline.IsZero() || setup.Before(deadline) {
				deadline = setup
			}
			if raw.SetDeadline(deadline) != nil {
				r.Body.Close()
				return nil, errProviderWire
			}
			config := t.tlsConfig.Clone()
			config.MinVersion = tls.VersionTLS12
			config.NextProtos = []string{"http/1.1"}
			if config.ServerName == "" {
				config.ServerName = "api.anthropic.com"
			}
			if config.InsecureSkipVerify {
				r.Body.Close()
				return nil, errProviderWire
			}
			wire := tls.Client(raw, config)
			c.wire = wire
			// Own the raw cancellation/close callback, rather than the unjoinable
			// internal HandshakeContext callback. Handshake is synchronous; raw deadline
			// and the joined callback enforce the earlier caller/service/setup limit.
			if wire.HandshakeContext(context.Background()) != nil {
				r.Body.Close()
				return nil, errProviderWire
			}
			state := wire.ConnectionState()
			if state.NegotiatedProtocol != "" && state.NegotiatedProtocol != "http/1.1" {
				r.Body.Close()
				return nil, errProviderWire
			}
		}
	}
	if o.stopSocket == nil {
		o.socketDone = make(chan struct{})
		o.stopSocket = context.AfterFunc(ctx, func() { defer close(o.socketDone); c.close() })
	}
	deadline, _ := ctx.Deadline()
	if c.raw.SetDeadline(deadline) != nil {
		r.Body.Close()
		return nil, errProviderWire
	}
	if ctx.Err() != nil {
		r.Body.Close()
		return nil, errProviderWire
	}
	o.writerDone = make(chan struct{})
	go func() {
		defer close(o.writerDone)
		bw := bufio.NewWriter(c.wire)
		o.writeErr = request.Write(bw)
		if o.writeErr == nil {
			o.writeErr = bw.Flush()
		}
		if o.writeErr != nil && !o.early.Load() {
			c.close()
		}
	}()
	br := bufio.NewReaderSize(c.wire, 4096)
	remaining := providerHeaderLimit
	var parser *bufio.Reader
	for infos := 0; ; infos++ {
		var head []byte
		lineLen := 0
		for {
			line, e := br.ReadSlice('\n')
			if len(line) > remaining {
				return nil, errProviderWire
			}
			remaining -= len(line)
			head = append(head, line...)
			lineLen += len(line)
			if e == bufio.ErrBufferFull {
				continue
			}
			if e != nil {
				return nil, errProviderWire
			}
			if lineLen == 2 && bytes.Equal(line, []byte("\r\n")) {
				break
			}
			lineLen = 0
		}
		// Only this bounded head can reach MIME-header graph allocation. MultiReader
		// returns its first source alone: ReadResponse cannot prefetch body at setup.
		parser = bufio.NewReaderSize(io.MultiReader(bytes.NewReader(head), br), 4096)
		response, e = http.ReadResponse(parser, request)
		if e != nil {
			return nil, errProviderWire
		}
		if response.ProtoMajor != 1 || response.ProtoMinor != 1 {
			return nil, errProviderWire
		}
		if response.StatusCode >= 100 && response.StatusCode < 200 {
			if response.StatusCode == 101 || infos >= 4 {
				return nil, errProviderWire
			}
			continue
		}
		break
	}
	// Early final headers must interrupt and JOIN a blocked upload. This uses a
	// write-only deadline, so an early valid success can still be read normally.
	select {
	case <-o.writerDone:
	default:
		o.early.Store(true)
		_ = c.raw.SetWriteDeadline(time.Now())
		<-o.writerDone
	}
	if ctx.Err() != nil {
		return nil, errProviderWire
	}
	if response.StatusCode >= 300 && response.StatusCode < 400 {
		response.Header.Del("Location")
	}
	if response.StatusCode != 200 {
		o.finish(false)
		response.Body = http.NoBody
		handed = true
		return response, nil
	}
	// Do not invoke ReadResponse's draining Close on partial bodies. Our closer
	// owns/closes the REAL raw socket, drops the parser and never reads for cleanup.
	framed := &providerFramedBody{ReadCloser: response.Body, eof: response.Body == http.NoBody}
	var decoded io.Reader = framed
	if strings.EqualFold(response.Header.Get("Content-Encoding"), "gzip") {
		decoded = &providerGzipReader{body: framed}
		response.Header.Del("Content-Encoding")
		response.Header.Del("Content-Length")
		response.ContentLength = -1
		response.Uncompressed = true
	}
	response.Body = &providerOwnedBody{reader: decoded, framed: framed, op: o, parser: parser, br: br, canReuse: !response.Close && o.writeErr == nil}
	handed = true
	return response, nil
}

type providerFramedBody struct {
	io.ReadCloser
	eof bool
}

func (b *providerFramedBody) Read(p []byte) (int, error) {
	n, e := b.ReadCloser.Read(p)
	if e == io.EOF {
		b.eof = true
	}
	return n, e
}

type providerOwnedBody struct {
	reader             io.Reader
	framed             *providerFramedBody
	op                 *providerOperation
	parser, br         *bufio.Reader
	canReuse, eof, bad bool
	once               sync.Once
}

func (b *providerOwnedBody) Read(p []byte) (int, error) {
	if b.reader == nil {
		return 0, http.ErrBodyReadAfterClose
	}
	n, e := b.reader.Read(p)
	if e == io.EOF {
		b.eof = true
	} else if e != nil {
		b.bad = true
	}
	return n, e
}
func (b *providerOwnedBody) Close() error {
	b.once.Do(func() {
		reuse := b.canReuse && b.eof && b.framed.eof && !b.bad && b.parser.Buffered() == 0 && b.br.Buffered() == 0
		if reuse {
			_ = b.framed.Close()
		}
		if z, ok := b.reader.(*providerGzipReader); ok {
			_ = z.Close()
		}
		b.op.finish(reuse)
		b.reader = nil
		b.framed = nil
		b.parser = nil
		b.br = nil
		b.op = nil
	})
	return nil
}

// Lazy initialization preserves the Service's malformed-success classification:
// invalid gzip is a response-body read error (bad_response), not a dial error.
type providerGzipReader struct {
	body        io.Reader
	reader      *gzip.Reader
	err         error
	initialized bool
}

func (g *providerGzipReader) Read(p []byte) (int, error) {
	if !g.initialized {
		g.initialized = true
		g.reader, g.err = gzip.NewReader(g.body)
	}
	if g.err != nil {
		return 0, g.err
	}
	return g.reader.Read(p)
}
func (g *providerGzipReader) Close() error {
	if g.reader != nil {
		return g.reader.Close()
	}
	return nil
}
