package migrations

import (
	_ "embed"
	"encoding/json"
	"errors"
)

//go:embed catalog-identity-v3.sql
var identityCatalogSQL string

//go:embed catalog-identity-v3.json
var identityManifest string

func validateIdentityRecognizer() error {
	if checksum(identitySQL) != identitySQLChecksum || checksum(identityCatalogSQL) != identityCatalogQueryChecksum || checksum(identityManifest) != identityManifestChecksum || checksum(catalogSQL+catalogManifest+ledgerSQL+catalogSafetyV2SQL+receiptManifest+identityCatalogSQL+identityManifest) != identityRecognizerChecksum {
		return errors.New("changed identity recognizer")
	}
	return nil
}

// Validate every independently captured definition before subtracting any keys.
// The caller owns this private view; the actual captured catalog stays intact.
func subtractIdentityCatalog(view catalogObjects) error {
	var additions catalogObjects
	if err := json.Unmarshal([]byte(identityManifest), &additions); err != nil {
		return err
	}
	if len(additions) != identityCatalogObjectCount {
		return errors.New("invalid identity manifest")
	}
	for key, want := range additions {
		got, ok := view[key]
		if !ok {
			return errors.New("missing identity definition")
		}
		if !equalCatalogDefinition(want, got) {
			return errors.New("wrong identity definition")
		}
	}
	for key := range additions {
		delete(view, key)
	}
	return nil
}
