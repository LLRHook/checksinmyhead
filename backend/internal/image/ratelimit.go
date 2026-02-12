package image

import (
	"sync"
	"time"
)

type RateLimiter struct {
	mu      sync.Mutex
	buckets map[uint][]time.Time // tabID -> upload timestamps
	limit   int
	window  time.Duration
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		buckets: make(map[uint][]time.Time),
		limit:   limit,
		window:  window,
	}
}

// Allow checks whether a tab is under the rate limit and records the attempt if so.
func (rl *RateLimiter) Allow(tabID uint) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-rl.window)

	// Prune expired entries
	timestamps := rl.buckets[tabID]
	valid := timestamps[:0]
	for _, ts := range timestamps {
		if ts.After(cutoff) {
			valid = append(valid, ts)
		}
	}

	if len(valid) >= rl.limit {
		rl.buckets[tabID] = valid
		return false
	}

	rl.buckets[tabID] = append(valid, now)
	return true
}
