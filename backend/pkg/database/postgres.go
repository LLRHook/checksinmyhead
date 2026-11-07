package database

import (
	"backend/migrations"
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func InitDB(ctx context.Context, mode migrations.Mode) (*gorm.DB, *migrations.State, error) {
	ctx, cancel := context.WithTimeout(ctx, migrations.MigrationTimeout)
	defer cancel()
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	name := os.Getenv("DB_NAME")
	user := os.Getenv("DB_USER")
	pw := os.Getenv("DB_PASSWORD")
	sslmode := os.Getenv("DB_SSLMODE")

	if host == "" || port == "" || name == "" || user == "" || pw == "" {
		return nil, nil, fmt.Errorf("missing required database environment variables")
	}

	if sslmode == "" {
		sslmode = "require"
	}

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=America/New_York", host, user, pw, name, port, sslmode)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger:               NewSQLLogger(),
		DisableAutomaticPing: true,
	})
	if err != nil {
		return nil, nil, safeStartupError(err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, nil, safeStartupError(err)
	}
	sqlDB.SetMaxOpenConns(envInt("DB_MAX_OPEN_CONNS", 10))
	sqlDB.SetMaxIdleConns(envInt("DB_MAX_IDLE_CONNS", 5))
	sqlDB.SetConnMaxLifetime(time.Duration(envInt("DB_CONN_MAX_LIFETIME_MINUTES", 30)) * time.Minute)
	sqlDB.SetConnMaxIdleTime(time.Duration(envInt("DB_CONN_MAX_IDLE_MINUTES", 5)) * time.Minute)

	// Current models never define historical DDL. This also retires the old
	// unchecked payer backfill: historical attribution is preserved verbatim.
	state, err := migrations.Run(ctx, sqlDB, mode)
	if err != nil {
		_ = sqlDB.Close()
		return nil, nil, safeStartupError(err)
	}
	return db, state, nil
}

func envInt(name string, fallback int) int {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}
