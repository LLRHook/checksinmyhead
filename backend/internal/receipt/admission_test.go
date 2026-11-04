package receipt

import (
	"context"
	"fmt"
	"net/netip"
	"sync"
	"testing"
	"time"
)

func TestAdmissionPolicy(t *testing.T) {
	for _, tc := range []struct {
		input string
		slots int
	}{{"", 2}, {"1", 1}, {"8", 8}, {"0", 0}, {"9", 0}, {"+2", 0}, {" 2", 0}, {"02", 0}, {"secret-invalid-policy", 0}} {
		t.Run(fmt.Sprintf("value_%d_%s", tc.slots, tc.input), func(t *testing.T) {
			p, e := parsePolicy(tc.input)
			t.Setenv("ANTHROPIC_API_KEY", "synthetic-local-fixture")
			t.Setenv("OCR_MAX_INFLIGHT", tc.input)
			service, constructorErr := NewService()
			if tc.slots == 0 {
				if constructorErr == nil || ValidatePolicy() == nil {
					if service != nil {
						service.Close()
					}
					t.Fatal("invalid policy admitted by production constructor")
				}
			} else {
				if constructorErr != nil {
					t.Fatal(constructorErr)
				}
				handler := NewHandler(service)
				defer handler.Close()
				if service.policy.slots != tc.slots || handler.admission.capacity != tc.slots || service.transport.limit != tc.slots {
					t.Fatal("constructor policy mismatch")
				}
			}

			if tc.slots == 0 {
				if e == nil || e.Error() != "invalid OCR policy" {
					t.Fatal("nonfinite policy error")
				}
			} else if e != nil || p.slots != tc.slots {
				t.Fatal("policy mismatch")
			}
		})
	}
}

func TestAdmissionLifetime(t *testing.T) {
	a := newAdmission(policy{2})
	defer a.close()
	now := time.Now()
	acquire := func(peer string) (func(), *ParseError) {
		return a.acquire(context.Background(), peer, func() time.Time { return now })
	}
	t.Run("invalid_and_precancel", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		if r, e := a.acquire(ctx, "192.0.2.1", func() time.Time { return now }); r != nil || e == nil {
			t.Fatal("canceled admission")
		}
		for _, peer := range []string{"invalid", "fe80::1%en0", ""} {
			if r, e := acquire(peer); r != nil || e.Code != ErrInvalidPeer {
				t.Fatal("invalid peer")
			}
		}
		if len(a.peers) != 0 || a.inflight != 0 {
			t.Fatal("denial state")
		}
	})
	t.Run("slots_before_charge", func(t *testing.T) {
		r1, e := acquire("192.0.2.1")
		if e != nil {
			t.Fatal(e)
		}
		r2, e := acquire("192.0.2.2")
		if e != nil {
			t.Fatal(e)
		}
		for i := 0; i < 40; i++ {
			if r, e := acquire(fmt.Sprintf("192.0.2.%d", i+3)); r != nil || e.Code != ErrOverloaded {
				t.Fatal("queued or admitted")
			}
		}
		if len(a.peers) != 2 || a.inflight != 2 {
			t.Fatal("denial charged")
		}
		r2()
		r2()
		r1()
		if a.inflight != 0 {
			t.Fatal("release not exactly once")
		}
	})
	t.Run("quota_normalization_expiry", func(t *testing.T) {
		for i := 0; i < 9; i++ {
			r, e := acquire("::ffff:192.0.2.1")
			if e != nil {
				t.Fatal(e)
			}
			r()
		}
		before := a.peers[netip.MustParseAddr("192.0.2.1")]
		if r, e := acquire("192.0.2.1"); r != nil || e.Code != ErrRateLimited || e.RetryAfter != 60 {
			t.Fatal("quota bypass")
		}
		if after := a.peers[netip.MustParseAddr("192.0.2.1")]; before != after {
			t.Fatal("denial extended expiry")
		}
		r, e := a.acquire(context.Background(), "192.0.2.1", func() time.Time { return now.Add(time.Minute) })
		if e != nil {
			t.Fatal(e)
		}
		r()
		if len(a.peers) != 1 {
			t.Fatal("admission expiry pruning")
		}
	})
	t.Run("full_active_table", func(t *testing.T) {
		a.mu.Lock()
		a.peers = make(map[netip.Addr]peerAdmissions)
		for i := 0; i < maxPeerKeys; i++ {
			ip := netip.AddrFrom4([4]byte{10, byte(i >> 8), byte(i), 1})
			a.peers[ip] = peerAdmissions{times: [10]time.Time{now}, n: 1}
		}
		a.mu.Unlock()
		if r, e := acquire("198.51.100.1"); r != nil || e.Code != ErrOverloaded || e.RetryAfter != 15 || len(a.peers) != 4096 {
			t.Fatal("table overflow")
		}
		r, e := acquire("10.0.0.1")
		if e != nil {
			t.Fatal("existing peer blocked")
		}
		r()
		r, e = a.acquire(context.Background(), "198.51.100.1", func() time.Time { return now.Add(time.Minute) })
		if e != nil {
			t.Fatal(e)
		}
		r()
		if len(a.peers) != 1 {
			t.Fatal("active entries not pruned")
		}
	})
}

func TestAdmissionContenders(t *testing.T) {
	for _, reverse := range []bool{false, true} {
		t.Run(fmt.Sprint(reverse), func(t *testing.T) {
			a := newAdmission(policy{2})
			defer a.close()
			start := make(chan struct{})
			hold := make(chan struct{})
			var wg sync.WaitGroup
			results := make(chan bool, 24)
			for i := 0; i < 24; i++ {
				wg.Add(1)
				go func(i int) {
					defer wg.Done()
					<-start
					r, e := a.acquire(context.Background(), fmt.Sprintf("192.0.2.%d", i+1), func() time.Time { return time.Now() })
					results <- e == nil
					if r != nil {
						<-hold
						r()
					}
				}(i)
			}
			close(start)
			accepted := 0
			for i := 0; i < 24; i++ {
				if <-results {
					accepted++
				}
			}
			if accepted != 2 {
				t.Fatalf("admitted=%d", accepted)
			}
			close(hold)
			wg.Wait()
			a.mu.Lock()
			n, keys := a.inflight, len(a.peers)
			a.mu.Unlock()
			if n != 0 || keys != 2 {
				t.Fatal("permits/state leaked")
			}
		})
	}
}

func TestAdmissionIdleSweepAndClose(t *testing.T) {
	a := newAdmission(policy{2})
	a.mu.Lock()
	a.peers[netip.MustParseAddr("192.0.2.1")] = peerAdmissions{times: [10]time.Time{time.Now().Add(-time.Minute)}, n: 1}
	a.mu.Unlock()
	deadline := time.Now().Add(sweepInterval + 2*time.Second)
	for {
		a.mu.Lock()
		n := len(a.peers)
		a.mu.Unlock()
		if n == 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("idle keys retained")
		}
		time.Sleep(20 * time.Millisecond)
	}
	a.close()
	a.close()
	select {
	case <-a.done:
	default:
		t.Fatal("sweeper not joined")
	}
	if r, e := a.acquire(context.Background(), "192.0.2.1", func() time.Time { return time.Now() }); r != nil || e == nil {
		t.Fatal("closed admission")
	}
}
