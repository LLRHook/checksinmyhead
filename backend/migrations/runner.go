package migrations

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"
)

const (
	MigrationTimeout = 60 * time.Second
	LockTimeout      = 5 * time.Second
	HealthTimeout    = time.Second
)

type Mode string

const (
	Apply  Mode = "apply"
	Verify Mode = "verify"
)

// State can only be created by a successfully committed schema validation. It
// pins readiness to that database/schema and to the binary's immutable prefix.
type State struct {
	db     *sql.DB
	schema string
	steps  []Step
}

// Error deliberately omits SQL, identifiers, DSNs and arbitrary driver messages.
// Unwrap retains typed cancellation/SQLSTATE diagnosis for trusted callers.
type Error struct {
	stage string
	cause error
}

func (e *Error) Error() string { return "schema initialization failed: " + e.stage }
func (e *Error) Unwrap() error { return e.cause }
func failure(ctx context.Context, stage string, err error) error {
	if ctx.Err() != nil {
		err = ctx.Err()
	}
	var pg interface{ SQLState() string }
	if errors.As(err, &pg) && pg.SQLState() == "55P03" {
		err = context.DeadlineExceeded
	}
	return &Error{stage, err}
}

// Run owns one Read Committed transaction. The schema-scoped transaction lock
// precedes every ledger read/create; a waiter reads the winner's committed state.
// All pending SQL, validation and ledger inserts commit together, or roll back.
func Run(ctx context.Context, db *sql.DB, mode Mode) (*State, error) {
	steps, err := Registry()
	if err != nil {
		return nil, failure(ctx, "registry", err)
	}
	return run(ctx, db, mode, steps)
}

func run(ctx context.Context, db *sql.DB, mode Mode, steps []Step) (state *State, runErr error) {
	if mode != Apply && mode != Verify {
		return nil, failure(ctx, "mode", nil)
	}
	if err := validateRegistry(steps); err != nil {
		return nil, failure(ctx, "registry", err)
	}
	if err := validateRecognizer(); err != nil {
		return nil, failure(ctx, "recognizer", err)
	}
	ctx, cancel := context.WithTimeout(ctx, MigrationTimeout)
	defer cancel()
	tx, err := db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return nil, failure(ctx, "begin", err)
	}
	defer func() {
		if err := tx.Rollback(); err != nil && !errors.Is(err, sql.ErrTxDone) {
			state = nil
			runErr = failure(ctx, "rollback", err)
		}
	}()
	var schema string
	if err = tx.QueryRowContext(ctx, "SELECT current_schema()").Scan(&schema); err != nil || schema == "" {
		return nil, failure(ctx, "target", err)
	}
	// Identifiers are quoted, never interpolated as SQL text or logged.
	if _, err = tx.ExecContext(ctx, "SELECT pg_catalog.set_config('search_path', $1, true)", quote(schema)); err != nil {
		return nil, failure(ctx, "target", err)
	}
	if _, err = tx.ExecContext(ctx, "SELECT pg_catalog.set_config('lock_timeout', '5s', true)"); err != nil {
		return nil, failure(ctx, "lock", err)
	}
	if _, err = tx.ExecContext(ctx, "SELECT pg_catalog.pg_advisory_xact_lock($1)", lockKey(schema)); err != nil {
		return nil, failure(ctx, "lock", err)
	}
	objects, err := catalog(ctx, tx, schema)
	if err != nil {
		return nil, failure(ctx, "catalog", err)
	}
	_, hasLedger := objects["relation/schema_migrations"]
	var history []record
	if hasLedger {
		if err = checkCatalog(objects, true, false); err != nil {
			return nil, failure(ctx, "ledger definition", err)
		}
		history, err = readHistory(ctx, tx, schema)
		if err != nil {
			return nil, failure(ctx, "history", err)
		}
		if err = checkHistory(history, steps, false); err != nil {
			return nil, failure(ctx, "history", err)
		}
		// Ledgered additions may extend the footprint, but cannot change any
		// required baseline definition. Unknown same-epoch versions are retained.
		if err = checkCatalog(objects, false, false); err != nil {
			return nil, failure(ctx, "baseline definition", err)
		}
	} else {
		if mode == Verify {
			return nil, failure(ctx, "required history", nil)
		}
		if hasBaselineObjects(objects) {
			if err = checkCatalog(objects, false, true); err != nil {
				return nil, failure(ctx, "legacy definition", err)
			}
			// Adoption records the frozen baseline without executing its DDL/DML.
			history = []record{fromStep(steps[0])}
		} else {
			if _, err = tx.ExecContext(ctx, steps[0].SQL); err != nil {
				return nil, failure(ctx, "baseline apply", err)
			}
		}
		if _, err = tx.ExecContext(ctx, ledgerSQL); err != nil {
			return nil, failure(ctx, "ledger create", err)
		}
		if len(history) > 0 {
			if err = insertRecord(ctx, tx, history[0]); err != nil {
				return nil, failure(ctx, "ledger insert", err)
			}
		}
	}
	if mode == Verify && len(history) < len(steps) {
		return nil, failure(ctx, "required history", nil)
	}
	for _, step := range steps[lenPrefix(history, steps):] {
		// Fresh baseline was already executed before ledger creation.
		if hasLedger || step.Version != 1 {
			if _, err = tx.ExecContext(ctx, step.SQL); err != nil {
				return nil, failure(ctx, "pending apply", err)
			}
		}
		if err = insertRecord(ctx, tx, fromStep(step)); err != nil {
			return nil, failure(ctx, "ledger insert", err)
		}
	}
	objects, err = catalog(ctx, tx, schema)
	if err != nil {
		return nil, failure(ctx, "catalog", err)
	}
	if err = checkCatalog(objects, false, false); err != nil {
		return nil, failure(ctx, "baseline definition", err)
	}
	if err = checkCatalog(objects, true, false); err != nil {
		return nil, failure(ctx, "ledger definition", err)
	}
	history, err = readHistory(ctx, tx, schema)
	if err != nil {
		return nil, failure(ctx, "history", err)
	}
	if err = checkHistory(history, steps, true); err != nil {
		return nil, failure(ctx, "required history", err)
	}
	if err = tx.Commit(); err != nil {
		return nil, failure(ctx, "commit", err)
	}
	return &State{db: db, schema: schema, steps: append([]Step(nil), steps...)}, nil
}

