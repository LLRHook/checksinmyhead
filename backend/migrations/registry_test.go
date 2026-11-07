package migrations

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestFrozenBaselineRegistry(t *testing.T) {
	steps, err := Registry()
	if err != nil || len(steps) != 3 {
		t.Fatal("baseline registry invalid")
	}
	if steps[0].Version != 1 || steps[0].Epoch != 1 || steps[0].Name != "0001_baseline.sql" {
		t.Fatal("baseline metadata changed")
	}
	sql := steps[0].SQL
	if strings.Contains(sql, "public.") || strings.Contains(sql, "\\") || strings.Contains(sql, "AutoMigrate") {
		t.Fatal("dump not normalized")
	}
	for _, line := range strings.Split(sql, "\n") {
		if strings.HasPrefix(line, "SET ") || strings.HasPrefix(line, "SELECT ") || strings.HasPrefix(line, "UPDATE ") {
			t.Fatal("session/data mutation in baseline")
		}
	}
	if strings.Count(sql, "CREATE TABLE ") != 9 || strings.Count(sql, "CREATE SEQUENCE ") != 8 {
		t.Fatal("frozen baseline object count changed")
	}
	steps[0].SQL = "changed"
	copy, err := Registry()
	if err != nil || copy[0].SQL == "changed" {
		t.Fatal("caller changed immutable registry")
	}
}

func TestInvalidRegistryFailsClosed(t *testing.T) {
	steps, _ := Registry()
	for _, name := range []string{"gap", "checksum", "epoch", "duplicate", "name", "empty"} {
		t.Run(name, func(t *testing.T) {
			candidate := append([]Step{}, steps...)
			switch name {
			case "gap":
				candidate[0].Version = 2
			case "checksum":
				candidate[0].SQL += "\n"
			case "epoch":
				candidate[0].Epoch++
			case "duplicate":
				candidate = append(candidate, candidate[0])
			case "name":
				candidate[0].Name = "synthetic-hostile-name\n"
			case "empty":
				candidate = nil
			}
			if validateRegistry(candidate) == nil {
				t.Fatal("invalid registry accepted")
			}
		})
	}
}

func TestFrozenCatalogRecognizer(t *testing.T) {
	if err := validateRecognizer(); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"query", "manifest", "ledger"} {
		t.Run(name, func(t *testing.T) {
			a, b, c := catalogSQL, catalogManifest, ledgerSQL
			defer func() { catalogSQL, catalogManifest, ledgerSQL = a, b, c }()
			switch name {
			case "query":
				catalogSQL += "\n"
			case "manifest":
				catalogManifest += "\n"
			case "ledger":
				ledgerSQL += "\n"
			}
			if validateRecognizer() == nil {
				t.Fatal("changed recognition payload accepted")
			}
		})
	}
	if MigrationTimeout != 60*time.Second || LockTimeout != 5*time.Second || HealthTimeout != time.Second {
		t.Fatal("approved budgets changed")
	}
}

func TestUnknownRunnerModeFailsBeforeDatabaseAccess(t *testing.T) {
	if state, err := Run(context.Background(), nil, Mode("synthetic-hostile-mode")); state != nil || err == nil || strings.Contains(err.Error(), "synthetic-hostile-mode") {
		t.Fatal("unknown mode did not fail safely")
	}
}

func TestIdentity0003RecognizerPinsAndPrivateView(t *testing.T) {
	for _, name := range []string{"sql", "query", "manifest"} {
		t.Run(name, func(t *testing.T) {
			a, b, c := identitySQL, identityCatalogSQL, identityManifest
			defer func() { identitySQL, identityCatalogSQL, identityManifest = a, b, c }()
			switch name {
			case "sql":
				identitySQL += "\n"
			case "query":
				identityCatalogSQL += "\n"
			case "manifest":
				identityManifest += "\n"
			}
			if validateRecognizer() == nil {
				t.Fatal("changed independently pinned identity payload accepted")
			}
		})
	}
	var objects catalogObjects
	if err := json.Unmarshal([]byte(catalogManifest), &objects); err != nil {
		t.Fatal(err)
	}
	for _, manifest := range []string{receiptManifest, identityManifest} {
		var additions catalogObjects
		if err := json.Unmarshal([]byte(manifest), &additions); err != nil {
			t.Fatal(err)
		}
		for k, v := range additions {
			objects[k] = v
		}
	}
	before, _ := json.Marshal(objects)
	steps, _ := Registry()
	history := []record{fromStep(steps[0]), fromStep(steps[1]), fromStep(steps[2])}
	if err := checkApplicationCatalog(objects, history, steps); err != nil {
		t.Fatal(err)
	}
	after, _ := json.Marshal(objects)
	if string(before) != string(after) {
		t.Fatal("recognition mutated actual catalog")
	}
	for k := range objects {
		if strings.HasPrefix(k, "column/bill_participants/") {
			copy := make(catalogObjects, len(objects))
			for k, v := range objects {
				copy[k] = v
			}
			delete(copy, k)
			if checkApplicationCatalog(copy, history, steps) == nil {
				t.Fatal("missing known definition accepted")
			}
		}
	}
}
