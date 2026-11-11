//go:build integration

package readiness

import (
	"backend/internal/testpostgres"
	"backend/migrations"
	"context"
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPostgresHealthContract(t *testing.T) {
	for _, status := range []string{"bill service - ok"} {
		t.Run(status, func(t *testing.T) {
			t.Setenv("RENDER_GIT_COMMIT", "synthetic-tested-sha")
			db := testpostgres.Open(t)
			state, err := migrations.Run(context.Background(), db, migrations.Apply)
			if err != nil {
				t.Fatal(err)
			}
			r := gin.New()
			r.GET("/health", Handler(state, status))
			probe := func(want int, wantStatus string) {
				t.Helper()
				w := httptest.NewRecorder()
				r.ServeHTTP(w, httptest.NewRequest("GET", "/health", nil))
				var body map[string]string
				if json.Unmarshal(w.Body.Bytes(), &body) != nil || w.Code != want || len(body) != 2 || body["status"] != wantStatus || body["commit"] != "synthetic-tested-sha" {
					t.Fatalf("wrong health contract: %d %s", w.Code, w.Body.String())
				}
			}
			probe(200, status)
			if _, err = db.Exec("UPDATE schema_migrations SET checksum=repeat('a',64)"); err != nil {
				t.Fatal(err)
			}
			probe(503, "service unavailable")
			db.Close()
			probe(503, "service unavailable")
		})
	}
	t.Run("unvalidated_startup", func(t *testing.T) {
		db := testpostgres.Open(t)
		if _, err := db.Exec("CREATE TABLE bills(wrong text)"); err != nil {
			t.Fatal(err)
		}
		state, err := migrations.Run(context.Background(), db, migrations.Apply)
		if err == nil {
			t.Fatal("wrong schema ready")
		}
		r := gin.New()
		r.GET("/health", Handler(state, "bill service - ok"))
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest("GET", "/health", nil))
		if w.Code != 503 {
			t.Fatal("failed startup returned ready health")
		}
	})
}
