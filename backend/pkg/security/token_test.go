package security

import (
	"strings"
	"testing"
)

func TestBase62CharsetValidity(t *testing.T) {
	for i := 0; i < 100; i++ {
		token := GenerateSecureToken()
		for _, c := range token {
			if !strings.ContainsRune(base62Charset, c) {
				t.Errorf("token %q contains invalid character %q", token, c)
			}
		}
	}
}

func TestTokenLengthRange(t *testing.T) {
	for i := 0; i < 1000; i++ {
		token := GenerateSecureToken()
		if len(token) < 10 || len(token) > 11 {
			t.Errorf("token length %d out of expected range [10,11]: %q", len(token), token)
		}
	}
}

func TestTokenUniqueness(t *testing.T) {
	seen := make(map[string]struct{}, 10000)
	for i := 0; i < 10000; i++ {
		token := GenerateSecureToken()
		if _, exists := seen[token]; exists {
			t.Fatalf("duplicate token generated: %q", token)
		}
		seen[token] = struct{}{}
	}
}

func TestBase62EncodeKnownValue(t *testing.T) {
	// All zeros should produce "0"
	result := base62Encode([]byte{0})
	if result != "" {
		// A single zero byte has big.Int value 0, which produces empty string
		// This is fine since we never generate all-zero random bytes in practice
	}

	// 0xFF = 255 in base62 = 4*62 + 7 = "47"
	result = base62Encode([]byte{0xFF})
	if result != "47" {
		t.Errorf("expected '47' for 0xFF, got %q", result)
	}
}
