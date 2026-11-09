package versionpolicy

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"io"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// publicAvailabilityJSON is the reviewed record of the binaries each targeted
// store actually offers. A minimum version is served only when every recorded
// release satisfies it, so raising enforcement needs a reviewed change to this
// file first. See docs/backend-api.md (GET /api/app/version-policy).
//
//go:embed public_availability.json
var publicAvailabilityJSON []byte

// NonBlockingMinimum is the minimum every client version satisfies.
const NonBlockingMinimum = "0.0.0"

// Reason states why a Decision serves its minimum. Values are fixed and never
// contain operator input.
type Reason string

const (
	ReasonEnforced                 Reason = "enforced"
	ReasonMinimumUnset             Reason = "minimum_unset"
	ReasonMinimumInvalid           Reason = "minimum_invalid"
	ReasonAvailabilityInvalid      Reason = "public_availability_invalid"
	ReasonAvailabilityMissing      Reason = "public_availability_missing"
	ReasonMinimumAboveAvailability Reason = "minimum_exceeds_public_availability"
)

// Decision is the minimum the policy endpoint serves and why.
type Decision struct {
	Minimum string
	Reason  Reason
}

// Enforced reports whether the operator's configured minimum is being served.
func (d Decision) Enforced() bool { return d.Reason == ReasonEnforced }

// StartupNotice is a fixed operator message for the startup log.
func (d Decision) StartupNotice() string {
	switch d.Reason {
	case ReasonEnforced:
		return "version policy: configured minimum is enforced; every recorded public release satisfies it"
	case ReasonMinimumUnset:
		return "version policy: no minimum configured; serving the non-blocking policy"
	case ReasonMinimumInvalid:
		return "version policy WARNING: MINIMUM_SUPPORTED_APP_VERSION is not numeric major.minor.patch; serving the non-blocking policy"
	case ReasonAvailabilityMissing:
		return "version policy WARNING: no public release is recorded; serving the non-blocking policy"
	case ReasonMinimumAboveAvailability:
		return "version policy WARNING: MINIMUM_SUPPORTED_APP_VERSION exceeds a recorded public release; serving the non-blocking policy"
	default:
		return "version policy WARNING: public availability record is invalid; serving the non-blocking policy"
	}
}

type release struct {
	Platform   string `json:"platform"`
	Storefront string `json:"storefront"`
	AppID      string `json:"app_id"`
	Version    string `json:"version"`
	MinimumOS  string `json:"minimum_os"`
	ReleasedOn string `json:"released_on"`
	VerifiedOn string `json:"verified_on"`
	Evidence   string `json:"evidence"`
}

type availabilityRecord struct {
	Schema   int       `json:"schema"`
	Releases []release `json:"releases"`
}

var (
	storefrontPattern = regexp.MustCompile(`^[a-z]{2}$`)
	appIDPattern      = regexp.MustCompile(`^[A-Za-z0-9._]{1,128}$`)
	osVersionPattern  = regexp.MustCompile(`^[0-9]{1,4}(\.[0-9]{1,4}){0,2}$`)
)

// parseVersion accepts only the numeric major.minor.patch form the mobile
// client can compare.
func parseVersion(value string) ([3]int, bool) {
	var parts [3]int
	if !stableVersionPattern.MatchString(value) {
		return parts, false
	}
	for index, field := range strings.Split(value, ".") {
		parsed, err := strconv.ParseUint(field, 10, 31)
		if err != nil {
			return parts, false
		}
		parts[index] = int(parsed)
	}
	return parts, true
}

func compareVersions(left, right [3]int) int {
	for index := range left {
		if left[index] < right[index] {
			return -1
		}
		if left[index] > right[index] {
			return 1
		}
	}
	return 0
}

// parseAvailability strictly decodes a record. Any defect rejects the whole
// record: a partly trusted record could hide a storefront that lags behind.
func parseAvailability(raw []byte) ([]release, bool) {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	var record availabilityRecord
	if err := decoder.Decode(&record); err != nil {
		return nil, false
	}
	if _, err := decoder.Token(); err != io.EOF {
		return nil, false
	}
	if record.Schema != 1 {
		return nil, false
	}
	seen := make(map[string]bool, len(record.Releases))
	for _, entry := range record.Releases {
		if entry.Platform != "ios" && entry.Platform != "android" {
			return nil, false
		}
		if !storefrontPattern.MatchString(entry.Storefront) ||
			!appIDPattern.MatchString(entry.AppID) ||
			!osVersionPattern.MatchString(entry.MinimumOS) {
			return nil, false
		}
		if _, ok := parseVersion(entry.Version); !ok {
			return nil, false
		}
		released, err := time.Parse("2006-01-02", entry.ReleasedOn)
		if err != nil {
			return nil, false
		}
		verified, err := time.Parse("2006-01-02", entry.VerifiedOn)
		if err != nil || verified.Before(released) {
			return nil, false
		}
		evidence, err := url.Parse(entry.Evidence)
		if err != nil || evidence.Scheme != "https" || evidence.Host == "" {
			return nil, false
		}
		key := entry.Platform + "/" + entry.Storefront
		if seen[key] {
			return nil, false
		}
		seen[key] = true
	}
	return record.Releases, true
}

// resolve returns the minimum to serve for an operator value and a raw record.
// The configured minimum is served only when it is valid and no recorded
// release is older than it; every other case serves NonBlockingMinimum.
func resolve(configured string, rawRecord []byte) Decision {
	nonBlocking := func(reason Reason) Decision {
		return Decision{Minimum: NonBlockingMinimum, Reason: reason}
	}
	configured = strings.TrimSpace(configured)
	if configured == "" {
		return nonBlocking(ReasonMinimumUnset)
	}
	minimum, ok := parseVersion(configured)
	if !ok {
		return nonBlocking(ReasonMinimumInvalid)
	}
	releases, ok := parseAvailability(rawRecord)
	if !ok {
		return nonBlocking(ReasonAvailabilityInvalid)
	}
	if len(releases) == 0 {
		return nonBlocking(ReasonAvailabilityMissing)
	}
	for _, entry := range releases {
		available, _ := parseVersion(entry.Version)
		if compareVersions(minimum, available) > 0 {
			return nonBlocking(ReasonMinimumAboveAvailability)
		}
	}
	return Decision{Minimum: configured, Reason: ReasonEnforced}
}
