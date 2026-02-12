package tab

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"fmt"
	"strconv"
	"strings"

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

// getMemberFromQuery reads ?m= and returns the member or nil.
func (h *TabHandler) getMemberFromQuery(c *gin.Context) *models.TabMember {
	memberToken := c.Query("m")
	if memberToken == "" {
		return nil
	}
	member, err := h.service.GetMemberByToken(memberToken)
	if err != nil {
		return nil
	}
	return member
}

func (h *TabHandler) CreateTab(c *gin.Context) {
	var body struct {
		Name                string `json:"name"`
		Description         string `json:"description"`
		CreatorDisplayName  string `json:"creator_display_name"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	tab := models.Tab{
		Name:        body.Name,
		Description: body.Description,
	}

	token := security.GenerateSecureToken()
	tab.AccessToken = token

	err := h.service.CreateTab(&tab)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	resp := gin.H{
		"tab_id":       tab.ID,
		"access_token": token,
		"share_url":    fmt.Sprintf("https://billington.app/t/%d?t=%s", tab.ID, token),
	}

	creatorName := strings.TrimSpace(body.CreatorDisplayName)
	if creatorName != "" {
		member, err := h.service.JoinTabAsCreator(tab.ID, creatorName)
		if err == nil {
			resp["member_token"] = member.MemberToken
			resp["member_id"] = member.ID
		}
	}

	c.JSON(201, resp)
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

	var memberID *uint
	if member := h.getMemberFromQuery(c); member != nil {
		memberID = &member.ID
	}

	err := h.service.AddBillToTab(tab.ID, body.BillID, memberID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill not found"})
			return
		}
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

	// If tab has members, only the creator can finalize
	if len(tab.Members) > 0 {
		member := h.getMemberFromQuery(c)
		if member == nil || member.Role != "creator" {
			c.JSON(403, gin.H{"error": "only the tab creator can finalize"})
			return
		}
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

func (h *TabHandler) JoinTab(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	var body struct {
		DisplayName string `json:"display_name"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	name := strings.TrimSpace(body.DisplayName)
	if name == "" || len(name) > 30 {
		c.JSON(400, gin.H{"error": "display_name must be 1-30 characters"})
		return
	}

	member, err := h.service.JoinTab(tab.ID, name)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(201, gin.H{
		"member_id":    member.ID,
		"member_token": member.MemberToken,
		"display_name": member.DisplayName,
		"role":         member.Role,
	})
}

func (h *TabHandler) GetMembers(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	members, err := h.service.GetMembers(tab.ID)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, members)
}
