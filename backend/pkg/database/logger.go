package database

import (
	"context"
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
	return &sqlLogger{
		level:         logger.Warn,
		slowThreshold: slowQueryThreshold(),
	}
}

func slowQueryThreshold() time.Duration {
	raw := strings.TrimSpace(os.Getenv("DB_SLOW_QUERY_MS"))
	if raw == "" {
		return defaultSlowQueryThreshold
	}

	ms, err := strconv.Atoi(raw)
	if err != nil || ms <= 0 {
		log.Printf("db logger: invalid DB_SLOW_QUERY_MS=%q, using %s", raw, defaultSlowQueryThreshold)
		return defaultSlowQueryThreshold
	}
	return time.Duration(ms) * time.Millisecond
}

func (l *sqlLogger) LogMode(level logger.LogLevel) logger.Interface {
	copy := *l
	copy.level = level
	return &copy
}

func (l *sqlLogger) Info(ctx context.Context, msg string, args ...interface{}) {
	if l.level >= logger.Info {
		log.Printf("db info: "+msg, args...)
	}
}

func (l *sqlLogger) Warn(ctx context.Context, msg string, args ...interface{}) {
	if l.level >= logger.Warn {
		log.Printf("db warn: "+msg, args...)
	}
}

func (l *sqlLogger) Error(ctx context.Context, msg string, args ...interface{}) {
	if l.level >= logger.Error {
		log.Printf("db error: "+msg, args...)
	}
}

func (l *sqlLogger) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	if l.level <= logger.Silent {
		return
	}

	elapsed := time.Since(begin)

	if err != nil && err != gorm.ErrRecordNotFound && l.level >= logger.Error {
		sql, rows := fc()
		op, table := classifySQL(sql)
		log.Printf("db query error elapsed=%s rows=%s op=%s table=%s err=%q sql=%q",
			elapsed.Round(time.Millisecond),
			formatRows(rows),
			op,
			table,
			err,
			sql,
		)
		return
	}

	if elapsed >= l.slowThreshold && l.level >= logger.Warn {
		sql, rows := fc()
		op, table := classifySQL(sql)
		log.Printf("db slow query elapsed=%s threshold=%s rows=%s op=%s table=%s sql=%q",
			elapsed.Round(time.Millisecond),
			l.slowThreshold,
			formatRows(rows),
			op,
			table,
			sql,
		)
	}
}

func classifySQL(sql string) (string, string) {
	fields := strings.Fields(sql)
	if len(fields) == 0 {
		return "unknown", "unknown"
	}

	op := strings.ToLower(fields[0])
	for i, field := range fields {
		normalized := strings.ToLower(strings.Trim(field, " \t\n\r(),"))
		switch {
		case op == "select" && normalized == "from" && i+1 < len(fields):
			return op, cleanIdentifier(fields[i+1])
		case op == "insert" && normalized == "into" && i+1 < len(fields):
			return op, cleanIdentifier(fields[i+1])
		case op == "update" && i == 0 && i+1 < len(fields):
			return op, cleanIdentifier(fields[i+1])
		case op == "delete" && normalized == "from" && i+1 < len(fields):
			return op, cleanIdentifier(fields[i+1])
		}
	}

	return op, "unknown"
}

func cleanIdentifier(identifier string) string {
	cleaned := strings.Trim(identifier, " \t\n\r,;()")
	cleaned = strings.Trim(cleaned, `"`)
	if cleaned == "" {
		return "unknown"
	}
	return cleaned
}

func formatRows(rows int64) string {
	if rows < 0 {
		return "unknown"
	}
	return fmt.Sprintf("%d", rows)
}
