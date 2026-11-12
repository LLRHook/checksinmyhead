//go:build integration

package startup

import (
	"backend/internal/testpostgres"
	"context"
	"database/sql"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

// Execute the actual API binary. PostgreSQL schema selection
// comes only from our owned random fixture, never a caller supplied schema/options.
// No serving process or application port is started by this test.
func TestPostgresServiceBinaryModes(t *testing.T) {
	for _, service := range []string{"bill-service"} {
		t.Run(service, func(t *testing.T) {
			bin := filepath.Join(t.TempDir(), service)
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()
			build := exec.CommandContext(ctx, "go", "build", "-o", bin, "./cmd/"+service)
			build.Dir = "../.."
			if output, err := build.CombinedOutput(); err != nil {
				t.Fatalf("binary build: %v; context=%v; process=%v; output=%s", err, ctx.Err(), build.ProcessState, output)
			}
			db := testpostgres.Open(t)
			var schema string
			if err := db.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
				t.Fatal(err)
			}
			cfg, err := pgx.ParseConfig(os.Getenv("BILLINGTON_TEST_POSTGRES_DSN"))
			if err != nil {
				t.Fatal("fixture config")
			}
			childEnv := []string{}
			// Avoid ambient provider config, DB redirects and arbitrary libpq options.
			for _, key := range []string{"PATH", "HOME", "TMPDIR", "GOCACHE", "GOTOOLCHAIN"} {
				if value, ok := os.LookupEnv(key); ok {
					childEnv = append(childEnv, key+"="+value)
				}
			}
			childEnv = append(childEnv, "DB_HOST="+cfg.Host, "DB_PORT="+strconv.Itoa(int(cfg.Port)), "DB_USER="+cfg.User, "DB_NAME="+cfg.Database, "DB_PASSWORD="+cfg.Password, "DB_SSLMODE=disable", "PGOPTIONS=-csearch_path="+schema)
			invoke := func(wantSuccess bool, args ...string) {
				t.Helper()
				ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				defer cancel()
				command := exec.CommandContext(ctx, bin, args...)
				command.Env = childEnv
				output, err := command.CombinedOutput()
				if ctx.Err() != nil {
					t.Fatal("binary served or hung instead of exiting")
				}
				if (err == nil) != wantSuccess {
					t.Fatalf("binary mode result: %v %s", err, output)
				}
				if strings.Contains(string(output), cfg.Password) || strings.Contains(string(output), schema) {
					t.Fatal("binary leaked database config")
				}
			}
			invoke(false, "--schema-mode=verify") // exits before serving an empty schema
			if count(t, db) != 0 {
				t.Fatal("verify-only wrote ledger")
			}
			invoke(true, "--migrate-only")
			if count(t, db) != 1 {
				t.Fatal("migration-only failed to initialize owned schema")
			}
			if _, err = db.Exec(`INSERT INTO tabs(id,name) VALUES(1,'Legacy trip');
 INSERT INTO bills(id,tab_id,added_by_member_id,paid_by_member_id,name,subtotal,tax,tip_amount,total,date)
 VALUES(1,1,71,NULL,'Null payer',10,0,0,10,now())`); err != nil {
				t.Fatal(err)
			}
			invoke(true, "--migrate-only")
			var preserved bool
			if err = db.QueryRow("SELECT paid_by_member_id IS NULL FROM bills WHERE id=1").Scan(&preserved); err != nil || !preserved {
				t.Fatal("startup rewrote historical payer")
			}
			if _, err = db.Exec("UPDATE schema_migrations SET compatibility_epoch=2"); err != nil {
				t.Fatal(err)
			}
			invoke(false, "--schema-mode=verify")
			invoke(false, "--migrate-only")
			invoke(false, "--schema-mode=hostile-synthetic-token")
			db.Close()
			invoke(false, "--healthcheck", "--migrate-only")
		})
	}
}
func count(t *testing.T, db *sql.DB) int {
	t.Helper()
	var n int
	if err := db.QueryRow("SELECT count(*) FROM pg_class WHERE relnamespace=current_schema()::regnamespace AND relname='schema_migrations'").Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}
