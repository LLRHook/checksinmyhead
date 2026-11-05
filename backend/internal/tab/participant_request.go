package tab

import (
	"backend/internal/bill"
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"github.com/gin-gonic/gin"
	"strconv"
)

func (h *TabHandler) CreateParticipant(c *gin.Context) { h.changeParticipant(c, "create") }
func (h *TabHandler) RenameParticipant(c *gin.Context) { h.changeParticipant(c, "rename") }
func (h *TabHandler) RequestBinding(c *gin.Context)    { h.changeParticipant(c, "request") }
func (h *TabHandler) DecideBinding(c *gin.Context)     { h.changeParticipant(c, "decision") }
func (h *TabHandler) changeParticipant(c *gin.Context, operation string) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	id, err := strconv.ParseUint(c.Param("billId"), 10, 63)
	if err != nil || id == 0 {
		safehttp.StopRejectedBody(c.Writer, c.Request)
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	change, source, err := bill.DecodeParticipantChange(c, operation, true)
	if err != nil {
		if !c.IsAborted() {
			mutation.WriteError(c, err)
		}
		return
	}
	service, ok := h.service.(ParticipantService)
	if !ok {
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	result, err := service.ChangeParticipant(c.Request.Context(), ParticipantCommand{Access: *access, BillID: uint(id), BillToken: source, Change: change})
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	bill.WriteParticipantResult(c, result)
}
func (h *TabHandler) GetMemberSelf(c *gin.Context)    { h.memberSelf(c, false) }
func (h *TabHandler) RenameMemberSelf(c *gin.Context) { h.memberSelf(c, true) }
func (h *TabHandler) memberSelf(c *gin.Context, rename bool) {
	access := writeAccess(c)
	if access == nil {
		return
	}
	var name *string
	if rename {
		var body struct {
			DisplayName *string `json:"display_name"`
		}
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil || body.DisplayName == nil {
			mutation.WriteError(c, mutation.Invalid)
			return
		}
		name = body.DisplayName
	}
	service, ok := h.service.(ParticipantService)
	if !ok {
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	member, err := service.MemberSelf(c.Request.Context(), MemberCommand{Access: *access, Name: name})
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	c.JSON(200, gin.H{"member_id": member.ID, "tab_id": member.TabID, "display_name": member.DisplayName, "role": member.Role})
}
