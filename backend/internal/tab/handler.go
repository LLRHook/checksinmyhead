package tab

import (
	"backend/internal/bill"
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
	"unicode/utf8"

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
	return h.getTabWithLookup(c, h.service.GetTab)
}

// getTabAuthAndValidate validates access using a lightweight tab lookup.
func (h *TabHandler) getTabAuthAndValidate(c *gin.Context) *models.Tab {
	return h.getTabWithLookup(c, h.service.GetTabAuth)
}

func (h *TabHandler) getTabWithLookup(
	c *gin.Context,
	lookup func(uint) (*models.Tab, error),
) *models.Tab {
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

	tab, err := lookup(uint(idUint))
	if err != nil && (!errors.Is(err, mutation.Review) || tab == nil) {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "tab not found"})
			return nil
		}
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return nil
	}

	if subtle.ConstantTimeCompare([]byte(token), []byte(tab.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}
	if err != nil {
		mutation.WriteError(c, err)
		return nil
	}

	return tab
}

func (h *TabHandler) CreateTab(c *gin.Context) {
	var body struct {
		Name               string `json:"name"`
		Description        string `json:"description"`
		CreatorDisplayName string `json:"creator_display_name"`
		DisplayCurrency    string `json:"display_currency"`
	}

	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 16<<10, false); err != nil {
		status := 400
		if errors.Is(err, safehttp.ErrJSONTooLarge) {
			status = 413
		}
		c.JSON(status, gin.H{"error": "bad request"})
		return
	}

	body.Name = security.SanitizeString(body.Name)
	body.Description = security.SanitizeString(body.Description)
	body.CreatorDisplayName = security.SanitizeString(body.CreatorDisplayName)
	if !utf8.ValidString(body.Name) || !utf8.ValidString(body.Description) || !utf8.ValidString(body.CreatorDisplayName) || utf8.RuneCountInString(body.Name) > 255 || utf8.RuneCountInString(body.Description) > 4096 || utf8.RuneCountInString(body.CreatorDisplayName) > 30 {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	displayCurrency := strings.ToUpper(strings.TrimSpace(body.DisplayCurrency))
	if len(displayCurrency) != 3 {
		displayCurrency = "USD"
	}
	tab := models.Tab{
		Name:            body.Name,
		Description:     body.Description,
		DisplayCurrency: displayCurrency,
	}

	token, err := security.GenerateSecureToken()
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}
	tab.AccessToken = token

	creator, err := h.service.CreateTab(c.Request.Context(), &tab, body.CreatorDisplayName)
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	resp := gin.H{
		"tab_id":       tab.ID,
		"access_token": token,
		"share_url":    fmt.Sprintf("%s/t/%d?t=%s", config.AppDomain(), tab.ID, token),
	}

	if creator != nil {
		resp["member_token"] = creator.MemberToken
		resp["member_id"] = creator.ID
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
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid tab id"})
		return
	}
	var body struct {
		BillID    uint   `json:"bill_id"`
		BillToken string `json:"bill_token"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}
	memberToken := c.GetHeader("X-Member-Token")
	if memberToken == "" {
		memberToken = c.Query("m")
	}
	command := AttachBillCommand{TabID: uint(id), BillID: body.BillID, BillToken: body.BillToken,
		TabToken: safehttp.AccessToken(c), MemberToken: memberToken}
	err = h.service.AddBillToTab(c.Request.Context(), command)
	switch {
	case errors.Is(err, ErrInvalidAttachment):
		c.JSON(400, gin.H{"error": "bill id and source token are required"})
	case errors.Is(err, ErrDestinationForbidden):
		c.JSON(403, gin.H{"error": "destination access denied"})
	case errors.Is(err, ErrTabFinalized):
		c.JSON(400, gin.H{"error": "tab is finalized"})
	case errors.Is(err, ErrSourceUnavailable):
		c.JSON(404, gin.H{"error": "source bill unavailable"})
	case err != nil:
		mutation.WriteError(c, err)
	default:
		c.JSON(200, gin.H{"status": "ok"})
	}
}

func (h *TabHandler) UpdateBillItemAssignments(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
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
		ExpectedUpdatedAt *string               `json:"expected_updated_at"`
		Assignments       bill.AssignmentInputs `json:"assignments"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	if body.Assignments == nil || len(body.Assignments) > 100 {
		c.JSON(400, gin.H{"error": "assignments are required"})
		return
	}
	assignments := make([]models.ItemAssignment, 0, len(body.Assignments))
	seen := make(map[string]struct{}, len(body.Assignments))
	var totalPercentage float64
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
		if name == "" || len([]rune(name)) > 30 || assignment.Percentage <= 0 || assignment.Percentage > 100 || math.IsNaN(assignment.Percentage) || math.IsInf(assignment.Percentage, 0) {
			c.JSON(400, gin.H{"error": "invalid item assignment"})
			return
		}
		key := strings.ToLower(name)
		if _, ok := seen[key]; ok {
			c.JSON(400, gin.H{"error": "duplicate person assignment"})
			return
		}
		seen[key] = struct{}{}
		totalPercentage += assignment.Percentage
		assignments = append(assignments, models.ItemAssignment{
			PersonName: name,
			Percentage: assignment.Percentage,
		})
	}
	if !models.ItemAssignmentTotalIsValid(totalPercentage) {
		c.JSON(400, gin.H{"error": "item assignments cannot exceed 100 percent"})
		return
	}

	if err := h.service.UpdateBillItemAssignmentsBatch(c.Request.Context(), AssignmentCommand{Access: *access, BillID: uint(billID), Updates: []BillItemAssignmentsUpdate{{ItemID: uint(itemID), Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt}}}); err != nil {
		if err == ErrAssignmentConflict {
			c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
			return
		}
		if err == ErrItemAlreadyPaid {
			c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
			return
		}
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "bill item not found"})
			return
		}
		mutation.WriteError(c, err)
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateBillItemAssignmentsBatch(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	billID, err := strconv.ParseUint(c.Param("billId"), 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid bill id"})
		return
	}
	var body struct {
		Updates bill.AssignmentUpdateInputs `json:"updates"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil || len(body.Updates) == 0 {
		c.JSON(400, gin.H{"error": "item updates are required"})
		return
	}

	if !bill.AssignmentInputCountsValid(body.Updates) {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	updates := make([]BillItemAssignmentsUpdate, 0, len(body.Updates))
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
		var expectedUpdatedAt *time.Time
		if itemUpdate.ExpectedUpdatedAt != nil && *itemUpdate.ExpectedUpdatedAt != "" {
			parsed, parseErr := time.Parse(time.RFC3339Nano, *itemUpdate.ExpectedUpdatedAt)
			if parseErr != nil {
				c.JSON(400, gin.H{"error": "invalid expected_updated_at"})
				return
			}
			expectedUpdatedAt = &parsed
		}
		assignments := make([]models.ItemAssignment, 0, len(itemUpdate.Assignments))
		seenPeople := make(map[string]struct{}, len(itemUpdate.Assignments))
		var totalPercentage float64
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
		updates = append(updates, BillItemAssignmentsUpdate{
			ItemID: itemUpdate.ItemID, Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt,
		})
	}
	if err := h.service.UpdateBillItemAssignmentsBatch(c.Request.Context(), AssignmentCommand{Access: *access, BillID: uint(billID), Updates: updates}); err != nil {
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

func (h *TabHandler) UpdateBillPersonSharePaid(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}
	if err := h.service.UpdateBillPersonSharePaid(c.Request.Context(), SharePaidCommand{Access: *access, BillID: uint(billID), ShareID: uint(shareID), Paid: *body.Paid}); err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "share not found"})
			return
		}
		mutation.WriteError(c, err)
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) UpdateTab(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	var body struct {
		Name            *string `json:"name"`
		Description     *string `json:"description"`
		DisplayCurrency *string `json:"display_currency"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}

	update := SettingsCommand{Access: *access}
	if body.Name != nil {
		sanitized := security.SanitizeString(*body.Name)
		update.Name = &sanitized
	}
	if body.Description != nil {
		sanitized := security.SanitizeString(*body.Description)
		update.Description = &sanitized
	}
	if body.DisplayCurrency != nil {
		currency := strings.ToUpper(strings.TrimSpace(*body.DisplayCurrency))
		if len(currency) != 3 {
			c.JSON(400, gin.H{"error": "invalid display currency"})
			return
		}
		update.DisplayCurrency = &currency
	}

	err := h.service.UpdateTab(c.Request.Context(), update)
	if err != nil {
		mutation.WriteError(c, err)
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) FinalizeTab(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	rows, err := h.service.FinalizeTab(c.Request.Context(), FinalizeCommand{Access: *access})
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	c.JSON(200, rows)
}

func (h *TabHandler) GetSettlements(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	settlements, err := h.service.GetSettlements(tab.ID)
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, settlements)
}

