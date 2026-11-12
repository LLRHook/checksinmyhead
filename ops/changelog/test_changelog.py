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
            'created_at': bot.stamp(NOW), 'updated_at': bot.stamp(NOW), 'closed_at': None, 'changed_files': 1, 'commits': 1, 'merge_commit_sha': 'd' * 40}


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
        self.reads = 0

    def pr(self, number):
        self.reads += 1
        if self.reads % 2 == 0 and self.before_fresh:
            self.before_fresh(self)
        return copy.deepcopy(self.data)

    def files(self, pr):
        return self.paths

    def change(self, pr):
        return self.fingerprint, self.paths

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
        return self.identity_ok

    def audit(self, pr):
        pass

    def merge(self, pr):
        self.merges.append(copy.deepcopy(pr))
        self.data.update(state='closed', merged=True)
        return 'd' * 40


class FakeDiscord:
    def __init__(self):
        self.message, self.state = None, None
        self.users, self.created, self.edited, self.seeds = {}, 0, 0, []
        self.before_final = None
        self.holder_reads = 0
        self.rate_limit = False
        self.now = NOW

    def find(self, number, hint=None):
        return copy.deepcopy(self.message), copy.deepcopy(self.state)

    def pending_clear(self):
        return True

    def holders(self, message):
        self.holder_reads += 1
        if self.before_final and self.holder_reads % 2 == 0:
            self.before_final(self)
        return self.users.copy()

    def post(self, number, state, text, message=None):
        if self.rate_limit:
            raise bot.Refused('API HTTP 429; retry on the next run')
        if message:
            self.edited += 1
        else:
            self.created += 1
        self.message = {'id': '500', 'timestamp': (self.message or {}).get('timestamp', bot.stamp(self.now)), 'content': text}
        self.state = copy.deepcopy(state)
        return copy.deepcopy(self.message)

    def problem(self, number, text):
        if self.message:
            self.message['content'] = text

    def seed(self, message):
        self.seeds.append(message)


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
        self.assertIn('seven days start again', status)
        self.assertIn('HELD by 20', status)
        self.assertLessEqual(len(self.dc.message['content'].encode('utf-16-le')) // 2, 2000)
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
        self.assertIn('Our friends', self.dc.message['content'])
        self.gh.fingerprint = 'e' * 64
        self.gh.data['head']['sha'] = 'c' * 40
        self.assertIn('seven days start again', self.run_bot())
        restart = self.dc.state['start']
        self.dc.users = {'42': 'Alex', '43': 'Sam'}
        self.now += bot.WEEK
        self.assertIn('HELD by 2', self.run_bot())
        self.assertIn('Alex', self.dc.message['content'])
        self.assertNotIn('[42]', self.dc.message['content'])
        self.assertEqual(self.gh.merges, [])
        self.dc.users.clear()
        self.assertIn('Merged', self.run_bot())
        self.assertEqual(self.dc.state['start'], restart)
        self.assertEqual(len(self.gh.merges), 1)
        self.assertEqual(self.dc.created, 1)
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_seven_days_exact_boundary_and_approval_cannot_shorten(self):
        self.posted()
        self.now -= timedelta(seconds=1)
        self.run_bot()
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
        self.assertIn('wait is cancelled', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.gh.data['draft'] = False
        self.gh.transitions.append({'event': 'ready_for_review', 'id': 2})
        self.assertIn('seven days start again', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.now += bot.WEEK
        self.run_bot()
        self.assertEqual(len(self.gh.merges), 1)

    def test_missed_draft_and_ready_events_reset_from_timeline(self):
        self.posted()
        self.gh.transitions += [{'event': 'converted_to_draft', 'id': 2}, {'event': 'ready_for_review', 'id': 3}]
        self.assertIn('seven days start again', self.run_bot())
        self.assertFalse(self.gh.merges)

    def test_closed_without_merging_updates_same_post(self):
        self.posted()
        self.gh.data['state'] = 'closed'
        self.assertEqual(self.run_bot(), 'closed')
        self.assertIn('Closed without merging', self.dc.message['content'])
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
        self.assertIn('Waiting for the author', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.assertEqual(self.dc.created, 1)

    def test_red_checks_and_merge_conflict_retry_after_deadline(self):
        self.posted()
        self.gh.is_green = False
        self.assertIn('Waiting for this check', self.run_bot())
        self.gh.is_green = True
        self.gh.data['mergeable_state'] = 'dirty'
        self.assertIn('combined safely', self.run_bot())
        self.gh.data['mergeable_state'] = 'clean'
        self.gh.data['mergeable'] = None
        self.assertIn('combined safely', self.run_bot())
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
        self.assertIn('paused', self.run_bot(mode='post'))
        self.gh.identity_ok = False
        self.assertIn('configure the merge account', self.run_bot())
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
        self.assertIn('stop reaction just arrived', self.run_bot())
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
        with self.assertRaises(AssertionError):
            namespace['reconcile'](self.gh, self.dc, 25, 'merge', self.now)
            self.assertFalse(self.gh.merges)


class FakeAPI:
    def __init__(self, handler):
        self.handler, self.calls = handler, []

    def request(self, method, path, body=None, query=False):
        self.calls.append((method, path, copy.deepcopy(body)))
        return self.handler(method, path, body)

    pages = bot.API.pages


class ChangelogAdapterTests(unittest.TestCase):
    def compare(self):
        return {'total_commits': 1, 'commits': [{'sha': HEAD, 'parents': [{'sha': BASE}]}],
                'files': [{'filename': 'app.py', 'status': 'modified', 'additions': 1, 'deletions': 1,
                           'patch': '@@ -1,2 +1,2 @@\n-old\n+new\n same'}]}

    def test_fingerprint_main_merge_stable_own_edits_and_resolution_restart(self):
        result = self.compare()
        gh = bot.GitHub(FakeAPI(lambda *args: result))
        original = gh.change(pull())[0]
        result['files'][0]['patch'] = result['files'][0]['patch'].replace('-1,2 +1,2', '-7,2 +7,2')
        result['commits'].append({'sha': 'c' * 40, 'parents': [{'sha': HEAD}, {'sha': BASE}]})
        result['total_commits'] = 2
        self.assertEqual(gh.change(pull())[0], original)
        result['files'][0]['patch'] = result['files'][0]['patch'].replace('+new', '+resolution')
        self.assertNotEqual(gh.change(pull())[0], original)
        result = self.compare()
        result['commits'][0]['sha'] = 'e' * 40
        self.assertNotEqual(gh.change(pull())[0], original)

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
                    self.assertEqual(gh.change(pull())[0], 'head:' + HEAD)

    def test_checks_exact_head_mandatory_context_and_each_terminal(self):
        head = pull()
        required = {'name': bot.REQUIRED_CHECK, 'app': {'slug': 'github-actions'}, 'head_sha': HEAD, 'status': 'completed', 'conclusion': 'success'}
        runs, statuses = [required], []
        api = FakeAPI(lambda method, path, body: {'check_runs': runs} if 'check-runs' in path else statuses)
        gh = bot.GitHub(api)
        self.assertTrue(gh.green(head))
        for defect in ('missing', 'head', 'pending', 'failure', 'skipped', 'neutral', 'foreign-app'):
            runs = [copy.deepcopy(required)]
            if defect == 'missing': runs = []
            elif defect == 'head': runs[0]['head_sha'] = BASE
            elif defect == 'pending': runs[0]['status'] = 'in_progress'
            elif defect == 'foreign-app': runs[0]['app']['slug'] = 'stranger'
            else: runs[0]['conclusion'] = defect
            with self.subTest(defect=defect): self.assertFalse(gh.green(head))
        runs = [required]
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
        with self.assertRaisesRegex(bot.Refused, '^Merge refused by GitHub;'):
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
        dc.post(25, state, 'hello')
        payload = api.calls[-1][2]
        self.assertTrue(payload['enforce_nonce'])
        self.assertLessEqual(len(payload['nonce']), 25)
        self.assertEqual(payload['allowed_mentions']['parse'], [])
        self.assertEqual(payload['allowed_mentions']['users'], [])
        dc.post(25, state, 'hello', {'id': '500'})
        self.assertEqual(api.calls[-1][2]['allowed_mentions'], payload['allowed_mentions'])
        with self.assertRaises(bot.Refused): dc.post(25, state, 'x' * 2001)
        escaped = bot.note(BODY.replace('Friends', '@everyone <@42> <@&7> `Friends` [click](evil)'))
        self.assertNotIn('@', escaped)
        self.assertNotIn('<', escaped)
        self.assertIn('\\`Friends\\`', escaped)
        self.assertIn('\\[click\\]', escaped)

    def test_discord_history_recovers_post_and_rejects_duplicate_or_foreign(self):
        state = {'version': 1, 'number': 25, 'start': bot.stamp(NOW - timedelta(seconds=1))}
        message = {'id': '500', 'timestamp': bot.stamp(NOW), 'author': {'id': '1'},
                   'embeds': [bot.state_embed(25, state)]}
        history = [message]
        api = FakeAPI(lambda method, path, body: {'id': '1'} if path == '/users/@me' else history)
        dc = bot.Discord(api, '123456')
        recovered, saved = dc.find(25)
        self.assertEqual(recovered['id'], '500')
        self.assertEqual(saved['start'], bot.stamp(NOW))
        history.append(dict(copy.deepcopy(message), id='501'))
        with self.assertRaisesRegex(bot.Refused, 'More than one'): dc.find(25)
        history[-1]['author']['id'] = '2'
        self.assertEqual(dc.find(25)[0]['id'], '500')

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
            self.prs[number].update(state='closed', merged=True, closed_at=bot.stamp(self.now), updated_at=bot.stamp(self.now))
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
        self.messages, self.calls, self.users = [], [], {}
        self.next, self.now = 100000, NOW
        self.failure = None

    def __call__(self, method, path, body):
        from urllib.parse import urlsplit, parse_qs
        self.calls.append((method, path, copy.deepcopy(body)))
        if self.failure:
            raise bot.HTTPFailure(self.failure)
        if path == '/users/@me': return {'id': '1'}
        if urlsplit(path).path == '/channels/123456': return {'guild_id': '444444'}
        if '/messages/search?' in path:
            query = parse_qs(urlsplit(path).query)
            link = query['content'][0]
            matches = [m for m in self.messages if m['author']['id'] == query['author_id'][0] and link in m.get('content', '')]
            return {'total_results': len(matches), 'messages': [[copy.deepcopy(m)] for m in matches]}
        parts = urlsplit(path).path.split('/')
        if method == 'GET' and '/reactions/' in path:
            return copy.deepcopy(self.users.get(parts[4], []))
        if method == 'GET':
            if len(parts) == 4:
                return copy.deepcopy(sorted(self.messages, key=lambda m: -int(m['id']))[:100])
            message = next((m for m in self.messages if m['id'] == parts[4]), None)
            if message is None: raise bot.HTTPFailure(404)
            return copy.deepcopy(message)
        if method == 'POST':
            self.next += 1
            message = dict(id=str(self.next), author={'id': '1'}, timestamp=bot.stamp(self.now))
            self.messages.append(message)
        elif method == 'PATCH':
            message = next(m for m in self.messages if m['id'] == parts[4])
        else:
            return {}
        message.update(content=body['content'])
        if 'embeds' in body:
            message['embeds'] = [dict(copy.deepcopy(embed), type='rich') for embed in body['embeds']]
        return copy.deepcopy(message)

    def noise(self, count):
        for _ in range(count):
            self.next += 1
            self.messages.append(dict(id=str(self.next), author={'id': '777'}, timestamp=bot.stamp(self.now), embeds=[]))


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

    def test_event_reconciles_every_followed_PR_not_just_its_payload(self):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'pull_request_target', 'CHANGELOG_MODE': 'post',
               'GITHUB_TOKEN': 'synthetic-github', 'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord',
               'CHANGELOG_DISCORD_CHANNEL_ID': '123456', 'GITHUB_EVENT_PATH': 'L25-synthetic-event.json'}
        event = {'repository': {'full_name': bot.REPO}, 'number': 1, 'pull_request': pull()}
        def request(api, method, path, body=None):
            return (dc if api.base.startswith('https://discord.com') else gh)(method, path, body)
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py']), patch('builtins.open', mock_open(read_data=json.dumps(event))), patch.object(bot.API, 'request', request), patch('sys.stdout', io.StringIO()):
            bot.main()
        self.assertEqual(len(dc.messages), 2)

    def test_local_rehearsal_selects_one_PR_and_is_refused_in_Actions(self):
        env = {'GITHUB_REPOSITORY': bot.REPO, 'GITHUB_EVENT_NAME': 'schedule', 'CHANGELOG_MODE': 'merge',
               'GITHUB_TOKEN': 'synthetic-github', 'CHANGELOG_DISCORD_BOT_TOKEN': 'synthetic-discord',
               'CHANGELOG_DISCORD_CHANNEL_ID': '123456', 'GITHUB_EVENT_PATH': 'L25-synthetic-event.json'}
        with patch.dict(os.environ, env, clear=True), patch.object(sys, 'argv', ['changelog.py', '--dry-run', '--rehearse', '25']), patch('builtins.open', mock_open(read_data='{}')), patch.object(bot, 'reconcile', return_value='Would merge') as reconcile, patch.object(bot, 'reconcile_all', side_effect=AssertionError('rehearsal must select one')), patch('sys.stdout', io.StringIO()):
            bot.main()
            self.assertEqual(reconcile.call_args.args[2:4], (25, 'merge'))
            self.assertTrue(reconcile.call_args.args[-1])
            os.environ['GITHUB_ACTIONS'] = 'true'
            with self.assertRaisesRegex(bot.Refused, 'local only'): bot.main()
            os.environ.pop('GITHUB_ACTIONS')
            with patch.object(sys, 'argv', ['changelog.py', '--rehearse', '0']), self.assertRaises(bot.Refused): bot.main()

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
            dc.messages.append(dict(id=str(dc.next), author={'id': '1'}, timestamp=state['start'], content='Old notice', embeds=[dict(bot.state_embed(n, state), type='rich')]))
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
        self.assertIn('Merged.', dc.messages[0]['content'])

    def test_one_failed_PR_does_not_stop_other_PRs_and_run_fails(self):
        gh, dc = ServiceGitHub(opened=2), ServiceDiscord()
        gh.compare_failures = 1
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW)
        self.assertEqual(len(dc.messages), 1)
        self.assertIn('change 2', dc.messages[0]['embeds'][0]['title'])
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
        fingerprint = adapter.change(gh.prs[1])[0]
        self.assertFalse(fingerprint.startswith('head:'))
        self.assertTrue(any('page=2' in c[1] for c in gh.calls))
        self.assertEqual(len(adapter._files[(1, gh.prs[1]['head']['sha'])]), 301)
        gh.prs[1]['changed_files'] = 3001
        self.assertEqual(adapter.change(gh.prs[1])[0], 'head:' + gh.prs[1]['head']['sha'])
        # The API's 3000-file limit uses a deterministic head-based clock.
        self.gh.fingerprint = 'head:' + HEAD
        self.gh.data['changed_files'] = 3001
        self.run_bot()
        original = self.dc.state['start']
        self.now += timedelta(days=3); self.run_bot()
        self.assertEqual(self.dc.state['start'], original)
        self.assertIn('large change', self.dc.message['content'])
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
        for kind in ('tracker', 'retarget', 'dependabot'):
            self.setUp(); self.run_bot()
            if kind == 'tracker': self.gh.paths = ['features.md']
            elif kind == 'retarget': self.gh.data['base']['ref'] = 'release'
            else: self.gh.data['user']['login'] = 'dependabot[bot]'
            self.assertEqual(self.run_bot(), 'exempt')
            self.assertNotIn('Earliest merge', self.dc.message['content'])
            self.assertNotIn('Hold this change', self.dc.message['content'])
            self.gh.data.update(state='closed', merged=True)
            self.run_bot()
            self.assertIn('Merged. It will be in the next app build.', self.dc.message['content'])

    def test_phone_states_local_times_no_ids_hashes_or_note_copy(self):
        self.run_bot()
        self.assertIn('<t:', self.dc.message['content'])
        self.assertIn(':R>', self.dc.message['content'])
        self.dc.users = {'301234567890123456': 'Maya'}
        self.run_bot()
        self.assertIn('Maya', self.dc.message['content'])
        self.assertNotIn('301234567890123456', self.dc.message['content'])
        self.assertNotIn('note', self.dc.state)
        embed = bot.state_embed(25, self.dc.state)
        self.assertNotIn(self.gh.fingerprint, embed['footer']['text'])
        self.assertNotIn('{', embed['footer']['text'])
        self.assertLess(len(embed['footer']['text']), 40)
        for state in ('draft', 'merged', 'closed'):
            self.gh.data.update(draft=state == 'draft', state='open' if state == 'draft' else 'closed', merged=state == 'merged')
            self.run_bot()
            self.assertNotIn('Earliest merge', self.dc.message['content'])
            self.assertNotIn('Hold this change', self.dc.message['content'])

    def test_uncertain_create_hidden_by_noise_never_discards_a_live_hold(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        original = copy.deepcopy(dc.messages[0])
        gh.comments[1][0]['body'] = bot.COMMENT + '\nDiscord message: pending\n```json\n' + bot.compact({'ready': '9'}) + '\n```'
        dc.users[original['id']] = [{'id': '42', 'username': 'Maya'}]
        dc.noise(500)
        gh.timeline += [{'event': 'converted_to_draft', 'id': 10}, {'event': 'ready_for_review', 'id': 11}]
        gh.calls.clear(); dc.calls.clear()
        original_handler = dc.__class__.__call__
        def unavailable_search(method, path, body):
            if '/messages/search?' in path:
                raise bot.HTTPFailure(502)
            return original_handler(dc, method, path, body)
        adapter = bot.Discord(FakeAPI(unavailable_search), '123456')
        with patch('sys.stdout', io.StringIO()), self.assertRaises(bot.Refused):
            bot.reconcile_all(bot.GitHub(FakeAPI(gh)), adapter, 'post', NOW + timedelta(days=1))
        self.assertEqual(dc.messages[0], original)
        self.assertFalse(any(c[0] == 'POST' for c in dc.calls))
        self.assertIn('Discord message: pending', gh.comments[1][0]['body'])

    def test_wrong_missing_hint_recovers_old_live_notice_and_keeps_its_hold(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        message_id = dc.messages[0]['id']
        dc.users[message_id] = [{'id': '42', 'username': 'Maya'}]
        dc.noise(500)
        # A writer forges a missing message ID plus an older ready generation.
        gh.comments[1][0]['body'] = bot.COMMENT + '\nDiscord message: 999999999\n```json\n' + bot.compact({'ready': '8'}) + '\n```'
        gh.timeline += [{'event': 'converted_to_draft', 'id': 10}, {'event': 'ready_for_review', 'id': 11}]
        self.services(gh, dc, NOW + timedelta(days=8), 'merge')
        self.assertEqual(len([m for m in dc.messages if m['author']['id'] == '1']), 1)
        self.assertIn('HELD by 1', dc.messages[0]['content'])
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('Discord message: ' + message_id, gh.comments[1][0]['body'])
        self.assertTrue(any('/messages/search?' in c[1] for c in dc.calls))

    def test_deleted_real_notice_recovery_and_unindexed_search_fails_closed(self):
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.messages.clear()
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=1))
        gh.prs[1]['draft'] = True
        gh.timeline.append({'event': 'converted_to_draft', 'id': 10})
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(days=2))
        gh.prs[1]['draft'] = False
        gh.timeline.append({'event': 'ready_for_review', 'id': 11})
        self.services(gh, dc, NOW + timedelta(days=3))
        self.assertEqual(len(dc.messages), 1)
        self.assertFalse(gh.prs[1]['merged'])
        before = copy.deepcopy((gh.comments, dc.messages))
        original_handler = dc.__class__.__call__
        def unindexed(method, path, body):
            if '/messages/search?' in path: return {'code': 110000, 'retry_after': 2}
            return original_handler(dc, method, path, body)
        gh.comments[1][0]['body'] = gh.comments[1][0]['body'].replace(dc.messages[0]['id'], '999999999')
        dc.noise(500)
        with patch('sys.stdout', io.StringIO()), self.assertRaises(bot.Refused):
            bot.reconcile_all(bot.GitHub(FakeAPI(gh)), bot.Discord(FakeAPI(unindexed), '123456'), 'post', NOW + timedelta(days=4))
        self.assertFalse(gh.prs[1]['merged'])
        self.assertIn('Waiting for the full seven days', dc.messages[0]['content'])

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
        for status in (403, 404):
            gh, dc = ServiceGitHub(), ServiceDiscord()
            self.services(gh, dc, NOW)
            dc.failure = status
            with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(hours=1))
            self.assertIn('restore View Channel', gh.comments[1][0]['body'])
        gh, dc = ServiceGitHub(), ServiceDiscord()
        self.services(gh, dc, NOW)
        dc.next += 1; dc.messages.append(dict(copy.deepcopy(dc.messages[0]), id=str(dc.next)))
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + timedelta(hours=1))
        self.assertIn('More than one notice', gh.comments[1][0]['body'])
        self.assertTrue(all('remove the duplicate' in m['content'] for m in dc.messages))

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
        self.assertIn('IDENTITY INCIDENT', dc.messages[0]['content'])
        self.assertIn('IDENTITY INCIDENT', gh.comments[1][0]['body'])
        note = next(run for run in gh.checks[gh.prs[1]['head']['sha']] if run['name'] == bot.CHECK)
        self.assertEqual(note['conclusion'], 'failure')
        with self.assertRaises(bot.Refused): self.services(gh, dc, NOW + bot.WEEK + timedelta(hours=1), 'post')
        self.assertIn('IDENTITY INCIDENT', dc.messages[0]['content'])

    def test_semantic_merge_refusal_updates_notice_without_restarting_week(self):
        self.posted()
        start = self.dc.state['start']
        with patch.object(self.gh, 'merge', side_effect=bot.MergeBlocked('Merge refused by GitHub; waiting for the owner or a later run')):
            self.assertIn('Merge refused', self.run_bot())
        self.assertIn('Merge refused', self.dc.message['content'])
        self.assertEqual(self.dc.state['start'], start)
        self.assertFalse(self.gh.merges)

    def test_other_PR_author_waits_manual_and_identity_incident_is_loud(self):
        self.run_bot(); self.now += bot.WEEK
        self.gh.data['user']['login'] = 'friend'
        self.assertIn('opened by someone else', self.run_bot())
        self.assertFalse(self.gh.merges)
        self.gh.data['user']['login'] = 'LLRHook'
        with patch.object(self.gh, 'merge', side_effect=bot.IdentityIncident('MERGE IDENTITY INCIDENT: stop the bot')):
            with self.assertRaises(bot.IdentityIncident): self.run_bot()
        self.assertIn('IDENTITY INCIDENT', self.dc.message['content'])
        self.assertIn('IDENTITY INCIDENT', self.gh.mirrors[-1][-1])
        self.assertIn('IDENTITY INCIDENT', self.gh.checks[-1])

if __name__ == '__main__':
    with patch('socket.socket.connect', side_effect=AssertionError('network forbidden in offline tests')):
        unittest.main(verbosity=2)
