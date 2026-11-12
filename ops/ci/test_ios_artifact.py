"""Small offline API/ZIP/YAML/signing-lifecycle fixtures. Network forbidden."""
import base64
import copy
from datetime import datetime, timezone
import io
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile
import yaml
import delivery_gate as gate
import ios_artifact as ios
import ios_sign

ROOT = Path(__file__).resolve().parents[2]
NOW = datetime(2026, 11, 5, tzinfo=timezone.utc).timestamp()
HOST = 'synthetic-results.blob.core.windows.net'
TOOL = {'flutter':'3.41.5','cocoapods':'1.16.2','sdk':'26.0','xcode':'Xcode 26.0\nBuild version SYNTHETIC','developer_dir':'/Applications/Xcode_26.0.app/Contents/Developer'}


def zipdata(files):
    b = io.BytesIO()
    with zipfile.ZipFile(b, 'w') as z:
        for name, data in files.items():
            z.writestr(zipfile.ZipInfo(name), data)
    return b.getvalue()


def ipa(**changes):
    p = {'CFBundleIdentifier':'com.example.app','CFBundleShortVersionString':'1.4.0','CFBundleVersion':'25',
         'CFBundleSupportedPlatforms':['iPhoneOS'],'DTPlatformName':'iphoneos'}
    p.update(changes)
    return zipdata({'Payload/Runner.app/Info.plist':plistlib.dumps(p),'Payload/Runner.app/Runner':b'SYNTHETIC-NOT-EXECUTABLE'})


def summary_receipt(b):
    n = {r:{'result':'success','outputs':{'report':gate.compact(dict(b,row=r,passed=1,failed=0,skipped=0,manifest=gate.manifest_hash(),reports=['d'*64]*len(gate.trusted_manifest()['reports'][r])))}} for r in gate.ROWS}
    return gate.collect(n,b)


def joblist(b, origin=False):
    names = ['Gate '+r for r in gate.ROWS]+['Selected checks all','Required delivery checks']+(['Upload iOS origin'] if origin else [])
    return [dict(id=i+1,name='checks / '+n if n.startswith(('Gate ','Selected ')) else n,run_id=int(b['run']),run_attempt=int(b['attempt']),head_sha=b['controller'],status='completed',conclusion='success',started_at='2026-11-05T00:00:00Z',completed_at='2026-11-05T01:00:00Z') for i,n in enumerate(names)]


class IOSArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ios-synthetic-'); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.repo = self.root/'repo'; self.repo.mkdir()
        self.env = dict(os.environ,GIT_AUTHOR_NAME='Victor Ivanov',GIT_AUTHOR_EMAIL='victor.n.ivanov@gmail.com',GIT_COMMITTER_NAME='Victor Ivanov',GIT_COMMITTER_EMAIL='victor.n.ivanov@gmail.com',GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=os.devnull,GIT_ALLOW_PROTOCOL='file',PYTHONDONTWRITEBYTECODE='1')
        self.git('init','--initial-branch=main')
        self.write_source('1.3.0','24'); self.git('add','.'); self.git('commit','-m','synthetic previous'); self.old=self.git('rev-parse','HEAD')
        self.write_source('1.4.0','25'); self.git('add','.'); self.git('commit','-m','synthetic source'); self.source=self.git('rev-parse','HEAD')
        (self.repo/'controller.txt').write_text('synthetic controller'); self.git('add','.'); self.git('commit','-m','synthetic C'); self.control=self.git('rev-parse','HEAD')
        self.git('update-ref','refs/remotes/origin/main',self.control)
        self.b={'source':self.source,'controller':self.control,'scope':'all','run':'71','attempt':'1'}
        self.current=dict(self.b,run='99')
        target={'source_floor':self.source,'capability_floors':{'synthetic':self.source},'schema_floor':self.source,'schema_epoch':1,'minimum_migration':2,'schema_registry_sha256':gate.digest((self.repo/'backend/migrations/registry.go').read_bytes()),'external_clearance':'SYNTHETIC-ONLY','app_id':'app-1','bundle_id':'com.example.app','toolchain':copy.deepcopy(TOOL),'artifact_download_hosts':[HOST],'previous_source':self.old}
        self.policy={'version':1,'enabled_targets':list(gate.TARGETS),'control_floor':self.old,'targets':{r:copy.deepcopy(target) for r in gate.TARGETS}}
        self.event=dict(self.env,GITHUB_REF='refs/heads/main',GITHUB_EVENT_NAME='workflow_dispatch',GITHUB_REPOSITORY=gate.REPOSITORY,GITHUB_WORKFLOW_REF=gate.REPOSITORY+'/.github/workflows/app-store-release.yml@refs/heads/main',GITHUB_SHA=self.control,GITHUB_RUN_ID='99',GITHUB_RUN_ATTEMPT='1',SOURCE=self.source,CONTROLLER=self.control,DELIVERY_TARGET='ios-production',GATE_RECEIPT=gate.compact(summary_receipt(self.current)),RELEASE_POLICY=gate.compact(self.policy),ORIGIN_RUN='71',ORIGIN_ATTEMPT='1',ASC_BUILD_ID='build-25',VERSION_STRING='1.4.0',VERIFY_ONLY='false',GH_TOKEN='INERT_GH_SENTINEL')
        self.receipt={'schema':1,'repository':gate.REPOSITORY,'workflow':ios.ORIGIN,'event':'workflow_dispatch','binding':self.b,'gate':summary_receipt(self.b),'source':ios.source_metadata(self.repo,self.source),'binary':ios.inspect_ipa(ipa(),{}),'toolchain':copy.deepcopy(TOOL),'asc':{'app_id':'app-1','build_id':'build-25','bundle':'com.example.app','version':'1.4.0','build':'25','platform':'IOS','processing_state':'VALID','audience':'APP_STORE_ELIGIBLE','expired':False,'expiration':'2099-01-01T00:00:00Z','uploaded_at':'2026-11-05T00:00:00Z'},'ipa_artifact':{'id':11,'name':ios.evidence_name('ipa',self.b),'digest':''}}
        self.calls=[]; self.ipa=ipa(); self.rebuild_artifacts()
        self.run=self.run_obj(self.b,True); self.current_run=self.run_obj(self.current,False,workflow='.github/workflows/app-store-release.yml');self.jobs=joblist(self.b,True);self.current_jobs=joblist(self.current)
        self.redirect='https://'+HOST+'/artifact?id=INERT_SIGNED_URL'
        self.client=ios.GitHub('INERT_GH_SENTINEL',[HOST],request=self.request)

    def git(self,*args):
        if args[0] == 'commit':
            for var in ('GIT_AUTHOR_IDENT', 'GIT_COMMITTER_IDENT'):
                identity = subprocess.check_output(['git','-C',str(self.repo),'var',var],env=self.env,text=True)
                self.assertTrue(identity.startswith('Victor Ivanov <victor.n.ivanov@gmail.com> '))
        result = subprocess.check_output(['git','-C',str(self.repo),*args],env=self.env,stderr=subprocess.DEVNULL,text=True).strip()
        if args[0] == 'commit':
            identity = subprocess.check_output(['git','-C',str(self.repo),'log','-1','--format=%an|%ae|%cn|%ce'],env=self.env,text=True).strip()
            self.assertEqual(identity,'Victor Ivanov|victor.n.ivanov@gmail.com|Victor Ivanov|victor.n.ivanov@gmail.com')
        return result

    def write_source(self,version,number):
        files={'mobile/pubspec.yaml':f'version: {version}+{number}\n','mobile/pubspec.lock':'synthetic dart lock','mobile/ios/Podfile.lock':'synthetic pods lock','mobile/lib/screens/settings/settings_screen.dart':f"text = 'Version {version}';\n",'backend/migrations/registry.go':'const CompatibilityEpoch = 1\n{Version: 1, Name: "one"}\n{Version: 2, Name: "two"}\n'}
        config='CURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";\nDEVELOPMENT_TEAM = ABCDE12345;\nMARKETING_VERSION = '+version+';\nPRODUCT_BUNDLE_IDENTIFIER = com.example.app;\nCODE_SIGN_STYLE = Automatic;\nCODE_SIGN_IDENTITY = "Apple Development";\nPROVISIONING_PROFILE_SPECIFIER = "";\n};\n'
        files['mobile/ios/Runner.xcodeproj/project.pbxproj']=config*3+'CURRENT_PROJECT_VERSION = 1;\nMARKETING_VERSION = 1.0;\nCODE_SIGN_STYLE = Automatic;\n};\n'
        for p,b in files.items():
            dest=self.repo/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(b)

    def run_obj(self,b,success,workflow=ios.ORIGIN):
        return dict(id=int(b['run']),run_attempt=int(b['attempt']),head_sha=b['controller'],head_branch='main',event='workflow_dispatch',path=workflow,repository={'id':1,'full_name':gate.REPOSITORY},head_repository={'id':1,'full_name':gate.REPOSITORY},status='completed' if success else 'in_progress',conclusion='success' if success else None)

    def meta(self,ident,kind,raw):
        return dict(id=ident,name=ios.evidence_name(kind,self.b),size_in_bytes=len(raw),digest='sha256:'+gate.digest(raw),expired=False,expires_at='2099-01-01T00:00:00Z',created_at='2026-11-05T00:30:00Z',workflow_run=dict(id=71,head_sha=self.control,head_branch='main',repository_id=1,head_repository_id=1))

    def rebuild_artifacts(self):
        self.ipa_zip=zipdata({'candidate.ipa':self.ipa})
        self.receipt['ipa_artifact']['digest']='sha256:'+gate.digest(self.ipa_zip)
        self.receipt_zip=zipdata({'receipt.json':gate.compact(self.receipt).encode()})
        self.artifacts=[self.meta(10,'origin',self.receipt_zip),self.meta(11,'ipa',self.ipa_zip)]

    def request(self,url,headers,limit):
        self.calls.append((url,headers.copy(),limit))
        if url.startswith('https://'+HOST):
            self.assertEqual(headers,{})
            return 200,{},self.receipt_zip if url.endswith('receipt') else self.ipa_zip
        self.assertEqual(headers['Authorization'],'Bearer INERT_GH_SENTINEL')
        path=url.removeprefix('https://api.github.com')
        if path.endswith('/attempts/1'):obj=self.current_run if '/runs/99/' in path else self.run
        elif '/jobs?' in path:
            rows=self.current_jobs if '/runs/99/' in path else self.jobs
            page=int(path.split('page=')[-1]);obj={'total_count':len(rows),'jobs':rows[(page-1)*5:page*5]}
        elif '/artifacts?' in path:
            page=int(path.split('page=')[-1]);obj={'total_count':len(self.artifacts),'artifacts':self.artifacts[(page-1):page]}
        elif path.endswith('/10/zip'):return 302,{'location':self.redirect+'/receipt'},b''
        elif path.endswith('/11/zip'):return 302,{'location':self.redirect+'/ipa'},b''
        else:self.fail('Unexpected synthetic GET '+path)
        return 200,{},gate.compact(obj).encode()

    def origin(self):
        return ios.verify_origin(self.repo,self.event,self.policy,self.current,self.client,now=lambda:NOW)

    def test_exact_origin_pagination_and_digest_binding(self):
        self.assertEqual(self.origin(),self.receipt)
        self.assertTrue(any('page=2' in c[0] for c in self.calls))
        self.assertTrue(any('page=2' in c[0] and '/jobs?' in c[0] for c in self.calls))
        self.assertNotEqual(self.source,self.run['head_sha'])
        ctx=ios.context(self.repo,self.event,github=self.client,refresh=False)
        self.assertEqual(ctx['origin']['asc']['build_id'],'build-25')

    def test_each_origin_identity_and_job_result_is_required(self):
        original=copy.deepcopy(self.run)
        for key,value in [('id',72),('run_attempt',2),('head_sha',self.old),('head_branch','feature'),('path','.github/workflows/ci.yml'),('event','pull_request'),('status','in_progress'),('conclusion','skipped'),('repository',{'full_name':'wrong/repo'}),('head_repository',{'full_name':'wrong/repo'})]:
            with self.subTest(key=key):
                self.run=dict(original,**{key:value})
                with self.assertRaises(gate.Rejected):self.origin()
        self.run=original
        original=copy.deepcopy(self.jobs)
        for i in range(len(original)):
            for state in ('failure','skipped','cancelled',None):
                with self.subTest(job=i,state=state):
                    self.jobs=copy.deepcopy(original);self.jobs[i]['conclusion']=state
                    with self.assertRaises(gate.Rejected):self.origin()
            self.jobs=[j for n,j in enumerate(original) if n!=i]
            with self.subTest(job=i,missing=True),self.assertRaises(gate.Rejected):self.origin()
        self.jobs=original+[dict(original[0],id=99)]
        with self.assertRaises(gate.Rejected):self.origin()

    def test_missing_duplicate_expired_tampered_and_wrong_named_artifacts(self):
        original=copy.deepcopy(self.artifacts)
        for defect in ('missing','duplicate','expired','expiry','name','digest','run','head','repo','size','attempt-window'):
            self.artifacts=copy.deepcopy(original)
            if defect=='missing':self.artifacts.pop(0)
            elif defect=='duplicate':self.artifacts.append(dict(self.artifacts[0],id=12))
            elif defect=='expired':self.artifacts[0]['expired']=True
            elif defect=='expiry':self.artifacts[0]['expires_at']='2020-01-01T00:00:00Z'
            elif defect=='name':self.artifacts[0]['name']='latest'
            elif defect=='digest':self.artifacts[0]['digest']='sha256:'+'0'*64
            elif defect=='run':self.artifacts[0]['workflow_run']['id']=99
            elif defect=='head':self.artifacts[0]['workflow_run']['head_sha']=self.source
            elif defect=='repo':self.artifacts[0]['workflow_run']['repository_id']=2
            elif defect=='size':self.artifacts[0]['size_in_bytes']=ios.MAX_ARCHIVE+1
            else:self.artifacts[0]['created_at']='2026-11-04T00:00:00Z'
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):self.origin()

    def test_receipt_gate_binary_and_processed_build_fields_are_bound(self):
        original=copy.deepcopy(self.receipt)
        mutations=[('binding','source',self.old),('binding','attempt','2'),('gate','status','failure'),('gate','scope','mobile'),('gate','rows',{}),('gate','manifest','0'*64),('source','locks',{}),('binary','sha256','0'*64),('binary','version','1.3.0'),('asc','app_id','wrong-app'),('asc','build_id','wrong-build'),('asc','platform','MAC_OS'),('asc','version','1.3.0'),('asc','build','24'),('asc','processing_state','PROCESSING'),('asc','processing_state','INVALID'),('asc','expired',True),('asc','audience','INTERNAL_ONLY'),('asc','expiration','2020-01-01T00:00:00Z'),('ipa_artifact','id',12)]
        for section,key,value in mutations:
            self.receipt=copy.deepcopy(original);self.receipt[section][key]=value;self.rebuild_artifacts()
            with self.subTest(section=section,key=key,value=value):
                # An app ID is also bound to current policy by context.
                with self.assertRaises(gate.Rejected):
                    ios.context(self.repo,self.event,github=self.client,refresh=False)
        self.receipt=original;self.ipa=ipa(CFBundleIdentifier='wrong.bundle');self.rebuild_artifacts()
        with self.assertRaises(gate.Rejected):self.origin()

    def test_current_gate_main_and_floors_are_reauthorized_before_origin(self):
        original=copy.deepcopy(self.event)
        for key,value in [('GITHUB_REF','refs/heads/feature'),('GITHUB_EVENT_NAME','pull_request'),('GITHUB_SHA',self.source),('GITHUB_WORKFLOW_REF',gate.WORKFLOW),('GATE_RECEIPT','{}'),('RELEASE_POLICY',gate.compact(gate.DISABLED_POLICY)),('VERSION_STRING','1.3.0'),('ORIGIN_ATTEMPT',''),('VERIFY_ONLY','yes')]:
            self.calls.clear()
            with self.subTest(key=key),self.assertRaises(gate.Rejected):ios.context(self.repo,dict(original,**{key:value}),github=self.client,refresh=False)
        # A repository with no RELEASE_POLICY variable gives every iOS job env ''.
        # Each of the three paths must refuse before any authenticated read, while the
        # same event with the synthetic enabled policy is accepted (BUG-1794258285).
        for target,filename in gate.IOS_WORKFLOWS.items():
            event=dict(original,DELIVERY_TARGET=target,GITHUB_WORKFLOW_REF=gate.REPOSITORY+'/.github/workflows/'+filename+'@refs/heads/main')
            self.current_run=self.run_obj(self.current,False,workflow='.github/workflows/'+filename)
            self.assertEqual(ios.context(self.repo,event,github=self.client,refresh=False)['authorization']['target'],target)
            for label,value in [('unset',''),('absent',None),('disabled',gate.compact(gate.DISABLED_POLICY))]:
                env=dict(event,RELEASE_POLICY=value)
                if value is None:del env['RELEASE_POLICY']
                self.calls.clear()
                with self.subTest(target=target,policy=label),self.assertRaises(gate.Rejected):ios.context(self.repo,env,github=self.client,refresh=False)
                self.assertEqual(self.calls,[],'policy refusal precedes authenticated reads')
        self.current_run=self.run_obj(self.current,False,workflow='.github/workflows/app-store-release.yml')
        policy=copy.deepcopy(self.policy);policy['control_floor']=self.control;policy['targets']['ios-production']['source_floor']=self.control
        with self.assertRaises(gate.Rejected):ios.context(self.repo,dict(original,RELEASE_POLICY=gate.compact(policy)),github=self.client,refresh=False)
        self.current_jobs[0]['conclusion']='skipped'
        with self.assertRaises(gate.Rejected):ios.context(self.repo,original,github=self.client,refresh=False)

    def test_ipa_multiple_missing_metadata_and_archive_paths_rejected(self):
        expected={'bundle':'com.example.app','version':'1.4.0','build':'25','platform':'IOS'}
        self.assertEqual(ios.inspect_ipa(ipa(),expected)['build'],'25')
        variants=[zipdata({'nothing':b'x'}),zipdata({'Payload/A.app/Info.plist':b'x','Payload/B.app/Info.plist':b'x'}),zipdata({'../receipt.json':b'x'}),ipa(CFBundleVersion='24'),ipa(CFBundleSupportedPlatforms=['iPhoneSimulator']),ipa(DTPlatformName='iphonesimulator'),ipa(CFBundleShortVersionString='1.3.0')]
        for raw in variants:
            with self.subTest(raw_hash=gate.digest(raw)),self.assertRaises(gate.Rejected):ios.inspect_ipa(raw,expected)

    def test_hostile_redirects_headers_bounds_and_log_taint(self):
        meta=self.artifacts[0]
        for redirect in ['http://'+HOST+'/x','https://evil.test/x','https://api.github.com/x','https://user:pass@'+HOST+'/x','https://'+HOST+'/x#fragment']:
            calls=[]
            def transport(url,headers,limit):
                calls.append((url,headers));return 302,{'location':redirect},b''
            client=ios.GitHub('INERT_GH_SENTINEL',[HOST],request=transport)
            with self.subTest(redirect=redirect),self.assertRaises(gate.Rejected):client.archive(meta)
            self.assertEqual(len(calls),1)
        calls=[]
        def transport(url,headers,limit):
            calls.append((url,headers));return (302,{'location':'https://'+HOST+'/x'},b'') if len(calls)==1 else (302,{'location':'https://evil.test'},b'')
        with self.assertRaises(gate.Rejected):ios.GitHub('INERT_GH_SENTINEL',[HOST],request=transport).archive(meta)
        self.assertEqual(calls[-1][1],{})
        with patch.object(ios.urllib.request,'build_opener') as opener:
            opener.return_value.open.side_effect=OSError('INERT_GH_SENTINEL INERT_SIGNED_URL')
            with self.assertRaisesRegex(gate.Rejected,'^evidence transport failed$'):ios.transport('https://api.github.com/x',{},5)
        previous=ios.signal.getsignal(ios.signal.SIGALRM)
        def expire(*args,**kwargs):
            ios.signal.getsignal(ios.signal.SIGALRM)(ios.signal.SIGALRM,None)
        with patch.object(ios.urllib.request,'build_opener') as opener:
            opener.return_value.open.side_effect=expire
            with self.assertRaisesRegex(gate.Rejected,'60-second deadline'):ios.transport('https://api.github.com/x',{},5)
        self.assertIs(ios.signal.getsignal(ios.signal.SIGALRM),previous)
        self.assertEqual(ios.signal.getitimer(ios.signal.ITIMER_REAL),(0.0,0.0))
        for obj in [dict(total_count=2001,artifacts=[]),dict(total_count=1,artifacts=[]),dict(total_count=True,artifacts=[])]:
            client=ios.GitHub('INERT',[HOST],request=lambda *args:(200,{},gate.compact(obj).encode()))
            with self.assertRaises(gate.Rejected):client.pages(ios.PREFIX+'/actions/runs/71/artifacts','artifacts')

    def test_actual_context_CLI_refreshes_main_and_never_accepts_local_receipt_file(self):
        import contextlib
        output=io.StringIO();calls=[];actual=gate.git
        def local_git(repo,*args,**kwargs):
            if args[0]=='fetch':calls.append('fresh-main');return ''
            return actual(repo,*args,**kwargs)
        with patch.dict(os.environ,self.event,clear=True),patch.object(sys,'argv',['ios_artifact.py','context','--repo',str(self.repo)]),patch.object(gate,'git',local_git),patch.object(ios,'GitHub',return_value=self.client),contextlib.redirect_stdout(output):
            ios.main()
        self.assertEqual(calls,['fresh-main','fresh-main'])
        result=gate.parse(output.getvalue());self.assertEqual(result['origin']['asc']['build_id'],'build-25')
        self.assertNotIn('INERT_GH_SENTINEL',output.getvalue());self.assertNotIn('INERT_SIGNED_URL',output.getvalue())
        p=subprocess.run([sys.executable,str(Path(ios.__file__)),'context','--receipt','arbitrary.json'],env=self.env,capture_output=True,text=True)
        self.assertEqual(p.returncode,2)

    def test_upload_context_requires_prior_version_bump_and_never_trusts_rerun(self):
        event=dict(self.event,DELIVERY_TARGET='ios-upload',GITHUB_WORKFLOW_REF=gate.REPOSITORY+'/'+ios.ORIGIN+'@refs/heads/main')
        self.current_run=self.run_obj(self.current,False)
        result=ios.context(self.repo,event,github=self.client,refresh=False)
        self.assertEqual(result['source']['source_build'],'25')
        for defect in ('previous-source','rerun','old-controller','wrong-source','wrong-main'):
            policy=copy.deepcopy(self.policy);env=copy.deepcopy(event)
            if defect=='previous-source':policy['targets']['ios-upload']['previous_source']=self.source;env['RELEASE_POLICY']=gate.compact(policy)
            elif defect=='rerun':env['GITHUB_RUN_ATTEMPT']='2'
            elif defect=='old-controller':policy['control_floor']=self.source;env['CONTROLLER']=self.old;env['RELEASE_POLICY']=gate.compact(policy)
            elif defect=='wrong-source':env['SOURCE']=self.old
            else:env['GITHUB_REF']='refs/tags/release-v1.4.0'
            with self.subTest(defect=defect),self.assertRaises(gate.Rejected):ios.context(self.repo,env,github=self.client,refresh=False)

    def test_narrow_guard_removal_controls_discriminate(self):
        import types
        source=Path(ios.__file__).read_text()
        observations=[]
        controls=[("receipt['event'] == 'workflow_dispatch' and receipt['binding'] == b", "receipt['event'] == 'workflow_dispatch'",'binding'),
                  ("actual == receipt['binary'] and ","",'hash')]
        for before,after,defect in controls:
            self.assertEqual(source.count(before),1)
            mutant=types.ModuleType('ios_mutant');exec(compile(source.replace(before,after),ios.__file__,'exec'),mutant.__dict__)
            old=copy.deepcopy(self.receipt)
            if defect=='binding':self.receipt['binding']=dict(self.b,attempt='2')
            else:self.receipt['binary']['sha256']='0'*64
            self.rebuild_artifacts()
            with self.subTest(defect=defect):
                with self.assertRaises(gate.Rejected):self.origin()
                with self.assertRaises(AssertionError):
                    with self.assertRaises(gate.Rejected):mutant.verify_origin(self.repo,self.event,self.policy,self.current,self.client,now=lambda:NOW)
            observations.append({'guard':before,'original_source_sha256':gate.digest(source.encode()),'mutant_source_sha256':gate.digest(source.replace(before,after).encode()),'invalid_receipt_sha256':gate.digest(gate.compact(self.receipt).encode()),'original':'REJECT','mutant':'ACCEPT','negative_assertion':'FAILED AS EXPECTED / caught by control'})
            self.receipt=old;self.rebuild_artifacts()
        if os.environ.get('CONTROL_REPORT'):
            Path(os.environ['CONTROL_REPORT']).write_text(gate.compact(observations)+'\n')


