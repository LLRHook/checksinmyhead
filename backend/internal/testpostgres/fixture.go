//go:build integration

// Package testpostgres owns synthetic schemas for explicitly selected PG tests.
// It is excluded from production builds. Callers must initialize via the real
// migration runner; frozen SQL is only for legacy fixtures.
package testpostgres

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
)

func Open(t *testing.T, tracer ...pgx.QueryTracer) *sql.DB {
	t.Helper()
	dsn := os.Getenv("BILLINGTON_TEST_POSTGRES_DSN")
	if dsn == "" {
		t.Fatal("explicit integration selection requires BILLINGTON_TEST_POSTGRES_DSN; no skip-to-green")
	}
	cfg, err := safeConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	if len(tracer) > 0 {
		cfg.Tracer = tracer[0]
	}
	cfg.ConnectTimeout = 3 * time.Second
	nonce := make([]byte, 12)
	if _, err := rand.Read(nonce); err != nil {
		t.Fatal("cannot generate owned schema identity")
	}
	schema := "billington_test_" + hex.EncodeToString(nonce)
	identifier := pgx.Identifier{schema}.Sanitize()
	cfg.RuntimeParams["application_name"] = schema
	admin := stdlib.OpenDB(*cfg)
	admin.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = admin.Close() })
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := admin.ExecContext(ctx, "CREATE SCHEMA "+identifier); err != nil {
		t.Fatal("cannot create isolated test schema")
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if _, err := admin.ExecContext(ctx, "DROP SCHEMA "+identifier+" CASCADE"); err != nil {
			t.Error("owned test schema cleanup failed")
		}
	})
	cfg.RuntimeParams["search_path"] = schema
	db := stdlib.OpenDB(*cfg)
	db.SetMaxOpenConns(12)
	t.Cleanup(func() { _ = db.Close() })
	if err := db.PingContext(ctx); err != nil {
		t.Fatal("test PostgreSQL unavailable")
	}
	t.Logf("PostgreSQL isolated schema %s", schema)
	return db
}

// safeConfig is tested without connecting: neither unsafe primary nor fallback
// hosts, identities, schema overrides nor arbitrary libpq options are accepted.
func safeConfig(dsn string) (*pgx.ConnConfig, error) {
	cfg, err := pgx.ParseConfig(dsn)
	if err != nil {
		return nil, errors.New("invalid test-only PostgreSQL DSN")
	}
	local := func(host string) bool { return host == "127.0.0.1" || host == "::1" || host == "localhost" }
	if !local(cfg.Host) || cfg.Database != "billington_test" || cfg.User != "billington_test" {
		return nil, errors.New("refuse nonlocal host or non-test database")
	}
	for _, fallback := range cfg.Fallbacks {
		if !local(fallback.Host) {
			return nil, errors.New("refuse nonlocal fallback")
		}
	}
	for _, key := range []string{"options", "search_path"} {
		if _, ok := cfg.RuntimeParams[key]; ok {
			return nil, errors.New("refuse caller-supplied schema/options")
		}
	}

	return cfg, nil
}
