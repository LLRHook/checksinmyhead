#!/usr/bin/env python3
"""Exercise immutable local service images using owned synthetic TLS/DNS fixtures.

No hosting account, existing database, real receipt, source upload or package install.
Requires Docker, Go, OpenSSL and Python's standard library. See backend/README.md.
"""
import argparse
import datetime
import hashlib
import io
import json
import pathlib
import re
import socket
import struct
import subprocess
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]


def execute(args, *, data=None, check=True, cwd=ROOT):
    result = subprocess.run(args, input=data, capture_output=True, cwd=cwd, timeout=120)
    if check and result.returncode:
        raise RuntimeError("fixture command failed: " + args[0])
    return result


def docker(*args):
    return execute(["docker", *args]).stdout.decode().strip()


def inspect(name):
    return json.loads(docker("inspect", name))[0]


def request(port, path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}" + path,
        data=json.dumps(body).encode() if body is not None else None, headers=headers)
    # Loopback fixtures must never inherit a proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=3) as response:
            return response.status, response.read(), dict(response.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read(), dict(error.headers)


def wait_until(predicate, timeout, description):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.25)
    raise RuntimeError("timed out: " + description)


def main():
    bases = [line.split()[1] for line in (ROOT / "backend/services/bill-service/Dockerfile").read_text().splitlines() if line.startswith("FROM ")]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bill-image", required=True)
    parser.add_argument("--web-image", required=True)
    parser.add_argument("--postgres-image", required=True, help="Existing immutable local PostgreSQL fixture image ID")
    parser.add_argument("--output", required=True, type=pathlib.Path, help="New local evidence directory")
    parser.add_argument("--static-base", default=bases[-1], help="Signed static base; defaults to the production Dockerfile pin")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    nonce = uuid.uuid4().hex[:16]
    label = "billington.runtime-check=" + nonce
    network = "billington-runtime-" + nonce
    schema = "billington_runtime_" + nonce
    metrics = "billington_runtime_metrics_" + nonce
    owned = []
    fixture = None
    record = {"run": nonce, "started": datetime.datetime.now(datetime.timezone.utc).isoformat(), "checks": [], "failures": [], "commands": [], "cleaned": False}

    def command(argv, **kwargs):
        # Only synthetic fixture values; customer credentials/tokens/keys never enter argv.
        enforce = kwargs.pop("check", True)
        result = execute(argv, check=False, **kwargs)
        number = len(record["commands"])
        for stream in ("stdout", "stderr"):
            (out / f"command-{number}.{stream}").write_bytes(getattr(result, stream))
        record["commands"].append({"argv": argv, "exit": result.returncode, "output": f"command-{number}"})
        if enforce and result.returncode:
            raise RuntimeError(f"fixture command {number} failed: " + argv[0])
        return result

    def check(name, ok, detail=None):
        record["checks"].append({"name": name, "pass": bool(ok), "detail": detail})
        print(name + (" PASS" if ok else " FAIL"), flush=True)
        if not ok:
            raise RuntimeError("check failed: " + name)

    def create(name, *argv):
        owned.append(name)
        command(["docker", "create", "--name", name, "--label", label, *argv])
        return name

    try:
        images = {key: inspect(value)["Id"] for key, value in
                  [("bill", args.bill_image), ("web", args.web_image), ("postgres", args.postgres_image)]}
        record["images"] = images
        for key in ("bill", "web"):
            image = inspect(images[key])
            check(key + "-platform", image["Os"] == "linux" and image["Architecture"] == "amd64")
            check(key + "-config", image["Config"]["User"] == "65532:65532" and
                  image["Config"]["Healthcheck"]["Test"] == ["CMD", "./" + key + "-service", "--healthcheck"])
            name = create(network + "-inspect-" + key, "--platform", "linux/amd64", images[key])
            raw = command(["docker", "export", name]).stdout
            with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
                files = archive.getmembers()
                binary = archive.extractfile("app/" + key + "-service").read()
                path = out / (key + "-service")
                path.write_bytes(binary)
                # ELF64 little-endian program headers: PT_INTERP=3, PT_DYNAMIC=2.
                check(key + "-elf-format", binary[:6] == b"\x7fELF\x02\x01")
                offset = struct.unpack_from("<Q", binary, 32)[0]
                size, count = struct.unpack_from("<HH", binary, 54)
                types = [struct.unpack_from("<I", binary, offset + n * size)[0] for n in range(count)]
                check(key + "-static-elf", 3 not in types and 2 not in types, {"program_types": types})
                info = command(["go", "version", "-m", str(path)], cwd=ROOT / "backend").stdout.decode()
                (out / (key + "-buildinfo.txt")).write_text(info)
                check(key + "-cgo-disabled", "CGO_ENABLED=0" in info and "GOARCH=amd64" in info and "GOOS=linux" in info)
                check(key + "-no-openpgp", "openpgp" not in info)
                packages = []
                for f in files:
                    if f.isfile() and f.name.startswith("var/lib/dpkg/status.d/") and not f.name.endswith(".md5sums"):
                        fields = dict(line.split(": ", 1) for line in archive.extractfile(f).read().decode().splitlines() if ": " in line and not line.startswith(" "))
                        packages.append({k: fields.get(k) for k in ("Package", "Version", "Architecture")})
                check(key + "-no-native-libraries", not any(
                    re.search(r"/(libc[.]so|libssl[.]so|ld-linux)", f.name) for f in files) and
                    not any(p["Package"].startswith(("libc6", "libssl")) for p in packages))
                record[key + "_artifact"] = {"sha256": hashlib.sha256(binary).hexdigest(), "bytes": image["Size"], "packages": packages}

        builder = bases[0]
        command(["docker", "run", "--rm", "--label", label, "--platform", "linux/amd64",
                 "-v", str(ROOT / "backend") + ":/app:ro", "-v", str(ROOT / "scripts/runtime-probe") + ":/probe-source:ro",
                 "-v", str(out) + ":/qa", "-w", "/app", "-e", "GOTOOLCHAIN=local", "-e", "CGO_ENABLED=0",
                 builder, "go", "build", "-mod=readonly", "-o", "/qa/runtime-probe", "/probe-source/main.go"])
        with tempfile.TemporaryDirectory(prefix=network + "-") as temp:
            fixture = pathlib.Path(temp)
            for prefix in ("ca", "bad-ca"):
                command(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", prefix + ".key", "-out", prefix + ".crt", "-days", "1", "-subj", "/CN=Synthetic runtime " + prefix], cwd=fixture)
            command(["openssl", "req", "-newkey", "rsa:2048", "-nodes", "-keyout", "server.key", "-out", "server.csr", "-subj", "/CN=runtime-postgres"], cwd=fixture)
            (fixture / "server.ext").write_text("subjectAltName=DNS:runtime-postgres\nextendedKeyUsage=serverAuth\n")
            command(["openssl", "x509", "-req", "-in", "server.csr", "-CA", "ca.crt", "-CAkey", "ca.key", "-CAcreateserial", "-out", "server.crt", "-days", "1", "-extfile", "server.ext"], cwd=fixture)
            record["fixture_certificates"] = {name: hashlib.sha256((fixture / name).read_bytes()).hexdigest() for name in ("ca.crt", "bad-ca.crt", "server.crt")}
            command(["docker", "network", "create", "--label", label, network])
            pg = create(network + "-postgres", "--network", network, "--network-alias", "runtime-postgres", "--network-alias", "wrong-postgres",
                        "--tmpfs", "/var/lib/postgresql/data:rw", "-e", "POSTGRES_USER=runtime_fixture", "-e", "POSTGRES_DB=runtime_fixture",
                        "-e", "POSTGRES_HOST_AUTH_METHOD=trust", images["postgres"], "postgres", "-c", "ssl=on", "-c", "ssl_cert_file=/runtime-fixture/server.crt",
                        "-c", "ssl_key_file=/runtime-fixture/server.key", "-c", "shared_preload_libraries=pg_stat_statements")
            buffer = io.BytesIO()
            with tarfile.open(fileobj=buffer, mode="w") as archive:
                for name in ("runtime-fixture", "runtime-fixture/server.crt", "runtime-fixture/server.key"):
                    info = tarfile.TarInfo(name)
                    info.uid = info.gid = 999
                    info.mode = 0o755
                    if "/" not in name:
                        info.type = tarfile.DIRTYPE
                        archive.addfile(info)
                    else:
                        data = (fixture / name.split("/")[-1]).read_bytes()
                        info.size = len(data)
                        info.mode = 0o600 if name.endswith(".key") else 0o644
                        archive.addfile(info, io.BytesIO(data))
            command(["docker", "cp", "-a", "-", pg + ":/"], data=buffer.getvalue())
            command(["docker", "start", pg])
            wait_until(lambda: execute(["docker", "exec", pg, "pg_isready", "-h", "127.0.0.1", "-U", "runtime_fixture", "-d", "runtime_fixture"], check=False).returncode == 0, 40, "TLS PostgreSQL")

            def sql(query):
                return command(["docker", "exec", pg, "psql", "-v", "ON_ERROR_STOP=1", "-U", "runtime_fixture", "-d", "runtime_fixture", "-Atc", query]).stdout.decode().strip()

            sql(f'CREATE SCHEMA "{schema}"; CREATE SCHEMA "{metrics}"; CREATE EXTENSION pg_stat_statements SCHEMA "{metrics}";')
            dns = create(network + "-dns", "--network", network, "--cap-drop=ALL", "--read-only", "--user", "65532:65532",
                         "--platform", "linux/amd64", "-v", str(out / "runtime-probe") + ":/qa/runtime-probe:ro", args.static_base, "/qa/runtime-probe", "--dns-server")
            command(["docker", "start", dns])
            dns_ip = inspect(dns)["NetworkSettings"]["Networks"][network]["IPAddress"]
            public_ip = socket.getaddrinfo("example.com", 443, family=socket.AF_INET, type=socket.SOCK_STREAM)[0][4][0]
            record["public_ca_host_address"] = public_ip
            ports, services = {}, {}

            def app_args(key, *, bad=None, selected_schema=schema):
                env = ["DB_HOST=" + ("wrong-postgres" if bad == "hostname" else "runtime-postgres"), "DB_PORT=5432", "DB_NAME=runtime_fixture", "DB_USER=runtime_fixture",
                       "DB_PASSWORD=synthetic-runtime-fixture", "DB_SSLMODE=verify-full", "PGSSLROOTCERT=/qa/" + ("bad-ca.crt" if bad == "ca" else "ca.crt"),
                       "PGOPTIONS=-csearch_path=" + selected_schema, "GIN_MODE=release", "RENDER_GIT_COMMIT=local-runtime-fixture",
                       "QA_NONCE=" + nonce + key, "QA_SCHEMA=" + selected_schema, "QA_WEB=" + ("1" if key == "web" else "0")]
                argv = ["--platform", "linux/amd64", "--network", network, "--read-only", "--cap-drop=ALL", "--security-opt", "no-new-privileges",
                        "--tmpfs", "/tmp:rw,nosuid,nodev,mode=1777,uid=65532,gid=65532", "--dns", dns_ip, "--dns-search", "runtime-check.test",
                        "--dns-search", ".".join(["x" * 60] * 3) + ".test", "--dns-option", "timeout:1", "--dns-option", "attempts:1",
                        "--add-host", "hosts-probe:192.0.2.44", "--add-host", "example.com:" + public_ip,
                        "-v", str(fixture / "ca.crt") + ":/qa/ca.crt:ro", "-v", str(fixture / "bad-ca.crt") + ":/qa/bad-ca.crt:ro",
                        "-v", str(out / "runtime-probe") + ":/qa/runtime-probe:ro"]
                for value in env:
                    argv += ["-e", value]
                return argv

            for key, port in (("bill", 8080), ("web", 8081)):
                # Every startup-negative control uses the exact final service binary.
                for bad in ("ca", "hostname"):
                    name = create(network + "-" + key + "-bad-" + bad, *app_args(key, bad=bad), images[key])
                    command(["docker", "start", name])
                    wait_until(lambda: not inspect(name)["State"]["Running"], 12, key + " TLS rejection")
                    check(key + "-startup-reject-" + bad, inspect(name)["State"]["ExitCode"] != 0)
                    logs = docker("logs", name)
                    check(key + "-startup-error-secrecy-" + bad, "synthetic-runtime-fixture" not in logs and schema not in logs)
                mode_schema = "billington_runtime_modes_" + nonce + key
                sql(f'CREATE SCHEMA "{mode_schema}"')
                for mode, expected_exit in (("--schema-mode=verify", 1), ("--migrate-only", 0)):
                    mode_name = "verify-empty" if expected_exit else "migrate-only"
                    name = create(network + "-" + key + "-" + mode_name, *app_args(key, selected_schema=mode_schema),
                                  images[key], "./" + key + "-service", mode)
                    command(["docker", "start", name])
                    wait_until(lambda: not inspect(name)["State"]["Running"], 15, key + " " + mode_name)
                    check(key + "-" + mode_name, (inspect(name)["State"]["ExitCode"] == 0) == (expected_exit == 0))
                    count = sql(f"SELECT count(*) FROM pg_class WHERE relnamespace='{mode_schema}'::regnamespace AND relname='schema_migrations'")
                    check(key + "-" + mode_name + "-ledger", count == ("0" if expected_exit else "1"))
                name = create(network + "-" + key + "-verify-serving", *app_args(key, selected_schema=mode_schema),
                              "-p", f"127.0.0.1::{port}", images[key], "./" + key + "-service", "--schema-mode=verify")
                command(["docker", "start", name])
                mode_port = int(inspect(name)["NetworkSettings"]["Ports"][str(port) + "/tcp"][0]["HostPort"])

                def mode_ready():
                    try:
                        return request(mode_port, "/health")[0] == 200
                    except (ConnectionError, urllib.error.URLError, TimeoutError):
                        return False

                wait_until(mode_ready, 15, key + " verify serving")
                check(key + "-verify-serving", True)
                command(["docker", "stop", "--time", "3", name])
                check(key + "-verify-graceful-exit", inspect(name)["State"]["ExitCode"] == 0)
                name = create(network + "-" + key, *app_args(key), "-p", f"127.0.0.1::{port}", images[key])
                services[key] = name
                command(["docker", "start", name])
                ports[key] = int(inspect(name)["NetworkSettings"]["Ports"][str(port) + "/tcp"][0]["HostPort"])

                def ready():
                    try:
                        return request(ports[key], "/health")[0] == 200
                    except (ConnectionError, urllib.error.URLError, TimeoutError):
                        return False

                wait_until(ready, 40, key + " fresh startup")
                check(key + "-health", json.loads(request(ports[key], "/health")[1])["status"] == key + " service - ok")
                sql(f'SELECT "{metrics}".pg_stat_statements_reset();')
                check(key + "-single-health-request", request(ports[key], "/health")[0] == 200)
                calls = sql(f"SELECT COALESCE(sum(calls),0)::int FROM \"{metrics}\".pg_stat_statements WHERE query LIKE 'SELECT COALESCE(jsonb_agg%' AND query LIKE '%schema_migrations%'")
                check(key + "-one-readiness-query", calls == "1", {"calls": calls})
                result = command(["docker", "exec", "-e", "GODEBUG=netdns=2", name, "/qa/runtime-probe"], check=False)
                (out / (key + "-probe.stdout")).write_bytes(result.stdout)
                (out / (key + "-probe.stderr")).write_bytes(result.stderr)
                check(key + "-runtime-probe", result.returncode == 0)
                record[key + "_runtime"] = json.loads(result.stdout)
                check(key + "-readonly-config", inspect(name)["HostConfig"]["ReadonlyRootfs"])

            check("fresh-ledger", sql(f'SELECT version FROM "{schema}".schema_migrations ORDER BY version') == "1\n2\n3")
            check("public-schema-untouched", sql("SELECT count(*) FROM pg_class WHERE relnamespace='public'::regnamespace AND relkind IN ('r','v','S')") == "0")
            payload = {"name": "Static runtime synthetic receipt", "lazy_mode": False, "subtotal": 12, "tax": 0, "tip_amount": 0, "total": 12,
                       "currency_code": "USD", "display_currency": "USD", "participants": [{"name": "QA"}], "items": [{"name": "Synthetic meal", "price": 12, "assignments": [{"person_name": "QA", "percentage": 100}]}],
                       "person_shares": [{"person_name": "QA", "items": [{"name": "Synthetic meal", "amount": 12, "is_shared": False}], "subtotal": 12, "tax_share": 0, "tip_share": 0, "total": 12}]}
            status, body, _ = request(ports["bill"], "/api/bills", payload)
            check("api-create", status == 201)
            created = json.loads(body)
            bill_id, token = str(created["bill_id"]), created["access_token"]
            status, body, _ = request(ports["bill"], "/api/bills/" + bill_id, token=token)
            check("api-authorized-read", status == 200 and b"Static runtime synthetic receipt" in body)
            check("api-no-token-denied", request(ports["bill"], "/api/bills/" + bill_id)[0] == 403)
            status, body, headers = request(ports["web"], "/b/" + bill_id, token=token)
            check("legacy-authorized-html", status == 200 and b"Static runtime synthetic receipt" in body and "text/html" in headers.get("Content-Type", ""))
            check("legacy-no-token-denied", request(ports["web"], "/b/" + bill_id)[0] == 403)
            check("application-connections-tls", sql("SELECT count(*)>=2 AND bool_and(s.ssl) FROM pg_stat_ssl s JOIN pg_stat_activity a USING(pid) WHERE a.usename='runtime_fixture' AND a.pid<>pg_backend_pid()") == "t")
            for key, name in services.items():
                wait_until(lambda: inspect(name)["State"]["Health"]["Status"] == "healthy", 45, key + " Docker healthy")
                check(key + "-docker-healthy", True)
                probe = command(["docker", "exec", name, "./" + key + "-service", "--healthcheck"])
                check(key + "-probe-silent", probe.stdout == probe.stderr == b"")
            checksum = sql(f'SELECT checksum FROM "{schema}".schema_migrations WHERE version=1')
            sql(f'UPDATE "{schema}".schema_migrations SET checksum=repeat(\'a\',64) WHERE version=1')
            for key, name in services.items():
                check(key + "-ledger-unready", request(ports[key], "/health")[0] == 503)
                check(key + "-probe-rejects-ledger", command(["docker", "exec", name, "./" + key + "-service", "--healthcheck"], check=False).returncode != 0)
            sql(f'UPDATE "{schema}".schema_migrations SET checksum=\'{checksum}\' WHERE version=1')
            # Pause preserves the ephemeral tmpfs while simulating an unresponsive DB.
            command(["docker", "pause", pg])
            for key in services:
                start = time.monotonic()
                status, body, _ = request(ports[key], "/health")
                elapsed = time.monotonic() - start
                check(key + "-db-unavailable", status == 503 and json.loads(body)["status"] == "service unavailable" and elapsed < 1.5, {"seconds": elapsed})
            print("Waiting for unchanged Docker health intervals to report unavailable DB...", flush=True)
            for key, name in services.items():
                wait_until(lambda: inspect(name)["State"]["Health"]["Status"] == "unhealthy", 105, key + " Docker unhealthy")
                check(key + "-docker-unhealthy", True)
            command(["docker", "unpause", pg])
            for key, name in services.items():
                wait_until(lambda: request(ports[key], "/health")[0] == 200, 15, key + " readiness recovery")
                check(key + "-readiness-recovered", True)
                wait_until(lambda: inspect(name)["State"]["Health"]["Status"] == "healthy", 45, key + " Docker recovery")
                check(key + "-docker-recovered", True)
            for key, name in services.items():
                command(["docker", "stop", "--time", "30", name])
                check(key + "-graceful-exit", inspect(name)["State"]["ExitCode"] == 0)
                logs = docker("logs", name)
                check(key + "-shutdown-log-secrecy", "synthetic-runtime-fixture" not in logs and schema not in logs)
            record["dns_queries"] = [json.loads(line) for line in docker("logs", dns).splitlines() if line.startswith("{")]
            names = [q["name"] for q in record["dns_queries"]]
            check("dns-fixture-observed-search", "search-probe.runtime-check.test." in names)
            check("dns-fixture-observed-cancellation", sum(name.startswith("cancel-") for name in names) >= 2)
            check("dns-fixture-observed-long-search", any(len(name) > 180 for name in names))
    except Exception as error:
        record["failures"].append(str(error))
        print("FAIL: " + str(error), flush=True)
    finally:
        for name in reversed(owned):
            state = execute(["docker", "inspect", name], check=False)
            if state.returncode == 0 and json.loads(state.stdout)[0]["Config"]["Labels"].get("billington.runtime-check") == nonce:
                execute(["docker", "rm", "-f", "-v", name], check=False)
        execute(["docker", "network", "rm", network], check=False)
        record["remaining_containers"] = docker("ps", "-aq", "--filter", "label=" + label).splitlines()
        record["remaining_networks"] = docker("network", "ls", "-q", "--filter", "label=" + label).splitlines()
        record["fixture_directory_removed"] = fixture is None or not fixture.exists()
        record["cleaned"] = not record["remaining_containers"] and not record["remaining_networks"] and record["fixture_directory_removed"]
        record["finished"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (out / "result.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps({"checks": len(record["checks"]), "failures": record["failures"], "cleaned": record["cleaned"]}), flush=True)
    return int(bool(record["failures"]) or not record["cleaned"])


if __name__ == "__main__":
    raise SystemExit(main())