class IOSLifecycleTests(unittest.TestCase):
    def test_action_lifecycle_cleans_owned_material_after_healthy_and_failed_build(self):
        fixture=IOSArtifactTests(methodName='test_exact_origin_pagination_and_digest_binding');fixture.setUp()
        try:
            ctx={'authorization':{'target':'ios-upload'},'verification_only':False,'binding':fixture.b,'source':fixture.receipt['source'],'toolchain':TOOL}
            uuid='00000000-0000-0000-0000-000000000001'
            profile={'UUID':uuid,'ExpirationDate':datetime(2099,1,1),'Entitlements':{'application-identifier':'ABCDE12345.com.example.app','com.apple.developer.team-identifier':'ABCDE12345','get-task-allow':False}}
            project=fixture.repo/'mobile/ios/Runner.xcodeproj/project.pbxproj';original=project.read_bytes()
            # This is the same tiny synthetic Git fixture; no application copy.
            env=dict(fixture.env,CONTROL_REPO=str(fixture.repo),BUILD_NUMBER='25',BUILD_NAME='1.4.0',BUNDLE_ID='com.example.app',TEAM_ID='ABCDE12345',CERTIFICATE_BASE64=base64.b64encode(b'INERT_CERT').decode(),PROFILE_BASE64=base64.b64encode(b'INERT_PROFILE').decode(),P12_PASSWORD='INERT_PASSWORD',RUNNER_TEMP=str(fixture.root))
            for outcome in ('healthy','build-failure','missing-ipa','multiple-ipa','metadata-mismatch','profile-collision','verify-only'):
                calls=[];profiles=fixture.root/'profiles';profiles.mkdir(exist_ok=True)
                out=fixture.repo/'mobile/build/ios/ipa'
                if out.exists():
                    for p in out.iterdir():p.unlink()
                if outcome=='profile-collision':(profiles/(uuid+'.mobileprovision')).write_text('PREEXISTING')
                def runner(args,cwd=None,env=None):
                    calls.append(args)
                    self.assertNotIn('INERT_CERT',str(args))
                    if args==['xcodebuild','-version']:return TOOL['xcode'].encode()
                    if args[:2]==['xcrun','--sdk']:return b'26.0'
                    if args==['pod','--version']:return b'1.16.2'
                    if args==['flutter','--version','--machine']:return b'{"frameworkVersion":"3.41.5"}'
                    if args[:3]==['security','cms','-D']:return plistlib.dumps(profile)
                    if args==['security','list-keychains','-d','user']:return b'"/synthetic/original.keychain-db"'
                    if args[:3]==['flutter','build','ipa']:
                        if outcome=='build-failure':raise gate.Rejected('synthetic tool failed')
                        out.mkdir(parents=True,exist_ok=True)
                        if outcome!='missing-ipa':(out/'one.ipa').write_bytes(ipa(CFBundleVersion='24') if outcome=='metadata-mismatch' else ipa())
                        if outcome=='multiple-ipa':(out/'two.ipa').write_bytes(ipa())
                    return b''
                selected=dict(ctx,verification_only=outcome=='verify-only');runenv=dict(env,IPA_DIR=str(fixture.root/('result-'+outcome)))
                with self.subTest(outcome=outcome),patch.object(gate,'assert_checkout'):
                    if outcome in ('healthy','verify-only'):ios_sign.sign(selected,fixture.repo,runenv,runner,profiles)
                    else:
                        with self.assertRaises(gate.Rejected):ios_sign.sign(selected,fixture.repo,runenv,runner,profiles)
                self.assertEqual(project.read_bytes(),original)
                self.assertFalse((fixture.repo/'mobile/ios/ExportOptions.plist').exists())
                self.assertFalse(list(fixture.root.glob('ios-sign-*')))
                if outcome=='profile-collision':
                    self.assertEqual((profiles/(uuid+'.mobileprovision')).read_text(),'PREEXISTING');(profiles/(uuid+'.mobileprovision')).unlink()
                else:self.assertEqual(list(profiles.iterdir()),[])
                if outcome=='verify-only':self.assertEqual(calls,[])
                elif outcome!='profile-collision':self.assertTrue(any(a[:2]==['security','delete-keychain'] for a in calls))
            configured=ios_sign.configure_runner(original,uuid).decode()
            self.assertEqual(configured.count('CODE_SIGN_STYLE = Manual;'),3)
            self.assertEqual(configured.count('CODE_SIGN_STYLE = Automatic;'),1) # RunnerTests remains untouched.
            # Timeout/error cleanup kills and joins the owned command group,
            # rather than leaving a child signer running after its parent exits.
            process=unittest.mock.Mock(pid=123456,returncode=-9)
            process.wait.side_effect=[subprocess.TimeoutExpired('synthetic',2700),0]
            def killed_or_absent(pid, sig):
                if sig == 0: raise ProcessLookupError()
            with patch.object(ios_sign.subprocess,'Popen',return_value=process) as spawn,patch.object(ios_sign.os,'killpg',side_effect=killed_or_absent) as kill:
                with self.assertRaises(gate.Rejected):ios_sign.command(['SYNTHETIC-NEVER-EXECUTED'])
                self.assertTrue(spawn.call_args.kwargs['start_new_session'])
                kill.assert_any_call(123456,ios_sign.signal.SIGKILL)
                kill.assert_any_call(123456,0)
                self.assertEqual(process.wait.call_count,2)
        finally:
            fixture.doCleanups()



