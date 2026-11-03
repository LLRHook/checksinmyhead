#!/usr/bin/env python3
"""Local CLI regressions: stub all app/tool side effects.

python3 scripts/test_local_workflow.py
Real PostgreSQL: scripts/verify_local_lifecycle.py (separate, explicit fixture).
"""
import importlib.util
import json
import os
import pty
import select
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

# Every tool with service/simulator/acquisition effects is a stub. npm deliberately
# owns a real child + grandchild to prove process-group cleanup, not just argv strings.
STUB = r'''
import json,os,signal,subprocess,sys,time
from pathlib import Path
root=Path(os.environ['FIXTURE'])
tool=Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'calls').open('a') as f: f.write(json.dumps([tool,args,str(Path.cwd())])+'\n')
case=os.environ.get('CASE','')
if tool=='node': print('v24.17.0')
elif tool=='lsof': sys.exit(0 if os.environ.get('OCCUPIED') in ('all', next((a for a in args if a.startswith('-iTCP:')), '')) else 1)
elif tool=='docker':
    if args==['compose','version']:
        if case=='no-compose': sys.exit('compose unavailable')
    elif args==['info']: pass
    elif args[:2]==['stop','--time']:
        state=json.loads((root/'state').read_text()); state[args[-1]]='stopped'; (root/'state').write_text(json.dumps(state))
        if case=='stop-failure': sys.exit(51)
    elif args[0]=='inspect':
        state=json.loads((root/'state').read_text())
        running=state.get(args[-1])=='running'
        if args[2]=='{{.State.Running}}': print(str(running).lower())
        else: print(('true ' if running else 'false ')+('starting' if case=='health-timeout' else 'unhealthy' if case=='health-failure' else 'healthy'))
    elif args[0]=='compose':
        command=args[3:]; state=json.loads((root/'state').read_text())
        if command==['config','--quiet'] and case=='bad-config': sys.stderr.write('SYNTHETIC_COMPOSE_DETAIL\n'); sys.exit(41)
        if command[:3]==['ps','--all','--quiet']:
            service=command[-1]; print(next((k for k in state if k.endswith(service)),''))
        if command[0] in ('up','start'):
            service=command[-1]; identifier=next((k for k in state if k.endswith(service)), 'owned-'+service)
            state[identifier]='running'; (root/'state').write_text(json.dumps(state))
            if case=='signal-up': time.sleep(2)
            if case=='partial-up' and service=='bill-service': sys.stderr.write('SYNTHETIC_UP_DETAIL\n'); sys.exit(45)
elif tool=='npm':
    if args==['--version']: print('11.12.1')
    elif args==['ci']:
        if case=='npm-ci-failure': sys.stderr.write('SYNTHETIC_NPM_DETAIL\n'); sys.exit(42)
    elif args==['run','dev']:
        if case=='npm-run-failure': sys.stderr.write('SYNTHETIC_NEXT_DETAIL\n'); sys.exit(42)
        code="import os,signal,subprocess,sys,time; from pathlib import Path; p=Path(sys.argv[1]); child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(120)',str(p)]); p.write_text(str(os.getpid())+' '+str(child.pid)); signal.signal(signal.SIGTERM,lambda *a: (child.wait(),sys.exit(0))); time.sleep(120)"
        child=subprocess.Popen([sys.executable,'-c',code,str(root/'descendants')])
        (root/'npm-pid').write_text(str(os.getpid()))
        def stop(*_):
            child.wait(timeout=4); sys.exit(0)
        signal.signal(signal.SIGTERM,stop)
        while not (root/'descendants').exists(): time.sleep(.01)
        if case=='web-exit-after-ready': time.sleep(1); sys.exit(46)
        child.wait()
elif tool=='flutter':
    if args==['--version','--machine']: print(json.dumps({'frameworkVersion':'3.41.5'}))
    elif args==['pub','get','--enforce-lockfile'] and case=='flutter-setup-failure': sys.stderr.write('SYNTHETIC_FLUTTER_DETAIL\n'); sys.exit(44)
    elif args[:2]==['run','--no-pub']:
        if case=='flutter-quit': sys.exit(0)
        if case=='flutter-interactive':
            print('SYNTHETIC_FLUTTER_INPUT_READY',flush=True)
            sys.exit(0 if sys.stdin.readline().strip()=='q' else 47)
        if case=='flutter-pod-request': sys.exit(subprocess.call(['pod','install','--verbose']))
        time.sleep(120)
elif tool=='pod':
    if args==['--version']: print('1.16.2')
    elif args==['install','--deployment'] and case=='pod-setup-failure': sys.stderr.write('SYNTHETIC_POD_DETAIL\n'); sys.exit(43)
elif tool=='xcrun':
    if args[:2]==['simctl','getenv'] and case=='sim-timeout': sys.exit(1)
    if args[:4]==['simctl','list','devices','available']:
        count=2 if case=='ambiguous-sim' else 1
        print(json.dumps({'devices':{'com.apple.CoreSimulator.SimRuntime.iOS-26-0':[{'udid':'sim-'+str(i),'state':'Shutdown' if case=='explicit-sim' else 'Booted','isAvailable':True} for i in range(count)]}}))
elif tool=='curl':
    if ':3100' in args[-1]:
        if case=='web-timeout' or not (root/'descendants').exists(): sys.exit(22)
    elif case=='api-http-failure': sys.stderr.write('SYNTHETIC_CURL_DETAIL\n'); sys.exit(22)
    elif case=='flutter-quit': time.sleep(2.1)
'''


