"""The signed-IPA action's bounded lifecycle; only Runner is rewritten.

This module is imported with fake commands in offline tests. Importing it never
runs a platform tool, creates credentials, or contacts a service.
"""
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import signal
import shlex
import subprocess
import sys
import tempfile
import time

import delivery_gate as gate
import ios_artifact as artifact


def close_owned_group(process):
    # A completed parent may still own live descendants. Close that group on
    # every path, then reap the direct child and require the group to disappear.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    finally:
        process.wait(timeout=5)
    deadline = time.monotonic() + 5
    while True:
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            return
        gate.require(time.monotonic() < deadline, 'owned build process group did not stop')
        time.sleep(0.01)


def command(args, cwd=None, env=None):
    # Tool output may contain signing material or signed URLs. Capture privately,
    # impose a deadline, retain no raw diagnostics and never log argv/ENV.
    with tempfile.TemporaryFile() as output:
        try:
            p = subprocess.Popen(args, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT,
                                 start_new_session=True)
            try:
                p.wait(timeout=2700)
            finally:
                close_owned_group(p)
            gate.require(p.returncode == 0, 'signed build tool failed')
            gate.require(output.tell() <= 16 * 1024 * 1024, 'build output exceeds bound')
            output.seek(0)
            return output.read()
        except (OSError, subprocess.TimeoutExpired):
            raise gate.Rejected('signed build tool failed/timed out') from None


def configure_runner(raw, uuid):
    text = raw.decode(); count = 0; result = []
    for part in text.split('};'):
        if 'CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";' in part:
            for before, after in [('CODE_SIGN_STYLE = Automatic;', 'CODE_SIGN_STYLE = Manual;'),
                                  ('CODE_SIGN_IDENTITY = "Apple Development";', 'CODE_SIGN_IDENTITY = "Apple Distribution";'),
                                  ('PROVISIONING_PROFILE_SPECIFIER = "";', 'PROVISIONING_PROFILE_SPECIFIER = "' + uuid + '";')]:
                gate.require(part.count(before) == 1, 'Runner signing configuration drift')
                part = part.replace(before, after)
            count += 1
        result.append(part)
    gate.require(count == 3, 'ambiguous Runner signing targets')
    return '};'.join(result).encode()


