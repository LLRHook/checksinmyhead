package receipt

// Preserve stdlib Go DNS parsing and hosts/search/server policy. The provider
// transport owns cancellation and joins cleanup at each native query socket.
import (
	"context"
	"net"
	"net/netip"
	"sync"
	"time"
)

// A direct caller-context Resolver lookup can return before its producers stop.
// A private invocation has no shared lookup users. Its OUTER wait is never
// canceled; its actual DNS socket dials/reads are canceled and joined instead.
// No custom DNS parser, application cache, global resolver change, or private API.
func providerResolve(ctx context.Context, host string, dial func(context.Context, string, string) (net.Conn, error)) ([]net.IPAddr, error) {
	r := &net.Resolver{PreferGo: true}
	r.Dial = func(query context.Context, n, a string) (net.Conn, error) {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		// Resolver server addresses are literal IP:port. Prevent recursive DNS or
		// Happy Eyeballs behind this seam; no external provider POST occurs here.
		if _, e := netip.ParseAddrPort(a); e != nil {
			return nil, errProviderWire
		}
		child, cancel := context.WithCancel(ctx)
		queryDone := make(chan struct{})
		stop := context.AfterFunc(query, func() { defer close(queryDone); cancel() })
		raw, e := dial(child, n, a)
		if e != nil {
			if !stop() {
				<-queryDone
			}
			cancel()
			return nil, e
		}
		c := newProviderDNSSocket(child, raw)
		c.doneCancel = func() {
			if !stop() {
				<-queryDone
			}
			cancel()
		}
		if packet, ok := raw.(net.PacketConn); ok {
			return &providerDNSPacket{providerDNSSocket: c, packet: packet}, nil
		}
		return c, nil
	}
	return r.LookupIPAddr(context.Background(), host)
}

// packet is intentionally exposed for native UDP DNS framing, with deadlines
// clamped to the earlier operation limit even when the resolver resets its own.
type providerDNSSocket struct {
	net.Conn
	ctx        context.Context
	stop       func() bool
	done       chan struct{}
	once       sync.Once
	closeOnce  sync.Once
	doneCancel func()
}

func newProviderDNSSocket(ctx context.Context, c net.Conn) *providerDNSSocket {
	s := &providerDNSSocket{Conn: c, ctx: ctx, done: make(chan struct{})}
	s.stop = context.AfterFunc(ctx, func() { defer close(s.done); s.closeRaw() })
	return s
}
func (s *providerDNSSocket) closeRaw() { s.closeOnce.Do(func() { s.Conn.Close() }) }
func (s *providerDNSSocket) Close() error {
	s.once.Do(func() {
		s.closeRaw()
		if !s.stop() {
			<-s.done
		}
		if s.doneCancel != nil {
			s.doneCancel()
		}
	})
	return nil
}
func (s *providerDNSSocket) SetDeadline(t time.Time) error {
	if d, ok := s.ctx.Deadline(); ok && (t.IsZero() || d.Before(t)) {
		t = d
	}
	return s.Conn.SetDeadline(t)
}

type providerDNSPacket struct {
	*providerDNSSocket
	packet net.PacketConn
}

func (s *providerDNSPacket) ReadFrom(p []byte) (int, net.Addr, error)  { return s.packet.ReadFrom(p) }
func (s *providerDNSPacket) WriteTo(p []byte, a net.Addr) (int, error) { return s.packet.WriteTo(p, a) }

func providerDialContext(ctx context.Context, n, a string) (net.Conn, error) {
	dialer := &net.Dialer{KeepAlive: 30 * time.Second, FallbackDelay: -1}
	return providerDialWithDNS(ctx, n, a, dialer.DialContext, dialer.DialContext)
}
func providerDialWithDNS(ctx context.Context, n, a string, dnsDial, tcpDial func(context.Context, string, string) (net.Conn, error)) (net.Conn, error) {
	host, port, e := net.SplitHostPort(a)
	if e != nil {
		return nil, errProviderWire
	}
	addrs, e := providerResolve(ctx, host, dnsDial)
	if e != nil {
		return nil, errProviderWire
	}
	// Serial native numeric dials give each reservation at most one provider socket
	// including cancel/closing. No loser from a parallel dial can outlive the call.
	for i, ip := range addrs {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		attempt := ctx
		cancel := func() {}
		if deadline, ok := ctx.Deadline(); ok {
			left := time.Until(deadline)
			share := left / time.Duration(len(addrs)-i)
			if share < 2*time.Second {
				share = 2 * time.Second
			}
			if share < left {
				attempt, cancel = context.WithTimeout(ctx, share)
			}
		}
		c, e := tcpDial(attempt, n, net.JoinHostPort(ip.String(), port))
		cancel()
		if e == nil {
			return c, nil
		}
	}
	return nil, errProviderWire
}
