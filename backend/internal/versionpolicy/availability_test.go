package versionpolicy

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

func entry(platform, storefront, version string) release {
	return release{
		Platform:   platform,
		Storefront: storefront,
		AppID:      "6746379502",
		Version:    version,
		MinimumOS:  "15.5",
		ReleasedOn: "2026-08-26",
		VerifiedOn: "2026-11-09",
		Evidence:   "https://itunes.apple.com/lookup?id=6746379502&country=" + storefront,
	}
}

func recordJSON(t *testing.T, releases ...release) []byte {
	t.Helper()
	if releases == nil {
		releases = []release{}
	}
	raw, err := json.Marshal(availabilityRecord{Schema: 1, Releases: releases})
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestCheckedInPublicAvailabilityRecordIsValid(t *testing.T) {
	releases, ok := parseAvailability(publicAvailabilityJSON)
	if !ok {
		t.Fatal("checked-in public_availability.json must pass strict validation")
	}
	if len(releases) == 0 {
		t.Fatal("checked-in public_availability.json must record at least one public release")
	}
}

func TestResolveServesConfiguredMinimumOnlyWithinEveryRecordedRelease(t *testing.T) {
	cases := []struct {
		name       string
		configured string
		releases   []release
		minimum    string
		reason     Reason
	}{
		{"unset is non-blocking", "", []release{entry("ios", "us", "2.1.0")}, "0.0.0", ReasonMinimumUnset},
		{"blank is non-blocking", "  ", []release{entry("ios", "us", "2.1.0")}, "0.0.0", ReasonMinimumUnset},
		{"review defect: 2.0.3 against public 1.4.0", "2.0.3", []release{entry("ios", "us", "1.4.0")}, "0.0.0", ReasonMinimumAboveAvailability},
		{"equal to the only release", "1.4.0", []release{entry("ios", "us", "1.4.0")}, "1.4.0", ReasonEnforced},
		{"below the only release", "1.3.9", []release{entry("ios", "us", "1.4.0")}, "1.3.9", ReasonEnforced},
		{"surrounding spaces are trimmed", " 1.4.0 ", []release{entry("ios", "us", "1.4.0")}, "1.4.0", ReasonEnforced},
		{"numeric, not lexical", "2.9.0", []release{entry("ios", "us", "2.10.0")}, "2.9.0", ReasonEnforced},
		{"numeric, not lexical (reverse)", "2.10.0", []release{entry("ios", "us", "2.9.9")}, "0.0.0", ReasonMinimumAboveAvailability},
		{"one lagging storefront blocks the raise", "2.1.0", []release{entry("ios", "us", "2.1.0"), entry("ios", "ca", "2.0.11")}, "0.0.0", ReasonMinimumAboveAvailability},
		{"one lagging platform blocks the raise", "2.1.0", []release{entry("ios", "us", "2.1.0"), entry("android", "us", "2.0.0")}, "0.0.0", ReasonMinimumAboveAvailability},
		{"every storefront and platform satisfies it", "2.1.0", []release{entry("ios", "us", "2.1.0"), entry("ios", "ca", "2.1.1"), entry("android", "us", "2.2.0")}, "2.1.0", ReasonEnforced},
		{"no recorded release", "1.0.0", nil, "0.0.0", ReasonAvailabilityMissing},
		{"two-part minimum", "2.1", []release{entry("ios", "us", "9.0.0")}, "0.0.0", ReasonMinimumInvalid},
		{"prerelease minimum", "2.1.0-beta", []release{entry("ios", "us", "9.0.0")}, "0.0.0", ReasonMinimumInvalid},
		{"overflowing minimum", "99999999999999999999.0.0", []release{entry("ios", "us", "9.0.0")}, "0.0.0", ReasonMinimumInvalid},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			got := resolve(test.configured, recordJSON(t, test.releases...))
			if got.Minimum != test.minimum || got.Reason != test.reason {
				t.Fatalf("resolve(%q) = %+v, want {%s %s}", test.configured, got, test.minimum, test.reason)
			}
			if got.Enforced() != (test.reason == ReasonEnforced) {
				t.Fatalf("Enforced() disagrees with reason %s", got.Reason)
			}
		})
	}
}

// Exhaustive over a small grid: whatever is configured and recorded, the served
// minimum is non-blocking or satisfied by every recorded release.
func TestResolveNeverServesMinimumAboveAnyRecordedRelease(t *testing.T) {
	var versions []string
	for major := 0; major <= 2; major++ {
		for _, minor := range []int{0, 10} {
			for _, patch := range []int{3, 11} {
				versions = append(versions, fmt.Sprintf("%d.%d.%d", major, minor, patch))
			}
		}
	}
	enforced := 0
	for _, configured := range versions {
		for _, first := range versions {
			for _, second := range versions {
				raw := recordJSON(t, entry("ios", "us", first), entry("ios", "ca", second))
				got := resolve(configured, raw)
				served, ok := parseVersion(got.Minimum)
				if !ok {
					t.Fatalf("served minimum %q is not numeric", got.Minimum)
				}
				if got.Minimum == NonBlockingMinimum {
					continue
				}
				enforced++
				for _, available := range []string{first, second} {
					parsed, _ := parseVersion(available)
					if compareVersions(served, parsed) > 0 {
						t.Fatalf("configured %s served %s above recorded %s", configured, got.Minimum, available)
					}
				}
			}
		}
	}
	if enforced == 0 {
		t.Fatal("grid never enforced a minimum; the property was not exercised")
	}
}

