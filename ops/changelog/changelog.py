"""Changelog: trusted-main, API-only Discord notice and seven-day squash gate.

No PR code is fetched or executed. All network mutations pass through API.request;
--dry-run makes that boundary read-only.
"""
import argparse
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

REPO = 'LLRHook/checksinmyhead'
AUTHOR = ('Victor Ivanov', 'victor.n.ivanov@gmail.com')
STOP = '🛑'
WEEK = timedelta(days=7)
COMMENT = '<!-- changelog:state:v1 -->'
START, END = '<!-- changelog:start -->', '<!-- changelog:end -->'
CHECK = 'Changelog note'
REQUIRED_CHECK = 'Required delivery checks'


class Refused(ValueError):
    """Safe-to-log failure; never include response bodies or credentials."""


def require(value, reason):
    if not value:
        raise Refused(reason)


def compact(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def stamp(now):
    return now.astimezone(timezone.utc).isoformat(timespec='seconds')


def date(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    require(result.tzinfo is not None, 'Clock has no timezone')
    return result


def safe(text):
    # Disable markdown/links, mentions, invisible controls and line-based spoofing.
    text = ''.join(c for c in text if c == '\n' or (c.isprintable() and c not in '\u202a\u202b\u202c\u202d\u202e'))
    text = text.replace('@', '＠').replace('<', '‹').replace('>', '›')
    return re.sub(r'([\\`*_~|\[\]()#])', r'\\\1', text)


def clip(text, units):
    return text.encode('utf-16-le')[:units * 2].decode('utf-16-le', errors='ignore')


def note(body):
    require(isinstance(body, str) and body.startswith(START) and body.count(START) == body.count(END) == 1,
            'Start the description with the Changelog note markers')
    text = body.split(START, 1)[1].split(END, 1)[0].strip()
    match = re.fullmatch(r'\*\*What changed:\*\*\s*(.+?)\s*\*\*Why:\*\*\s*(.+)', text, re.S)
    require(match, 'Fill in What changed and Why')
    for part in match.groups():
        require(len(part.strip()) >= 12 and not re.search(
            r'one to three sentences|one or two sentences|\b(?:TODO|TBD|placeholder)\b', part, re.I),
            'Replace the template text with a real note')
    output = 'What changed: ' + safe(match[1]) + '\n\nWhy: ' + safe(match[2])
    require(len(output.encode('utf-16-le')) // 2 <= 1100, 'Changelog note exceeds 1100 characters after escaping; shorten it')
    return output


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class API:
    def __init__(self, base, token, scheme='Bearer', dry_run=False):
        self.base, self.token, self.scheme, self.dry_run = base, token, scheme, dry_run
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, path, body=None):
        require(path.startswith('/') and not path.startswith('//'), 'Invalid API path')
        if self.dry_run and method != 'GET':
            print('DRY RUN: ' + method + ' ' + self.base + path)
            return {}
        headers = {'Authorization': self.scheme + ' ' + self.token, 'Content-Type': 'application/json',
                   'User-Agent': 'Billington-Changelog', 'Accept': 'application/json'}
        if self.base == 'https://api.github.com':
            headers['X-GitHub-Api-Version'] = '2022-11-28'
        request = urllib.request.Request(self.base + path, data=None if body is None else compact(body).encode(),
                                         headers=headers, method=method)
        try:
            with self.opener.open(request, timeout=30) as response:
                raw = response.read(8_000_001)
                require(len(raw) <= 8_000_000, 'API response too large')
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            # Do not retry writes after an uncertain result. The next run recovers
            # from Discord history / fresh GitHub merged state, including HTTP429.
            raise Refused('API HTTP ' + str(error.code) + '; retry on the next run') from None
        except (OSError, ValueError):
            raise Refused('API unavailable or invalid response; retry on the next run') from None

    def pages(self, path, key=None):
        values = []
        for page in range(1, 101):
            result = self.request('GET', path + ('&' if '?' in path else '?') + f'per_page=100&page={page}')
            batch = result[key] if key else result
            require(isinstance(batch, list), 'Invalid paginated API response')
            values.extend(batch)
            if len(batch) < 100:
                return values
        raise Refused('API pagination limit reached')


class GitHub:
    def __init__(self, api, merge_api=None, proof='', dry_run=False):
        self.api, self.merge_api, self.proof, self.dry_run = api, merge_api, proof, dry_run
        self.root = '/repos/' + REPO

    def pr(self, number):
        return self.api.request('GET', self.root + '/pulls/' + str(number))

    def pulls(self):
        # Include closed PRs so a missed close event is reconciled on schedule.
        return self.api.pages(self.root + '/pulls?state=all&sort=updated&direction=desc')

    def timeline(self, number):
        return self.api.pages(self.root + '/issues/' + str(number) + '/timeline')

    def change(self, pr):
        """Stable through a clean merge-main update, conservative on ambiguity.

        Keep unique non-merge commit IDs AND the net diff. Adding/removing/rebasing
        any own commit restarts. Main merge commits are ignored only in the commit
        set; their resolutions still alter the net diff. Hunk coordinates alone
        are ignored, allowing upstream line insertions to move unchanged hunks.
        """
        head, base = pr['head']['sha'], pr['base']['sha']
        try:
            result = self.api.request('GET', self.root + '/compare/' + base + '...' + head + '?per_page=100')
        except Refused:
            return None, []
        files, commits = result.get('files'), result.get('commits')
        if (not isinstance(files, list) or not isinstance(commits, list) or len(files) >= 300
                or result.get('total_commits') != len(commits) or len(commits) >= 100):
            return None, []
        changes = []
        for f in files:
            patch = f.get('patch')
            # Missing/truncated patches (including binary files) cannot prove an
            # unchanged change; the caller restarts every time until resolvable.
            if not isinstance(patch, str) or not patch:
                return None, [f['filename'] for f in files]
            added = sum(line.startswith('+') for line in patch.splitlines())
            removed = sum(line.startswith('-') for line in patch.splitlines())
            if added != f.get('additions') or removed != f.get('deletions'):
                return None, [f['filename'] for f in files]
            changes.append([f['filename'], f.get('previous_filename'), f['status'],
                            re.sub(r'(?m)^@@ -\d+(,\d+)? \+\d+(,\d+)? @@', r'@@ -\1 +\2 @@', patch)])
        own = sorted(c['sha'] for c in commits if len(c['parents']) == 1)
        fingerprint = hashlib.sha256(compact([sorted(changes), own]).encode()).hexdigest()
        return fingerprint, [f['filename'] for f in files]

    def files(self, pr):
        files = self.api.pages(self.root + '/pulls/' + str(pr['number']) + '/files')
        require(len(files) == pr['changed_files'], 'Incomplete PR file list')
        return [f['filename'] for f in files]

    def check(self, pr, error):
        body = {'name': CHECK, 'head_sha': pr['head']['sha'], 'status': 'completed',
                'conclusion': 'failure' if error else 'success',
                'output': {'title': error or 'Note ready', 'summary': error or 'The note is ready for Changelog.'}}
        if self.dry_run:
            print('DRY RUN: note check ' + body['conclusion'])
            return
        runs = self.api.pages(self.root + '/commits/' + pr['head']['sha'] + '/check-runs?filter=latest', 'check_runs')
        existing = [r for r in runs if r['name'] == CHECK and r['app']['slug'] == 'github-actions']
        if existing:
            body.pop('head_sha'); body.pop('name')
            self.api.request('PATCH', self.root + '/check-runs/' + str(existing[-1]['id']), body)
        else:
            self.api.request('POST', self.root + '/check-runs', body)

    def green(self, pr):
        head = pr['head']['sha']
        runs = self.api.pages(self.root + '/commits/' + head + '/check-runs?filter=latest', 'check_runs')
        # The mandatory delivery context must be a completed Actions check on this
        # exact head. Unknown/pending/skipped/neutral checks never count as green.
        required = [r for r in runs if r['name'] == REQUIRED_CHECK and r['app']['slug'] == 'github-actions']
        if not required or any(r.get('head_sha') != head or r.get('status') != 'completed'
                               or r.get('conclusion') != 'success' for r in runs):
            return False
        statuses = self.api.pages(self.root + '/commits/' + head + '/statuses')
        latest = {}
        for status in statuses:
            latest.setdefault(status['context'], status)
        return all(s['state'] == 'success' for s in latest.values())

    def previous_notice(self, number):
        comments = self.api.pages(self.root + '/issues/' + str(number) + '/comments')
        return any(c['user']['login'] == 'github-actions[bot]' and c['body'].startswith(COMMENT) for c in comments)

    def mirror(self, number, state, message, text):
        if self.dry_run:
            print('DRY RUN: mirror PR #' + str(number))
            return
        comments = self.api.pages(self.root + '/issues/' + str(number) + '/comments')
        candidates = [c for c in comments if c['user']['login'] == 'github-actions[bot]' and c['body'].startswith(COMMENT)]
        require(len(candidates) <= 1, 'Duplicate Changelog state comments; needs a person')
        body = COMMENT + '\nChangelog: ' + text + '\n\nDiscord message: ' + message + '\n\n```json\n' + compact(state) + '\n```'
        if candidates:
            if candidates[0]['body'] != body:
                self.api.request('PATCH', self.root + '/issues/comments/' + str(candidates[0]['id']), {'body': body})
        else:
            self.api.request('POST', self.root + '/issues/' + str(number) + '/comments', {'body': body})

    def identity(self, pr):
        if (not self.merge_api or not re.fullmatch(r'[1-9][0-9]*', self.proof)
                or pr['user']['login'] != 'LLRHook'):
            return False
        viewer = self.merge_api.request('GET', '/user')
        if (viewer.get('login'), viewer.get('name')) != ('LLRHook', AUTHOR[0]):
            return False
        commits = self.api.pages(self.root + '/pulls/' + str(pr['number']) + '/commits')
        if len(commits) != pr['commits'] or not commits or any(
                (c['commit']['author']['name'], c['commit']['author']['email']) != AUTHOR for c in commits):
            return False
        proof = self.pr(int(self.proof))
        if not proof.get('merged') or proof.get('merged_by', {}).get('login') != viewer['login']:
            return False
        commit = self.api.request('GET', self.root + '/git/commits/' + proof['merge_commit_sha'])
        return (len(commit['parents']) == 1 and
                (commit['author']['name'], commit['author']['email']) == AUTHOR)

    def merge(self, pr):
        if self.dry_run:
            print('DRY RUN: squash merge PR #' + str(pr['number']))
            return None
        query = '''mutation($input:MergePullRequestInput!){mergePullRequest(input:$input){pullRequest{merged mergeCommit{oid author{name email}}}}}'''
        result = self.merge_api.request('POST', '/graphql', {'query': query, 'variables': {'input': {
            'pullRequestId': pr['node_id'], 'expectedHeadOid': pr['head']['sha'], 'mergeMethod': 'SQUASH',
            'authorEmail': AUTHOR[1], 'commitHeadline': pr['title'] + ' (#' + str(pr['number']) + ')',
            'commitBody': ''}}})
        require(not result.get('errors'), 'Merge refused by GitHub; waiting for a person or a later run')
        merged = result['data']['mergePullRequest']['pullRequest']
        require(merged['merged'], 'GitHub did not merge')
        commit = merged['mergeCommit']
        require((commit['author']['name'], commit['author']['email']) == AUTHOR,
                'MERGE IDENTITY INCIDENT: pause Changelog and inspect the merged commit')
        return commit['oid']


class Discord:
    def __init__(self, api, channel):
        self.api, self.channel = api, channel
        self.root = '/channels/' + channel + '/messages'
        self.bot = api.request('GET', '/users/@me')['id']

    def history(self):
        result, before = [], ''
        for _ in range(1000):
            batch = self.api.request('GET', self.root + '?limit=100' + ('&before=' + before if before else ''))
            require(isinstance(batch, list), 'Invalid Discord history')
            result.extend(batch)
            if len(batch) < 100:
                return result
            before = batch[-1]['id']
        raise Refused('Discord history limit reached; waiting for a person')

    def find(self, number):
        marker = 'Changelog ' + REPO + '#' + str(number)
        matches = [m for m in self.history() if m['author']['id'] == self.bot and
                   m.get('embeds') and m['embeds'][0].get('title') == marker]
        require(len(matches) <= 1, 'Duplicate Discord notices; waiting for a person')
        if not matches:
            return None, None
        message = matches[0]
        try:
            state = json.loads(message['embeds'][0]['footer']['text'])
            require(state['version'] == 1 and state['number'] == number, 'Invalid Discord state')
            state['start'] = stamp(max(date(state['start']), date(message['timestamp'])))
            return message, state
        except (KeyError, ValueError, TypeError):
            raise Refused('Invalid Discord state; waiting for a person') from None

    def holders(self, message):
        users = {}
        # Both normal and super reactions count, unique by user ID.
        for kind in (0, 1):
            after = ''
            for _ in range(100):
                path = self.root + '/' + message + '/reactions/' + urllib.parse.quote(STOP) + f'?limit=100&type={kind}'
                batch = self.api.request('GET', path + ('&after=' + after if after else ''))
                for user in batch:
                    if user['id'] != self.bot:
                        users[user['id']] = safe(user.get('global_name') or user['username'])[:60]
                if len(batch) < 100:
                    break
                after = batch[-1]['id']
            else:
                raise Refused('Reaction pagination limit reached; holding')
        return users

    def post(self, number, state, text, message=None):
        payload = {'content': text, 'allowed_mentions': {'parse': [], 'users': [], 'roles': [], 'replied_user': False},
                   'embeds': [{'title': 'Changelog ' + REPO + '#' + str(number), 'footer': {'text': compact(state)}}]}
        require(len(text.encode('utf-16-le')) // 2 <= 2000 and len(compact(state)) <= 2048, 'Notice too long; holding')
        if message:
            if message.get('content') == text and message.get('embeds') == payload['embeds']:
                return message
            return self.api.request('PATCH', self.root + '/' + message['id'], payload)
        payload.update(nonce=hashlib.sha256((REPO + '#' + str(number)).encode()).hexdigest()[:24], enforce_nonce=True)
        return self.api.request('POST', self.root, payload)

    def seed(self, message):
        for emoji in (STOP, '👍'):
            self.api.request('PUT', self.root + '/' + message + '/reactions/' + urllib.parse.quote(emoji) + '/@me')


def eligible(pr):
    return (pr['head']['repo'] is not None and pr['head']['repo']['full_name'] == REPO and
            pr['base']['repo']['full_name'] == REPO and pr['base']['ref'] == 'main' and
            pr['user']['login'] not in ('dependabot[bot]', 'dependabot'))


def render(pr, state, text, status):
    deadline = date(state['start']) + WEEK
    return ('Changelog · #' + str(pr['number']) + ' · ' + clip(safe(pr['title']), 140) + '\n\n' + text + '\n\n' +
            status + '\nEarliest merge: ' + stamp(deadline) + '\n' +
            '🛑 Hold this change · 👍 Thanks (the week stays)\n' +
            'https://github.com/' + REPO + '/pull/' + str(pr['number']))


def reconcile(gh, dc, number, mode, now, dry_run=False):
    require(mode in ('post', 'merge'), 'Changelog is OFF: set CHANGELOG_MODE to post or merge')
    pr = gh.pr(number)
    if not eligible(pr):
        return 'exempt'
    paths = gh.files(pr)
    if paths and set(paths) <= {'bugs.md', 'features.md', 'CHANGELOG.md'}:
        return 'exempt'
    message, old = dc.find(number)
    require(message or not gh.previous_notice(number), 'Discord notice missing; do not discard holds by reposting. Waiting for a person')
    if pr['state'] != 'open':
        if message:
            status = 'Merged · ' + pr['merge_commit_sha'] if pr.get('merged') else 'Closed without merging.'
            dc.post(number, old, render(pr, old, old['note'], status), message)
            gh.mirror(number, old, message['id'], status)
        return 'closed'
    if pr['draft'] and not message:
        return 'draft'
    error = None
    try:
        text = note(pr.get('body'))
    except Refused as exc:
        text, error = (old or {}).get('note', ''), str(exc)
    gh.check(pr, error)
    if not message and (error or pr['draft']):
        return 'missing-note'
    timeline = gh.timeline(number)
    transitions = [e for e in timeline if e.get('event') in ('ready_for_review', 'converted_to_draft', 'reopened')]
    ready = str(transitions[-1]['id']) if transitions else 'initial'
    fingerprint, _ = gh.change(pr)
    state = copy.deepcopy(old) if old else {'version': 1, 'number': number, 'start': stamp(now), 'holds': {}}
    restarted = bool(old and (old.get('fingerprint') != fingerprint or fingerprint is None or old.get('ready') != ready or old.get('cancelled')))
    if restarted or fingerprint is None:
        state['start'] = stamp(now)
    state.update(fingerprint=fingerprint, ready=ready, note=text, cancelled=pr['draft'])
    if pr['draft']:
        state['start'] = stamp(now)
    current = dc.holders(message['id']) if message else {}
    # Bound stored names, keeping the exact total in the status; reaction data is
    # freshly re-read before merging, never trusted from this persisted summary.
    state['holds'] = {uid: old.get('holds', {}).get(uid, stamp(now)) if old else stamp(now)
                      for uid in sorted(current)[:8]}
    status = 'Waiting for the full seven days.'
    if restarted:
        status = 'Restarted: the change or ready status changed. A new seven days starts now.'
    if fingerprint is None:
        status = 'Restarted: GitHub could not prove the full change. Waiting for a complete comparison.'
    if current:
        names = ', '.join(current[uid] + ' [' + uid + '] since ' + state['holds'][uid] for uid in state['holds'])
        status = 'HELD by ' + str(len(current)) + ' people: ' + clip(names, 220) + '. Remove 🛑 to release; the original deadline stays.'
    if pr['draft']:
        status = 'Draft again. Clock cancelled; a full week starts when ready again.'
    if error:
        status = 'Waiting for the author: ' + error + '.'
    if (restarted or fingerprint is None) and not status.startswith('Restarted') and not pr['draft']:
        status = 'Restarted: a new seven-day window starts now.\n' + status
    due = now >= date(state['start']) + WEEK
    can_merge = due and not current and not error and not pr['draft'] and fingerprint is not None
    if can_merge:
        identity_ok = False
        if mode == 'merge':
            try:
                identity_ok = gh.identity(pr)
            except Refused:
                identity_ok = False
        if mode != 'merge':
            status = 'The week has passed. Merging is paused; waiting for a person.'
        elif not identity_ok:
            status = 'The week has passed. Merge identity is not proven; waiting for a person.'
        else:
            # Refetch the PR, comparison, note, timeline, head checks and reactions
            # immediately before the conditional expectedHeadOid mutation.
            fresh = gh.pr(number)
            fresh_transitions = [e for e in gh.timeline(number) if e.get('event') in ('ready_for_review', 'converted_to_draft', 'reopened')]
            fresh_ready = str(fresh_transitions[-1]['id']) if fresh_transitions else 'initial'
            if (not eligible(fresh) or fresh['draft'] or fresh['state'] != 'open' or
                    fresh['head']['sha'] != pr['head']['sha'] or fresh['base']['sha'] != pr['base']['sha'] or
                    fresh.get('body') != pr.get('body') or fresh_ready != ready or gh.change(fresh)[0] != fingerprint):
                status = 'The pull request changed during this run; waiting for a later run.'
            elif not gh.green(fresh):
                status = 'The week has passed. Waiting for green checks on this exact change.'
            elif fresh.get('mergeable') is not True or fresh.get('mergeable_state') != 'clean':
                status = 'The week has passed. Waiting for a clean merge (conflict, protection, or GitHub still checking).'
            elif dc.holders(message['id']):
                status = 'HELD: a stop reaction arrived; waiting for a later run.'
            else:
                try:
                    commit = gh.merge(fresh)
                    status = 'Would squash merge now.' if dry_run else 'Merged · ' + commit
                except Refused as exc:
                    status = str(exc)
    if dry_run:
        print('DRY RUN: PR #' + str(number) + ': ' + status)
        return status
    posted = dc.post(number, state, render(pr, state, text, status), message)
    if not message:
        # Discord's timestamp is the actual start, including a recovered nonce.
        state['start'] = stamp(max(date(state['start']), date(posted['timestamp'])))
        posted = dc.post(number, state, render(pr, state, text, status), posted)
    dc.seed(posted['id'])
    gh.mirror(number, state, posted['id'], status)
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    env = os.environ
    require(env.get('GITHUB_REPOSITORY') == REPO, 'Wrong repository')
    require(env.get('GITHUB_EVENT_NAME') in ('pull_request_target', 'schedule'), 'Wrong event')
    require(env.get('CHANGELOG_MODE') in ('post', 'merge'), 'Changelog OFF or unconfigured: no API calls made')
    require(env.get('GITHUB_TOKEN') and env.get('CHANGELOG_DISCORD_BOT_TOKEN'), 'Missing API credentials: no API calls made')
    require(re.fullmatch(r'[1-9][0-9]{5,24}', env.get('CHANGELOG_DISCORD_CHANNEL_ID', '')), 'Missing/invalid CHANGELOG_DISCORD_CHANNEL_ID')
    event = json.loads(open(env['GITHUB_EVENT_PATH']).read())
    if env['GITHUB_EVENT_NAME'] == 'pull_request_target':
        require(event['repository']['full_name'] == REPO, 'Wrong event repository')
        if not eligible(event['pull_request']):
            print('Exempt event; no API calls made')
            return
    gh_api = API('https://api.github.com', env['GITHUB_TOKEN'], dry_run=args.dry_run)
    merge_api = API('https://api.github.com', env['CHANGELOG_MERGE_TOKEN'], dry_run=args.dry_run) if env.get('CHANGELOG_MERGE_TOKEN') else None
    gh = GitHub(gh_api, merge_api, env.get('CHANGELOG_IDENTITY_PROOF_PR', ''), args.dry_run)
    dc = Discord(API('https://discord.com/api/v10', env['CHANGELOG_DISCORD_BOT_TOKEN'], 'Bot', args.dry_run), env['CHANGELOG_DISCORD_CHANNEL_ID'])
    numbers = [event['number']] if env['GITHUB_EVENT_NAME'] == 'pull_request_target' else [pr['number'] for pr in gh.pulls()]
    failed = False
    for number in numbers:
        try:
            print('PR #' + str(number) + ': ' + reconcile(gh, dc, number, env['CHANGELOG_MODE'], datetime.now(timezone.utc), args.dry_run))
        except Refused as exc:
            failed = True
            print('::error::PR #' + str(number) + ': ' + str(exc))
    require(not failed, 'Some pull requests could not be reconciled; no unsafe fallback was used')


if __name__ == '__main__':
    try:
        main()
    except (Refused, KeyError, TypeError, ValueError) as exc:
        print('::error::' + (str(exc) if isinstance(exc, Refused) else 'Invalid API data or configuration; no unsafe fallback'), file=sys.stderr)
        sys.exit(1)
