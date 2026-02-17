package web

import (
	"backend/internal/bill"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type WebpageHandler struct {
	service bill.BillService
}

func NewWebpageHandler(service bill.BillService) *WebpageHandler {
	return &WebpageHandler{service: service}
}

func (h *WebpageHandler) CreateHTML(c *gin.Context) {
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
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	if URLtoken != bill.AccessToken {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return
	}

	c.HTML(200, "bill.html", bill)
}
