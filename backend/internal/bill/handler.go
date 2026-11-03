package bill

import (
	"backend/internal/currency"
	"backend/pkg/config"
	"backend/pkg/database"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"backend/pkg/security"
	"crypto/subtle"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var errDisplayConversionUnavailable = errors.New("display conversion unavailable")

type displayRateProvider interface {
	GetRate(from, to string) (currency.Rate, error)
}

type BillHandler struct {
	service BillService
	rates   displayRateProvider
}

func NewBillHandler(service BillService, rates ...displayRateProvider) *BillHandler {
	var rateService displayRateProvider
	if len(rates) > 0 {
		rateService = rates[0]
	}
	return &BillHandler{service: service, rates: rateService}
}

func (h *BillHandler) CreateBill(c *gin.Context) {
	bill, err := decodeCreateBill(c.Writer, c.Request)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid bill content"})
		return
	}

	token, err := security.GenerateSecureToken()
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	bill.AccessToken = token
	err = h.service.createBill(c.Request.Context(), bill, h.prepareDisplay)

	if err != nil {
		if errors.Is(err, errDisplayConversionUnavailable) {
			c.JSON(503, gin.H{"error": "currency conversion is temporarily unavailable"})
			return
		}
		if errors.Is(err, ErrInvalidCreation) {
			c.JSON(400, gin.H{"error": "invalid bill content"})
			return
		}
		if errors.Is(err, ErrInvalidCurrency) {
			c.JSON(400, gin.H{"error": "unsupported currency code"})
			return
		}
		if errors.Is(err, ErrExchangeRateUnavailable) {
			c.JSON(503, gin.H{"error": "daily exchange rate is unavailable; retry or use USD"})
			return
		}
		database.LogRequestError(err)
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

// Display and frozen USD quoting remain separate provider contracts. Creation
// calls this only after validating and deriving the standalone graph once.
func (h *BillHandler) prepareDisplay(bill *models.Bill) error {
	if bill.CurrencyCode != bill.DisplayCurrency {
		if h.rates == nil {
			return errDisplayConversionUnavailable
		}
		rate, err := h.rates.GetRate(bill.CurrencyCode, bill.DisplayCurrency)
		if err != nil {
			return errDisplayConversionUnavailable
		}
		displayTotal := bill.Total * rate.Value
		if !finite(rate.Value) || rate.Value <= 0 || !finite(displayTotal) {
			return errDisplayConversionUnavailable
		}
		bill.DisplayTotal = &displayTotal
		bill.ExchangeRate = &rate.Value
		bill.ExchangeRateSource = rate.Source
		bill.ExchangeRateDate = rate.UpdatedAt.Format(time.DateOnly)
	} else {
		displayTotal := bill.Total
		bill.DisplayTotal = &displayTotal
	}
	return nil
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
		database.LogRequestError(err)
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

func (h *BillHandler) GetBill(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}

	bill.AccessToken = ""
	c.JSON(200, bill)
}

func (h *BillHandler) UpdateLazyItemAssignments(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 4<<20)
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid bill id"})
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
	if !models.ItemAssignmentTotalIsValid(totalPercentage) {
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
	if err := h.service.UpdateItemAssignmentsBatch(c.Request.Context(), ClaimCommand{Access: BillAccess{BillID: uint(id), BillToken: safehttp.AccessToken(c)}, Updates: []ItemAssignmentsUpdate{{ItemID: uint(itemID), Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt}}}); err != nil {
		switch {
		case errors.Is(err, ErrAssignmentConflict):
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
		case errors.Is(err, ErrItemAlreadyPaid):
			c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
		case errors.Is(err, gorm.ErrRecordNotFound):
			c.JSON(404, gin.H{"error": "bill item not found"})
		default:
			mutation.WriteError(c, err)
		}
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

func (h *BillHandler) UpdateLazyItemAssignmentsBatch(c *gin.Context) {
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 4<<20)
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid bill id"})
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
		if !models.ItemAssignmentTotalIsValid(totalPercentage) {
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

	if err := h.service.UpdateItemAssignmentsBatch(c.Request.Context(), ClaimCommand{Access: BillAccess{BillID: uint(id), BillToken: safehttp.AccessToken(c)}, Updates: updates}); err != nil {
		switch {
		case errors.Is(err, ErrAssignmentConflict):
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
		case errors.Is(err, ErrItemAlreadyPaid):
			c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
		case errors.Is(err, gorm.ErrRecordNotFound):
			c.JSON(404, gin.H{"error": "bill item not found"})
		default:
			mutation.WriteError(c, err)
		}
		return
	}

	updatedBill, err := h.service.GetBill(uint(id))
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	updatedBill.AccessToken = ""
	c.JSON(200, updatedBill)
}

func (h *BillHandler) UpdatePersonSharePaid(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid bill id"})
		return
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 4<<10)
	shareID, err := strconv.ParseUint(c.Param("shareId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid share id"})
		return
	}

	var body struct {
		Paid *bool `json:"paid"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}

	if err := h.service.UpdatePersonSharePaid(c.Request.Context(), BillSharePaidCommand{Access: BillAccess{BillID: uint(id), BillToken: safehttp.AccessToken(c)}, ShareID: uint(shareID), Paid: *body.Paid}); err != nil {
		if errors.Is(err, ErrPersonShareNotFound) {
			c.JSON(404, gin.H{"error": "share not found on this bill"})
			return
		}
		mutation.WriteError(c, err)
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}
