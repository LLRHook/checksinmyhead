package tab

import (
	"backend/pkg/models"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

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
