//go:build integration && replayperf

package main

import (
	"backend/internal/testpostgres"
	"backend/migrations"
	"context"
	"database/sql"
	"github.com/jackc/pgx/v5"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"testing"
)

func testpostgresOpenReplayMeasure(t *testing.T, q pgx.QueryTracer) *sql.DB {
	t.Helper()
	db := testpostgres.Open(t, q)
	if _, err := migrations.Run(context.Background(), db, migrations.Apply); err != nil {
		t.Fatal(err)
	}
	return db
}
func replayMeasureGorm(t *testing.T, db *sql.DB) *gorm.DB {
	t.Helper()
	g, err := gorm.Open(postgres.New(postgres.Config{Conn: db}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	return g
}
