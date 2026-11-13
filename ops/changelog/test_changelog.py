"""Offline synthetic API and lifecycle proof; the test process forbids sockets."""
import copy
from datetime import timedelta
import io
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch, mock_open
import urllib.error

sys.path.insert(0, str(Path(__file__).parent))
import changelog as bot

NOW = bot.date('2026-11-12T12:00:00+00:00')
BODY = bot.START + '\n**What changed:** Friends can see each proposed app change.\n**Why:** Everyone gets time to object before it goes live.\n' + bot.END
HEAD = 'a' * 40
BASE = 'b' * 40


def pull():
    return {'number': 25, 'node_id': 'synthetic-PR', 'title': 'Show proposed changes', 'body': BODY,
            'user': {'login': 'LLRHook'}, 'head': {'sha': HEAD, 'repo': {'full_name': bot.REPO}},
            'base': {'sha': BASE, 'repo': {'full_name': bot.REPO}, 'ref': 'main'},
            'draft': False, 'state': 'open', 'merged': False, 'mergeable': True, 'mergeable_state': 'clean',
            'created_at': bot.stamp(NOW), 'updated_at': bot.stamp(NOW), 'closed_at': None, 'changed_files': 1, 'commits': 1, 'merge_commit_sha': 'd' * 40, 'merged_by': None}


class FakeGitHub:
    def __init__(self):
        self.data = pull()
        self.paths = ['app.py']
        self.fingerprint = 'f' * 64
        self.transitions = [{'event': 'ready_for_review', 'id': 1}]
        self.waiting_check = bot.REQUIRED_CHECK
        self.checks, self.mirrors, self.merges = [], [], []
        self.is_green, self.identity_ok = True, True
        self.before_fresh = None
        self.merge_api = object()
        self.reads = 0

    def pr(self, number):
        self.reads += 1
        if self.reads % 2 == 0 and self.before_fresh:
            self.before_fresh(self)
        return copy.deepcopy(self.data)

    def files(self, pr):
        return self.paths, True

    def change(self, pr):
        return self.fingerprint

    def timeline(self, number):
        return self.transitions

    def check(self, pr, error):
        self.checks.append(error)

    def prepare_check(self, pr):
        pass

    def hint(self, number):
        if not self.mirrors:
            return {}
        previous = self.mirrors[-1]
        return dict(previous[1], message=previous[2] if len(previous) > 2 else None, exists=True)

    def mirror(self, *args):
        self.mirrors.append(copy.deepcopy(args))

    def green(self, pr):
        return self.is_green

    def identity(self, pr):
        return self.identity_ok and pr['user']['login'] == 'LLRHook'

    def audit(self, pr):
        pass

    def merge(self, pr):
        self.merges.append(copy.deepcopy(pr))
        self.data.update(state='closed', merged=True, merged_by={'login': 'LLRHook'})
        return 'd' * 40


class FakeDiscord:
    def __init__(self):
        self.message, self.state = None, None
        self.users, self.created, self.edited, self.seeds = {}, 0, 0, []
        self.before_final = None
        self.holder_reads = 0
        self.thumbs = {}
        self.rate_limit = False
        self.now = NOW

    def find(self, pr, hint=None):
        return copy.deepcopy(self.message), copy.deepcopy(self.state)

    def holders(self, message):
        self.holder_reads += 1
        if self.before_final and self.holder_reads % 2 == 0:
            self.before_final(self)
        return self.users.copy()

    def fresh(self, pr, message):
        return copy.deepcopy(self.message)

    def record(self, message, number):
        return copy.deepcopy(self.state)

    def stops(self, message):
        return self.holders(message['id'])

    def has_approval_reactions(self, message):
        return bool(self.thumbs)

    def approvers(self, message):
        return self.thumbs.copy()

    def post(self, pr, state, text, message=None):
        if self.rate_limit:
            raise bot.Refused('API HTTP 429; retry on the next run')
        if message:
            self.edited += 1
        else:
            self.created += 1
        self.message = {'id': '500', 'channel_id': '123456', 'author': {'id': '1'}, 'timestamp': (self.message or {}).get('timestamp', bot.stamp(self.now)), 'content': '',
                        'embeds': [dict(bot.state_embed(pr['number'], state), title=bot.safe(pr['title']), description=text)]}
        self.state = copy.deepcopy(state)
        return copy.deepcopy(self.message)

    def seed(self, message):
        self.seeds.append(message)


def visible(message):
    return message['embeds'][0].get('description', '')


class ChangelogLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.gh, self.dc = FakeGitHub(), FakeDiscord()
        self.now = NOW

    def run_bot(self, mode='merge', dry_run=False):
        self.dc.now = self.now
        # Each reconciliation reads initial PR, then fresh PR only when due.
        self.gh.reads = 0
        return bot.reconcile(self.gh, self.dc, 25, mode, self.now, dry_run)

    def posted(self):
        self.run_bot()
        self.now += bot.WEEK

    def test_restart_is_explicit_while_held_and_phone_notice_fits(self):
        self.run_bot()
        self.gh.data['title'] = '🛑' * 300
        self.gh.data['body'] = BODY.replace('Friends', 'X' * 800)
        self.gh.fingerprint = 'e' * 64
        self.dc.users = {str(i): '🛑' * 60 for i in range(10, 30)}
        status = self.run_bot()
        self.assertIn('week starts again', status)
        self.assertIn('On hold:', status)
        self.assertLessEqual(len(visible(self.dc.message).encode('utf-16-le')) // 2, 2000)
        self.assertFalse(self.gh.merges)

    def test_whole_life_draft_ready_note_code_hold_release_merge(self):
        self.gh.data['draft'] = True
        self.assertEqual(self.run_bot(), 'draft')
        self.assertEqual(self.dc.created, 0)
        self.gh.data['draft'] = False
        self.run_bot()
        original = self.dc.state['start']
        self.now += timedelta(days=1)
        self.gh.data['body'] = BODY.replace('Friends', 'Our friends')
        self.run_bot()
        self.assertEqual(self.dc.state['start'], original)
        self.assertIn('Our friends', visible(self.dc.message))
        self.gh.fingerprint = 'e' * 64
        self.gh.data['head']['sha'] = 'c' * 40
        self.assertIn('week starts again', self.run_bot())
        restart = self.dc.state['start']
        self.dc.users = {'42': 'Alex', '43': 'Sam'}
        self.now += bot.WEEK
        self.assertIn('On hold:', self.run_bot())
        self.assertIn('Alex', visible(self.dc.message))
        self.assertNotIn('[42]', visible(self.dc.message))
        self.assertEqual(self.gh.merges, [])
        self.dc.users.clear()
        self.assertIn("It's in", self.run_bot())
        self.assertEqual(self.dc.state['start'], restart)
        self.assertEqual(len(self.gh.merges), 1)
        self.assertEqual(self.dc.created, 1)
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_seven_days_exact_boundary_without_approval(self):
        self.posted()
        self.now -= timedelta(seconds=1)
        self.run_bot()
        self.assertEqual(self.gh.reads, 1)
        self.assertFalse(self.gh.merges)
        self.now += timedelta(seconds=1)
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_main_update_without_own_change_preserves_clock(self):
        self.run_bot()
        start = self.dc.state['start']
        self.now += timedelta(days=2)
        self.gh.data['head']['sha'], self.gh.data['base']['sha'] = 'e' * 40, 'f' * 40
        self.run_bot()
        self.assertEqual(self.dc.state['start'], start)

    def test_back_to_draft_cancels_and_ready_starts_full_week(self):
        self.posted()
        self.gh.data['draft'] = True
        self.assertIn('wait is off', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.gh.data['draft'] = False
        self.gh.transitions.append({'event': 'ready_for_review', 'id': 2})
        self.assertIn('week starts again', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.now += bot.WEEK
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_missed_draft_and_ready_events_reset_from_timeline(self):
        self.posted()
        self.gh.transitions += [{'event': 'converted_to_draft', 'id': 2}, {'event': 'ready_for_review', 'id': 3}]
        self.assertIn('week starts again', self.run_bot())
        self.assertFalse(self.gh.merges)

    def test_closed_without_merging_updates_same_post(self):
        self.posted()
        self.gh.data['state'] = 'closed'
        self.assertEqual(self.run_bot(), 'closed')
        self.assertIn("Dropped: this change won't go live", visible(self.dc.message))
        self.assertFalse(self.gh.merges)
        self.assertEqual(self.dc.created, 1)

    def test_tracker_dependabot_fork_other_base_exempt_without_discord(self):
        for kind in ('tracker', 'dependabot', 'fork', 'deleted-fork', 'other-base'):
            with self.subTest(kind=kind):
                self.setUp()
                if kind == 'tracker': self.gh.paths = ['bugs.md', 'features.md', 'CHANGELOG.md']
                elif kind == 'dependabot': self.gh.data['user']['login'] = 'dependabot[bot]'
                elif kind == 'fork': self.gh.data['head']['repo']['full_name'] = 'stranger/fork'
                elif kind == 'deleted-fork': self.gh.data['head']['repo'] = None
                else: self.gh.data['base']['ref'] = 'feature'
                self.assertEqual(self.run_bot(), 'exempt')
                self.assertEqual(self.dc.created, 0)
                self.assertFalse(self.gh.merges)

    def test_missing_template_or_overlong_note_fails_check_no_post_or_merge(self):
        template = (Path(__file__).parents[2] / '.github/pull_request_template.md').read_text()
        for body in ('', template, BODY.replace('Friends', 'TODO'), BODY.replace('Friends', 'X' * 1100)):
            with self.subTest(body=body[:30]):
                self.setUp()
                self.gh.data['body'] = body
                self.assertEqual(self.run_bot(), 'missing-note')
                self.assertTrue(self.gh.checks[-1])
                self.assertEqual(self.dc.created, 0)
                self.assertFalse(self.gh.merges)

    def test_removing_note_after_post_blocks_existing_deadline(self):
        self.posted()
        self.gh.data['body'] = ''
        self.assertIn("Paused: the author needs to fix this change's description.", self.run_bot())
        self.assertFalse(self.gh.merges)
        self.assertEqual(self.dc.created, 1)

    def test_red_checks_and_merge_conflict_retry_after_deadline(self):
        self.posted()
        self.gh.is_green = False
        self.assertIn('automatic test', self.run_bot())
        self.gh.is_green = True
        self.gh.data['mergeable_state'] = 'dirty'
        self.assertIn('clashes with another change', self.run_bot())
        self.gh.data['mergeable_state'] = 'clean'
        self.gh.data['mergeable'] = None
        self.assertEqual(bot.GITHUB_WAIT, self.run_bot())
        self.gh.data['mergeable'] = True
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_unavailable_compare_leaves_clock_and_all_outputs_untouched(self):
        self.run_bot()
        before = copy.deepcopy((self.dc.state, self.dc.message, self.gh.checks, self.gh.mirrors))
        self.now += timedelta(days=6)
        with patch.object(self.gh, 'change', side_effect=bot.Refused('API HTTP 502')):
            with self.assertRaises(bot.Refused): self.run_bot()
        self.assertEqual((self.dc.state, self.dc.message, self.gh.checks, self.gh.mirrors), before)
        self.now += timedelta(days=1)
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_duplicate_event_and_recovery_after_comment_failure_do_not_repost(self):
        with patch.object(self.gh, 'mirror', side_effect=bot.Refused('synthetic crash')):
            with self.assertRaises(bot.Refused): self.run_bot()
        self.run_bot()
        self.run_bot()
        self.assertEqual(self.dc.created, 1)

    def test_recovered_nonce_cannot_backdate_a_new_change(self):
        original_post = self.dc.post
        def recovered(number, state, text, message=None):
            result = original_post(number, state, text, message)
            if message is None:
                self.dc.message['timestamp'] = bot.stamp(NOW - timedelta(days=2))
                result['timestamp'] = self.dc.message['timestamp']
            return result
        with patch.object(self.dc, 'post', recovered): self.run_bot()
        self.assertEqual(self.dc.state['start'], bot.stamp(NOW))
        self.assertFalse(self.gh.merges)

    def test_deleted_discord_post_cannot_discard_holds_or_repost(self):
        self.posted()
        self.dc.message = self.dc.state = None
        with self.assertRaisesRegex(bot.Refused, 'notice was deleted'): self.run_bot()
        self.assertEqual(self.dc.created, 1)
        self.assertFalse(self.gh.merges)

    def test_discord_rate_limit_never_merges_without_notice(self):
        self.dc.rate_limit = True
        with self.assertRaisesRegex(bot.Refused, '429'): self.run_bot()
        self.assertFalse(self.gh.merges)
        self.dc.rate_limit = False
        self.run_bot()
        self.assertEqual(self.dc.created, 1)

    def test_missing_identity_and_post_mode_wait_for_person(self):
        self.posted()
        self.assertIn('owner switches it on', self.run_bot(mode='post'))
        self.gh.identity_ok = False
        self.assertIn('owner switches it on', self.run_bot())
        self.assertFalse(self.gh.merges)
        with patch.object(self.gh, 'identity', side_effect=bot.Refused('expired credential')):
            with self.assertRaises(bot.Refused): self.run_bot()
        self.assertFalse(self.gh.merges)

    def test_off_switch_rejects_before_any_api(self):
        with patch.object(self.gh, 'pr', side_effect=AssertionError('must not read')):
            for mode in ('', 'off', 'typo'):
                with self.subTest(mode=mode), self.assertRaises(bot.Refused): self.run_bot(mode)

    def test_head_body_base_or_ready_race_cannot_merge(self):
        self.posted()
        for field in ('head', 'body', 'base', 'ready', 'draft', 'closed', 'fork'):
            def change(gh):
                if field in ('head', 'base'): gh.data[field]['sha'] = 'e' * 40
                elif field == 'body': gh.data['body'] += '\nEdited'
                elif field == 'ready': gh.transitions.append({'event': 'ready_for_review', 'id': 3})
                elif field == 'draft': gh.data['draft'] = True
                elif field == 'closed': gh.data['state'] = 'closed'
                else: gh.data['head']['repo']['full_name'] = 'stranger/fork'
            with self.subTest(field=field):
                self.gh.data, self.gh.transitions = pull(), [{'event': 'ready_for_review', 'id': 1}]
                self.gh.before_fresh = change
                self.assertIn('updated during', self.run_bot())
                self.assertFalse(self.gh.merges)

    def test_stop_reaction_arriving_at_final_read_holds(self):
        self.posted()
        self.dc.holder_reads = 0
        self.dc.before_final = lambda dc: dc.users.update({'42': 'Alex'})
        self.assertIn('On hold: Alex tapped', self.run_bot())
        self.assertFalse(self.gh.merges)

    def test_dry_run_lifecycle_does_not_write_or_merge(self):
        self.posted()
        before = copy.deepcopy(self.dc.__dict__)
        with patch.object(self.gh, 'merge', return_value=None) as merge, patch.object(self.gh, 'mirror') as mirror, patch.object(self.dc, 'post') as post:
            with io.StringIO() as output, patch('sys.stdout', output):
                self.run_bot(dry_run=True)
            post.assert_not_called(); mirror.assert_not_called()
            # The real GitHub adapter has a separate dry-run mutation guard.
            self.assertEqual(merge.call_count, 1)
        self.assertEqual(self.dc.message, before['message'])

    def test_deadline_guard_mutation_is_caught(self):
        source = Path(bot.__file__).read_text()
        before = "due = now >= date(state['start']) + WEEK"
        self.assertEqual(source.count(before), 1)
        namespace = {'__name__': 'synthetic_mutant'}
        exec(compile(source.replace(before, 'due = True'), bot.__file__, 'exec'), namespace)
        self.run_bot()
        reads = self.gh.reads
        with self.assertRaises(AssertionError):
            namespace['reconcile'](self.gh, self.dc, 25, 'merge', self.now)
            self.assertEqual(self.gh.reads, reads + 1, 'an unapproved early run must not enter the merge path')
            self.assertFalse(self.gh.merges)


class FakeAPI:
    def __init__(self, handler):
        self.handler, self.calls = handler, []

    def request(self, method, path, body=None, query=False):
        self.calls.append((method, path, copy.deepcopy(body)))
        return self.handler(method, path, body)

    pages = bot.API.pages


class ChangelogClockTests(unittest.TestCase):
    def cli(self, kind, ref='refs/heads/main'):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': kind, 'GITHUB_REF': ref,
               'CHANGELOG_MODE': 'post', 'GITHUB_TOKEN': 'synthetic-github',
               'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord', 'CHANGELOG_DISCORD_CHANNEL_ID': '123456',
               'GITHUB_EVENT_PATH': 'synthetic-clock-event.json'}
        def request(api, method, path, body=None):
            return (dc if api.base.startswith('https://discord.com') else gh)(method, path, body)
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch('builtins.open', mock_open(read_data='{}')), patch.object(bot.API, 'request', request), patch('sys.stdout', io.StringIO()):
            bot.main()
        return gh, dc

    def test_dispatch_on_main_sweeps_exactly_like_schedule(self):
        scheduled = self.cli('schedule')
        dispatched = self.cli('workflow_dispatch')
        self.assertEqual([c[:2] for c in scheduled[0].calls], [c[:2] for c in dispatched[0].calls])
        self.assertEqual([c[:2] for c in scheduled[1].calls], [c[:2] for c in dispatched[1].calls])
        self.assertEqual(len(dispatched[1].messages), 2)
        self.assertEqual({n for n, comments in dispatched[0].comments.items() if comments}, {1, 2})
        # The existing cron path is not newly restricted by the dispatch guard.
        self.assertEqual(len(self.cli('schedule', 'refs/heads/other')[1].messages), 2)

    def test_dispatch_on_any_other_or_missing_ref_refuses_before_API_or_event_file(self):
        for ref in ('refs/heads/other', 'refs/tags/main', 'main', '', None):
            env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'workflow_dispatch'}
            if ref is not None: env['GITHUB_REF'] = ref
            with self.subTest(ref=ref), patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch.object(bot.API, 'request', side_effect=AssertionError('network forbidden')) as request, patch('builtins.open', side_effect=AssertionError('event must not be read')) as event_file:
                with self.assertRaisesRegex(bot.Refused, 'dispatch requires refs/heads/main; no API calls made'): bot.main()
                request.assert_not_called(); event_file.assert_not_called()

    def test_unknown_event_still_refuses_before_API(self):
        for kind in ('push', 'repository_dispatch', '', 'unexpected'):
            with self.subTest(kind=kind), patch.dict(os.environ, {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': kind}, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch.object(bot.API, 'request', side_effect=AssertionError('network forbidden')) as request:
                with self.assertRaisesRegex(bot.Refused, 'Wrong event'): bot.main()
                request.assert_not_called()

    def clock(self, state='active', failure='', args=(), missing=False):
        import subprocess
        import tempfile
        script = Path(__file__).with_name('clock')/'changelog-clock'
        with tempfile.TemporaryDirectory(prefix='Changelog clock ') as folder:
            root = Path(folder); log = root/'calls.jsonl'; stub = root/'gh'
            stub.write_text('#!' + sys.executable + '\n' + '''import json,os,sys
with open(os.environ['CLOCK_LOG'], 'a') as log:
    log.write(json.dumps({'args': sys.argv[1:], 'stdin': sys.stdin.read()}) + '\\n')
if sys.argv[1] == 'api':
    if os.environ['CLOCK_FAILURE'] == 'read':
        print('untrusted gh response', file=sys.stderr); sys.exit(23)
    print(os.environ['CLOCK_STATE'])
else:
    print('untrusted gh output'); print('untrusted gh response', file=sys.stderr)
    if os.environ['CLOCK_FAILURE'] == 'dispatch': sys.exit(24)
''')
            stub.chmod(0o755)
            env = {'PATH': str(root) if not missing else str(root/'absent'), 'CLOCK_LOG': str(log),
                   'CLOCK_STATE': state, 'CLOCK_FAILURE': failure, 'GH_TOKEN': 'synthetic-not-a-credential'}
            result = subprocess.run(['/bin/sh', str(script), *args], input='stdin must be ignored', capture_output=True, text=True, env=env)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        return result, calls

    def test_clock_active_dispatches_once_with_fixed_main_arguments(self):
        result, calls = self.clock()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout + result.stderr, '')
        self.assertEqual([c['args'] for c in calls], [
            ['api', 'repos/LLRHook/checksinmyhead/actions/workflows/changelog-schedule.yml', '--jq', '.state'],
            ['workflow', 'run', 'changelog-schedule.yml', '-R', 'LLRHook/checksinmyhead', '--ref', 'main']])
        self.assertEqual([c['stdin'] for c in calls], ['', ''])

    def test_clock_every_other_state_exits_zero_without_dispatch(self):
        for state in ('disabled_manually', 'disabled_inactivity', 'deleted', '', 'unknown', 'active\nextra'):
            with self.subTest(state=state):
                result, calls = self.clock(state)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(len(calls), 1)
                self.assertEqual(result.stdout + result.stderr, '')

    def test_clock_failed_read_and_dispatch_report_one_safe_line(self):
        for failure, count, message in [('read', 1, 'could not read workflow state'), ('dispatch', 2, 'could not dispatch the sweep')]:
            with self.subTest(failure=failure):
                result, calls = self.clock(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(calls), count)
                self.assertEqual(result.stdout, '')
                self.assertEqual(result.stderr, 'Changelog clock ' + message + '\n')

    def test_clock_rejects_arguments_and_missing_gh_fails_safely(self):
        result, calls = self.clock(args=('other/repository',))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        self.assertEqual(result.stderr, 'Changelog clock takes no arguments\n')
        result, calls = self.clock(missing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        self.assertEqual(result.stderr, 'Changelog clock could not read workflow state\n')

    def test_clock_units_parse_as_user_oneshot_and_four_calendar_minutes(self):
        import configparser
        import subprocess
        folder = Path(__file__).with_name('clock')
        script = folder/'changelog-clock'
        self.assertTrue(script.stat().st_mode & 0o111)
        self.assertEqual(script.read_text().splitlines()[0], '#!/bin/sh')
        subprocess.run(['/bin/sh', '-n', str(script)], check=True, capture_output=True)
        service, timer = [configparser.ConfigParser(interpolation=None) for _ in range(2)]
        service.read(folder/'changelog-clock.service'); timer.read(folder/'changelog-clock.timer')
        self.assertEqual(service.sections(), ['Unit', 'Service'])
        self.assertEqual(dict(service['Service']), {'type': 'oneshot', 'execstart': '%h/.local/bin/changelog-clock'})
        self.assertEqual(timer.sections(), ['Unit', 'Timer', 'Install'])
        self.assertEqual(dict(timer['Timer']), {'oncalendar': '*:07,22,37,52', 'unit': 'changelog-clock.service'})
        self.assertEqual(dict(timer['Install']), {'wantedby': 'timers.target'})


class ChangelogAdapterTests(unittest.TestCase):
    def test_CLI_exposes_only_help_and_read_only_dry_run(self):
        options = set()
        original = bot.argparse.ArgumentParser.add_argument
        def capture(parser, *args, **kwargs):
            options.update(args)
            return original(parser, *args, **kwargs)
        with patch.object(bot.argparse.ArgumentParser, 'add_argument', capture), patch.object(sys, 'argv', ['changelog', '--help']), patch('sys.stdout', io.StringIO()):
            with self.assertRaises(SystemExit) as result: bot.main()
        self.assertEqual(result.exception.code, 0)
        self.assertEqual(options, {'-h', '--help', '--dry-run'})

    def compare(self):
        return {'total_commits': 1, 'commits': [{'sha': HEAD, 'parents': [{'sha': BASE}]}],
                'files': [{'filename': 'app.py', 'status': 'modified', 'additions': 1, 'deletions': 1,
                           'patch': '@@ -1,2 +1,2 @@\n-old\n+new\n same'}]}

    def test_fingerprint_main_merge_stable_own_edits_and_resolution_restart(self):
        result = self.compare()
        gh = bot.GitHub(FakeAPI(lambda *args: result))
        original = gh.change(pull())
        result['files'][0]['patch'] = result['files'][0]['patch'].replace('-1,2 +1,2', '-7,2 +7,2')
        result['commits'].append({'sha': 'c' * 40, 'parents': [{'sha': HEAD}, {'sha': BASE}]})
        result['total_commits'] = 2
        self.assertEqual(gh.change(pull()), original)
        result['files'][0]['patch'] = result['files'][0]['patch'].replace('+new', '+resolution')
        self.assertNotEqual(gh.change(pull()), original)
        result = self.compare()
        result['commits'][0]['sha'] = 'e' * 40
        self.assertNotEqual(gh.change(pull()), original)

    def test_comparison_truncation_falls_back_and_failed_read_propagates(self):
        for kind in ('commits', 'patch', 'binary', 'http'):
            result = self.compare()
            if kind == 'commits': result['total_commits'] = 1001
            elif kind == 'patch': result['files'][0]['additions'] = 2
            elif kind == 'binary': result['files'][0].pop('patch')
            def handle(*args):
                if kind == 'http': raise bot.Refused('API unavailable')
                return result
            with self.subTest(kind=kind):
                gh = bot.GitHub(FakeAPI(handle))
                if kind == 'http':
                    with self.assertRaises(bot.Refused): gh.change(pull())
                else:
                    self.assertEqual(gh.change(pull()), 'head:' + HEAD)

    def test_checks_exact_head_mandatory_context_and_each_terminal(self):
        head = pull()
        required = {'name': bot.REQUIRED_CHECK, 'app': {'slug': 'github-actions'}, 'head_sha': HEAD, 'status': 'completed', 'conclusion': 'success'}
        valid_note = dict(required, name=bot.CHECK)
        runs, statuses = [required, valid_note], []
        api = FakeAPI(lambda method, path, body: {'check_runs': runs} if 'check-runs' in path else statuses)
        gh = bot.GitHub(api)
        self.assertTrue(gh.green(head))
        for defect in ('missing', 'head', 'pending', 'failure', 'skipped', 'neutral', 'foreign-app'):
            runs = [copy.deepcopy(required), valid_note]
            if defect == 'missing': runs = []
            elif defect == 'head': runs[0]['head_sha'] = BASE
            elif defect == 'pending': runs[0]['status'] = 'in_progress'
            elif defect == 'foreign-app': runs[0]['app']['slug'] = 'stranger'
            else: runs[0]['conclusion'] = defect
            with self.subTest(defect=defect): self.assertFalse(gh.green(head))
        runs = [required, valid_note]
        statuses = [{'context': 'old-ci', 'state': 'pending'}]
        self.assertFalse(gh.green(head))
        statuses.insert(0, {'context': 'old-ci', 'state': 'success'})
        self.assertTrue(gh.green(head))

    def test_check_missing_note_failure_then_success_updates_same_check(self):
        existing = []
        api = FakeAPI(lambda method, path, body: {'check_runs': existing} if method == 'GET' else {})
        gh = bot.GitHub(api)
        gh.check(pull(), 'Fill in Why')
        self.assertEqual(api.calls[-1][2]['conclusion'], 'failure')
        existing.append({'name': bot.CHECK, 'app': {'slug': 'github-actions'}, 'id': 12})
        gh._runs.clear()
        gh.check(pull(), None)
        self.assertEqual(api.calls[-1][0], 'PATCH')
        self.assertEqual(api.calls[-1][2]['conclusion'], 'success')

    def test_account_identity_and_graphql_squash_exact_head_author_subject(self):
        author = {'name': bot.AUTHOR[0], 'email': bot.AUTHOR[1]}
        api = FakeAPI(lambda *args: {'author': dict(author)})
        viewer = {'login': 'LLRHook', 'name': bot.AUTHOR[0]}
        merge = FakeAPI(lambda method, path, body: dict(viewer) if path == '/user' else
                        {'data': {'mergePullRequest': {'pullRequest': {'merged': True, 'mergeCommit': {'oid': 'd' * 40, 'author': dict(author)}}}}})
        gh = bot.GitHub(api, merge)
        self.assertTrue(gh.identity(pull()))
        self.assertEqual(gh.merge(pull()), 'd' * 40)
        inputs = merge.calls[-1][2]['variables']['input']
        self.assertEqual(inputs['expectedHeadOid'], HEAD)
        self.assertEqual(inputs['authorEmail'], bot.AUTHOR[1])
        self.assertEqual(inputs['mergeMethod'], 'SQUASH')
        self.assertEqual(inputs['commitHeadline'], 'Show proposed changes (#25)')
        self.assertEqual(inputs['commitBody'], '')
        viewer['name'] = 'Unexpected profile'; self.assertFalse(gh.identity(pull()))
        viewer.update(name=bot.AUTHOR[0], login='another-account'); self.assertFalse(gh.identity(pull()))
        viewer['login'] = 'LLRHook'
        self.assertFalse(bot.GitHub(api).identity(pull()))
        other = pull(); other['user']['login'] = 'collaborator'
        self.assertFalse(gh.identity(other))
        author['name'] = 'Wrong Person'
        with self.assertRaisesRegex(bot.IdentityIncident, 'IDENTITY INCIDENT'): gh.merge(pull())
        self.assertTrue(all('/commits?' not in call[1] and '/pulls/' not in call[1] for call in api.calls))

    def test_merge_api_errors_are_safe_and_not_retried(self):
        api = FakeAPI(lambda *args: {'errors': [{'message': 'tainted-secret-response'}]})
        with self.assertRaisesRegex(bot.Refused, r'^GitHub declined the merge;'):
            bot.GitHub(api, api).merge(pull())
        self.assertEqual(len(api.calls), 1)

    def test_reactions_paginate_normal_and_burst_exclude_self_only(self):
        def handler(method, path, body):
            if path == '/users/@me': return {'id': '1'}
            if 'after=' in path: return [{'id': '999', 'username': '@everyone'}]
            if 'type=1' in path: return [{'id': '999', 'username': '@everyone'}]
            return [{'id': str(i), 'username': 'Alex'} for i in range(1, 101)]
        api = FakeAPI(handler)
        dc = bot.Discord(api, '123456'); dc.bot = '1'
        users = dc.holders('500')
        self.assertEqual(len(users), 100)
        self.assertNotIn('1', users)
        self.assertEqual(users['999'], '＠everyone')

    def test_notice_nonce_no_mentions_bounded_plain_text(self):
        api = FakeAPI(lambda method, path, body: {'id': '1'})
        dc = bot.Discord(api, '123456')
        state = {'version': 1, 'number': 25, 'start': bot.stamp(NOW), 'holds': {}}
        dc.post(pull(), state, 'hello')
        payload = api.calls[-1][2]
        self.assertTrue(payload['enforce_nonce'])
        self.assertLessEqual(len(payload['nonce']), 25)
        self.assertEqual(payload['allowed_mentions']['parse'], [])
        self.assertEqual(payload['allowed_mentions']['users'], [])
        dc.post(pull(), state, 'hello', {'id': '500'})
        self.assertEqual(api.calls[-1][2]['allowed_mentions'], payload['allowed_mentions'])
        with self.assertRaises(bot.Refused): dc.post(pull(), state, 'x' * 4097)
        escaped = bot.note(BODY.replace('Friends', '@everyone <@42> <@&7> `Friends` [click](evil)'))
        self.assertNotIn('@', escaped)
        self.assertNotIn('<', escaped)
        self.assertIn('\\`Friends\\`', escaped)
        self.assertIn('\\[click\\]', escaped)

    def test_discord_history_recovers_post_and_rejects_duplicate_or_foreign(self):
        state = {'version': 1, 'number': 25, 'start': bot.stamp(NOW - timedelta(seconds=1))}
        message = {'id': '500', 'channel_id': '123456', 'timestamp': bot.stamp(NOW), 'author': {'id': '1'},
                   'embeds': [bot.state_embed(25, state)]}
        history = [message]
        api = FakeAPI(lambda method, path, body: {'id': '1'} if path == '/users/@me' else history)
        dc = bot.Discord(api, '123456')
        recovered, saved = dc.find(pull())
        self.assertEqual(recovered['id'], '500')
        self.assertEqual(saved['start'], bot.stamp(NOW))
        history.append(dict(copy.deepcopy(message), id='501'))
        with self.assertRaisesRegex(bot.Refused, 'More than one'): dc.find(pull())
        history[-1]['author']['id'] = '2'
        self.assertEqual(dc.find(pull())[0]['id'], '500')

    def test_comment_is_readable_mirror_never_merge_authority(self):
        comments = [{'id': 1, 'user': {'login': 'stranger'}, 'body': bot.COMMENT + ' forged old start'}]
        api = FakeAPI(lambda method, path, body: comments if method == 'GET' else {})
        gh = bot.GitHub(api)
        gh.mirror(25, {'start': bot.stamp(NOW)}, '500', 'Waiting')
        self.assertEqual(api.calls[-1][0], 'POST')
        self.assertIn(bot.stamp(NOW), api.calls[-1][2]['body'])

    def test_HTTP_dry_run_blocks_all_writes_and_never_connects(self):
        api = bot.API('https://discord.com/api/v10', 'synthetic-token', 'Bot', True)
        with patch.object(api.opener, 'open', side_effect=AssertionError('network forbidden')) as request, patch('sys.stdout', io.StringIO()):
            for method in ('POST', 'PATCH', 'PUT', 'DELETE'): api.request(method, '/channels/123/messages', {})
        request.assert_not_called()
        merge = bot.GitHub(api, api, dry_run=True)
        with patch('sys.stdout', io.StringIO()): self.assertIsNone(merge.merge(pull()))

    def test_HTTP_rate_limit_and_redirect_hide_body_token_and_do_not_retry(self):
        api = bot.API('https://discord.com/api/v10', 'synthetic-token', 'Bot')
        for status in (429, 302, 503):
            error = urllib.error.HTTPError('https://discord.com/api/v10/test', status, 'tainted', {}, io.BytesIO(b'synthetic-token'))
            with patch.object(api.opener, 'open', side_effect=error) as request:
                with self.assertRaisesRegex(bot.Refused, 'API HTTP ' + str(status)) as failure: api.request('POST', '/test', {})
                self.assertNotIn('synthetic-token', str(failure.exception))
                self.assertEqual(request.call_count, 1)
        self.assertIsNone(bot.NoRedirect().redirect_request(None, None, None, None, None, None))

    def test_CLI_dry_run_ready_PR_uses_only_reads(self):
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'pull_request_target',
               'CHANGELOG_MODE': 'post', 'GITHUB_TOKEN': 'synthetic-github',
               'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord', 'CHANGELOG_DISCORD_CHANNEL_ID': '123456',
               'GITHUB_EVENT_PATH': 'L25-synthetic-event.json'}
        event = {'number': 25, 'repository': {'full_name': bot.REPO}, 'pull_request': pull()}
        methods = []
        def request(api, method, path, body=None, query=False):
            methods.append(method)
            if path == '/users/@me': return {'id': '1'}
            if '/channels/' in path: return []
            if '/pulls?state=open' in path: return [pull()]
            if '/pulls?state=closed' in path: return []
            if path.endswith('/pulls/25'): return pull()
            if '/files?' in path: return [{'filename': 'app.py'}]
            if '/compare/' in path: return self.compare()
            if '/check-runs?' in path: return {'check_runs': []}
            return []
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py', '--dry-run']), patch('builtins.open', mock_open(read_data=json.dumps(event))), patch.object(bot.API, 'request', request), patch('sys.stdout', io.StringIO()) as output:
            bot.main()
        self.assertEqual(set(methods), {'GET'})
        self.assertIn('DRY RUN: PR #25', output.getvalue())

    def test_CLI_fork_exemption_precedes_any_service_call(self):
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'pull_request_target',
               'CHANGELOG_MODE': 'post', 'GITHUB_TOKEN': 'synthetic-github',
               'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord', 'CHANGELOG_DISCORD_CHANNEL_ID': '123456',
               'GITHUB_EVENT_PATH': 'L25-synthetic-event.json'}
        event = {'number': 25, 'repository': {'full_name': bot.REPO}, 'pull_request': pull()}
        event['pull_request']['head']['repo']['full_name'] = 'stranger/fork'
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch('builtins.open', mock_open(read_data=json.dumps(event))), patch.object(bot.API, 'request', side_effect=AssertionError('network forbidden')), patch('sys.stdout', io.StringIO()):
            bot.main()

    def test_CLI_kill_switch_missing_secret_wrong_repo_and_fork_no_network(self):
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'schedule', 'CHANGELOG_MODE': 'off'}
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch.object(bot.API, 'request', side_effect=AssertionError('network forbidden')):
            with self.assertRaisesRegex(bot.Refused, 'OFF'): bot.main()
            os.environ['CHANGELOG_MODE'] = 'post'
            with self.assertRaisesRegex(bot.Refused, 'credentials'): bot.main()
            os.environ['GITHUB_REPOSITORY'] = 'stranger/repo'
            with self.assertRaisesRegex(bot.Refused, 'Wrong repository'): bot.main()


