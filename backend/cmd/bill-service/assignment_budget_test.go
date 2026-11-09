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
	"net/http"
	"net/http/httptest"
	"runtime"
	"strings"
	"testing"
)

type assignmentBudgetBills struct {
	bill.BillService
	assignments int
}

func (s *assignmentBudgetBills) UpdateItemAssignmentsBatch(_ context.Context, c bill.ClaimCommand) error {
	s.assignments = 0
	for _, u := range c.Updates {
		s.assignments += len(u.Assignments)
	}
	return nil
}
func (*assignmentBudgetBills) GetBill(uint) (*models.Bill, error) { return &models.Bill{ID: 1}, nil }

// maxAssignmentUpdateBody is the same 2,815,905-byte body as the a1perf
// max_mutation_50000 path: 500 updates of 100 assignments, 22-byte names.
func maxAssignmentUpdateBody() string {
	var updates []any
	for i := 1; i <= 500; i++ {
		var as []any
		for j := 0; j < 100; j++ {
			as = append(as, map[string]any{"person_name": strings.Repeat("a", 20) + string(rune('A'+j/26)) + string(rune('A'+j%26)), "percentage": 1})
		}
		updates = append(updates, map[string]any{"item_id": i, "assignments": as})
	}
	body, _ := json.Marshal(map[string]any{"updates": updates})
	return string(body)
}
func assignmentBudgetRouter(tb testing.TB) (http.Handler, *assignmentBudgetBills) {
	tb.Helper()
	oldMode, gw, lw := gin.Mode(), gin.DefaultWriter, log.Writer()
	gin.SetMode(gin.TestMode)
	gin.DefaultWriter = io.Discard
	log.SetOutput(io.Discard)
	tb.Cleanup(func() { gin.SetMode(oldMode); gin.DefaultWriter = gw; log.SetOutput(lw) })
	tb.Setenv("TRUSTED_PROXY_CIDRS", "")
	bills := &assignmentBudgetBills{}
	r, err := newRouter(bill.NewBillHandler(bills), currency.NewHandler(exchange.NewClient("http://127.0.0.1:1")), tab.NewTabHandler(&jsonContractTabs{}), nil, nil)
	if err != nil {
		tb.Fatal(err)
	}
	return r, bills
}

// BenchmarkMaxAssignmentUpdate times the production router, decoder and DTO
// transformation for the largest admitted update; the service is injected.
// The a1perf harness remains the acceptance measurement for the 10 ms p95 target.
func BenchmarkMaxAssignmentUpdate(b *testing.B) {
	r, bills := assignmentBudgetRouter(b)
	body := maxAssignmentUpdateBody()
	b.SetBytes(int64(len(body)))
	b.ReportAllocs()
	for b.Loop() {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("PATCH", "/api/bills/1/assignments", strings.NewReader(body)))
		if w.Code != 200 || bills.assignments != 50000 {
			b.Fatalf("status=%d assignments=%d", w.Code, bills.assignments)
		}
	}
}

// TestMaxAssignmentUpdateAllocationBudget is the deterministic regression guard
// for the bounded update decode. Wall time is measured by the a1perf harness;
// bytes and allocations per request do not depend on machine load. The budgets
// hold only while the body is decoded in one bounded streaming pass and the
// command slices are sized once: a whole-document buffer, a second typed decode
// or growth by append each exceed them.
func TestMaxAssignmentUpdateAllocationBudget(t *testing.T) {
	r, bills := assignmentBudgetRouter(t)
	body := maxAssignmentUpdateBody()
	if len(body) != 2815905 {
		t.Fatalf("body bytes=%d", len(body))
	}
	do := func() {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("PATCH", "/api/bills/1/assignments", strings.NewReader(body)))
		if w.Code != 200 || bills.assignments != 50000 {
			t.Fatalf("status=%d assignments=%d", w.Code, bills.assignments)
		}
	}
	for i := 0; i < 3; i++ {
		do()
	}
	const runs = 10
	var before, after runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&before)
	for i := 0; i < runs; i++ {
		do()
	}
	runtime.ReadMemStats(&after)
	bytes, allocations := (after.TotalAlloc-before.TotalAlloc)/runs, (after.Mallocs-before.Mallocs)/runs
	t.Logf("bytes/request=%d allocations/request=%d", bytes, allocations)
	if bytes > maxAssignmentUpdateBytes || allocations > maxAssignmentUpdateAllocations {
		t.Fatalf("bytes/request=%d (budget %d) allocations/request=%d (budget %d)", bytes, maxAssignmentUpdateBytes, allocations, maxAssignmentUpdateAllocations)
	}
}

const (
	maxAssignmentUpdateBytes       = 12 << 20
	maxAssignmentUpdateAllocations = 4000
)
