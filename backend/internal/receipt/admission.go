package receipt

import (
	"context"
	"net/netip"
	"sync"
	"time"
)

type peerAdmissions struct {
	times [10]time.Time
	n     int
}

func (b peerAdmissions) prune(now time.Time) peerAdmissions {
	i := 0
	for i < b.n && !b.times[i].After(now.Add(-peerWindow)) {
		i++
	}
	copy(b.times[:], b.times[i:b.n])
	b.n -= i
	return b
}

// admission owns both bounds under one lock: a denial cannot consume a slot,
// allocate a peer, extend its lifetime, or spend a rolling admission.
type admission struct {
	mu                 sync.Mutex
	peers              map[netip.Addr]peerAdmissions
	inflight, capacity int
	closed             bool
	stop, done         chan struct{}
	once               sync.Once
}

func newAdmission(p policy) *admission {
	a := &admission{peers: make(map[netip.Addr]peerAdmissions), capacity: p.slots, stop: make(chan struct{}), done: make(chan struct{})}
	go func() {
		defer close(a.done)
		t := time.NewTicker(sweepInterval)
		defer t.Stop()
		for {
			select {
			case now := <-t.C:
				a.mu.Lock()
				a.prune(now)
				a.mu.Unlock()
			case <-a.stop:
				return
			}
		}
	}()
	return a
}

func (a *admission) prune(now time.Time) {
	for ip, b := range a.peers {
		if b.n == 0 || !b.times[b.n-1].Add(peerWindow).After(now) {
			delete(a.peers, ip)
		}
	}
}

func (a *admission) acquire(ctx context.Context, peer string, now time.Time) (func(), *ParseError) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if ctx.Err() != nil || a.closed {
		return nil, &ParseError{Code: ErrProviderDown}
	}
	ip, err := netip.ParseAddr(peer)
	if err != nil || ip.Zone() != "" {
		return nil, &ParseError{Code: ErrInvalidPeer}
	}
	ip = ip.Unmap()
	a.prune(now)
	b, exists := a.peers[ip]
	b = b.prune(now)
	if !exists && len(a.peers) >= maxPeerKeys {
		return nil, &ParseError{Code: ErrOverloaded, RetryAfter: 15}
	}
	if b.n == len(b.times) {
		return nil, &ParseError{Code: ErrRateLimited, RetryAfter: int((b.times[0].Add(peerWindow).Sub(now) + time.Second - 1) / time.Second)}
	}
	if a.inflight >= a.capacity {
		return nil, &ParseError{Code: ErrOverloaded, RetryAfter: 1}
	}
	a.inflight++
	b.times[b.n] = now
	b.n++
	a.peers[ip] = b
	var once sync.Once
	return func() { once.Do(func() { a.mu.Lock(); a.inflight--; a.mu.Unlock() }) }, nil
}

func (a *admission) close() {
	a.once.Do(func() { a.mu.Lock(); a.closed = true; a.mu.Unlock(); close(a.stop) })
	<-a.done
}
