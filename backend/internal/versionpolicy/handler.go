package versionpolicy

import (
	"os"
	"regexp"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	defaultMinimumVersion = "2.0.3"
	defaultStoreURL       = "https://apps.apple.com/app/id6746379502"
)

var stableVersionPattern = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

// Handler serves the client update policy. It is intentionally public: this
// endpoint is a release-policy hint, never an authorization boundary.
func Handler() gin.HandlerFunc {
	return func(c *gin.Context) {
		minimum := strings.TrimSpace(os.Getenv("MINIMUM_SUPPORTED_APP_VERSION"))
		if !stableVersionPattern.MatchString(minimum) {
			minimum = defaultMinimumVersion
		}
		storeURL := strings.TrimSpace(os.Getenv("APP_STORE_URL"))
		if storeURL == "" {
			storeURL = defaultStoreURL
		}
		c.Header("Cache-Control", "no-store")
		c.JSON(200, gin.H{
			"minimum_supported_version": minimum,
			"store_url":                 storeURL,
		})
	}
}
