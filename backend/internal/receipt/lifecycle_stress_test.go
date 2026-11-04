package receipt

import (
	"context"
	"io"
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// Repeatedly contend Close's rejection/WaitGroup boundary with cancellation and
// with the real idle timer/claim path. Every round joins callers and actual raw
// socket Close; fixture callbacks alone do not establish native completion.
func TestOwnershipConcurrentCloseStress(t *testing.T) {
	for _, mode := range []string{"active_cancel", "idle_timer_claim"} {
		t.Run(mode, func(t *testing.T) {
			for round := range 32 {
				arrived := make(chan struct{}, 2)
				var live, posts atomic.Int32
				s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
					io.Copy(io.Discard, r.Body)
					posts.Add(1)
					arrived <- struct{}{}
					if mode == "active_cancel" {
						<-r.Context().Done()
						return
					}
					io.WriteString(w, envelope(validReceipt))
				})
				s.transport.idleTimeout = time.Duration(1+round%4) * time.Millisecond
				proofSetDial(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
					c, err := (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
					if err == nil {
						live.Add(1)
						return &proofCountClose{Conn: c, live: &live}, nil
					}
					return nil, err
				})
				ctx, cancel := context.WithCancel(context.Background())
				done := make(chan error, 1)
				start := func() {
					go func() { _, err := s.Parse(ctx, []byte("fixture"), "image/jpeg"); done <- err }()
				}
				start()
				select {
				case <-arrived:
				case <-time.After(2 * time.Second):
					cancel()
					s.Close()
					t.Fatal("stress provider never received first POST")
				}
				if mode == "idle_timer_claim" {
					if err := <-done; err != nil {
						cancel()
						s.Close()
						t.Fatal(err)
					}
					start()
				}
				var closers sync.WaitGroup
				closers.Add(12)
				for range 12 {
					go func() { defer closers.Done(); s.Close() }()
				}
				cancel()
				joined := make(chan struct{})
				go func() { closers.Wait(); close(joined) }()
				proofWait(t, joined, "concurrent Close joins")
				select {
				case err := <-done:
					if mode == "active_cancel" || err != nil {
						requireCode(t, err, ErrProviderDown)
					}
				case <-time.After(2 * time.Second):
					t.Fatal("Parse survived all Close returns")
				}
				proofWait(t, s.transport.done, "stress timer join")
				s.transport.mu.Lock()
				count, idle := s.transport.count, len(s.transport.idle)
				s.transport.mu.Unlock()
				server.Close()
				if count != 0 || idle != 0 || live.Load() != 0 || posts.Load() > 2 {
					t.Fatalf("round %d: count=%d idle=%d live=%d posts=%d", round, count, idle, live.Load(), posts.Load())
				}
			}
			t.Log("32 rounds, 384 concurrent Close calls, all native sockets/timers/callers joined")
		})
	}
}
