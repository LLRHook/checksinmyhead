// Package healthcheck implements the service binaries' local liveness probe.
package healthcheck

import (
	"encoding/json"
	"io"
	"net/http"
	"time"
)

const (
	requestTimeout = 2 * time.Second
	maxBodyBytes   = 4096
)

// ExitCode returns 0 only for a bounded, successful health response. Callers use
// a fixed loopback URL and dispatch this mode before initializing the database.
// No response content or transport error is logged by the probe.
func ExitCode(address, expectedStatus string) int {
	return probe(address, expectedStatus, requestTimeout)
}

func probe(address, expectedStatus string, timeout time.Duration) int {
	transport := &http.Transport{
		// A local probe must not inherit HTTP_PROXY or transparently decompress an
		// unbounded response. The body limit applies to the bytes we actually read.
		DisableCompression: true,
		DisableKeepAlives:  true,
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{
		Transport: transport,
		Timeout:   timeout,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	response, err := client.Get(address)
	if err != nil {
		return 1
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return 1
	}
	body, err := io.ReadAll(io.LimitReader(response.Body, maxBodyBytes+1))
	if err != nil || len(body) > maxBodyBytes {
		return 1
	}
	var health struct {
		Status string `json:"status"`
		Commit string `json:"commit"`
	}
	if json.Unmarshal(body, &health) != nil || health.Status != expectedStatus {
		return 1
	}
	return 0
}