def alive(pid):
    result = subprocess.run(['/bin/ps', '-o', 'stat=', '-p', str(pid)], capture_output=True, text=True)
    return result.returncode == 0 and result.stdout.strip() and not result.stdout.strip().startswith('Z')


class StartupFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='billington-cli-test-')
        self.root = Path(self.tmp.name).resolve()
        for folder in ('bin', 'backend', 'web-bill-viewer/node_modules/.bin', '.github/workflows', 'mobile/.dart_tool', 'mobile/ios/Pods'):
            (self.root/folder).mkdir(parents=True)
        shutil.copy(ROOT/'dev.sh', self.root/'dev.sh')
        (self.root/'scripts').mkdir()
        shutil.copy(ROOT/'scripts/dev_runtime.py', self.root/'scripts/dev_runtime.py')
        (self.root/'backend/.env.example').write_text('DB_NAME=synthetic_only\n')
        # This must remain bytes, never executable shell input.
        self.env_bytes = b'DB_NAME=synthetic\nDONT_EVAL=$(touch NEVER_EVAL)\n'
        (self.root/'backend/.env').write_bytes(self.env_bytes)
        (self.root/'web-bill-viewer/.env.local').write_bytes(self.env_bytes)
        (self.root/'web-bill-viewer/.node-version').write_text('24\n')
        (self.root/'web-bill-viewer/node_modules/.bin/next').touch(mode=0o700)
        (self.root/'.github/workflows/ci.yml').write_text('FLUTTER_VERSION: 3.41.5\n')
        (self.root/'mobile/.dart_tool/package_config.json').write_text('{}')
        for name in ('Podfile.lock', 'Pods/Manifest.lock'):
            (self.root/'mobile/ios'/name).write_text('COCOAPODS: 1.16.2\n')
        (self.root/'state').write_text('{}')
        for tool in ('docker', 'node', 'npm', 'flutter', 'pod', 'xcrun', 'curl', 'lsof'):
            path=self.root/'bin'/tool
            path.write_text('#!'+sys.executable+'\n'+STUB)
            path.chmod(0o700)
        (self.root/'bin/python3').symlink_to(sys.executable)
        # Ordinary lifecycle cases are not short-deadline benchmarks. The healthy
        # quit case includes a2.1s API response, within curl's three-second limit.
        # Timeout-specific cases below select their own one-second stage budget.
        self.env = dict(os.environ, FIXTURE=str(self.root), PATH=str(self.root/'bin')+':/usr/bin:/bin:/usr/sbin', BILLINGTON_READY_TIMEOUT='5', TMPDIR=str(self.root))
        self.env.pop('BILLINGTON_SIMULATOR_ID', None)
        self.process = None

    def tearDown(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=12)
        # On a regression, collect all owned descendant IDs before discarding fixture.
        for path in (self.root/'descendants', self.root/'npm-pid'):
            if path.exists():
                for pid in map(int, path.read_text().split()):
                    if alive(pid):
                        cmd=subprocess.check_output(['/bin/ps','-o','command=','-p',str(pid)],text=True)
                        if str(self.root) in cmd: os.kill(pid, signal.SIGKILL)
        self.tmp.cleanup()

    def calls(self):
        path=self.root/'calls'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def run_cli(self, args=('--no-mobile',), case='', active=False, signum=signal.SIGTERM, repeat=False):
        self.env['CASE']=case
        with (self.root/'stdout').open('w') as stdout, (self.root/'stderr').open('w') as stderr:
            self.process=subprocess.Popen(['/bin/bash', str(self.root/'dev.sh'), *args], env=self.env, cwd=self.root, stdout=stdout, stderr=stderr, start_new_session=True)
            if active == 'up':
                deadline=time.monotonic()+10
                while not any(c[0]=='docker' and 'up' in c[1] for c in self.calls()):
                    if time.monotonic()>deadline: self.fail('up never reached')
                    time.sleep(.03)
                self.process.send_signal(signum)
            elif active:
                deadline=time.monotonic()+12
                while 'Ready:' not in (self.root/'stdout').read_text() or not (self.root/'descendants').exists():
                    if self.process.poll() is not None: self.fail((self.root/'stderr').read_text())
                    if time.monotonic()>deadline: self.fail('CLI never became ready')
                    time.sleep(.03)
                # Mobile starts just after the web ready line.
                if not args:
                    while not any(c[0]=='flutter' and c[1][:1]==['run'] for c in self.calls()):
                        if self.process.poll() is not None or time.monotonic()>deadline: self.fail('Flutter never started')
                        time.sleep(.03)
                self.process.send_signal(signum)
                if repeat:
                    time.sleep(.05)
                    if self.process.poll() is None: self.process.send_signal(signum)
            rc=self.process.wait(timeout=15)
        self.assertFalse((self.root/'NEVER_EVAL').exists())
        return rc, (self.root/'stdout').read_text()+(self.root/'stderr').read_text()

    def stopped(self):
        return [a[-1] for tool,a,_ in self.calls() if tool=='docker' and a[:1]==['stop']]

    def assert_no_runtime(self):
        self.assertFalse(self.stopped())
        self.assertFalse(any(c[0]=='docker' and any(a in ('up','start','down') for a in c[1]) for c in self.calls()))

