// runtime-probe is local verification tooling, never copied into a service image.
// Build from backend with the production compiler, CGO_ENABLED=0 and this file's path.
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"os"
	"os/user"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/net/dns/dnsmessage"
)

// The DNS fixture answers only synthetic names; it never forwards a query.
func serveDNS() {
	conn, err := net.ListenPacket("udp", ":53")
	if err != nil {
		os.Exit(1)
	}
	defer conn.Close()
	buffer := make([]byte, 4096)
	for {
		n, peer, err := conn.ReadFrom(buffer)
		if err != nil {
			return
		}
		var request dnsmessage.Message
		if request.Unpack(buffer[:n]) != nil || len(request.Questions) != 1 {
			continue
		}
		q := request.Questions[0]
		name := q.Name.String()
		_ = json.NewEncoder(os.Stdout).Encode(map[string]any{"name": name, "type": q.Type})
		if strings.HasPrefix(name, "cancel-") {
			continue // Deliberate blackhole: prove in-flight context cancellation.
		}
		response := dnsmessage.Message{
			Header:    dnsmessage.Header{ID: request.ID, Response: true, RecursionDesired: true, RecursionAvailable: true},
			Questions: request.Questions,
		}
		if name == "search-probe.runtime-check.test." {
			if q.Type == dnsmessage.TypeA {
				response.Answers = []dnsmessage.Resource{{
					Header: dnsmessage.ResourceHeader{Name: q.Name, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET, TTL: 1},
					Body:   &dnsmessage.AResource{A: [4]byte{192, 0, 2, 45}},
				}}
			}
		} else {
			response.Header.RCode = dnsmessage.RCodeNameError
		}
		packet, err := response.Pack()
		if err == nil {
			_, _ = conn.WriteTo(packet, peer)
		}
	}
}

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--dns-server" {
		serveDNS()
		return
	}
	report := map[string]any{}
	exit := 0
	defer func() {
		if failed := recover(); failed != nil {
			report["failed_check"] = failed // Only literal check names are panicked below.
			exit = 1
		}
		_ = json.NewEncoder(os.Stdout).Encode(report)
		os.Exit(exit)
	}()
	require := func(name string, ok bool) {
		report[name] = ok
		if !ok {
			panic(name)
		}
	}
	must := func(name string, err error) { require(name, err == nil) }

	require("probe_uid_gid", os.Getuid() == 65532 && os.Getgid() == 65532)
	current, err := user.Current()
	must("passwd_lookup", err)
	require("passwd_nonroot", current.Uid == "65532" && current.Gid == "65532")
	report["passwd_home"] = current.HomeDir
	proc, err := os.ReadFile("/proc/1/status")
	must("service_status_readable", err)
	require("service_uid_gid", strings.Contains(string(proc), "Uid:\t65532\t65532\t65532\t65532") && strings.Contains(string(proc), "Gid:\t65532\t65532\t65532\t65532"))
	require("app_write_denied", os.WriteFile("/app/runtime-check-must-not-write", []byte("synthetic"), 0600) != nil)
	require("root_write_denied", os.WriteFile("/runtime-check-must-not-write", []byte("synthetic"), 0600) != nil)
	f, err := os.CreateTemp("/tmp", "runtime-check-")
	must("tmp_writable", err)
	defer os.Remove(f.Name())
	must("tmp_close", f.Close())
	st, err := os.Stat("/tmp")
	must("tmp_stat", err)
	require("tmp_sticky", st.Mode()&os.ModeSticky != 0)
	owner, ok := st.Sys().(*syscall.Stat_t)
	require("tmp_owned", ok && owner.Uid == 65532 && owner.Gid == 65532)
	location, err := time.LoadLocation("America/New_York")
	must("tzdata_loaded", err)
	_, winter := time.Date(2026, 1, 15, 12, 0, 0, 0, location).Zone()
	_, summer := time.Date(2026, 7, 15, 12, 0, 0, 0, location).Zone()
	require("tzdata_dst", winter == -18000 && summer == -14400)

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	for _, test := range []struct{ name, host, want string }{
		{"hosts_file", "hosts-probe", "192.0.2.44"},
		{"service_dns", "runtime-postgres", ""},
		{"dns_search", "search-probe", "192.0.2.45"},
	} {
		ips, err := net.DefaultResolver.LookupHost(ctx, test.host)
		require(test.name, err == nil && len(ips) > 0 && (test.want == "" || ips[0] == test.want))
	}
	_, err = net.DefaultResolver.LookupHost(ctx, "absent-probe")
	var dnsErr *net.DNSError
	require("dns_nxdomain", errors.As(err, &dnsErr) && dnsErr.IsNotFound)
	lookup, stop := context.WithTimeout(ctx, 250*time.Millisecond)
	start := time.Now()
	_, err = net.DefaultResolver.LookupHost(lookup, "cancel-"+os.Getenv("QA_NONCE")+".runtime-check.test.")
	lookupErr := lookup.Err()
	stop()
	report["dns_cancel_ms"] = time.Since(start).Milliseconds()
	// The packet deadline can win the context race and return a DNSError timeout
	// without wrapping context.DeadlineExceeded. Require the actual context deadline,
	// typed DNS timeout and bounded elapsed time rather than a particular wrapper.
	require("dns_cancellation", lookupErr == context.DeadlineExceeded && errors.As(err, &dnsErr) && dnsErr.IsTimeout && time.Since(start) >= 200*time.Millisecond && time.Since(start) < time.Second)

	roots, err := x509.SystemCertPool()
	must("system_ca_loaded", err)
	require("system_ca_nonempty", len(roots.Subjects()) > 0)
	client := http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{TLSClientConfig: &tls.Config{
			RootCAs: roots, MinVersion: tls.VersionTLS12,
		}},
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse },
	}
	response, err := client.Get("https://example.com/")
	must("public_https_connected", err)
	require("public_https_verified", response.TLS != nil && len(response.TLS.VerifiedChains) > 0 && response.StatusCode == 200)
	must("public_https_close", response.Body.Close())

	config, err := pgx.ParseConfig("host=runtime-postgres port=5432 dbname=runtime_fixture user=runtime_fixture sslmode=verify-full sslrootcert=/qa/ca.crt TimeZone=America/New_York")
	must("database_config", err)
	config.RuntimeParams["search_path"] = os.Getenv("QA_SCHEMA")
	conn, err := pgx.ConnectConfig(ctx, config)
	must("database_connect", err)
	defer conn.Close(ctx)
	var ssl bool
	var tz, version, schema string
	must("database_tls_query", conn.QueryRow(ctx, "SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()").Scan(&ssl))
	require("database_tls", ssl)
	must("database_timezone_query", conn.QueryRow(ctx, "SHOW TimeZone").Scan(&tz))
	require("database_timezone", tz == "America/New_York")
	must("database_schema_query", conn.QueryRow(ctx, "SELECT current_schema()").Scan(&schema))
	require("database_owned_schema", strings.HasPrefix(schema, "billington_runtime_") && schema == os.Getenv("QA_SCHEMA"))
	must("database_version_query", conn.QueryRow(ctx, "SHOW server_version").Scan(&version))
	report["postgres_version"] = version
	for _, key := range []string{"bad_ca", "wrong_host"} {
		bad := config.Copy()
		if key == "bad_ca" {
			bad.TLSConfig.RootCAs = x509.NewCertPool()
		} else {
			bad.TLSConfig.ServerName = "wrong-host.invalid"
		}
		c, err := pgx.ConnectConfig(ctx, bad)
		if c != nil {
			_ = c.Close(ctx)
		}
		var authority x509.UnknownAuthorityError
		var hostname x509.HostnameError
		require("tls_reject_"+key, err != nil && (key == "bad_ca" && errors.As(err, &authority) || key == "wrong_host" && errors.As(err, &hostname)))
	}
	if os.Getenv("QA_WEB") == "1" {
		_, err = os.ReadFile("/app/internal/web/templates/bill.html")
		must("template_readable", err)
	}
}