def sign(context, candidate, env, run=command, profile_dir=None):
    gate.require(context['authorization']['target'] == 'ios-upload', 'signing requires upload authority')
    if context['verification_only']:
        return {'verified': True, 'writes': 0}
    gate.assert_checkout(candidate, context['binding']['source'])
    source = context['source']; tool = context['toolchain']
    build = artifact.field(env.get('BUILD_NUMBER'), artifact.BUILD, 'invalid binary build input')
    gate.require(env.get('BUILD_NAME') == source['version'] and env.get('BUNDLE_ID') == source['bundle'], 'signed action version/bundle mismatch')
    team = artifact.field(env.get('TEAM_ID'), r'[A-Z0-9]{10}', 'invalid signing team')
    project = candidate / 'mobile/ios/Runner.xcodeproj/project.pbxproj'
    backup = project.read_bytes()
    gate.require(backup.decode().count('DEVELOPMENT_TEAM = ' + team + ';') >= 3, 'project signing team mismatch')
    gate.require(backup == artifact.blob(env['CONTROL_REPO'], source=context['binding']['source'], path='mobile/ios/Runner.xcodeproj/project.pbxproj'), 'candidate project differs from S')
    for path, digest in source['locks'].items():
        gate.require(gate.digest((candidate / path).read_bytes()) == digest, 'candidate lock differs from S')
    runenv = dict(os.environ, DEVELOPER_DIR=tool['developer_dir'])
    # Do not pass certificate/ASC/GitHub credentials to package acquisition or
    # Flutter build scripts. Signing uses the installed temporary keychain.
    for name in list(runenv):
        if name.startswith(('DELIVERY_', 'ASC_', 'SIGN_')) or name in ('GH_TOKEN','GITHUB_TOKEN','P12_PASSWORD','CERTIFICATE_BASE64','PROFILE_BASE64'):
            del runenv[name]
    gate.require(run(['xcodebuild','-version'], env=runenv).decode().strip() == tool['xcode'], 'Xcode pin mismatch')
    gate.require(run(['xcrun','--sdk','iphoneos','--show-sdk-version'], env=runenv).decode().strip() == tool['sdk'], 'SDK pin mismatch')
    gate.require(run(['pod','--version'], env=runenv).decode().strip() == tool['cocoapods'], 'CocoaPods pin mismatch')
    flutter = json.loads(run(['flutter','--version','--machine'], env=runenv))
    gate.require(flutter.get('frameworkVersion') == tool['flutter'], 'Flutter pin mismatch')
    mobile = candidate / 'mobile'
    output = mobile / 'build/ios/ipa'
    gate.require(not output.exists() or not list(output.glob('*.ipa')), 'stale IPA output; origin must build once')
    export = mobile / 'ios/ExportOptions.plist'
    gate.require(not export.is_symlink(), 'unsafe export options path')
    previous_export = export.read_bytes() if export.exists() else None
    profiles = profile_dir or Path.home() / 'Library/MobileDevice/Provisioning Profiles'
    installed = None; keychain = None; original_keychains = None; cleanup_errors = []
    with tempfile.TemporaryDirectory(prefix='ios-sign-', dir=env.get('RUNNER_TEMP')) as temp:
        temp = Path(temp)
        primary_error = None
        try:
            cert = temp / 'certificate.p12'; profile = temp / 'profile.mobileprovision'
            for path, name in [(cert,'CERTIFICATE_BASE64'),(profile,'PROFILE_BASE64')]:
                raw = base64.b64decode(env.get(name, ''), validate=True)
                gate.require(raw, 'empty signing material')
                path.write_bytes(raw); path.chmod(0o600)
            profile_data = plistlib.loads(run(['security','cms','-D','-i',str(profile)], env=runenv))
            uuid = artifact.field(profile_data.get('UUID'), r'[A-Fa-f0-9-]{36}', 'invalid profile UUID')
            expiry = profile_data.get('ExpirationDate')
            gate.require(isinstance(expiry, datetime) and expiry.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc), 'profile expired/missing expiry')
            ent = profile_data.get('Entitlements', {})
            gate.require(ent.get('application-identifier') == team + '.' + source['bundle'] and
                         ent.get('com.apple.developer.team-identifier') == team and ent.get('get-task-allow') is False and
                         not profile_data.get('ProvisionedDevices') and not profile_data.get('ProvisionsAllDevices'), 'profile is not exact App Store distribution')
            profiles.mkdir(parents=True, exist_ok=True)
            destination_profile = profiles / (uuid + '.mobileprovision')
            gate.require(not destination_profile.exists(), 'refuse overwriting preexisting signing profile')
            # Mark as owned only after the collision check.
            installed = destination_profile
            installed.write_bytes(profile.read_bytes()); installed.chmod(0o600)
            original_keychains = shlex.split(run(['security','list-keychains','-d','user'], env=runenv).decode())
            keychain = temp / 'signing.keychain-db'; password = secrets.token_hex(24)
            run(['security','create-keychain','-p',password,str(keychain)], env=runenv)
            run(['security','set-keychain-settings','-lut','3600',str(keychain)], env=runenv)
            run(['security','unlock-keychain','-p',password,str(keychain)], env=runenv)
            run(['security','import',str(cert),'-P',env.get('P12_PASSWORD',''),'-A','-t','cert','-f','pkcs12','-k',str(keychain)], env=runenv)
            run(['security','set-key-partition-list','-S','apple-tool:,apple:','-s','-k',password,str(keychain)], env=runenv)
            run(['security','list-keychains','-d','user','-s',str(keychain),*original_keychains], env=runenv)
            project.write_bytes(configure_runner(backup, uuid))
            export.write_bytes(plistlib.dumps({'method':'app-store-connect','teamID':team,'signingStyle':'manual','uploadSymbols':True,
                                              'provisioningProfiles':{source['bundle']:uuid}}))
            run(['flutter','pub','get','--enforce-lockfile'], cwd=mobile, env=runenv)
            run(['pod','install','--deployment'], cwd=mobile / 'ios', env=runenv)
            for path, digest in source['locks'].items():
                gate.require(gate.digest((candidate / path).read_bytes()) == digest, 'acquisition changed locked dependencies')
            run(['flutter','build','ipa','--release','--no-pub','--build-name='+source['version'],'--build-number='+build,
                 '--export-options-plist=ios/ExportOptions.plist'], cwd=mobile, env=runenv)
            ipas = list(output.glob('*.ipa'))
            gate.require(len(ipas) == 1 and ipas[0].is_file() and not ipas[0].is_symlink(), 'missing/multiple IPA outputs')
            payload = ipas[0].read_bytes()
            binary = artifact.inspect_ipa(payload, {'bundle':source['bundle'],'version':source['version'],'build':build,'platform':'IOS'})
            destination = Path(env['IPA_DIR']); destination.mkdir(parents=True, exist_ok=False)
            (destination / 'candidate.ipa').write_bytes(payload)
            return binary
        except BaseException as error:
            primary_error = error
            raise
        finally:
            def clean(label, action):
                try:
                    action()
                except BaseException:
                    cleanup_errors.append(label)

            clean('project', lambda: project.write_bytes(backup))
            clean('export options', lambda: export.unlink(missing_ok=True) if previous_export is None else export.write_bytes(previous_export))
            if installed is not None:
                clean('owned profile', lambda: installed.unlink(missing_ok=True))
            if original_keychains is not None:
                clean('keychain search list', lambda: run(['security','list-keychains','-d','user','-s',*original_keychains], env=runenv))
            if keychain is not None:
                clean('temporary keychain', lambda: run(['security','delete-keychain',str(keychain)], env=runenv))
            if cleanup_errors:
                error = gate.Rejected('signing cleanup failed: ' + ', '.join(cleanup_errors))
                if primary_error is not None:
                    raise error from primary_error
                raise error from None


def main():
    env = dict(os.environ); env['CONTROL_REPO'] = env.get('CONTROL_REPO', 'control')
    ctx = artifact.context(env['CONTROL_REPO'], env)
    result = sign(ctx, Path('candidate').resolve(), env)
    if not ctx['verification_only']:
        gate.emit('ipa_path', str((Path(env['IPA_DIR'])/'candidate.ipa').resolve()))
        gate.emit('ipa_sha256', result['sha256'])
    print('Signed IPA lifecycle verified')


if __name__ == '__main__':
    def interrupted(*_):
        raise InterruptedError('owned signing operation interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    try:
        main()
    except Exception:
        print('Signed IPA rejected; verify authority, inputs, exact toolchain, packaging and cleanup', file=sys.stderr)
        sys.exit(1)
