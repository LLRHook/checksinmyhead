"""Authenticated processed-IPA provenance for the existing delivery gate.

No local receipt path is accepted for promotion. Only a named, digest-checked
artifact from an explicit successful run AND attempt can cross that seam.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import plistlib
import re
import stat
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

import delivery_gate as gate

require = gate.require
Rejected = gate.Rejected
ORIGIN = '.github/workflows/testflight.yml'
PREFIX = '/repos/' + gate.REPOSITORY
MAX_ARCHIVE = 512 * 1024 * 1024
MAX_JSON = 2 * 1024 * 1024
MAX_PAGES = 20
VERSION = r'[0-9]+\.[0-9]+\.[0-9]+'
BUILD = r'[0-9]+(?:\.[0-9]+){0,2}'
LOCKS = ('mobile/pubspec.lock', 'mobile/ios/Podfile.lock')


def positive(value):
    require(isinstance(value, (str, int)) and not isinstance(value, bool) and
            re.fullmatch(r'[1-9][0-9]{0,18}', str(value)) is not None, 'invalid run/attempt/artifact ID')
    return str(value)


def field(value, pattern, reason):
    require(isinstance(value, str) and re.fullmatch(pattern, value) is not None, reason)
    return value


def timestamp(value):
    try:
        result = datetime.fromisoformat(value.replace('Z', '+00:00'))
        require(result.tzinfo is not None, 'missing timestamp timezone')
        return result.timestamp()
    except (ValueError, TypeError, AttributeError):
        raise Rejected('invalid evidence timestamp') from None


class RawRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None


@contextmanager
def request_deadline():
    # This CLI owns a single POSIX main thread on macOS/Linux. Socket idle
    # timeouts alone do not bound a peer that trickles headers or body bytes.
    require(signal.getitimer(signal.ITIMER_REAL) == (0.0, 0.0), 'nested evidence deadline refused')
    previous = signal.getsignal(signal.SIGALRM)
    def expired(*_):
        raise Rejected('evidence request exceeded 60-second deadline')
    signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, 60)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def transport(url, headers, limit):
    """One bounded HTTPS GET. Redirects, error bodies and credentials are never logged."""
    gate.safe_url(url)
    try:
        with request_deadline():
            try:
                response = urllib.request.build_opener(RawRedirect).open(
                    urllib.request.Request(url, headers=headers, method='GET'), timeout=60)
            except urllib.error.HTTPError as error:
                response = error
            with response as response:
                body = response.read(limit + 1)
                require(len(body) <= limit, 'evidence response too large')
                return response.status, {k.lower(): v for k, v in response.headers.items()}, body
    except Rejected:
        raise
    except Exception:
        raise Rejected('evidence transport failed') from None


class GitHub:
    def __init__(self, token, download_hosts, request=transport, clock=time.monotonic):
        require(isinstance(token, str) and token and not re.search(r'[\x00-\x20\x7f]', token), 'missing GitHub artifact token')
        require(isinstance(download_hosts, list) and download_hosts and len(download_hosts) <= 8, 'missing artifact download host policy')
        for host in download_hosts:
            field(host, r'[a-z0-9.-]+', 'invalid artifact host')
            require(host.endswith(('.blob.core.windows.net', '.actions.githubusercontent.com')), 'unapproved artifact host suffix')
        self.headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                        'X-GitHub-Api-Version': '2026-03-10'}
        self.hosts = download_hosts
        self.request = request
        self.clock = clock

    def api(self, path, limit=MAX_JSON):
        require(isinstance(path, str) and path.startswith(PREFIX + '/') and
                not re.search(r'[\x00-\x20\x7f#]', path) and not any(x in path for x in ('..', '\\', '%')), 'untrusted GitHub evidence path')
        return self.request('https://api.github.com' + path, self.headers.copy(), limit)

    def json(self, path):
        code, _, body = self.api(path)
        require(code == 200, 'GitHub evidence unavailable (missing/expired/forbidden); select an evidenced origin')
        require(len(body) <= MAX_JSON, 'oversized GitHub JSON evidence')
        data = gate.parse(body)
        require(isinstance(data, dict), 'malformed GitHub evidence')
        return data

    def pages(self, path, key):
        require('?' not in path, 'invalid pagination base')
        seen = set(); records = []; count = None
        for page in range(1, MAX_PAGES + 1):
            obj = self.json(path + '?per_page=100&page=' + str(page))
            total = obj.get('total_count'); rows = obj.get(key)
            require(type(total) is int and 0 <= total <= 100 * MAX_PAGES and isinstance(rows, list) and len(rows) <= 100,
                    'unbounded/malformed GitHub pagination')
            if count is None:
                count = total
            require(total == count, 'evidence changed during pagination')
            for row in rows:
                ident = positive(row.get('id'))
                require(ident not in seen, 'duplicate evidence across pages')
                seen.add(ident); records.append(row)
            require(len(records) <= total, 'inconsistent pagination total')
            if len(records) == total:
                return records
            require(rows, 'incomplete evidence pagination')
        raise Rejected('evidence pagination limit reached')

    def archive(self, metadata):
        ident = positive(metadata.get('id'))
        code, headers, _ = self.api(PREFIX + '/actions/artifacts/' + ident + '/zip', limit=MAX_JSON)
        require(code == 302, 'artifact missing/expired or download redirect absent; no legacy fallback')
        location = headers.get('location')
        u = gate.safe_url(location)
        require(u.hostname in self.hosts, 'artifact redirect host outside reviewed policy')
        start = self.clock()
        # Absolutely no GitHub Authorization, cookies or API headers at the signed URL.
        code, _, body = self.request(location, {}, MAX_ARCHIVE)
        require(self.clock() - start < 60 and code == 200 and len(body) <= MAX_ARCHIVE, 'artifact download failed/expired/oversized')
        require(len(body) == metadata.get('size_in_bytes') and 'sha256:' + gate.digest(body) == metadata.get('digest'), 'artifact archive size/digest mismatch')
        return body


def blob(repo, source, path):
    p = subprocess.run(['git', '-C', str(repo), 'show', gate.sha(source) + ':' + path], capture_output=True, check=False)
    require(p.returncode == 0, 'missing source version/lock evidence')
    return p.stdout


def source_metadata(repo, source):
    pubspec = blob(repo, source, 'mobile/pubspec.yaml').decode()
    versions = re.findall(r'^version: (' + VERSION + r')\+([1-9][0-9]*)\s*$', pubspec, re.M)
    require(len(versions) == 1, 'invalid source marketing/build version')
    version, number = versions[0]
    project = blob(repo, source, 'mobile/ios/Runner.xcodeproj/project.pbxproj').decode()
    # RunnerTests deliberately uses 1.0. Select only Runner configurations by its
    # FLUTTER_BUILD_NUMBER marker; Pods and test targets must never be rewritten.
    configs = [part for part in project.split('/* Begin XCBuildConfiguration section */')[-1].split('};')
               if 'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";' in part]
    require(len(configs) == 3 and all(re.search(r'MARKETING_VERSION = ' + re.escape(version) + r';', c) for c in configs),
            'Runner/source marketing version mismatch')
    bundles = [re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = "?([A-Za-z0-9.-]+)"?;', c) for c in configs]
    require(all(len(x) == 1 for x in bundles) and len({x[0] for x in bundles}) == 1, 'ambiguous Runner bundle')
    settings = blob(repo, source, 'mobile/lib/screens/settings/settings_screen.dart').decode()
    require(len(re.findall(r"'Version " + re.escape(version) + r"'", settings)) == 1, 'Settings/source version mismatch')
    return {'bundle': bundles[0][0], 'version': version, 'source_build': number, 'platform': 'IOS',
            'locks': {p: gate.digest(blob(repo, source, p)) for p in LOCKS}}


def zip_entries(raw, expected=None):
    require(len(raw) <= MAX_ARCHIVE, 'oversized archive')
    try:
        archive = zipfile.ZipFile(io.BytesIO(raw))
        entries = archive.infolist()
        require(0 < len(entries) <= 50000 and len({i.filename for i in entries}) == len(entries), 'empty/duplicate archive entries')
        require(sum(i.file_size for i in entries) <= 2 * MAX_ARCHIVE, 'expanded archive too large')
        for info in entries:
            name = info.filename
            require(not name.startswith('/') and '\\' not in name and '..' not in name.split('/') and
                    not re.search(r'[\x00-\x1f\x7f]', name) and not info.flag_bits & 1 and
                    not stat.S_ISLNK(info.external_attr >> 16), 'unsafe archive member')
        if expected is not None:
            require(set(archive.namelist()) == set(expected), 'unexpected receipt/archive contents')
        return archive
    except (zipfile.BadZipFile, RuntimeError):
        raise Rejected('malformed archive') from None


def inspect_ipa(raw, expected):
    with zip_entries(raw) as archive:
        names = [n for n in archive.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info.plist', n)]
        require(len(names) == 1, 'missing/multiple primary IPA bundles')
        info = archive.getinfo(names[0]); require(info.file_size <= MAX_JSON, 'IPA plist too large')
        try:
            p = plistlib.loads(archive.read(info))
        except Exception:
            raise Rejected('invalid IPA metadata plist') from None
    actual = {'bundle': p.get('CFBundleIdentifier'), 'version': p.get('CFBundleShortVersionString'),
              'build': p.get('CFBundleVersion'), 'platform': 'IOS'}
    require(p.get('CFBundleSupportedPlatforms') == ['iPhoneOS'] and p.get('DTPlatformName') == 'iphoneos', 'wrong IPA platform')
    field(actual['build'], BUILD, 'invalid IPA build number')
    require(all(actual.get(k) == v for k, v in expected.items()), 'IPA metadata/source/build mismatch')
    return dict(actual, sha256=gate.digest(raw), bytes=len(raw))


def evidence_name(kind, b):
    require(kind in ('ipa', 'origin'), 'invalid artifact kind')
    return 'ios-' + kind + '-' + gate.sha(b['source']) + '-' + positive(b['run']) + '-' + positive(b['attempt'])


def verify_run(run, b, completed, workflow=ORIGIN):
    require(str(run.get('id')) == b['run'] and str(run.get('run_attempt')) == b['attempt'] and
            run.get('head_sha') == b['controller'] and run.get('head_branch') == 'main' and
            run.get('event') == 'workflow_dispatch' and run.get('path') in (workflow, workflow + '@refs/heads/main') and
            run.get('repository', {}).get('full_name') == gate.REPOSITORY and
            run.get('head_repository', {}).get('full_name') == gate.REPOSITORY and
            type(run.get('repository', {}).get('id')) is int and run['repository']['id'] > 0 and
            run.get('head_repository', {}).get('id') == run['repository']['id'], 'origin repository/workflow/event/S-C/run/attempt mismatch')
    if completed:
        require(run.get('status') == 'completed' and run.get('conclusion') == 'success', 'origin attempt was not successful')
    else:
        require(run.get('status') == 'in_progress' and run.get('conclusion') is None, 'current upload run is not active')


def verify_jobs(jobs, b, origin=False):
    # Reusable-job prefixes are set by GitHub. Match the exact final job name,
    # reject duplicate matches, and verify actual API attempt/head values.
    names = ['Gate ' + row for row in gate.ROWS] + ['Selected checks all', 'Required delivery checks']
    if origin:
        names += ['Upload iOS origin']
    selected = {}
    for name in names:
        matches = [j for j in jobs if j.get('name', '').split(' / ')[-1] == name]
        require(len(matches) == 1, 'missing/ambiguous origin gate job')
        j = matches[0]
        require(str(j.get('run_id')) == b['run'] and str(j.get('run_attempt')) == b['attempt'] and
                j.get('head_sha') == b['controller'] and j.get('status') == 'completed' and
                j.get('conclusion') == 'success', 'origin gate/upload job failed/skipped/wrong attempt')
        selected[name] = j
    return selected


def artifact_metadata(obj, name, b, now, repository_id):
    positive(obj.get('id'))
    require(obj.get('name') == name and obj.get('expired') is False and timestamp(obj.get('expires_at')) > now,
            'wrong-name/expired artifact; restore reviewed evidence, never rebuild on promotion')
    require(type(obj.get('size_in_bytes')) is int and 0 < obj['size_in_bytes'] <= MAX_ARCHIVE and
            re.fullmatch(r'sha256:[0-9a-f]{64}', str(obj.get('digest'))) is not None, 'artifact size/digest missing')
    run = obj.get('workflow_run', {})
    require(str(run.get('id')) == b['run'] and run.get('head_sha') == b['controller'] and
            run.get('head_branch') == 'main' and type(run.get('repository_id')) is int and
            run.get('repository_id') == run.get('head_repository_id') == repository_id, 'artifact origin metadata mismatch')
    return obj


def verify_origin(repo, env, policy, current_b, github, now=time.time):
    run_id = positive(env.get('ORIGIN_RUN')); attempt = positive(env.get('ORIGIN_ATTEMPT'))
    # API run data establishes C. S comes from the freshly gated current candidate,
    # never from the run's head_sha (which is C, not the application S).
    run = github.json(PREFIX + '/actions/runs/' + run_id + '/attempts/' + attempt)
    b = dict(current_b, run=run_id, attempt=attempt, controller=gate.sha(run.get('head_sha')))
    verify_run(run, b, True)
    gate.ancestor(repo, gate.sha(policy.get('control_floor')), b['controller'])
    gate.ancestor(repo, b['controller'], gate.sha(gate.git(repo, 'rev-parse', 'refs/remotes/origin/main')))
    origin_jobs = verify_jobs(github.pages(PREFIX + '/actions/runs/' + run_id + '/attempts/' + attempt + '/jobs', 'jobs'), b, True)
    upload_job = origin_jobs['Upload iOS origin']
    start = timestamp(upload_job.get('started_at')); end = timestamp(upload_job.get('completed_at'))
    require(start <= end, 'invalid origin attempt job window')
    artifacts = github.pages(PREFIX + '/actions/runs/' + run_id + '/artifacts', 'artifacts')
    name = evidence_name('origin', b)
    matches = [a for a in artifacts if a.get('name') == name]
    require(len(matches) == 1, 'origin receipt missing/ambiguous/expired; supply an exact evidenced run+attempt')
    meta = artifact_metadata(matches[0], name, b, now(), run['repository']['id'])
    require(start <= timestamp(meta.get('created_at')) <= end, 'receipt artifact outside selected origin attempt job')
    with zip_entries(github.archive(meta), ['receipt.json']) as archive:
        require(archive.getinfo('receipt.json').file_size <= MAX_JSON, 'oversized origin receipt')
        receipt = gate.parse(archive.read('receipt.json'))
    require(isinstance(receipt, dict) and set(receipt) == {'schema','repository','workflow','event','binding','gate','source','binary','toolchain','asc','ipa_artifact'}, 'unknown/legacy receipt schema')
    require(receipt['schema'] == 1 and receipt['repository'] == gate.REPOSITORY and receipt['workflow'] == ORIGIN and
            receipt['event'] == 'workflow_dispatch' and receipt['binding'] == b, 'receipt origin binding mismatch')
    gate.verify_receipt(receipt['gate'], b)
    source = source_metadata(repo, b['source'])
    require(receipt['source'] == source, 'receipt source/lock metadata mismatch')
    target = policy['targets'][env['DELIVERY_TARGET']]
    require(receipt['toolchain'] == target.get('toolchain'), 'origin toolchain outside current reviewed policy')
    ipa = receipt['ipa_artifact']
    require(isinstance(ipa, dict) and set(ipa) == {'id','name','digest'}, 'invalid IPA artifact receipt')
    imatches = [a for a in artifacts if str(a.get('id')) == str(ipa['id'])]
    require(len(imatches) == 1, 'exact IPA artifact missing/ambiguous')
    imeta = artifact_metadata(imatches[0], evidence_name('ipa', b), b, now(), run['repository']['id'])
    require(start <= timestamp(imeta.get('created_at')) <= end, 'IPA artifact outside selected origin attempt job')
    require({k: imeta[k] for k in ipa} == ipa, 'IPA artifact ID/name/digest mismatch')
    with zip_entries(github.archive(imeta), ['candidate.ipa']) as archive:
        actual = inspect_ipa(archive.read('candidate.ipa'), {k: receipt['binary'].get(k) for k in ('bundle','version','build','platform')})
    require(actual == receipt['binary'] and actual['bundle'] == source['bundle'] and actual['version'] == source['version'], 'IPA hash/binary provenance mismatch')
    asc = receipt['asc']
    require(isinstance(asc, dict) and set(asc) == {'app_id','build_id','bundle','version','build','platform','processing_state','audience','expired','expiration','uploaded_at'}, 'malformed processed-build receipt')
    for key in ('app_id','build_id'):
        field(asc.get(key), r'[A-Za-z0-9-]{1,100}', 'invalid ASC identity')
    require(asc['build_id'] == env.get('ASC_BUILD_ID') and all(asc[k] == actual[k] for k in ('bundle','version','build','platform')) and
            asc['processing_state'] == 'VALID' and asc['audience'] == 'APP_STORE_ELIGIBLE' and asc['expired'] is False and
            timestamp(asc['expiration']) > now(), 'unmatched/ineligible historical ASC receipt')
    timestamp(asc['uploaded_at'])
    return receipt


def context(repo, env, github=None, refresh=True):
    target = env.get('DELIVERY_TARGET')
    require(target in gate.IOS_WORKFLOWS, 'invalid iOS target')
    gate.assert_checkout(repo, env.get('CONTROLLER'))
    b = gate.binding(env, env.get('SOURCE'), env.get('CONTROLLER'))
    receipt = gate.parse(env.get('GATE_RECEIPT', ''))
    policy = gate.parse(env.get('RELEASE_POLICY', ''))
    if refresh:
        gate.git(repo, 'fetch', '--no-tags', 'origin', '+refs/heads/main:refs/remotes/origin/main')
    approved = gate.authorize(repo, target, receipt, b, env, policy)
    source = source_metadata(repo, b['source'])
    t = policy['targets'][target]
    require(source['bundle'] == t.get('bundle_id') and t.get('app_id') and isinstance(t.get('toolchain'), dict), 'missing/mismatched iOS app/toolchain policy')
    field(t['app_id'], r'[A-Za-z0-9-]{1,100}', 'invalid ASC app policy identity')
    tool = t['toolchain']
    require(set(tool) == {'flutter','xcode','sdk','cocoapods','developer_dir'} and tool['flutter'] == '3.41.5' and
            tool['cocoapods'] == '1.16.2' and field(tool['sdk'], r'[0-9]+\.[0-9]+(?:\.[0-9]+)?', 'invalid SDK pin') and
            int(tool['sdk'].split('.')[0]) >= 26 and
            re.fullmatch(r'/Applications/Xcode_[0-9]+(?:\.[0-9]+)*\.app/Contents/Developer', tool['developer_dir']) and
            re.fullmatch(r'Xcode [0-9]+(?:\.[0-9]+)*\nBuild version [A-Za-z0-9]+', tool['xcode']), 'invalid pinned toolchain')
    client = github or GitHub(env.get('GH_TOKEN'), t.get('artifact_download_hosts'))
    result = {'authorization': approved, 'source': source, 'gate': receipt, 'toolchain': tool, 'app_id': str(t['app_id']),
              'binding': b, 'verification_only': boolean(env, 'VERIFY_ONLY', False)}
    current_run = client.json(PREFIX + '/actions/runs/' + b['run'] + '/attempts/' + b['attempt'])
    verify_run(current_run, b, False, '.github/workflows/' + gate.IOS_WORKFLOWS[target])
    verify_jobs(client.pages(PREFIX + '/actions/runs/' + b['run'] + '/attempts/' + b['attempt'] + '/jobs', 'jobs'), b)
    if target == 'ios-upload':
        require(b['attempt'] == '1', 'upload reruns are ambiguous; reconcile prior attempt before a newly authorized origin')
        previous = source_metadata(repo, gate.sha(t.get('previous_source')))
        gate.ancestor(repo, t['previous_source'], b['source'])
        require(int(source['source_build']) > int(previous['source_build']) and
                tuple(map(int, source['version'].split('.'))) > tuple(map(int, previous['version'].split('.'))), 'origin requires the AGENTS marketing/source build bump')
    else:
        result['origin'] = verify_origin(repo, env, policy, b, client)
        require(result['origin']['asc']['app_id'] == result['app_id'], 'origin app differs from current app policy')
        require(env.get('VERSION_STRING') == source['version'], 'requested version differs from proven source')
    if refresh:
        # Recheck after potentially slow historical artifact downloads as well
        # as before them, still inside the noncancelling environment job.
        gate.git(repo, 'fetch', '--no-tags', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        result['authorization'] = gate.authorize(repo, target, receipt, b, env, policy)
    return result


def boolean(env, name, default):
    value = env.get(name, str(default).lower())
    require(value in ('true','false'), 'invalid boolean option')
    return value == 'true'


def main():
    p = argparse.ArgumentParser()
    p.add_argument('command', choices=['context','inspect','receipt'])
    p.add_argument('--repo', default='control')
    a = p.parse_args(); env = os.environ
    ctx = context(a.repo, env)
    if a.command == 'context':
        print(gate.compact(ctx)); return
    require(env['DELIVERY_TARGET'] == 'ios-upload', 'origin command requires upload policy')
    path = Path(env.get('IPA_PATH', ''))
    require(path.is_file() and not path.is_symlink(), 'missing/unsafe IPA output')
    build = field(env.get('BUILD_NUMBER'), BUILD, 'invalid build number')
    binary = inspect_ipa(path.read_bytes(), {'bundle':ctx['source']['bundle'],'version':ctx['source']['version'],'platform':'IOS','build':build})
    expected_hash = field(env.get('IPA_SHA256'), r'[0-9a-f]{64}', 'missing signed-action IPA hash')
    require(binary['sha256'] == expected_hash, 'IPA bytes differ from signed-action inspection')
    if a.command == 'inspect':
        print(gate.compact(binary)); return
    asc = gate.parse(Path(env['ASC_RECEIPT']).read_bytes())
    require(asc.pop('upload_ipa_sha256', None) == expected_hash, 'missing/mismatched local upload IPA witness')
    require(all(asc.get(k) == binary[k] for k in ('bundle','version','platform','build')) and
            asc.get('processing_state') == 'VALID' and asc.get('app_id') == ctx['app_id'], 'unprocessed/mismatched upload receipt')
    metadata = {'id': int(positive(env.get('IPA_ARTIFACT_ID'))), 'name':evidence_name('ipa',ctx['binding']),
                'digest': 'sha256:' + field(env.get('IPA_ARTIFACT_DIGEST'), r'[0-9a-f]{64}', 'missing uploaded IPA digest')}
    record = {'schema':1,'repository':gate.REPOSITORY,'workflow':ORIGIN,'event':'workflow_dispatch',
              'binding':ctx['binding'],'gate':ctx['gate'],'source':ctx['source'],'binary':binary,
              'toolchain':ctx['toolchain'],'asc':asc,'ipa_artifact':metadata}
    dest = Path(env['RECEIPT_DIR']); dest.mkdir(parents=True, exist_ok=False)
    (dest/'receipt.json').write_text(gate.compact(record) + '\n')


if __name__ == '__main__':
    try:
        main()
    except (Rejected, OSError, KeyError, TypeError, ValueError, AttributeError, zipfile.BadZipFile) as error:
        # Finite diagnostics only; transport errors, signed URLs and arbitrary data
        # never pass through the CLI error channel.
        # Rejected reasons originate only from fixed policy assertions and the
        # sanitized transports above. Never include arbitrary exception text.
        reason = str(error) if isinstance(error, Rejected) else 'missing/malformed evidence contract'
        print('iOS evidence rejected: ' + reason, file=sys.stderr)
        sys.exit(1)
