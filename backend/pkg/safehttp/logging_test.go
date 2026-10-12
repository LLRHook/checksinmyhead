package safehttp

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestAccessTokenPrefersBearerHeader(t *testing.T) {
	request := httptest.NewRequest("GET", "/?t=query-token", nil)
	request.Header.Set("Authorization", "Bearer header-token")
	context, _ := gin.CreateTestContext(httptest.NewRecorder())
	context.Request = request

	if token := AccessToken(context); token != "header-token" {
		t.Fatalf("got token %q, want header token", token)
	}
}

func TestAccessTokenFallsBackToQuery(t *testing.T) {
	request := httptest.NewRequest("GET", "/?t=query-token", nil)
	request.Header.Set("Authorization", "Basic credentials")
	context, _ := gin.CreateTestContext(httptest.NewRecorder())
	context.Request = request

	if token := AccessToken(context); token != "query-token" {
		t.Fatalf("got token %q, want query token", token)
	}
}

func TestFormatRequestLogOmitsQueryCredentials(t *testing.T) {
	request := httptest.NewRequest("GET", "/api/tabs/19?t=secret-token&m=member-secret", nil)
	line := FormatRequestLog(gin.LogFormatterParams{
		Request:    request,
		ClientIP:   "127.0.0.1",
		Method:     request.Method,
		StatusCode: 200,
	})
	if strings.Contains(line, "secret-token") || strings.Contains(line, "member-secret") {
		t.Fatalf("request log exposed query credentials: %q", line)
	}
	if !strings.Contains(line, "/api/tabs/19") {
		t.Fatalf("request path missing from log line: %q", line)
	}
}
