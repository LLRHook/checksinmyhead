package tab

import (
	"backend/pkg/models"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

type assignmentValidationService struct {
	TabService
	updated      bool
	batchUpdates []BillItemAssignmentsUpdate
}

func (s *assignmentValidationService) GetTabAuth(uint) (*models.Tab, error) {
	return &models.Tab{ID: 7, AccessToken: "secret"}, nil
}

func (s *assignmentValidationService) GetMembers(uint) ([]models.TabMember, error) {
	return nil, nil
}

func (s *assignmentValidationService) UpdateBillItemAssignments(uint, uint, uint, []models.ItemAssignment, *time.Time) error {
	s.updated = true
	return nil
}

func (s *assignmentValidationService) UpdateBillItemAssignmentsBatch(_, _ uint, updates []BillItemAssignmentsUpdate) error {
	s.batchUpdates = updates
	return nil
}

func TestUpdateBillItemAssignmentsBatchPassesAllUpdatesTogether(t *testing.T) {
	gin.SetMode(gin.TestMode)
	service := &assignmentValidationService{}
	recorder := httptest.NewRecorder()
	ctx, _ := gin.CreateTestContext(recorder)
	ctx.Params = gin.Params{{Key: "id", Value: "7"}, {Key: "billId", Value: "9"}}
	body := `{"updates":[{"item_id":11,"expected_updated_at":"2026-10-12T20:00:00Z","assignments":[{"person_name":"Alex","percentage":100}]},{"item_id":12,"expected_updated_at":"2026-10-12T20:00:00Z","assignments":[]}]}`
	ctx.Request = httptest.NewRequest("PATCH", "/tabs/7/bills/9/assignments?t=secret", strings.NewReader(body))
	ctx.Request.Header.Set("Content-Type", "application/json")

	NewTabHandler(service).UpdateBillItemAssignmentsBatch(ctx)
	if recorder.Code != 200 || len(service.batchUpdates) != 2 {
		t.Fatalf("status = %d, updates = %#v", recorder.Code, service.batchUpdates)
	}
	if service.batchUpdates[0].ItemID != 11 || service.batchUpdates[1].ItemID != 12 {
		t.Fatalf("unexpected batch updates: %#v", service.batchUpdates)
	}
}

func TestUpdateBillItemAssignmentsRejectsInvalidSplits(t *testing.T) {
	gin.SetMode(gin.TestMode)

	for _, test := range []struct {
		name string
		body string
	}{
		{name: "over one hundred percent", body: `{"assignments":[{"person_name":"Alex","percentage":150}]}`},
		{name: "sum exceeds one hundred percent", body: `{"assignments":[{"person_name":"Alex","percentage":60},{"person_name":"Sam","percentage":60}]}`},
		{name: "duplicate person", body: `{"assignments":[{"person_name":"Alex","percentage":50},{"person_name":"alex","percentage":50}]}`},
		{name: "empty assignment name", body: `{"assignments":[{"person_name":" ","percentage":100}]}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			service := &assignmentValidationService{}
			recorder := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(recorder)
			ctx.Params = gin.Params{{Key: "id", Value: "7"}, {Key: "billId", Value: "9"}, {Key: "itemId", Value: "11"}}
			ctx.Request = httptest.NewRequest("PATCH", "/tabs/7/bills/9/items/11?t=secret", strings.NewReader(test.body))
			ctx.Request.Header.Set("Content-Type", "application/json")

			NewTabHandler(service).UpdateBillItemAssignments(ctx)

			if recorder.Code != 400 || service.updated {
				t.Fatalf("status = %d, update called = %t; want 400 without update", recorder.Code, service.updated)
			}
		})
	}
}

type creatorCheckService struct {
	TabService
	members []models.TabMember
	member  *models.TabMember
}

func (s creatorCheckService) GetMembers(uint) ([]models.TabMember, error) {
	return s.members, nil
}

func (s creatorCheckService) GetMemberByToken(string) (*models.TabMember, error) {
	return s.member, nil
}

func TestGetTabWithLookupAcceptsBearerAndShareQueryTokens(t *testing.T) {
	gin.SetMode(gin.TestMode)

	for _, test := range []struct {
		name   string
		path   string
		header string
	}{
		{name: "bearer header", header: "Bearer secret"},
		{name: "share query", path: "?t=secret"},
	} {
		t.Run(test.name, func(t *testing.T) {
			ctx, _ := gin.CreateTestContext(httptest.NewRecorder())
			ctx.Params = gin.Params{{Key: "id", Value: "42"}}
			ctx.Request = httptest.NewRequest("GET", "/tabs/42"+test.path, nil)
			ctx.Request.Header.Set("Authorization", test.header)

			lookupCalls := 0
			got := (&TabHandler{}).getTabWithLookup(ctx, func(id uint) (*models.Tab, error) {
				lookupCalls++
				if id != 42 {
					t.Fatalf("lookup id = %d, want 42", id)
				}
				return &models.Tab{ID: id, AccessToken: "secret"}, nil
			})

			if got == nil || got.ID != 42 || lookupCalls != 1 {
				t.Fatalf("lookup result = %v, calls = %d", got, lookupCalls)
			}
		})
	}
}

func TestGetTabWithLookupRejectsInvalidIDAndToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	for _, test := range []struct {
		name       string
		id         string
		token      string
		wantStatus int
	}{
		{name: "invalid id", id: "nope", token: "secret", wantStatus: 400},
		{name: "wrong token", id: "42", token: "wrong", wantStatus: 403},
	} {
		t.Run(test.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(recorder)
			ctx.Params = gin.Params{{Key: "id", Value: test.id}}
			ctx.Request = httptest.NewRequest("GET", "/tabs/"+test.id+"?t="+test.token, nil)

			lookupCalls := 0
			got := (&TabHandler{}).getTabWithLookup(ctx, func(id uint) (*models.Tab, error) {
				lookupCalls++
				return &models.Tab{ID: id, AccessToken: "secret"}, nil
			})

			if got != nil || recorder.Code != test.wantStatus {
				t.Fatalf("result = %v, status = %d, want %d", got, recorder.Code, test.wantStatus)
			}
			if test.id == "nope" && lookupCalls != 0 {
				t.Fatalf("lookup called %d times for invalid ID", lookupCalls)
			}
		})
	}
}

func TestRequireCreatorKeepsLegacyTabsAndRestrictsCollaborativeActions(t *testing.T) {
	gin.SetMode(gin.TestMode)

	for _, test := range []struct {
		name        string
		service     creatorCheckService
		wantAllowed bool
		wantError   string
	}{
		{name: "legacy tab without members", wantAllowed: true},
		{
			name: "creator",
			service: creatorCheckService{
				members: []models.TabMember{{TabID: 7}},
				member:  &models.TabMember{TabID: 7, MemberToken: "member", Role: "creator"},
			},
			wantAllowed: true,
		},
		{
			name: "regular member",
			service: creatorCheckService{
				members: []models.TabMember{{TabID: 7}},
				member:  &models.TabMember{TabID: 7, MemberToken: "member", Role: "member"},
			},
			wantError: "only the tab creator can finalize",
		},
	} {
		t.Run(test.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(recorder)
			ctx.Request = httptest.NewRequest("POST", "/tabs/7/finalize?m=member", nil)
			handler := NewTabHandler(test.service)
			allowed := handler.requireCreator(ctx, 7, "finalize")

			if allowed != test.wantAllowed {
				t.Fatalf("allowed = %t, want %t", allowed, test.wantAllowed)
			}
			if test.wantError != "" && !strings.Contains(recorder.Body.String(), test.wantError) {
				t.Fatalf("error = %q, want %q", recorder.Body.String(), test.wantError)
			}
		})
	}
}
