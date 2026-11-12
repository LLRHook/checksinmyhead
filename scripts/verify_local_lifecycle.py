#!/usr/bin/env python3
"""Real PostgreSQL down/restart/reset proof, restricted to a new labelled local fixture.

Requires an already-installed immutable PostgreSQL image ID; never pulls or starts
app/simulator services. Raw commands/output and cleanup proof stay in --output.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
OWNER_LABEL = 'io.billington.test-owner'
DATA_LABEL = 'io.billington.test-data'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres-image', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'sha256:[a-f0-9]{64}', args.postgres_image):
        parser.error('use a local immutable image ID (sha256:<64 hex>), never a tag')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    docker = shutil.which('docker')
    project = 'billington-test-local-' + uuid.uuid4().hex[:12]
    owner = str(uuid.uuid4())
    volume = project + '_postgres_data'
    result = {'project': project, 'owner': owner, 'image': args.postgres_image, 'commands': [], 'assertions': {}}
    result['source_hashes'] = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in
                               ('backend/Makefile','backend/docker-compose.yml','dev.sh','scripts/reset_local_test.py')}

    def run(argv, *, env=None, check=True):
        completed = subprocess.run(argv, env=env, cwd=ROOT, capture_output=True, text=True, timeout=45)
        index = len(result['commands'])
        (output/f'{index:03d}.stdout').write_text(completed.stdout)
        (output/f'{index:03d}.stderr').write_text(completed.stderr)
        result['commands'].append({'argv': list(map(str,argv)), 'exit': completed.returncode})
        if check and completed.returncode:
            raise RuntimeError(f'fixture command {index} failed (exit {completed.returncode}); see retained output')
        return completed

    labels = {OWNER_LABEL: owner, DATA_LABEL: 'synthetic'}
    config = {'services': {'postgres': {
        'image': args.postgres_image, 'labels': labels,
        'environment': {'POSTGRES_USER': 'billington_test', 'POSTGRES_DB': 'billington_test', 'POSTGRES_PASSWORD': 'synthetic-local-only'},
        'volumes': ['postgres_data:/var/lib/postgresql/data'],
        'healthcheck': {'test': ['CMD-SHELL', 'pg_isready -U billington_test -d billington_test'], 'interval': '1s', 'timeout': '2s', 'retries': 20},
    }}, 'volumes': {'postgres_data': {'labels': labels}}, 'networks': {'default': {'labels': labels}}}
    compose_file = output/'compose.json'
    compose_file.write_text(json.dumps(config, indent=2)+'\n')
    prefix = [docker, 'compose', '--project-name', project, '--file', str(compose_file)]

    def assert_owned():
        for kind, names, projection in (
            ('container', run(prefix+['ps','--all','--quiet']).stdout.split(), '{{json .Config.Labels}}'),
            ('volume', run([docker,'volume','ls','--quiet','--filter',f'label=com.docker.compose.project={project}']).stdout.split(), '{{json .Labels}}'),
            ('network', run([docker,'network','ls','--quiet','--filter',f'label=com.docker.compose.project={project}']).stdout.split(), '{{json .Labels}}'),
        ):
            for name in names:
                found=json.loads(run([docker,kind,'inspect','--format',projection,name]).stdout)
                assert found.get(OWNER_LABEL)==owner and found.get(DATA_LABEL)=='synthetic'
                assert found.get('com.docker.compose.project')==project

    def ready():
        run(prefix+['up','-d','postgres'])
        identifier=run(prefix+['ps','--quiet','postgres']).stdout.strip()
        deadline=time.monotonic()+30
        while time.monotonic()<deadline:
            health=run([docker,'inspect','--format','{{.State.Health.Status}}',identifier]).stdout.strip()
            if health=='healthy':
                assert_owned()
                return identifier
            if health=='unhealthy': break
            time.sleep(.25)
        raise RuntimeError('owned PostgreSQL readiness failed within 30s')

    def sql(identifier, statement):
        return run([docker,'exec',identifier,'psql','-U','billington_test','-d','billington_test','-At','-v','ON_ERROR_STOP=1','-c',statement]).stdout.strip()

    def reset(selected_project=project, selected_owner=owner, check=True):
        return run(['make','-C',str(ROOT/'backend'),'reset-test',f'TEST_PROJECT={selected_project}',f'TEST_OWNER={selected_owner}'],check=check)

    def absent():
        return (not run(prefix+['ps','--all','--quiet']).stdout.strip() and
                run([docker,'volume','inspect',volume],check=False).returncode != 0 and
                not run([docker,'network','ls','--quiet','--filter',f'label=com.docker.compose.project={project}']).stdout.strip())

    # Only the CLI adapter is substituted: execute the actual fixed make down.
    adapter = output/'bin'
    adapter.mkdir()
    wrapper=adapter/'docker'
    wrapper.write_text('#!'+sys.executable+'\nimport os,sys\n'
        'assert sys.argv[1:]==["compose","down"]\n'
        f'os.execv({docker!r}, {prefix!r}+sys.argv[2:])\n')
    wrapper.chmod(0o700)
    env=dict(os.environ,PATH=str(adapter)+os.pathsep+os.environ['PATH'])
    created=False
    try:
        assert run([docker,'volume','inspect',volume],check=False).returncode != 0
        # Quiet config validation: inspect only names, never resolved env values.
        synthetic=output/'stack.env'
        synthetic.write_text('DB_HOST=postgres\nDB_PORT=5432\nDB_USER=billington_test\nDB_NAME=billington_test\nDB_PASSWORD=synthetic-local-only\nANTHROPIC_API_KEY=\n')
        env_config={**os.environ,'DB_HOST':'postgres','DB_PORT':'5432','DB_USER':'billington_test','DB_NAME':'billington_test','DB_PASSWORD':'synthetic-local-only','ANTHROPIC_API_KEY':'','COMPOSE_PROFILES':''}
        actual=[docker,'compose','--env-file',str(synthetic),'-f',str(ROOT/'backend/docker-compose.yml')]
        run(actual+['config','--quiet'],env=env_config)
        assert set(run(actual+['config','--services'],env=env_config).stdout.split())=={'postgres','bill-service'}
        assert run(actual+['config','--volumes'],env=env_config).stdout.split()==['postgres_data']
        result['assertions']['default_service_names']=True
        created=True
        identifier=ready()
        sql(identifier,'CREATE TABLE workflow_sentinel (id integer PRIMARY KEY); INSERT INTO workflow_sentinel VALUES (1);')
        assert sql(identifier,'SELECT count(*) FROM workflow_sentinel')=='1'
        assert_owned()
        run(['make','-C',str(ROOT/'backend'),'down'],env=env)
        run([docker,'volume','inspect',volume])
        identifier=ready()
        assert sql(identifier,'SELECT count(*) FROM workflow_sentinel')=='1'
        result['assertions']['exact_make_down_restart_preserves_sentinel']=True
        for selected_project,selected_owner in (('backend',owner),(project,'wrong-owner-1234567890')):
            assert reset(selected_project,selected_owner,check=False).returncode != 0
            assert sql(identifier,'SELECT count(*) FROM workflow_sentinel')=='1'
        result['assertions']['normal_project_and_wrong_owner_rejected_with_sentinel_intact']=True
        # A second volume with the selected project but no synthetic-data label
        # must block the entire reset before removing any existing container/data.
        alien=project+'_unconfirmed'
        run([docker,'volume','create','--label',f'com.docker.compose.project={project}','--label',f'{OWNER_LABEL}={owner}',alien])
        try:
            assert reset(check=False).returncode != 0
            assert sql(identifier,'SELECT count(*) FROM workflow_sentinel')=='1'
            result['assertions']['unconfirmed_volume_rejects_before_any_deletion']=True
        finally:
            found=json.loads(run([docker,'volume','inspect','--format','{{json .Labels}}',alien]).stdout)
            assert found=={'com.docker.compose.project':project,OWNER_LABEL:owner}
            run([docker,'volume','rm',alien])
        assert_owned()
        reset()
        assert absent()
        identifier=ready()
        assert sql(identifier,"SELECT COALESCE(to_regclass('workflow_sentinel')::text,'ABSENT')")=='ABSENT'
        result['assertions']['owned_explicit_reset_removes_data']=True
    finally:
        if created:
            assert_owned()
            if run([docker,'volume','inspect',volume],check=False).returncode == 0:
                reset()
        result['cleanup_complete']=absent()
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    assert result['cleanup_complete']
    print(json.dumps({'assertions':result['assertions'],'cleanup_complete':result['cleanup_complete'],'output':str(output)},indent=2))


if __name__ == '__main__':
    main()