class ServiceGitHub:
    """Stateful REST/GraphQL fake: paths, pagination and server-added fields."""
    def __init__(self, closed=0, opened=1):
        self.now = NOW
        self.prs, self.comments, self.checks, self.calls = {}, {}, {}, []
        self.compare_failures = 0
        self.author = dict(name=bot.AUTHOR[0], email=bot.AUTHOR[1])
        self.compare_files = [{'filename': 'app.py', 'sha': 'c' * 40, 'status': 'modified',
                               'additions': 1, 'deletions': 0, 'patch': '@@ -1 +1,2 @@\n x\n+y'}]
        self.compare_commits = [{'sha': HEAD, 'parents': [{}]}]
        for n in range(1, closed + opened + 1):
            pr = pull()
            pr.update(number=n, state='closed' if n <= closed else 'open', merged=n <= closed,
                      closed_at=bot.stamp(NOW - timedelta(days=30)) if n <= closed else None,
                      updated_at=bot.stamp(NOW - timedelta(days=30)) if n <= closed else bot.stamp(NOW))
            pr['head']['sha'] = f'{n:040x}'
            self.prs[n] = pr
            self.comments[n] = []
            self.checks[pr['head']['sha']] = [{'id': n * 10, 'name': bot.REQUIRED_CHECK, 'app': {'slug': 'github-actions'},
                                            'head_sha': pr['head']['sha'], 'status': 'completed', 'conclusion': 'success'}]
        self.timeline = [{'event': 'ready_for_review', 'id': 9}]

    def __call__(self, method, path, body):
        from urllib.parse import urlsplit, parse_qs
        self.calls.append((method, path, copy.deepcopy(body)))
        result = self.handle(method, path, body, urlsplit(path), parse_qs(urlsplit(path).query))
        return copy.deepcopy(result)

    def handle(self, method, path, body, url, query):
        if path == '/user': return {'login': 'LLRHook', 'name': bot.AUTHOR[0]}
        if path == '/graphql':
            number = int(body['variables']['input']['pullRequestId'].split('-')[-1])
            self.prs[number].update(state='closed', merged=True, merged_by={'login': 'LLRHook'}, closed_at=bot.stamp(self.now), updated_at=bot.stamp(self.now))
            return {'data': {'mergePullRequest': {'pullRequest': {'merged': True,
                    'mergeCommit': {'oid': 'd' * 40, 'author': dict(self.author)}}}}}
        rest = url.path[len('/repos/' + bot.REPO):]
        parts = rest.strip('/').split('/')
        page = int(query.get('page', ['1'])[0])
        if rest == '/pulls':
            values = [dict(p, node_id='synthetic-' + str(p['number'])) for p in self.prs.values() if p['state'] == query['state'][0]]
            values.sort(key=lambda p: p['updated_at'], reverse=True)
            return values[(page - 1) * 100:page * 100]
        if parts[0] == 'pulls':
            pr = dict(self.prs[int(parts[1])], node_id='synthetic-' + parts[1])
            if len(parts) == 2: return pr
            if parts[2] == 'files': return self.compare_files[(page - 1) * 100:page * 100]
        if parts[0] == 'issues' and parts[1] != 'comments':
            number = int(parts[1])
            if parts[2] == 'timeline': return self.timeline
            if parts[2] == 'comments':
                if method == 'GET': return self.comments[number]
                comment = {'id': number, 'body': body['body'], 'user': {'login': 'github-actions[bot]'}}
                self.comments[number] = [comment]
                return comment
        if parts[:2] == ['issues', 'comments']:
            self.comments[int(parts[2])][0]['body'] = body['body']; return {}
        if parts[0] == 'compare':
            if self.compare_failures:
                self.compare_failures -= 1
                raise bot.HTTPFailure(502)
            result = {'total_commits': len(self.compare_commits), 'commits': self.compare_commits[(page - 1) * 100:page * 100]}
            if page == 1: result['files'] = self.compare_files[:300]
            return result
        if parts[0] == 'commits':
            if parts[2] == 'check-runs': return {'check_runs': self.checks[parts[1]]}
            if parts[2] == 'statuses': return []
        if parts[0] == 'check-runs':
            if method == 'POST':
                runs = self.checks[body['head_sha']]
                run = dict(body, id=10000 + len(runs), app={'slug': 'github-actions'})
                run['output'] = dict(run['output'], annotations_count=0)
                runs.append(run); return run
            for runs in self.checks.values():
                for run in runs:
                    if run['id'] == int(parts[1]): run.update(body); return run
        if parts[:2] == ['git', 'commits']: return {'author': dict(self.author)}
        raise AssertionError('Unexpected fake GitHub path: ' + method + ' ' + path)


