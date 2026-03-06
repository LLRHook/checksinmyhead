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

func (h *BillHandler) GetBill(c *gin.Context) {
	id := c.Param("id")

	// Try Authorization header first, fall back to query param
	URLtoken := ""
	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		URLtoken = strings.TrimPrefix(authHeader, "Bearer ")
	} else {
		URLtoken = c.Query("t")
	}

	if id == "" {
		c.JSON(400, gin.H{"error": "bad id"})
		return
	}

	idUint, err := strconv.ParseUint(id, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid id format"})
		return
	}

	bill, err := h.service.GetBill(uint(idUint))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill not found"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	if subtle.ConstantTimeCompare([]byte(URLtoken), []byte(bill.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return
	}

	bill.AccessToken = ""
	c.JSON(200, bill)
}
