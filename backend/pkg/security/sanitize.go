package security

import (
	"regexp"
	"strings"
)

var htmlTagRegex = regexp.MustCompile(`<[^>]*>`)

// SanitizeString strips HTML tags and trims whitespace from user input.
// This prevents stored XSS when values are rendered in web contexts.
func SanitizeString(s string) string {
	// A tag match must start with '<'. Most participant names contain none;
	// avoid the regexp replacement's copies when there cannot be a match.
	if strings.Contains(s, "<") {
		s = htmlTagRegex.ReplaceAllString(s, "")
	}
	s = strings.TrimSpace(s)
	return s
}