class ServiceDiscord:
    def __init__(self):
        self.messages, self.calls, self.users, self.bursts = [], [], {}, {}
        self.approvals, self.approval_bursts = {}, {}
        self.next, self.now = 100000, NOW
        self.failure = None

    def __call__(self, method, path, body):
        from urllib.parse import urlsplit, parse_qs
        self.calls.append((method, path, copy.deepcopy(body)))
        if self.failure and path != '/users/@me':
            raise bot.HTTPFailure(self.failure)
        if path == '/users/@me': return {'id': '1'}
        parts = urlsplit(path).path.split('/')
        if method == 'GET' and '/reactions/' in path:
            kind = parse_qs(urlsplit(path).query).get('type', ['0'])[0]
            from urllib.parse import unquote
            emoji = unquote(parts[6])
            if emoji == bot.STOP:
                users = (self.bursts if kind == '1' else self.users).get(parts[4], [])
            else:
                users = (self.approval_bursts if kind == '1' else self.approvals).get(parts[4], {}).get(emoji, [])
            after = parse_qs(urlsplit(path).query).get('after', ['0'])[0]
            return copy.deepcopy([u for u in users if int(u['id']) > int(after)][:100])
        if method == 'GET':
            if len(parts) == 4:
                ordered = sorted(self.messages, key=lambda m: -int(m['id']))
                before = parse_qs(urlsplit(path).query).get('before', [None])[0]
                return [self.render(m) for m in ordered if not before or int(m['id']) < int(before)][:100]
            message = next((m for m in self.messages if m['id'] == parts[4]), None)
            if message is None: raise bot.HTTPFailure(404)
            return self.render(message)
        if method == 'POST':
            self.next += 1
            message = dict(id=str(self.next), channel_id='123456', author={'id': '1'}, timestamp=bot.stamp(self.now), reactions=[])
            self.messages.append(message)
        elif method == 'PATCH':
            message = next(m for m in self.messages if m['id'] == parts[4])
        else:
            if method == 'PUT':
                from urllib.parse import unquote
                message = next(m for m in self.messages if m['id'] == parts[4])
                emoji = unquote(parts[6])
                if not any(r['emoji']['name'] == emoji for r in message['reactions']):
                    message['reactions'].append({'emoji': {'name': emoji}, 'me': True})
            return {}
        message.update(content=body['content'])
        if 'embeds' in body:
            message['embeds'] = [dict(copy.deepcopy(embed), type='rich') for embed in body['embeds']]
        return self.render(message)

    def render(self, message):
        result = copy.deepcopy(message)
        seeds = {r['emoji']['name'] for r in message.get('reactions', []) if r.get('me')}
        normal = dict(self.approvals.get(message['id'], {}))
        burst = dict(self.approval_bursts.get(message['id'], {}))
        normal[bot.STOP] = self.users.get(message['id'], [])
        burst[bot.STOP] = self.bursts.get(message['id'], [])
        result['reactions'] = []
        for emoji in sorted(seeds | normal.keys() | burst.keys()):
            n = len({u['id'] for u in normal.get(emoji, [])} | ({'1'} if emoji in seeds else set()))
            b = len({u['id'] for u in burst.get(emoji, [])})
            if n + b:
                result['reactions'].append({'emoji': {'id': None, 'name': emoji}, 'me': emoji in seeds, 'me_burst': False, 'count': n + b, 'count_details': {'normal': n, 'burst': b}})
        return result

    def noise(self, count):
        for _ in range(count):
            self.next += 1
            self.messages.append(dict(id=str(self.next), channel_id='123456', author={'id': '777'}, timestamp=bot.stamp(self.now), embeds=[]))


