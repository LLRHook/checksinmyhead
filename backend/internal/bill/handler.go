package bill

import (
	"backend/internal/currency"
	"backend/pkg/config"
	"backend/pkg/database"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"crypto/subtle"
	"errors"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type BillHandler struct{ service BillService }

func NewBillHandler(service BillService) *BillHandler { return &BillHandler{service: service} }

func (h *BillHandler) CreateBill(c *gin.Context) {
	if _, ok := safehttp.IdentityVersion(c); !ok {
		return
	}
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
		mutation.WriteError(c, err)
		return
	}

	if result.OriginalResponse != nil {
		c.Data(201, "application/json; charset=utf-8", result.OriginalResponse)
		return
	}
	c.Header("Cache-Control", "private, no-store")
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
	version, ok := safehttp.IdentityVersion(c)
	if !ok {
		return
	}
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}

	viewer, err := BillViewer(*bill, safehttp.MemberToken(c))
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	if version == 2 {
		safehttp.JSONValue(c, 200, ViewBill(*bill, viewer))
		return
	}
	if err := LegacyBillRepresentable(*bill); err != nil {
		mutation.WriteError(c, err)
		return
	}
	value := LegacyBill(*bill)
	safehttp.JSONValue(c, 200, value)
}

func (h *BillHandler) UpdateLazyItemAssignments(c *gin.Context)      { h.updateClaims(c, true) }
func (h *BillHandler) UpdateLazyItemAssignmentsBatch(c *gin.Context) { h.updateClaims(c, false) }
func (h *BillHandler) updateClaims(c *gin.Context, single bool) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 63)
	if err != nil || id == 0 {
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	updates, expected, err := DecodeClaim(c, single)
	if err != nil {
		if !c.IsAborted() {
			WriteClaimError(c, err)
		}
		return
	}
	err = h.service.UpdateItemAssignmentsBatch(c.Request.Context(), ClaimCommand{Access: BillAccess{BillID: uint(id), BillToken: safehttp.AccessToken(c)}, Updates: updates, ExpectedRevision: expected})
	if err != nil {
		WriteClaimError(c, err)
		return
	}
	if single {
		c.JSON(200, gin.H{"status": "ok"})
		return
	}
	b, err := h.service.GetBill(uint(id))
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	viewer, err := BillViewer(*b, safehttp.MemberToken(c))
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	version, _ := safehttp.IdentityVersion(c)
	b.AccessToken = ""
	if version == 2 {
		safehttp.JSONValue(c, 200, ViewBill(*b, viewer))
	} else {
		if err := LegacyBillRepresentable(*b); err != nil {
			mutation.WriteError(c, err)
			return
		}
		value := LegacyBill(*b)
		safehttp.JSONValue(c, 200, value)
	}
}

func (h *BillHandler) UpdatePersonSharePaid(c *gin.Context) {
	if _, ok := safehttp.IdentityVersion(c); !ok {
		return
	}
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, identityStrict(c)); err != nil || body.Paid == nil {
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

func identityStrict(c *gin.Context) bool {
	version, _ := safehttp.ParseIdentityVersion(c.Request.Header)
	return version == 2
}
