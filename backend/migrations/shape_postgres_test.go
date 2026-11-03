//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"sort"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

type statementCounter struct{ count atomic.Int64 }

func (c *statementCounter) TraceQueryStart(ctx context.Context, _ *pgx.Conn, _ pgx.TraceQueryStartData) context.Context {
	c.count.Add(1)
	return ctx
}
func (c *statementCounter) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}

func TestPostgresReadinessQueryShape(t *testing.T) {
	counter := &statementCounter{}
	db := testpostgres.Open(t, counter)
	counter.count.Store(0)
	start := time.Now()
	state := apply(t, db)
	t.Logf("fresh startup statements=%d duration=%s (includes transaction control, session setup, catalogs and ledger; one sample)", counter.count.Load(), time.Since(start))
	counter.count.Store(0)
	start = time.Now()
	apply(t, db)
	t.Logf("repeat startup statements=%d duration=%s (includes transaction control, session setup, catalogs and ledger; one sample)", counter.count.Load(), time.Since(start))
	for run := 1; run <= 3; run++ {
		samples := make([]time.Duration, 100)
		counter.count.Store(0)
		for i := range samples {
			start := time.Now()
			if err := state.Check(context.Background()); err != nil {
				t.Fatal(err)
			}
			samples[i] = time.Since(start)
		}
		if got := counter.count.Load(); got != 100 {
			t.Fatalf("health made %d queries for 100 requests", got)
		}
		sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
		t.Logf("local PG17.11 race-build readiness run=%d samples=100 queries_per_request=1 p50=%s p95=%s max=%s; no accounting scans, production latency claim or startup distribution", run, samples[49], samples[94], samples[99])
	}
}
