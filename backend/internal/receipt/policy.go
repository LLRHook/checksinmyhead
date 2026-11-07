package receipt

import (
	"errors"
	"strconv"
	"time"
)

const (
	maxReceiptSize   = 10 << 20 // Total multipart bytes, including boundaries.
	operationTimeout = 40 * time.Second
	providerTimeout  = 30 * time.Second
	maxResponseSize  = 2 << 20
	maxTextSize      = 512 << 10
	maxPeerKeys      = 4096
	peerWindow       = time.Minute
	sweepInterval    = 15 * time.Second
)

type policy struct{ slots int }

func parsePolicy(value string) (policy, error) {
	if value == "" {
		return policy{slots: 2}, nil
	}
	// Configuration errors are finite and never echo supplied values.
	n, err := strconv.Atoi(value)
	if err != nil || len(value) != 1 || n < 1 || n > 8 {
		return policy{}, errors.New("invalid OCR policy")
	}
	return policy{slots: n}, nil
}
