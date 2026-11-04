//go:build a1perf

package main

import (
	"backend/internal/bill"
	"backend/internal/currency"
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
	"runtime"
	"sort"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"
)

type a1MeasureBill struct {
	bill.BillService
	hold func(bill.ClaimCommand)
}

func (s a1MeasureBill) CreateBill(_ context.Context, c bill.CreateBillCommand) (bill.CreateBillResult, error) {
	return bill.CreateBillResult{BillID: 1}, nil
}
func (s a1MeasureBill) GetBill(uint) (*models.Bill, error) { return &models.Bill{ID: 1}, nil }
func (s a1MeasureBill) UpdateItemAssignmentsBatch(_ context.Context, c bill.ClaimCommand) error {
	if s.hold != nil {
		s.hold(c)
	}
	return nil
}
func TestA1JSONMeasurements(t *testing.T) {
	gin.SetMode(gin.TestMode)
	gw, lw := gin.DefaultWriter, log.Writer()
	gin.DefaultWriter = io.Discard
	log.SetOutput(io.Discard)
	defer func() { gin.DefaultWriter = gw; log.SetOutput(lw) }()
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	tabs := &a1Tabs{}
	var hold func(bill.ClaimCommand)
	service := a1MeasureBill{hold: func(c bill.ClaimCommand) {
		if hold != nil {
			hold(c)
		}
	}}
	r, err := newRouter(bill.NewBillHandler(service), currency.NewHandler(exchange.NewClient("http://127.0.0.1:1")), tab.NewTabHandler(tabs), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	var updates []any
	for i := 1; i <= 500; i++ {
		var as []any
		for j := 0; j < 100; j++ {
			as = append(as, map[string]any{"person_name": strings.Repeat("a", 20) + string(rune('A'+j/26)) + string(rune('A'+j%26)), "percentage": 1})
		}
		updates = append(updates, map[string]any{"item_id": i, "assignments": as})
	}
	maxBatch, _ := json.Marshal(map[string]any{"updates": updates})
	updates = nil
	var items []any
	for i := 0; i < 500; i++ {
		var as []any
		for j := 0; j < 10; j++ {
			as = append(as, map[string]any{"person_name": string(rune('A' + j)), "percentage": 10})
		}
		items = append(items, map[string]any{"name": "Item", "price": 1, "assignments": as})
	}
	maxCreate, _ := json.Marshal(map[string]any{"name": "Max", "subtotal": 500, "total": 500, "items": items})
	items = nil
	paths := []struct {
		name, path, method, body string
		status                   int
		stream                   bool
	}{
		{"normal_tab", "/api/tabs", "POST", `{"name":"Trip","creator_display_name":"Alex"}`, 201, false},
		{"max_tab_bytes", "/api/tabs", "POST", `{}` + strings.Repeat(" ", (16<<10)-2), 201, false},
		{"max_creation_5000", "/api/bills", "POST", string(maxCreate), 201, false},
		{"max_mutation_50000", "/api/bills/1/assignments", "PATCH", string(maxBatch), 200, false},
		{"reject_tab_bytes_known", "/api/tabs", "POST", `{}` + strings.Repeat(" ", (16<<10)-1), 413, false},
		{"reject_tab_bytes_streamed", "/api/tabs", "POST", `{}` + strings.Repeat(" ", (16<<10)-1), 413, true},
		{"reject_creation_minimal_array", "/api/bills", "POST", `{"name":"X","subtotal":0,"total":0,"items":[` + strings.Repeat(`null,`, 9999) + `null]}`, 400, false},
		{"reject_mutation_minimal_array", "/api/bills/1/assignments", "PATCH", `{"updates":[` + strings.Repeat(`{},`, 59999) + `{}]}`, 400, false},
		{"reject_syntax", "/api/tabs", "POST", `!`, 400, false},
	}
	do := func(p int) {
		v := paths[p]
		req := httptest.NewRequest(v.method, v.path, strings.NewReader(v.body))
		if v.stream {
			req.ContentLength = -1
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code != v.status {
			t.Fatalf("measurement path=%s status=%d", v.name, w.Code)
		}
	}
	for i := range paths {
		for j := 0; j < 10; j++ {
			do(i)
		}
	}
	runtime.GC()
	runtime.GC()
	var baseline runtime.MemStats
	runtime.ReadMemStats(&baseline)
	goroutines := runtime.NumGoroutine()
	result := map[string]any{"runtime": runtime.Version(), "goos": runtime.GOOS, "goarch": runtime.GOARCH, "cpu": runtime.NumCPU(), "gomaxprocs": runtime.GOMAXPROCS(0), "warmup_samples_per_path": 10, "provider_calls": 0, "SQL_queries": 0, "scope": "production router + decoder/DTO transformation; injected services exclude business/database I/O, no response caching"}
	var runs []any
	for run := 1; run <= 3; run++ {
		for i, v := range paths {
			var before, after runtime.MemStats
			runtime.ReadMemStats(&before)
			samples := make([]int64, 100)
			for j := range samples {
				start := time.Now()
				do(i)
				samples[j] = time.Since(start).Nanoseconds()
			}
			runtime.ReadMemStats(&after)
			ordered := append([]int64(nil), samples...)
			sort.Slice(ordered, func(a, b int) bool { return ordered[a] < ordered[b] })
			target := int64(10 * time.Millisecond)
			if strings.HasPrefix(v.name, "reject") {
				target = int64(5 * time.Millisecond)
			}
			runs = append(runs, map[string]any{"run": run, "path": v.name, "body_bytes": len(v.body), "samples_ns": samples, "median_ns": ordered[49], "p95_ns": ordered[94], "max_ns": ordered[99], "allocated_bytes": after.TotalAlloc - before.TotalAlloc, "allocations": after.Mallocs - before.Mallocs, "p95_target_ns": target, "p95_target_met": ordered[94] < target})
		}
	}
	result["runs"] = runs
	entered, release := make(chan struct{}, 8), make(chan struct{})
	hold = func(c bill.ClaimCommand) { entered <- struct{}{}; <-release; runtime.KeepAlive(c) }
	runtime.GC()
	runtime.GC()
	var before, peak runtime.MemStats
	runtime.ReadMemStats(&before)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); do(3) }()
	}
	for i := 0; i < 8; i++ {
		select {
		case <-entered:
		case <-time.After(10 * time.Second):
			t.Fatal("burst did not admit eight")
		}
	}
	runtime.ReadMemStats(&peak)
	var usage syscall.Rusage
	syscall.Getrusage(syscall.RUSAGE_SELF, &usage)
	rss := usage.Maxrss
	if runtime.GOOS != "darwin" {
		rss *= 1024
	}
	result["burst"] = map[string]any{"slots": 8, "path": "max_mutation_50000", "heap_increment_bytes": int64(peak.HeapAlloc) - int64(before.HeapAlloc), "heap_sys_increment_bytes": int64(peak.HeapSys) - int64(before.HeapSys), "process_peak_RSS_bytes": rss, "allocated_bytes": peak.TotalAlloc - before.TotalAlloc, "target_bytes": 256 << 20, "target_met": int64(peak.HeapAlloc)-int64(before.HeapAlloc) <= 256<<20}
	close(release)
	wg.Wait()
	hold = nil
	runtime.GC()
	runtime.GC()
	<-time.After(75 * time.Second)
	runtime.GC()
	runtime.GC()
	var retained runtime.MemStats
	runtime.ReadMemStats(&retained)
	result["retention"] = map[string]any{"idle_seconds": 75, "GC_before_and_after": 2, "heap_increment_bytes": int64(retained.HeapAlloc) - int64(baseline.HeapAlloc), "goroutines_before": goroutines, "goroutines_after": runtime.NumGoroutine(), "target_bytes": 4 << 20, "target_met": int64(retained.HeapAlloc)-int64(baseline.HeapAlloc) <= 4<<20}
	output := os.Getenv("A1_MEASURE_OUTPUT")
	if output == "" {
		t.Fatal("A1_MEASURE_OUTPUT required")
	}
	data, _ := json.MarshalIndent(result, "", "  ")
	if err := os.WriteFile(output, data, 0600); err != nil {
		t.Fatal(err)
	}
}
