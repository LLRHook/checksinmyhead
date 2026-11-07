// Package migrations contains the immutable PostgreSQL registry.
package migrations

import (
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

const CompatibilityEpoch = 1

//go:embed 0001_baseline.sql
var baselineSQL string

//go:embed 0002_receipt_replay_display.sql
var receiptSQL string

//go:embed 0003_participant_identity.sql
var identitySQL string

// Step is a frozen migration payload; append versions instead of editing one.
type Step struct {
	ValidationChecksum string
	Version            int
	Name               string
	Checksum           string
	Epoch              int
	SQL                string
}

// Registry returns a private copy of independently pinned additive steps.
func Registry() ([]Step, error) {
	steps := []Step{
		{Version: 1, Name: "0001_baseline.sql", Checksum: "d46084b1caae072be155d7e38c71eba986774853e7d004b08d19daa411992f55", ValidationChecksum: recognizerChecksum, Epoch: CompatibilityEpoch, SQL: baselineSQL},
		{Version: 2, Name: "0002_receipt_replay_display.sql", Checksum: receiptSQLChecksum, ValidationChecksum: receiptRecognizerChecksum, Epoch: CompatibilityEpoch, SQL: receiptSQL},
		{Version: 3, Name: "0003_participant_identity.sql", Checksum: identitySQLChecksum, ValidationChecksum: identityRecognizerChecksum, Epoch: CompatibilityEpoch, SQL: identitySQL},
	}
	if err := validateRegistry(steps); err != nil {
		return nil, err
	}
	return steps, nil
}

func validateRegistry(steps []Step) error {
	if len(steps) == 0 {
		return errors.New("invalid migration registry")
	}
	names := map[string]bool{}
	for i, step := range steps {
		if step.Version != i+1 || step.Epoch != CompatibilityEpoch || names[step.Name] || !strings.HasPrefix(step.Name, fmt.Sprintf("%04d_", step.Version)) || !namePattern.MatchString(step.Name) {
			return errors.New("invalid migration registry")
		}
		names[step.Name] = true
		sum := sha256.Sum256([]byte(step.SQL))
		if step.SQL == "" || hex.EncodeToString(sum[:]) != step.Checksum || !digestPattern.MatchString(step.ValidationChecksum) {
			return errors.New("migration checksum mismatch")
		}
	}
	return nil
}