class StartupTests(StartupFixture):
    def test_missing_flutter_has_no_cleanup(self):
        (self.root/'bin/flutter').unlink()
        rc,out=self.run_cli(())
        self.assertEqual(rc,1); self.assertIn('Missing flutter',out); self.assert_no_runtime()

    def test_missing_compose_has_no_cleanup(self):
        rc,out=self.run_cli(case='no-compose')
        self.assertEqual(rc,1); self.assertIn('docker compose version',out); self.assert_no_runtime()

    def test_toolchain_mismatch_has_no_cleanup(self):
        (self.root/'web-bill-viewer/.node-version').write_text('99\n')
        rc,out=self.run_cli()
        self.assertEqual(rc,1); self.assertIn('Use Node 99',out); self.assert_no_runtime()

    def test_missing_env_requests_setup_without_writing(self):
        (self.root/'backend/.env').unlink()
        rc,out=self.run_cli()
        self.assertEqual(rc,1); self.assertIn('setup',out); self.assertFalse((self.root/'backend/.env').exists()); self.assert_no_runtime()

    def test_missing_web_dependencies_requests_setup(self):
        (self.root/'web-bill-viewer/node_modules/.bin/next').unlink()
        rc,out=self.run_cli()
        self.assertEqual(rc,1); self.assertIn('setup',out); self.assert_no_runtime()

    def test_stale_mobile_lock_requests_setup(self):
        (self.root/'mobile/ios/Pods/Manifest.lock').write_text('different')
        rc,out=self.run_cli(())
        self.assertEqual(rc,1); self.assertIn('setup',out); self.assert_no_runtime()

    def test_setup_locks_and_preserves_env(self):
        rc,out=self.run_cli(('setup',))
        self.assertEqual(rc,0,out)
        self.assertIn(['npm',['ci'],str(self.root/'web-bill-viewer')],self.calls())
        self.assertIn(['flutter',['pub','get','--enforce-lockfile'],str(self.root/'mobile')],self.calls())
        self.assertIn(['pod',['install','--deployment'],str(self.root/'mobile/ios')],self.calls())
        self.assertEqual((self.root/'backend/.env').read_bytes(),self.env_bytes)
        self.assertEqual((self.root/'web-bill-viewer/.env.local').read_bytes(),self.env_bytes)
        self.assert_no_runtime()

    def test_setup_creates_only_missing_env_examples(self):
        (self.root/'backend/.env').unlink(); (self.root/'web-bill-viewer/.env.local').unlink()
        rc,out=self.run_cli(('setup','--no-mobile'))
        self.assertEqual(rc,0,out)
        self.assertEqual((self.root/'backend/.env').read_bytes(),(self.root/'backend/.env.example').read_bytes())
        self.assertEqual((self.root/'web-bill-viewer/.env.local').read_text(),'NEXT_PUBLIC_API_URL=http://localhost:8080\n')
        self.assertFalse(any(c[0] in ('flutter','pod','xcrun') for c in self.calls()))
        self.assert_no_runtime()

    def test_setup_failure_keeps_diagnostic_and_exit42(self):
        rc,out=self.run_cli(('setup',),case='npm-ci-failure')
        self.assertEqual(rc,42); self.assertIn('SYNTHETIC_NPM_DETAIL',out); self.assertIn('web locked setup',out); self.assert_no_runtime()
        self.assertFalse(any(c[1][:2]==['pub','get'] for c in self.calls()))

    def test_flutter_setup_failure_keeps_status(self):
        rc,out=self.run_cli(('setup',),case='flutter-setup-failure')
        self.assertEqual(rc,44); self.assertIn('SYNTHETIC_FLUTTER_DETAIL',out); self.assert_no_runtime()

    def test_pod_setup_failure_keeps_status(self):
        rc,out=self.run_cli(('setup',),case='pod-setup-failure')
        self.assertEqual(rc,43); self.assertIn('SYNTHETIC_POD_DETAIL',out); self.assert_no_runtime()

    def test_quiet_config_failure_keeps_status(self):
        rc,out=self.run_cli(case='bad-config')
        self.assertEqual(rc,41); self.assertIn('SYNTHETIC_COMPOSE_DETAIL',out); self.assert_no_runtime()

    def test_occupied_web_port_is_not_killed(self):
        self.env['OCCUPIED']='-iTCP:3100'
        rc,out=self.run_cli()
        self.assertEqual(rc,1); self.assertIn('3100 is occupied',out); self.assert_no_runtime()

    def test_occupied_api_port_stops_only_owned_postgres(self):
        self.env['OCCUPIED']='-iTCP:8080'
        rc,out=self.run_cli()
        self.assertEqual(rc,1); self.assertIn('8080 is occupied',out); self.assertEqual(self.stopped(),['owned-postgres'])

    def test_health_failure_stops_only_new_service(self):
        rc,out=self.run_cli(case='health-failure')
        self.assertEqual(rc,1); self.assertIn('not healthy',out); self.assertEqual(self.stopped(),['owned-postgres'])

    def test_health_wait_is_bounded(self):
        self.env['BILLINGTON_READY_TIMEOUT']='1'
        start=time.monotonic(); rc,out=self.run_cli(case='health-timeout')
        self.assertEqual(rc,1); self.assertIn('timed out',out); self.assertLess(time.monotonic()-start,7)
        self.assertEqual(self.stopped(),['owned-postgres'])

    def test_partial_up_failure_stops_exact_owned_containers(self):
        rc,out=self.run_cli(case='partial-up')
        self.assertEqual(rc,45); self.assertIn('SYNTHETIC_UP_DETAIL',out)
        self.assertEqual(self.stopped(),['owned-bill-service','owned-postgres'])

    def test_api_probe_failure_keeps_status(self):
        rc,out=self.run_cli(case='api-http-failure')
        self.assertEqual(rc,22); self.assertIn('SYNTHETIC_CURL_DETAIL',out)
        self.assertEqual(self.stopped(),['owned-bill-service','owned-postgres'])

    def test_npm_startup_failure_shows_log_and_exit42(self):
        rc,out=self.run_cli(case='npm-run-failure')
        self.assertEqual(rc,42); self.assertIn('SYNTHETIC_NEXT_DETAIL',out); self.assertIn('Next.js startup',out)

    def test_term_repeated_cleanup_no_installs_and_descendants(self):
        rc,out=self.run_cli(active=True,repeat=True)
        self.assertEqual(rc,143,out)
        self.assertEqual(self.stopped(),['owned-bill-service','owned-postgres'])
        self.assertFalse(any(c[1][:1] in (['ci'],['install'],['pub']) for c in self.calls()))
        self.assertFalse(any(c[0] in ('flutter','pod','xcrun') for c in self.calls()))
        for name in ('npm-pid','descendants'):
            for pid in map(int,(self.root/name).read_text().split()): self.assertFalse(alive(pid),f'{name} survived cleanup: {pid}')
        run_dirs=list(self.root.glob('billington-dev.*'))
        self.assertEqual(len(run_dirs),1); self.assertEqual(run_dirs[0].stat().st_mode & 0o777,0o700)
        self.assertIn(str(run_dirs[0]/'web.log'),out)

    def test_int_keeps_status130(self):
        rc,out=self.run_cli(active=True,signum=signal.SIGINT)
        self.assertEqual(rc,130,out)

    def test_preexisting_running_services_are_never_started_or_stopped(self):
        (self.root/'state').write_text(json.dumps({'pre-postgres':'running','pre-bill-service':'running'}))
        rc,out=self.run_cli(active=True)
        self.assertEqual(rc,143,out); self.assertEqual(self.stopped(),[])
        self.assertFalse(any('up' in c[1] or 'start' in c[1] for c in self.calls() if c[0]=='docker'))

    def test_preexisting_stopped_service_is_started_and_stopped_by_id(self):
        (self.root/'state').write_text(json.dumps({'pre-postgres':'stopped'}))
        rc,out=self.run_cli(active=True)
        self.assertEqual(rc,143,out); self.assertEqual(self.stopped(),['owned-bill-service','pre-postgres'])
        self.assertTrue(any(c[1][-2:]==['start','postgres'] for c in self.calls()))

    def test_cleanup_failure_does_not_replace_original_exit(self):
        rc,out=self.run_cli(case='stop-failure',active=True)
        self.assertEqual(rc,143,out); self.assertIn('Could not stop owned container',out)

    def test_ambiguous_simulator_fails_before_startup(self):
        rc,out=self.run_cli((),case='ambiguous-sim')
        self.assertEqual(rc,1); self.assertIn('Select one available iOS simulator',out); self.assert_no_runtime()

    def test_explicit_simulator_and_flutter_no_acquisition(self):
        self.env['BILLINGTON_SIMULATOR_ID']='sim-0'
        rc,out=self.run_cli((),case='explicit-sim',active=True)
        self.assertEqual(rc,143,out)
        self.assertTrue(any(c[1]==['simctl','boot','sim-0'] for c in self.calls()))
        self.assertTrue(any(c[1]==['run','--no-pub','-d','sim-0'] for c in self.calls()))
        self.assertFalse(any(c[1][:1] in (['ci'],['install'],['pub']) for c in self.calls()))

    def test_flutter_cannot_silently_run_pod_install(self):
        rc,out=self.run_cli((),case='flutter-pod-request')
        self.assertEqual(rc,1,out); self.assertIn('CocoaPods acquisition requested',out)
        self.assertFalse(any(c[0]=='pod' and c[1][:1]==['install'] for c in self.calls()))

    def test_interactive_flutter_owns_terminal_for_quit(self):
        self.env['CASE']='flutter-interactive'
        pid,fd=pty.fork()
        if pid==0:
            os.chdir(self.root)
            os.execve('/bin/bash',['/bin/bash',str(self.root/'dev.sh')],self.env)
        status=None; output=b''; sent=False; deadline=time.monotonic()+15
        try:
            while time.monotonic()<deadline:
                if select.select([fd],[],[],.1)[0]:
                    try:
                        chunk=os.read(fd,8192)
                    except OSError:
                        chunk=b''
                    output+=chunk
                if b'SYNTHETIC_FLUTTER_INPUT_READY' in output and not sent:
                    os.write(fd,b'q\n'); sent=True
                done,status_now=os.waitpid(pid,os.WNOHANG)
                if done:
                    status=status_now; break
            self.assertIsNotNone(status,output.decode(errors='replace'))
            self.assertEqual(os.waitstatus_to_exitcode(status),0,output.decode(errors='replace'))
            self.assertTrue(sent)
            self.assertEqual(self.stopped(),['owned-bill-service','owned-postgres'])
        finally:
            if status is None:
                os.kill(pid,signal.SIGTERM); os.waitpid(pid,0)
            os.close(fd)

    def test_normal_flutter_quit_returns_success_and_cleans_owned_work(self):
        rc,out=self.run_cli((),case='flutter-quit')
        self.assertEqual(rc,0,out)
        self.assertEqual(self.stopped(),['owned-bill-service','owned-postgres'])

    def test_simulator_wait_is_bounded(self):
        self.env['BILLINGTON_READY_TIMEOUT']='1'
        start=time.monotonic(); rc,out=self.run_cli((),case='sim-timeout')
        self.assertEqual(rc,1,out); self.assertIn('simulator readiness timed out',out)
        self.assertLess(time.monotonic()-start,12)

    def test_preexisting_unhealthy_service_is_never_stopped(self):
        (self.root/'state').write_text(json.dumps({'pre-postgres':'running'}))
        rc,out=self.run_cli(case='health-failure')
        self.assertEqual(rc,1,out); self.assertEqual(self.stopped(),[])

    def test_signal_during_partial_up_stops_created_container(self):
        rc,out=self.run_cli(case='signal-up',active='up')
        self.assertEqual(rc,143,out); self.assertEqual(self.stopped(),['owned-postgres'])

    def test_web_exit_while_running_keeps_exit_and_kills_descendants(self):
        rc,out=self.run_cli(case='web-exit-after-ready')
        self.assertEqual(rc,46,out)
        for pid in map(int,(self.root/'descendants').read_text().split()): self.assertFalse(alive(pid))

    def test_web_readiness_timeout_is_bounded(self):
        self.env['BILLINGTON_READY_TIMEOUT']='1'
        start=time.monotonic(); rc,out=self.run_cli(case='web-timeout')
        self.assertEqual(rc,1,out); self.assertIn('Next.js readiness timed out',out)
        self.assertLess(time.monotonic()-start,10)


