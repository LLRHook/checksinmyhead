package versionpolicy

import (
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func servePolicy(handler gin.HandlerFunc) *httptest.ResponseRecorder {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.GET("/api/app/version-policy", handler)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest("GET", "/api/app/version-policy", nil))
	return response
}

func TestHandlerReturnsConfiguredPolicyWithoutCaching(t *testing.T) {
	t.Setenv("APP_STORE_URL", "https://store.example/billington")
	// A record in which every storefront already offers 2.1.0.
	decision := resolve("2.1.0", recordJSON(t, entry("ios", "us", "2.1.0"), entry("ios", "ca", "2.2.0")))
	response := servePolicy(handlerFor(decision))
	if response.Code != 200 {
		t.Fatalf("expected 200, got %d", response.Code)
	}
	if response.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("policy response must not be cached")
	}
	if got := response.Body.String(); got != `{"capabilities":{"bill_creation_replay":{"key_format":"base64url-32","version":1},"participant_identity":{"version":2}},"minimum_supported_version":"2.1.0","store_url":"https://store.example/billington"}` {
		t.Fatalf("unexpected policy: %s", got)
	}
}

func TestHandlerFallsBackForInvalidMinimumVersion(t *testing.T) {
	t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", "2.1")
	t.Setenv("APP_STORE_URL", "")
	response := servePolicy(Handler())
	if got := response.Body.String(); got != `{"capabilities":{"bill_creation_replay":{"key_format":"base64url-32","version":1},"participant_identity":{"version":2}},"minimum_supported_version":"0.0.0","store_url":"https://apps.apple.com/app/id6746379502"}` {
		t.Fatalf("unexpected fallback policy: %s", got)
	}
}
