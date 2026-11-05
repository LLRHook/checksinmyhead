package web

import (
	billpkg "backend/internal/bill"
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"crypto/subtle"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type WebpageHandler struct {
	service billpkg.BillService
}

func NewWebpageHandler(service billpkg.BillService) *WebpageHandler {
	return &WebpageHandler{service: service}
}

func (h *WebpageHandler) CreateHTML(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
	id := c.Param("id")

	URLtoken := safehttp.AccessToken(c)

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
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	if URLtoken == "" || bill.AccessToken == "" || subtle.ConstantTimeCompare([]byte(URLtoken), []byte(bill.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return
	}

	bill.AccessToken = ""
	view := billpkg.ViewBill(*bill, nil)
	for i := range view.PersonShares {
		if view.PersonShares[i].Label != nil {
			view.PersonShares[i].PersonName = *view.PersonShares[i].Label
		}
	}
	c.HTML(200, "bill.html", view)
}
