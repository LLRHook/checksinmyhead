"""Offline contracts for the exact helper/graph called by candidate workflows.

All network transports are injected local functions. Git repos contain only tiny
synthetic text fixtures, never application/source copies. No publication occurs.
"""
import copy
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import yaml
os.environ['GIT_ALLOW_PROTOCOL'] = 'file'  # Synthetic Git transports cannot reach SSH/HTTPS endpoints.
import delivery_gate as gate
from test_ios_artifact import validate_ios_graph

ROOT = Path(__file__).resolve().parents[2]
B = {'source': 'a'*40, 'controller': 'b'*40, 'scope': 'all', 'run': '712', 'attempt': '2'}


def summary(row, b=B):
    return dict(b, row=row, passed=1, failed=0, skipped=0, manifest=gate.manifest_hash(), reports=['d'*64] * len(gate.trusted_manifest()['reports'][row]))


def needs(b=B):
    return {r: {'result': 'success', 'outputs': {'report': gate.compact(summary(r, b))}} for r in gate.ROWS}


class CollectorTests(unittest.TestCase):
    def test_healthy_full_selected_gate(self):
        result = gate.collect(needs(), B)
        self.assertEqual(result['source'], 'a'*40)
        self.assertEqual(set(result['rows']), set(gate.ROWS))

    def test_each_selected_result_must_succeed(self):
        for row in gate.ROWS:
            for state in ('failure', 'skipped', 'cancelled', '', None):
                with self.subTest(row=row, state=state):
                    changed = needs(); changed[row]['result'] = state
                    with self.assertRaises(gate.Rejected): gate.collect(changed, B)

    def test_each_result_and_report_is_mandatory(self):
        for row in gate.ROWS:
            for defect in ('missing-result', 'missing-output', 'malformed', 'zero', 'skipped', 'failed', 'source', 'controller', 'scope', 'run', 'attempt', 'hash'):
                with self.subTest(row=row, defect=defect):
                    changed = needs()
                    if defect == 'missing-result': del changed[row]
                    elif defect == 'missing-output': changed[row]['outputs'] = {}
                    elif defect == 'malformed': changed[row]['outputs']['report'] = '{'
                    else:
                        r = summary(row)
                        if defect == 'zero': r['passed'] = 0
                        elif defect in ('failed', 'skipped'): r[defect] = 1
                        elif defect == 'hash': r['reports'] = []
                        else: r[defect] = 'wrong'
                        changed[row]['outputs']['report'] = gate.compact(r)
                    with self.assertRaises(gate.Rejected): gate.collect(changed, B)

    def test_narrow_context_and_unexpected_rows_rejected(self):
        with self.assertRaises(gate.Rejected):gate.collect(needs(), dict(B, scope='backend'))
        changed=needs();changed['surprise']=changed['web']
        with self.assertRaises(gate.Rejected):gate.collect(changed,B)

    def test_duplicate_json_keys_and_hostile_operator_values(self):
        for value in ('{"version":1,"version":2}', '{', '', 'null\nfalse'):
            with self.subTest(value=value),self.assertRaises(gate.Rejected):gate.parse(value)
        for value in ('main', 'a'*39, 'a'*41, 'A'*40, '$(touch PWNED)', 'a'*40+'\nsource=evil', '--help'):
            with self.subTest(value=value),self.assertRaises(gate.Rejected):gate.sha(value)
        with self.assertRaises(gate.Rejected):gate.binding({'GITHUB_RUN_ID':'1\nx=y','GITHUB_RUN_ATTEMPT':'1'}, 'a'*40,'b'*40)


class GitFixture(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='gate-synthetic-');self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.repo=self.root/'repo';self.repo.mkdir()
        self.env=dict(os.environ,GIT_AUTHOR_NAME='Victor Ivanov',GIT_AUTHOR_EMAIL='victor.n.ivanov@gmail.com',GIT_COMMITTER_NAME='Victor Ivanov',GIT_COMMITTER_EMAIL='victor.n.ivanov@gmail.com',GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=os.devnull,GIT_TERMINAL_PROMPT='0')
        self.call('init','--initial-branch=main')
        (self.repo/'backend/migrations').mkdir(parents=True);(self.repo/'web-bill-viewer').mkdir()
        self.registry=self.repo/'backend/migrations/registry.go'
        self.registry.write_text('const CompatibilityEpoch = 1\n{Version: 1, Name: "one"}\n')
        (self.repo/'web-bill-viewer/index.txt').write_text('synthetic viewer\n')
        self.call('add','.');self.call('commit','-m','synthetic baseline');self.old=self.call('rev-parse','HEAD')
        self.registry.write_text('const CompatibilityEpoch = 1\n{Version: 1, Name: "one"}\n{Version: 2, Name: "two"}\n')
        self.call('add','.');self.call('commit','-m','synthetic source floor');self.source=self.call('rev-parse','HEAD')
        (self.repo/'controller.txt').write_text('synthetic C\n');self.call('add','.');self.call('commit','-m','synthetic controller');self.controller=self.call('rev-parse','HEAD')
        self.call('update-ref','refs/remotes/origin/main',self.controller)
        self.call('tag','-a','backend-v1.2.3',self.source,'-m','synthetic data tag')
        self.b=dict(B,source=self.source,controller=self.controller)
        self.event=dict(self.env,GITHUB_REF='refs/heads/main',GITHUB_EVENT_NAME='workflow_dispatch',GITHUB_REPOSITORY=gate.REPOSITORY,GITHUB_WORKFLOW_REF=gate.WORKFLOW,GITHUB_SHA=self.controller)
        self.policy={'version':1,'enabled_targets':['backend','web'],'control_floor':self.source,'targets':{}}
        target={'source_floor':self.source,'capability_floors':{'synthetic_replay':self.source},'schema_floor':self.source,'schema_epoch':1,'minimum_migration':2,'schema_registry_sha256':gate.digest(self.registry.read_bytes()),'external_clearance':'SYNTHETIC-ONLY-no-live-eligibility'}
        self.policy['targets']={r:copy.deepcopy(target) for r in ('backend','web')}
        self.receipt=gate.collect(needs(self.b),self.b)

    def call(self,*args):
        if args[0] == 'commit':
            for var in ('GIT_AUTHOR_IDENT', 'GIT_COMMITTER_IDENT'):
                identity = subprocess.check_output(['git','-C',str(self.repo),'var',var],env=self.env,text=True)
                self.assertTrue(identity.startswith('Victor Ivanov <victor.n.ivanov@gmail.com> '))
        result = subprocess.check_output(['git','-C',str(self.repo),*args],env=self.env,stderr=subprocess.DEVNULL,text=True).strip()
        if args[0] == 'commit':
            identity = subprocess.check_output(['git','-C',str(self.repo),'log','-1','--format=%an|%ae|%cn|%ce'],env=self.env,text=True).strip()
            self.assertEqual(identity,'Victor Ivanov|victor.n.ivanov@gmail.com|Victor Ivanov|victor.n.ivanov@gmail.com')
        return result


class FloorTests(GitFixture):
    def auth(self,policy=None,event=None,b=None,receipt=None,target='backend'):
        return gate.authorize(self.repo,target,self.receipt if receipt is None else receipt,self.b if b is None else b,self.event if event is None else event,self.policy if policy is None else policy)

    def test_healthy_older_S_and_newer_C_are_distinct(self):
        result=self.auth();self.assertEqual(result['source'],self.source);self.assertEqual(result['controller'],self.controller)
        self.assertNotEqual(self.source,self.controller)
        self.assertEqual(self.call('log','-1','--format=%an <%ae>|%cn <%ce>'),'Victor Ivanov <victor.n.ivanov@gmail.com>|Victor Ivanov <victor.n.ivanov@gmail.com>')

    def test_pr_tag_feature_and_foreign_controller_never_privileged(self):
        for key,values in {'GITHUB_REF':['refs/tags/backend-v1.2.3','refs/heads/feature'], 'GITHUB_EVENT_NAME':['pull_request','pull_request_target'], 'GITHUB_WORKFLOW_REF':['evil/.github/workflows/ci.yml@refs/heads/main'], 'GITHUB_REPOSITORY':['attacker/repo'],'GITHUB_SHA':[self.source]}.items():
            for value in values:
                with self.subTest(key=key,value=value),self.assertRaises(gate.Rejected):self.auth(event=dict(self.event,**{key:value}))

    def test_missing_invalid_and_disabled_policy(self):
        for policy in ({},gate.DISABLED_POLICY,dict(self.policy,enabled_targets=['unrecognized']),dict(self.policy,control_floor=None),dict(self.policy,targets={})):
            with self.subTest(policy=policy),self.assertRaises(gate.Rejected):self.auth(policy=policy)

    def test_old_unknown_capability_source_control_and_schema_floors(self):
        for defect in ('source-old','source-unknown','control-future','capability-unknown','capability-future','capability-missing','schema-unknown','schema-old','schema-epoch','schema-registry','clearance-missing'):
            policy=copy.deepcopy(self.policy);target=policy['targets']['backend'];b=self.b
            if defect=='source-old':b=dict(self.b,source=self.old)
            elif defect=='source-unknown':target['source_floor']='e'*40
            elif defect=='control-future':policy['control_floor']='e'*40
            elif defect=='capability-unknown':target['capability_floors']={'required':'e'*40}
            elif defect=='capability-future':target['capability_floors']={'required':self.controller}
            elif defect=='capability-missing':target['capability_floors']={}
            elif defect=='schema-unknown':target['schema_floor']='e'*40
            elif defect=='schema-old':target['minimum_migration']=3
            elif defect=='schema-epoch':target['schema_epoch']=2
            elif defect=='schema-registry':target['schema_registry_sha256']='a'*64
            else:target['external_clearance']=''
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):self.auth(policy=policy,b=b,receipt=gate.collect(needs(b),b))

    def test_forged_changed_missing_or_wrong_gate_receipts(self):
        for key,value in [('source',self.controller),('controller',self.source),('scope','backend'),('run','99'),('attempt','1'),('status','failure'),('rows',{})]:
            with self.subTest(key=key),self.assertRaises(gate.Rejected):self.auth(receipt=dict(self.receipt,**{key:value}))
        with self.assertRaises(gate.Rejected):self.auth(receipt={})

    def test_stale_automatic_run_rejected_but_current_control_works(self):
        with self.assertRaises(gate.Rejected):self.auth(event=dict(self.event,GITHUB_EVENT_NAME='push'))
        current=dict(self.b,source=self.controller)
        self.assertEqual(self.auth(event=dict(self.event,GITHUB_EVENT_NAME='push'),b=current,receipt=gate.collect(needs(current),current))['main'],self.controller)
        self.call('update-ref','refs/remotes/origin/main',self.source)
        with self.assertRaises(gate.Rejected):self.auth()

    def test_exact_source_tag_and_checkout_resolved_once(self):
        self.assertEqual(gate.resolve(self.repo,self.controller,'backend-v1.2.3','workflow_dispatch','refs/heads/main'),self.source)
        self.assertEqual(gate.resolve(self.repo,self.controller,self.source,'workflow_dispatch','refs/heads/main'),self.source)
        gate.assert_checkout(self.repo,self.controller)
        with self.assertRaises(gate.Rejected):gate.assert_checkout(self.repo,self.source)
        for requested in ('main','feature','$(touch PWNED)','backend-v1.2.3;echo bad','--all'):
            with self.subTest(requested=requested),self.assertRaises(gate.Rejected):gate.resolve(self.repo,self.controller,requested,'workflow_dispatch','refs/heads/main')
        with self.assertRaises(gate.Rejected):gate.resolve(self.repo,self.controller,self.source,'workflow_dispatch','refs/heads/feature')
        with self.assertRaises(gate.Rejected):gate.resolve(self.repo,self.controller,'','push','refs/tags/backend-v1.2.3')
        self.call('update-ref','refs/tags/backend-v1.2.3',self.old)
        with self.assertRaises(gate.Rejected):gate.resolve(self.repo,self.source,'','push','refs/tags/backend-v1.2.3')

    def test_offline_CLI_required_collector_and_emission(self):
        path=self.root/'output';e=dict(self.event,GITHUB_RUN_ID=B['run'],GITHUB_RUN_ATTEMPT=B['attempt'],GITHUB_OUTPUT=str(path),NEEDS=gate.compact({'resolve':{'result':'success','outputs':{'candidate':self.source,'controller':self.controller}},'checks':{'result':'success','outputs':{'receipt':gate.compact(self.receipt)}}}))
        args=[sys.executable,str(Path(gate.__file__)),'required','--repo',str(self.repo),'--source',self.source,'--controller',self.controller]
        good=subprocess.run(args,env=e,capture_output=True,text=True);self.assertEqual(good.returncode,0,good.stderr)
        self.assertIn('source='+self.source,path.read_text());path.unlink()
        n=gate.parse(e['NEEDS']);n['checks']['result']='skipped';e['NEEDS']=gate.compact(n)
        bad=subprocess.run(args,env=e,capture_output=True,text=True);self.assertEqual(bad.returncode,1);self.assertFalse(path.exists())

    def test_phase_F_always_unavailable_even_with_synthetic_receipt(self):
        for target in gate.DISABLED:
            with self.subTest(target=target),self.assertRaises(gate.Rejected):self.auth(target=target)
        p=subprocess.run([sys.executable,str(Path(gate.__file__)),'ios-unavailable'],capture_output=True,text=True)
        self.assertEqual(p.returncode,1);self.assertIn('F-phase required',p.stderr)


