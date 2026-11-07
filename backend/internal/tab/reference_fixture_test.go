package tab

import (
	billpkg "backend/internal/bill"
	"backend/internal/testidentity"
	"backend/pkg/models"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

// referenceAuthRequest is used explicitly by modern positive claim/read cases.
// Raw wire1 compatibility, malformed input and capability negatives still call
// authRequest directly. Known synthetic labels are translated at this test seam;
// the actual request sent to the application contains only scoped references.
func referenceAuthRequest(t *testing.T, db *gorm.DB, r *gin.Engine, method, path, body, token, member string) *httptest.ResponseRecorder {
	t.Helper()
	version := 0
	if method == "GET" {
		version = 2
	}
	if method == "PATCH" && (strings.Contains(path, "/items/") || strings.HasSuffix(path, "/assignments")) {
		parts := strings.Split(strings.Trim(path, "/"), "/")
		pos := 2
		if len(parts) > 4 && parts[1] == "tabs" {
			pos = 4
		}
		id, err := strconv.ParseUint(parts[pos], 10, 63)
		if err != nil {
			t.Fatal(err)
		}
		var value map[string]any
		if err := json.Unmarshal([]byte(body), &value); err != nil {
			t.Fatal(err)
		}
		convert := func(v any) {
			assignments, ok := v.([]any)
			if !ok {
				return
			}
			for _, entry := range assignments {
				a, ok := entry.(map[string]any)
				if !ok {
					t.Fatal("explicit reference fixture has a non-object assignment")
				}
				if label, ok := a["person_name"].(string); ok {
					p := testidentity.Participant(t, db, uint(id), label)
					delete(a, "person_name")
					a["participant_id"] = p.ID
				}
			}
		}
		if updates, ok := value["updates"].([]any); ok {
			for _, entry := range updates {
				u := entry.(map[string]any)
				convert(u["assignments"])
			}
		} else {
			convert(value["assignments"])
		}
		if _, present := value["expected_revision"]; !present {
			value["expected_revision"] = *testidentity.Revision(t, db, uint(id))
		}
		data, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		body = string(data)
		version = 2
	}
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if member != "" {
		req.Header.Set("X-Member-Token", member)
	}
	if version != 0 {
		req.Header.Set("X-Billington-Identity-Version", fmt.Sprint(version))
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func bindReferenceFixture(t *testing.T, db *gorm.DB, b models.Bill, label string, member, actor models.TabMember) {
	t.Helper()
	p := testidentity.Participant(t, db, b.ID, label)
	testidentity.Bind(t, db, b.ID, p.ID, member.ID, actor.ID)
}

func referenceUpdates(t *testing.T, db *gorm.DB, billID uint, updates []BillItemAssignmentsUpdate) []BillItemAssignmentsUpdate {
	t.Helper()
	next := append([]BillItemAssignmentsUpdate(nil), updates...)
	for i := range next {
		next[i].Assignments = append([]models.ItemAssignment(nil), next[i].Assignments...)
		for j := range next[i].Assignments {
			a := &next[i].Assignments[j]
			if a.ParticipantID == nil {
				p := testidentity.Participant(t, db, billID, a.PersonName)
				a.ParticipantID = &p.ID
				a.PersonName = ""
			}
		}
	}
	return next
}
func referenceTabCommand(t *testing.T, db *gorm.DB, c AssignmentCommand) AssignmentCommand {
	t.Helper()
	c.Updates = referenceUpdates(t, db, c.BillID, c.Updates)
	if c.ExpectedRevision == nil {
		c.ExpectedRevision = testidentity.Revision(t, db, c.BillID)
	}
	return c
}
func referenceBillCommand(t *testing.T, db *gorm.DB, c billpkg.ClaimCommand) billpkg.ClaimCommand {
	t.Helper()
	c.Updates = referenceUpdates(t, db, c.Access.BillID, c.Updates)
	if c.ExpectedRevision == nil {
		c.ExpectedRevision = testidentity.Revision(t, db, c.Access.BillID)
	}
	return c
}
func versionAuthRequest(r *gin.Engine, method, path, body, token, member string, version int) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if member != "" {
		req.Header.Set("X-Member-Token", member)
	}
	req.Header.Set("X-Billington-Identity-Version", fmt.Sprint(version))
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}
