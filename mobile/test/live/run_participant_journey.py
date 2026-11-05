#!/usr/bin/env python3
"""One strict owned-schema matched-client journey. No server source/normal DB writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[3]
DSN = 'host=127.0.0.1 port=51168 user=billington_test dbname=billington_test sslmode=disable'

def run(command, cwd, env, output, timeout=180):
    with output.open('w') as log:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'{command[0]} failed ({result.returncode}); see {output}')

def source_bindings():
    paths=[]
    for folder,patterns in [('backend',['*.go','*.sql']),('mobile/lib',['*.dart']),('mobile/test/live',['*.dart','*.go','*.py']),('web-bill-viewer/src',['*.ts','*.tsx']),('web-bill-viewer/scripts',['*.cjs'])]:
        for pattern in patterns:
            paths.extend((ROOT/folder).rglob(pattern))
    paths.extend(ROOT/path for path in ['backend/go.mod','backend/go.sum','mobile/pubspec.yaml','mobile/pubspec.lock','web-bill-viewer/package.json','web-bill-viewer/package-lock.json','web-bill-viewer/.node-version'])
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(paths))}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--run', action='store_true');args=parser.parse_args()
    if os.environ.get('BILLINGTON_TEST_POSTGRES_DSN') != DSN:
        raise SystemExit('Exact reviewed loopback51168 test-only DSN required; no inherited schema/options')
    env=os.environ.copy()
    for key in list(env):
        if key.startswith('PG') or key.startswith('DB_') or key in ('DATABASE_URL','DATABASE_DSN'):
            del env[key]
    env['BILLINGTON_TEST_POSTGRES_DSN']=DSN
    node=subprocess.check_output(['node','--version'],env=env,text=True).strip()
    if not node.startswith('v24.'):
        raise SystemExit('Use the existing locked Node24 executable in PATH')
    output=ROOT/'.vv'/'cd-identity'/f'http-{uuid.uuid4().hex}'
    output.mkdir(parents=True)
    env['BILLINGTON_CD_RUN']=str(output);env['BILLINGTON_CD_WORKSPACE']=str(ROOT)
    bindings=source_bindings()
    receipt={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
             'branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
             'status':subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True),
             'sha256':bindings}
    (output/'source-bindings.json').write_text(json.dumps(receipt,indent=2))
    destination=ROOT/'backend'/'cmd'/'bill-service'/'cd_matched_fixture_test.go'
    overlay=output/'overlay.json';overlay.write_text(json.dumps({'Replace':{str(destination):str(Path(__file__).with_name('participant_http_fixture_test.go'))}}))
    psql=shutil.which('psql')
    if psql is None:
        candidate=Path('/opt/homebrew/opt/libpq/bin/psql')
        if candidate.exists():psql=str(candidate)
    if not psql:raise SystemExit('Existing psql required for independent fixture identity/cleanup')
    identity=subprocess.check_output([psql,'-w',DSN,'-Atc',"SELECT current_user,current_database(),version()"],env=env,text=True)
    if not identity.startswith('billington_test|billington_test|PostgreSQL 17.11 '):
        raise SystemExit('Unexpected PostgreSQL runtime identity')
    (output/'postgres-runtime.txt').write_text(identity)
    run([str(ROOT/'web-bill-viewer/node_modules/.bin/tsc'),'src/lib/api.ts','src/lib/currency.ts','--module','commonjs','--target','es2022','--esModuleInterop','--skipLibCheck','--outDir',str(output/'web-api')],ROOT/'web-bill-viewer',env,output/'web-compile.log')
    binary=output/'fixture.test'
    run(['go','test','-race','-tags=integration','-overlay',str(overlay),'-c','-o',str(binary),'./cmd/bill-service'],ROOT/'backend',env,output/'go-compile.log')
    listed=subprocess.check_output([str(binary),'-test.list','^TestCDMatchedClientHTTPFixture$'],env=env,text=True)
    (output/'go-list.txt').write_text(listed)
    if listed.strip()!='TestCDMatchedClientHTTPFixture':raise SystemExit('Unexpected fixture selection')
    print(output,flush=True)
    if not args.run:return
    try:
        run(['go','test','-race','-count=1','-json','-tags=integration','-overlay',str(overlay),'./cmd/bill-service','-run','^TestCDMatchedClientHTTPFixture$','-timeout','5m'],ROOT/'backend',env,output/'go-http.jsonl',330)
    finally:
        (output/'source-after.json').write_text(json.dumps({'unchanged':bindings==source_bindings()},indent=2))
        # Independently inspect only the exact recorded owned identity, after Go
        # and supervised client groups settle. Never kill a PG session by prefix.
        scope=output/'owned-postgres.json'
        if scope.exists():
            schema=json.loads(scope.read_text())['schema']
            if not re.fullmatch(r'billington_test_[a-f0-9]{24}',schema):raise RuntimeError('Unsafe cleanup identity')
            sessions=subprocess.check_output([psql,'-w',DSN,'-Atc',f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{schema}'"],env=env,text=True).strip()
            if sessions!='0':raise RuntimeError(f'Owned sessions remain for exact {schema}; cleanup blocked')
            remaining=subprocess.check_output([psql,'-w',DSN,'-Atc',f"SELECT count(*) FROM pg_namespace WHERE nspname='{schema}'"],env=env,text=True).strip()
            if remaining=='1':
                subprocess.run([psql,'-w',DSN,'-v','ON_ERROR_STOP=1','-c',f'DROP SCHEMA "{schema}" CASCADE'],env=env,check=True,stdout=subprocess.DEVNULL)
            (output/'cleanup.json').write_text(json.dumps({'schema':schema,'owned_sessions':0,'schema_remaining':0,'fallback_drop':remaining=='1'},indent=2))
if __name__=='__main__':main()
