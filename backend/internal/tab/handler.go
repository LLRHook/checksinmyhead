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

	"strconv"
	"strings"
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
	version, ok := safehttp.IdentityVersion(c)
	if !ok {
		return nil
	}
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
	if err != nil && (!(errors.Is(err, mutation.Review) || errors.Is(err, bill.ErrIdentityReview)) || tab == nil) {
		if err == gorm.ErrRecordNotFound {
			c.JSON(404, gin.H{"error": "tab not found"})
			return nil
		}
		database.LogRequestError(err)
		c.JSON(500, gin.H{"error": "an internal error occurred"})
		return nil
	}

	if token == "" || tab.AccessToken == "" || subtle.ConstantTimeCompare([]byte(token), []byte(tab.AccessToken)) != 1 {
		c.JSON(403, gin.H{"error": "token mismatch"})
		return nil
	}
	if err != nil && version != 2 {
		mutation.WriteError(c, bill.ErrClientUpgrade)
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

	viewer, err := bill.ViewerMember(tab.ID, tab.Members, safehttp.MemberToken(c))
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	version, _ := safehttp.IdentityVersion(c)
	if version == 2 {
		safehttp.JSONValue(c, 200, viewTab(*tab, viewer))
		return
	}
	if err := legacyTabRepresentable(tab); err != nil {
		mutation.WriteError(c, err)
		return
	}
	tab.AccessToken = ""
	for i := range tab.Bills {
		tab.Bills[i] = bill.LegacyBill(tab.Bills[i])
	}
	safehttp.JSONValue(c, 200, tab)
}

func (h *TabHandler) AddBillToTab(c *gin.Context) {
	version, ok := safehttp.IdentityVersion(c)
	if !ok {
		return
	}
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		c.JSON(400, gin.H{"error": "invalid tab id"})
		return
	}
	var body struct {
		BillID           uint   `json:"bill_id"`
		BillToken        string `json:"bill_token"`
		ExpectedRevision *int64 `json:"expected_revision"`
	}
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
		c.JSON(400, gin.H{"error": "bad request"})
		return
	}
	memberToken := safehttp.MemberToken(c)
	if version == 2 && (body.ExpectedRevision == nil || *body.ExpectedRevision < 0) || version == 1 && body.ExpectedRevision != nil {
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	command := AttachBillCommand{TabID: uint(id), BillID: body.BillID, BillToken: body.BillToken,
		TabToken: safehttp.AccessToken(c), MemberToken: memberToken, IdentityVersion: version, ExpectedRevision: body.ExpectedRevision}
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

func (h *TabHandler) UpdateBillItemAssignments(c *gin.Context)      { h.updateClaims(c, true) }
func (h *TabHandler) UpdateBillItemAssignmentsBatch(c *gin.Context) { h.updateClaims(c, false) }
func (h *TabHandler) updateClaims(c *gin.Context, single bool) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	id, err := strconv.ParseUint(c.Param("billId"), 10, 63)
	if err != nil || id == 0 {
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	updates, expected, err := bill.DecodeClaim(c, single)
	if err != nil {
		if !c.IsAborted() {
			bill.WriteClaimError(c, err)
		}
		return
	}
	if err := h.service.UpdateBillItemAssignmentsBatch(c.Request.Context(), AssignmentCommand{Access: *access, BillID: uint(id), Updates: updates, ExpectedRevision: expected}); err != nil {
		bill.WriteClaimError(c, err)
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, identityStrict(c)); err != nil || body.Paid == nil {
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, identityStrict(c)); err != nil {
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
	version, _ := safehttp.IdentityVersion(c)
	if version == 2 {
		var viewer *uint
		if len(rows) > 0 {
			viewer = rows[0].ViewerMemberID
		}
		safehttp.JSONValue(c, 200, viewSettlements(models.Tab{ID: access.TabID}, rows, viewer, nil))
		return
	}
	c.JSON(200, rows)
}

func (h *TabHandler) GetSettlements(c *gin.Context) {
	if reader, ok := h.service.(SettlementReader); ok {
		access := writeAccess(c)
		if access == nil {
			return
		}
		history, err := reader.ReadSettlements(c.Request.Context(), *access)
		if err != nil {
			mutation.WriteError(c, err)
			return
		}
		version, _ := safehttp.IdentityVersion(c)
		if version == 2 {
			safehttp.JSONValue(c, 200, history)
		} else {
			if history.ReviewStatus != "ready" && history.ReviewStatus != "legacy_identity_review_required" {
				mutation.WriteError(c, bill.ErrClientUpgrade)
				return
			}
			safehttp.JSONValue(c, 200, history.RawRows)
		}
		return
	}
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
	if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, identityStrict(c)); err != nil || body.Paid == nil {
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
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, identityStrict(c)); err != nil {
			c.JSON(400, gin.H{"error": "bad request"})
			return
		}
		body.DisplayName = security.SanitizeString(body.DisplayName)
		if body.DisplayName == "" || utf8.RuneCountInString(body.DisplayName) > 30 {
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

	if _, err := bill.ViewerMember(tab.ID, members, safehttp.MemberToken(c)); err != nil {
		mutation.WriteError(c, err)
		return
	}
	c.JSON(200, members)
}

// writeAccess parses capabilities; current authority/state is resolved only by
// the repository after acquiring the tab root lock.
func writeAccess(c *gin.Context) *TabAccess {
	if _, ok := safehttp.IdentityVersion(c); !ok {
		return nil
	}
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil || id == 0 {
		safehttp.StopRejectedBody(c.Writer, c.Request)
		c.JSON(400, gin.H{"error": "invalid tab id"})
		return nil
	}
	member := safehttp.MemberToken(c)
	return &TabAccess{TabID: uint(id), TabToken: safehttp.AccessToken(c), MemberToken: member}
}

func identityStrict(c *gin.Context) bool {
	version, _ := safehttp.ParseIdentityVersion(c.Request.Header)
	return version == 2
}
