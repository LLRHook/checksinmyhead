package bill

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"backend/pkg/models"
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

func TestUpdateLazyItemAssignmentsRequiresLazyBillAndValidToken(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	handler := NewBillHandler(NewBillService(repo))
	router := gin.New()
	router.POST("/api/bills", handler.CreateBill)
	router.PATCH("/api/bills/:id/items/:itemId/assignments", handler.UpdateLazyItemAssignments)

	create := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/bills", bytes.NewBufferString(`{"name":"Cafe","total":20,"lazy_mode":true}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(create, request)
	if create.Code != http.StatusCreated {
		t.Fatalf("expected bill creation, got %d: %s", create.Code, create.Body.String())
	}
	var created map[string]any
	if err := json.Unmarshal(create.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	id := int(created["bill_id"].(float64))
	token := created["access_token"].(string)

	patchReq := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/bills/%d/items/7/assignments", id), bytes.NewBufferString(`{"assignments":[{"person_name":"Alex","percentage":100}]}`))
	patchReq.Header.Set("Content-Type", "application/json")
	patchReq.Header.Set("Authorization", "Bearer "+token)
	patchRes := httptest.NewRecorder()
	router.ServeHTTP(patchRes, patchReq)
	if patchRes.Code != http.StatusOK {
		t.Fatalf("expected assignment success, got %d: %s", patchRes.Code, patchRes.Body.String())
	}
	if repo.updatedBillID != uint(id) || repo.updatedItemID != 7 || len(repo.updatedItems) != 1 || repo.updatedItems[0].PersonName != "Alex" {
		t.Fatalf("unexpected assignment write: %#v", repo.updatedItems)
	}

	invalidReq := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/bills/%d/items/7/assignments", id), bytes.NewBufferString(`{"assignments":[{"person_name":"Alex","percentage":75}]}`))
	invalidReq.Header.Set("Content-Type", "application/json")
	invalidReq.Header.Set("Authorization", "Bearer "+token)
	invalidRes := httptest.NewRecorder()
	router.ServeHTTP(invalidRes, invalidReq)
	if invalidRes.Code != http.StatusBadRequest {
		t.Fatalf("expected invalid split to be rejected, got %d", invalidRes.Code)
	}

	unauthorizedReq := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/bills/%d/items/7/assignments", id), bytes.NewBufferString(`{"assignments":[]}`))
	unauthorizedReq.Header.Set("Content-Type", "application/json")
	unauthorizedRes := httptest.NewRecorder()
	router.ServeHTTP(unauthorizedRes, unauthorizedReq)
	if unauthorizedRes.Code != http.StatusForbidden {
		t.Fatalf("expected invalid token rejection, got %d", unauthorizedRes.Code)
	}
}

func TestUpdateLazyItemAssignmentsRejectsNonLazyBill(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	handler := NewBillHandler(NewBillService(repo))
	router := gin.New()
	router.POST("/api/bills", handler.CreateBill)
	router.PATCH("/api/bills/:id/items/:itemId/assignments", handler.UpdateLazyItemAssignments)

	create := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/bills", bytes.NewBufferString(`{"name":"Cafe","total":20}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(create, request)
	var created map[string]any
	if err := json.Unmarshal(create.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	patchReq := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/bills/%v/items/7/assignments", created["bill_id"]), bytes.NewBufferString(`{"assignments":[]}`))
	patchReq.Header.Set("Content-Type", "application/json")
	patchReq.Header.Set("Authorization", "Bearer "+created["access_token"].(string))
	patchRes := httptest.NewRecorder()
	router.ServeHTTP(patchRes, patchReq)
	if patchRes.Code != http.StatusBadRequest {
		t.Fatalf("expected non-lazy bill rejection, got %d", patchRes.Code)
	}
}

func TestUpdateLazyItemAssignmentsBatchValidatesAndReturnsBill(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	repo.bills[33] = &models.Bill{
		ID:          33,
		LazyMode:    true,
		AccessToken: "secret",
		Name:        "Dinner",
	}
	handler := NewBillHandler(NewBillService(repo))
	router := gin.New()
	router.PATCH("/api/bills/:id/assignments", handler.UpdateLazyItemAssignmentsBatch)
	request := httptest.NewRequest(http.MethodPatch, "/api/bills/33/assignments", bytes.NewBufferString(`{"updates":[{"item_id":8,"expected_updated_at":"2026-10-12T20:00:00Z","assignments":[{"person_name":"Alex","percentage":100}]},{"item_id":9,"expected_updated_at":"2026-10-12T20:00:00Z","assignments":[{"person_name":"Alex","percentage":100}]}]}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer secret")
	response := httptest.NewRecorder()
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("expected batch success, got %d: %s", response.Code, response.Body.String())
	}
	if len(repo.updatedBatch) != 2 || repo.updatedBatch[0].ItemID != 8 || repo.updatedBatch[1].ItemID != 9 {
		t.Fatalf("unexpected batch updates: %#v", repo.updatedBatch)
	}
	if strings.Contains(response.Body.String(), "secret") {
		t.Fatal("batch response exposed the bill access token")
	}

	// The mock returns the stored pointer; a real GetBill call loads a fresh row.
	repo.bills[33].AccessToken = "secret"
	duplicate := httptest.NewRequest(http.MethodPatch, "/api/bills/33/assignments", bytes.NewBufferString(`{"updates":[{"item_id":8,"assignments":[]},{"item_id":8,"assignments":[]}]}`))
	duplicate.Header.Set("Content-Type", "application/json")
	duplicate.Header.Set("Authorization", "Bearer secret")
	duplicateResponse := httptest.NewRecorder()
	router.ServeHTTP(duplicateResponse, duplicate)
	if duplicateResponse.Code != http.StatusBadRequest {
		t.Fatalf("expected duplicate item update rejection, got %d", duplicateResponse.Code)
	}
}

func TestTripTokenCanOpenAttachedBillReadOnly(t *testing.T) {
	gin.SetMode(gin.TestMode)
	repo := newMockRepo()
	tabID := uint(19)
	repo.bills[27] = &models.Bill{
		ID:          27,
		TabID:       &tabID,
		AccessToken: "bill-secret",
		Tab:         &models.Tab{AccessToken: "trip-secret"},
		PersonShares: []models.PersonShare{{
			ID:         159,
			BillID:     27,
			PersonName: "Alex",
		}},
	}
	handler := NewBillHandler(NewBillService(repo))
	router := gin.New()
	router.GET("/api/bills/:id", handler.GetBill)
	router.PATCH("/api/bills/:id/shares/:shareId", handler.UpdatePersonSharePaid)

	getReq := httptest.NewRequest(http.MethodGet, "/api/bills/27", nil)
	getReq.Header.Set("Authorization", "Bearer trip-secret")
	getRes := httptest.NewRecorder()
	router.ServeHTTP(getRes, getReq)
	if getRes.Code != http.StatusOK {
		t.Fatalf("expected trip token bill view, got %d: %s", getRes.Code, getRes.Body.String())
	}
	if strings.Contains(getRes.Body.String(), "bill-secret") {
		t.Fatal("bill access token was exposed in bill response")
	}

	patchReq := httptest.NewRequest(http.MethodPatch, "/api/bills/27/shares/159", bytes.NewBufferString(`{"paid":true}`))
	patchReq.Header.Set("Content-Type", "application/json")
	patchReq.Header.Set("Authorization", "Bearer trip-secret")
	patchRes := httptest.NewRecorder()
	router.ServeHTTP(patchRes, patchReq)
	if patchRes.Code != http.StatusForbidden {
		t.Fatalf("expected trip token to be read-only, got %d", patchRes.Code)
	}
}
