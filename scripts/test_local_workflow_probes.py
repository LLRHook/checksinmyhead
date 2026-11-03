#!/usr/bin/env python3
"""Inventory failures, real process groups and PTYs with synthetic service tools.

Run through test_local_workflow.py, which loads these cases once alongside the
existing startup/reset controls. No Docker daemon or simulator is contacted.
"""
import json
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import time

import test_local_workflow as base


PREFIX = r'''
import json,os,signal,subprocess,sys,time
from pathlib import Path
root=Path(os.environ['FIXTURE']);tool=Path(sys.argv[0]).name;args=sys.argv[1:];case=os.environ.get('CASE','')
def record():
    with (root/'calls').open('a') as f:f.write(json.dumps([tool,args,str(Path.cwd())])+'\n')
if tool=='docker' and args[:1]==['compose'] and args[3:6]==['ps','--all','--quiet'] and case.startswith('inventory-'):
    p=root/'inventory-count';n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n))
    if (case=='inventory-before' and n==1) or (case=='inventory-after' and n==2) or (case=='inventory-persistent' and n>=2):
        record();sys.stderr.write('SYNTHETIC_INVENTORY_FAILURE\n');sys.exit(57 if n==1 else 58)
blocked=(case=='blocked-inspect' and tool=='docker' and args[:1]==['inspect'] and 'Health' in args[2]) or \
    (case=='blocked-sim-list' and tool=='xcrun' and args[:4]==['simctl','list','devices','available']) or \
    (case=='blocked-sim-boot' and tool=='xcrun' and args[:2]==['simctl','boot']) or \
    (case=='blocked-sim-getenv' and tool=='xcrun' and args[:2]==['simctl','getenv'])
if blocked:
    record();child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(120)',str(root)])
    (root/'probe-pids').write_text(str(os.getpid())+' '+str(child.pid));time.sleep(120);sys.exit(0)
if case=='blocked-sim-boot' and tool=='xcrun' and args[:4]==['simctl','list','devices','available']:
    record();print(json.dumps({'devices':{'com.apple.CoreSimulator.SimRuntime.iOS-26-0':[{'udid':'sim-0','state':'Shutdown','isAvailable':True}]}}));sys.exit(0)
if case in ('blocked-sim-boot','blocked-sim-getenv') and tool=='curl' and ':3100' in args[-1]:
    record();deadline=time.monotonic()+2
    while not (root/'descendants').exists() and time.monotonic()<deadline:time.sleep(.01)
    sys.exit(0 if (root/'descendants').exists() else 22)
if case.startswith('tty-') and tool=='flutter' and args[:2]==['run','--no-pub']:
    record();(root/'flutter-pid').write_text(str(os.getpid()));(root/'flutter-ready').touch()
    print('SYNTHETIC_FLUTTER_INPUT_READY',flush=True);sys.exit(0 if sys.stdin.readline().strip()=='q' else 47)
'''