func (h *TabHandler) UpdateSettlement(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil || body.Paid == nil {
		c.JSON(400, gin.H{"error": "paid field required"})
		return
	}

	if err := h.service.UpdateSettlementPaid(c.Request.Context(), SettlementPaidCommand{Access: *access, SettlementID: uint(settlementID), Paid: *body.Paid}); err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "settlement not found"})
			return
		}
		mutation.WriteError(c, err)
		return
	}

	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) JoinTab(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	var body struct {
		DisplayName string `json:"display_name"`
	}
	if access.MemberToken == "" {
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil {
			c.JSON(400, gin.H{"error": "bad request"})
			return
		}
		body.DisplayName = security.SanitizeString(body.DisplayName)
		if body.DisplayName == "" || len(body.DisplayName) > 30 {
			c.JSON(400, gin.H{"error": "display_name must be 1-30 characters"})
			return
		}
	}
	member, replay, err := h.service.JoinTab(c.Request.Context(), JoinCommand{Access: *access, DisplayName: body.DisplayName})
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	status := 201
	if replay {
		status = 200
	}
	c.JSON(status, gin.H{"member_id": member.ID, "member_token": member.MemberToken, "display_name": member.DisplayName, "role": member.Role})
}

func (h *TabHandler) LeaveTab(c *gin.Context) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	if err := h.service.DeleteMember(c.Request.Context(), LeaveCommand{Access: *access}); err != nil {
		mutation.WriteError(c, err)
		return
	}
	c.JSON(200, gin.H{"status": "ok"})
}

func (h *TabHandler) GetMembers(c *gin.Context) {
	tab := h.getTabAuthAndValidate(c)
	if tab == nil {
		return
	}

	members, err := h.service.GetMembers(tab.ID)
	if err != nil {
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return
	}

	c.JSON(200, members)
}

// writeAccess parses capabilities; current authority/state is resolved only by
// the repository after acquiring the tab root lock.
func writeAccess(c *gin.Context) *TabAccess {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid tab id"})
		return nil
	}
	member := c.GetHeader("X-Member-Token")
	if member == "" {
		member = c.Query("m")
	}
	return &TabAccess{TabID: uint(id), TabToken: safehttp.AccessToken(c), MemberToken: member}
}
