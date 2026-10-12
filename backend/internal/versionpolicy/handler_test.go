package versionpolicy

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestHandlerReturnsConfiguredPolicyWithoutCaching(t *testing.T) {
	t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", "2.1.0")
	t.Setenv("APP_STORE_URL", "https://store.example/billington")
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.GET("/api/app/version-policy", Handler())
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest("GET", "/api/app/version-policy", nil))
	if response.Code != 200 {
		t.Fatalf("expected 200, got %d", response.Code)
	}
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("policy response must not be cached")
	}
	if got := response.Body.String(); got != `{"minimum_supported_version":"2.1.0","store_url":"https://store.example/billington"}` {
		t.Fatalf("unexpected policy: %s", got)
	}
}

func TestHandlerFallsBackForInvalidMinimumVersion(t *testing.T) {
	t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", "2.1")
	t.Setenv("APP_STORE_URL", "")
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.GET("/api/app/version-policy", Handler())
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest("GET", "/api/app/version-policy", nil))
	if got := response.Body.String(); got != `{"minimum_supported_version":"2.0.3","store_url":"https://apps.apple.com/app/id6746379502"}` {
		t.Fatalf("unexpected fallback policy: %s", got)
	}
}