class PredecessorTests(GitFixture):
    """The fixture's old revision has registry 1 and S appends 2: publishing S is a schema step."""
    BASE='https://billington-api.onrender.com'

    def health(self,commit):return 200,gate.compact({'status':'bill service - ok','commit':commit}).encode()

    def observe(self,answer,floors=None,source=None,module=gate):
        calls=[]
        def request(method,url):
            calls.append((method,url))
            if isinstance(answer,Exception):raise answer
            return answer
        result=module.predecessor_clear(self.repo,self.source if source is None else source,{'synthetic_replay':self.old} if floors is None else floors,self.BASE,request=request)
        self.assertEqual(calls,[('GET',self.BASE+'/health')])
        return result['predecessor']

    def test_serving_predecessor_must_reach_the_named_reader_floor_before_a_schema_step(self):
        reader=gate.READER_CAPABILITY
        self.assertEqual(self.observe(self.health(self.old),{reader:self.old}),'warm-reader-floor')
        for floors in (None,{},{reader:self.source},{reader:'e'*40},{reader:None},{'other_capability':self.old},[self.old]):
            with self.subTest(floors=floors),self.assertRaises(gate.Rejected) as rejected:self.observe(self.health(self.old),floors)
            self.assertIn('stop it before publishing',str(rejected.exception))
        with self.assertRaises(gate.Rejected):self.observe(self.health(self.old),{reader:'not-a-sha'})

    def test_absent_identical_or_schema_equal_predecessor_needs_no_floor(self):
        for code in (404,502,503):
            with self.subTest(code=code):self.assertEqual(self.observe((code,b'<html>suspended</html>')),'not-serving')
        self.assertEqual(self.observe(self.health(self.source)),'same-revision')
        # C carries the same registry as S; an older S applies no step over a newer serving revision.
        self.assertEqual(self.observe(self.health(self.source),source=self.controller),'no-schema-step')
        self.assertEqual(self.observe(self.health(self.source),source=self.old),'no-schema-step')

    def test_unknown_unrelated_or_unobservable_predecessor_is_rejected(self):
        tree=self.call('rev-parse',self.old+'^{tree}');unrelated=self.call('commit-tree',tree,'-m','synthetic unrelated history')
        reader={gate.READER_CAPABILITY:self.old}
        answers={'transport':gate.Rejected('transport request failed'),'not-json':(200,b'<html>starting</html>'),'no-commit':(200,b'{"status":"bill service - ok"}'),
                 'empty-commit':self.health(''),'short':self.health(self.old[:12]),'uppercase':self.health(self.old.upper()),'number':(200,b'{"commit":1}'),
                 'duplicate':(200,('{"commit":"%s","commit":"%s"}'%(self.source,self.source)).encode()),'array':(200,b'[]'),
                 'unknown-object':self.health('e'*40),'unrelated':self.health(unrelated)}
        # An unhealthy predecessor is still a serving predecessor: its own 5xx health object never reads as stopped.
        unhealthy=lambda code,commit:(code,gate.compact({'status':'service unavailable','commit':commit}).encode())
        answers.update({'unhealthy-unknown':unhealthy(503,'e'*40),'unhealthy-no-commit':(503,b'{"status":"service unavailable"}'),
                        'unhealthy-truncated':(502,b' {"status":'),'unhealthy-unrelated':unhealthy(500,unrelated)})
        for name,answer in answers.items():
            with self.subTest(defect=name),self.assertRaises(gate.Rejected):self.observe(answer,reader)
        for code in (500,502,503):
            with self.subTest(unhealthy=code):
                self.assertEqual(self.observe(unhealthy(code,self.old),reader),'warm-reader-floor')
                with self.assertRaises(gate.Rejected):self.observe(unhealthy(code,self.old),{})
        for base in ('http://billington-api.onrender.com','https://evil.test','https://billington-api.onrender.com/other','https://billington-api.onrender.com?x=1'):
            with self.subTest(base=base),self.assertRaises(gate.Rejected):gate.predecessor_clear(self.repo,self.source,reader,base,request=lambda *_:self.fail('unsafe base was requested'))



class SelectionTests(unittest.TestCase):
    def test_initial_policy_disables_all_publication(self):
        for policy in ('', '{}', '{', gate.compact(gate.DISABLED_POLICY)):
            self.assertEqual(gate.publication_selection('push','refs/heads/main','checks',policy),[])
            with self.assertRaises(gate.Rejected):gate.publication_selection('workflow_dispatch','refs/heads/main','backend',policy)
        enabled=gate.compact({'version':1,'enabled_targets':['backend','web']})
        self.assertEqual(gate.publication_selection('push','refs/heads/main','checks',enabled),['backend','web'])
        for event,ref in [('pull_request','refs/pull/42/merge'),('push','refs/tags/backend-v1.2.3'),('workflow_dispatch','refs/heads/feature')]:
            self.assertEqual(gate.publication_selection(event,ref,'both',enabled),[])


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='gate-reports-');self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
    def report(self,kind,obj,lines=False):
        f=self.root/'report.json';f.write_text('\n'.join(gate.compact(x) for x in obj) if lines else gate.compact(obj));return gate.read_report(kind,f)[1]
    def test_go_report_positive_runner_ID_and_missing_skip_zero_fail(self):
        good=[{'Action':'start','Package':'backend/example'},{'Action':'run','Package':'backend/example','Test':'TestRequired'},{'Action':'pass','Package':'backend/example','Test':'TestRequired'},{'Action':'pass','Package':'backend/example'}]
        cases=self.report('go',good,True);gate.validate_cases(cases,['backend/example/TestRequired'])
        for changed in (good[:2]+[good[-1]], good[:-1], good[:2]+[dict(good[2],Action='skip'),good[-1]], [good[0],good[-1]], [dict(good[-1],Action='fail')]):
            with self.subTest(changed=changed),self.assertRaises(gate.Rejected):gate.validate_cases(self.report('go',changed,True),['backend/example/TestRequired'])
        with self.assertRaises(gate.Rejected):gate.validate_cases(cases,['backend/example/TestMissing'])
    def test_flutter_multiplicity_complete_and_skipped_ids(self):
        events=[{'type':'suite','suite':{'id':0,'path':'/tmp/candidate/mobile/test/family_test.dart'}}]
        for i in (1,2):events += [{'type':'testStart','test':{'id':i,'name':'identical name','suiteID':0}},{'type':'testDone','testID':i,'result':'success','skipped':False,'hidden':False}]
        events += [{'type':'done','success':True}]
        cases=self.report('flutter',events,True);self.assertEqual(len(cases),2);self.assertNotEqual(cases[0]['id'],cases[1]['id']);gate.validate_cases(cases,['mobile/test/family_test.dart'])
        for defect in ('skip','missing-done','missing-id'):
            changed=copy.deepcopy(events)
            if defect=='skip':changed[2]['skipped']=True
            elif defect=='missing-done':changed.pop()
            else:changed[2]['testID']=500
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):gate.validate_cases(self.report('flutter',changed,True),['mobile/test/family_test.dart'])
    def test_vitest_parameter_multiplicity_and_skip_or_missing_family(self):
        suite={'name':'/tmp/candidate/web-bill-viewer/src/family.test.ts','assertionResults':[{'fullName':'same title','status':'passed'},{'fullName':'same title','status':'passed'}]}
        report={'success':True,'numTotalTests':2,'numPassedTests':2,'testResults':[suite]}
        cases=self.report('vitest',report);self.assertEqual(len(cases),2);gate.validate_cases(cases,['web-bill-viewer/src/family.test.ts'])
        report['testResults'][0]['assertionResults'][1]['status']='pending'
        with self.assertRaises(gate.Rejected):gate.validate_cases(self.report('vitest',report),[])
    def test_malformed_zero_duplicate_and_unexpected_case_fields(self):
        for cases in ([],[{'id':'1','family':'required','status':'skip'}],[{'id':'1','family':'required','status':'pass'}]*2,[{'family':'required','status':'pass'}]):
            with self.subTest(cases=cases),self.assertRaises(gate.Rejected):gate.validate_cases(cases,['required'])
        f=self.root/'bad';f.write_text('not JSON\n')
        with self.assertRaises(gate.Rejected):gate.read_report('go',f)


class TransportTests(unittest.TestCase):
    def test_hook_exact_sha_preserves_query_and_rejects_unsafe_hosts(self):
        url=gate.hook_url('https://api.render.com/deploy/synthetic?key=never-a-real-key&flag=&ref=old&extra=value',B['source'])
        self.assertEqual(dict(gate.urllib.parse.parse_qsl(gate.urllib.parse.urlsplit(url).query,keep_blank_values=True)),{'key':'never-a-real-key','flag':'','ref':'a'*40,'extra':'value'})
        for hook in ('','http://api.render.com/deploy/synthetic?key=x','https://evil.test/deploy/synthetic?key=x','https://api.render.com@evil.test/deploy/x','https://api.render.com/deploy/x?key=%0aevil','https://api.render.com/deploy/x?key=x#frag'):
            with self.subTest(hook=hook),self.assertRaises(gate.Rejected):gate.hook_url(hook,B['source'])
    def test_hook_failure_missing_secret_and_strict_health_smoke(self):
        good=json.dumps({'status':'bill service - ok','commit':B['source']}).encode()
        for defect in ('healthy','hook-failure','hook-malformed','hook-missing-secret','health-wrong','health-missing','health-status','health-http','smoke200','smoke401','smoke403'):
            calls=[];ticks=[0]
            def clock():ticks[0]+=450;return ticks[0]
            def request(method,url):
                calls.append((method,url))
                if method=='POST':return (500,b'{}') if defect=='hook-failure' else (200,b'not json') if defect=='hook-malformed' else (202,b'{}')
                if url.endswith('/health'):
                    if defect=='health-wrong':return 200,json.dumps({'status':'bill service - ok','commit':B['controller']}).encode()
                    if defect=='health-missing':return 200,b'{"status":"bill service - ok"}'
                    if defect=='health-status':return 200,json.dumps({'status':'bad','commit':B['source']}).encode()
                    if defect=='health-http':return 503,good
                    return 200,good
                return (int(defect[5:]),b'') if defect.startswith('smoke') else (404,b'')
            args=(B['source'],'' if defect=='hook-missing-secret' else 'https://api.render.com/deploy/synthetic?key=local','https://billington-api.onrender.com')
            with self.subTest(defect=defect):
                if defect=='healthy':self.assertTrue(gate.deploy_backend(*args,request=request,clock=clock,sleep=lambda _:None)['triggered'])
                else:
                    with self.assertRaises(gate.Rejected):gate.deploy_backend(*args,request=request,clock=clock,sleep=lambda _:None)
                    if defect=='hook-missing-secret':self.assertEqual(calls,[])
    def test_verification_only_never_posts_and_hostile_response_not_logged(self):
        calls=[]
        def request(method,url):
            calls.append(method);return (200,json.dumps({'status':'bill service - ok','commit':B['source']}).encode()) if url.endswith('/health') else (404,b'')
        r=gate.deploy_backend(B['source'],'','https://billington-api.onrender.com',True,request=request)
        self.assertFalse(r['triggered']);self.assertEqual(calls,['GET','GET'])
    def test_http_redirect_is_refused(self):
        with self.assertRaises(gate.Rejected):gate.NoRedirect().redirect_request(None,None,302,'',{},'https://evil.test')


