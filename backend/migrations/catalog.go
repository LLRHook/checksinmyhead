package migrations

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"reflect"
	"strings"
)

// The v1 recognizer and ledger DDL are frozen independently of the baseline SQL.
// A newly supported legacy footprint must append a recognizer, never rewrite v1.
//
//go:embed catalog.sql
var catalogSQL string

//go:embed catalog-v1.json
var catalogManifest string

//go:embed ledger.sql
var ledgerSQL string

// Startup guard v2 is independently frozen; v1/history checksums stay unchanged.
//
//go:embed catalog-safety-v2.sql
var catalogSafetyV2SQL string

const catalogSafetyV2Checksum = "fa97060f905ba1bcdb4c5147dd21824f82e9ed7a7c757e3728b6bf499ce1bb00"

func validateRecognizer() error {
	if checksum(catalogSafetyV2SQL) != catalogSafetyV2Checksum || checksum(catalogSQL) != catalogQueryChecksum || checksum(catalogManifest) != catalogManifestChecksum || checksum(ledgerSQL) != ledgerChecksum || checksum(catalogSQL+catalogManifest+ledgerSQL) != recognizerChecksum {
		return errors.New("changed catalog recognizer")
	}
	return validateReceiptRecognizer()
}

type catalogObjects map[string]json.RawMessage

func catalog(ctx context.Context, q querier, schema string) (catalogObjects, error) {
	query := "SELECT key, value FROM (" + catalogSQL + ") frozen_catalog UNION ALL SELECT 'validation/catalog-safety-v2', to_jsonb(accepted) FROM (" + catalogSafetyV2SQL + ") safety"
	rows, err := q.QueryContext(ctx, query, schema)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	objects := catalogObjects{}
	safetyChecked := false
	for rows.Next() {
		var key string
		var value json.RawMessage
		if err = rows.Scan(&key, &value); err != nil {
			return nil, err
		}
		if key == "validation/catalog-safety-v2" {
			var accepted bool
			if safetyChecked || json.Unmarshal(value, &accepted) != nil || !accepted {
				return nil, errors.New("unsupported catalog enforcement")
			}
			safetyChecked = true
			continue
		}
		if _, duplicate := objects[key]; duplicate {
			return nil, errors.New("duplicate catalog object")
		}
		objects[key] = value
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if !safetyChecked {
		return nil, errors.New("missing catalog safety validation")
	}
	return objects, nil
}
func isLedger(key string) bool {
	return key == "relation/schema_migrations" || strings.Contains(key, "/schema_migrations/")
}
func hasBaselineObjects(objects catalogObjects) bool {
	for key := range objects {
		if !isLedger(key) {
			return true
		}
	}
	return false
}
func checkCatalog(objects catalogObjects, ledger, strict bool) error {
	var expected catalogObjects
	if err := json.Unmarshal([]byte(catalogManifest), &expected); err != nil {
		return err
	}
	for key, want := range expected {
		if isLedger(key) != ledger {
			continue
		}
		got, ok := objects[key]
		if !ok {
			return errors.New("missing catalog definition")
		}
		if !equalCatalogDefinition(want, got) {
			return errors.New("wrong catalog definition")
		}
	}
	if strict {
		for key := range objects {
			if isLedger(key) == ledger {
				if _, ok := expected[key]; !ok {
					return errors.New("unknown application definition")
				}
			}
		}
	}
	return nil
}

func equalCatalogDefinition(want, got json.RawMessage) bool {
	var a, b any
	left, right := json.NewDecoder(bytes.NewReader(want)), json.NewDecoder(bytes.NewReader(got))
	left.UseNumber()
	right.UseNumber()
	return left.Decode(&a) == nil && right.Decode(&b) == nil && reflect.DeepEqual(a, b)
}
