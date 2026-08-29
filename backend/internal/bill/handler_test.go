package bill

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestCreateBill_ReturnsExplicitUnavailableAndDoesNotPersist(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	handler := NewBillHandler(NewBillService(repo, &fakeExchangeRateProvider{err: errors.New("offline")}))
	router := gin.New()
	router.POST("/api/bills", handler.CreateBill)

	req := httptest.NewRequest(http.MethodPost, "/api/bills", bytes.NewBufferString(`{"name":"Cafe","total":100,"currency_code":"EUR"}`))
	req.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, req)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d: %s", response.Code, response.Body.String())
	}
	if len(repo.bills) != 0 {
		t.Fatal("bill was persisted despite unavailable conversion")
	}
}

func TestCreateBill_ReturnsAuthoritativeUSDAudit(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	handler := NewBillHandler(NewBillService(repo))
	router := gin.New()
	router.POST("/api/bills", handler.CreateBill)

	req := httptest.NewRequest(http.MethodPost, "/api/bills", bytes.NewBufferString(`{"name":"Cafe","total":42.37}`))
	req.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, req)

	if response.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", response.Code, response.Body.String())
	}
	var body map[string]any
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["currency_code"] != "USD" || body["usd_exchange_rate"] != float64(1) || body["usd_total"] != 42.37 {
		t.Fatalf("unexpected audit response: %#v", body)
	}
}

func TestGetExchangeRate_RejectsUnsupportedCurrencyBeforeProvider(t *testing.T) {
	gin.SetMode(gin.TestMode)
	provider := &fakeExchangeRateProvider{}
	handler := NewBillHandler(NewBillService(newMockRepo(), provider))
	router := gin.New()
	router.GET("/api/exchange-rates/:currency", handler.GetExchangeRate)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/exchange-rates/ZZZ", nil))

	if response.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", response.Code, response.Body.String())
	}
	if provider.calls != 0 {
		t.Fatalf("unsupported currency reached provider %d time(s)", provider.calls)
	}
}
