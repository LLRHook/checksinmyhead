//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"context"
	"encoding/json"
	"os"
	"testing"
)

// This opt-in capture uses an isolated owned PG schema; checked-in independent
// literals, not current GORM models, remain the recognition authority.
func TestCaptureReceiptCatalog(t *testing.T) {
	path := os.Getenv("BILLINGTON_CAPTURE_RECEIPT_CATALOG")
	if path == "" { // Ordinary qualification checks the independent pinned manifest.
		if validateReceiptRecognizer() != nil {
			t.Fatal("receipt recognizer changed")
		}
		return
	}
	db := testpostgres.Open(t)
	execSQL(t, db, baselineSQL)
	sql, err := os.ReadFile("0002_receipt_replay_display.sql")
	if err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, string(sql))
	var schema string
	if err := db.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
		t.Fatal(err)
	}
	objects, err := catalog(context.Background(), db, schema)
	if err != nil {
		t.Fatal(err)
	}
	baseline := catalogObjects{}
	if err := json.Unmarshal([]byte(catalogManifest), &baseline); err != nil {
		t.Fatal(err)
	}
	additions := catalogObjects{}
	for k, v := range objects {
		if _, ok := baseline[k]; !ok {
			additions[k] = v
		}
	}
	if len(additions) != 9 {
		t.Fatalf("want nine additions, got%d", len(additions))
	}
	data, err := json.MarshalIndent(additions, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
}
