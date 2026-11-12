package receipt

import (
	"context"
	"errors"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"testing"
)

func proofSetDNS(s *Service, dnsDial, tcpDial func(context.Context, string, string) (net.Conn, error)) {
	s.transport.dialContext = func(ctx context.Context, n, a string) (net.Conn, error) {
		return providerDialWithDNS(ctx, n, a, dnsDial, tcpDial)
	}
}

func TestOwnershipDNSJoin(t *testing.T) {
	s := proofService(t)
	started := make(chan struct{})
	release, free := proofGate(t)
	var start sync.Once
	var mu sync.Mutex
	sealed := false
	var peers []net.Conn
	var wg, closedWG sync.WaitGroup
	var opens, closes atomic.Int32
	dnsDial := func(ctx context.Context, _, _ string) (net.Conn, error) {
		mu.Lock()
		defer mu.Unlock()
		if sealed {
			return nil, errors.New("synthetic sealed DNS")
		}
		c, p := net.Pipe()
		peers = append(peers, p)
		opens.Add(1)
		closedWG.Add(1)
		wg.Add(1)
		go func() { defer wg.Done(); defer p.Close(); start.Do(func() { close(started) }); io.Copy(io.Discard, p) }()
		return &proofDNSClose{Conn: c, release: release, closes: &closes, closedWG: &closedWG}, nil
	}
	proofSetDNS(s, dnsDial, func(context.Context, string, string) (net.Conn, error) {
		return nil, errors.New("synthetic no provider TCP expected")
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	h, done := proofHandler(t, s, ctx)
	defer func() {
		mu.Lock()
		sealed = true
		free()
		for _, p := range peers {
			p.Close()
		}
		mu.Unlock()
		proofWait(t, done, "DNS handler cleanup")
		s.Close()
		closedWG.Wait()
		wg.Wait()
		t.Logf("proof: DNS sockets opened=%d closed=%d", opens.Load(), closes.Load())
		if opens.Load() != closes.Load() {
			t.Error("DNS sockets not closed/joined")
		}
	}()
	proofWait(t, started, "native DNS query")
	cancel()
	proofHeld(t, h, done, "native resolver DNS cleanup")
}

type proofDNSClose struct {
	net.Conn
	release  <-chan struct{}
	once     sync.Once
	closes   *atomic.Int32
	closedWG *sync.WaitGroup
}

func (c *proofDNSClose) Close() error {
	c.once.Do(func() { c.Conn.Close(); <-c.release; c.closes.Add(1); c.closedWG.Done() })
	return nil
}