func lenPrefix(history []record, steps []Step) int {
	if len(history) > len(steps) {
		return len(steps)
	}
	return len(history)
}
func quote(identifier string) string { return `"` + strings.ReplaceAll(identifier, `"`, `""`) + `"` }
func lockKey(schema string) int64 {
	sum := sha256.Sum256([]byte("billington/schema-migrations/v1/" + schema))
	return int64(binary.BigEndian.Uint64(sum[:8]) & ((1 << 63) - 1))
}

type record struct {
	Version            int       `json:"version"`
	Name               string    `json:"name"`
	Checksum           string    `json:"checksum"`
	ValidationChecksum string    `json:"validation_checksum"`
	Epoch              int       `json:"compatibility_epoch"`
	AppliedAt          time.Time `json:"applied_at"`
}

func fromStep(s Step) record {
	return record{Version: s.Version, Name: s.Name, Checksum: s.Checksum, ValidationChecksum: recognizerChecksum, Epoch: s.Epoch}
}

var digestPattern = regexp.MustCompile(`^[0-9a-f]{64}$`)
var namePattern = regexp.MustCompile(`^[0-9]{4,}_[a-z0-9_]+\.sql$`)

func checkHistory(history []record, steps []Step, required bool) error {
	if len(history) == 0 || required && len(history) < len(steps) {
		return errors.New("missing history")
	}
	names := map[string]bool{}
	for i, r := range history {
		if r.Version != i+1 || r.Epoch != CompatibilityEpoch || !namePattern.MatchString(r.Name) || !strings.HasPrefix(r.Name, fmt.Sprintf("%04d_", r.Version)) || names[r.Name] || !digestPattern.MatchString(r.Checksum) || !digestPattern.MatchString(r.ValidationChecksum) || r.AppliedAt.IsZero() {
			return errors.New("invalid history")
		}
		names[r.Name] = true
		if i < len(steps) && (r.Name != steps[i].Name || r.Checksum != steps[i].Checksum || r.ValidationChecksum != recognizerChecksum) {
			return errors.New("changed history")
		}
	}
	return nil
}

type querier interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

func readHistory(ctx context.Context, q querier, schema string) ([]record, error) {
	var payload []byte
	err := q.QueryRowContext(ctx, `SELECT COALESCE(jsonb_agg(to_jsonb(m) ORDER BY version),'[]'::jsonb) FROM `+quote(schema)+`.schema_migrations m`).Scan(&payload)
	if err != nil {
		return nil, err
	}
	var rows []record
	err = json.Unmarshal(payload, &rows)
	return rows, err
}
func insertRecord(ctx context.Context, tx *sql.Tx, r record) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO schema_migrations(version,name,checksum,validation_checksum,compatibility_epoch) VALUES ($1,$2,$3,$4,$5)`, r.Version, r.Name, r.Checksum, r.ValidationChecksum, r.Epoch)
	return err
}

// Check is one bounded live database/ledger query. It does no accounting scans,
// provider calls, schema mutation, or cached readiness. Startup validated catalogs;
// operators must rerun verify after out-of-band DDL.
func (s *State) Check(ctx context.Context) error {
	if s == nil || s.db == nil {
		return errors.New("database not ready")
	}
	ctx, cancel := context.WithTimeout(ctx, HealthTimeout)
	defer cancel()
	history, err := readHistory(ctx, s.db, s.schema)
	if err != nil {
		return failure(ctx, "readiness", err)
	}
	if err = checkHistory(history, s.steps, true); err != nil {
		return failure(ctx, "readiness", err)
	}
	return nil
}

func checksum(payload string) string {
	sum := sha256.Sum256([]byte(payload))
	return hex.EncodeToString(sum[:])
}
