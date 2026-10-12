package config

import "testing"

func TestAppDomain(t *testing.T) {
	t.Run("uses default", func(t *testing.T) {
		t.Setenv("APP_DOMAIN", "")
		if got := AppDomain(); got != defaultAppDomain {
			t.Fatalf("AppDomain() = %q, want %q", got, defaultAppDomain)
		}
	})

	t.Run("uses configured domain", func(t *testing.T) {
		t.Setenv("APP_DOMAIN", "https://example.test")
		if got := AppDomain(); got != "https://example.test" {
			t.Fatalf("AppDomain() = %q, want configured domain", got)
		}
	})
}