class MirrorTests(GitFixture):
    def test_explicit_S_split_and_real_local_remote_lease(self):
        hosts=self.root/'hosts';hosts.write_text(gate.HOST_KEY)
        bare=self.root/'remote.git';subprocess.check_call(['git','init','--bare',str(bare)],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        split=gate.mirror_plan(self.repo,self.source,hosts)
        self.call('push',str(bare),self.old+':refs/heads/main')
        commands=[];keyfiles=[]
        def adapter(repo,*args,env=None):
            args=list(args);commands.append(args)
            if env:
                self.assertIn('StrictHostKeyChecking=yes',env['GIT_SSH_COMMAND'])
                import shlex
                parts=shlex.split(env['GIT_SSH_COMMAND']);keyfile=Path(parts[parts.index('-i')+1]);keyfiles.append(keyfile)
                self.assertEqual(keyfile.stat().st_mode&0o777,0o600);self.assertEqual(keyfile.read_text(),'SYNTHETIC KEY\n')
            if gate.MIRROR in args:args[args.index(gate.MIRROR)]=str(bare)
            return gate.git(repo,*args,env=self.env)
        r=gate.sync_web(self.repo,self.source,'SYNTHETIC KEY\n',hosts,adapter)
        self.assertEqual(r['subtree'],split);self.assertEqual(r['previous_remote'],self.old)
        self.assertTrue(all(not p.exists() for p in keyfiles));self.assertEqual(gate.git(bare,'rev-parse','refs/heads/main'),split)
        self.assertTrue(any('--force-with-lease=refs/heads/main:'+self.old in cmd for cmd in commands));self.assertFalse(any('--force' in cmd for cmd in commands))
        self.call('push','--force',str(bare),self.old+':refs/heads/main')
        self.call('push',str(bare),self.source+':refs/heads/race-seed')
        def race(repo,*args,env=None):
            if args[0]=='push':gate.git(bare,'update-ref','refs/heads/main',self.source)
            return adapter(repo,*args,env=env)
        with self.assertRaises(gate.Rejected):gate.sync_web(self.repo,self.source,'SYNTHETIC KEY\n',hosts,race)
        self.assertEqual(gate.git(bare,'rev-parse','refs/heads/main'),self.source)
        self.assertTrue(all(not p.exists() for p in keyfiles))
    def test_unknown_host_wrong_subtree_and_missing_secret_rejected(self):
        hosts=self.root/'hosts';hosts.write_text('untrusted host\n')
        with self.assertRaises(gate.Rejected):gate.mirror_plan(self.repo,self.source,hosts)
        hosts.write_text(gate.HOST_KEY)
        with self.assertRaises(gate.Rejected):gate.sync_web(self.repo,self.source,'',hosts)
        def wrong(repo,*args,**kwargs):
            if args[0]=='subtree':return self.source
            return 'a'*40 if args[-1].endswith('^{tree}') else 'b'*40
        with self.assertRaises(gate.Rejected):gate.mirror_plan(self.repo,self.source,hosts,wrong)


# The exact commands of each gate row after `set -euo pipefail`. A scan that can be
# dropped, masked with `|| true` or moved behind the report is not a gate (BUG-1793644501).
PYTHON = '"$RUNNER_TEMP/delivery-python/bin/python" control/ops/ci/unittest_report.py control/ops/ci/'
RUBY = 'ruby -r "$GITHUB_WORKSPACE/control/ops/ci/minitest_report.rb" '
GATE_COMMANDS = {row: ['set -euo pipefail'] + lines for row, lines in {
    'automation': [
        "python3 -c 'import sys; assert sys.version_info[:2] == (3,12)'",
        'python3 -m venv "$RUNNER_TEMP/delivery-python"',
        '"$RUNNER_TEMP/delivery-python/bin/pip" install --require-hashes --only-binary=:all: -r control/ops/ci/requirements-ci.txt',
        'CASE_REPORT="$REPORT_DIR/gate-tests.json" ' + PYTHON + 'test_delivery_gate.py',
        'CASE_REPORT="$REPORT_DIR/ruby.json" ' + RUBY + 'candidate/.github/scripts/asc_release_test.rb',
        'for script in candidate/.github/scripts/*.rb control/ops/ci/*.rb; do ruby -c "$script"; done',
        'CASE_REPORT="$REPORT_DIR/ios-python.json" ' + PYTHON + 'test_ios_artifact.py',
        'CASE_REPORT="$REPORT_DIR/ios-ruby.json" ' + RUBY + 'control/.github/scripts/asc_delivery_test.rb'],
    'local-workflow': [
        '/bin/bash -n candidate/dev.sh',
        'CASE_REPORT="$REPORT_DIR/local-workflow.json" python3 control/ops/ci/unittest_report.py candidate/scripts/test_local_workflow.py'],
    'backend': [
        'cd candidate/backend',
        'test -z "$(gofmt -l .)" || { gofmt -l .; echo "::error::Run \'gofmt -w .\' in backend/"; exit 1; }',
        'go mod download',
        'go mod verify',
        'go build ./...',
        'go vet ./...',
        'go test -race -count=1 -json ./... | tee "$REPORT_DIR/go-default.jsonl"',
        'go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...'],
    'postgres': [
        'cd candidate/backend',
        'go mod download',
        'go mod verify',
        'go build ./cmd/bill-service',
        'go test -race -count=1 -json -timeout=20m -tags=integration ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres | tee "$REPORT_DIR/go-postgres.jsonl"'],
    'mobile': [
        'cd candidate/mobile',
        'flutter pub get --enforce-lockfile',
        'flutter analyze',
        'flutter test --no-pub --reporter=json | tee "$REPORT_DIR/flutter.jsonl"'],
    'web': [
        'cd candidate/web-bill-viewer',
        'npm ci',
        'npm run lint',
        'npm test -- --reporter=json --outputFile="$REPORT_DIR/vitest.json"',
        'npm run build',
        'npm audit --audit-level=moderate'],
}.items()}


# Structural validation targets the actual proposed graph; mutation controls prove
# a removed needs edge/changed checkout/skip bypass is rejected by the same checker.
def validate_graph(root):
    workflows={p.name:yaml.safe_load(p.read_text()) for p in (root/'.github/workflows').glob('*.yml')}
    def require(ok,msg):gate.require(ok,msg)
    checks=workflows['checks.yml'];ci=workflows['ci.yml']
    require(set(checks['on'])=={'workflow_call'} and not checks['on']['workflow_call'].get('secrets'),'checks secret contract')
    require(checks['permissions']=={'contents':'read'},'check permission escalation')
    require(set(checks['jobs'])==set(gate.ROWS)|{'aggregate'},'canonical check rows changed')
    require(checks['jobs']['aggregate']['if']=='always()' and set(checks['jobs']['aggregate']['needs'])==set(gate.ROWS),'aggregate edges missing')
    require(ci['jobs']['required']['name']=='Required delivery checks' and ci['jobs']['required']['if']=='always()' and set(ci['jobs']['required']['needs'])=={'resolve','checks'},'required full gate edges missing')
    require(set(ci['on']['push'])=={'branches','tags'} and ci['on']['pull_request'] is None,'path filtered full gate')
    for filename,w in workflows.items():
        require(w['permissions']=={'contents':'read'},'default permission mismatch')
        require('pull_request_target' not in w['on'],'privileged PR event')
        for name,job in w['jobs'].items():
            require(not job.get('continue-on-error'),'continue-on-error')
            if 'uses' in job:
                publisher_secrets = {
                    ('ci.yml', 'publish-backend'): {'DELIVERY_RENDER_DEPLOY_HOOK_URL': '${{ secrets.DELIVERY_RENDER_DEPLOY_HOOK_URL }}'},
                    ('ci.yml', 'publish-web'): {'DELIVERY_VERCEL_DEPLOY_KEY': '${{ secrets.DELIVERY_VERCEL_DEPLOY_KEY }}'},
                }
                if filename in ('testflight.yml','app-store-release.yml','update-release-notes.yml') and name == 'deliver':
                    names = ['DELIVERY_ASC_KEY_ID','DELIVERY_ASC_ISSUER_ID','DELIVERY_ASC_API_KEY_P8']
                    if filename == 'testflight.yml': names += ['DELIVERY_BUILD_CERTIFICATE_BASE64','DELIVERY_P12_PASSWORD','DELIVERY_PROVISIONING_PROFILE_BASE64']
                    require(job.get('secrets') == {k:'${{ secrets.'+k+' }}' for k in names}, 'named iOS secret forwarding')
                elif (filename, name) in publisher_secrets:
                    require(job.get('secrets') == publisher_secrets[(filename, name)], 'named publisher secret forwarding')
                else:
                    require('secrets' not in job, 'secret passed to nonpublisher reusable job')
                if job['uses'].endswith('checks.yml'):require(job['with']['scope']=='all','narrow full gate')
                continue
            require(type(job.get('timeout-minutes')) is int and job['timeout-minutes']>0,'missing timeout')
            for step in job.get('steps',[]):
                require(not step.get('continue-on-error'),'step continue-on-error')
                if 'uses' in step:
                    require(step['uses'] == './control/.github/actions/build-signed-ipa' or re.fullmatch('[^@]+@[0-9a-f]{40}',step['uses']) is not None,'mutable action')
                    if step['uses'].startswith('actions/checkout@'):
                        values=step['with'];require(values['persist-credentials'] is False,'persisted token')
                        if values['path']=='candidate':require(values['ref']==('${{ inputs.source_sha }}' if filename=='checks.yml' else '${{ inputs.source }}'),'candidate checkout wrong S')
                        elif filename=='checks.yml':require(values['ref']=='${{ inputs.controller_sha }}','trusted helper checkout wrong C')
                        else:require(values['ref'] in ('${{ github.sha }}','${{ inputs.controller }}'),'privileged control from candidate')
                    if step['uses'].startswith('subosito/flutter-action@'):
                        require(step['with']['cache']=='false' and step['with']['pub-cache']=='false','mutable nested cache enabled')
                if 'run' in step:
                    require('${{' not in step['run'],'unsafe shell interpolation')
                    require('skip_tests' not in step['run'],'test bypass')
                    require('secrets: inherit' not in step['run'],'secret inheritance')
            if filename=='checks.yml' and name in gate.ROWS:
                require('if' not in job,'required row skipped')
                runtext='\n'.join(s.get('run','') for s in job['steps'])
                require('assert-checkout --repo candidate --source "$SOURCE"' in runtext and ' summarize' in runtext,'missing source/report helper invocation')
    mobile_command = next(s['run'] for s in checks['jobs']['mobile']['steps'] if s.get('name') == 'Canonical mobile row')
    acquire = 'flutter pub get --enforce-lockfile\n'
    report = 'flutter test --no-pub --reporter=json | tee "$REPORT_DIR/flutter.jsonl"'
    require(acquire in mobile_command and report in mobile_command and mobile_command.index(acquire) < mobile_command.index(report), 'locked acquisition before clean Flutter JSON report')
    pg=checks['jobs']['postgres'];body='\n'.join(s.get('run','') for s in pg['steps'])
    wanted='go test -race -count=1 -json -timeout=20m -tags=integration ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres'
    require(wanted in body,'eight-package PG row changed')
    service=pg['services']['postgres'];require(service['ports']==['127.0.0.1:5432:5432'] and '@sha256:' in service['image'],'PG service identity/loopback')
    require('host=127.0.0.1 ' in pg['env']['BILLINGTON_TEST_POSTGRES_DSN'] and 'dbname=billington_test' in pg['env']['BILLINGTON_TEST_POSTGRES_DSN'],'unsafe PG DSN')
    for target,filename,environment,secret in [('backend','deploy-backend.yml','backend-production','DELIVERY_RENDER_DEPLOY_HOOK_URL'),('web','sync-web-viewer.yml','web-production','DELIVERY_VERCEL_DEPLOY_KEY')]:
        publisher=workflows[filename];require(set(publisher['on'])=={'workflow_call'},'independent push/manual bypass')
        require(publisher['on']['workflow_call'].get('secrets') == {secret: {'required': True}}, 'required named publisher secret declaration')
        job=publisher['jobs']['publish'];require(job['environment']==environment and "github.ref == 'refs/heads/main'" in job['if'],'publisher main environment')
        require(job['concurrency']=={'group':environment,'cancel-in-progress':False},'cancelling publisher')
        step=job['steps'][-1];require(' publish' in step['run'] and step.get('env',{}).get('GATE_RECEIPT')=='${{ inputs.receipt }}' and step['env'][secret]=='${{ secrets.'+secret+' }}','publisher contract invocation')
        caller=ci['jobs']['publish-'+target];require(set(caller['needs'])=={'resolve','required'} and caller['with']['receipt']=='${{ needs.required.outputs.receipt }}' and caller['with']['source']=='${{ needs.required.outputs.source }}' and "needs.required.result == 'success'" in caller['if'],'publisher missing gate edge')
    for name in ('testflight.yml','app-store-release.yml','update-release-notes.yml'):
        w=workflows[name];require(w['jobs']['checks']['uses']=='./.github/workflows/checks.yml','iOS missing common gate')
        text=(root/'.github/workflows'/name).read_text();require('skip_tests' not in text and set(w['jobs']['deliver']['needs'])=={'resolve','required'},'phase-F alternate path')
    action=yaml.safe_load((root/'.github/actions/build-signed-ipa/action.yml').read_text())
    require(len(action['runs']['steps'])==1 and action['runs']['steps'][0]['run']=='python3 control/ops/ci/ios_sign.py','signed action bypass')
    expected_workflows = {'ci.yml','checks.yml','deploy-backend.yml','sync-web-viewer.yml','testflight.yml','app-store-release.yml','update-release-notes.yml','ios-origin.yml','ios-promote.yml'}
    require(set(workflows) == expected_workflows, 'alternate workflow owner')
    helper = 'python3 control/ops/ci/delivery_gate.py'
    args = ' --repo control --controller "$CONTROLLER" --source "$SOURCE"'
    require(checks['env'] == {'CONTROLLER':'${{ inputs.controller_sha }}','SOURCE':'${{ inputs.source_sha }}','CHECK_SCOPE':'${{ inputs.scope }}','REPORT_DIR':'${{ github.workspace }}/reports'}, 'C/S/scope dataflow')
    require(checks['on']['workflow_call']['inputs'] == {k:{'required':True,'type':'string'} for k in ('source_sha','controller_sha','scope')}, 'checks input contract')
    for key in ('receipt','source','controller'):
        require(checks['on']['workflow_call']['outputs'][key]['value'] == '${{ jobs.aggregate.outputs.'+key+' }}', 'reusable output bypass')
        require(checks['jobs']['aggregate']['outputs'][key] == '${{ steps.gate.outputs.'+key+' }}', 'aggregate output bypass')
        require(ci['jobs']['required']['outputs'][key] == '${{ steps.required.outputs.'+key+' }}', 'outer output bypass')
    collect_step = checks['jobs']['aggregate']['steps'][-1]
    require(collect_step['id']=='gate' and collect_step['run']==helper+' collect'+args and collect_step['env']=={'NEEDS':'${{ toJSON(needs) }}'}, 'collector helper/dataflow replaced')
    required_step = ci['jobs']['required']['steps'][-1]
    require(required_step['run']==helper+' required'+args and required_step['env']=={'CONTROLLER':'${{ github.sha }}','SOURCE':'${{ needs.resolve.outputs.candidate }}','NEEDS':'${{ toJSON(needs) }}'}, 'outer required helper/dataflow replaced')
    manifest = gate.trusted_manifest()
    require(checks['defaults']=={'run':{'shell':'bash'}}, 'gate shell changed')
    pins = {'actions/checkout':'fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09',
            'actions/setup-go':'924ae3a1cded613372ab5595356fb5720e22ba16',
            'actions/setup-node':'a0853c24544627f65ddf259abe73b1d18a591444',
            'subosito/flutter-action':'1a449444c387b1966244ae4d4f8c696479add0b2',
            'actions/upload-artifact':'cf430e030ddbb5b0abf93d22962f4752f3646cd9'}
    for row in gate.ROWS:
        job=checks['jobs'][row]
        require(job['outputs']=={'report':'${{ steps.report.outputs.report }}'}, 'row output bypass')
        reports=[step for step in job['steps'] if step.get('id')=='report']
        expected=' '.join(kind+':reports/'+name for kind,name in manifest['reports'][row])
        require(len(reports)==1 and reports[0]['run']==helper+' summarize'+args+' --row '+row+' --reports '+expected, 'actual report adapter selection changed')
        require(not reports[0].get('if'), 'skipped report validation')
        command=next(step['run'] for step in job['steps'] if step.get('name')=='Canonical '+row+' row')
        require(command.startswith('set -euo pipefail\n'), 'runner failure exit swallowed')
        # Every build, test and scan line is part of the gate: a failed scan fails the
        # row only while its exact command, order, shell and step list stay in place.
        canonical=[step for step in job['steps'] if step.get('name')=='Canonical '+row+' row']
        require(len(canonical)==1 and set(canonical[0])=={'name','run'} and command.split('\n')==GATE_COMMANDS[row], 'gate command removed, weakened, masked, reordered or skipped: '+row)
        require([step['run'] for step in job['steps'] if 'run' in step]==[helper+' assert-checkout --repo control --source "$CONTROLLER"', helper+' assert-checkout --repo candidate --source "$SOURCE"', 'mkdir -p reports', command, reports[0]['run']], 'unreviewed command in gate row: '+row)
        require(set(job)=={'name','runs-on','timeout-minutes','outputs','steps'}|({'services','env'} if row=='postgres' else set()), 'unreviewed gate row setting: '+row)
        require(job['steps'][2]['run']==helper+' assert-checkout --repo control --source "$CONTROLLER"' and
                job['steps'][3]['run']==helper+' assert-checkout --repo candidate --source "$SOURCE"', 'checkout assertion replaced')
        require(job['steps'].index(reports[0]) > next(i for i,step in enumerate(job['steps']) if step.get('name')=='Canonical '+row+' row'), 'report precedes execution')
        require('secrets.' not in gate.compact(job), 'secret passed to candidate validation')
    for filename,w in workflows.items():
        for name,job in w['jobs'].items():
            for step in job.get('steps',[]):
                if 'uses' in step:
                    if step['uses'] == './control/.github/actions/build-signed-ipa': continue
                    owner,ref=step['uses'].split('@')
                    require(pins.get(owner)==ref,'unverified action pin')
            if 'resolve' == name:
                require(job['steps'][-1]['run']==helper+' resolve --repo control --controller "$CONTROLLER"', 'source resolver replaced')
                require(job['steps'][-1]['env']=={'CONTROLLER':'${{ github.sha }}','REQUESTED_SOURCE':"${{ inputs.source || '' }}",'REQUESTED_TARGET':"${{ inputs.target || 'checks' }}",'RELEASE_POLICY':'${{ vars.RELEASE_POLICY }}','BEFORE_SOURCE':"${{ github.event.before || '' }}"}, 'source/policy resolver override')
            if job.get('uses')=='./.github/workflows/checks.yml':
                require(job['needs']=='resolve' and job['with']=={'source_sha':'${{ needs.resolve.outputs.candidate }}','controller_sha':'${{ needs.resolve.outputs.controller }}','scope':'all'}, 'common gate C/S or scope override')
    for target,filename,secret in [('backend','deploy-backend.yml','DELIVERY_RENDER_DEPLOY_HOOK_URL'),('web','sync-web-viewer.yml','DELIVERY_VERCEL_DEPLOY_KEY')]:
        w=workflows[filename];j=w['jobs']['publish'];step=j['steps'][-1]
        require(set(w['jobs'])=={'publish'},'alternate mutation job')
        require(step['run']==helper+' publish'+args,'trusted publisher helper replaced')
        expected={'CONTROLLER':'${{ inputs.controller }}','SOURCE':'${{ inputs.source }}','GATE_RECEIPT':'${{ inputs.receipt }}','RELEASE_POLICY':'${{ vars.RELEASE_POLICY }}','DELIVERY_TARGET':target,secret:'${{ secrets.'+secret+' }}'}
        if target=='backend':expected['VERIFY_ONLY']='${{ inputs.skip_deploy }}'
        require(step['env']==expected,'publisher policy/secret/source override')
        require(ci['jobs']['publish-'+target]['uses']=='./.github/workflows/'+filename and ci['jobs']['publish-'+target]['with']['controller']=='${{ needs.required.outputs.controller }}', 'publisher workflow/controller replaced')
        expected_if="${{ github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch') && needs.required.result == 'success' && needs.resolve.outputs."+target+" == 'true' }}"
        require(' '.join(ci['jobs']['publish-'+target]['if'].split()) == expected_if, 'publication result/ref condition weakened')
    for filename in ('testflight.yml','app-store-release.yml','update-release-notes.yml'):
        w=workflows[filename];require(set(w['jobs'])=={'resolve','checks','required','deliver'},'alternate iOS mutation job')
        require(w['jobs']['required']==ci['jobs']['required'],'iOS required collector differs')
        require(set(w['jobs']['deliver']['needs'])=={'resolve','required'},'iOS common gate missing')
    cancel=workflows['update-release-notes.yml']['on']['workflow_dispatch']['inputs']['allow_cancel']
    require(cancel['type']=='boolean' and cancel['default'] is False,'cancellation consent changed')
    validate_ios_graph(root,workflows)
    validate_workflow_syntax(workflows)
    validate_execution_settings(workflows)
    return workflows


# BUG-1793644519. Entry workflows own one group per ref and event. Only pull-request
# validation is cancelled in progress: any other cancellation could stop a publisher
# mid-mutation. Reusable workflows declare no top-level group (it would be evaluated
# in the caller's context and can collide with the caller's own); their mutation jobs
# serialize on a literal noncancelling job group instead.
ENTRY_CONCURRENCY = {
    'ci.yml': {'group': 'controller-${{ github.ref }}-${{ github.event_name }}', 'cancel-in-progress': "${{ github.event_name == 'pull_request' }}"},
    'testflight.yml': {'group': 'testflight-${{ github.ref }}-${{ github.event_name }}', 'cancel-in-progress': False},
    'app-store-release.yml': {'group': 'app-store-release-${{ github.ref }}-${{ github.event_name }}', 'cancel-in-progress': False},
    'update-release-notes.yml': {'group': 'release-notes-${{ github.ref }}-${{ github.event_name }}', 'cancel-in-progress': False},
}
MUTATION_GROUPS = {'backend-production': 'backend-production', 'web-production': 'web-production', 'ios-upload': 'ios-upload', 'ios-production': 'ios-upload'}
READ_EVIDENCE_JOBS = {('testflight.yml', 'deliver'), ('app-store-release.yml', 'deliver'), ('update-release-notes.yml', 'deliver'), ('ios-origin.yml', 'origin'), ('ios-promote.yml', 'promote')}
LONGEST_JOB_MINUTES = 60


def validate_execution_settings(workflows):
    require = gate.require
    for filename, workflow in workflows.items():
        events = workflow.get('on', workflow.get(True))
        require(isinstance(events, dict) and bool(events), 'unenumerated workflow triggers in ' + filename)
        reusable = set(events) == {'workflow_call'}
        if reusable:
            require('concurrency' not in workflow, 'top-level group in reusable workflow ' + filename)
        else:
            require('pull_request' not in events or filename == 'ci.yml', 'unreviewed pull-request workflow ' + filename)
            require(workflow.get('concurrency') == ENTRY_CONCURRENCY.get(filename), 'entry workflow group missing, shared or cancelling: ' + filename)
        for name, job in workflow['jobs'].items():
            where = filename + ':' + name
            if 'permissions' in job:
                require((filename, name) in READ_EVIDENCE_JOBS and job['permissions'] == {'contents': 'read', 'actions': 'read'}, 'unreviewed job token at ' + where)
            if 'environment' in job:
                group = MUTATION_GROUPS.get(job['environment']) if isinstance(job['environment'], str) else None
                require(reusable and group is not None and job.get('concurrency') == {'group': group, 'cancel-in-progress': False}, 'mutation job unserialized or cancelling at ' + where)
            else:
                require('concurrency' not in job, 'unreviewed job group at ' + where)
            if 'uses' not in job:
                require(type(job.get('timeout-minutes')) is int and job['timeout-minutes'] <= LONGEST_JOB_MINUTES, 'missing or unbounded timeout at ' + where)


# GitHub rejects a whole workflow file ("workflow file issue", a failed run with no
# jobs on every push) when an expression names a context its key does not provide.
# This is GitHub's documented table: Actions contexts reference, "Context
# availability". First matching key prefix wins; '*' is one job/step/service/input ID.
_JOB = 'github needs strategy matrix vars inputs'
_STEP = _JOB + ' job runner env secrets steps'
_STATUS = 'always cancelled success failure'
CONTEXT_AVAILABILITY = [(tuple(key.split('.')), frozenset(contexts.split()), frozenset(special.lower().split())) for key, contexts, special in [
    ('run-name', 'github inputs vars', ''),
    ('concurrency', 'github inputs vars', ''),
    ('env', 'github secrets inputs vars', ''),
    ('on.workflow_call.inputs.*.default', 'github inputs vars', ''),
    ('on.workflow_call.outputs.*.value', 'github jobs vars inputs', ''),
    ('jobs.*.concurrency', _JOB, ''),
    ('jobs.*.container.credentials', _JOB + ' env secrets', ''),
    ('jobs.*.container.env', _JOB + ' job runner env secrets', ''),
    ('jobs.*.container', _JOB, ''),
    ('jobs.*.continue-on-error', _JOB, ''),
    ('jobs.*.defaults.run', _JOB + ' env', ''),
    ('jobs.*.env', _JOB + ' secrets', ''),
    ('jobs.*.environment.url', _JOB + ' job runner env steps', ''),
    ('jobs.*.environment', _JOB, ''),
    ('jobs.*.if', 'github needs vars inputs', _STATUS),
    ('jobs.*.name', _JOB, ''),
    ('jobs.*.outputs', _STEP, ''),
    ('jobs.*.runs-on', _JOB, ''),
    ('jobs.*.secrets', _JOB + ' secrets', ''),
    ('jobs.*.services.*.credentials', _JOB + ' env secrets', ''),
    ('jobs.*.services.*.env', _JOB + ' job runner env secrets', ''),
    ('jobs.*.services', _JOB, ''),
    ('jobs.*.steps.*.if', _JOB + ' job runner env steps', _STATUS + ' hashFiles'),
    ('jobs.*.steps.*.continue-on-error', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.env', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.name', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.run', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.timeout-minutes', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.with', _STEP, 'hashFiles'),
    ('jobs.*.steps.*.working-directory', _STEP, 'hashFiles'),
    ('jobs.*.strategy', 'github needs vars inputs', ''),
    ('jobs.*.timeout-minutes', _JOB, ''),
    ('jobs.*.with', _JOB, ''),
]]
EXPRESSION_FUNCTIONS = frozenset('contains startswith endswith format join tojson fromjson'.split())
EXPRESSION_LITERALS = frozenset('true false null nan infinity'.split())
REUSABLE_CALL_KEYS = frozenset('name uses with secrets needs if permissions strategy concurrency'.split())
TOKEN_LEVELS = {'none': 0, 'read': 1, 'write': 2}


def expression_names(text):
    """Named values and function calls of one expression body, string literals removed."""
    bare = re.sub(r"'(?:[^']|'')*'", ' ', text)
    found = [(m.group(1).lower(), bool(m.group(2))) for m in re.finditer(r'(?<![\w.-])([A-Za-z_][\w-]*)(\s*\()?', bare)]
    return [(name, call) for name, call in found if call or name not in EXPRESSION_LITERALS]


def validate_workflow_syntax(workflows):
    """Reject expressions and reusable calls that GitHub refuses when it loads the file."""
    require = gate.require
    def walk(node, path):
        if isinstance(node, dict):
            for key, value in node.items():
                yield from walk(value, path + ('on' if key is True else str(key),))
        elif isinstance(node, list):
            for index, value in enumerate(node):
                yield from walk(value, path + (str(index),))
        elif isinstance(node, str):
            yield path, node
    for filename, workflow in workflows.items():
        for path, text in walk(workflow, ()):
            bodies = re.findall(r'\$\{\{(.*?)\}\}', text, re.S)
            where = filename + ':' + '.'.join(path)
            require(text.count('${{') == len(bodies), 'unterminated expression at ' + where)
            if not bodies and path[-1] == 'if' and len(path) in (3, 5):
                bodies = [text]  # `if` is always an expression, with or without ${{ }}.
            if not bodies:
                continue
            rule = next((r for r in CONTEXT_AVAILABILITY if len(path) >= len(r[0]) and all(want in ('*', got) for want, got in zip(r[0], path))), None)
            require(rule is not None, 'expression outside a documented workflow key at ' + where)
            for body in bodies:
                for name, call in expression_names(body):
                    if call:
                        require(name in EXPRESSION_FUNCTIONS or name in rule[2], 'function ' + name + ' unavailable at ' + where)
                    else:
                        require(name in rule[1], "Unrecognized named-value: '" + name + "' at " + where)
        # Reusable workflows: declared typed inputs, and callers that satisfy the contract.
        def triggers(w):
            events = w.get('on', w.get(True))
            require(isinstance(events, dict), 'unenumerated workflow triggers in ' + filename)
            return events
        def token(owner, fallback):
            scopes = owner.get('permissions', fallback)
            require(isinstance(scopes, dict), 'unenumerated token permissions in ' + filename)
            return scopes
        for name, spec in ((triggers(workflow).get('workflow_call') or {}).get('inputs') or {}).items():
            require(spec.get('type') in ('string', 'number', 'boolean'), 'untyped reusable input ' + filename + ':' + name)
        for jobname, job in workflow['jobs'].items():
            if 'uses' not in job:
                continue
            where = filename + ':' + jobname
            require(set(job) <= REUSABLE_CALL_KEYS, 'unsupported reusable-call key at ' + where)
            require(job['uses'].startswith('./.github/workflows/') and job['uses'].split('/')[-1] in workflows, 'unknown reusable workflow at ' + where)
            callee = workflows[job['uses'].split('/')[-1]]
            require('workflow_call' in triggers(callee), 'callee is not reusable at ' + where)
            contract = triggers(callee)['workflow_call'] or {}
            for kind in ('inputs', 'secrets'):
                declared = contract.get(kind) or {}
                supplied = job.get('with' if kind == 'inputs' else kind) or {}
                require(isinstance(supplied, dict) and set(supplied) <= set(declared), 'undeclared reusable ' + kind + ' at ' + where)
                missing = [k for k, spec in declared.items() if (spec or {}).get('required') and 'default' not in (spec or {}) and k not in supplied]
                require(not missing, 'missing required reusable ' + kind + ' at ' + where)
            # A called workflow cannot raise GITHUB_TOKEN permissions above its caller job.
            granted = token(job, token(workflow, {}))
            for called in callee['jobs'].values():
                for scope, level in token(called, token(callee, {})).items():
                    require(TOKEN_LEVELS[level] <= TOKEN_LEVELS[granted.get(scope, 'none')], 'called workflow exceeds caller token at ' + where)


class GraphTests(unittest.TestCase):
    def test_execution_settings_are_pinned_bounded_serialized_and_read_only(self):
        actual = {p.name: yaml.safe_load(p.read_text()) for p in (ROOT/'.github/workflows').glob('*.yml')}
        validate_execution_settings(actual)
        self.assertEqual(set(ENTRY_CONCURRENCY) | {n for n, w in actual.items() if set(w['on']) == {'workflow_call'}}, set(actual))
        groups = [c['group'] for c in ENTRY_CONCURRENCY.values()]
        self.assertEqual(len(set(groups)), len(groups))
        self.assertFalse({g.split('-${{')[0] for g in groups} & set(MUTATION_GROUPS.values()))
        defects = {
            'ci-cancels-main-publisher': ('ci.yml', lambda w: w['concurrency'].update({'cancel-in-progress': True})),
            'ci-cancels-all-events': ('ci.yml', lambda w: w['concurrency'].update({'cancel-in-progress': "${{ github.event_name != 'workflow_dispatch' }}"})),
            'ci-no-group': ('ci.yml', lambda w: w.pop('concurrency')),
            'ci-one-group-for-every-ref': ('ci.yml', lambda w: w['concurrency'].update(group='controller')),
            'testflight-no-group': ('testflight.yml', lambda w: w.pop('concurrency')),
            'app-store-no-group': ('app-store-release.yml', lambda w: w.pop('concurrency')),
            'notes-no-group': ('update-release-notes.yml', lambda w: w.pop('concurrency')),
            'testflight-cancels-upload': ('testflight.yml', lambda w: w['concurrency'].update({'cancel-in-progress': True})),
            'entry-shares-mutation-group': ('app-store-release.yml', lambda w: w['concurrency'].update(group='ios-upload')),
            'entries-share-one-group': ('update-release-notes.yml', lambda w: w['concurrency'].update(group=ENTRY_CONCURRENCY['testflight.yml']['group'])),
            'reusable-top-level-group': ('checks.yml', lambda w: w.update(concurrency={'group': 'checks-${{ github.ref }}', 'cancel-in-progress': True})),
            'publisher-top-level-group': ('deploy-backend.yml', lambda w: w.update(concurrency={'group': 'backend-production', 'cancel-in-progress': False})),
            'backend-publisher-cancels': ('deploy-backend.yml', lambda w: w['jobs']['publish']['concurrency'].update({'cancel-in-progress': True})),
            'web-publisher-unserialized': ('sync-web-viewer.yml', lambda w: w['jobs']['publish'].pop('concurrency')),
            'web-publisher-dynamic-group': ('sync-web-viewer.yml', lambda w: w['jobs']['publish']['concurrency'].update(group='web-production-${{ github.run_id }}')),
            'origin-own-group': ('ios-origin.yml', lambda w: w['jobs']['origin']['concurrency'].update(group='ios-origin')),
            'promotion-cancels': ('ios-promote.yml', lambda w: w['jobs']['promote']['concurrency'].update({'cancel-in-progress': True})),
            'validation-row-group': ('checks.yml', lambda w: w['jobs']['web'].update(concurrency={'group': 'web', 'cancel-in-progress': True})),
            'entry-job-environment': ('ci.yml', lambda w: w['jobs']['required'].update(environment='backend-production', concurrency={'group': 'backend-production', 'cancel-in-progress': False})),
            'job-token-write': ('ci.yml', lambda w: w['jobs']['required'].update(permissions={'contents': 'write'})),
            'resolver-token-write': ('ci.yml', lambda w: w['jobs']['resolve'].update(permissions={'contents': 'write', 'actions': 'write'})),
            'publisher-token-write': ('sync-web-viewer.yml', lambda w: w['jobs']['publish'].update(permissions={'contents': 'read', 'deployments': 'write'})),
            'job-token-oidc': ('deploy-backend.yml', lambda w: w['jobs']['publish'].update(permissions={'contents': 'read', 'id-token': 'write'})),
            'job-token-extra-read': ('checks.yml', lambda w: w['jobs']['aggregate'].update(permissions={'contents': 'read', 'actions': 'read'})),
            'evidence-job-token-write': ('ios-promote.yml', lambda w: w['jobs']['promote']['permissions'].update(actions='write')),
            'timeout-platform-default': ('ios-origin.yml', lambda w: w['jobs']['origin'].update({'timeout-minutes': 360})),
        }
        for defect, (filename, mutate) in defects.items():
            changed = copy.deepcopy(actual)
            mutate(changed[filename])
            with self.subTest(defect=defect), self.assertRaises(gate.Rejected):
                validate_execution_settings(changed)

    def test_workflow_expressions_use_only_documented_contexts(self):
        actual = {p.name: yaml.safe_load(p.read_text()) for p in (ROOT/'.github/workflows').glob('*.yml')}
        validate_workflow_syntax(actual)
        self.assertEqual(expression_names("needs.a.result == 'runner.temp' && !inputs.x || fromJSON(env.Y)['secrets']"),
                         [('needs', False), ('inputs', False), ('fromjson', True), ('env', False)])
        # BUG-1794258285: GitHub refused ios-origin.yml on every push for exactly this.
        defects = {
            'job-env-runner': ('ios-origin.yml', lambda w: w['jobs']['origin']['env'].update(IPA_DIR='${{ runner.temp }}/ios-ipa')),
            'job-env-steps': ('ios-origin.yml', lambda w: w['jobs']['origin']['env'].update(BUILD='${{ steps.prepare.outputs.build }}')),
            'job-if-env': ('ios-origin.yml', lambda w: w['jobs']['origin'].update({'if': "${{ env.DELIVERY_TARGET == 'ios-upload' }}"})),
            'job-if-bare-secrets': ('ios-promote.yml', lambda w: w['jobs']['promote'].update({'if': "secrets.DELIVERY_ASC_KEY_ID != ''"})),
            'job-runs-on-runner': ('checks.yml', lambda w: w['jobs']['backend'].update({'runs-on': '${{ runner.os }}'})),
            'job-concurrency-secrets': ('deploy-backend.yml', lambda w: w['jobs']['publish']['concurrency'].update(group='${{ secrets.DELIVERY_RENDER_DEPLOY_HOOK_URL }}')),
            'job-timeout-env': ('checks.yml', lambda w: w['jobs']['web'].update({'timeout-minutes': '${{ env.LIMIT }}'})),
            'job-env-hashfiles': ('checks.yml', lambda w: w['jobs']['web'].update(env={'LOCK': "${{ hashFiles('**/package-lock.json') }}"})),
            'workflow-env-needs': ('checks.yml', lambda w: w['env'].update(RESULT='${{ needs.backend.result }}')),
            'workflow-concurrency-needs': ('ci.yml', lambda w: w.update(concurrency={'group': '${{ needs.resolve.outputs.candidate }}'})),
            'reusable-default-secrets': ('ios-origin.yml', lambda w: w['on']['workflow_call']['inputs']['release_notes'].update(default='${{ secrets.NOTES }}')),
            'reusable-with-secrets': ('testflight.yml', lambda w: w['jobs']['deliver']['with'].update(release_notes='${{ secrets.NOTES }}')),
            'reusable-with-runner': ('ci.yml', lambda w: w['jobs']['checks']['with'].update(scope='${{ runner.os }}')),
            'step-if-secrets': ('ios-origin.yml', lambda w: w['jobs']['origin']['steps'][3].update({'if': "${{ secrets.DELIVERY_P12_PASSWORD != '' }}"})),
            'step-uses-expression': ('ios-origin.yml', lambda w: w['jobs']['origin']['steps'][0].update(uses='actions/checkout@${{ vars.PIN }}')),
            'job-if-hashfiles': ('checks.yml', lambda w: w['jobs']['aggregate'].update({'if': "always() && hashFiles('x') != ''"})),
            'unknown-context': ('ci.yml', lambda w: w['jobs']['resolve']['steps'][-1]['env'].update(CONTROLLER='${{ gitlab.sha }}')),
            'unknown-function': ('ci.yml', lambda w: w['jobs']['resolve']['steps'][-1]['env'].update(CONTROLLER='${{ toUpper(github.sha) }}')),
            'unterminated': ('ci.yml', lambda w: w['jobs']['resolve']['steps'][-1]['env'].update(CONTROLLER='${{ github.sha')),
            'untyped-input': ('ios-origin.yml', lambda w: w['on']['workflow_call']['inputs']['source'].pop('type')),
            'undeclared-input': ('testflight.yml', lambda w: w['jobs']['deliver']['with'].update(operation='promote')),
            'missing-required-input': ('testflight.yml', lambda w: w['jobs']['deliver']['with'].pop('receipt')),
            'undeclared-secret': ('ci.yml', lambda w: w['jobs']['publish-web']['secrets'].update(DELIVERY_ASC_KEY_ID='${{ secrets.DELIVERY_ASC_KEY_ID }}')),
            'missing-required-secret': ('testflight.yml', lambda w: w['jobs']['deliver']['secrets'].pop('DELIVERY_P12_PASSWORD')),
            'caller-token-below-callee': ('testflight.yml', lambda w: w['jobs']['deliver'].pop('permissions')),
            'call-step-key': ('testflight.yml', lambda w: w['jobs']['deliver'].update({'timeout-minutes': 5})),
            'call-missing-file': ('testflight.yml', lambda w: w['jobs']['deliver'].update(uses='./.github/workflows/ios-upload.yml')),
            'call-nonreusable': ('testflight.yml', lambda w: w['jobs']['deliver'].update(uses='./.github/workflows/ci.yml', secrets={}, **{'with': {}})),
        }
        for defect, (filename, mutate) in defects.items():
            changed = copy.deepcopy(actual)
            mutate(changed[filename])
            with self.subTest(defect=defect), self.assertRaises(gate.Rejected):
                validate_workflow_syntax(changed)
        # Healthy controls stay accepted: the rule set is not a blanket refusal.
        for control, (filename, mutate) in {
            'step-env-runner': ('ios-origin.yml', lambda w: w['jobs']['origin']['steps'][2].update(env={'SCRATCH': '${{ runner.temp }}/scratch'})),
            'job-env-secrets': ('ios-origin.yml', lambda w: w['jobs']['origin']['env'].update(KEY='${{ secrets.DELIVERY_ASC_KEY_ID }}')),
            'step-if-status': ('checks.yml', lambda w: w['jobs']['web']['steps'][-1].update({'if': "always() && hashFiles('reports/vitest.json') != ''"})),
            'job-if-bare-status': ('checks.yml', lambda w: w['jobs']['aggregate'].update({'if': "always() && needs.backend.result != 'skipped'"})),
        }.items():
            changed = copy.deepcopy(actual)
            mutate(changed[filename])
            with self.subTest(control=control):
                validate_workflow_syntax(changed)

    def test_actual_graph_and_negative_mutations(self):
        validate_graph(ROOT)
        # Copy ONLY candidate workflow/control text into a synthetic YAML fixture.
        # No application checkout or application tree is copied.
        original_defects = ('needs','checkout','skip','publisher-trigger','publisher-receipt','pg-packages','nested-cache','signing','helper','report-output','manifest-override','scope','required-output','cancel-consent','ios-bypass','policy-override','unverified-pin')
        secret_defects = tuple(target + ':' + defect for target in ('backend', 'web') for defect in ('missing-map','inherit','wrong-key','wrong-value','extra-secret','missing-declaration','optional-declaration','wrong-declaration'))
        # BUG-1793644501: a failed scan must fail its row. Removing, weakening, masking,
        # reordering or skipping a gate command is a reviewed controller change, never silent.
        scan_defects = {
            'scan-vulnerability-removed': ('backend', lambda lines: [l for l in lines if 'govulncheck' not in l]),
            'scan-vulnerability-masked': ('backend', lambda lines: [l + ' || true' if 'govulncheck' in l else l for l in lines]),
            'scan-vet-removed': ('backend', lambda lines: [l for l in lines if l != 'go vet ./...']),
            'scan-format-removed': ('backend', lambda lines: [l for l in lines if 'gofmt' not in l]),
            'scan-module-verify-removed': ('postgres', lambda lines: [l for l in lines if l != 'go mod verify']),
            'scan-analyze-removed': ('mobile', lambda lines: [l for l in lines if l != 'flutter analyze']),
            'scan-lint-removed': ('web', lambda lines: [l for l in lines if l != 'npm run lint']),
            'scan-build-removed': ('web', lambda lines: [l for l in lines if l != 'npm run build']),
            'scan-audit-removed': ('web', lambda lines: [l for l in lines if 'npm audit' not in l]),
            'scan-audit-weakened': ('web', lambda lines: [l.replace('--audit-level=moderate', '--audit-level=critical') for l in lines]),
            'scan-errexit-disabled': ('web', lambda lines: lines[:1] + ['set +e'] + lines[1:]),
            'scan-reordered': ('backend', lambda lines: lines[:-2] + lines[-1:] + lines[-2:-1]),
            'scan-ruby-syntax-removed': ('automation', lambda lines: [l for l in lines if 'ruby -c' not in l]),
            'scan-shell-syntax-removed': ('local-workflow', lambda lines: [l for l in lines if '/bin/bash -n' not in l]),
            'scan-step-skipped': ('backend', None),
            'scan-step-shell': ('web', None),
            'scan-default-shell': ('web', None),
            'scan-report-forged': ('web', None),
            'scan-job-env': ('backend', None),
        }
        for defect in original_defects + secret_defects + ('mobile-auto-pub', 'mobile-missing-acquisition') + tuple(scan_defects):
            with self.subTest(defect=defect),tempfile.TemporaryDirectory(prefix='gate-yaml-') as d:
                r=Path(d);wf=r/'.github/workflows';wf.mkdir(parents=True)
                for p in (ROOT/'.github/workflows').glob('*.yml'):(wf/p.name).write_text(p.read_text())
                ac=r/'.github/actions/build-signed-ipa';ac.mkdir(parents=True);(ac/'action.yml').write_text((ROOT/'.github/actions/build-signed-ipa/action.yml').read_text())
                path=wf/'checks.yml';j=yaml.safe_load(path.read_text())
                if ':' in defect:
                    target, problem = defect.split(':')
                    secret = 'DELIVERY_RENDER_DEPLOY_HOOK_URL' if target == 'backend' else 'DELIVERY_VERCEL_DEPLOY_KEY'
                    if problem.endswith('declaration'):
                        path = wf / ('deploy-backend.yml' if target == 'backend' else 'sync-web-viewer.yml')
                        j = yaml.safe_load(path.read_text())
                        contract = j['on']['workflow_call']
                        if problem == 'missing-declaration': del contract['secrets']
                        elif problem == 'optional-declaration': contract['secrets'][secret]['required'] = False
                        else: contract['secrets'] = {'UNRELATED_SECRET': {'required': True}}
                    else:
                        path = wf / 'ci.yml'; j = yaml.safe_load(path.read_text())
                        caller = j['jobs']['publish-' + target]
                        if problem == 'missing-map': del caller['secrets']
                        elif problem == 'inherit': caller['secrets'] = 'inherit'
                        elif problem == 'wrong-key': caller['secrets'] = {'UNRELATED_SECRET': '${{ secrets.' + secret + ' }}'}
                        elif problem == 'wrong-value': caller['secrets'][secret] = '${{ secrets.LEGACY_KEY }}'
                        else: caller['secrets']['EXTRA_KEY'] = '${{ secrets.EXTRA_KEY }}'
                elif defect in scan_defects:
                    row, change = scan_defects[defect]
                    step = next(s for s in j['jobs'][row]['steps'] if s.get('name') == 'Canonical ' + row + ' row')
                    if change is not None:
                        lines = step['run'].split('\n')
                        self.assertNotEqual(change(lines), lines)
                        step['run'] = '\n'.join(change(lines))
                    elif defect == 'scan-step-skipped': step['if'] = "${{ github.event_name != 'push' }}"
                    elif defect == 'scan-step-shell': step['shell'] = 'bash {0}'
                    elif defect == 'scan-default-shell': j['defaults']['run']['shell'] = 'sh'
                    elif defect == 'scan-report-forged':
                        steps = j['jobs'][row]['steps']
                        steps.insert(steps.index(step) + 1, {'run': 'cp candidate/web-bill-viewer/vitest.json reports/vitest.json'})
                    else: j['jobs'][row]['env'] = {'GOFLAGS': '-mod=mod'}
                elif defect in ('mobile-auto-pub', 'mobile-missing-acquisition'):
                    step = next(s for s in j['jobs']['mobile']['steps'] if s.get('name') == 'Canonical mobile row')
                    step['run'] = step['run'].replace(' --no-pub', '') if defect == 'mobile-auto-pub' else step['run'].replace('flutter pub get --enforce-lockfile\n', '')
                elif defect=='helper':
                    j['jobs']['aggregate']['steps'][-1]['run']=j['jobs']['aggregate']['steps'][-1]['run'].replace('control/','candidate/')
                elif defect=='report-output':j['jobs']['backend']['outputs']['report']='success'
                elif defect=='manifest-override':
                    step=next(s for s in j['jobs']['postgres']['steps'] if s.get('id')=='report');step['run']+=' --manifest candidate/manifest.json'
                elif defect=='scope':
                    path=wf/'ci.yml';j=yaml.safe_load(path.read_text());j['jobs']['checks']['with']['scope']='backend'
                elif defect=='required-output':
                    path=wf/'ci.yml';j=yaml.safe_load(path.read_text());j['jobs']['required']['outputs']['source']='${{ github.sha }}'
                elif defect=='cancel-consent':
                    path=wf/'update-release-notes.yml';j=yaml.safe_load(path.read_text());j['on']['workflow_dispatch']['inputs']['allow_cancel']['default']=True
                elif defect=='ios-bypass':
                    path=wf/'testflight.yml';j=yaml.safe_load(path.read_text());j['jobs']['deliver']['uses']='./.github/workflows/checks.yml'
                elif defect=='policy-override':
                    path=wf/'deploy-backend.yml';j=yaml.safe_load(path.read_text());j['jobs']['publish']['steps'][-1]['env']['RELEASE_POLICY']='${{ inputs.policy }}'
                elif defect=='unverified-pin':j['jobs']['backend']['steps'][0]['uses']='actions/checkout@'+'a'*40
                elif defect=='needs':j['jobs']['aggregate']['needs'].remove('postgres')
                elif defect=='checkout':j['jobs']['backend']['steps'][1]['with']['ref']='main'
                elif defect=='skip':j['jobs']['backend']['continue-on-error']=True
                elif defect=='pg-packages':
                    for step in j['jobs']['postgres']['steps']:
                        if 'go test' in step.get('run',''):step['run']=step['run'].replace('./internal/readiness ','')
                elif defect=='nested-cache':
                    for step in j['jobs']['mobile']['steps']:
                        if step.get('uses','').startswith('subosito/'):step['with']['pub-cache']='true'
                elif defect in ('publisher-trigger','publisher-receipt'):
                    path=wf/'deploy-backend.yml';j=yaml.safe_load(path.read_text())
                    if defect=='publisher-trigger':j['on']['push']={'branches':['main']}
                    else:del j['jobs']['publish']['steps'][-1]['env']['GATE_RECEIPT']
                else:path=ac/'action.yml';j=yaml.safe_load(path.read_text());j['runs']['steps'][0]['run']='echo signed'
                path.write_text(yaml.safe_dump(j,sort_keys=False))
                with self.assertRaises((gate.Rejected,KeyError)):validate_graph(r)



class CompletionRegressions(unittest.TestCase):
    def test_collector_rejects_candidate_supplied_manifest_hash(self):
        changed = needs()
        row = summary('postgres')
        row['manifest'] = 'e' * 64
        changed['postgres']['outputs']['report'] = gate.compact(row)
        with self.assertRaises(gate.Rejected):
            gate.collect(changed, B)

    def test_http_adapter_preserves_expected_error_status_without_network(self):
        import io
        import urllib.error
        error = urllib.error.HTTPError('https://example.invalid/synthetic', 404, 'synthetic', {}, io.BytesIO(b'{}'))
        with patch.object(gate.urllib.request, 'build_opener') as factory:
            factory.return_value.open.side_effect = error
            self.assertEqual(gate.http('GET', 'https://example.invalid/synthetic'), (404, b'{}'))


class ManifestReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='gate-manifest-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = gate.trusted_manifest()

    def go_events(self, families):
        events = []
        migration_children = (
            'early_deadline_result_survives_missing_barrier',
            'observer_error_keeps_primary_outcome',
            'missing_result_remains_unresolved',
            'closed_channel_is_not_success',
            'barrier_and_single_receive_preserve_original_cause',
        )
        assignment_children = {
            'TestCreateAssignmentDecodeDifferential': (
                'absent',
                'root_null',
                'name_null',
                'name_empty',
                'ref_null',
                'ref_empty',
                'both_null',
                'full_values',
                'folded_keys',
                'escaped_keys',
                'unicode_folded_key',
                'name_value_then_null',
                'name_null_then_value',
                'name_value_then_empty',
                'ref_value_then_null',
                'ref_null_then_value',
                'ref_value_then_empty',
                'folded_duplicate_name',
                'folded_duplicate_ref',
                'percentage_value_then_null',
                'percentage_null_then_value',
                'percentage_negative_zero',
                'percentage_negative',
                'percentage_subnormal',
                'percentage_underflow',
                'percentage_max_finite',
                'percentage_overflow',
                'wrong_name_type',
                'wrong_ref_type',
                'wrong_percentage_type',
                'wrong_name_before_valid',
                'wrong_name_after_valid',
                'wrong_ref_before_valid',
                'wrong_ref_after_valid',
                'wrong_percentage_before_valid',
                'wrong_percentage_after_valid',
                'unknown_null',
                'unknown_after_valid',
                'hidden_ref_flag',
                'hidden_name_flag',
                'untagged_name_alias',
                'invalid_utf8_value',
                'unpaired_surrogate',
                'root_array',
                'root_string',
                'root_number',
                'root_boolean',
                'empty_input',
                'truncated_object',
                'truncated_value',
                'malformed_separator',
                'trailing_document',
                'trailing_null',
                'trailing_garbage',
                'non_json_whitespace',
                'trailing_whitespace',
            ),
            'TestCreateAssignmentDecodeRequestContracts': (
                'wire1_absent_ref',
                'wire1_scalar_null_duplicate',
                'wire1_folded_name',
                'wire1_null_ref',
                'wire1_empty_ref',
                'wire1_duplicate_ref_to_null',
                'wire2_absent_name',
                'wire2_pointer_null_duplicate',
                'wire2_folded_ref',
                'wire2_null_name',
                'wire2_empty_name',
                'wire2_duplicate_name_to_null',
                'wire2_missing_ref',
                'wire2_null_ref',
            ),
        }
        followup_children = {'TestCreationRemaindersPreserveZeroShares': ('zero_tax_share', 'zero_total_share'),
         'TestCreationInsertAuditsShares': ('legacy_full',
                                            'partial_below_half_cent',
                                            'unclaimed',
                                            'fresh_reference_input',
                                            'overallocated',
                                            'negative_component',
                                            'nonfinite_component',
                                            'malformed_foreign_audit',
                                            'persisted_identity_not_fresh'),
         'TestCreationRoundingRemainsAccountable': ('mobile_fifteen_percent_half_cent',
                                                    'documented_one_cent_tolerance',
                                                    'healthy_exact_cent',
                                                    'mobile_eighteen_percent',
                                                    'mobile_quarter_tip_with_tax',
                                                    'signed_discount_remains_accountable'),
         'TestCentRemaindersPreserveClaimAndNameOrder': ('positive_name',
                                                         'negative_name',
                                                         'positive_recent',
                                                         'negative_recent',
                                                         'zero_before_negative_name',
                                                         'zero_recent_is_ineligible',
                                                         'eligible_recent_after_zero'),
         'TestRemainderDistributionIsBoundedForExtremeCounts': ('positive',
                                                                'negative',
                                                                'min_int64',
                                                                'eligible_bulk_debit',
                                                                'eligible_tie_order',
                                                                'insufficient',
                                                                'negative_balance',
                                                                'eligible_small_reference')}
        packages = sorted({f.rsplit('/', 1)[0] for f in families})
        for package in packages:
            events.append({'Action': 'start', 'Package': package})
            for family in families:
                if family.rsplit('/', 1)[0] == package:
                    test = family.rsplit('/', 1)[1]
                    events.append({'Action': 'run', 'Package': package, 'Test': test})
                    if family == 'backend/migrations/TestMigrationOutcomeObservation':
                        children = migration_children
                    elif package == 'backend/internal/bill':
                        children = assignment_children.get(test, followup_children.get(test, ()))
                    elif package == 'backend/pkg/safehttp':
                        children = {'TestStreamArrayStdlibCompatibility': ('nul',),
                                    'TestDecodeJSONPostgresText': ('map_nul', 'any_nul', 'invalid_utf8_replaced', 'unpaired_surrogate_replaced', 'map_key_nul', 'alias_nul', 'named_and_number')}.get(test, ())
                    elif package == 'backend/internal/tab':
                        children = {'TestPostgresJSONTextValidation': ('share_item_name',),
                                    'TestPostgresNULTokens': ('participant_query', 'paid_query', 'both_query', 'member_query', 'member_header', 'access_header', 'bill_read_member', 'tab_read_access')}.get(test, ())
                    else:
                        children = ()
                    for child in children:
                        events.extend([{'Action': action, 'Package': package,
                                        'Test': test + '/' + child} for action in ('run', 'pass')])
                    events.append({'Action': 'pass', 'Package': package, 'Test': test})
            events.append({'Action': 'pass', 'Package': package})
        return events

    def write(self, name, obj, lines=False):
        path = self.root/name
        path.write_text('\n'.join(gate.compact(x) for x in obj) if lines else gate.compact(obj))
        return path

    def test_every_source_grounded_Go_family_is_mandatory_and_overlap_is_retained(self):
        self.assertEqual(self.manifest['postgres_packages'], list(gate.PG_PACKAGES))
        self.assertIn('backend/migrations/TestPostgresIdentity0003NullSafeGroups', self.manifest['rows']['postgres'])
        snapshot_family = 'backend/internal/tab/TestPostgresLifecycleSnapshotCanonicalRows'
        self.assertIn(snapshot_family, self.manifest['rows']['postgres'])
        self.assertNotIn(snapshot_family, self.manifest['rows']['backend'])
        digest_family = 'backend/internal/tab/TestPostgresLifecycleDigestTracksCanonicalSnapshot'
        self.assertIn(digest_family, self.manifest['rows']['postgres'])
        self.assertNotIn(digest_family, self.manifest['rows']['backend'])
        overlap = set(self.manifest['rows']['backend']) & set(self.manifest['rows']['postgres'])
        self.assertTrue(overlap)
        assignment_prefixes = ('TestCreateAssignmentDecodeDifferential/',
                               'TestCreateAssignmentDecodeRequestContracts/')
        for row, filename in [('backend','go-default.jsonl'), ('postgres','go-postgres.jsonl')]:
            families = self.manifest['rows'][row]
            for parent in ('TestCreateAssignmentDecodeDifferential',
                           'TestCreateAssignmentDecodeReceiverSequence',
                           'TestCreateAssignmentDecodeRequestContracts'):
                self.assertIn('backend/internal/bill/' + parent, families)
            for parent in ('TestCreationRemaindersPreserveZeroShares', 'TestCreationInsertAuditsShares', 'TestCreationRoundingRemainsAccountable'):
                self.assertIn('backend/internal/bill/' + parent, families)
            events = self.go_events(families)
            children = [event['Test'] for event in events
                        if event['Action'] == 'run' and '/' in event.get('Test', '')]
            path = self.write(filename, events, True)
            healthy = gate.summarize(row, [('go', str(path))], self.manifest, B)
            self.assertEqual(healthy['passed'], len(families) + len(children))
            for absent in families:
                with self.subTest(row=row, absent=absent):
                    self.write(filename, self.go_events([f for f in families if f != absent]), True)
                    with self.assertRaises(gate.Rejected):
                        gate.summarize(row, [('go', str(path))], self.manifest, B)
            if row == 'postgres':
                child_prefix = 'TestMigrationOutcomeObservation/'
                migration_children = [child for child in children if child.startswith(child_prefix)]
                self.assertEqual(len(migration_children), 5)
                self.assertEqual(len(set(migration_children)), 5)
                for absent in migration_children:
                    with self.subTest(row=row, absent_child=absent):
                        selected = [event for event in events if event.get('Test') != absent]
                        self.assertEqual([event['Action'] for event in selected
                                          if event.get('Test') == child_prefix[:-1]], ['run', 'pass'])
                        self.assertEqual({event['Test'] for event in selected if event['Action'] == 'run'
                                          and event.get('Test', '').startswith(child_prefix)}, set(migration_children) - {absent})
                        path = self.write(filename, selected, True)
                        gate.validate_cases(gate.read_report('go', path)[1], families)
                        with self.assertRaisesRegex(gate.Rejected, 'missing mandatory test registration'):
                            gate.summarize(row, [('go', str(path))], self.manifest, B)
            assignment_children = [child for child in children if child.startswith(assignment_prefixes)]
            self.assertEqual(len(assignment_children), 70)
            self.assertEqual(len(set(assignment_children)), 70)
            for absent in assignment_children:
                with self.subTest(row=row, absent_assignment_child=absent):
                    selected = [event for event in events if event.get('Test') != absent]
                    parent = absent.rsplit('/', 1)[0]
                    self.assertEqual([event['Action'] for event in selected
                                      if event.get('Test') == parent], ['run', 'pass'])
                    self.assertEqual({event['Test'] for event in selected if event['Action'] == 'run'
                                      and event.get('Test', '').startswith(assignment_prefixes)}, set(assignment_children) - {absent})
                    path = self.write(filename, selected, True)
                    gate.validate_cases(gate.read_report('go', path)[1], families)
                    with self.assertRaisesRegex(gate.Rejected, 'missing mandatory test registration'):
                        gate.summarize(row, [('go', str(path))], self.manifest, B)

            followup_prefixes = ('TestCreationRemaindersPreserveZeroShares/', 'TestCreationInsertAuditsShares/',
                                 'TestCreationRoundingRemainsAccountable/', 'TestCentRemaindersPreserveClaimAndNameOrder/',
                                 'TestRemainderDistributionIsBoundedForExtremeCounts/')
            followup_children = [child for child in children if child.startswith(followup_prefixes)]
            self.assertEqual(len(followup_children), 32)
            self.assertEqual(len(set(followup_children)), 32)
            for absent in followup_children:
                with self.subTest(row=row, absent_accounting_child=absent):
                    selected = [event for event in events if event.get('Test') != absent]
                    parent = absent.rsplit('/', 1)[0]
                    self.assertEqual([event['Action'] for event in selected if event.get('Test') == parent], ['run', 'pass'])
                    self.assertEqual({event['Test'] for event in selected if event['Action'] == 'run'
                                      and event.get('Test', '').startswith(followup_prefixes)}, set(followup_children) - {absent})
                    path = self.write(filename, selected, True)
                    gate.validate_cases(gate.read_report('go', path)[1], families)
                    with self.assertRaisesRegex(gate.Rejected, 'missing mandatory test registration'):
                        gate.summarize(row, [('go', str(path))], self.manifest, B)

    def test_no_test_packages_are_distinct_from_skipped_or_unfinished_tests(self):
        good = self.go_events(['backend/example/TestSelected'])
        empty = [{'Action':'start','Package':'backend/empty'},
                 {'Action':'output','Package':'backend/empty','Output':'?\tbackend/empty\t[no test files]\n'},
                 {'Action':'skip','Package':'backend/empty'}]
        path = self.write('go.jsonl', good+empty, True)
        gate.validate_cases(gate.read_report('go', path)[1], ['backend/example/TestSelected'])
        for defect in ('missing-terminal','terminal-without-run','skip','cancelled','fail','malformed','duplicate-terminal','after-package'):
            events = self.go_events(['backend/example/TestSelected'])
            if defect == 'missing-terminal': events.pop(2)
            elif defect == 'terminal-without-run': events.pop(1)
            elif defect in ('skip','cancelled','fail'): events[2]['Action'] = defect
            elif defect == 'malformed': events.insert(1, {'Action':'unknown','Package':'backend/example'})
            elif defect == 'duplicate-terminal': events.insert(3, events[2])
            else: events += [events[1]]
            with self.subTest(defect=defect), self.assertRaises(gate.Rejected):
                gate.validate_cases(gate.read_report('go', self.write('bad.jsonl',events,True))[1], ['backend/example/TestSelected'])

    def test_public_render_table_requires_each_named_case(self):
        family = 'web-bill-viewer/src/lib/__tests__/public-web.test.ts'
        manifest = {'rows': {'web': [family]},
                    'reports': {'web': [['vitest', 'vitest.json']]},
                    'required_selections': {'web': {family: self.manifest['required_selections']['web'][family]}}}
        rendered = ['home renders complete public content without API or browser storage',
                    'policy renders complete public content without API or browser storage']
        titles = ['confines public indexing, canonical and social metadata to public routes',
                  *rendered, 'publishes only visible, bounded software claims on the homepage',
                  'enumerates only public documents and lets crawlers read private noindex',
                  'scopes the policy to the App Store version and marks unreleased behavior',
                  'states the released collection, provider, log, link and removal facts',
                  'makes no publication, effective-date, compliance or no-collection claim']
        def report(selected):
            cases = [{'fullName': 'public and private acquisition isolation ' + title,
                      'status': 'passed'} for title in selected]
            return self.write('vitest.json', {'success': True,
                'numTotalTests': len(cases), 'numPassedTests': len(cases),
                'testResults': [{'name': '/tmp/candidate/' + family,
                                 'assertionResults': cases}]})
        self.assertEqual(gate.summarize('web', [('vitest', str(report(titles)))], manifest, B)['passed'], len(titles))
        for absent in ([rendered[0]], [rendered[1]], rendered):
            with self.subTest(absent=absent), self.assertRaises(gate.Rejected):
                gate.summarize('web', [('vitest', str(report([title for title in titles if title not in absent])))], manifest, B)

    def test_all_adapter_families_and_report_files_are_required(self):
        for row in ('automation','local-workflow'):
            reports = []
            families = self.manifest['rows'][row]
            for kind, name in self.manifest['reports'][row]:
                selected = [f for f in families if (name == 'ruby.json' and f.startswith('ASCReleaseTest#')) or (name == 'ios-ruby.json' and f.startswith('IOSASCTests#')) or (name == 'ios-python.json' and f.startswith(('IOSArtifactTests.','IOSLifecycleTests.','IOSGraphTests.','IOSFailureBoundaryTests.'))) or (name == 'gate-tests.json' and '#' not in f and not f.startswith(('IOSArtifactTests.','IOSLifecycleTests.','IOSGraphTests.','IOSFailureBoundaryTests.')))] if row == 'automation' else families
                cases = [{'id':f,'family':f,'status':'pass'} for f in selected]
                obj = dict(complete=True, success=True, tests_run=len(cases), started=[c['id'] for c in cases], cases=cases)
                reports.append((kind,str(self.write(name,obj))))
            good = gate.summarize(row,reports,self.manifest,B)
            self.assertGreater(good['passed'],0)
            for family in families:
                cases = [{'id':f,'family':f,'status':'pass'} for f in families if f != family]
                with self.subTest(row=row, family=family),self.assertRaises(gate.Rejected):
                    gate.validate_cases(cases,families)
            with self.assertRaises(gate.Rejected): gate.summarize(row,reports[:-1],self.manifest,B)

    def test_mobile_and_web_reject_missing_literal_selections_and_runner_terminals(self):
        for kind, row, name in [('flutter','mobile','flutter.jsonl'),('vitest','web','vitest.json')]:
            manifest = {'rows':{row:['mobile/test/selected_test.dart' if row == 'mobile' else 'web-bill-viewer/selected.test.ts']},
                        'reports':{row:[[kind,name]]}}
            family = manifest['rows'][row][0]
            manifest['required_selections'] = {row:{family:[r'(?:^| )first$', r'(?:^| )second$']}}
            def report(titles):
                if kind == 'flutter':
                    events = [{'type':'suite','suite':{'id':1,'path':'/tmp/candidate/'+family}}]
                    for i,title in enumerate(titles):
                        events += [{'type':'testStart','test':{'id':i,'name':title,'suiteID':1}},
                                   {'type':'testDone','testID':i,'result':'success','skipped':False}]
                    return self.write(name,events+[{'type':'done','success':True}],True)
                cases = [{'fullName':t,'status':'passed'} for t in titles]
                return self.write(name,{'success':True,'numTotalTests':len(cases),'numPassedTests':len(cases),
                                        'testResults':[{'name':'/tmp/candidate/'+family,'assertionResults':cases}]})
            path=report(['group first','group second'])
            self.assertEqual(gate.summarize(row,[(kind,str(path))],manifest,B)['passed'],2)
            for titles in (['group first'], ['group second'], [], ['first','first']):
                with self.subTest(row=row,titles=titles),self.assertRaises(gate.Rejected):
                    gate.summarize(row,[(kind,str(report(titles)))],manifest,B)
        # All inherited families remain present; isolate the new exact literals.
        # The inherited mobile/web selection and terminal controls stay unchanged.
        quality_family = 'mobile/test/screenshot_quality_test.dart'
        quality_titles = (
            'Bill Details identity uses each saved roster color, not the amount rank',
            'Bill Details identity preserves a single saved roster color',
            'Bill Details identity keeps saved colors when multiple people choose the same color',
            'Bill Details identity counts items in plain English',
            'Bill Details identity chevrons follow the actual expanded row',
            'Person color ink every palette color reads on white and on its own row tint',
            'Person color ink keeps ink that already reads',
            'Person color ink avatar ink meets normal text contrast on every palette color',
            "Person color ink a shared item never takes one person's color",
            'Assignee stack shows four people instead of a +1',
            'Assignee stack summarises everyone past four',
            'Participant visual controls four-person selector fits the safe viewport at default text size',
            'Participant visual controls custom split rows remain usable at enlarged text size',
            'Participant visual controls summary amount ink changes no recorded values',
            'Participant visual controls auto-added owner keeps saved color with fresh occurrence refs',
        )
        quality_manifest = {
            'rows': {'mobile': self.manifest['rows']['mobile']},
            'reports': {'mobile': self.manifest['reports']['mobile']},
            'required_selections': {'mobile': {quality_family:
                self.manifest['required_selections']['mobile'][quality_family]}},
        }
        def quality_report(absent=None):
            events = []
            test_id = 0
            for suite_id, selected_family in enumerate(quality_manifest['rows']['mobile']):
                events.append({'type': 'suite', 'suite': {
                    'id': suite_id, 'path': '/tmp/candidate/' + selected_family}})
                titles = quality_titles if selected_family == quality_family else ('inherited family registration',)
                for title in titles:
                    if selected_family == quality_family and title == absent:
                        continue
                    events.extend([
                        {'type': 'testStart', 'test': {'id': test_id, 'name': title, 'suiteID': suite_id}},
                        {'type': 'testDone', 'testID': test_id, 'result': 'success', 'skipped': False},
                    ])
                    test_id += 1
            events.append({'type': 'done', 'success': True})
            return self.write('flutter.jsonl', events, True)
        healthy = gate.summarize('mobile', [('flutter', str(quality_report()))], quality_manifest, B)
        self.assertEqual(healthy['passed'], len(quality_manifest['rows']['mobile']) - 1 + len(quality_titles))
        for absent in quality_titles:
            with self.subTest(row='mobile', omitted_quality_literal=absent), self.assertRaisesRegex(
                    gate.Rejected, 'missing mandatory test registration'):
                gate.summarize('mobile', [('flutter', str(quality_report(absent)))], quality_manifest, B)
        # Independent source literals; keep every inherited family present while
        # isolating each new required-selection owner from unrelated matchers.
        followup_titles = [('flutter',
          'mobile',
          'mobile/test/tab_import_capacity_test.dart',
          ('thirty remote receipts retain every returned local ID',
           'thirty one remote receipts fail atomically without dangling IDs',
           'pending history survives a failed multi-receipt import',
           'referenced history survives a failed multi-receipt import',
           'a later existing import target cannot be evicted by an earlier new row',
           'malformed later receipt rolls back earlier refreshed content',
           'tab reference checkpoint failure rolls back the entire import',
           'invalid remote IDs never become a partial receipt list',
           'local history read error clears loading and retry recovers',
           'full remote history offers retry without partial person balances')),
         ('flutter',
          'mobile',
          'mobile/test/receipt_timestamp_test.dart',
          ('new receipt uses insertion time instead of historical table default',
           'explicit receipt timestamp is stored unchanged and an existing handle keeps its row')),
         # The conditional-title loop had no selection at all: its four named modes
         # could be removed while the row stayed green (focused S4 review, 2026-11-09).
         ('flutter',
          'mobile',
          'mobile/test/receipt_native_io_test.dart',
          ('native timeout closes actual upstream connection',
           'native real setup deadline can expire before any complete POST',
           'native headers stall timeout terminates upstream and joins fixture cleanup',
           'native cancellation stops a streaming upload and cancels its input subscription',
           'native source-error joins its input subscription cleanup',
           'native cleanup-error joins its input subscription cleanup',
           'native reentrant joins its input subscription cleanup',
           'native 302 never follows Location and counts only one wire POST',
           'native failed POST is never retried and a deliberate manual retry sends one new POST',
           'native compressed response enforces decoded 1MiB and closes stream',
           'native dropped response after upload never replays a POST')),
         ('vitest',
          'web',
          'web-bill-viewer/src/components/__tests__/LazyBillSession.test.ts',
          ('lazy viewer session across refreshed receipt props preserves typed join text when refreshed '
           'participants have a new array identity',
           'lazy viewer session across refreshed receipt props preserves deliberately emptied text but seeds the '
           'suggestion for a different tab',
           'lazy viewer session across refreshed receipt props revalidates the selected occurrence without '
           'repeating membership recovery on graph refresh',
           'lazy viewer session across refreshed receipt props clears its recovery warning after successful '
           'reauthentication without erasing another error',
           'lazy viewer session across refreshed receipt props keeps locked item status readable in both '
           'themes and uses a contrasting dark split hover'))]
        for kind, row, family, titles in followup_titles:
            focused = {'rows': {row: self.manifest['rows'][row]},
                       'reports': {row: self.manifest['reports'][row]},
                       'required_selections': {row: {family: self.manifest['required_selections'][row][family]}}}
            def followup_report(absent=None):
                if kind == 'flutter':
                    events, test_id = [], 0
                    for suite_id, selected_family in enumerate(focused['rows'][row]):
                        events.append({'type': 'suite', 'suite': {'id': suite_id, 'path': '/tmp/candidate/' + selected_family}})
                        cases = ('independent family-presence witness',) + titles if selected_family == family else ('inherited family registration',)
                        for title in cases:
                            if selected_family == family and title == absent:
                                continue
                            events.extend([{'type': 'testStart', 'test': {'id': test_id, 'name': title, 'suiteID': suite_id}},
                                           {'type': 'testDone', 'testID': test_id, 'result': 'success', 'skipped': False}])
                            test_id += 1
                    return self.write('flutter.jsonl', events + [{'type': 'done', 'success': True}], True)
                suites = []
                for selected_family in focused['rows'][row]:
                    cases = ('independent family-presence witness',) + titles if selected_family == family else ('inherited family registration',)
                    assertions = [{'fullName': title, 'status': 'passed'} for title in cases
                                  if not (selected_family == family and title == absent)]
                    suites.append({'name': '/tmp/candidate/' + selected_family, 'assertionResults': assertions})
                count = sum(len(suite['assertionResults']) for suite in suites)
                return self.write('vitest.json', {'success': True, 'numTotalTests': count,
                                  'numPassedTests': count, 'testResults': suites})
            self.assertEqual(gate.summarize(row, [(kind, str(followup_report()))], focused, B)['passed'],
                             len(focused['rows'][row]) + len(titles))
            for absent in titles:
                with self.subTest(row=row, omitted_followup_literal=absent), self.assertRaisesRegex(
                        gate.Rejected, 'missing mandatory test registration'):
                    gate.summarize(row, [(kind, str(followup_report(absent)))], focused, B)
        for defect in ('missing-done','after-done','duplicate-id','failed-done','unknown-event'):
            events=[{'type':'suite','suite':{'id':1,'path':'/tmp/mobile/test/x.dart'}},
                    {'type':'testStart','test':{'id':1,'name':'x','suiteID':1}},
                    {'type':'testDone','testID':1,'result':'success','skipped':False}, {'type':'done','success':True}]
            if defect=='missing-done':events.pop()
            elif defect=='after-done':events += [{'type':'print','message':'late'}]
            elif defect=='duplicate-id':events.insert(3,events[1])
            elif defect=='failed-done':events[-1]['success']=False
            else:events.insert(1,{'type':'unknown'})
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):gate.read_report('flutter',self.write(name,events,True))


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='gate-adapters-'); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)

    def test_actual_unittest_adapter_records_terminal_methods_and_repeated_subtests(self):
        for outcome in ('pass','skip','fail','error','expected','unexpected'):
            decorators = '@unittest.skip("synthetic")\n' if outcome=='skip' else '@unittest.expectedFailure\n' if outcome in ('expected','unexpected') else ''
            action = 'self.fail("synthetic")' if outcome in ('fail','expected') else 'raise ValueError("synthetic")' if outcome=='error' else 'self.assertTrue(True)'
            script=self.root/'synthetic_test.py'
            script.write_text('import unittest\nclass Synthetic(unittest.TestCase):\n'+''.join('    '+l+'\n' for l in decorators.splitlines())+'    def test_selected(self):\n        '+action+'\n        for _ in (1,2):\n            with self.subTest(label="same"):\n                self.assertTrue(True)\nif __name__ == "__main__": unittest.main()\n')
            report=self.root/'python.json'
            r=subprocess.run([sys.executable,str(ROOT/'ops/ci/unittest_report.py'),str(script)],env=dict(os.environ,CASE_REPORT=str(report),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True)
            with self.subTest(outcome=outcome):
                raw=report.read_bytes();cases=gate.parse(raw)['cases']
                if outcome=='pass':
                    self.assertEqual(r.returncode,0);gate.validate_cases(cases,['Synthetic.test_selected'])
                    self.assertEqual(len(cases),3);self.assertEqual(len({c['id'] for c in cases}),3)
                else:
                    with self.assertRaises(gate.Rejected):
                        gate.validate_cases(gate.read_report('cases',report)[1],['Synthetic.test_selected'])
        obj=gate.parse(report.read_bytes());obj.update(success=True)
        for defect in ('empty','unfinished','missing-terminal','duplicate','zero'):
            changed=copy.deepcopy(obj)
            if defect=='empty':changed['cases']=[]
            elif defect=='unfinished':changed['complete']=False
            elif defect=='missing-terminal':changed['cases']=[c for c in changed['cases'] if c['id'] not in changed['started']]
            elif defect=='duplicate':changed['started']*=2
            else:changed['tests_run']=0
            report.write_text(gate.compact(changed))
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):gate.read_report('cases',report)

    def test_actual_ruby_adapter_has_real_minitest_results_without_ASC(self):
        script=self.root/'synthetic_test.rb';report=self.root/'ruby.json'
        for outcome in ('pass','skip','fail'):
            action={'pass':'assert_equal 2, 1 + 1','skip':'skip "synthetic"','fail':'assert_equal 3, 1 + 1'}[outcome]
            script.write_text('require "minitest/autorun"\nclass SyntheticRuby < Minitest::Test\n  def test_selected\n    '+action+'\n  end\nend\n')
            r=subprocess.run(['ruby','-r',str(ROOT/'ops/ci/minitest_report.rb'),str(script)],env=dict(os.environ,CASE_REPORT=str(report)),capture_output=True,text=True)
            with self.subTest(outcome=outcome):
                if outcome=='pass':
                    self.assertEqual(r.returncode,0,r.stderr);cases=gate.read_report('cases',report)[1]
                    gate.validate_cases(cases,['SyntheticRuby#test_selected'])
                else:
                    with self.assertRaises(gate.Rejected):gate.validate_cases(gate.read_report('cases',report)[1],['SyntheticRuby#test_selected'])