def validate_ios_graph(root, workflows=None):
    w = workflows or {p.name:yaml.safe_load(p.read_text()) for p in (root/'.github/workflows').glob('*.yml')}
    require=gate.require
    asc=['DELIVERY_ASC_KEY_ID','DELIVERY_ASC_ISSUER_ID','DELIVERY_ASC_API_KEY_P8']
    signing=['DELIVERY_BUILD_CERTIFICATE_BASE64','DELIVERY_P12_PASSWORD','DELIVERY_PROVISIONING_PROFILE_BASE64']
    for filename,callee,operation in [('testflight.yml','ios-origin.yml','origin'),('app-store-release.yml','ios-promote.yml','promote'),('update-release-notes.yml','ios-promote.yml','notes')]:
        wrapper=w[filename];call=wrapper['jobs']['deliver']
        require(call['uses']=='./.github/workflows/'+callee,'iOS callee bypass')
        require(call['permissions']=={'contents':'read','actions':'read'},'iOS token scope')
        require(call['if']=="${{ github.ref == 'refs/heads/main' && github.event_name == 'workflow_dispatch' && needs.required.result == 'success' }}",'iOS privilege event/gate bypass')
        require(set(call['needs'])=={'resolve','required'},'iOS gate edge')
        for k in ('source','controller','receipt'):
            require(call['with'][k]=='${{ needs.required.outputs.'+k+' }}','iOS binding dataflow')
        require(call['with']['verification_only']=='${{ inputs.verification_only }}','verification-only forwarding')
        if operation!='origin':
            require(call['with']['operation']==operation,'iOS operation override')
            for k in ('origin_run','origin_attempt','asc_build_id'):
                require(call['with'][k]=='${{ inputs.'+k+' }}' and wrapper['on']['workflow_dispatch']['inputs'][k]['required'] is True,'explicit origin identity required')
        secrets=asc+signing if operation=='origin' else asc
        require(call['secrets']=={k:'${{ secrets.'+k+' }}' for k in secrets},'iOS named caller secrets')
    for filename,jobname,target,secret_names in [('ios-origin.yml','origin','ios-upload',asc+signing),('ios-promote.yml','promote','ios-production',asc)]:
        reuse=w[filename];job=reuse['jobs'][jobname]
        require(set(reuse['on'])=={'workflow_call'} and set(reuse['jobs'])=={jobname},'alternate iOS writer')
        require(reuse['on']['workflow_call']['secrets']=={k:{'required':True} for k in secret_names},'required scoped iOS declarations')
        require(job['environment']==target and job['concurrency']=={'group':'ios-upload','cancel-in-progress':False},'iOS environment/serialization')
        require(job['if']=="${{ github.ref == 'refs/heads/main' && github.event_name == 'workflow_dispatch' }}",'iOS main-only job')
        require(job['permissions']=={'contents':'read','actions':'read'},'iOS job permissions')
        e=job['env']
        for key,value in {'CONTROLLER':'${{ inputs.controller }}','SOURCE':'${{ inputs.source }}','GATE_RECEIPT':'${{ inputs.receipt }}','RELEASE_POLICY':'${{ vars.RELEASE_POLICY }}','CONTROL_REPO':'control','VERIFY_ONLY':'${{ inputs.verification_only }}','GH_TOKEN':'${{ github.token }}'}.items():
            require(e[key]==value,'iOS current authority dataflow')
        require(job['steps'][0]['with']=={'ref':'${{ inputs.controller }}','path':'control','fetch-depth':0,'persist-credentials':False},'iOS C checkout')
    origin=w['ios-origin.yml']['jobs']['origin'];steps=origin['steps'];by_name={s.get('name'):s for s in steps}
    require(len(steps)==10,'alternate origin/ref writer')
    require(origin['name']=='Upload iOS origin' and origin['env']['DELIVERY_TARGET']=='ios-upload','origin job identity')
    require(steps[1]['with']=={'ref':'${{ inputs.source }}','path':'candidate','fetch-depth':0,'persist-credentials':False},'origin independent S')
    require(by_name['Fresh authority before toolchain or signing']['run']=='python3 control/ops/ci/ios_artifact.py context > /dev/null','origin pre-sign authority')
    require(steps[2] is by_name['Fresh authority before toolchain or signing'] and 'if' not in steps[2] and all(s['uses'].startswith('actions/checkout@') for s in steps[:2]),'authority after toolchain, signing or upload')
    require(by_name['Allocate exact next binary build']['run']=='ruby control/.github/scripts/asc_delivery.rb prepare','number owner')
    require(by_name['Build once and inspect exact IPA']['uses']=='./control/.github/actions/build-signed-ipa','C signed action')
    require(by_name['Upload once and require current processed exact build']['run']=='ruby control/.github/scripts/asc_delivery.rb upload','origin upload owner')
    require(by_name['Bind processed ASC identity to immutable IPA metadata']['run']=='python3 control/ops/ci/ios_artifact.py receipt','origin receipt owner')
    for name in ['Upload once and require current processed exact build','Bind processed ASC identity to immutable IPA metadata']:
        require(by_name[name]['env']['IPA_SHA256']=='${{ steps.ipa.outputs.ipa-sha256 }}','signed-action IPA hash continuity')
    for name in ['Build once and inspect exact IPA','Upload once and require current processed exact build','Immutable IPA evidence','Bind processed ASC identity to immutable IPA metadata','Immutable originating receipt']:
        require(by_name[name]['if']=='${{ !inputs.verification_only }}','verification-only origin writes')
    # GitHub provides no runner context at jobs.<job_id>.env: the three runner-owned
    # paths belong only to the steps that read them (BUG-1794258285).
    paths={'IPA_DIR':'${{ runner.temp }}/ios-ipa','RECEIPT_DIR':'${{ runner.temp }}/ios-origin-receipt','ASC_RECEIPT':'${{ runner.temp }}/ios-processed.json'}
    require(not set(paths)&set(origin['env']),'runner context in origin job env')
    readers={'Build once and inspect exact IPA':{'IPA_DIR'},'Upload once and require current processed exact build':{'ASC_RECEIPT'},'Bind processed ASC identity to immutable IPA metadata':{'ASC_RECEIPT','RECEIPT_DIR'}}
    for step in steps:
        bound={k:v for k,v in step.get('env',{}).items() if k in paths}
        require(bound=={k:paths[k] for k in readers.get(step.get('name'),())},'origin evidence path binding')
    for kind,name,path in [('ipa','Immutable IPA evidence',paths['IPA_DIR']+'/candidate.ipa'),('origin','Immutable originating receipt',paths['RECEIPT_DIR']+'/receipt.json')]:
        upload=by_name[name]
        require(upload['with']['name']=='ios-'+kind+'-${{ inputs.source }}-${{ github.run_id }}-${{ github.run_attempt }}' and upload['with']['path']==path and upload['with']['overwrite'] is False and upload['with']['if-no-files-found']=='error','immutable exact artifact selection')
    promo=w['ios-promote.yml']['jobs']['promote']
    require(promo['env']['DELIVERY_TARGET']=="${{ inputs.operation == 'promote' && 'ios-production' || 'ios-notes' }}",'promotion target binding')
    require(len(promo['steps'])==3,'promotion alternate transport')
    for step,operation in zip(promo['steps'][1:],('promote','notes')):
        require(step['if']=="${{ inputs.operation == '"+operation+"' }}" and step['run']=='ruby control/.github/scripts/asc_delivery.rb '+operation,'exact promotion/notes entry')
        require(step['env']['ALLOW_CANCEL']=='${{ inputs.allow_cancel }}' and step['env']['RESUBMIT']=='${{ inputs.resubmit }}','cancellation/resubmit forwarding')
        require(step['env']['DELIVERY_ASC_API_KEY_P8']=='${{ secrets.DELIVERY_ASC_API_KEY_P8 }}','ASC secret use')
    require(w['ios-promote.yml']['on']['workflow_call']['inputs']['allow_cancel']=={'type':'boolean','default':False},'reusable cancellation consent')
    action=yaml.safe_load((root/'.github/actions/build-signed-ipa/action.yml').read_text())
    require(action['runs']['steps'][0]['run']=='python3 control/ops/ci/ios_sign.py','signed lifecycle owner')
    expected={'BUILD_NUMBER':'${{ inputs.build-number }}','BUILD_NAME':'${{ inputs.build-name }}','CERTIFICATE_BASE64':'${{ inputs.certificate-base64 }}','P12_PASSWORD':'${{ inputs.p12-password }}','PROFILE_BASE64':'${{ inputs.provisioning-profile-base64 }}','TEAM_ID':'${{ inputs.team-id }}','BUNDLE_ID':'${{ inputs.bundle-id }}'}
    require(action['runs']['steps'][0]['env']==expected,'safe signed input dataflow')


