package healthcheck

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestServiceHealthcheckMode(t *testing.T) {
	for _, service := range []struct {
		name string
		port string
	}{
		{"bill-service", "8080"},
		{"web-service", "8081"},
	} {
		t.Run(service.name, func(t *testing.T) {
			binary := filepath.Join(t.TempDir(), service.name)
			build := exec.Command("go", "build", "-o", binary, "./cmd/"+service.name)
			build.Dir = "../.."
			if output, err := build.CombinedOutput(); err != nil {
				t.Fatalf("build service: %v\n%s", err, output)
			}
			env := []string{}
			for _, value := range os.Environ() {
				if !strings.HasPrefix(value, "DB_") {
					env = append(env, value)
				}
			}
			listener, err := net.Listen("tcp", "127.0.0.1:"+service.port)
			if err != nil {
				t.Fatal(err) // Never skip if a prerequisite is occupied.
			}
			var mode atomic.Int32
			var redirectHits atomic.Int32
			server := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/redirect-target" {
					redirectHits.Add(1)
				} else if r.URL.Path != "/health" {
					t.Error("wrong health path")
				}
				switch mode.Load() {
				case 1:
					w.WriteHeader(http.StatusServiceUnavailable)
				case 2:
					fmt.Fprint(w, `{"status":`)
					return
				case 3:
					fmt.Fprint(w, strings.Repeat(" ", maxBodyBytes+1))
				case 4:
					if r.URL.Path == "/health" {
						http.Redirect(w, r, "/redirect-target", http.StatusFound)
						return
					}
				case 5:
					select {
					case <-r.Context().Done():
						return
					case <-time.After(4 * time.Second):
					}
				}
				fmt.Fprintf(w, `{"status":%q,"commit":"synthetic"}`, strings.ReplaceAll(service.name, "-", " ")+" - ok")
			}), ReadHeaderTimeout: time.Second}
			defer server.Close()
			go server.Serve(listener)
			ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
			defer cancel()
			for i, name := range []string{"healthy", "non-200", "malformed", "oversized", "redirect", "timeout"} {
				t.Run(name, func(t *testing.T) {
					mode.Store(int32(i))
					command := exec.CommandContext(ctx, binary, "--healthcheck")
					command.Env = env
					start := time.Now()
					output, err := command.CombinedOutput()
					want := 1
					if i == 0 {
						want = 0
					}
					if command.ProcessState == nil || command.ProcessState.ExitCode() != want || len(output) != 0 {
						t.Fatalf("no DB configuration: want exit %d, error=%v, output bytes=%d", want, err, len(output))
					}
					if i == 5 && time.Since(start) > 3*time.Second {
						t.Fatal("binary probe exceeded its request bound")
					}
				})
			}
			if redirectHits.Load() != 0 {
				t.Fatal("binary probe followed a redirect")
			}
			server.Close()
			command := exec.CommandContext(ctx, binary, "--healthcheck")
			command.Env = env
			output, err := command.CombinedOutput()
			if command.ProcessState == nil || command.ProcessState.ExitCode() != 1 || len(output) != 0 {
				t.Fatalf("closed endpoint: error=%v, output bytes=%d", err, len(output))
			}
			command = exec.CommandContext(ctx, binary)
			command.Env = env
			output, err = command.CombinedOutput()
			if err == nil || !strings.Contains(string(output), "missing required database environment variables") {
				t.Fatal("default startup must still initialize the database")
			}
		})
	}
}