class GuardRemovalTests(unittest.TestCase):
    def mutant(self, before, after):
        import types
        source=Path(gate.__file__).read_text();self.assertEqual(source.count(before),1)
        module=types.ModuleType('synthetic_guard_removal');module.__file__=gate.__file__
        exec(compile(source.replace(before,after),gate.__file__,'exec'),module.__dict__)
        return module

    def test_selected_result_and_health_guard_removals_are_detected(self):
        invalid=needs();invalid['postgres']['result']='skipped'
        with self.assertRaises(gate.Rejected):gate.collect(invalid,B)
        mutant=self.mutant("require(n.get('result') == 'success', 'selected check did not succeed: ' + row)","require(True, 'removed selected-result guard')")
        with self.assertRaises(AssertionError):
            with self.assertRaises(mutant.Rejected):mutant.collect(invalid,B)
        body=gate.compact({'status':'bill service - ok','commit':B['controller']}).encode()
        self.assertFalse(gate.healthy(200,body,B['source']))
        mutant=self.mutant(" and data.get('commit') == sha(source)","")
        with self.assertRaises(AssertionError):self.assertFalse(mutant.healthy(200,body,B['source']))


class EntrypointTests(GitFixture):
    def test_workflow_publisher_command_reauthorizes_before_synthetic_transport(self):
        import contextlib
        import io
        workflow=yaml.safe_load((ROOT/'.github/workflows/deploy-backend.yml').read_text())
        self.assertEqual(workflow['jobs']['publish']['steps'][-1]['run'], 'python3 control/ops/ci/delivery_gate.py publish --repo control --controller "$CONTROLLER" --source "$SOURCE"')
        event=dict(self.event,GITHUB_RUN_ID=B['run'],GITHUB_RUN_ATTEMPT=B['attempt'],DELIVERY_TARGET='backend',
                   RELEASE_POLICY=gate.compact(self.policy),GATE_RECEIPT=gate.compact(self.receipt),VERIFY_ONLY='false',
                   DELIVERY_RENDER_DEPLOY_HOOK_URL='https://api.render.com/deploy/synthetic?key=not-a-secret')
        actual_git=gate.git;actual_deploy=gate.deploy_backend;calls=[];serving=[self.source]
        def local_git(repo,*args,**kwargs):
            if args[0]=='fetch':calls.append('fresh-main');return ''
            return actual_git(repo,*args,**kwargs)
        def request(method,url):
            calls.append(method)
            if method=='POST':return 202,b'{}'
            # The first health read is the serving predecessor; later reads are the deployed S.
            commit=serving[0] if calls.count('GET')==1 else self.source
            return (200,gate.compact({'status':'bill service - ok','commit':commit}).encode()) if url.endswith('/health') else (404,b'')
        def deploy(*args):return actual_deploy(*args,request=request,sleep=lambda _:None)
        argv=['delivery_gate.py','publish','--repo',str(self.repo),'--source',self.source,'--controller',self.controller]
        for defect in ('healthy','disabled-policy','bad-receipt','wrong-C','feature','missing-secret','invalid-boolean','verification-only','serving-old-reader'):
            env=dict(event);calls.clear();serving[0]=self.old if defect=='serving-old-reader' else self.source
            if defect=='disabled-policy':env['RELEASE_POLICY']=gate.compact(gate.DISABLED_POLICY)
            elif defect=='bad-receipt':env['GATE_RECEIPT']=gate.compact(dict(self.receipt,source=self.controller))
            elif defect=='wrong-C':env['GITHUB_SHA']=self.source
            elif defect=='feature':env['GITHUB_REF']='refs/heads/feature'
            elif defect=='missing-secret':env['DELIVERY_RENDER_DEPLOY_HOOK_URL']=''
            elif defect=='invalid-boolean':env['VERIFY_ONLY']='$(touch PWNED)'
            elif defect=='verification-only':env['VERIFY_ONLY']='true';env['DELIVERY_RENDER_DEPLOY_HOOK_URL']=''
            with self.subTest(defect=defect),patch.dict(os.environ,env,clear=True),patch.object(sys,'argv',argv),patch.object(gate,'git',local_git),patch.object(gate,'http',request),patch.object(gate,'deploy_backend',deploy),contextlib.redirect_stdout(io.StringIO()) as output:
                if defect in ('healthy','verification-only'):
                    gate.main();self.assertIn('fresh-main',calls)
                    self.assertEqual('POST' in calls,defect=='healthy')
                    # The serving predecessor is observed before any hook request.
                    if defect=='healthy':self.assertEqual(calls,['fresh-main','GET','POST','GET','GET'])
                    self.assertNotIn('not-a-secret',output.getvalue())
                else:
                    with self.assertRaises(gate.Rejected):gate.main()
                    self.assertNotIn('POST',calls)

    def test_main_changes_select_publication_after_full_gate_and_no_candidate_policy_override(self):
        policy=gate.compact({'version':1,'enabled_targets':['backend','web']})
        for paths,expected in [(['docs/guide.md'],[]),(['backend/internal/bill/model.go'],['backend']),
                               (['web-bill-viewer/src/page.tsx'],['web']),(['.github/workflows/checks.yml'],['backend','web'])]:
            with self.subTest(paths=paths):self.assertEqual(gate.publication_selection('push','refs/heads/main','checks',policy,paths),expected)
        out=self.root/'resolve-output'
        env=dict(self.event,GITHUB_EVENT_NAME='push',GITHUB_SHA=self.controller,BEFORE_SOURCE=self.source,GITHUB_OUTPUT=str(out),REQUESTED_TARGET='checks',RELEASE_POLICY=policy)
        argv=['delivery_gate.py','resolve','--repo',str(self.repo),'--controller',self.controller]
        with patch.dict(os.environ,env,clear=True),patch.object(sys,'argv',argv):gate.main()
        self.assertIn('backend=false',out.read_text());self.assertIn('web=false',out.read_text())
        # Policy files in S have no read path in resolve/authorize; only the externally
        # supplied nonsecret policy above is consumed. CLI has no override option.
        r=subprocess.run([sys.executable,str(Path(gate.__file__)),'collect','--manifest','candidate/hostile.json'],capture_output=True,text=True)
        self.assertEqual(r.returncode,2)

    def test_ASC_transport_and_all_iOS_inputs_remain_unavailable_with_explicit_cancel_consent(self):
        ruby=ROOT/'.github/scripts/asc_api.rb'
        script='require '+json.dumps(str(ruby))+'\nmodule Net; class HTTP; def self.start(*); abort "NETWORK FORBIDDEN"; end; end; end\n[:post,:patch,:delete].each do |verb|\n begin\n ASC.request(verb,"/synthetic",body:{},allow_failure:true)\n abort "WRITE WAS ALLOWED"\n rescue ASC::Error => e\n abort "WRONG FAILURE" unless e.message == "ASC writes require verified delivery authority"\n end\nend\nputs "3 synthetic ASC mutation verbs rejected before authentication/network"\n'
        r=subprocess.run(['ruby','-e',script],env={k:v for k,v in self.env.items() if not k.startswith('ASC_')},capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr);self.assertIn('3 synthetic ASC',r.stdout)
        notes=yaml.safe_load((ROOT/'.github/workflows/update-release-notes.yml').read_text())
        self.assertEqual(notes['on']['workflow_dispatch']['inputs']['allow_cancel']['default'],False)
        for allow_cancel in ('true','false','$(touch PWNED)'):
            for target in gate.DISABLED:
                with self.subTest(allow_cancel=allow_cancel,target=target):
                    env=dict(self.event,ALLOW_CANCEL=allow_cancel,VERSION_STRING='1.2.3',BUILD_NUMBER='13')
                    with self.assertRaises(gate.Rejected):gate.authorize(self.repo,target,self.receipt,self.b,env,self.policy)
        for name in ('testflight.yml','app-store-release.yml','update-release-notes.yml'):
            w=yaml.safe_load((ROOT/'.github/workflows'/name).read_text())
            self.assertNotIn('skip_tests',w['on']['workflow_dispatch']['inputs'])
            self.assertEqual(set(w['jobs']['deliver']['needs']),{'resolve','required'})
            self.assertIn("needs.required.result == 'success'",w['jobs']['deliver']['if'])
            command='ios-unavailable' # Retired CLI still denies unauthenticated alternate entry.
            result=subprocess.run([sys.executable,str(Path(gate.__file__)),command],env=dict(self.event,ALLOW_CANCEL='true'),capture_output=True,text=True)
            self.assertEqual(result.returncode,1);self.assertIn('F-phase required',result.stderr)

    def test_source_floor_guard_removal_cannot_hide_future_source_floor(self):
        import types
        policy=copy.deepcopy(self.policy);policy['targets']['backend']['source_floor']=self.controller
        with self.assertRaises(gate.Rejected):gate.authorize(self.repo,'backend',self.receipt,self.b,self.event,policy)
        source=Path(gate.__file__).read_text();guard="ancestor(repo, sha(t.get('source_floor')), b['source']); "
        self.assertEqual(source.count(guard),1)
        mutant=types.ModuleType('synthetic_floor_guard_removal');mutant.__file__=gate.__file__
        exec(compile(source.replace(guard,''),gate.__file__,'exec'),mutant.__dict__)
        with self.assertRaises(AssertionError):
            with self.assertRaises(mutant.Rejected):mutant.authorize(self.repo,'backend',self.receipt,self.b,self.event,policy)