class ProbeTests(base.StartupFixture):
    def setUp(self):
        super().setUp()
        stub=base.STUB.replace("        if case=='web-exit-after-ready': time.sleep(1); sys.exit(46)",
            "        if case=='web-exit-after-ready': time.sleep(1); sys.exit(46)\n"
            "        if case=='tty-web-exit':\n"
            "            while not (root/'flutter-ready').exists(): time.sleep(.01)\n"
            "            sys.stderr.write('SYNTHETIC_LATE_WEB_FAILURE\\n');sys.exit(46)")
        assert stub!=base.STUB
        for tool in ('docker','node','npm','flutter','pod','xcrun','curl','lsof'):
            (self.root/'bin'/tool).write_text('#!'+sys.executable+'\n'+PREFIX+'\n'+stub)
        self.tty_pid=None;self.tty_status=None;self.tty_fd=None

    def observe(self,row):
        row['calls']=self.calls();row['stopped']=self.stopped()
        row['state']=json.loads((self.root/'state').read_text())
        return json.dumps({k:v for k,v in row.items() if k!='calls'},sort_keys=True)

    def force_owned_processes(self):
        # Test-failure teardown only. Every PID came from this fixture's stubs;
        # require its command to contain the unique root before signaling its group.
        groups=set()
        for name in ('probe-pids','flutter-pid','npm-pid','descendants'):
            p=self.root/name
            if not p.exists():continue
            for pid in map(int,p.read_text().split()):
                if base.alive(pid):
                    cmd=subprocess.check_output(['/bin/ps','-o','command=','-p',str(pid)],text=True)
                    if str(self.root) in cmd:
                        try:groups.add(os.getpgid(pid))
                        except ProcessLookupError:pass
        for group in groups:
            if group!=os.getpgrp():
                try:os.killpg(group,signal.SIGKILL)
                except ProcessLookupError:pass

    def tearDown(self):
        try:
            if self.tty_pid and self.tty_status is None:
                self.force_owned_processes()
                try:os.kill(self.tty_pid,signal.SIGKILL)
                except ProcessLookupError:pass
                try:_,self.tty_status=os.waitpid(self.tty_pid,0)
                except ChildProcessError:pass
            if self.tty_fd is not None:
                os.close(self.tty_fd);self.tty_fd=None
            if self.process and self.process.poll() is None:
                self.force_owned_processes()
                self.process.kill();self.process.wait(timeout=5)
            self.force_owned_processes()
        finally:super().tearDown()

    def test_failed_before_inventory_cannot_take_over_running_service(self):
        (self.root/'state').write_text(json.dumps({'pre-postgres':'running','pre-bill-service':'running'}))
        rc,out=self.inventory_run('inventory-before')
        takeover=any('up' in c[1] or 'start' in c[1] for c in self.calls() if c[0]=='docker')
        details=self.observe({'rc':rc,'output':out,'takeover':takeover})
        self.assertTrue(rc==57 and not takeover and not self.stopped(),details)

    def test_failed_after_inventory_keeps_pending_cleanup_and_status(self):
        rc,out=self.inventory_run('inventory-after')
        later_start=any(c[0]=='docker' and c[1][-1:] == ['bill-service'] and ('up' in c[1] or 'start' in c[1]) for c in self.calls())
        details=self.observe({'rc':rc,'output':out,'later_start':later_start})
        self.assertTrue(rc==58 and not later_start and self.stopped()==['owned-postgres'],details)

    def inventory_run(self,case):
        # A correct implementation exits before readiness. A broken one may reach
        # steady state; terminate only that case to observe its ownership cleanup.
        self.env['CASE']=case
        with (self.root/'stdout').open('w') as out,(self.root/'stderr').open('w') as err:
            self.process=subprocess.Popen(['/bin/bash',str(self.root/'dev.sh'),'--no-mobile'],cwd=self.root,env=self.env,stdout=out,stderr=err,start_new_session=True)
            deadline=time.monotonic()+12
            while self.process.poll() is None:
                if 'Ready:' in (self.root/'stdout').read_text():
                    self.process.send_signal(signal.SIGTERM);break
                if time.monotonic()>deadline:self.fail('inventory case neither exited nor reached controlled readiness')
                time.sleep(.02)
            rc=self.process.wait(timeout=12)
        return rc,(self.root/'stdout').read_text()+(self.root/'stderr').read_text()

    def blocked_probe(self,case,signum=None):
        self.env.update(CASE=case,BILLINGTON_READY_TIMEOUT='30' if signum else '1')
        if case=='blocked-sim-boot':self.env['BILLINGTON_SIMULATOR_ID']='sim-0'
        args=['--no-mobile'] if case=='blocked-inspect' else []
        with (self.root/'stdout').open('w') as stdout,(self.root/'stderr').open('w') as stderr:
            self.process=subprocess.Popen(['/bin/bash',str(self.root/'dev.sh'),*args],cwd=self.root,env=self.env,stdout=stdout,stderr=stderr,start_new_session=True)
            deadline=time.monotonic()+10
            while not (self.root/'probe-pids').exists():
                if self.process.poll() is not None or time.monotonic()>deadline:
                    details=self.observe({'setup_failed':True,'case':case,'rc':self.process.poll(),'output':(self.root/'stdout').read_text()+(self.root/'stderr').read_text()})
                    self.fail('blocked probe boundary was not reached: '+details)
                time.sleep(.02)
            if signum: self.process.send_signal(signum)
            start=time.monotonic();bounded=True
            try:rc=self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                bounded=False;self.force_owned_processes()
                rc=self.process.wait(timeout=8)
        out=(self.root/'stdout').read_text()+(self.root/'stderr').read_text()
        live=[pid for pid in map(int,(self.root/'probe-pids').read_text().split()) if base.alive(pid)]
        details=self.observe({'case':case,'bounded_without_intervention':bounded,'seconds_from_block':round(time.monotonic()-start,3),'rc':rc,'live_probe_pids':live,'output':out})
        self.assertTrue(bounded and not live,details)
        if signum: self.assertEqual(rc,128+signum,details)
        else: self.assertTrue(rc!=0 and 'timed out' in out.lower(),details)

    def test_blocked_container_inspection_has_a_real_deadline(self):self.blocked_probe('blocked-inspect')
    def test_blocked_simulator_listing_has_a_real_deadline(self):self.blocked_probe('blocked-sim-list')
    def test_blocked_simulator_boot_has_a_real_deadline(self):self.blocked_probe('blocked-sim-boot')
    def test_blocked_simulator_getenv_has_a_real_deadline(self):self.blocked_probe('blocked-sim-getenv')

    def tty_failure(self,case):
        self.env['CASE']=case
        pid,fd=pty.fork()
        if pid==0:
            os.chdir(self.root);os.execve('/bin/bash',['/bin/bash',str(self.root/'dev.sh')],self.env)
        self.tty_pid=pid;self.tty_fd=fd
        output=b'';ready=False;boundary=None;intervened=False;deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            if select.select([fd],[],[],.05)[0]:
                try:output+=os.read(fd,8192)
                except OSError:pass
            if b'SYNTHETIC_FLUTTER_INPUT_READY' in output and not ready:
                ready=True;boundary=time.monotonic()
                if case in ('tty-driver-term','tty-driver-int'):
                    os.kill(pid,signal.SIGTERM if case=='tty-driver-term' else signal.SIGINT)
            done,status=os.waitpid(pid,os.WNOHANG)
            if done:self.tty_status=status;break
            if ready and time.monotonic()-boundary>4 and not intervened:
                # Release a broken foreground implementation so teardown cannot hang.
                intervened=True;os.write(fd,b'q\n')
        if self.tty_status is None:self.fail('TTY driver did not terminate even after controlled q')
        rc=os.waitstatus_to_exitcode(self.tty_status)
        live=[]
        for name in ('flutter-pid','npm-pid','descendants'):
            p=self.root/name
            if p.exists():live.extend(pid for pid in map(int,p.read_text().split()) if base.alive(pid))
        details=self.observe({'case':case,'ready':ready,'required_q_intervention':intervened,'rc':rc,'live_owned_pids':live,'output':output.decode(errors='replace')})
        self.assertTrue(ready and not intervened and rc==({'tty-driver-term':143,'tty-driver-int':130,'tty-web-exit':46}[case]) and not live,details)

    def test_tty_driver_term_interrupts_foreground_flutter(self):self.tty_failure('tty-driver-term')
    def test_tty_late_web_failure_is_supervised(self):self.tty_failure('tty-web-exit')
    def test_term_during_blocked_docker_probe_reaps_descendants(self):
        self.blocked_probe('blocked-inspect',signal.SIGTERM)

    def test_int_during_blocked_simulator_probe_reaps_descendants(self):
        self.blocked_probe('blocked-sim-getenv',signal.SIGINT)

    def test_tty_driver_int_interrupts_foreground_flutter(self):
        self.tty_failure('tty-driver-int')

    def test_persistently_failed_inventory_requires_manual_inspection(self):
        rc,out=self.inventory_run('inventory-persistent')
        self.assertEqual(rc,58,out)
        self.assertIn('ownership remains unknown',out)
        self.assertIn('inspect Compose ps',out)
        self.assertEqual(self.stopped(),[])
        self.assertEqual(json.loads((self.root/'state').read_text()),{'owned-postgres':'running'})
