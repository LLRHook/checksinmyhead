package bill

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"backend/pkg/security"
	"crypto/subtle"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func appDomain() string {
	if d := os.Getenv("APP_DOMAIN"); d != "" {
		return d
	}
	return "https://billingtonapp.vercel.app"
}

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

	//Parse JSON from request body
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
	//Call service
	err = h.service.CreateBill(c.Request.Context(), &bill)

	//Return response based on result
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

	// Return created bill with ID
	c.JSON(201, gin.H{
		"bill_id":              bill.ID,
		"access_token":         token,
		"share_url":            fmt.Sprintf("%s/b/%d?t=%s", appDomain(), bill.ID, token),
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

	// Try Authorization header first, fall back to query param
	token := ""
	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token = strings.TrimPrefix(authHeader, "Bearer ")
	} else {
		token = c.Query("t")
	}

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
	if subtle.ConstantTimeCompare([]byte(token), []byte(bill.AccessToken)) != 1 {
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

func (h *BillHandler) UpdatePersonSharePaid(c *gin.Context) {
	bill := h.getBillAndValidate(c)
	if bill == nil {
		return
	}

	shareID, err := strconv.ParseUint(c.Param("shareId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid share id"})
		return
	}

	// Verify the share belongs to this bill
	found := false
	for _, s := range bill.PersonShares {
		if s.ID == uint(shareID) {
			found = true
			break
		}
	}
	if !found {
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

	if err := h.service.UpdatePersonSharePaid(uint(shareID), *body.Paid); err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}
