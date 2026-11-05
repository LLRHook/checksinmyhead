package migrations

import (
	_ "embed"
	"encoding/json"
	"errors"
)

//go:embed catalog-receipt-v2.json
var receiptManifest string

func validateReceiptRecognizer() error {
	if checksum(receiptSQL) != receiptSQLChecksum || checksum(receiptManifest) != receiptManifestChecksum || checksum(catalogSQL+catalogManifest+ledgerSQL+catalogSafetyV2SQL+receiptManifest) != receiptRecognizerChecksum {
		return errors.New("changed receipt recognizer")
	}
	return nil
}

func checkApplicationCatalog(objects catalogObjects, history []record, steps []Step) error {
	// Never edit the captured map. Validate EVERY approved addition before removing
	// only those exact names from a private view of frozen baseline recognition.
	view := make(catalogObjects, len(objects))
	for k, v := range objects {
		view[k] = v
	}
	known := len(steps)
	if known >= 3 && len(history) >= 3 {
		if err := subtractIdentityCatalog(view); err != nil {
			return err
		}
	}
	if known >= 2 && len(history) >= 2 {
		var additions catalogObjects
		if err := json.Unmarshal([]byte(receiptManifest), &additions); err != nil {
			return err
		}
		if len(additions) != 9 {
			return errors.New("invalid receipt manifest")
		}
		for key, want := range additions {
			got, ok := view[key]
			if !ok {
				return errors.New("missing receipt definition")
			}
			// Reuse exact-number/structural comparison, never string-format matching.
			if !equalCatalogDefinition(want, got) {
				return errors.New("wrong receipt definition")
			}
		}
		for key := range additions {
			delete(view, key)
		}
	}
	// Unknown same-epoch suffixes may add definitions. A known prefix and strict
	// adoption cannot conceal arbitrary extras or partial/weak receipt objects.
	strict := len(history) <= known && len(history) <= 3
	return checkCatalog(view, false, strict)
}