class IOSGraphTests(unittest.TestCase):
    def test_actual_workflow_boundary_mutations(self):
        validate_ios_graph(ROOT)
        original={p.name:yaml.safe_load(p.read_text()) for p in (ROOT/'.github/workflows').glob('*.yml')}
        for defect in ('main','gate','source','controller','receipt','attempt','origin-run','target','missing-secret','inherit','optional-secret','signing-to-promotion','environment','cancel','cancel-forward','policy','fresh-main','candidate-action','upload','receipt-owner','upload-hash','receipt-hash','artifact-name','artifact-path','artifact-overwrite','verification-build','verification-upload','verification-receipt','job-env-path','build-path','upload-path','receipt-path','stray-path','authority-order','authority-skip'):
            w=copy.deepcopy(original);origin=w['ios-origin.yml']['jobs']['origin'];promo=w['ios-promote.yml']['jobs']['promote'];call=w['app-store-release.yml']['jobs']['deliver'];steps=origin['steps'];names={s.get('name'):s for s in steps}
            if defect=='main':promo['if']='true'
            elif defect=='gate':call['needs'].remove('required')
            elif defect in ('source','controller','receipt'):call['with'][defect]='untrusted'
            elif defect=='attempt':call['with']['origin_attempt']='latest'
            elif defect=='origin-run':del call['with']['origin_run']
            elif defect=='target':promo['env']['DELIVERY_TARGET']='ios-upload'
            elif defect=='missing-secret':del call['secrets']['DELIVERY_ASC_KEY_ID']
            elif defect=='inherit':call['secrets']='inherit'
            elif defect=='optional-secret':w['ios-promote.yml']['on']['workflow_call']['secrets']['DELIVERY_ASC_API_KEY_P8']['required']=False
            elif defect=='signing-to-promotion':w['ios-promote.yml']['on']['workflow_call']['secrets']['DELIVERY_P12_PASSWORD']={'required':True}
            elif defect=='environment':promo['environment']='ios-upload'
            elif defect=='cancel':w['ios-promote.yml']['on']['workflow_call']['inputs']['allow_cancel']['default']=True
            elif defect=='cancel-forward':promo['steps'][2]['env']['ALLOW_CANCEL']='true'
            elif defect=='policy':promo['env']['RELEASE_POLICY']='${{ inputs.policy }}'
            elif defect=='fresh-main':names['Fresh authority before toolchain or signing']['run']='echo authorized'
            elif defect=='candidate-action':names['Build once and inspect exact IPA']['uses']='./candidate/.github/actions/build-signed-ipa'
            elif defect=='upload':names['Upload once and require current processed exact build']['run']='xcrun altool --upload-app'
            elif defect=='receipt-owner':names['Bind processed ASC identity to immutable IPA metadata']['run']='cp arbitrary.json receipt.json'
            elif defect=='upload-hash':del names['Upload once and require current processed exact build']['env']['IPA_SHA256']
            elif defect=='receipt-hash':names['Bind processed ASC identity to immutable IPA metadata']['env']['IPA_SHA256']='untrusted'
            elif defect.startswith('artifact-'):
                key=defect.split('-')[1];names['Immutable IPA evidence']['with'][key]='latest' if key!='overwrite' else True
            elif defect=='job-env-path':origin['env']['IPA_DIR']='${{ runner.temp }}/ios-ipa'
            elif defect=='build-path':del names['Build once and inspect exact IPA']['env']
            elif defect=='upload-path':names['Upload once and require current processed exact build']['env']['ASC_RECEIPT']='${{ github.workspace }}/ios-processed.json'
            elif defect=='receipt-path':del names['Bind processed ASC identity to immutable IPA metadata']['env']['RECEIPT_DIR']
            elif defect=='authority-order':steps[2],steps[3]=steps[3],steps[2]
            elif defect=='authority-skip':names['Fresh authority before toolchain or signing']['if']='${{ !inputs.verification_only }}'
            elif defect=='stray-path':names['Allocate exact next binary build']['env']['ASC_RECEIPT']='${{ runner.temp }}/ios-processed.json'
            else:
                name={'verification-build':'Build once and inspect exact IPA','verification-upload':'Upload once and require current processed exact build','verification-receipt':'Immutable originating receipt'}[defect]
                del names[name]['if']
            with self.subTest(defect=defect),self.assertRaises((gate.Rejected,KeyError)):validate_ios_graph(ROOT,w)

    def test_tag_retirement_rejects_ref_writes_and_preserves_checks_only_tags(self):
        original={p.name:yaml.safe_load(p.read_text()) for p in (ROOT/'.github/workflows').glob('*.yml')}
        validate_ios_graph(ROOT,original)
        self.assertEqual(original['app-store-release.yml']['on']['push']['tags'],['release-v*'])
        self.assertIn("github.event_name == 'workflow_dispatch'",original['app-store-release.yml']['jobs']['deliver']['if'])
        for defect in ('origin-write-token','caller-write-token','extra-origin-tag-step','extra-promotion-tag-step','inline-ref-write'):
            w=copy.deepcopy(original)
            if defect=='origin-write-token':w['ios-origin.yml']['jobs']['origin']['permissions']['contents']='write'
            elif defect=='caller-write-token':w['testflight.yml']['jobs']['deliver']['permissions']['contents']='write'
            elif defect=='extra-origin-tag-step':w['ios-origin.yml']['jobs']['origin']['steps'].append({'run':'git push origin refs/tags/example'})
            elif defect=='extra-promotion-tag-step':w['ios-promote.yml']['jobs']['promote']['steps'].append({'run':'git tag example'})
            else:w['ios-promote.yml']['jobs']['promote']['steps'][1]['run']+='; gh api git/refs --method POST'
            with self.subTest(defect=defect),self.assertRaises((gate.Rejected,KeyError)):validate_ios_graph(ROOT,w)

