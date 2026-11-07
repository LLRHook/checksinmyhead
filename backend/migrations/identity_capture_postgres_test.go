//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"encoding/json"
	"os"
	"testing"
)

// Capture real PostgreSQL17.11 definitions from exact SQL, never GORM/models.
// No environment variable means qualification checks the frozen capture instead.
func TestCaptureIdentity0003Catalog(t *testing.T) {
	path := os.Getenv("BILLINGTON_CAPTURE_IDENTITY_CATALOG")
	if path == "" {
		if err := validateIdentityRecognizer(); err != nil {
			t.Fatal(err)
		}
		return
	}
	db := testpostgres.Open(t)
	var version string
	if err := db.QueryRow("SHOW server_version_num").Scan(&version); err != nil || version != "170011" {
		t.Fatalf("capture requires pinned PG17.11: %s, %v", version, err)
	}
	execSQL(t, db, baselineSQL)
	execSQL(t, db, receiptSQL)
	execSQL(t, db, identitySQL)
	var schema string
	if err := db.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
		t.Fatal(err)
	}
	objects, err := catalog(context.Background(), db, schema)
	if err != nil {
		t.Fatal(err)
	}
	known := catalogObjects{}
	if err := json.Unmarshal([]byte(catalogManifest), &known); err != nil {
		t.Fatal(err)
	}
	var receipt catalogObjects
	if err := json.Unmarshal([]byte(receiptManifest), &receipt); err != nil {
		t.Fatal(err)
	}
	for k, v := range receipt {
		known[k] = v
	}
	additions := catalogObjects{}
	for k, v := range objects {
		if want, ok := known[k]; ok {
			if !equalCatalogDefinition(want, v) {
				t.Fatalf("0003 changed frozen definition %s", k)
			}
		} else {
			additions[k] = v
		}
	}
	data, err := json.MarshalIndent(additions, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
	t.Logf("captured %d independent v3 additions", len(additions))
}
