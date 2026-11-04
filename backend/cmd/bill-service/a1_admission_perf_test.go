//go:build a1perf

package main

import (
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"github.com/gin-gonic/gin"
	"io"
	"log"
	"net/http/httptest"
	"os"
	"sort"
	"strings"
	"testing"
	"time"
)

func TestA1AdmissionMeasurements(t *testing.T) {
	gin.SetMode(gin.TestMode)
	gw, lw := gin.DefaultWriter, log.Writer()
	gin.DefaultWriter = io.Discard
	log.SetOutput(io.Discard)
	defer func() { gin.DefaultWriter = gw; log.SetOutput(lw) }()
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	entered := make(chan struct{}, 8)
	tabs := &a1Tabs{create: func(ctx context.Context, _ *models.Tab, _ string) (*models.TabMember, error) {
		entered <- struct{}{}
		<-ctx.Done()
		return nil, ctx.Err()
	}}
	b, c := newCurrencyHandlers(&compositionRepo{}, exchange.NewClient("http://127.0.0.1:1"))
	r, err := newRouter(b, c, tab.NewTabHandler(tabs), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	start := func(ctx context.Context) <-chan struct{} {
		done := make(chan struct{})
		go func() {
			defer close(done)
			req := httptest.NewRequest("POST", "/api/tabs", strings.NewReader(`{}`)).WithContext(ctx)
			r.ServeHTTP(httptest.NewRecorder(), req)
		}()
		select {
		case <-entered:
		case <-time.After(time.Second):
			t.Fatal("measurement entry missing")
		}
		return done
	}
	summarize := func(samples []int64, target time.Duration) map[string]any {
		sorted := append([]int64(nil), samples...)
		sort.Slice(sorted, func(a, b int) bool { return sorted[a] < sorted[b] })
		return map[string]any{"samples_ns": samples, "median_ns": sorted[49], "p95_ns": sorted[94], "max_ns": sorted[99], "target_ns": int64(target), "target_met": sorted[99] <= int64(target)}
	}
	var results []any
	for run := 1; run <= 3; run++ {
		ctx, cancel := context.WithCancel(context.Background())
		var held []<-chan struct{}
		for i := 0; i < 8; i++ {
			held = append(held, start(ctx))
		}
		samples := make([]int64, 100)
		for j := range samples {
			req := httptest.NewRequest("POST", "/api/tabs", strings.NewReader(`{}`))
			req.Header.Set("Content-Type", "text/plain")
			w := httptest.NewRecorder()
			stamp := time.Now()
			r.ServeHTTP(w, req)
			samples[j] = time.Since(stamp).Nanoseconds()
			if w.Code != 503 || w.Header().Get("Retry-After") != "1" {
				cancel()
				t.Fatalf("saturation=%d", w.Code)
			}
		}
		cancel()
		for _, done := range held {
			select {
			case <-done:
			case <-time.After(time.Second):
				t.Fatal("held cleanup failed")
			}
		}
		results = append(results, map[string]any{"run": run, "path": "saturated_admission", "result": summarize(samples, 5*time.Millisecond)})
		samples = make([]int64, 100)
		for j := range samples {
			ctx, cancel := context.WithCancel(context.Background())
			done := start(ctx)
			stamp := time.Now()
			cancel()
			select {
			case <-done:
				samples[j] = time.Since(stamp).Nanoseconds()
			case <-time.After(time.Second):
				t.Fatal("cancel failed to release")
			}
		}
		results = append(results, map[string]any{"run": run, "path": "observed_cancel_to_handler_and_gate_release", "result": summarize(samples, 250*time.Millisecond)})
	}
	output := os.Getenv("A1_ADMISSION_MEASURE_OUTPUT")
	if output == "" {
		t.Fatal("A1_ADMISSION_MEASURE_OUTPUT required")
	}
	data, _ := json.MarshalIndent(map[string]any{"warmup": "eight admitted requests establish saturation before sampling; each cancellation sampled only after handler entry", "runs": results, "provider_calls": 0, "SQL_queries": 0}, "", "  ")
	if err := os.WriteFile(output, data, 0600); err != nil {
		t.Fatal(err)
	}
}
