package migrations

import "testing"

func TestCatalogSafetyGuardV2Checksum(t *testing.T) {
	old := catalogSafetyV2SQL
	defer func() { catalogSafetyV2SQL = old }()
	catalogSafetyV2SQL += "\n-- synthetic changed guard"
	if validateRecognizer() == nil {
		t.Fatal("changed v2 guard accepted")
	}
}
