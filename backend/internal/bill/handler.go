package bill

import (
	"backend/internal/currency"
	"backend/pkg/config"
	"backend/pkg/models"
	"backend/pkg/safehttp"
	"backend/pkg/security"
	"crypto/subtle"
	"errors"
	"fmt"
	"log"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type BillHandler struct {
	service BillService
	rates   *currency.Service
}

func NewBillHandler(service BillService, rates ...*currency.Service) *BillHandler {
	var rateService *currency.Service
	if len(rates) > 0 {
		rateService = rates[0]
	}
	return &BillHandler{service: service, rates: rateService}
}

func (h *BillHandler) CreateBill(c *gin.Context) {
	var bill models.Bill

	if err := c.ShouldBindJSON(&bill); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	// Sanitize user-provided strings
	bill.Name = security.SanitizeString(bill.Name)
	if bill.CurrencyCode == "" {
		bill.CurrencyCode = "USD"
	}
	if bill.DisplayCurrency == "" {
		bill.DisplayCurrency = bill.CurrencyCode
	}
	if bill.CurrencyCode != bill.DisplayCurrency {
		if h.rates == nil {
			c.JSON(503, gin.H{"error": "currency conversion is temporarily unavailable"})
			return
		}
		rate, err := h.rates.GetRate(bill.CurrencyCode, bill.DisplayCurrency)
		if err != nil {
			c.JSON(503, gin.H{"error": "currency conversion is temporarily unavailable"})
			return
		}
		displayTotal := bill.Total * rate.Value
		bill.DisplayTotal = &displayTotal
		bill.ExchangeRate = &rate.Value
		bill.ExchangeRateSource = rate.Source
		bill.ExchangeRateDate = rate.UpdatedAt.Format(time.DateOnly)
	} else {
		displayTotal := bill.Total
		bill.DisplayTotal = &displayTotal
	}
	for i := range bill.Items {
		bill.Items[i].Name = security.SanitizeString(bill.Items[i].Name)
	}
	for i := range bill.PersonShares {
		bill.PersonShares[i].PersonName = security.SanitizeString(bill.PersonShares[i].PersonName)
	}

	token, err := security.GenerateSecureToken()
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	bill.AccessToken = token
	err = h.service.CreateBill(c.Request.Context(), &bill)

	if err != nil {
		if errors.Is(err, ErrInvalidCurrency) {
			c.JSON(400, gin.H{"error": "unsupported currency code"})
			return
		}
		if errors.Is(err, ErrExchangeRateUnavailable) {
			c.JSON(503, gin.H{"error": "daily exchange rate is unavailable; retry or use USD"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(201, gin.H{
		"bill_id":              bill.ID,
		"access_token":         token,
		"share_url":            fmt.Sprintf("%s/b/%d?t=%s", config.AppDomain(), bill.ID, token),
		"currency_code":        bill.CurrencyCode,
		"usd_exchange_rate":    bill.USDExchangeRate,
		"exchange_rate_date":   bill.ExchangeRateDate,
		"exchange_rate_source": bill.ExchangeRateSource,
		"usd_total":            bill.USDTotal,
	})
}

func (h *BillHandler) GetExchangeRate(c *gin.Context) {
	quote, err := h.service.GetUSDExchangeRate(c.Request.Context(), c.Param("currency"))
	if err != nil {
		if errors.Is(err, ErrInvalidCurrency) {
			c.JSON(400, gin.H{"error": "unsupported currency code"})
			return
		}
		c.JSON(503, gin.H{"error": "daily exchange rate is unavailable; retry or use USD"})
		return
	}
	c.JSON(200, quote)
}

// getBillAndValidate parses the ID, fetches the bill, and validates the token.
// Returns the bill on success or writes an error and returns nil.
func (h *BillHandler) getBillAndValidate(c *gin.Context) *models.Bill {
	id := c.Param("id")

	token := safehttp.AccessToken(c)

	if id == "" {
		c.JSON(400, gin.H{"error": "bad id"})
		return nil
	}

	idUint, err := strconv.ParseUint(id, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid id format"})
		return nil
	}

	bill, err := h.service.GetBill(uint(idUint))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill not found"})
			return nil
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return nil
	}
	validBillToken := token != "" && subtle.ConstantTimeCompare([]byte(token), []byte(bill.AccessToken)) == 1
	validTabToken := token != "" && bill.Tab != nil && subtle.ConstantTimeCompare([]byte(token), []byte(bill.Tab.AccessToken)) == 1
	if !validBillToken && !validTabToken {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}

	return bill
}

func requireBillToken(c *gin.Context, bill *models.Bill) bool {
	token := safehttp.AccessToken(c)
	if token != "" && subtle.ConstantTimeCompare([]byte(token), []byte(bill.AccessToken)) == 1 {
		return true
	}
	c.JSON(403, gin.H{"error": "bill token required for this action"})
	return false
}

func (h *BillHandler) GetBill(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}

	bill.AccessToken = ""
	c.JSON(200, bill)
}

func (h *BillHandler) UpdateLazyItemAssignments(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}
	if !requireBillToken(c, bill) {
		return
	}
	if !bill.LazyMode || bill.TabID != nil {
		c.JSON(400, gin.H{"error": "item claiming is only available on standalone lazy bills"})
		return
	}
	itemID, err := strconv.ParseUint(c.Param("itemId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid item id"})
		return
	}
	var body struct {
		ExpectedUpdatedAt *string `json:"expected_updated_at"`
		Assignments       []struct {
			PersonName string  `json:"person_name"`
			Percentage float64 `json:"percentage"`
		} `json:"assignments"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Assignments == nil {
		c.JSON(400, gin.H{"error": "assignments are required"})
		return
	}

	assignments := make([]models.ItemAssignment, 0, len(body.Assignments))
	seen := make(map[string]struct{}, len(body.Assignments))
	totalPercentage := 0.0
	for _, assignment := range body.Assignments {
		name := security.SanitizeString(assignment.PersonName)
		key := strings.ToLower(name)
		if name == "" || len([]rune(name)) > 30 || assignment.Percentage <= 0 || assignment.Percentage > 100 || math.IsNaN(assignment.Percentage) || math.IsInf(assignment.Percentage, 0) {
			c.JSON(400, gin.H{"error": "invalid item assignment"})
			return
		}
		if _, exists := seen[key]; exists {
			c.JSON(400, gin.H{"error": "duplicate person assignment"})
			return
		}
		seen[key] = struct{}{}
		totalPercentage += assignment.Percentage
		assignments = append(assignments, models.ItemAssignment{PersonName: name, Percentage: assignment.Percentage})
	}
	if totalPercentage > 100.01 {
		c.JSON(400, gin.H{"error": "item assignments cannot exceed 100 percent"})
		return
	}

	var expectedUpdatedAt *time.Time
	if body.ExpectedUpdatedAt != nil && *body.ExpectedUpdatedAt != "" {
		parsed, parseErr := time.Parse(time.RFC3339Nano, *body.ExpectedUpdatedAt)
		if parseErr != nil {
			c.JSON(400, gin.H{"error": "invalid expected_updated_at"})
			return
		}
		expectedUpdatedAt = &parsed
	}
	if err := h.service.UpdateItemAssignments(bill.ID, uint(itemID), assignments, expectedUpdatedAt); err != nil {
		switch {
		case errors.Is(err, ErrAssignmentConflict):
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
		case errors.Is(err, ErrItemAlreadyPaid):
			c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
		case errors.Is(err, gorm.ErrRecordNotFound):
			c.JSON(404, gin.H{"error": "bill item not found"})
		default:
			log.Printf("internal error: %v", err)
			c.JSON(500, gin.H{"error": "an internal error occurred"})
		}
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

func (h *BillHandler) UpdateLazyItemAssignmentsBatch(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}
	if !requireBillToken(c, bill) {
		return
	}
	if !bill.LazyMode || bill.TabID != nil {
		c.JSON(400, gin.H{"error": "item claiming is only available on standalone lazy bills"})
		return
	}

	var body struct {
		Updates []struct {
			ItemID            uint    `json:"item_id"`
			ExpectedUpdatedAt *string `json:"expected_updated_at"`
			Assignments       []struct {
				PersonName string  `json:"person_name"`
				Percentage float64 `json:"percentage"`
			} `json:"assignments"`
		} `json:"updates"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body.Updates) == 0 {
		c.JSON(400, gin.H{"error": "item updates are required"})
		return
	}

	updates := make([]ItemAssignmentsUpdate, 0, len(body.Updates))
	seenItems := make(map[uint]struct{}, len(body.Updates))
	for _, itemUpdate := range body.Updates {
		if itemUpdate.ItemID == 0 {
			c.JSON(400, gin.H{"error": "invalid item id"})
			return
		}
		if _, exists := seenItems[itemUpdate.ItemID]; exists {
			c.JSON(400, gin.H{"error": "duplicate item update"})
			return
		}
		seenItems[itemUpdate.ItemID] = struct{}{}
		if itemUpdate.Assignments == nil {
			c.JSON(400, gin.H{"error": "assignments are required"})
			return
		}

		assignments := make([]models.ItemAssignment, 0, len(itemUpdate.Assignments))
		seenPeople := make(map[string]struct{}, len(itemUpdate.Assignments))
		totalPercentage := 0.0
		for _, assignment := range itemUpdate.Assignments {
			name := security.SanitizeString(assignment.PersonName)
			key := strings.ToLower(name)
			if name == "" || len([]rune(name)) > 30 || assignment.Percentage <= 0 || assignment.Percentage > 100 || math.IsNaN(assignment.Percentage) || math.IsInf(assignment.Percentage, 0) {
				c.JSON(400, gin.H{"error": "invalid item assignment"})
				return
			}
			if _, exists := seenPeople[key]; exists {
				c.JSON(400, gin.H{"error": "duplicate person assignment"})
				return
			}
			seenPeople[key] = struct{}{}
			totalPercentage += assignment.Percentage
			assignments = append(assignments, models.ItemAssignment{PersonName: name, Percentage: assignment.Percentage})
		}
		if totalPercentage > 100.01 {
			c.JSON(400, gin.H{"error": "item assignments cannot exceed 100 percent"})
			return
		}

		var expectedUpdatedAt *time.Time
		if itemUpdate.ExpectedUpdatedAt != nil && *itemUpdate.ExpectedUpdatedAt != "" {
			parsed, err := time.Parse(time.RFC3339Nano, *itemUpdate.ExpectedUpdatedAt)
			if err != nil {
				c.JSON(400, gin.H{"error": "invalid expected_updated_at"})
				return
			}
			expectedUpdatedAt = &parsed
		}
		updates = append(updates, ItemAssignmentsUpdate{
			ItemID: itemUpdate.ItemID, Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt,
		})
	}

	if err := h.service.UpdateItemAssignmentsBatch(bill.ID, updates); err != nil {
		switch {
		case errors.Is(err, ErrAssignmentConflict):
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
		case errors.Is(err, ErrItemAlreadyPaid):
			c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
		case errors.Is(err, gorm.ErrRecordNotFound):
			c.JSON(404, gin.H{"error": "bill item not found"})
		default:
			log.Printf("internal error: %v", err)
			c.JSON(500, gin.H{"error": "an internal error occurred"})
		}
		return
	}

	updatedBill, err := h.service.GetBill(bill.ID)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	updatedBill.AccessToken = ""
	c.JSON(200, updatedBill)
}

func (h *BillHandler) UpdatePersonSharePaid(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}
	if !requireBillToken(c, bill) {
		return
	}

	shareID, err := strconv.ParseUint(c.Param("shareId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid share id"})
		return
	}

	// Verify the share belongs to this bill
	var personName string
	for _, s := range bill.PersonShares {
		if s.ID == uint(shareID) {
			personName = s.PersonName
			break
		}
	}
	if personName == "" {
		c.JSON(404, gin.H{"error": "share not found on this bill"})
		return
	}

	var body struct {
		Paid *bool `json:"paid"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}

	if err := h.service.UpdatePersonSharePaid(bill.ID, personName, *body.Paid); err != nil {
		if errors.Is(err, ErrPersonShareNotFound) {
			c.JSON(404, gin.H{"error": "share not found on this bill"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}
