package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/safehttp"
	"backend/pkg/security"
	"github.com/gin-gonic/gin"
	"strconv"
	"time"
)

func DecodeClaim(c *gin.Context, single bool) ([]ItemAssignmentsUpdate, *int64, error) {
	version, ok := safehttp.IdentityVersion(c)
	if !ok {
		return nil, nil, mutation.Invalid
	}
	var itemID uint
	if single {
		id, err := strconv.ParseUint(c.Param("itemId"), 10, 63)
		if err != nil || id == 0 {
			safehttp.StopRejectedBody(c.Writer, c.Request)
			return nil, nil, mutation.Invalid
		}
		itemID = uint(id)
	}
	var expected *int64
	updates := []ItemAssignmentsUpdate{}
	if version == 1 {
		var input AssignmentUpdateInputs
		if single {
			var body struct {
				ExpectedUpdatedAt *string          `json:"expected_updated_at"`
				Assignments       AssignmentInputs `json:"assignments"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil {
				return nil, nil, mutation.Invalid
			}
			input = AssignmentUpdateInputs{{ItemID: itemID, ExpectedUpdatedAt: body.ExpectedUpdatedAt, Assignments: body.Assignments}}
		} else {
			var body struct {
				Updates AssignmentUpdateInputs `json:"updates"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, false); err != nil {
				return nil, nil, mutation.Invalid
			}
			input = body.Updates
		}
		if !AssignmentInputCountsValid(input) {
			return nil, nil, mutation.Invalid
		}
		for _, u := range input {
			if u.Assignments == nil {
				return nil, nil, mutation.Invalid
			}
			next, err := claimUpdate(u.ItemID, u.ExpectedUpdatedAt)
			if err != nil {
				return nil, nil, err
			}
			for _, a := range u.Assignments {
				next.Assignments = append(next.Assignments, models.ItemAssignment{PersonName: security.SanitizeString(a.PersonName), Percentage: a.Percentage})
			}
			updates = append(updates, next)
		}
	} else {
		var input referenceUpdateInputs
		if single {
			var body struct {
				ExpectedRevision  *int64                    `json:"expected_revision"`
				ExpectedUpdatedAt *string                   `json:"expected_updated_at"`
				Assignments       referenceAssignmentInputs `json:"assignments"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, true); err != nil {
				return nil, nil, mutation.Invalid
			}
			expected = body.ExpectedRevision
			input = referenceUpdateInputs{{ItemID: itemID, ExpectedUpdatedAt: body.ExpectedUpdatedAt, Assignments: body.Assignments}}
		} else {
			var body struct {
				ExpectedRevision *int64                `json:"expected_revision"`
				Updates          referenceUpdateInputs `json:"updates"`
			}
			if err := safehttp.DecodeJSON(c.Writer, c.Request, &body, safehttp.MutationBodyLimit, true); err != nil {
				return nil, nil, mutation.Invalid
			}
			expected = body.ExpectedRevision
			input = body.Updates
		}
		if expected == nil || *expected < 0 || len(input) == 0 || len(input) > 500 {
			return nil, nil, mutation.Invalid
		}
		count := 0
		for _, u := range input {
			count += len(u.Assignments)
			if u.Assignments == nil || len(u.Assignments) > 100 || count > 50000 {
				return nil, nil, mutation.Invalid
			}
		}
		for _, u := range input {
			next, err := claimUpdate(u.ItemID, u.ExpectedUpdatedAt)
			if err != nil {
				return nil, nil, err
			}
			for _, a := range u.Assignments {
				if a.ParticipantID == nil || *a.ParticipantID == 0 {
					return nil, nil, mutation.Invalid
				}
				next.Assignments = append(next.Assignments, models.ItemAssignment{ParticipantID: a.ParticipantID, Percentage: a.Percentage})
			}
			updates = append(updates, next)
		}
	}
	if err := ValidateAssignmentUpdates(updates); err != nil {
		return nil, nil, err
	}
	return updates, expected, nil
}
func claimUpdate(itemID uint, expected *string) (ItemAssignmentsUpdate, error) {
	next := ItemAssignmentsUpdate{ItemID: itemID, Assignments: []models.ItemAssignment{}}
	if expected != nil && *expected != "" {
		date, err := time.Parse(time.RFC3339Nano, *expected)
		if err != nil {
			return next, mutation.Invalid
		}
		next.ExpectedUpdatedAt = &date
	}
	return next, nil
}
func WriteClaimError(c *gin.Context, err error) {
	if err == ErrAssignmentConflict {
		c.JSON(409, gin.H{"error": "item changed; refresh and try again"})
		return
	}
	if err == ErrItemAlreadyPaid {
		c.JSON(409, gin.H{"error": "paid shares cannot be changed"})
		return
	}
	mutation.WriteError(c, err)
}
