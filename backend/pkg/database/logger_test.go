package database

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"testing"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

const sensitive = "synthetic-bill-token/member-token/@payment/receipt-content\nforged-log-entry"

type stateError struct{ state string }

func (e stateError) Error() string    { return sensitive }
func (e stateError) SQLState() string { return e.state }

type forbiddenFormat struct{}

func (forbiddenFormat) String() string { panic("logger formatted an argument") }

func captureLogs(t *testing.T, f func()) string {
	t.Helper()
	var out bytes.Buffer
	old, flags, prefix := log.Writer(), log.Flags(), log.Prefix()
	log.SetOutput(&out)
	log.SetFlags(0)
	log.SetPrefix("")
	t.Cleanup(func() { log.SetOutput(old); log.SetFlags(flags); log.SetPrefix(prefix) })
	f()
	return out.String()
}

func assertNoSensitive(t *testing.T, output string) {
	t.Helper()
	for _, part := range strings.FieldsFunc(sensitive, func(r rune) bool { return r == '/' || r == '\n' }) {
		if strings.Contains(output, part) {
			t.Fatalf("sensitive marker escaped (output bytes=%d)", len(output))
		}
	}
}

func TestSQLLoggerSecrecyAtEveryLevel(t *testing.T) {
	for _, level := range []logger.LogLevel{logger.Silent, logger.Error, logger.Warn, logger.Info} {
		t.Run(fmt.Sprint(level), func(t *testing.T) {
			output := captureLogs(t, func() {
				l := (&sqlLogger{slowThreshold: time.Millisecond}).LogMode(level)
				l.Info(context.Background(), sensitive+" %v", forbiddenFormat{})
				l.Warn(context.Background(), sensitive+" %v", forbiddenFormat{})
				l.Error(context.Background(), sensitive+" %v", forbiddenFormat{})
				for _, query := range []string{
					`SELECT * FROM bills WHERE token = '` + sensitive + `'`,
					`INSERT INTO "person_shares" VALUES ('` + sensitive + `')`,
					`UPDATE "` + sensitive + `" SET token = 'x'`,
					sensitive + ` SELECT FROM tabs`,
					`SELECT '` + sensitive + ` FROM ` + sensitive,
				} {
					for _, err := range []error{nil, errors.New(sensitive), stateError{state: sensitive}, stateError{state: "23505"}, gorm.ErrRecordNotFound} {
						l.Trace(context.Background(), time.Now().Add(-time.Second), func() (string, int64) { return query, 7 }, err)
					}
				}
			})
			assertNoSensitive(t, output)
			if level == logger.Silent && output != "" {
				t.Fatal("silent logger wrote output")
			}
			if level >= logger.Error && !strings.Contains(output, "op=select table=bills class=constraint sqlstate=23505") {
				t.Fatal("lost safe diagnostic categories")
			}
			if level >= logger.Warn && !strings.Contains(output, "event=slow") {
				t.Fatal("missing slow diagnostic")
			}
		})
	}
}

func TestSQLLoggerParameterizedQueries(t *testing.T) {
	l := NewSQLLogger().(*sqlLogger)
	query, params := l.ParamsFilter(context.Background(), "SELECT * FROM bills WHERE token = $1", forbiddenFormat{})
	if query != "SELECT * FROM bills WHERE token = $1" || len(params) != 0 {
		t.Fatal("bind values retained")
	}
}

func TestSQLLoggerFastAndSilentDoNotEvaluateQuery(t *testing.T) {
	for _, level := range []logger.LogLevel{logger.Silent, logger.Error, logger.Warn} {
		l := &sqlLogger{level: level, slowThreshold: time.Hour}
		l.Trace(context.Background(), time.Now(), func() (string, int64) { t.Fatal("query callback evaluated"); return "", 0 }, nil)
	}
}

func TestSQLLoggerConfigurationIsSafe(t *testing.T) {
	for _, raw := range []string{sensitive, "-1", "0", "9223372036854775807", "9223372036855"} {
		t.Run(fmt.Sprintf("invalid-%d", len(raw)), func(t *testing.T) {
			t.Setenv("DB_SLOW_QUERY_MS", raw)
			output := captureLogs(t, func() {
				if slowQueryThreshold() != defaultSlowQueryThreshold {
					t.Fatal("unsafe threshold")
				}
			})
			assertNoSensitive(t, output)
			if output != "db logger: invalid DB_SLOW_QUERY_MS, using 500ms\n" {
				t.Fatal("invalid config not fixed text")
			}
		})
	}
	for _, tc := range []struct {
		raw  string
		want time.Duration
	}{{"", 500 * time.Millisecond}, {" 12 ", 12 * time.Millisecond}} {
		t.Setenv("DB_SLOW_QUERY_MS", tc.raw)
		if slowQueryThreshold() != tc.want {
			t.Fatal("threshold default/valid value changed")
		}
	}
}

func TestSQLLoggerClassificationsAreAllowlisted(t *testing.T) {
	for _, q := range []string{sensitive, "SELECT * FROM " + sensitive, strings.Repeat("x", 5000)} {
		op, table := classifySQL(q)
		assertNoSensitive(t, op+table)
		if table != "unknown" {
			t.Fatal("untrusted table accepted")
		}
	}
	for _, tc := range []struct {
		err          error
		class, state string
	}{
		{nil, "none", "none"}, {context.Canceled, "canceled", "none"}, {context.DeadlineExceeded, "timeout", "none"},
		{gorm.ErrRecordNotFound, "not_found", "none"}, {stateError{"23505"}, "constraint", "23505"},
		{stateError{"TOKEN"}, "database", "unknown"}, {stateError{sensitive}, "database", "unknown"},
		{fmt.Errorf("%s: %w", sensitive, stateError{"40P01"}), "transaction", "40P01"},
	} {
		class, state := errorMetadata(tc.err)
		if class != tc.class || state != tc.state {
			t.Fatal("incorrect safe error class")
		}
		assertNoSensitive(t, safeStartupError(tc.err).Error())
	}
}

func TestInitDBErrorsAreSafe(t *testing.T) {
	for _, k := range []string{"DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_SSLMODE"} {
		t.Setenv(k, "")
	}
	if _, err := InitDB(); err == nil || err.Error() != "missing required database environment variables" {
		t.Fatal("static missing-env guard changed")
	}
	// A parse failure occurs before any network operation, and embeds hostile env
	// text in the underlying driver error. Both returned and logged errors stay safe.
	t.Setenv("DB_HOST", "127.0.0.1")
	t.Setenv("DB_PORT", sensitive)
	t.Setenv("DB_NAME", "billington_test")
	t.Setenv("DB_USER", sensitive)
	t.Setenv("DB_PASSWORD", sensitive)
	t.Setenv("DB_SSLMODE", "disable")
	output := captureLogs(t, func() {
		db, err := InitDB()
		if db != nil || err == nil {
			t.Fatal("expected invalid configuration failure")
		}
		assertNoSensitive(t, err.Error())
		if !strings.HasPrefix(err.Error(), "database initialization failed:") {
			t.Fatal("unsanitized startup error")
		}
	})
	assertNoSensitive(t, output)
}
