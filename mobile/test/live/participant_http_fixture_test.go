//go:build integration

// Installed by run_participant_journey.py as a read-only Go overlay. No backend
// file is changed. Only this anchored parent is executed, never measurement tests.
package main

import (
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func cdChild(t *testing.T, root, directory, report string, env []string, name string, args ...string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = directory
	cmd.Env = append(os.Environ(), env...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		if cmd.Process == nil {
			return nil
		}
		return syscall.Kill(-cmd.Process.Pid, syscall.SIGTERM)
	}
	cmd.WaitDelay = 3 * time.Second
	out, err := os.Create(filepath.Join(root, report))
	if err != nil {
		t.Fatal(err)
	}
	defer out.Close()
	cmd.Stdout = out
	cmd.Stderr = out
	if err := cmd.Run(); err != nil {
		t.Fatalf("owned client %s failed: %v; see %s", name, err, report)
	}
}
func TestCDMatchedClientHTTPFixture(t *testing.T) {
	root := os.Getenv("BILLINGTON_CD_RUN")
	workspace := os.Getenv("BILLINGTON_CD_WORKSPACE")
	if root == "" || workspace == "" {
		t.Fatal("explicit owned run/workspace required")
	}
	db, g, router, calls, logs := replayRouter(t)
	var schema, application, version string
	if err := db.QueryRow("SELECT current_schema(),current_setting('application_name'),version()").Scan(&schema, &application, &version); err != nil {
		t.Fatal(err)
	}
	if schema != application {
		t.Fatal("fixture scope/application mismatch")
	}
	identity := map[string]any{"schema": schema, "application_name": application, "postgres": version, "port": 51168, "workspace": workspace}
	bytes, _ := json.MarshalIndent(identity, "", "  ")
	if err := os.WriteFile(filepath.Join(root, "owned-postgres.json"), bytes, 0600); err != nil {
		t.Fatal(err)
	}
	t.Logf("owned schema/application %s", schema)
	server := httptest.NewServer(router)
	t.Cleanup(func() { server.CloseClientConnections(); server.Close() })
	output := filepath.Join(root, "synthetic-fixture.json")
	common := []string{"BILLINGTON_CD_HTTP=" + server.URL, "BILLINGTON_CD_OUTPUT=" + output}
	cdChild(t, root, filepath.Join(workspace, "mobile"), "flutter-live-create.jsonl", common, "flutter", "test", "--no-pub", "--reporter=json", "test/live/participant_http_journey.dart")
	// Synthetic raw legacy history is separate from the client-built receipt.
	// Money/labels/flags are inserted as historical evidence, never promoted or repaired.
	legacy := models.Bill{Name: "Raw legacy", Subtotal: 5, Total: 5, CurrencyCode: "USD", USDExchangeRate: 1, USDTotal: 5, ExchangeRateSource: "native-usd", Date: time.Now().UTC(), AccessToken: "synthetic-legacy-source", IdentityVersion: 1, IdentityState: "legacy_review"}
	if err := g.Omit("PersonShares", "Items", "ParticipantRows").Create(&legacy).Error; err != nil {
		t.Fatal(err)
	}
	shares := []models.PersonShare{{BillID: legacy.ID, PersonName: "", Subtotal: 2, Total: 2, Items: []models.ItemDetail{}}, {BillID: legacy.ID, PersonName: "", Subtotal: 3, Total: 3, Items: []models.ItemDetail{}}}
	if err := g.Create(&shares).Error; err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	var fixture map[string]any
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	fixture["legacy_bill_id"] = legacy.ID
	fixture["legacy_source"] = legacy.AccessToken
	data, _ = json.Marshal(fixture)
	if err := os.WriteFile(output, data, 0600); err != nil {
		t.Fatal(err)
	}
	webEnv := append(append([]string{}, common...), "NEXT_PUBLIC_API_URL="+server.URL, "BILLINGTON_CD_WEB_API="+filepath.Join(root, "web-api", "api.js"), "BILLINGTON_CD_BROWSER_RESULT="+filepath.Join(root, "browser-result.json"))
	cdChild(t, root, workspace, "browser-live.log", webEnv, "node", filepath.Join(workspace, "web-bill-viewer", "scripts", "participant-http-journey.cjs"))
	cdChild(t, root, filepath.Join(workspace, "mobile"), "flutter-live-recover.jsonl", append(common, "BILLINGTON_CD_PHASE=recover-attachment"), "flutter", "test", "--no-pub", "--reporter=json", "test/live/participant_http_journey.dart")
	var count int
	if err := db.QueryRow("SELECT count(*) FROM bills WHERE id=$1", int64(fixture["bill_id"].(float64))).Scan(&count); err != nil || count != 1 {
		t.Fatal("client receipt was not persisted exactly once")
	}
	if calls.Load() != 0 {
		t.Fatal("USD journey unexpectedly called a quote provider")
	}
	// All requests/children have settled before reading the shared captured sink.
	if err := os.WriteFile(filepath.Join(root, "sanitized-server.log"), logs.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "server-result.json"), []byte(fmt.Sprintf(`{"status":"pass","client_receipts":1,"quote_calls":0,"schema":%q}`, schema)), 0600); err != nil {
		t.Fatal(err)
	}
}