class DocumentationContractTests(unittest.TestCase):
    def test_VERIFICATION_uses_the_actual_report_commands_and_keeps_manual_boundaries(self):
        text=(ROOT/'VERIFICATION.md').read_text().replace('\\|','|')
        self.assertLessEqual(len((ROOT/'VERIFICATION.md').read_bytes()),20*1024)
        checks=yaml.safe_load((ROOT/'.github/workflows/checks.yml').read_text())
        for row in gate.ROWS:
            command=next(s['run'] for s in checks['jobs'][row]['steps'] if s.get('name')=='Canonical '+row+' row')
            for line in command.splitlines():
                if line.startswith(('go test ','flutter test ','npm test ')):
                    with self.subTest(row=row,command=line):self.assertIn('`'+line+'`',text)
        self.assertIn('Last verified: never',text)
        self.assertIn('phase F',text)
        self.assertIn('No hosted mutation or Render/Vercel control-plane work',text)
        self.assertNotIn('skip_tests',text)

    def test_VERIFICATION_names_CI_python_and_inline_iOS_reports(self):
        text=(ROOT/'VERIFICATION.md').read_text()
        self.assertIn('python3.12 -m venv',text)
        self.assertIn('--require-hashes --only-binary=:all: -r ops/ci/requirements-ci.txt',text)
        self.assertIn('macOS',text)
        for name,script in (('gate-tests','test_delivery_gate'),('ios-python','test_ios_artifact')):
            self.assertIn('CASE_REPORT="$REPORT_DIR/'+name+'.json" "$VV_PYTHON" ops/ci/unittest_report.py ops/ci/'+script+'.py',text)
        self.assertIn('CASE_REPORT="$REPORT_DIR/ios-ruby.json" ruby -r "$PWD/ops/ci/minitest_report.rb" .github/scripts/asc_delivery_test.rb',text)
        self.assertIn('password=<fixture-password>',text)
        # Text moved out of this size-limited file stays required: each link and its target heading.
        for path,heading in (('backend/README.md','PostgreSQL schema startup'),('backend/README.md','PostgreSQL verification retention'),
                             ('ops/ci/README.md','Isolated Go unit row'),('ops/ci/README.md','Local viewer CORS proof')):
            with self.subTest(heading=heading):
                self.assertIn(path+'#'+heading.lower().replace(' ','-'),text)
                self.assertIn('\n## '+heading+'\n',(ROOT/path).read_text())

    def test_VERIFICATION_isolates_ports_and_allows_only_the_selected_viewer_origin(self):
        text=(ROOT/'VERIFICATION.md').read_text()
        recipe=text.split('## Appendix A',1)[1]
        override=recipe.split("<<'YAML'\n",1)[1].split('\nYAML',1)[0]
        config=yaml.load(override,Loader=yaml.BaseLoader)
        api=config['services']['bill-service']
        self.assertIn('ports: !override',override)
        self.assertEqual(api['ports'],['127.0.0.1:${VV_API_PORT:?set VV_API_PORT}:8080'])
        self.assertEqual(api['environment']['CORS_ORIGINS'],'${VV_VIEWER_ORIGIN:?set VV_VIEWER_ORIGIN}')
        # The allowed origin is the URL the viewer prints: the address and port it is started on.
        host=re.search(r'npm run start -- --hostname (\S+) -p "\$VV_WEB_PORT"',text).group(1)
        self.assertIn('export VV_VIEWER_ORIGIN="http://'+host+':$VV_WEB_PORT"',recipe)
        self.assertIn('DB_PASSWORD="${VV_DB_PASSWORD:?set VV_DB_PASSWORD}"',recipe)
        self.assertIn('--env-file /dev/null',recipe)
        self.assertNotIn('DB_PASSWORD=vv_synthetic_fixture',recipe)

    def test_operational_docs_match_routes_and_signed_capabilities(self):
        read=lambda path:(ROOT/path).read_text()
        readme=read('README.md')
        # PR #149 removed the viewer's /privacy route; the maintained route is /privacy-policy.
        # README may name the old route only where it says that it was removed.
        for paragraph in readme.split('\n\n'):
            if re.search(r'(?<![\w.])/privacy(?![-\w.])',paragraph):
                with self.subTest(paragraph=paragraph[:60]):self.assertRegex(paragraph,r'removed on purpose \(PR #149\)')
        self.assertIn('/privacy-policy',readme)
        api=read('docs/backend-api.md')
        routes=re.findall(r'r\.(GET|POST|PATCH|PUT|DELETE)\("([^"]+)"',read('backend/cmd/bill-service/main.go'))
        self.assertGreaterEqual(len(routes),31)
        self.assertIn('## Route index',api)
        index=api.split('## Route index',1)[1].split('\n## ',1)[0]
        self.assertEqual(sorted(re.findall(r'^\| `([A-Z]+) (/[^`]*)` \|',index,re.M)),sorted(routes))
        self.assertNotIn('/images',api)
        # The documented invite capabilities describe these signed-build inputs.
        self.assertNotIn('associated-domains',read('mobile/ios/Runner/RunnerProfile.entitlements'))
        self.assertIn('<string>billington</string>',read('mobile/ios/Runner/Info.plist'))

    def test_initial_policy_and_local_reports_cannot_emit_a_release_receipt(self):
        with tempfile.TemporaryDirectory(prefix='gate-local-report-') as d:
            output=Path(d)/'github-output'
            env=dict(os.environ,GITHUB_OUTPUT=str(output))
            r=subprocess.run([sys.executable,str(Path(gate.__file__)),'validate-reports','--row','backend','--reports','go:'+str(Path(d)/'missing')],env=env,capture_output=True,text=True)
            self.assertEqual(r.returncode,1);self.assertFalse(output.exists())
            self.assertEqual(gate.DISABLED_POLICY,{'version':1,'enabled_targets':[],'control_floor':None,'targets':{}})

if __name__ == '__main__':
    with patch('socket.socket.connect', side_effect=AssertionError('network forbidden in offline tests')):
        unittest.main(verbosity=2)
