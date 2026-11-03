package startup

import (
	"backend/migrations"
	"strings"
	"testing"
)

func TestSharedStartupModes(t *testing.T) {
	for _, tc := range []struct {
		name            string
		args            []string
		mode            migrations.Mode
		migrate, health bool
	}{
		{name: "default", mode: migrations.Apply},
		{name: "apply", args: []string{"--schema-mode=apply"}, mode: migrations.Apply},
		{name: "verify", args: []string{"--schema-mode=verify"}, mode: migrations.Verify},
		{name: "migration_only", args: []string{"--migrate-only"}, mode: migrations.Apply, migrate: true},
		{name: "health", args: []string{"--healthcheck"}, mode: migrations.Apply, health: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			o, err := Parse(tc.args)
			if err != nil || o.SchemaMode != tc.mode || o.MigrateOnly != tc.migrate || o.Healthcheck != tc.health {
				t.Fatal("wrong startup dispatch", err)
			}
		})
	}
}
func TestInvalidStartupArgumentsAreSanitized(t *testing.T) {
	hostile := "synthetic-token\npassword=value"
	for _, args := range [][]string{
		{"--schema-mode=" + hostile}, {"--schema-mode="}, {"--schema-mode=other"},
		{"--migrate-only", "--schema-mode=verify"}, {"--healthcheck", "--migrate-only"},
		{"--healthcheck=false", "--schema-mode=verify"}, {"--unknown=" + hostile}, {hostile},
		{"--migrate-only=" + hostile}, {"--verify-only"},
	} {
		_, err := Parse(args)
		if err == nil || err.Error() != "invalid service arguments" || strings.Contains(err.Error(), hostile) {
			t.Fatal("unsafe or accepted invalid CLI")
		}
	}
}
