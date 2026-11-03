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

func validateRecognizer() error {
	if checksum(catalogSQL) != catalogQueryChecksum || checksum(catalogManifest) != catalogManifestChecksum || checksum(ledgerSQL) != ledgerChecksum || checksum(catalogSQL+catalogManifest+ledgerSQL) != recognizerChecksum {
		return errors.New("changed catalog recognizer")
	}
	return nil
}

type catalogObjects map[string]json.RawMessage

func catalog(ctx context.Context, q querier, schema string) (catalogObjects, error) {
	rows, err := q.QueryContext(ctx, catalogSQL, schema)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	objects := catalogObjects{}
	for rows.Next() {
		var key string
		var value json.RawMessage
		if err = rows.Scan(&key, &value); err != nil {
			return nil, err
		}
		if _, duplicate := objects[key]; duplicate {
			return nil, errors.New("duplicate catalog object")
		}
		objects[key] = value
	}
	return objects, rows.Err()
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
		var a, b any
		left, right := json.NewDecoder(bytes.NewReader(want)), json.NewDecoder(bytes.NewReader(got))
		left.UseNumber()
		right.UseNumber()
		if left.Decode(&a) != nil || right.Decode(&b) != nil || !reflect.DeepEqual(a, b) {
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
