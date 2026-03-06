package security

import (
	"regexp"
	"strings"
)

var htmlTagRegex = regexp.MustCompile(`<[^>]*>`)

// SanitizeString strips HTML tags and trims whitespace from user input.
// This prevents stored XSS when values are rendered in web contexts.
func SanitizeString(s string) string {
	s = htmlTagRegex.ReplaceAllString(s, "")
	s = strings.TrimSpace(s)
	return s
}
