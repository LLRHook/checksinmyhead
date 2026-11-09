package versionpolicy

import (
	"os"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

const defaultStoreURL = "https://apps.apple.com/app/id6746379502"

var stableVersionPattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

// Current resolves MINIMUM_SUPPORTED_APP_VERSION against the checked-in public
// availability record. With no environment the result is non-blocking.
func Current() Decision {
	return resolve(os.Getenv("MINIMUM_SUPPORTED_APP_VERSION"), publicAvailabilityJSON)
}

// Handler serves the client update policy. It is intentionally public: this
// endpoint is a release-policy hint, never an authorization boundary. The
// minimum is resolved once, when the handler is built.
func Handler() gin.HandlerFunc {
	return handlerFor(Current())
}

func handlerFor(decision Decision) gin.HandlerFunc {
	return func(c *gin.Context) {
		storeURL := strings.TrimSpace(os.Getenv("APP_STORE_URL"))
		if storeURL == "" {
			storeURL = defaultStoreURL
		}
		c.Header("Cache-Control", "no-store")
		c.JSON(200, gin.H{
			"minimum_supported_version": decision.Minimum,
			"store_url":                 storeURL,
			"capabilities": gin.H{
				"bill_creation_replay": gin.H{"version": 1, "key_format": "base64url-32"},
				"participant_identity": gin.H{"version": 2},
			},
		})
	}
}
