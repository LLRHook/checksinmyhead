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

// Step is a frozen migration payload; append versions instead of editing one.
type Step struct {
	Version  int
	Name     string
	Checksum string
	Epoch    int
	SQL      string
}

// Registry returns a private copy, and checks a separately pinned checksum before
// use. 0002 is reserved for separately approved receipt metadata, not an empty step.
func Registry() ([]Step, error) {
	steps := []Step{{1, "0001_baseline.sql", "d46084b1caae072be155d7e38c71eba986774853e7d004b08d19daa411992f55", CompatibilityEpoch, baselineSQL}}
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
		if step.SQL == "" || hex.EncodeToString(sum[:]) != step.Checksum {
			return errors.New("migration checksum mismatch")
		}
	}
	return nil
}
