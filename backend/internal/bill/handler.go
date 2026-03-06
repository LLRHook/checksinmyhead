package bill

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"crypto/subtle"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"

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
}

func NewBillHandler(service BillService) *BillHandler {
	return &BillHandler{service: service}
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
	err = h.service.CreateBill(&bill)

	//Return response based on result
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	// Return created bill with ID
	c.JSON(201, gin.H{
		"bill_id":      bill.ID,
		"access_token": token,
		"share_url":    fmt.Sprintf("%s/b/%d?t=%s", appDomain(), bill.ID, token),
	})
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
