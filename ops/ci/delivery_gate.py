"""Reviewed-controller checks, reports and managed source publishers (stdlib only).

C owns this file and its case manifest. S supplies app code, never release policy.
Receipt JSON is an internal synchronous needs contract, NOT an artifact attestation.
iOS uses this same owner; historical artifact authentication lives in ios_artifact.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

ROWS = ('automation', 'local-workflow', 'backend', 'postgres', 'mobile', 'web')
PG_PACKAGES = ('backend/cmd/bill-service', 'backend/internal/bill', 'backend/internal/tab',
               'backend/pkg/database', 'backend/migrations', 'backend/internal/startup',
               'backend/internal/readiness', 'backend/internal/testpostgres')
DISABLED = ('ios-upload', 'ios-production', 'ios-notes')
TARGETS = ('backend', 'web', *DISABLED)
REPOSITORY = 'LLRHook/checksinmyhead'
WORKFLOW = REPOSITORY + '/.github/workflows/ci.yml@refs/heads/main'
IOS_WORKFLOWS = dict(zip(DISABLED, ('testflight.yml', 'app-store-release.yml', 'update-release-notes.yml')))
MIRROR = 'git@github.com:dhaliwalg/checksinmyhead.git'
HOST_KEY = 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl\n'
DISABLED_POLICY = {'version': 1, 'enabled_targets': [], 'control_floor': None, 'targets': {}}


class Rejected(ValueError):
    pass


def require(ok, reason):
    if not ok:
        raise Rejected(reason)


def sha(value):
    require(isinstance(value, str) and re.fullmatch('[0-9a-f]{40}', value) is not None, 'invalid full source SHA')
    return value


def digest(data):
    return hashlib.sha256(data).hexdigest()


def compact(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':'))


def parse(data):
    # Duplicate policy/receipt keys must not silently override earlier values.
    def pairs(items):
        obj = {}
        for k, v in items:
            require(k not in obj, 'duplicate JSON field')
            obj[k] = v
        return obj
    try:
        return json.loads(data, object_pairs_hook=pairs,
                          parse_constant=lambda _: require(False, 'nonfinite JSON value'))
    except (TypeError, json.JSONDecodeError) as e:
        raise Rejected('invalid JSON') from e


def git(repo, *args, env=None):
    p = subprocess.run(['git', '-C', str(repo), *args], capture_output=True, env=env, check=False)
    require(p.returncode == 0, 'git operation failed: ' + args[0])
    return p.stdout.decode().strip()


def ancestor(repo, before, after):
    sha(before); sha(after)
    # --is-ancestor rejects unknown objects too (no fetch/fallback to branch tips).
    p = subprocess.run(['git', '-C', str(repo), 'merge-base', '--is-ancestor', before, after],
                       capture_output=True, check=False)
    require(p.returncode == 0, 'unknown or out-of-lineage source floor')


def assert_checkout(repo, expected):
    require(git(repo, 'rev-parse', 'HEAD') == sha(expected), 'checkout/source mismatch')


def resolve(repo, controller, requested, event, ref):
    sha(controller)
    require(event in ('push', 'pull_request', 'workflow_dispatch'), 'unsupported event')
    if event == 'workflow_dispatch':
        require(ref == 'refs/heads/main', 'manual controller must run on main')
    if requested:
        require(event == 'workflow_dispatch', 'only manual main may select source')
        if re.fullmatch(r'backend-v[0-9]+\.[0-9]+\.[0-9]+', requested):
            source = git(repo, 'rev-parse', '--verify', 'refs/tags/' + requested + '^{commit}')
        else:
            source = sha(requested)
            require(git(repo, 'rev-parse', '--verify', source + '^{commit}') == source, 'unresolved source')
    else:
        source = controller
    if ref.startswith('refs/tags/'):
        require(re.fullmatch(r'refs/tags/(?:backend|release)-v[0-9]+\.[0-9]+\.[0-9]+', ref) is not None,
                'invalid backend tag')
        require(git(repo, 'rev-parse', '--verify', ref + '^{commit}') == source, 'tag target moved')
    return sha(source)


def binding(env, source, controller):
    sha(source); sha(controller)
    require(re.fullmatch('[1-9][0-9]*', env.get('GITHUB_RUN_ID', '')) is not None, 'missing run id')
    require(re.fullmatch('[1-9][0-9]*', env.get('GITHUB_RUN_ATTEMPT', '')) is not None, 'missing attempt')
    return {'source': source, 'controller': controller, 'scope': 'all',
            'run': env['GITHUB_RUN_ID'], 'attempt': env['GITHUB_RUN_ATTEMPT']}


def validate_cases(cases, expected):
    require(isinstance(cases, list) and len(cases) > 0, 'zero executed cases')
    ids = []
    families = set()
    for c in cases:
        require(isinstance(c, dict) and set(c) in ({'id', 'family', 'status'}, {'id', 'family', 'status', 'name'}), 'malformed case')
        require(isinstance(c['id'], str) and c['id'], 'missing runner case ID')
        require(isinstance(c['family'], str) and c['family'], 'missing case family')
        require(c['status'] == 'pass', 'failed/skipped/unfinished case')
        ids.append(c['id']); families.add(c['family'])
    require(len(ids) == len(set(ids)), 'duplicate runner ID')
    require(set(expected).issubset(families), 'missing mandatory case family')
    return cases


def read_report(kind, path):
    raw = Path(path).read_bytes()
    if kind == 'go':
        cases = []; running = {}; packages = {}; seen_packages = set(); empty_packages = set()
        for line in raw.decode().splitlines():
            e = parse(line); require(isinstance(e, dict), 'malformed Go event')
            package = e.get('Package'); action = e.get('Action'); test = e.get('Test')
            require(isinstance(package, str) and package, 'missing Go package')
            require(action in ('start', 'run', 'pause', 'cont', 'pass', 'fail', 'skip', 'output', 'bench'), 'unknown Go action')
            seen_packages.add(package)
            require(package not in packages, 'event after Go package terminal')
            if action == 'output' and not test and re.fullmatch(r'\?\s+' + re.escape(package) + r'\s+\[no test files\]\n?', e.get('Output', '')):
                empty_packages.add(package)
            if test:
                require(isinstance(test, str), 'malformed Go test ID')
                key = package + '/' + test
                if action == 'run':
                    require(key not in running, 'duplicate Go run ID')
                    running[key] = 'run'
                elif action in ('pass', 'fail', 'skip'):
                    require(running.get(key) == 'run', 'terminal case without run')
                    running[key] = action
                    cases.append({'id': key, 'family': package + '/' + test.split('/')[0], 'status': action})
            elif action in ('pass', 'fail', 'skip'):
                require(package not in packages, 'duplicate package result')
                packages[package] = action
        require(seen_packages and set(packages) == seen_packages and
                all(v == 'pass' or (v == 'skip' and k in empty_packages and not any(x.startswith(k + '/') for x in running))
                    for k, v in packages.items()), 'missing/failed/skipped Go package')
        require(all(v == 'pass' for v in running.values()), 'unfinished/failed/skipped Go test')
    elif kind == 'flutter':
        suites = {}; running = {}; seen = set(); cases = []; done = False
        for line in raw.decode().splitlines():
            e = parse(line); require(isinstance(e, dict) and not done, 'malformed/event after Flutter done')
            typ = e.get('type')
            require(typ in ('start', 'suite', 'group', 'testStart', 'testDone', 'error', 'print', 'done', 'allSuites'), 'unknown Flutter event')
            if typ == 'suite':
                suite = e['suite']; require(suite['id'] not in suites, 'duplicate Flutter suite')
                suites[suite['id']] = suite['path'].replace('\\', '/')
            elif typ == 'testStart':
                t = e['test']; require(type(t['id']) is int and t['id'] >= 0 and t['id'] not in seen, 'duplicate/malformed Flutter runner ID')
                seen.add(t['id']); running[t['id']] = t
            elif typ == 'testDone':
                t = running.pop(e['testID'], None); require(t is not None, 'unknown Flutter runner ID')
                # Runner loading pseudo-tests are not executed application cases.
                if t.get('name', '').startswith('loading ') and e.get('hidden') is True:
                    require(e.get('result') == 'success' and not e.get('skipped'), 'failed Flutter loader')
                    continue
                family = suites.get(t.get('suiteID'), '')
                family = family[family.index('mobile/test/'):] if 'mobile/test/' in family else family
                require(family and isinstance(t.get('name'), str), 'missing Flutter suite/name')
                cases.append({'id': str(e['testID']), 'family': family, 'name': t['name'],
                              'status': 'pass' if e.get('result') == 'success' and e.get('skipped') is False else 'fail'})
            elif typ == 'error':
                raise Rejected('Flutter error event')
            elif typ == 'done':
                require(not done and e.get('success') is True, 'Flutter did not complete successfully'); done = True
        require(done and not running, 'incomplete Flutter report')
    elif kind == 'vitest':
        report = parse(raw); cases = []
        require(isinstance(report, dict) and report.get('success') is True and isinstance(report.get('testResults'), list), 'failed Vitest run')
        for suite in report.get('testResults', []):
            family = suite['name'].replace('\\', '/')
            family = family[family.index('web-bill-viewer/'):] if 'web-bill-viewer/' in family else family
            for i, c in enumerate(suite.get('assertionResults', [])):
                # The ordinal preserves parameterized tests with the same displayed title.
                cases.append({'id': family + ':' + str(i) + ':' + c['fullName'], 'family': family, 'name': c['fullName'],
                              'status': 'pass' if c['status'] == 'passed' else c['status']})
        require(type(report.get('numTotalTests')) is int and type(report.get('numPassedTests')) is int and
                report['numTotalTests'] == len(cases) and report['numPassedTests'] == len(cases),
                'Vitest counters mismatch')
        require(report.get('numPendingTests', 0) == 0 and report.get('numTodoTests', 0) == 0,
                'Vitest skip/todo')
    elif kind == 'cases':
        report = parse(raw)
        require(isinstance(report, dict) and report.get('complete') is True and report.get('success') is True and
                type(report.get('tests_run')) is int and report['tests_run'] > 0, 'incomplete runner adapter report')
        cases = report.get('cases')
        require(isinstance(cases, list) and isinstance(report.get('started'), list) and
                len(report['started']) == report['tests_run'] and len(set(report['started'])) == report['tests_run'] and
                all(sum(c.get('id') == ident for c in cases) == 1 for ident in report['started']), 'missing runner terminals')
    else:
        raise Rejected('unknown report format')
    return raw, cases


def summarize(row, reports, manifest, b):
    require(row in ROWS, 'unknown check row')
    require([[kind, Path(path).name] for kind, path in reports] == manifest['reports'][row], 'missing/unexpected report selection')
    all_cases = []; digests = []
    for kind, path in reports:
        raw, cases = read_report(kind, path)
        # Separate runner namespaces; no deduplication across default and tagged jobs.
        all_cases += [dict(c, id=Path(path).name + ':' + c['id']) for c in cases]
        digests.append(digest(raw))
    validate_cases(all_cases, manifest['rows'][row])
    # Match each literal registration to a distinct runner case. Parameterized
    # expansions retain every ID; no synthetic total replaces the runtime report.
    for family, patterns in manifest.get('required_selections', {}).get(row, {}).items():
        available = [c for c in all_cases if c['family'] == family]
        assigned = {}
        def match(index, visited):
            for case_index, case in enumerate(available):
                if case_index not in visited and re.search(patterns[index], case.get('name', '')):
                    visited.add(case_index)
                    if case_index not in assigned or match(assigned[case_index], visited):
                        assigned[case_index] = index
                        return True
            return False
        require(all(match(index, set()) for index in range(len(patterns))), 'missing mandatory test registration')
    return dict(b, row=row, passed=len(all_cases), failed=0, skipped=0,
                manifest=digest(compact(manifest).encode()), reports=digests)


def trusted_manifest():
    manifest = parse(Path(__file__).with_name('case_manifest.json').read_bytes())
    require(manifest.get('version') == 1 and set(manifest.get('rows', {})) == set(ROWS) and
            set(manifest.get('reports', {})) == set(ROWS) and all(manifest['rows'].values()), 'invalid trusted case manifest')
    return manifest


def manifest_hash():
    return digest(compact(trusted_manifest()).encode())


def validate_summary(summary, row, b):
    require(isinstance(summary, dict) and all(summary.get(k) == v for k, v in b.items()), 'report source/controller/scope/run mismatch')
    require(summary.get('row') == row and type(summary.get('passed')) is int and summary['passed'] > 0,
            'missing/zero row report')
    require(type(summary.get('skipped')) is int and type(summary.get('failed')) is int and
            summary['skipped'] == 0 and summary['failed'] == 0, 'report failure/skip')
    require(summary.get('manifest') == manifest_hash() and
            len(summary.get('reports', [])) == len(trusted_manifest()['reports'][row]), 'untrusted/missing report manifest')
    hashes = [summary.get('manifest')] + summary.get('reports', [])
    require(len(hashes) >= 2 and all(isinstance(h, str) and re.fullmatch('[0-9a-f]{64}', h) for h in hashes),
            'malformed report hashes')


def collect(needs, b):
    require(b.get('scope') == 'all', 'only the full gate is supported')
    require(isinstance(needs, dict) and set(needs) == set(ROWS), 'missing/unexpected selected result')
    rows = {}
    for row in ROWS:
        n = needs[row]
        require(n.get('result') == 'success', 'selected check did not succeed: ' + row)
        summary = parse(n.get('outputs', {}).get('report', ''))
        validate_summary(summary, row, b)
        rows[row] = digest(compact(summary).encode())
    return dict(b, rows=rows, manifest=manifest_hash(), status='success')


def verify_receipt(receipt, b):
    require(isinstance(receipt, dict) and receipt.get('status') == 'success' and
            receipt.get('manifest') == manifest_hash() and
            all(receipt.get(k) == v for k, v in b.items()) and
            set(receipt.get('rows', {})) == set(ROWS), 'unmatched gate output')
    require(all(isinstance(v, str) and re.fullmatch('[0-9a-f]{64}', v) for v in receipt['rows'].values()),
            'invalid gate row digest')
    return receipt


def publication_selection(event, ref, requested, policy_text, changed_paths=None):
    require(requested in ('checks', 'backend', 'web', 'both'), 'invalid publication selection')
    if ref != 'refs/heads/main' or event not in ('push', 'workflow_dispatch'):
        return []
    try:
        policy = parse(policy_text)
        require(policy.get('version') == 1 and isinstance(policy.get('enabled_targets'), list), 'disabled policy')
        enabled = policy['enabled_targets']
        require(all(t in TARGETS for t in enabled), 'unknown publication target')
    except (Rejected, AttributeError):
        enabled = []
    selected = ['backend', 'web'] if event == 'push' or requested == 'both' else ([] if requested == 'checks' else [requested])
    if event == 'push' and changed_paths is not None:
        shared = any(p.startswith(('.github/', 'ops/ci/')) for p in changed_paths)
        selected = [t for t, prefix in [('backend', 'backend/'), ('web', 'web-bill-viewer/')]
                    if shared or any(p.startswith(prefix) for p in changed_paths)]
    if event == 'workflow_dispatch':
        require(set(selected).issubset(enabled), 'requested publication disabled by RELEASE_POLICY')
    return [t for t in selected if t in enabled]


def authorize(repo, target, receipt, b, env, policy):
    require(target in TARGETS, 'unknown target')
    require(env.get('GITHUB_REF') == 'refs/heads/main' and env.get('GITHUB_EVENT_NAME') in ('push', 'workflow_dispatch'),
            'publication requires main push/main dispatch')
    workflow = (REPOSITORY + '/.github/workflows/' + IOS_WORKFLOWS[target] + '@refs/heads/main') if target in IOS_WORKFLOWS else WORKFLOW
    require(env.get('GITHUB_REPOSITORY') == REPOSITORY and env.get('GITHUB_WORKFLOW_REF') == workflow,
            'untrusted publication controller')
    if target in IOS_WORKFLOWS:
        require(env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'iOS requires main dispatch')
    require(env.get('GITHUB_SHA') == b['controller'], 'C differs from workflow controller')
    verify_receipt(receipt, b)
    require(isinstance(policy, dict) and policy.get('version') == 1, 'missing/invalid RELEASE_POLICY')
    enabled = policy.get('enabled_targets')
    require(isinstance(enabled, list) and len(enabled) == len(set(enabled)) and
            all(t in TARGETS for t in enabled) and target in enabled, 'target disabled/unknown')
    main = sha(git(repo, 'rev-parse', 'refs/remotes/origin/main'))
    ancestor(repo, sha(policy.get('control_floor')), b['controller']); ancestor(repo, b['controller'], main)
    targets = policy.get('targets'); require(isinstance(targets, dict), 'invalid targets')
    t = targets.get(target); require(isinstance(t, dict), 'missing target policy')
    ancestor(repo, sha(t.get('source_floor')), b['source']); ancestor(repo, b['source'], main)
    if env['GITHUB_EVENT_NAME'] == 'push':
        require(main == b['controller'] == b['source'], 'stale automatic publication')
    require(isinstance(t.get('external_clearance'), str) and t['external_clearance'].strip(), 'missing external release clearance')
    floors = t.get('capability_floors')
    require(isinstance(floors, dict) and bool(floors), 'missing capability floors')
    for name, floor in floors.items():
        require(re.fullmatch('[a-z][a-z0-9_]{0,63}', name) is not None, 'invalid capability name')
        ancestor(repo, sha(floor), b['source'])
    ancestor(repo, sha(t.get('schema_floor')), b['source'])
    raw = subprocess.run(['git', '-C', str(repo), 'show', b['source'] + ':backend/migrations/registry.go'], capture_output=True, check=False)
    require(raw.returncode == 0, 'missing schema registry')
    registry = raw.stdout.decode()
    require(digest(registry.encode()) == t.get('schema_registry_sha256'), 'unknown schema registry')
    epochs = re.findall(r'^const CompatibilityEpoch = ([0-9]+)$', registry, re.M)
    versions = [int(x) for x in re.findall(r'\{Version: ([0-9]+),', registry)]
    require(len(epochs) == 1 and int(epochs[0]) == t.get('schema_epoch') and
            type(t.get('minimum_migration')) is int and t['minimum_migration'] > 0 and
            versions == list(range(1, len(versions)+1)) and len(versions) >= t['minimum_migration'],
            'incompatible/old schema floor')
    # Registry identity + ancestry are source evidence only; clearance is externally held.
    return dict(b, target=target, main=main, policy_sha256=digest(compact(policy).encode()))


def safe_url(value, host=None):
    require(isinstance(value, str) and value and not re.search(r'[\x00-\x20\x7f]', value), 'missing/unsafe URL')
    try:
        u = urllib.parse.urlsplit(value)
        require(u.scheme == 'https' and u.hostname and u.username is None and u.password is None and
                u.port in (None, 443) and not u.fragment and (host is None or u.hostname == host), 'untrusted URL')
    except ValueError:
        raise Rejected('untrusted URL') from None
    return u


def hook_url(value, source):
    u = safe_url(value, 'api.render.com'); sha(source)
    require(u.path.startswith('/deploy/') and len(u.path) > len('/deploy/'), 'invalid hook path')
    try:
        params = urllib.parse.parse_qsl(u.query, keep_blank_values=True, strict_parsing=True)
    except ValueError as e:
        raise Rejected('invalid hook query') from e
    require(all(re.fullmatch('[A-Za-z0-9_.-]+', k) and not re.search(r'[\x00-\x1f\x7f]', v) for k, v in params),
            'unsafe hook query')
    require(len([v for k, v in params if k == 'key' and v.strip()]) == 1 and
            len([k for k, v in params if k == 'key']) == 1, 'missing/ambiguous hook credential')
    require(not any(k == 'imgURL' for k, v in params), 'image hook is not the source publishing route')
    params = [(k, v) for k, v in params if k != 'ref'] + [('ref', source)]
    return urllib.parse.urlunsplit(u._replace(query=urllib.parse.urlencode(params)))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise Rejected('redirect refused')


def http(method, url):
    try:
        # HTTPError carries the real status/body for expected negative routes.
        # Redirects are refused before any request can reach a different host.
        try:
            response = urllib.request.build_opener(NoRedirect).open(urllib.request.Request(url, method=method), timeout=60)
        except urllib.error.HTTPError as error:
            response = error
        with response as r:
            body = r.read(1024*1024+1)
            require(len(body) <= 1024*1024, 'oversized transport response')
            return r.status, body
    except Exception as e:
        # Do not expose URL, query credential, response or exception text.
        raise Rejected('transport request failed') from None


def healthy(code, body, source):
    try:
        data = parse(body)
        return code == 200 and isinstance(data, dict) and data.get('status') == 'bill service - ok' and data.get('commit') == sha(source)
    except (ValueError, TypeError):
        return False


def deploy_backend(source, hook, base, verification_only=False, request=http, clock=time.monotonic, sleep=time.sleep):
    sha(source); u = safe_url(base, 'billington-api.onrender.com')
    require(u.path in ('', '/') and not u.query, 'invalid health base')
    if not verification_only:
        code, body = request('POST', hook_url(hook, source))
        require(code in (200, 202) and isinstance(parse(body), dict), 'hook failed')
    deadline = clock() + 900  # Preserve the free-instance cold-start allowance.
    while clock() < deadline:
        try:
            code, body = request('GET', base.rstrip('/') + '/health')
            if healthy(code, body, source):
                break
        except Rejected:
            pass
        sleep(15)
    else:
        raise Rejected('exact healthy revision not observed within 900 seconds')
    # This read proves the negative route response only. DB readiness is /health.
    code, _ = request('GET', base.rstrip('/') + '/api/bills/0?t=smoketest')
    require(code in (400, 404), 'unexpected unknown-resource response (auth is not database health)')
    return {'source': source, 'verification': 'exact-health', 'triggered': not verification_only}


def mirror_plan(repo, source, hosts, run_git=git):
    sha(source)
    require(Path(hosts).read_text() == HOST_KEY, 'untrusted GitHub host key')
    split = sha(run_git(repo, 'subtree', 'split', '--prefix=web-bill-viewer', source))
    require(run_git(repo, 'rev-parse', split + '^{tree}') == run_git(repo, 'rev-parse', source + ':web-bill-viewer'),
            'subtree tree mismatch')
    return split


def sync_web(repo, source, key, hosts, run_git=git):
    require(isinstance(key, str) and key.strip() and '\x00' not in key, 'missing mirror credential')
    split = mirror_plan(repo, source, hosts, run_git)
    with tempfile.TemporaryDirectory(prefix='delivery-ssh-') as temp:
        private = Path(temp) / 'key'; private.write_text(key); private.chmod(0o600)
        known = Path(temp) / 'known_hosts'; known.write_text(Path(hosts).read_text()); known.chmod(0o600)
        # Fixed paths created by tempfile, quoted for spaces; no key in command/log/config.
        import shlex
        env = dict(os.environ, GIT_SSH_COMMAND='ssh -F /dev/null -i ' + shlex.quote(str(private)) +
                   ' -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlgorithms=ssh-ed25519' +
                   ' -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=' + shlex.quote(str(known)), GIT_TERMINAL_PROMPT='0')
        remote = run_git(repo, 'ls-remote', '--refs', MIRROR, 'refs/heads/main', env=env)
        require(re.fullmatch('[0-9a-f]{40}\trefs/heads/main', remote) is not None, 'missing/ambiguous remote lease')
        old = sha(remote.split('\t')[0])
        run_git(repo, 'push', '--force-with-lease=refs/heads/main:' + old, MIRROR, split + ':refs/heads/main', env=env)
    return {'source': source, 'subtree': split, 'previous_remote': old, 'provider_deployment': 'NOT VERIFIED'}


def emit(name, value):
    require('\n' not in value and '\r' not in value, 'unsafe output')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
        f.write(name + '=' + value + '\n')


def main():
    p = argparse.ArgumentParser(); p.add_argument('command', choices=['resolve', 'assert-checkout', 'validate-reports', 'summarize', 'collect', 'required', 'publish', 'ios-unavailable'])
    p.add_argument('--repo', default='control'); p.add_argument('--source'); p.add_argument('--controller'); p.add_argument('--row'); p.add_argument('--reports', nargs='*', default=[])
    a = p.parse_args(); e = os.environ
    if a.command == 'ios-unavailable':
        raise Rejected('F-phase required: verified processed build + immutable IPA/source/origin-run+attempt/ASC eligibility receipt; all iOS writes disabled')
    if a.command == 'validate-reports':
        # Local verification of the same reports; deliberately no run binding,
        # receipt or GitHub output that a publisher could consume.
        print(compact(summarize(a.row, [x.split(':', 1) for x in a.reports], trusted_manifest(), {})))
        return
    if a.command == 'assert-checkout':
        assert_checkout(a.repo, a.source); return
    assert_checkout(a.repo, a.controller)
    if a.command == 'resolve':
        s = resolve(a.repo, a.controller, e.get('REQUESTED_SOURCE', ''), e['GITHUB_EVENT_NAME'], e['GITHUB_REF'])
        emit('candidate', s); emit('controller', sha(a.controller))
        changed = None
        if e['GITHUB_EVENT_NAME'] == 'push' and e['GITHUB_REF'] == 'refs/heads/main':
            before = sha(e.get('BEFORE_SOURCE', ''))
            if before != '0' * 40:
                ancestor(a.repo, before, s)
                changed = git(a.repo, 'diff', '--name-only', before, s).splitlines()
        selected = publication_selection(e['GITHUB_EVENT_NAME'], e['GITHUB_REF'], e.get('REQUESTED_TARGET', 'checks'), e.get('RELEASE_POLICY', ''), changed)
        for target in ('backend', 'web'):
            emit(target, 'true' if target in selected else 'false')
        return
    require(e.get('GITHUB_SHA') == a.controller, 'C differs from workflow SHA')
    b = binding(e, a.source, a.controller)
    require(e.get('CHECK_SCOPE', 'all') == 'all', 'unproved narrow scope')
    if a.command == 'summarize':
        r = summarize(a.row, [x.split(':', 1) for x in a.reports], trusted_manifest(), b)
        emit('report', compact(r)); return
    if a.command == 'required':
        needs = parse(e['NEEDS'])
        require(set(needs) == {'resolve', 'checks'} and all(n.get('result') == 'success' for n in needs.values()),
                'required full gate dependency failed/skipped/cancelled/missing')
        require(needs['resolve']['outputs']['candidate'] == b['source'] and
                needs['resolve']['outputs']['controller'] == b['controller'], 'resolved source mismatch')
        r = verify_receipt(parse(needs['checks']['outputs'].get('receipt', '')), b)
        emit('receipt', compact(r)); emit('source', b['source']); emit('controller', b['controller']); return
    if a.command == 'collect':
        r = collect(parse(e['NEEDS']), b)
        emit('receipt', compact(r)); emit('source', b['source']); emit('controller', b['controller']); return
    receipt = parse(e.get('GATE_RECEIPT', '')); target = e.get('DELIVERY_TARGET', '')
    require(target in ('backend', 'web'), 'source publisher supports backend/web only')
    policy = parse(e.get('RELEASE_POLICY', ''))
    # Fresh inside the noncancelling environment job; no candidate checkout or code.
    git(a.repo, 'fetch', '--no-tags', 'origin', '+refs/heads/main:refs/remotes/origin/main')
    approved = authorize(a.repo, target, receipt, b, e, policy)
    if target == 'backend':
        require(e.get('VERIFY_ONLY', 'false') in ('true', 'false'), 'invalid verification-only value')
        result = deploy_backend(a.source, e.get('DELIVERY_RENDER_DEPLOY_HOOK_URL', ''),
                                'https://billington-api.onrender.com', e.get('VERIFY_ONLY') == 'true')
    else:
        result = sync_web(a.repo, a.source, e.get('DELIVERY_VERCEL_DEPLOY_KEY', ''), Path(__file__).with_name('github_known_hosts'))
    print(compact(dict(approved, transport=result)))


if __name__ == '__main__':
    try:
        main()
    except (Rejected, OSError, KeyError, TypeError, AttributeError) as error:
        # Sanitized; arbitrary operator values/transport exceptions never reach logs.
        print('Delivery gate rejected: ' + (str(error) if isinstance(error, Rejected) else 'missing or malformed contract'), file=sys.stderr)
        sys.exit(1)