class IOSFailureBoundaryTests(unittest.TestCase):
    def fixture(self):
        f = IOSArtifactTests(methodName='test_exact_origin_pagination_and_digest_binding')
        f.setUp()
        self.addCleanup(f.doCleanups)
        return f

    def signing(self, fixture, outcome=None):
        ctx = {'authorization': {'target': 'ios-upload'}, 'verification_only': False,
               'binding': fixture.b, 'source': fixture.receipt['source'], 'toolchain': TOOL}
        profile = {'UUID': '00000000-0000-0000-0000-000000000001',
                   'ExpirationDate': datetime(2099, 1, 1), 'Entitlements': {
                       'application-identifier': 'ABCDE12345.com.example.app',
                       'com.apple.developer.team-identifier': 'ABCDE12345', 'get-task-allow': False}}
        env = dict(fixture.env, CONTROL_REPO=str(fixture.repo), BUILD_NUMBER='25',
                   BUILD_NAME='1.4.0', BUNDLE_ID='com.example.app', TEAM_ID='ABCDE12345',
                   CERTIFICATE_BASE64=base64.b64encode(b'INERT_CERT').decode(),
                   PROFILE_BASE64=base64.b64encode(b'INERT_PROFILE').decode(),
                   P12_PASSWORD='INERT_PASSWORD', RUNNER_TEMP=str(fixture.root),
                   IPA_DIR=str(fixture.root/'signed-output'))
        calls = []
        def runner(args, cwd=None, env=None):
            calls.append(args)
            if args == ['xcodebuild', '-version']: return TOOL['xcode'].encode()
            if args[:2] == ['xcrun', '--sdk']: return b'26.0'
            if args == ['pod', '--version']: return b'1.16.2'
            if args == ['flutter', '--version', '--machine']: return b'{"frameworkVersion":"3.41.5"}'
            if args[:3] == ['security', 'cms', '-D']: return plistlib.dumps(profile)
            if args == ['security', 'list-keychains', '-d', 'user']: return b'"/synthetic/original.keychain-db"'
            if args[:3] == ['flutter', 'build', 'ipa']:
                path = fixture.repo/'mobile/build/ios/ipa/one.ipa'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(ipa())
            if outcome == 'search-list' and args == ['security','list-keychains','-d','user','-s','/synthetic/original.keychain-db']:
                raise gate.Rejected('synthetic restore failure')
            return b''
        return ctx, env, calls, runner, fixture.root/'profiles'

    def test_owned_group_is_closed_after_parent_success_and_failure(self):
        child_program = "import json,os,sys,time;open(sys.argv[1],'w').write(json.dumps({'pid':os.getpid(),'pgid':os.getpgrp()}));time.sleep(30)"
        parent_program = "import subprocess,sys,time,pathlib;subprocess.Popen([sys.executable,'-c',sys.argv[3],sys.argv[1]]);deadline=time.monotonic()+3\nwhile not pathlib.Path(sys.argv[1]).exists():\n if time.monotonic()>deadline:raise RuntimeError('child marker missing')\n time.sleep(.01)\nsys.exit(int(sys.argv[2]))"
        with tempfile.TemporaryDirectory(prefix='owned-command-proof-') as temp:
            for code in (0, 1):
                marker = Path(temp)/f'process-{code}.json'
                group = None
                try:
                    args = [sys.executable, '-c', parent_program, str(marker), str(code), child_program]
                    with self.subTest(parent_exit=code):
                        if code:
                            with self.assertRaises(gate.Rejected): ios_sign.command(args)
                        else:
                            self.assertEqual(ios_sign.command(args), b'')
                        self.assertTrue(marker.is_file(), 'actual child must run before parent exits')
                        group = json.loads(marker.read_text())
                        try:
                            os.kill(group['pid'], 0)
                            alive = True
                        except ProcessLookupError:
                            alive = False
                        self.assertFalse(alive, 'owned descendant survives returned command')
                finally:
                    if marker.exists():
                        group = json.loads(marker.read_text())
                        try: os.killpg(group['pgid'], signal.SIGKILL)
                        except ProcessLookupError: pass
                        deadline = time.monotonic() + 5
                        while True:
                            try: os.killpg(group['pgid'], 0)
                            except ProcessLookupError: break
                            self.assertLess(time.monotonic(), deadline, 'fixture group cleanup did not finish')
                            time.sleep(.01)
                        if os.environ.get('CASE_REPORT'):
                            record = dict(group, parent_exit=code, group_absent_after_cleanup=True)
                            with Path(os.environ['CASE_REPORT']).with_name('ios-owned-python-processes.jsonl').open('a') as log:
                                log.write(json.dumps(record) + '\n')

    def test_early_restore_faults_do_not_skip_independent_private_cleanup(self):
        actual_write = Path.write_bytes
        actual_unlink = Path.unlink
        for fault in ('first-project-write', 'project-restore', 'project-restore-interrupt', 'primary-and-restore', 'export-unlink', 'profile-unlink', 'search-list'):
            f = self.fixture()
            ctx, env, calls, runner, profiles = self.signing(f, fault)
            project = f.repo/'mobile/ios/Runner.xcodeproj/project.pbxproj'
            original = project.read_bytes()
            export = f.repo/'mobile/ios/ExportOptions.plist'
            actual_runner = runner
            if fault == 'primary-and-restore':
                def runner(args, cwd=None, env=None):
                    if args[:3] == ['flutter','build','ipa']:
                        raise gate.Rejected('synthetic primary build failure')
                    return actual_runner(args, cwd=cwd, env=env)
            def write(path, data):
                if path == project and fault == 'project-restore-interrupt' and data == original:
                    raise KeyboardInterrupt()
                if path == project and (fault == 'first-project-write' or fault in ('project-restore','primary-and-restore') and data == original):
                    raise PermissionError('synthetic project fault')
                return actual_write(path, data)
            def unlink(path, *args, **kwargs):
                if fault == 'export-unlink' and path == export or fault == 'profile-unlink' and path.parent == profiles:
                    raise PermissionError('synthetic unlink fault')
                return actual_unlink(path, *args, **kwargs)
            with self.subTest(fault=fault):
                with patch.object(gate, 'assert_checkout'), patch.object(Path, 'write_bytes', write), patch.object(Path, 'unlink', unlink):
                    with self.assertRaises(gate.Rejected) as caught:
                        ios_sign.sign(ctx, f.repo, env, runner, profiles)
                self.assertIn('signing cleanup failed:', str(caught.exception))
                if fault == 'primary-and-restore':
                    self.assertIsInstance(caught.exception.__cause__, gate.Rejected)
                    self.assertEqual(str(caught.exception.__cause__), 'synthetic primary build failure')
                self.assertTrue(any(a[:2] == ['security','delete-keychain'] for a in calls), 'later keychain cleanup skipped')
                self.assertTrue(any(a == ['security','list-keychains','-d','user','-s','/synthetic/original.keychain-db'] for a in calls), 'search-list restoration skipped')
                if fault != 'profile-unlink': self.assertEqual(list(profiles.iterdir()), [])
                self.assertFalse(list(f.root.glob('ios-sign-*')))

    def test_signed_copy_keeps_exact_bytes_inspected_before_output_mutation(self):
        f = self.fixture()
        ctx, env, calls, runner, profiles = self.signing(f)
        actual_inspect = ios.inspect_ipa
        original = ipa()
        def inspect(raw, expected):
            result = actual_inspect(raw, expected)
            # Same bundle/version/build metadata, different actual binary bytes.
            (f.repo/'mobile/build/ios/ipa/one.ipa').write_bytes(
                zipdata({'Payload/Runner.app/Info.plist': plistlib.dumps({
                    'CFBundleIdentifier':'com.example.app','CFBundleShortVersionString':'1.4.0',
                    'CFBundleVersion':'25','CFBundleSupportedPlatforms':['iPhoneOS'],'DTPlatformName':'iphoneos'}),
                    'Payload/Runner.app/Runner': b'SYNTHETIC-REPLACEMENT'}))
            return result
        with patch.object(gate, 'assert_checkout'), patch.object(ios, 'inspect_ipa', inspect):
            binary = ios_sign.sign(ctx, f.repo, env, runner, profiles)
        copied = (Path(env['IPA_DIR'])/'candidate.ipa').read_bytes()
        self.assertEqual(binary['sha256'], gate.digest(original))
        self.assertEqual(gate.digest(copied), binary['sha256'], 'copied IPA differs from inspected input bytes')

    def test_origin_receipt_rejects_upload_to_artifact_binary_substitution(self):
        f = self.fixture()
        original = ipa()
        binary = ios.inspect_ipa(original, {})
        changed = zipdata({'Payload/Runner.app/Info.plist': plistlib.dumps({
            'CFBundleIdentifier':'com.example.app','CFBundleShortVersionString':'1.4.0',
            'CFBundleVersion':'25','CFBundleSupportedPlatforms':['iPhoneOS'],'DTPlatformName':'iphoneos'}),
            'Payload/Runner.app/Runner': b'SYNTHETIC-REPLACEMENT'})
        ctx = {'binding': f.b, 'source': f.receipt['source'], 'gate': f.receipt['gate'], 'app_id':'app-1','toolchain':TOOL}
        for fault in ('healthy', 'replaced', 'missing-upload-hash', 'wrong-upload-hash', 'wrong-action-hash'):
            path = f.root/f'{fault}.ipa'
            path.write_bytes(changed if fault == 'replaced' else original)
            asc = dict(f.receipt['asc'], upload_ipa_sha256=binary['sha256'])
            if fault == 'missing-upload-hash': asc.pop('upload_ipa_sha256')
            if fault == 'wrong-upload-hash': asc['upload_ipa_sha256'] = '0'*64
            receipt_path = f.root/f'{fault}-processed.json'
            receipt_path.write_text(gate.compact(asc))
            env = {'DELIVERY_TARGET':'ios-upload','IPA_PATH':str(path),'BUILD_NUMBER':'25',
                   'IPA_SHA256':'0'*64 if fault == 'wrong-action-hash' else binary['sha256'],
                   'ASC_RECEIPT':str(receipt_path),'IPA_ARTIFACT_ID':'11','IPA_ARTIFACT_DIGEST':'d'*64,
                   'RECEIPT_DIR':str(f.root/(fault+'-receipt'))}
            with self.subTest(fault=fault), patch.dict(os.environ, env), patch.object(ios,'context',return_value=ctx), patch.object(sys,'argv',['ios_artifact.py','receipt']):
                if fault == 'healthy':
                    ios.main()
                    result = gate.parse((Path(env['RECEIPT_DIR'])/'receipt.json').read_bytes())
                    self.assertEqual(result['binary']['sha256'], binary['sha256'])
                else:
                    with self.assertRaises(gate.Rejected): ios.main()


if __name__ == '__main__':
    with patch('socket.socket.connect', side_effect=AssertionError('network forbidden in iOS fixture')):
        unittest.main(verbosity=2)
