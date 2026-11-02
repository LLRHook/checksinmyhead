package database

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const defaultSlowQueryThreshold = 500 * time.Millisecond

type sqlLogger struct {
	level         logger.LogLevel
	slowThreshold time.Duration
}

func NewSQLLogger() logger.Interface {
	return &sqlLogger{level: logger.Warn, slowThreshold: slowQueryThreshold()}
}

func slowQueryThreshold() time.Duration {
	raw := strings.TrimSpace(os.Getenv("DB_SLOW_QUERY_MS"))
	if raw == "" {
		return defaultSlowQueryThreshold
	}
	ms, err := strconv.ParseInt(raw, 10, 64)
	// Bound conversion before multiplication; config text must never reach logs.
	if err != nil || ms <= 0 || ms > int64((1<<63-1)/time.Millisecond) {
		log.Print("db logger: invalid DB_SLOW_QUERY_MS, using 500ms")
		return defaultSlowQueryThreshold
	}
	return time.Duration(ms) * time.Millisecond
}

func (l *sqlLogger) LogMode(level logger.LogLevel) logger.Interface {
	copy := *l
	copy.level = level
	return &copy
}

// GORM may supply parameter-bearing errors through these methods, including
// connection failures. Message strings and arguments are deliberately discarded.
func (l *sqlLogger) Info(_ context.Context, _ string, _ ...interface{}) {
	if l.level >= logger.Info {
		log.Print("db event level=info")
	}
}
func (l *sqlLogger) Warn(_ context.Context, _ string, _ ...interface{}) {
	if l.level >= logger.Warn {
		log.Print("db event level=warn")
	}
}
func (l *sqlLogger) Error(_ context.Context, _ string, _ ...interface{}) {
	if l.level >= logger.Error {
		log.Print("db event level=error")
	}
}

// ParamsFilter prevents GORM from interpolating bind values for this logger.
// Trace still treats the resulting query as untrusted (raw SQL may have literals).
func (l *sqlLogger) ParamsFilter(_ context.Context, sql string, _ ...interface{}) (string, []interface{}) {
	return sql, nil
}

func (l *sqlLogger) Trace(_ context.Context, begin time.Time, fc func() (string, int64), err error) {
	if l.level <= logger.Silent {
		return
	}
	elapsed := time.Since(begin)
	event := "query"
	switch {
	case err != nil && !errors.Is(err, gorm.ErrRecordNotFound) && l.level >= logger.Error:
		event = "error"
	case elapsed >= l.slowThreshold && l.level >= logger.Warn:
		event = "slow"
	case l.level < logger.Info:
		return
	}
	sql, rows := fc()
	op, table := classifySQL(sql)
	class, state := errorMetadata(err)
	log.Printf("db event=%s elapsed=%s rows=%s op=%s table=%s class=%s sqlstate=%s",
		event, elapsed.Round(time.Millisecond), formatRows(rows), op, table, class, state)
}

// Only exact, finite categories can escape classification. Never return a token
// from SQL or a driver's error/message/detail/hint, even if it looks like an identifier.
func classifySQL(sql string) (string, string) {
	if len(sql) > 4096 {
		return "unknown", "unknown"
	}
	fields := strings.Fields(sql)
	if len(fields) == 0 {
		return "unknown", "unknown"
	}
	op := strings.ToLower(fields[0])
	switch op {
	case "select", "insert", "update", "delete", "create", "alter", "drop", "begin", "commit", "rollback":
	default:
		return "unknown", "unknown"
	}
	for i, field := range fields {
		word := strings.ToLower(field)
		if (op == "select" || op == "delete") && word == "from" || op == "insert" && word == "into" || op == "update" && i == 0 {
			if i+1 < len(fields) {
				return op, cleanIdentifier(fields[i+1])
			}
		}
	}
	return op, "unknown"
}

func cleanIdentifier(identifier string) string {
	switch strings.Trim(identifier, `"`) {
	case "bills":
		return "bills"
	case "bill_items":
		return "bill_items"
	case "people":
		return "people"
	case "bill_participants":
		return "bill_participants"
	case "item_assignments":
		return "item_assignments"
	case "person_shares":
		return "person_shares"
	case "tabs":
		return "tabs"
	case "tab_members":
		return "tab_members"
	case "tab_settlements":
		return "tab_settlements"
	case "schema_migrations":
		return "schema_migrations"
	default:
		return "unknown"
	}
}

func errorMetadata(err error) (string, string) {
	switch {
	case err == nil:
		return "none", "none"
	case errors.Is(err, context.Canceled):
		return "canceled", "none"
	case errors.Is(err, context.DeadlineExceeded):
		return "timeout", "none"
	case errors.Is(err, gorm.ErrRecordNotFound):
		return "not_found", "none"
	}
	var pg interface{ SQLState() string }
	if errors.As(err, &pg) {
		// SQLSTATE-shaped arbitrary strings are not safe either: exact allowlist only.
		switch state := pg.SQLState(); state {
		case "23502", "23503", "23505", "23514", "23P01":
			return "constraint", state
		case "40001", "40P01":
			return "transaction", state
		case "55P03", "57014":
			return "timeout", state
		case "08000", "08001", "08003", "08004", "08006", "08007", "08P01", "57P01", "57P02", "57P03", "53300":
			return "connection", state
		case "42P01", "42703", "42501", "42601":
			return "schema", state
		}
	}
	return "database", "unknown"
}

func safeStartupError(err error) error {
	class, state := errorMetadata(err)
	return fmt.Errorf("database initialization failed: class=%s sqlstate=%s", class, state)
}

func formatRows(rows int64) string {
	if rows < 0 {
		return "unknown"
	}
	return strconv.FormatInt(rows, 10)
}
