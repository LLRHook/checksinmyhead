package bill

import (
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"github.com/gin-gonic/gin"
	"strconv"
)

func DecodeParticipantChange(c *gin.Context, operation string, attached bool) (ParticipantChange, string, error) {
	version, ok := safehttp.IdentityVersion(c)
	if !ok {
		return ParticipantChange{}, "", mutation.Invalid
	}
	if version != 2 {
		safehttp.StopRejectedBody(c.Writer, c.Request)
		return ParticipantChange{}, "", ErrClientUpgrade
	}
	change := ParticipantChange{Operation: operation}
	source := ""
	if operation != "create" {
		id, err := strconv.ParseUint(c.Param("participantId"), 10, 63)
		if err != nil || id == 0 {
			safehttp.StopRejectedBody(c.Writer, c.Request)
			return change, source, mutation.Invalid
		}
		change.ParticipantID = uint(id)
	}
	switch operation {
	case "create":
		var body struct {
			ClientRef        string  `json:"client_ref"`
			Name             *string `json:"name"`
			ExpectedRevision *int64  `json:"expected_revision"`
		}
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
			return change, source, mutation.Invalid
		}
		change.ClientRef, change.Name, change.ExpectedRevision = body.ClientRef, body.Name, body.ExpectedRevision
	case "rename":
		if attached {
			var body struct {
				Name             *string `json:"name"`
				ExpectedRevision *int64  `json:"expected_revision"`
				BillToken        string  `json:"bill_token"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
				return change, source, mutation.Invalid
			}
			change.Name, change.ExpectedRevision, source = body.Name, body.ExpectedRevision, body.BillToken
		} else {
			var body struct {
				Name             *string `json:"name"`
				ExpectedRevision *int64  `json:"expected_revision"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
				return change, source, mutation.Invalid
			}
			change.Name, change.ExpectedRevision = body.Name, body.ExpectedRevision
		}
	case "request":
		var body struct {
			ExpectedRevision *int64 `json:"expected_revision"`
		}
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
			return change, source, mutation.Invalid
		}
		change.ExpectedRevision = body.ExpectedRevision
	case "decision":
		var body struct {
			ExpectedRevision *int64 `json:"expected_revision"`
			RequestRevision  *int64 `json:"request_revision"`
			MemberID         *uint  `json:"member_id"`
			Decision         string `json:"decision"`
			BillToken        string `json:"bill_token"`
		}
		if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, 4<<10, true); err != nil {
			return change, source, mutation.Invalid
		}
		change.ExpectedRevision, change.RequestRevision, change.MemberID, change.Decision, source = body.ExpectedRevision, body.RequestRevision, body.MemberID, body.Decision, body.BillToken
	default:
		return change, source, mutation.Invalid
	}
	return change, source, nil
}
func WriteParticipantResult(c *gin.Context, result ParticipantResult) {
	safehttp.JSONValue(c, 200, gin.H{"participant": ParticipantView{result.Participant, result.Participant.BindingState()}, "identity_revision": result.IdentityRevision})
}
func (h *BillHandler) CreateParticipant(c *gin.Context) { h.changeParticipant(c, "create") }
func (h *BillHandler) RenameParticipant(c *gin.Context) { h.changeParticipant(c, "rename") }
func (h *BillHandler) changeParticipant(c *gin.Context, operation string) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 63)
	if err != nil || id == 0 {
		safehttp.StopRejectedBody(c.Writer, c.Request)
		mutation.WriteError(c, mutation.Invalid)
		return
	}
	change, _, err := DecodeParticipantChange(c, operation, false)
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
	result, err := service.ChangeParticipant(c.Request.Context(), StandaloneParticipantCommand{Access: BillAccess{uint(id), safehttp.AccessToken(c)}, Change: change})
	if err != nil {
		mutation.WriteError(c, err)
		return
	}
	WriteParticipantResult(c, result)
}
