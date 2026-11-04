//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/receipt"
	"backend/internal/tab"
	"backend/migrations"
	"bytes"
	"context"
	"mime/multipart"
	"net/http/httptest"
	"testing"
)

func TestOCRAdmissionHasNoDatabaseStatements(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "synthetic-local-fixture")
	t.Setenv("OCR_MAX_INFLIGHT", "")
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	q := &currencyQueryCount{}
	db := currencyPostgres(t, q)
	sql, _ := db.DB()
	state, err := migrations.Run(context.Background(), sql, migrations.Verify)
	if err != nil {
		t.Fatal(err)
	}
	svc, err := receipt.NewService()
	if err != nil {
		t.Fatal(err)
	}
	h := receipt.NewHandler(svc)
	defer h.Close()
	b, c := newCurrencyHandlers(bill.NewBillRepository(db), exchange.NewClient("http://127.0.0.1:1"))
	router, err := newRouter(b, c, tab.NewTabHandler(tab.NewTabService(tab.NewTabRepository(db))), h, state)
	if err != nil {
		t.Fatal(err)
	}
	// Intentionally invalid synthetic uploads must never reach the real fixed provider.
	// No valid image is sent from this composition test; wire-success is tested with
	// the receipt package's private owned TLS seam.
	for _, kind := range []string{"missing", "mime", "oversize", "quota"} {
		t.Run(kind, func(t *testing.T) {
			repeats := 1
			if kind == "quota" {
				repeats = 11
			}
			for i := 0; i < repeats; i++ {
				var body bytes.Buffer
				mw := multipart.NewWriter(&body)
				if kind == "mime" {
					p, _ := mw.CreateFormFile("image", "fixture.txt")
					_, _ = p.Write([]byte("synthetic unsupported image"))
				}
				_ = mw.Close()
				req := httptest.NewRequest("POST", "/api/receipts/parse", &body)
				req.Header.Set("Content-Type", mw.FormDataContentType())
				req.RemoteAddr = "192.0.2.10:1234"
				if kind == "oversize" {
					req.ContentLength = (10 << 20) + 1
				}
				out := httptest.NewRecorder()
				q.data.Store(0)
				q.control.Store(0)
				q.enabled.Store(true)
				router.ServeHTTP(out, req)
				q.enabled.Store(false)
				if out.Code != 400 && out.Code != 413 && out.Code != 429 {
					t.Fatalf("unexpected rejection=%d", out.Code)
				}
				if q.data.Load() != 0 || q.control.Load() != 0 {
					t.Fatal("OCR used database")
				}
			}
		})
	}
	t.Run("health_one_query", func(t *testing.T) {
		q.data.Store(0)
		q.control.Store(0)
		q.enabled.Store(true)
		out := httptest.NewRecorder()
		router.ServeHTTP(out, httptest.NewRequest("GET", "/health", nil))
		q.enabled.Store(false)
		if out.Code != 200 || q.data.Load() != 1 || q.control.Load() != 0 {
			t.Fatalf("health=%d data=%d control=%d", out.Code, q.data.Load(), q.control.Load())
		}
	})
}
