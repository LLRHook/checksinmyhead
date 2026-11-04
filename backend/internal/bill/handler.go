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
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type BillHandler struct{ service BillService }

func NewBillHandler(service BillService) *BillHandler { return &BillHandler{service: service} }

func (h *BillHandler) CreateBill(c *gin.Context) {
	bill, err := decodeCreateBill(c.Writer, c.Request)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid bill content"})
		return
	}

	key, err := parseCreationKey(c.Request.Header)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid creation key"})
		return
	}
	result, err := h.service.CreateBill(c.Request.Context(), CreateBillCommand{Content: bill, Key: key})

	if err != nil {
		currency.WriteRetryAfter(c, err)
		if errors.Is(err, ErrReplayConflict) {
			c.JSON(409, gin.H{"error": "creation conflict", "code": "creation_conflict"})
			return
		}
		if errors.Is(err, ErrReplayVersion) || errors.Is(err, ErrCreateUncertain) {
			c.JSON(503, gin.H{"error": "creation temporarily unavailable", "code": "creation_unavailable"})
			return
		}
		if errors.Is(err, ErrDisplayConversionUnavailable) {
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

	c.Header("Cache-Control", "no-store")
	c.JSON(201, gin.H{
		"bill_id": result.BillID, "access_token": result.AccessToken,
		"share_url":     fmt.Sprintf("%s/b/%d?t=%s", config.AppDomain(), result.BillID, result.AccessToken),
		"currency_code": result.CurrencyCode, "usd_exchange_rate": result.USDExchangeRate,
		"exchange_rate_date": result.ExchangeRateDate, "exchange_rate_source": result.ExchangeRateSource, "usd_total": result.USDTotal,
	})
}

func (h *BillHandler) GetExchangeRate(c *gin.Context) {
	quote, err := h.service.GetUSDExchangeRate(c.Request.Context(), c.Param("currency"))
	if err != nil {
		if errors.Is(err, ErrInvalidCurrency) {
			c.JSON(400, gin.H{"error": "unsupported currency code"})
			return
		}
		currency.WriteRetryAfter(c, err)
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
		ExpectedUpdatedAt *string          `json:"expected_updated_at"`
		Assignments       AssignmentInputs `json:"assignments"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil || body.Assignments == nil || len(body.Assignments) > 100 {
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
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid bill id"})
		return
	}
	var body struct {
		Updates AssignmentUpdateInputs `json:"updates"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil || len(body.Updates) == 0 {
		c.JSON(400, gin.H{"error": "item updates are required"})
		return
	}

	if !AssignmentInputCountsValid(body.Updates) {
		c.JSON(400, gin.H{"error": "bad request"})
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
	shareID, err := strconv.ParseUint(c.Param("shareId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid share id"})
		return
	}

	var body struct {
		Paid *bool `json:"paid"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, false); err != nil || body.Paid == nil {
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
