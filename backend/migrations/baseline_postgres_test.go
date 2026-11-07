//go:build integration

package migrations

import (
	"backend/internal/testpostgres"
	"testing"
)

func TestRunnerBaselineFootprintPostgres(t *testing.T) {
	db := testpostgres.Open(t)
	apply(t, db)
	if scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relkind='r'") != 10 ||
		scalar(t, db, "SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relkind='S'") != 9 {
		t.Fatal("wrong baseline plus ledger footprint")
	}
}
