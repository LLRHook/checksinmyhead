package healthcheck

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestProbeResponses(t *testing.T) {
	for _, test := range []struct {
		name string
		code int
		body string
		want int
	}{
		{"healthy", 200, `{"status":"bill service - ok","commit":"synthetic"}`, 0},
		{"web healthy", 200, `{"status":"web service - ok","commit":""}`, 0},
		{"non-200", 503, `{"status":"bill service - ok"}`, 1},
		{"empty", 200, ``, 1},
		{"malformed", 200, `{"status":`, 1},
		{"wrong status", 200, `{"status":"unhealthy"}`, 1},
		{"missing status", 200, `{"commit":"synthetic"}`, 1},
		{"wrong type", 200, `{"status":true}`, 1},
		{"null", 200, `null`, 1},
		{"trailing JSON", 200, `{"status":"bill service - ok"}{}`, 1},
		{"oversized", 200, `{"status":"bill service - ok"}` + strings.Repeat(" ", maxBodyBytes), 1},
	} {
		t.Run(test.name, func(t *testing.T) {
			var requests atomic.Int32
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				requests.Add(1)
				if r.Method != http.MethodGet || r.URL.Path != "/health" {
					t.Error("probe must use one GET /health")
				}
				w.WriteHeader(test.code)
				fmt.Fprint(w, test.body)
			}))
			defer server.Close()
			expected := "bill service - ok"
			if test.name == "web healthy" {
				expected = "web service - ok"
			}
			if got := ExitCode(server.URL+"/health", expected); got != test.want {
				t.Fatalf("exit = %d, want %d", got, test.want)
			}
			if requests.Load() != 1 {
				t.Fatal("probe must make exactly one request")
			}
		})
	}
}

func TestProbeRejectsRedirect(t *testing.T) {
	var followed atomic.Int32
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		followed.Add(1)
		fmt.Fprint(w, `{"status":"bill service - ok"}`)
	}))
	defer target.Close()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, target.URL, http.StatusFound)
	}))
	defer server.Close()
	if ExitCode(server.URL+"/health", "bill service - ok") != 1 || followed.Load() != 0 {
		t.Fatal("probe must fail without following a redirect")
	}
}

func TestProbeTimeout(t *testing.T) {
	for _, headers := range []bool{false, true} {
		t.Run(fmt.Sprintf("headers=%t", headers), func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if headers {
					w.WriteHeader(http.StatusOK)
					w.(http.Flusher).Flush()
				}
				select {
				case <-r.Context().Done():
				case <-time.After(time.Second):
					fmt.Fprint(w, `{"status":"bill service - ok"}`)
				}
			}))
			defer server.Close()
			start := time.Now()
			if probe(server.URL+"/health", "bill service - ok", 25*time.Millisecond) != 1 {
				t.Fatal("probe must reject a slow response")
			}
			if time.Since(start) > 750*time.Millisecond {
				t.Fatal("probe did not bound the whole request")
			}
		})
	}
}

func TestProbeTransportFailure(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	server.Close()
	if ExitCode(server.URL+"/health", "bill service - ok") != 1 {
		t.Fatal("probe must reject a connection failure")
	}
}