func TestInvalidPublicAvailabilityRecordFailsToNonBlocking(t *testing.T) {
	valid := entry("ios", "us", "9.0.0")
	mutate := func(change func(*release)) []release {
		changed := valid
		change(&changed)
		return []release{changed}
	}
	marshal := func(releases []release) string {
		return string(recordJSON(t, releases...))
	}
	records := map[string]string{
		"empty file":              ``,
		"not json":                `not json`,
		"wrong top-level type":    `[]`,
		"null":                    `null`,
		"unknown schema":          `{"schema":2,"releases":[]}`,
		"missing schema":          `{"releases":[]}`,
		"unknown top-level field": `{"schema":1,"releases":[],"waiver":true}`,
		"unknown release field":   strings.Replace(marshal([]release{valid}), `"platform"`, `"override":"x","platform"`, 1),
		"trailing document":       marshal([]release{valid}) + `{}`,
		"unknown platform":        marshal(mutate(func(r *release) { r.Platform = "web" })),
		"uppercase storefront":    marshal(mutate(func(r *release) { r.Storefront = "US" })),
		"missing storefront":      marshal(mutate(func(r *release) { r.Storefront = "" })),
		"missing app id":          marshal(mutate(func(r *release) { r.AppID = "" })),
		"two-part version":        marshal(mutate(func(r *release) { r.Version = "9.0" })),
		"prerelease version":      marshal(mutate(func(r *release) { r.Version = "9.0.0-rc1" })),
		"overflowing version":     marshal(mutate(func(r *release) { r.Version = "99999999999999999999.0.0" })),
		"missing minimum os":      marshal(mutate(func(r *release) { r.MinimumOS = "" })),
		"bad release date":        marshal(mutate(func(r *release) { r.ReleasedOn = "26 Aug 2026" })),
		"missing verified date":   marshal(mutate(func(r *release) { r.VerifiedOn = "" })),
		"verified before release": marshal(mutate(func(r *release) { r.VerifiedOn = "2026-08-25" })),
		"non-https evidence":      marshal(mutate(func(r *release) { r.Evidence = "http://itunes.apple.com/lookup" })),
		"missing evidence":        marshal(mutate(func(r *release) { r.Evidence = "" })),
		"duplicate storefront":    marshal([]release{valid, valid}),
	}
	for name, raw := range records {
		t.Run(name, func(t *testing.T) {
			got := resolve("1.0.0", []byte(raw))
			if got.Minimum != NonBlockingMinimum || got.Reason != ReasonAvailabilityInvalid {
				t.Fatalf("invalid record served %+v", got)
			}
		})
	}
	// The unmodified entry is valid, so each case above fails for its own defect.
	if got := resolve("1.0.0", recordJSON(t, valid)); !got.Enforced() {
		t.Fatalf("control record must enforce, got %+v", got)
	}
}

func TestStartupNoticeIsFixedAndNeverEchoesOperatorInput(t *testing.T) {
	const marker = "7.7.7"
	decisions := []Decision{
		resolve(marker, recordJSON(t, entry("ios", "us", "9.0.0"))),
		resolve("", recordJSON(t, entry("ios", "us", "9.0.0"))),
		resolve(marker+"-secret", recordJSON(t, entry("ios", "us", "9.0.0"))),
		resolve(marker, recordJSON(t)),
		resolve(marker, recordJSON(t, entry("ios", "us", "1.4.0"))),
		resolve(marker, []byte(`{"schema":2,"note":"`+marker+`"}`)),
	}
	wantReasons := []Reason{
		ReasonEnforced, ReasonMinimumUnset, ReasonMinimumInvalid,
		ReasonAvailabilityMissing, ReasonMinimumAboveAvailability, ReasonAvailabilityInvalid,
	}
	seen := map[string]bool{}
	for index, decision := range decisions {
		if decision.Reason != wantReasons[index] {
			t.Fatalf("decision %d reason = %s, want %s", index, decision.Reason, wantReasons[index])
		}
		notice := decision.StartupNotice()
		if notice == "" || strings.Contains(notice, marker) || seen[notice] {
			t.Fatalf("notice for %s must be fixed, distinct and free of operator input: %q", decision.Reason, notice)
		}
		seen[notice] = true
		if !decision.Enforced() && decision.Reason != ReasonMinimumUnset && !strings.Contains(notice, "WARNING") {
			t.Fatalf("rejected configuration must warn: %q", notice)
		}
	}
}
