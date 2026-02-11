package tab

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"fmt"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type TabHandler struct {
	service TabService
}

func NewTabHandler(service TabService) *TabHandler {
	return &TabHandler{service: service}
}

// getTabAndValidate parses the ID, fetches the tab, and validates the token.
// Returns the tab on success or writes an error and returns nil.
func (h *TabHandler) getTabAndValidate(c *gin.Context) *models.Tab {
	id := c.Param("id")
	urlToken := c.Query("t")

	if id == "" {
		c.JSON(400, gin.H{"error": "bad id"})
		return nil
	}

	idUint, err := strconv.ParseUint(id, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid id format"})
		return nil
	}

	tab, err := h.service.GetTab(uint(idUint))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "tab not found"})
			return nil
		}
		c.JSON(500, gin.H{"error": err.Error()})
		return nil
	}

	if urlToken != tab.AccessToken {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}

	return tab
}

func (h *TabHandler) CreateTab(c *gin.Context) {
	var tab models.Tab

	if err := c.ShouldBindJSON(&tab); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	token := security.GenerateSecureToken()
	tab.AccessToken = token

	err := h.service.CreateTab(&tab)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(201, gin.H{
		"tab_id":       tab.ID,
		"access_token": token,
		"share_url":    fmt.Sprintf("https://billington.app/t/%d?t=%s", tab.ID, token),
	})
}

func (h *TabHandler) GetTab(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	c.JSON(200, tab)
}

func (h *TabHandler) AddBillToTab(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	if tab.Finalized {
		c.JSON(400, gin.H{"error": "tab is finalized"})
		return
	}

	var body struct {
		BillID uint `json:"bill_id"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	err := h.service.AddBillToTab(tab.ID, body.BillID)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateTab(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	if tab.Finalized {
		c.JSON(400, gin.H{"error": "tab is finalized"})
		return
	}

	var body struct {
		Name        *string `json:"name"`
		Description *string `json:"description"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	update := &models.Tab{ID: tab.ID}
	if body.Name != nil {
		update.Name = *body.Name
	}
	if body.Description != nil {
		update.Description = *body.Description
	}

	err := h.service.UpdateTab(update)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) FinalizeTab(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	settlements, err := h.service.FinalizeTab(tab.ID)
	if err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, settlements)
}

func (h *TabHandler) GetSettlements(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	settlements, err := h.service.GetSettlements(tab.ID)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, settlements)
}

func (h *TabHandler) UpdateSettlement(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	settlementID, err := strconv.ParseUint(c.Param("settlementId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid settlement id"})
		return
	}

	var body struct {
		Paid *bool `json:"paid"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}

	if err := h.service.UpdateSettlementPaid(uint(settlementID), *body.Paid); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}