spec=importlib.util.spec_from_file_location('reset_local_test',ROOT/'scripts/reset_local_test.py')
reset_module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reset_module)


class ResetGuardTests(unittest.TestCase):
    def setUp(self):
        self.project='billington-test-12345678'
        self.owner='unique-owner-123456789'
        labels={reset_module.PROJECT_LABEL:self.project,reset_module.OWNER_LABEL:self.owner,reset_module.DATA_LABEL:'synthetic'}
        self.volume={'Name':self.project+'_postgres_data','Labels':dict(labels)}
        self.container={'Id':'exact-container-id','Labels':dict(labels),'Mounts':[{'Type':'volume','Name':self.volume['Name']}]}
        self.network={'Id':'exact-network-id','Labels':dict(labels)}
        self.mutations=[]

    def docker(self,*args):
        if args[:2]==('ps','--all'): return self.container['Id']
        if args[:2]==('volume','ls'): return self.volume['Name']
        if args[:2]==('network','ls'): return self.network['Id']
        if args[:2]==('container','inspect'): return json.dumps(self.container)
        if args[:2]==('volume','inspect'): return json.dumps([self.volume])
        if args[:2]==('network','inspect'): return json.dumps([self.network])
        self.mutations.append(args); return ''

    def reject(self):
        with patch.object(reset_module,'docker',self.docker), self.assertRaises(ValueError):
            reset_module.reset(self.project,self.owner)
        self.assertEqual(self.mutations,[])

    def test_reject_normal_project_before_docker(self):
        self.project='backend'; self.reject()

    def test_reject_missing_explicit_owner(self):
        self.owner=''; self.reject()

    def test_reject_wrong_volume_owner_before_any_deletion(self):
        self.volume['Labels'][reset_module.OWNER_LABEL]='wrong'; self.reject()

    def test_reject_missing_synthetic_label_before_any_deletion(self):
        del self.volume['Labels'][reset_module.DATA_LABEL]; self.reject()

    def test_reject_wrong_container_owner_before_any_deletion(self):
        self.container['Labels'][reset_module.OWNER_LABEL]='wrong'; self.reject()

    def test_reject_wrong_network_owner_before_any_deletion(self):
        self.network['Labels'][reset_module.OWNER_LABEL]='wrong'; self.reject()

    def test_reject_external_volume_mount_before_any_deletion(self):
        self.container['Mounts'][0]['Name']='backend_postgres_data'; self.reject()

    def test_reject_bind_mount_before_any_deletion(self):
        self.container['Mounts']=[{'Type':'bind','Source':'/do-not-touch'}]; self.reject()

    def test_reset_only_exact_owned_resources(self):
        with patch.object(reset_module,'docker',self.docker): reset_module.reset(self.project,self.owner)
        self.assertEqual(self.mutations,[('container','rm','--force','exact-container-id'),('volume','rm',self.volume['Name']),('network','rm','exact-network-id')])


if __name__ == '__main__':
    # Let the process/PTY regressions share fixtures without inheriting and
    # executing the original startup test cases a second time.
    sys.modules['test_local_workflow'] = sys.modules[__name__]
    from test_local_workflow_probes import ProbeTests
    unittest.main(verbosity=2)
