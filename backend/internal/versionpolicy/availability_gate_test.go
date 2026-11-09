package versionpolicy

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

// The helpers below are an independent oracle: they read the checked-in record
// and the served policy without using the package's own comparison code.

type oracleRelease struct {
	Platform   string `json:"platform"`
	Storefront string `json:"storefront"`
	Version    string `json:"version"`
}

func oracleParts(t *testing.T, version string) [3]int {
	t.Helper()
	var parts [3]int
	fields := strings.Split(version, ".")
	if len(fields) != 3 {
		t.Fatalf("version %q is not major.minor.patch", version)
	}
	for index, field := range fields {
		value, err := strconv.Atoi(field)
		if err != nil || value < 0 {
			t.Fatalf("version %q is not numeric", version)
		}
		parts[index] = value
	}
	return parts
}

func oracleCompare(t *testing.T, left, right string) int {
	t.Helper()
	leftParts, rightParts := oracleParts(t, left), oracleParts(t, right)
	for index := range leftParts {
		if leftParts[index] != rightParts[index] {
			if leftParts[index] < rightParts[index] {
				return -1
			}
			return 1
		}
	}
	return 0
}

func checkedInReleases(t *testing.T) []oracleRelease {
	t.Helper()
	raw, err := os.ReadFile("public_availability.json")
	if err != nil {
		t.Fatalf("read checked-in public availability record: %v", err)
	}
	var record struct {
		Releases []oracleRelease `json:"releases"`
	}
	if err := json.Unmarshal(raw, &record); err != nil {
		t.Fatalf("decode checked-in public availability record: %v", err)
	}
	if len(record.Releases) == 0 {
		t.Fatal("checked-in public availability record lists no release")
	}
	return record.Releases
}

func lowestCheckedInVersion(t *testing.T) string {
	t.Helper()
	releases := checkedInReleases(t)
	lowest := releases[0].Version
	for _, release := range releases[1:] {
		if oracleCompare(t, release.Version, lowest) < 0 {
			lowest = release.Version
		}
	}
	return lowest
}

func servedMinimum(t *testing.T) string {
	t.Helper()
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.GET("/api/app/version-policy", Handler())
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest("GET", "/api/app/version-policy", nil))
	if response.Code != 200 {
		t.Fatalf("expected 200, got %d", response.Code)
	}
	var body struct {
		Minimum string `json:"minimum_supported_version"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode policy: %v", err)
	}
	return body.Minimum
}

func nextPatch(t *testing.T, version string) string {
	t.Helper()
	parts := oracleParts(t, version)
	return strconv.Itoa(parts[0]) + "." + strconv.Itoa(parts[1]) + "." + strconv.Itoa(parts[2]+1)
}

// The source default must be safe with no environment at all: a fresh deploy
// may never tell a public binary that it needs a version no store offers.
func TestSourceDefaultMinimumNeverExceedsPublicAvailability(t *testing.T) {
	t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", "")
	t.Setenv("APP_STORE_URL", "")
	lowest := lowestCheckedInVersion(t)
	if got := servedMinimum(t); oracleCompare(t, got, lowest) > 0 {
		t.Fatalf("source default minimum %s exceeds publicly available %s", got, lowest)
	}
}

// An operator minimum above every recorded public release must not be served:
// it would lock out users for whom the store has no satisfying binary.
func TestConfiguredMinimumAbovePublicAvailabilityIsNotEnforced(t *testing.T) {
	lowest := lowestCheckedInVersion(t)
	for _, configured := range []string{nextPatch(t, lowest), "2.0.3", "999.0.0"} {
		if oracleCompare(t, configured, lowest) <= 0 {
			continue
		}
		t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", configured)
		if got := servedMinimum(t); got != "0.0.0" {
			t.Fatalf("configured %s above public %s was served as %s; want non-blocking 0.0.0", configured, lowest, got)
		}
	}
}

// Enforcement stays available once the store offers a satisfying binary.
func TestConfiguredMinimumWithinPublicAvailabilityIsEnforced(t *testing.T) {
	lowest := lowestCheckedInVersion(t)
	t.Setenv("MINIMUM_SUPPORTED_APP_VERSION", lowest)
	if got := servedMinimum(t); got != lowest {
		t.Fatalf("configured %s equal to public availability was served as %s", lowest, got)
	}
}
