package receipt

import (
	"context"
	"testing"
	"time"
)

func TestDriverAdmissionClock(t *testing.T) {
	t.Run("samples_inside_the_critical_section", func(t *testing.T) {
		a := newAdmission(policy{2})
		defer a.close()
		calls := 0
		release, err := a.acquire(context.Background(), "192.0.2.1", func() time.Time {
			calls++
			if a.mu.TryLock() {
				a.mu.Unlock()
				t.Error("admission time sampled outside the critical section")
			}
			return time.Now()
		})
		if err != nil || calls != 1 {
			t.Fatalf("valid clock/admission failed: calls=%d error=%v", calls, err)
		}
		release()
	})
	t.Run("canceled_admission_never_samples_or_charges", func(t *testing.T) {
		a := newAdmission(policy{2})
		defer a.close()
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		called := false
		release, err := a.acquire(ctx, "192.0.2.1", func() time.Time { called = true; return time.Now() })
		if release != nil || err == nil || called || len(a.peers) != 0 || a.inflight != 0 {
			t.Error("canceled admission sampled time or changed state")
		}
	})
	t.Run("actual_admission_order_keeps_recent_starts", func(t *testing.T) {
		a := newAdmission(policy{2})
		defer a.close()
		now := time.Unix(2_000_000_000, 0)
		clock := func() time.Time { return now }
		admit := func() {
			t.Helper()
			release, err := a.acquire(context.Background(), "192.0.2.1", clock)
			if err != nil {
				t.Fatalf("positive admission failed: %v", err)
			}
			release()
		}
		now = now.Add(time.Second)
		admit()
		now = now.Add(time.Second)
		admit()
		now = now.Add(58 * time.Second)
		for range 8 {
			admit()
		}
		release, err := a.acquire(context.Background(), "192.0.2.1", clock)
		if release != nil {
			release()
		}
		if err == nil || err.Code != ErrRateLimited {
			t.Error("recent rolling starts expired early")
		}
		now = now.Add(time.Second)
		admit()
	})
}
