package tab

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"crypto/subtle"
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

	// Try Authorization header first, fall back to query param
	token := ""
	authHeader := c.GetHeader("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		token = strings.TrimPrefix(authHeader, "Bearer ")
	} else {
		token = c.Query("t")
	}
	urlToken := token

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
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return nil
	}

	if subtle.ConstantTimeCompare([]byte(urlToken), []byte(tab.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}

	return tab
}

// getTabAuthAndValidate validates access using a lightweight tab lookup.
func (h *TabHandler) getTabAuthAndValidate(c *gin.Context) *models.Tab {
	id := c.Param("id")

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

	tab, err := h.service.GetTabAuth(uint(idUint))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "tab not found"})
			return nil
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return nil
	}

	if subtle.ConstantTimeCompare([]byte(token), []byte(tab.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}

	return tab
}

// getMemberFromQuery reads the member token from X-Member-Token header or ?m= query param.
func (h *TabHandler) getMemberFromQuery(c *gin.Context, tabID uint) *models.TabMember {
	memberToken := c.GetHeader("X-Member-Token")
	if memberToken == "" {
		memberToken = c.Query("m")
	}
	if memberToken == "" {
		return nil
	}
	member, err := h.service.GetMemberByToken(memberToken)
	if err != nil {
		return nil
	}
	if member.TabID != tabID {
		return nil
	}
	return member
}

func (h *TabHandler) CreateTab(c *gin.Context) {
	var body struct {
		Name               string `json:"name"`
		Description        string `json:"description"`
		CreatorDisplayName string `json:"creator_display_name"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	tab := models.Tab{
		Name:        security.SanitizeString(body.Name),
		Description: security.SanitizeString(body.Description),
	}

	token, err := security.GenerateSecureToken()
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	tab.AccessToken = token

	err = h.service.CreateTab(&tab)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	resp := gin.H{
		"tab_id":       tab.ID,
		"access_token": token,
		"share_url":    fmt.Sprintf("%s/t/%d?t=%s", appDomain(), tab.ID, token),
	}

	creatorName := security.SanitizeString(body.CreatorDisplayName)
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

	tab.AccessToken = ""
	c.JSON(200, tab)
}

func (h *TabHandler) AddBillToTab(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	if tab.Finalized {
		c.JSON(400, gin.H{"error": "tab is finalized"})
		return
	}

	var body struct {
		BillID    uint   `json:"bill_id"`
		BillToken string `json:"bill_token"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	var memberID *uint
	if member := h.getMemberFromQuery(c, tab.ID); member != nil {
		memberID = &member.ID
	}

	err := h.service.AddBillToTab(tab.ID, body.BillID, body.BillToken, memberID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill not found"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateBillItemAssignments(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	if tab.Finalized {
		c.JSON(400, gin.H{"error": "tab is finalized"})
		return
	}

	billID, err := strconv.ParseUint(c.Param("billId"), 10, 32)
	if err != nil {
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
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	assignments := make([]models.ItemAssignment, 0, len(body.Assignments))
	var expectedUpdatedAt *time.Time
	if body.ExpectedUpdatedAt != nil && *body.ExpectedUpdatedAt != "" {
		parsed, parseErr := time.Parse(time.RFC3339Nano, *body.ExpectedUpdatedAt)
		if parseErr != nil {
			c.JSON(400, gin.H{"error": "invalid expected_updated_at"})
			return
		}
		expectedUpdatedAt = &parsed
	}
	for _, assignment := range body.Assignments {
		name := security.SanitizeString(assignment.PersonName)
		if name == "" || assignment.Percentage <= 0 {
			continue
		}
		assignments = append(assignments, models.ItemAssignment{
			PersonName: name,
			Percentage: assignment.Percentage,
		})
	}

	if err := h.service.UpdateBillItemAssignments(tab.ID, uint(billID), uint(itemID), assignments, expectedUpdatedAt); err != nil {
		if err == ErrAssignmentConflict {
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
			return
		}
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill item not found"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateBillPersonSharePaid(c *gin.Context) {
	tab := h.getTabAndValidate(c)
	if tab == nil {
		return
	}

	billID, err := strconv.ParseUint(c.Param("billId"), 10, 32)
	if err != nil {
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
	if err := c.ShouldBindJSON(&body); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}
	member := h.getMemberFromQuery(c, tab.ID)
	if member == nil {
		c.JSON(403, gin.H{"error": "member token required"})
		return
	}
	var matchingShare *models.PersonShare
	for i := range tab.Bills {
		if tab.Bills[i].ID != uint(billID) {
			continue
		}
		for j := range tab.Bills[i].PersonShares {
			if tab.Bills[i].PersonShares[j].ID == uint(shareID) {
				matchingShare = &tab.Bills[i].PersonShares[j]
				break
			}
		}
	}
	if matchingShare == nil || !strings.EqualFold(matchingShare.PersonName, member.DisplayName) {
		c.JSON(403, gin.H{"error": "share does not belong to member"})
		return
	}
	if err := h.service.UpdateBillPersonSharePaid(tab.ID, uint(billID), uint(shareID), *body.Paid); err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "share not found"})
			return
		}
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateTab(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
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
		sanitized := security.SanitizeString(*body.Name)
		update.Name = sanitized
	}
	if body.Description != nil {
		sanitized := security.SanitizeString(*body.Description)
		update.Description = sanitized
	}

	err := h.service.UpdateTab(update)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) FinalizeTab(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	// If tab has members, only the creator can finalize
	members, err := h.service.GetMembers(tab.ID)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	if len(members) > 0 {
		member := h.getMemberFromQuery(c, tab.ID)
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
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	settlements, err := h.service.GetSettlements(tab.ID)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, settlements)
}

func (h *TabHandler) UpdateSettlement(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
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
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) JoinTab(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
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

	name := security.SanitizeString(body.DisplayName)
	if name == "" || len(name) > 30 {
		c.JSON(400, gin.H{"error": "display_name must be 1-30 characters"})
		return
	}

	member, err := h.service.JoinTab(tab.ID, name)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
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
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	members, err := h.service.GetMembers(tab.ID)
	if err != nil {
		log.Printf("internal error: %v", err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, members)
}