class ChangelogRevisionTests(unittest.TestCase):
    def setUp(self):
        self.gh, self.dc = FakeGitHub(), FakeDiscord()
        self.now = NOW

    run_bot = ChangelogLifecycleTests.run_bot
    posted = ChangelogLifecycleTests.posted

    def services(self, gh_server, dc_server, now, mode='post'):
        gh_server.now = dc_server.now = now
        gh = bot.GitHub(FakeAPI(gh_server), FakeAPI(gh_server))
        dc = bot.Discord(FakeAPI(dc_server), '123456')
        with patch('sys.stdout', io.StringIO()):
            bot.reconcile_all(gh, dc, mode, now)
        return gh, dc

    def test_event_handles_only_its_PR_and_schedule_handles_the_active_set(self):
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'pull_request_target', 'CHANGELOG_MODE': 'post',
               'GITHUB_TOKEN': 'synthetic-github', 'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord',
               'CHANGELOG_DISCORD_CHANNEL_ID': '123456', 'GITHUB_EVENT_PATH': 'L25-synthetic-event.json'}
        for kind in ('ordinary', 'dependabot', 'retargeted'):
            gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
            event = {'repository': {'full_name': bot.REPO}, 'number': 1, 'pull_request': pull()}
            if kind == 'dependabot': event['pull_request']['user']['login'] = 'dependabot[bot]'
            if kind == 'retargeted': event['pull_request']['base']['ref'] = 'release'
            def request(api, method, path, body=None):
                return (dc if api.base.startswith('https://discord.com') else gh)(method, path, body)
            with self.subTest(kind=kind), patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch('builtins.open', mock_open(read_data=json.dumps(event))), patch.object(bot.API, 'request', request), patch('sys.stdout', io.StringIO()):
                bot.main()
                self.assertEqual(len(dc.messages), 1)
                self.assertIn('/pull/1#', dc.messages[0]['embeds'][0]['url'])


    def test_failed_Discord_read_preserves_outputs_and_write_denial_is_visible(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        before = copy.deepcopy((gh.comments, gh.checks, dc.messages))
        dc.failure = 502
        gh.calls.clear(); dc.calls.clear()
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=6))
        self.assertEqual((gh.comments, gh.checks, dc.messages), before)
        self.assertFalse(any(c[0] != 'GET' for c in gh.calls + dc.calls))
        self.run_bot()
        with patch.object(self.dc, 'post', side_effect=bot.NoticeProblem('Changelog cannot write to this channel. Ask the owner to restore Send Messages and Embed Links.')):
            with self.assertRaises(bot.NoticeProblem): self.run_bot()
        self.assertIn('restore Send Messages', self.gh.mirrors[-1][-1])


    def test_active_sweep_request_ceiling_300_closed_7_open_500_noise(self):
        gh, dc = ServiceGitHub(closed=300, opened=7), ServiceDiscord()
        # Old notices exist, but never cause an old PR to be fetched individually.
        for n in range(1, 301):
            state = {'version': 1, 'number': n, 'start': bot.stamp(NOW - timedelta(days=30)), 'ready': '9'}
            dc.next += 1
            dc.messages.append(dict(id=str(dc.next), channel_id='123456', author={'id': '1'}, timestamp=state['start'], content='Old notice', embeds=[dict(bot.state_embed(n, state), type='rich')]))
            gh.comments[n] = [{'id': n, 'user': {'login': 'github-actions[bot]'}, 'body': bot.COMMENT + '\nDiscord message: ' + str(dc.next)}]
        self.services(gh, dc, NOW)
        dc.noise(500)
        gh.calls.clear(); dc.calls.clear()
        self.services(gh, dc, NOW + timedelta(hours=1))
        self.assertLessEqual(len(gh.calls), 50)
        self.assertLessEqual(len(dc.calls), 25)
        self.assertEqual([c for c in dc.calls if c[0] != 'GET'], [])
        self.assertEqual([c for c in gh.calls if c[0] != 'GET'], [])
        self.assertFalse(any('/pulls/' + str(n) + '?' in c[1] or c[1].endswith('/pulls/' + str(n)) for c in gh.calls for n in range(1, 301)))
        print('F1 steady requests: GitHub=' + str(len(gh.calls)) + ', Discord=' + str(len(dc.calls)) + ', edits=0, reactions=0')

    def test_transient_compare_day6_real_adapters_merge_day7_without_writes(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        before = copy.deepcopy((gh.comments, gh.checks, dc.messages))
        gh.calls.clear(); dc.calls.clear(); gh.compare_failures = 1
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=6))
        self.assertEqual((gh.comments, gh.checks, dc.messages), before)
        self.assertFalse(any(c[0] != 'GET' for c in gh.calls + dc.calls))
        self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])
        self.assertIn("It's in", visible(dc.messages[0]))

    def test_one_failed_PR_does_not_stop_other_PRs_and_run_fails(self):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        gh.compare_failures = 1
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW)
        self.assertEqual(len(dc.messages), 1)
        self.assertEqual(dc.messages[0]['embeds'][0]['title'], 'Show proposed changes')
        self.assertFalse(gh.comments[1])

    def test_binary_and_rename_finish_day7_image_change_restarts_once(self):
        for status in ('modified', 'renamed'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            gh.compare_files = [{'filename': 'image.png', 'previous_filename': 'old.png', 'status': status,
                                 'sha': 'c' * 40, 'additions': 0, 'deletions': 0}]
            self.services(gh, dc, NOW)
            self.services(gh, dc, NOW + bot.WEEK, 'merge')
            self.assertTrue(gh.prs[1]['merged'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        gh.compare_files = [{'filename': 'image.png', 'status': 'modified', 'sha': 'c' * 40}]
        self.services(gh, dc, NOW)
        gh.compare_files[0]['sha'] = 'e' * 40
        self.services(gh, dc, NOW + timedelta(days=2))
        self.services(gh, dc, NOW + timedelta(days=8), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.services(gh, dc, NOW + timedelta(days=9), 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_paged_files_and_commits_then_stable_exact_head_fallback(self):
        gh = ServiceGitHub()
        gh.compare_files *= 301
        for i, f in enumerate(gh.compare_files): gh.compare_files[i] = dict(f, filename=str(i) + '.py')
        gh.prs[1]['changed_files'] = 301
        gh.compare_commits = [{'sha': f'{n:040x}', 'parents': [{}]} for n in range(101)]
        adapter = bot.GitHub(FakeAPI(gh))
        fingerprint = adapter.change(gh.prs[1])
        self.assertFalse(fingerprint.startswith('head:'))
        self.assertTrue(any('page=2' in c[1] for c in gh.calls))
        self.assertEqual(len(adapter._files[(1, gh.prs[1]['head']['sha'])]), 301)
        gh.prs[1]['changed_files'] = 3001
        self.assertEqual(adapter.change(gh.prs[1]), 'head:' + gh.prs[1]['head']['sha'])
        # The API's 3000-file limit uses a deterministic head-based clock.
        self.gh.fingerprint = 'head:' + HEAD
        self.gh.data['changed_files'] = 3001
        self.run_bot()
        original = self.dc.state['start']
        self.now += timedelta(days=3); self.run_bot()
        self.assertEqual(self.dc.state['start'], original)
        self.assertIn('big change', visible(self.dc.message))
        self.gh.fingerprint = 'head:' + BASE
        self.gh.data['head']['sha'] = BASE
        self.run_bot(); restarted = self.dc.state['start']
        self.now += timedelta(days=7); self.run_bot()
        self.assertEqual(self.dc.state['start'], restarted)
        self.assertEqual(len(self.gh.merges), 1)

    def test_discord_429_retries_once_with_bounded_retry_after(self):
        api = bot.API('https://discord.com/api/v10', 'synthetic-token', 'Bot')
        error = urllib.error.HTTPError('https://discord.com/api/v10/test', 429, '', {}, io.BytesIO(b'{"retry_after":0.25}'))
        response = unittest.mock.MagicMock()
        response.__enter__.return_value.read.return_value = b'{}'
        with patch.object(api.opener, 'open', side_effect=[error, response]) as request, patch.object(bot.time, 'sleep') as sleep:
            self.assertEqual(api.request('GET', '/test'), {})
            self.assertEqual(request.call_count, 2); sleep.assert_called_once_with(0.25)
        errors = [urllib.error.HTTPError('https://discord.com/api/v10/test', 429, '', {}, io.BytesIO(b'{"retry_after":0}')) for _ in range(2)]
        with patch.object(api.opener, 'open', side_effect=errors) as request, patch.object(bot.time, 'sleep'):
            with self.assertRaises(bot.HTTPFailure): api.request('GET', '/test')
            self.assertEqual(request.call_count, 2)
        for delay in (6, -1, 'slow'):
            error = urllib.error.HTTPError('https://discord.com/api/v10/test', 429, '', {}, io.BytesIO(json.dumps({'retry_after': delay}).encode()))
            with patch.object(api.opener, 'open', side_effect=error) as request, patch.object(bot.time, 'sleep') as sleep:
                with self.assertRaises(bot.HTTPFailure): api.request('GET', '/test')
                request.assert_called_once(); sleep.assert_not_called()

    def test_exempt_notice_is_finished_and_later_manual_merge_is_true(self):
        for kind in ('tracker', 'retarget'):
            self.setUp(); self.run_bot()
            if kind == 'tracker': self.gh.paths = ['features.md']
            elif kind == 'retarget': self.gh.data['base']['ref'] = 'release'
            self.assertEqual(self.run_bot(), 'exempt')
            self.assertNotIn('Goes live', visible(self.dc.message))
            self.assertNotIn('Tap 🛑', visible(self.dc.message))
            self.gh.data.update(state='closed', merged=True)
            self.run_bot()
            self.assertIn(bot.MERGED, visible(self.dc.message))

    def test_phone_states_local_times_no_ids_hashes_or_note_copy(self):
        self.run_bot()
        self.assertIn('<t:', visible(self.dc.message))
        self.assertIn(':R>', visible(self.dc.message))
        self.dc.users = {'301234567890123456': 'Maya'}
        self.run_bot()
        self.assertIn('Maya', visible(self.dc.message))
        self.assertNotIn('301234567890123456', visible(self.dc.message))
        self.assertNotIn('note', self.dc.state)
        self.assertEqual(self.dc.message['content'], '')
        self.assertNotIn('footer', self.dc.message['embeds'][0])
        self.assertEqual(len(self.dc.message['embeds']), 1)
        for state in ('draft', 'merged', 'closed'):
            self.gh.data.update(draft=state == 'draft', state='open' if state == 'draft' else 'closed', merged=state == 'merged')
            self.run_bot()
            self.assertNotIn('Goes live', visible(self.dc.message))
            self.assertNotIn('Tap 🛑', visible(self.dc.message))


    def test_deleted_notice_draft_ready_recovery_starts_full_week(self):
        self.run_bot(); self.dc.message = self.dc.state = None
        with self.assertRaises(bot.NoticeProblem): self.run_bot()
        self.assertIn('draft, then ready again', self.gh.mirrors[-1][-1])
        self.gh.data['draft'] = True
        self.gh.transitions.append({'event': 'converted_to_draft', 'id': 2})
        with self.assertRaises(bot.NoticeProblem): self.run_bot()
        self.gh.data['draft'] = False
        self.gh.transitions.append({'event': 'ready_for_review', 'id': 3})
        self.now += timedelta(days=8)
        self.run_bot()
        self.assertEqual(self.dc.created, 2)
        self.assertFalse(self.gh.merges)
        self.assertEqual(self.dc.state['start'], bot.stamp(self.now))

    def test_channel_access_and_duplicates_have_comment_and_notice_recovery(self):
        for denied in ('identity', 'hint'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            original = dc.__call__
            def denial(method, path, body):
                if path == ('/users/@me' if denied == 'identity' else '/channels/123456/messages/' + dc.messages[0]['id']):
                    raise bot.HTTPFailure(403)
                return original(method, path, body)
            client = bot.Discord(FakeAPI(denial), '123456')
            if denied == 'identity':
                with self.assertRaises(bot.HTTPFailure): client.find(gh.prs[1], {'message': dc.messages[0]['id']})
                self.assertNotIn('cannot read this channel', gh.comments[1][0]['body'])
            else:
                message, state = client.find(gh.prs[1], {'message': dc.messages[0]['id']})
                self.assertEqual(message['id'], dc.messages[0]['id'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        original = dc.__call__
        def denied_seed(method, path, body):
            if method == 'PUT': raise bot.HTTPFailure(403)
            return original(method, path, body)
        with self.assertRaises(bot.NoticeProblem):
            bot.reconcile(bot.GitHub(FakeAPI(gh)), bot.Discord(FakeAPI(denied_seed), '123456'), 1, 'post', NOW)
        self.assertIn('restore Add Reactions', gh.comments[1][0]['body'])
        for status in (403, 404):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            dc.failure = status
            with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(hours=1))
            self.assertIn('restore View Channel', gh.comments[1][0]['body'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.next += 1; dc.messages.append(dict(copy.deepcopy(dc.messages[0]), id=str(dc.next)))
        gh.comments[1] = []
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(hours=1))
        self.assertIn('More than one notice', gh.comments[1][0]['body'])
        self.assertTrue(all('remove the duplicate' not in visible(m) for m in dc.messages))

    def test_draft_note_check_and_named_missing_required_check(self):
        self.gh.data.update(draft=True, body='')
        self.run_bot()
        self.assertTrue(self.gh.checks[-1])
        self.assertEqual(self.dc.created, 0)
        self.gh.data.update(draft=False, body=BODY)
        self.run_bot(); self.now += bot.WEEK
        self.gh.is_green = False
        self.assertIn(bot.REQUIRED_CHECK, self.run_bot())
        self.assertIn(bot.REQUIRED_CHECK, self.run_bot(mode='post'))

    def test_real_merge_adapter_wrong_raw_author_fails_Actions_PR_and_notice(self):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.author['name'] = 'Unexpected Author'
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])
        self.assertFalse(gh.prs[2]['merged'])
        self.assertEqual(visible(dc.messages[0]).split('\n\n')[-1], bot.MERGED)
        self.assertNotIn('IDENTITY INCIDENT', visible(dc.messages[0]))
        self.assertIn('IDENTITY INCIDENT', gh.comments[1][0]['body'])
        note = next(run for run in gh.checks[gh.prs[1]['head']['sha']] if run['name'] == bot.CHECK)
        self.assertEqual(note['conclusion'], 'failure')
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=1), 'post')
        self.assertEqual(visible(dc.messages[0]).split('\n\n')[-1], bot.MERGED)
        self.assertNotIn('IDENTITY INCIDENT', visible(dc.messages[0]))

    def test_semantic_merge_refusal_updates_notice_without_restarting_week(self):
        self.posted()
        start = self.dc.state['start']
        with patch.object(self.gh, 'merge', side_effect=bot.MergeBlocked('Merge refused by GitHub; waiting for the owner or a later run')):
            self.assertEqual(bot.GITHUB_WAIT, self.run_bot())
        self.assertIn(bot.GITHUB_WAIT, visible(self.dc.message))
        self.assertIn('Merge refused', self.gh.mirrors[-1][-1])
        self.assertEqual(self.dc.state['start'], start)
        self.assertFalse(self.gh.merges)

    def test_other_PR_author_waits_manual_and_identity_incident_is_loud(self):
        self.run_bot(); self.now += bot.WEEK
        self.gh.data['user']['login'] = 'friend'
        self.assertIn('Someone else wrote this one', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.gh.data['user']['login'] = 'LLRHook'
        with patch.object(self.gh, 'merge', side_effect=bot.IdentityIncident('MERGE IDENTITY INCIDENT: stop the bot')):
            with self.assertRaises(bot.IdentityIncident): self.run_bot()
        self.assertTrue(visible(self.dc.message).endswith(bot.MERGED))
        self.assertNotIn('IDENTITY INCIDENT', visible(self.dc.message))
        self.assertIn('IDENTITY INCIDENT', self.gh.mirrors[-1][-1])
        self.assertIn('IDENTITY INCIDENT', self.gh.checks[-1])

    def test_saved_real_check_list_optional_results_and_blocking_conclusions(self):
        # Verbatim name/app/status/conclusion/head-match inventory supplied by L28.
        rows = '''publish-backend\tgithub-actions\tcompleted\tskipped\ttrue
publish-web\tgithub-actions\tcompleted\tskipped\ttrue
Required delivery checks\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Selected checks all\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate web\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate automation\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate backend\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate mobile\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate local-workflow\tgithub-actions\tcompleted\tsuccess\ttrue
checks / Gate postgres\tgithub-actions\tcompleted\tsuccess\ttrue
resolve\tgithub-actions\tcompleted\tsuccess\ttrue'''
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        head = gh.prs[1]['head']['sha']
        note_run = next(r for r in gh.checks[head] if r['name'] == bot.CHECK)
        copied = []
        for i, row in enumerate(rows.splitlines()):
            name, app, status, conclusion, exact = row.split('\t')
            copied.append(dict(id=100 + i, name=name, app={'slug': app}, head_sha=head if exact == 'true' else BASE,
                               status=status, conclusion=conclusion))
        gh.checks[head] = copied + [note_run, dict(copied[0], name='changelog', status='in_progress', conclusion=None)]
        adapter = bot.GitHub(FakeAPI(gh))
        self.assertTrue(adapter.green(gh.prs[1]))
        for outcome in ('failure', 'cancelled', 'timed_out', 'action_required', 'stale', 'startup_failure', 'unknown', None):
            gh.checks[head][0]['conclusion'] = outcome
            with self.subTest(outcome=outcome): self.assertFalse(adapter.green(gh.prs[1]))
        gh.checks[head][0].update(conclusion='neutral')
        self.assertTrue(adapter.green(gh.prs[1]))
        gh.checks[head][0].update(status='queued')
        self.assertFalse(adapter.green(gh.prs[1]))
        gh.checks[head][0].update(status='completed', conclusion='skipped')
        for name in (bot.REQUIRED_CHECK, bot.CHECK):
            selected = next(r for r in gh.checks[head] if r['name'] == name)
            for outcome in ('skipped', 'neutral', 'failure'):
                selected['conclusion'] = outcome
                with self.subTest(required=name, outcome=outcome): self.assertFalse(adapter.green(gh.prs[1]))
            selected['conclusion'] = 'success'
        self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_history_lookup_recovers_held_notice_after_deleted_or_retitled_comment(self):
        for kind in ('deleted', 'retitled', 'forged'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            original = dc.messages[0]['id']
            dc.users[original] = [{'id': '42', 'username': 'Maya'}]
            self.services(gh, dc, NOW + timedelta(days=1))
            dc.noise(500)
            if kind == 'deleted': gh.comments[1] = []
            elif kind == 'retitled': gh.comments[1][0]['body'] = 'Someone changed this comment title'
            else: gh.comments[1][0]['body'] = bot.COMMENT + '\nDiscord message: 123456789012345678'
            self.services(gh, dc, NOW + timedelta(days=2))
            self.services(gh, dc, NOW + timedelta(days=9), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
            self.assertEqual(len([m for m in dc.messages if m['author']['id'] == '1']), 1)
            self.assertEqual(dc.messages[0]['id'], original)
            self.assertIn('Maya tapped', visible(dc.messages[0]))

    def test_lost_initial_post_response_recovers_without_orphaning_the_week(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        handler = dc.__class__.__call__
        fired = False
        def lost(method, path, body):
            nonlocal fired
            value = handler(dc, method, path, body)
            if method == 'POST' and not fired:
                fired = True
                raise bot.HTTPFailure(502)
            return value
        with patch('sys.stdout', io.StringIO()), self.assertRaises(bot.Refused):
            bot.reconcile_all(bot.GitHub(FakeAPI(gh)), bot.Discord(FakeAPI(lost), '123456'), 'post', NOW)
        self.assertEqual(len(dc.messages), 1)
        self.assertEqual(gh.comments[1], [])
        dc.noise(500)
        self.services(gh, dc, NOW + timedelta(days=1))
        self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])
        self.assertEqual(len([m for m in dc.messages if m['author']['id'] == '1']), 1)

    def test_deleted_notice_draft_ready_recovers_through_channel_history(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.messages.clear()
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=1))
        gh.prs[1]['draft'] = True; gh.timeline.append({'event': 'converted_to_draft', 'id': 10})
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=2))
        gh.prs[1]['draft'] = False; gh.timeline.append({'event': 'ready_for_review', 'id': 11})
        self.services(gh, dc, NOW + timedelta(days=3))
        self.assertEqual(len(dc.messages), 1)
        self.services(gh, dc, NOW + timedelta(days=9), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.services(gh, dc, NOW + timedelta(days=10), 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_history_page_costs_and_safety_cap(self):
        for age, pages in ((1, 1), (7, 4), (30, 16)):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            created = NOW - timedelta(days=age)
            gh.prs[1]['created_at'] = bot.stamp(created)
            dc.now = created - timedelta(seconds=1); dc.noise(1)
            for i in range(age * 50):
                dc.now = created + timedelta(seconds=i * 1728)
                dc.noise(1)
            found = bot.Discord(FakeAPI(dc), '123456').find(gh.prs[1])
            self.assertEqual(found, (None, None))
            self.assertEqual(sum('?limit=100' in c[1] for c in dc.calls), pages)
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.users[dc.messages[0]['id']] = [{'id': '42', 'username': 'Maya'}]
        dc.noise(2100); gh.comments[1] = []
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=9), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.assertEqual(len([m for m in dc.messages if m['author']['id'] == '1']), 1)
        self.assertIn('Close this pull request and open', gh.comments[1][0]['body'])

    def test_holder_name_cannot_inject_the_comment_message_pointer(self):
        for name in ('Discord message: 123456789012345678', '\nDiscord message: 123456789012345678\n'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            message_id = dc.messages[0]['id']
            dc.users[message_id] = [{'id': '42', 'username': name}]
            self.services(gh, dc, NOW + timedelta(days=1))
            self.assertEqual(bot.GitHub(FakeAPI(gh)).hint(1)['message'], message_id)
            self.assertNotIn('<t:', gh.comments[1][0]['body'])
            self.assertIn('November 2026', gh.comments[1][0]['body'])

    def test_manual_merge_of_another_author_is_not_a_bot_identity_incident(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        gh.prs[1]['user']['login'] = 'friend-dev'
        self.services(gh, dc, NOW)
        self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertIn('owner will put it live by hand', visible(dc.messages[0]))
        gh.author = {'name': 'Other Author', 'email': 'other@example.invalid'}
        gh.prs[1].update(state='closed', merged=True, closed_at=bot.stamp(NOW + bot.WEEK), updated_at=bot.stamp(NOW + bot.WEEK))
        gh.calls.clear()
        self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=1), 'merge')
        self.assertTrue(visible(dc.messages[0]).endswith(bot.MERGED))
        self.assertFalse(any('/git/commits/' in c[1] for c in gh.calls))
        self.assertNotIn('INCIDENT', gh.comments[1][0]['body'])
        self.assertTrue(all(r.get('conclusion') == 'success' for r in gh.checks[gh.prs[1]['head']['sha']]))

    def test_burst_only_stop_and_hinted_message_author_are_enforced(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        message = dc.messages[0]
        dc.bursts[message['id']] = [{'id': '42', 'username': 'Maya'}]
        self.services(gh, dc, NOW + bot.WEEK, 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('Maya tapped', visible(message))
        foreign = copy.deepcopy(message); foreign['author']['id'] = '777'
        dc.messages = [foreign]
        found = bot.Discord(FakeAPI(dc), '123456').find(gh.prs[1], {'message': foreign['id']})
        self.assertEqual(found, (None, None))
        wrong_channel = copy.deepcopy(message); wrong_channel['channel_id'] = '999999'
        dc.messages = [wrong_channel]
        self.assertEqual(bot.Discord(FakeAPI(dc), '123456').find(gh.prs[1], {'message': message['id']}), (None, None))

    def test_unexpected_per_PR_error_is_sanitized_and_sweep_continues(self):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        handler = gh.__class__.__call__
        def unexpected(method, path, body):
            if path.endswith('/pulls/1'): raise KeyError('synthetic-sensitive-value')
            return handler(gh, method, path, body)
        with patch('sys.stdout', io.StringIO()) as output, self.assertRaises(bot.Refused):
            bot.reconcile_all(bot.GitHub(FakeAPI(unexpected)), bot.Discord(FakeAPI(dc), '123456'), 'post', NOW)
        self.assertIn('PR #1: KeyError', output.getvalue())
        self.assertNotIn('synthetic-sensitive-value', output.getvalue())
        self.assertEqual(len(dc.messages), 1)

    def test_event_and_hourly_request_costs_and_recent_closure_cutoff(self):
        gh, dc = ServiceGitHub(opened=10), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.calls.clear(); dc.calls.clear()
        bot.reconcile(bot.GitHub(FakeAPI(gh)), bot.Discord(FakeAPI(dc), '123456'), 1, 'post', NOW + timedelta(hours=1))
        event = len(gh.calls), len(dc.calls)
        self.assertEqual(event, (6, 2))
        gh.calls.clear(); dc.calls.clear()
        self.services(gh, dc, NOW + timedelta(hours=1))
        hourly = len(gh.calls), len(dc.calls)
        self.assertEqual(hourly, (62, 11))
        self.assertEqual(tuple(event[i] * 15 + hourly[i] * 4 for i in (0, 1)), (338, 74))
        gh = ServiceGitHub(closed=3, opened=1)
        for number, age in ((1, 2), (2, 29), (3, 0.1)):
            gh.prs[number].update(closed_at=bot.stamp(NOW - timedelta(days=age)), updated_at=bot.stamp(NOW - timedelta(days=age)))
        self.assertEqual({p['number'] for p in bot.GitHub(FakeAPI(gh)).pulls(NOW)}, {3, 4})

    def test_record_only_change_and_link_preview_are_not_ignored(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        message = copy.deepcopy(dc.messages[0])
        adapter = bot.Discord(FakeAPI(dc), '123456'); adapter.bot = '1'
        state = adapter.record(message, 1)
        state['fingerprint'] = 'e' * 64
        dc.calls.clear()
        adapter.post(gh.prs[1], state, visible(message), message)
        self.assertEqual(dc.calls[-1][0], 'PATCH')
        latest = copy.deepcopy(dc.messages[0]); latest['embeds'].append({'type': 'link', 'url': 'https://example.invalid'})
        dc.calls.clear()
        adapter.post(gh.prs[1], state, visible(latest), latest)
        self.assertEqual(dc.calls[-1][0], 'PATCH')
        self.assertEqual(len(dc.messages[0]['embeds']), 1)

    def test_owner_merge_audit_recovers_lost_reply_and_failed_commit_read(self):
        for fault in ('reply', 'commit-read'):
            for wrong in (False, True):
                with self.subTest(fault=fault, wrong=wrong):
                    gh, dc = ServiceGitHub(), ServiceDiscord()
                    self.services(gh, dc, NOW)
                    if wrong: gh.author = {'name': 'Someone Else', 'email': 'other@example.invalid'}
                    original = gh.__call__
                    fired = False
                    def lose_response(method, path, body):
                        nonlocal fired
                        match = path == '/graphql' if fault == 'reply' else '/git/commits/' in path
                        if match and not fired:
                            fired = True
                            if fault == 'reply': original(method, path, body)
                            raise bot.HTTPFailure(502)
                        return original(method, path, body)
                    gh.now = dc.now = NOW + bot.WEEK
                    with self.assertRaises(bot.Refused), patch('sys.stdout', io.StringIO()):
                        bot.reconcile_all(bot.GitHub(FakeAPI(lose_response), FakeAPI(lose_response)), bot.Discord(FakeAPI(dc), '123456'), 'merge', NOW + bot.WEEK)
                    self.assertTrue(fired)
                    self.assertTrue(gh.prs[1]['merged'])
                    gh.calls.clear()
                    if wrong:
                        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=1))
                        self.assertIn('not authored by Victor Ivanov <victor.n.ivanov@gmail.com>', gh.comments[1][0]['body'])
                        self.assertIn('set CHANGELOG_MODE to post', gh.comments[1][0]['body'])
                        note = next(r for r in gh.checks[gh.prs[1]['head']['sha']] if r['name'] == bot.CHECK)
                        self.assertEqual(note['conclusion'], 'failure')
                    else:
                        self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=1))
                        self.assertEqual(sum('/git/commits/' in c[1] for c in gh.calls), 1)
                        gh.calls.clear()
                        self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=2))
                        self.assertFalse(any('/git/commits/' in c[1] for c in gh.calls))
                    self.assertTrue(visible(dc.messages[0]).endswith(bot.MERGED))
                    self.assertNotIn('IDENTITY INCIDENT', visible(dc.messages[0]))

    def test_hand_merge_audit_requires_both_owner_opener_and_owner_merger(self):
        for opener, merger, audited in (('LLRHook', 'LLRHook', True), ('friend-dev', 'LLRHook', False), ('LLRHook', 'friend-dev', False)):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            gh.prs[1]['user']['login'] = opener
            self.services(gh, dc, NOW)
            gh.prs[1].update(state='closed', merged=True, merged_by={'login': merger}, closed_at=bot.stamp(NOW), updated_at=bot.stamp(NOW))
            gh.author = {'name': 'Someone Else', 'email': 'other@example.invalid'}
            gh.calls.clear()
            if audited:
                with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(hours=1))
                self.assertIn('IDENTITY INCIDENT', gh.comments[1][0]['body'])
            else:
                self.services(gh, dc, NOW + timedelta(hours=1))
                self.assertFalse(any('/git/commits/' in c[1] for c in gh.calls))
            self.assertTrue(visible(dc.messages[0]).endswith(bot.MERGED))

    def test_never_posted_exempt_PRs_skip_Discord_and_all_writes(self):
        for kind in ('dependabot', 'non-main', 'tracker'):
            gh, dc = ServiceGitHub(opened=3), ServiceDiscord()
            for pr in gh.prs.values():
                pr['created_at'] = bot.stamp(NOW - timedelta(days=45))
                if kind == 'dependabot': pr['user']['login'] = 'dependabot[bot]'
                elif kind == 'non-main': pr['base']['ref'] = 'feature/other'
            if kind == 'tracker': gh.compare_files[0]['filename'] = 'features.md'
            # One exempt draft exercises the early branch too.
            gh.prs[1]['draft'] = True
            dc.noise(2250)
            for hour in (0, 1, 2):
                gh.calls.clear(); dc.calls.clear()
                self.services(gh, dc, NOW + timedelta(hours=hour))
                self.assertEqual(dc.calls, [])
                self.assertFalse(any(c[0] != 'GET' for c in gh.calls))
                self.assertTrue(all(not comments for comments in gh.comments.values()))

    def test_draft_notice_stays_unchanged_then_ready_gets_full_week(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.prs[1]['draft'] = True
        gh.timeline.append({'event': 'converted_to_draft', 'id': 10})
        self.services(gh, dc, NOW + timedelta(days=1))
        before = copy.deepcopy((dc.messages, gh.comments))
        for hour in (1, 2, 3):
            gh.calls.clear(); dc.calls.clear()
            self.services(gh, dc, NOW + timedelta(days=1, hours=hour))
            self.assertEqual((dc.messages, gh.comments), before)
            self.assertFalse(any(c[0] != 'GET' for c in gh.calls + dc.calls))
        gh.prs[1]['draft'] = False
        gh.timeline.append({'event': 'ready_for_review', 'id': 11})
        ready = NOW + timedelta(days=3)
        self.services(gh, dc, ready)
        record = bot.Discord(FakeAPI(dc), '123456').record(dc.messages[0], 1)
        self.assertEqual(bot.date(record['start']), ready)
        self.services(gh, dc, ready + bot.WEEK - timedelta(microseconds=1), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.services(gh, dc, ready + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_ready_in_the_timeline_before_the_draft_flag_clears_still_gets_full_week(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.prs[1]['draft'] = True
        gh.timeline.append({'event': 'converted_to_draft', 'id': 10})
        self.services(gh, dc, NOW + timedelta(days=1))
        # One run still reads the pull request as a draft although its timeline already
        # shows it ready. That run saves the new ready event; only the saved "cancelled"
        # flag then makes the next run start a new week.
        gh.timeline.append({'event': 'ready_for_review', 'id': 11})
        self.services(gh, dc, NOW + timedelta(days=8), 'merge')
        gh.prs[1]['draft'] = False
        ready = NOW + timedelta(days=8, hours=1)
        self.services(gh, dc, ready, 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        record = bot.Discord(FakeAPI(dc), '123456').record(dc.messages[0], 1)
        self.assertEqual(bot.date(record['start']), ready)
        self.services(gh, dc, ready + bot.WEEK - timedelta(microseconds=1), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.services(gh, dc, ready + bot.WEEK, 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_broken_note_keeps_holders_and_developer_instruction_off_Discord(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.users[dc.messages[0]['id']] = [{'id': '42', 'username': 'Maya'}]
        gh.prs[1]['body'] = ''
        self.services(gh, dc, NOW + timedelta(days=8), 'merge')
        status = visible(dc.messages[0])
        self.assertIn('On hold: Maya tapped 🛑', status)
        self.assertTrue(status.endswith("Paused: the author needs to fix this change's description."))
        self.assertNotIn('markers', status)
        self.assertIn('Start the description with the Changelog note markers', gh.comments[1][0]['body'])
        self.assertFalse(gh.prs[1]['merged'])

    def test_merge_refusal_and_each_non_conflict_state_use_the_waiting_wording(self):
        for state in ('blocked', 'behind', 'unstable', 'unknown', None, 'future-state', 'clean', 'dirty'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            gh.prs[1].update(mergeable=False, mergeable_state=state)
            self.services(gh, dc, NOW + bot.WEEK, 'merge')
            status = visible(dc.messages[0]).split('\n\n')[-1]
            self.assertTrue(status.endswith('.'))
            if state == 'dirty': self.assertIn('clashes with another change', status)
            else:
                self.assertEqual(status, bot.GITHUB_WAIT)
                self.assertIn('mergeable_state is ' + str(state), gh.comments[1][0]['body'])
            self.assertFalse(gh.prs[1]['merged'])
        # Where Changelog will not merge by itself it must not say it keeps checking.
        for mode, opener, expected in (('post', 'LLRHook', 'It goes live once the owner switches it on.'),
                                       ('merge', 'dhaliwalg', 'the owner will put it live by hand.')):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            gh.prs[1]['user'] = {'login': opener}
            self.services(gh, dc, NOW)
            gh.prs[1].update(mergeable=False, mergeable_state='blocked')
            self.services(gh, dc, NOW + bot.WEEK, mode)
            status = visible(dc.messages[0]).split('\n\n')[-1]
            self.assertIn(expected, status)
            self.assertNotIn('keep checking', status)
            self.assertFalse(gh.prs[1]['merged'])
        for response in ({'errors': [{'message': 'not for channel readers'}]}, {'data': {'mergePullRequest': {'pullRequest': {'merged': False}}}}):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            original = gh.__call__
            def decline(method, path, body):
                return response if path == '/graphql' else original(method, path, body)
            gh.now = dc.now = NOW + bot.WEEK
            bot.reconcile(bot.GitHub(FakeAPI(decline), FakeAPI(decline)), bot.Discord(FakeAPI(dc), '123456'), 1, 'merge', NOW + bot.WEEK)
            self.assertTrue(visible(dc.messages[0]).endswith(bot.GITHUB_WAIT))
            self.assertIn('GitHub', gh.comments[1][0]['body'])
            self.assertIn('mergeable_state is clean', gh.comments[1][0]['body'])
            self.assertNotIn('not for channel readers', gh.comments[1][0]['body'])

    def test_mirror_deadline_is_written_once_and_recovery_messages_are_documented(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        mirror = gh.comments[1][0]['body'].split('```json', 1)[0]
        self.assertEqual(mirror.count('19 November 2026 at 12:00:00 UTC'), 1)
        readme = Path(__file__).with_name('README.md').read_text()
        for message in ('cannot add the stop buttons', 'cannot read the stop reactions', 'Too many stop reactions',
                        'saved review record is damaged', 'Duplicate Changelog comments', 'Notice too long; holding', '2,000'):
            self.assertIn(message, readme)

    def test_lazy_check_read_and_optional_wrong_head_remain_safe(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.calls.clear()
        self.services(gh, dc, NOW + bot.WEEK)
        self.assertEqual(sum(c[0] == 'GET' and '/check-runs' in c[1] for c in gh.calls), 1)
        adapter = bot.GitHub(FakeAPI(gh))
        self.assertIsInstance(adapter.change(gh.prs[1]), str)
        head = gh.prs[1]['head']['sha']
        gh.checks[head].append({'id': 991, 'name': 'optional', 'app': {'slug': 'github-actions'},
                                'head_sha': BASE, 'status': 'completed', 'conclusion': 'success'})
        self.assertFalse(adapter.green(gh.prs[1]))
        self.assertEqual(adapter.waiting_check, 'optional')


    def approve(self, dc, uid='42', name='Maya', emoji='👍', burst=False):
        target = dc.approval_bursts if burst else dc.approvals
        target.setdefault(dc.messages[0]['id'], {}).setdefault(emoji, []).append({'id': uid, 'username': name, 'global_name': name})

    def push(self, gh, sha='e'):
        gh.prs[1]['head']['sha'] = sha * 40
        gh.compare_commits.append({'sha': sha * 40, 'parents': [{}]})
        gh.compare_files[0]['patch'] += '\n+changed'
        gh.compare_files[0]['additions'] += 1
        gh.checks[sha * 40] = [dict(gh.checks[next(iter(gh.checks))][0], head_sha=sha * 40)]

    def test_one_human_thumb_merges_day_one_with_approved_names(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        self.approve(dc)
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        self.assertTrue(gh.prs[1]['merged'])
        self.assertTrue(visible(dc.messages[0]).endswith('Approved by Maya. ' + bot.MERGED))
        self.assertIn('Approved by Maya.', gh.comments[1][0]['body'])
        self.services(gh, dc, NOW + timedelta(days=1, hours=1))
        self.assertTrue(visible(dc.messages[0]).endswith('Approved by Maya. ' + bot.MERGED))

    def test_counting_thumb_withdrawn_during_the_final_read_cannot_merge_beside_a_stale_thumb(self):
        def run(read):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.approve(dc, '43', 'Alex'); self.push(gh)
            self.services(gh, dc, NOW + timedelta(days=1), 'merge')  # Alex's thumb predates this version: stale.
            self.assertFalse(gh.prs[1]['merged'])
            self.approve(dc)
            original = dc.__call__; reads = 0; refused = False
            def withdrawn(method, path, body):
                nonlocal reads
                if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                    reads += 1
                    if reads == read:
                        thumbs = dc.approvals[dc.messages[0]['id']]
                        thumbs['👍'] = [user for user in thumbs['👍'] if user['id'] != '42']
                return original(method, path, body)
            gh.now = dc.now = NOW + timedelta(days=2)
            try:
                bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(withdrawn), '123456'), 1, 'merge', gh.now)
            except bot.Refused:
                refused = True
            return gh.prs[1]['merged'], refused, reads, visible(dc.messages[0])
        merged, refused, reads, notice = run(0)
        self.assertTrue(merged); self.assertFalse(refused); self.assertIn('Approved by Maya.', notice)
        outcomes = [run(read) for read in range(1, reads + 1)]
        self.assertFalse(any(merged for merged, *_ in outcomes))
        # Withdrawn after the people were listed: only the last snapshot can show it, so the run retries.
        self.assertEqual([refused for _, refused, *_ in outcomes][-1], True)
        self.assertNotIn('Approved by', outcomes[-1][3])

    def test_stop_always_wins_and_removed_final_approval_cannot_merge_early(self):
        for late_stop in (False, True):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.approve(dc)
            if not late_stop: dc.users[dc.messages[0]['id']] = [{'id': '43', 'username': 'Alex'}]
            original = dc.__call__; reads = 0
            def final_stop(method, path, body):
                nonlocal reads
                if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                    reads += 1
                    if reads == 2: dc.users[dc.messages[0]['id']] = [{'id': '43', 'username': 'Alex'}]
                return original(method, path, body)
            gh.now = dc.now = NOW + timedelta(days=1)
            calls_before = len(gh.calls)
            bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(final_stop), '123456'), 1, 'merge', gh.now)
            if not late_stop:
                self.assertEqual(sum(c[0] == 'GET' and c[1].endswith('/pulls/1') for c in gh.calls[calls_before:]), 1)
            self.assertFalse(gh.prs[1]['merged'])
            status = visible(dc.messages[0]).split('\n\n')[-1]
            self.assertIn('On hold:', status); self.assertNotIn('👍', status)
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        original = dc.__call__; reads = 0
        def removed(method, path, body):
            nonlocal reads
            if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                reads += 1
                if reads == 2: dc.approvals.clear()
            return original(method, path, body)
        gh.now = dc.now = NOW + timedelta(days=1)
        bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(removed), '123456'), 1, 'merge', gh.now)
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('Goes live as soon as', visible(dc.messages[0]))

        for changed in ('approval-policy', 'fingerprint', 'clock'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.approve(dc)
            original = dc.__call__; reads = 0
            def changed_record(method, path, body):
                nonlocal reads
                result = original(method, path, body)
                if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                    reads += 1
                    if reads == 2:
                        record = bot.Discord(FakeAPI(dc), '123456').record(result, 1)
                        if changed == 'approval-policy': record.pop('approval_policy')
                        elif changed == 'fingerprint': record['fingerprint'] = 'f' * 64
                        else: record['start'] = bot.stamp(NOW + timedelta(hours=1))
                        result['embeds'][0].update(bot.state_embed(1, record))
                return result
            gh.now = dc.now = NOW + timedelta(days=1)
            with self.assertRaises(bot.Refused):
                bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(changed_record), '123456'), 1, 'merge', gh.now)
            self.assertFalse(gh.prs[1]['merged'])

        # Preserve an observed removal even when the person re-adds at the final read.
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc); self.push(gh)
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        dc.approvals.clear(); self.approve(dc, '43', 'Jordan')
        original = dc.__call__; reads = 0
        def regiven_at_final(method, path, body):
            nonlocal reads
            if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                reads += 1
                if reads == 2:
                    dc.approvals.clear(); self.approve(dc)
            return original(method, path, body)
        gh.now = dc.now = NOW + timedelta(days=2)
        bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(regiven_at_final), '123456'), 1, 'merge', gh.now)
        self.assertTrue(gh.prs[1]['merged'])
        self.assertIn('Approved by Maya.', visible(dc.messages[0]))

        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        dc.users[dc.messages[0]['id']] = [{'id': '43', 'username': 'Alex'}]
        original = dc.__call__
        def inconsistent_stop(method, path, body):
            if method == 'GET' and '/reactions/' in path and '%F0%9F%9B%91' in path: return []
            return original(method, path, body)
        gh.now = dc.now = NOW + timedelta(days=1)
        with self.assertRaises(bot.Refused):
            bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(inconsistent_stop), '123456'), 1, 'merge', gh.now)
        self.assertFalse(gh.prs[1]['merged'])

        # Stops are read after approval listing, so a newly arrived stop wins.
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        original = dc.__call__; reads = 0
        def stop_during_approval_read(method, path, body):
            nonlocal reads
            if method == 'GET' and '/reactions/' in path and '%F0%9F%91%8D' in path and 'type=0' in path:
                reads += 1
                if reads == 2: dc.users[dc.messages[0]['id']] = [{'id': '43', 'username': 'Alex'}]
            return original(method, path, body)
        gh.now = dc.now = NOW + timedelta(days=1)
        bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(stop_during_approval_read), '123456'), 1, 'merge', gh.now)
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('On hold: Alex', visible(dc.messages[0]))
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        original = dc.__call__; reads = 0
        def remove_at_last_snapshot(method, path, body):
            nonlocal reads
            if method == 'GET' and path == '/channels/123456/messages/' + dc.messages[0]['id']:
                reads += 1
                if reads == 3: dc.approvals.clear()
            return original(method, path, body)
        gh.now = dc.now = NOW + timedelta(days=1)
        bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(remove_at_last_snapshot), '123456'), 1, 'merge', gh.now)
        self.assertFalse(gh.prs[1]['merged'])

    def test_approval_is_invalidated_by_push_then_regiven_or_second_person(self):
        for second_person in (False, True):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.approve(dc)
            self.push(gh)
            self.services(gh, dc, NOW + timedelta(days=1), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
            self.assertIn("Earlier 👍 don't count for this version. To approve it, remove your 👍, wait 15 minutes, then tap 👍 again.", visible(dc.messages[0]))
            self.services(gh, dc, NOW + timedelta(days=2), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
            if second_person: self.approve(dc, '43', 'Jordan')
            else:
                dc.approvals.clear()
                self.services(gh, dc, NOW + timedelta(days=2, hours=1), 'merge')
                self.approve(dc)
            self.services(gh, dc, NOW + timedelta(days=2, hours=2), 'merge')
            self.assertTrue(gh.prs[1]['merged'])
            self.assertIn('Approved by ' + ('Jordan' if second_person else 'Maya'), visible(dc.messages[0]))

    def test_note_edit_preserves_approval_draft_ready_invalidates_it(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        gh.prs[1]['body'] = BODY.replace('Friends', 'All friends')
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        self.assertTrue(gh.prs[1]['merged'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        gh.prs[1]['draft'] = True
        # REST is stale draft while the ready transition has already arrived.
        gh.timeline.append({'event': 'ready_for_review', 'id': 10})
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        gh.prs[1]['draft'] = False
        self.services(gh, dc, NOW + timedelta(days=2), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        record = bot.Discord(FakeAPI(dc), '123456').record(dc.messages[0], 1)
        self.assertEqual(bot.date(record['start']), NOW + timedelta(days=2))
        self.assertEqual(record['stale_approvals'], ['42'])

    def test_skin_tones_super_author_and_bot_own_approval_rules(self):
        tones = ['👍', '👍🏻', '👍🏼', '👍🏽', '👍🏾', '👍🏿']
        self.assertEqual(list(bot.THUMBS), tones)
        for emoji in tones:
            for burst in (False, True):
                gh, dc = ServiceGitHub(), ServiceDiscord()
                self.services(gh, dc, NOW); self.approve(dc, emoji=emoji, burst=burst)
                self.services(gh, dc, NOW + timedelta(days=1), 'merge')
                self.assertTrue(gh.prs[1]['merged'], (emoji, burst))
        for uid, robot in (('1', True), ('777', True)):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            self.approve(dc, uid=uid)
            dc.approvals[dc.messages[0]['id']]['👍'][0]['bot'] = robot
            self.services(gh, dc, NOW + timedelta(days=1), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc, uid='123', name='LLRHook')
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        self.assertTrue(gh.prs[1]['merged'])

        invalid = bot.Discord(FakeAPI(lambda *args: [{'id': 'invalid', 'username': 'Ghost'}]), '123456')
        invalid.bot = '1'
        with self.assertRaises(bot.Refused): invalid.holders('500', '👍', people=True)

    def test_stop_reaction_without_a_count_still_holds_an_approved_change(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        dc.users[dc.messages[0]['id']] = [{'id': '43', 'username': 'Sam'}]
        # Discord has not always sent a count with a reaction; no count is not "nobody".
        def no_stop_count(method, path, body):
            result = dc(method, path, body)
            for message in result if isinstance(result, list) else [result]:
                for reaction in message.get('reactions', []) if isinstance(message, dict) else []:
                    if reaction['emoji']['name'] == bot.STOP:
                        reaction.pop('count', None); reaction.pop('count_details', None)
            return result
        gh.now = dc.now = NOW + timedelta(days=1)
        bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(no_stop_count), '123456'), 1, 'merge', gh.now)
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('On hold: Sam tapped 🛑', visible(dc.messages[0]))

    def test_approved_path_preserves_every_fresh_merge_gate(self):
        for defect in ('head', 'body', 'ready', 'fingerprint', 'draft', 'base', 'closed', 'checks', 'conflict', 'identity'):
            self.setUp(); self.run_bot(); self.dc.thumbs = {'42': 'Maya'}; self.now += timedelta(days=1)
            if defect == 'checks': self.gh.is_green = False
            elif defect == 'conflict': self.gh.data['mergeable_state'] = 'dirty'
            elif defect == 'identity': self.gh.identity_ok = False
            else:
                def race(gh):
                    if defect == 'head': gh.data['head']['sha'] = 'e' * 40
                    elif defect == 'body': gh.data['body'] += ' '
                    elif defect == 'ready': gh.transitions.append({'event': 'ready_for_review', 'id': 9})
                    elif defect == 'fingerprint': gh.fingerprint = 'e' * 64
                    elif defect == 'draft': gh.data['draft'] = True
                    elif defect == 'base': gh.data['base']['sha'] = 'e' * 40
                    elif defect == 'closed': gh.data['state'] = 'closed'
                self.gh.before_fresh = race
            self.run_bot()
            self.assertFalse(self.gh.merges, defect)
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW); self.approve(dc)
        gh.prs[1]['body'] = ''
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('Paused:', visible(dc.messages[0]))

    def test_approved_post_mode_missing_token_and_other_author_only_change_wording(self):
        for kind in ('post', 'missing-token', 'other'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            if kind == 'other': gh.prs[1]['user']['login'] = 'friend-dev'
            self.services(gh, dc, NOW); self.approve(dc)
            # Non-clean state must not replace the approved manual/post message.
            gh.prs[1]['mergeable_state'] = 'blocked'
            gh.now = dc.now = NOW + timedelta(days=1)
            client = bot.GitHub(FakeAPI(gh), None if kind == 'missing-token' else FakeAPI(gh))
            bot.reconcile(client, bot.Discord(FakeAPI(dc), '123456'), 1, 'post' if kind == 'post' else 'merge', gh.now)
            self.assertFalse(gh.prs[1]['merged'])
            self.assertIn('Maya tapped 👍.', visible(dc.messages[0]))
            self.assertIn('put it live by hand' if kind == 'other' else 'owner switches it on', visible(dc.messages[0]))

    def test_legacy_lost_or_damaged_approval_records_fail_closed_until_regiven(self):
        for damage in ('legacy', 'invalid-policy', 'damaged'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.approve(dc)
            adapter = bot.Discord(FakeAPI(dc), '123456')
            state = adapter.record(dc.messages[0], 1)
            if damage == 'legacy':
                for key in list(state):
                    if key.startswith('approval_') or key == 'stale_approvals': state.pop(key)
            elif damage == 'invalid-policy': state['stale_approvals'] = 'not-a-list'
            if damage == 'damaged': dc.messages[0]['embeds'][0]['url'] = dc.messages[0]['embeds'][0]['url'].split('#')[0] + '#changelog-broken'
            else: dc.messages[0]['embeds'][0].update(bot.state_embed(1, state))
            if damage == 'damaged':
                with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=1), 'merge')
            else:
                self.services(gh, dc, NOW + timedelta(days=1), 'merge')
                self.services(gh, dc, NOW + timedelta(days=2), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
            if damage != 'damaged':
                dc.approvals.clear(); self.services(gh, dc, NOW + timedelta(days=2, hours=1))
                self.approve(dc); self.services(gh, dc, NOW + timedelta(days=2, hours=2), 'merge')
                self.assertTrue(gh.prs[1]['merged'])

    def test_approval_recovery_deleted_comment_lost_reply_and_duplicate_notice(self):
        for scenario in ('comment', 'reply', 'duplicate'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            if scenario == 'reply':
                original = dc.__call__
                def lost(method, path, body):
                    result = original(method, path, body)
                    if method == 'POST': raise bot.HTTPFailure(502)
                    return result
                with self.assertRaises(bot.Refused):
                    bot.reconcile(bot.GitHub(FakeAPI(gh)), bot.Discord(FakeAPI(lost), '123456'), 1, 'post', NOW)
            else: self.services(gh, dc, NOW)
            self.approve(dc)
            gh.comments[1] = []
            if scenario == 'duplicate':
                dc.messages.append(dict(copy.deepcopy(dc.messages[0]), id='100099'))
                with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=1), 'merge')
                self.assertFalse(gh.prs[1]['merged'])
            else:
                self.services(gh, dc, NOW + timedelta(days=1), 'merge')
                self.assertTrue(gh.prs[1]['merged'])
            self.assertEqual(len([m for m in dc.messages if m['author']['id'] == '1']), 2 if scenario == 'duplicate' else 1)

    def test_restart_publication_failure_and_late_thumb_cannot_approve_old_version(self):
        for fault in ('none', 'before-followup', 'lost-edit-reply'):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW); self.push(gh)
            original = dc.__call__; patched = False; added = False
            def during_publish(method, path, body):
                nonlocal patched, added
                if method == 'PATCH' and not patched:
                    patched = True
                    self.approve(dc)
                    result = original(method, path, body)
                    if fault == 'lost-edit-reply': raise bot.HTTPFailure(502)
                    return result
                if patched and method == 'GET' and '/messages/' in path and '/reactions/' not in path and not added:
                    added = True
                    if fault == 'before-followup': raise bot.HTTPFailure(502)
                return original(method, path, body)
            gh.now = dc.now = NOW + timedelta(days=1)
            try:
                bot.reconcile(bot.GitHub(FakeAPI(gh), FakeAPI(gh)), bot.Discord(FakeAPI(during_publish), '123456'), 1, 'merge', gh.now)
            except bot.Refused: self.assertNotEqual(fault, 'none')
            self.services(gh, dc, NOW + timedelta(days=2), 'merge')
            self.assertFalse(gh.prs[1]['merged'])
            record = bot.Discord(FakeAPI(dc), '123456').record(dc.messages[0], 1)
            self.assertEqual(record['stale_approvals'], ['42'])
            dc.approvals.clear(); self.services(gh, dc, NOW + timedelta(days=2, hours=1))
            self.approve(dc); self.services(gh, dc, NOW + timedelta(days=2, hours=2), 'merge')
            self.assertTrue(gh.prs[1]['merged'])

    def test_approval_state_is_bounded_and_overflow_requires_all_thumbs_gone(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        for uid in range(42, 62): self.approve(dc, str(uid), 'Member ' + str(uid))
        self.push(gh)
        self.services(gh, dc, NOW + timedelta(days=1), 'merge')
        record = bot.Discord(FakeAPI(dc), '123456').record(dc.messages[0], 1)
        self.assertEqual(len(record['stale_approvals']), 8)
        self.assertTrue(record['approval_overflow'])
        dc.approvals[dc.messages[0]['id']]['👍'] = dc.approvals[dc.messages[0]['id']]['👍'][-1:]
        self.services(gh, dc, NOW + timedelta(days=2), 'merge')
        self.assertFalse(gh.prs[1]['merged'])
        dc.approvals.clear(); self.services(gh, dc, NOW + timedelta(days=2, hours=1))
        self.approve(dc); self.services(gh, dc, NOW + timedelta(days=2, hours=2), 'merge')
        self.assertTrue(gh.prs[1]['merged'])

    def test_seed_only_reactions_do_not_list_and_schedule_budget_is_bounded(self):
        gh, dc = ServiceGitHub(opened=10), ServiceDiscord()
        self.services(gh, dc, NOW)
        gh.calls.clear(); dc.calls.clear()
        self.services(gh, dc, NOW + timedelta(minutes=15))
        self.assertEqual((len(gh.calls), len(dc.calls)), (62, 11))
        self.assertFalse(any('/reactions/' in c[1] for c in dc.calls))
        self.assertFalse(any(c[0] != 'GET' for c in gh.calls + dc.calls))
        self.assertEqual(4 * 62 + 15 * 6, 338)
        self.assertLess(338, 500)
        workflow = (Path(__file__).parents[2] / '.github/workflows/changelog-schedule.yml').read_text()
        self.assertIn("7,22,37,52 * * * *", workflow)



if __name__ == '__main__':
    with patch('socket.socket.connect', side_effect=AssertionError('network forbidden in offline tests')):
        unittest.main(verbosity=2)
