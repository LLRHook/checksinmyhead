"""Changelog: trusted-main, API-only Discord notice and seven-day squash gate.

No PR code is fetched or executed. All network mutations pass through API.request;
--dry-run makes that boundary read-only.
"""
import base64
import argparse
import copy
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
import re
import sys
import time
import zlib
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


class HTTPFailure(Refused):
    def __init__(self, status):
        self.status = status
        super().__init__('API HTTP ' + str(status) + '; retry on the next run')


class NoticeProblem(Refused):
    """Persistent channel/state problem that needs a visible recovery instruction."""


class IdentityIncident(Refused):
    pass


class MergeBlocked(Refused):
    pass


def require(value, reason):
    if not value:
        raise Refused(reason)


def compact(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def stamp(now):
    return now.astimezone(timezone.utc).isoformat(timespec='microseconds')


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
        for attempt in range(2):
            try:
                with self.opener.open(request, timeout=30) as response:
                    raw = response.read(8_000_001)
                    require(len(raw) <= 8_000_000, 'API response too large')
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as error:
                # Discord documents retry_after in seconds. Honour it once, only
                # when the delay is finite and <= 5s; never retry an uncertain 5xx.
                if self.base == 'https://discord.com/api/v10' and error.code == 429 and attempt == 0:
                    try:
                        delay = json.loads(error.read(4096)).get('retry_after')
                    except (ValueError, OSError):
                        delay = None
                    if type(delay) in (int, float) and 0 <= delay <= 5:
                        time.sleep(delay)
                        continue
                raise HTTPFailure(error.code) from None
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
    def __init__(self, api, merge_api=None, dry_run=False):
        self.api, self.merge_api, self.dry_run = api, merge_api, dry_run
        self._comments, self._files, self._runs = {}, {}, {}
        self.waiting_check = REQUIRED_CHECK
        self.root = '/repos/' + REPO

    def pr(self, number):
        return self.api.request('GET', self.root + '/pulls/' + str(number))

    def pulls(self, now=None):
        now = now or datetime.now(timezone.utc)
        opened = self.api.pages(self.root + '/pulls?state=open&sort=updated&direction=desc')
        recent = []
        cutoff = now - timedelta(days=1)
        for page in range(1, 101):
            batch = self.api.request('GET', self.root + f'/pulls?state=closed&sort=updated&direction=desc&per_page=100&page={page}')
            recent.extend(p for p in batch if date(p['closed_at']) >= cutoff)
            if len(batch) < 100 or date(batch[-1]['updated_at']) < cutoff:
                break
        else:
            raise Refused('Recent pull request pagination exceeded the run budget')
        return opened + recent

    def timeline(self, number):
        return self.api.pages(self.root + '/issues/' + str(number) + '/timeline')

    def change(self, pr):
        """Net diff + own commits; API limits use a stable, exact-head fallback.

        A failed read propagates without changing a notice or its clock. File
        lists beyond compare's 300-file cap use the paginated PR files endpoint.
        Above its 3000-file cap (or 1000 commits/run), any new head starts a week.
        """
        head, base = pr['head']['sha'], pr['base']['sha']
        fallback = ('head:' + head, [])
        path = self.root + '/compare/' + base + '...' + head
        result = self.api.request('GET', path + '?per_page=100&page=1')
        files, commits = result.get('files'), result.get('commits')
        total = result.get('total_commits')
        if not isinstance(files, list) or not isinstance(commits, list) or type(total) is not int or total > 1000:
            return fallback
        page = 1
        while len(commits) < total:
            page += 1
            batch = self.api.request('GET', path + f'?per_page=100&page={page}').get('commits')
            if not batch or page > 10:
                return fallback
            commits += batch
        if len(commits) != total:
            return fallback
        if len(files) != pr['changed_files']:
            self.files(pr)
            files = self._files[(pr['number'], head)]
        if len(files) != pr['changed_files'] or len(files) > 3000:
            return fallback
        changes = []
        for f in files:
            patch = f.get('patch')
            identity = [f['filename'], f.get('previous_filename'), f['status']]
            if not patch:
                if not re.fullmatch('[0-9a-f]{40}', f.get('sha', '')):
                    return fallback
                changes.append(identity + [f['sha']])
                continue
            added = sum(line.startswith('+') for line in patch.splitlines())
            removed = sum(line.startswith('-') for line in patch.splitlines())
            if added != f.get('additions') or removed != f.get('deletions'):
                return fallback
            changes.append(identity + [re.sub(r'(?m)^@@ -\d+(,\d+)? \+\d+(,\d+)? @@', r'@@ -\1 +\2 @@', patch)])
        own = sorted(c['sha'] for c in commits if len(c['parents']) == 1)
        fingerprint = hashlib.sha256(compact([sorted(changes), own]).encode()).hexdigest()
        return fingerprint, [f['filename'] for f in files]

    def files(self, pr):
        key = (pr['number'], pr['head']['sha'])
        if key not in self._files:
            self._files[key] = self.api.pages(self.root + '/pulls/' + str(pr['number']) + '/files') if pr['changed_files'] <= 3000 else []
        files = self._files[key]
        paths = [f['filename'] for f in files]
        return paths if len(files) == pr['changed_files'] else paths + ['incomplete-file-list']

    def prepare_check(self, pr):
        self._runs[pr['head']['sha']] = self.api.pages(self.root + '/commits/' + pr['head']['sha'] + '/check-runs?filter=latest', 'check_runs')

    def check(self, pr, error):
        body = {'name': CHECK, 'head_sha': pr['head']['sha'], 'status': 'completed',
                'conclusion': 'failure' if error else 'success',
                'output': {'title': error or 'Note ready', 'summary': error or 'The note is ready for Changelog.'}}
        if self.dry_run:
            print('DRY RUN: note check ' + body['conclusion'])
            return
        if pr['head']['sha'] not in self._runs:
            self.prepare_check(pr)
        runs = self._runs[pr['head']['sha']]
        existing = [r for r in runs if r['name'] == CHECK and r['app']['slug'] == 'github-actions']
        if existing:
            if (all(existing[-1].get(k) == body[k] for k in ('status', 'conclusion')) and
                    all(existing[-1].get('output', {}).get(k) == body['output'][k] for k in ('title', 'summary'))):
                return
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
        self._runs[head] = runs
        bad = [r for r in runs if r.get('head_sha') != head or r.get('status') != 'completed' or r.get('conclusion') != 'success']
        self.waiting_check = REQUIRED_CHECK if not required else (bad[0]['name'] if bad else '')
        if not required or bad:
            return False
        statuses = self.api.pages(self.root + '/commits/' + head + '/statuses')
        latest = {}
        for status in statuses:
            latest.setdefault(status['context'], status)
        blocked = [s['context'] for s in latest.values() if s['state'] != 'success']
        self.waiting_check = blocked[0] if blocked else ''
        return not blocked

    def comments(self, number):
        if number not in self._comments:
            self._comments[number] = self.api.pages(self.root + '/issues/' + str(number) + '/comments')
        return [c for c in self._comments[number] if c['user']['login'] == 'github-actions[bot]' and c['body'].startswith(COMMENT)]

    def hint(self, number):
        comments = self.comments(number)
        require(len(comments) <= 1, 'Duplicate Changelog comments; ask the owner to keep one')
        if not comments:
            return {}
        match = re.search(r'```json\n(.*?)\n```', comments[0]['body'], re.S)
        try:
            data = json.loads(match[1]) if match else {}
        except ValueError:
            data = {}
        pointer = re.search(r'Discord message: ([0-9]+)', comments[0]['body'])
        return {'message': pointer[1] if pointer else None, 'ready': data.get('ready'), 'exists': True}

    def mirror(self, number, state, message, text):
        if self.dry_run:
            print('DRY RUN: mirror PR #' + str(number))
            return
        candidates = self.comments(number)
        body = COMMENT + '\nChangelog: ' + text + '\n\nDiscord message: ' + (message or 'pending') + '\n\n```json\n' + compact(state) + '\n```'
        if candidates:
            if candidates[0]['body'] != body:
                self.api.request('PATCH', self.root + '/issues/comments/' + str(candidates[0]['id']), {'body': body})
                candidates[0]['body'] = body
        else:
            result = self.api.request('POST', self.root + '/issues/' + str(number) + '/comments', {'body': body})
            self._comments[number] = [dict(result, body=body, user={'login': 'github-actions[bot]'})]

    def identity(self, pr):
        if not self.merge_api or pr['user']['login'] != 'LLRHook':
            return False
        viewer = self.merge_api.request('GET', '/user')
        return (viewer.get('login'), viewer.get('name')) == ('LLRHook', AUTHOR[0])

    def audit(self, pr):
        raw = self.api.request('GET', self.root + '/git/commits/' + pr['merge_commit_sha'])
        if (raw['author']['name'], raw['author']['email']) != AUTHOR:
            raise IdentityIncident('MERGE IDENTITY INCIDENT: the merged author is wrong. Owner: set CHANGELOG_MODE to off and inspect this change.')

    def merge(self, pr):
        if self.dry_run:
            print('DRY RUN: squash merge PR #' + str(pr['number']))
            return None
        query = '''mutation($input:MergePullRequestInput!){mergePullRequest(input:$input){pullRequest{merged mergeCommit{oid author{name email}}}}}'''
        result = self.merge_api.request('POST', '/graphql', {'query': query, 'variables': {'input': {
            'pullRequestId': pr['node_id'], 'expectedHeadOid': pr['head']['sha'], 'mergeMethod': 'SQUASH',
            'authorEmail': AUTHOR[1], 'commitHeadline': pr['title'] + ' (#' + str(pr['number']) + ')',
            'commitBody': ''}}})
        if result.get('errors'):
            raise MergeBlocked('Merge refused by GitHub; waiting for the owner or a later run')
        merged = result['data']['mergePullRequest']['pullRequest']
        if not merged['merged']:
            raise MergeBlocked('The week has passed. GitHub has not merged this change; waiting for the owner or a later run.')
        commit = merged['mergeCommit']
        self.audit(dict(pr, merge_commit_sha=commit['oid']))
        return commit['oid']


def state_embed(number, state):
    # Store full-strength state in the embed link fragment, outside the phone
    # reader's text. The bot-owned message alone still recovers all clock data.
    packed = base64.urlsafe_b64encode(zlib.compress(compact(state).encode())).decode().rstrip('=')
    return {'title': 'Changelog · change ' + str(number),
            'url': 'https://github.com/' + REPO + '/pull/' + str(number) + '#changelog-' + packed,
            'footer': {'text': 'Changelog · review record'}}


class Discord:
    def __init__(self, api, channel):
        self.api, self.channel = api, channel
        self.root = '/channels/' + channel + '/messages'
        self.bot = None
        self.recent = None
        self.affected = {}

    def history(self):
        if self.recent is None:
            self.recent = self.api.request('GET', self.root + '?limit=100')
        return self.recent

    def recover(self, number):
        # A missing/untrusted hint is not proof of deletion. Search only this
        # app's messages, independently of channel history, before any reset.
        channel = self.api.request('GET', '/channels/' + self.channel)
        require(re.fullmatch('[0-9]+', channel.get('guild_id', '')), 'Channel has no server identity')
        query = urllib.parse.urlencode({'channel_id': self.channel, 'author_id': self.bot,
                                       'content': 'https://github.com/' + REPO + '/pull/' + str(number), 'limit': 25})
        result = self.api.request('GET', '/guilds/' + channel['guild_id'] + '/messages/search?' + query)
        require(type(result.get('total_results')) is int and isinstance(result.get('messages'), list),
                'Discord notice search is not indexed or unavailable; retry on the next run')
        require(result['total_results'] < 25, 'Too many matching notices to recover safely; ask the owner to restore the original message link')
        messages = []
        for group in result['messages']:
            messages.extend(group if isinstance(group, list) else [group])
        return messages

    def find(self, number, hint=None):
        try:
            if self.bot is None:
                self.bot = self.api.request('GET', '/users/@me')['id']
            marker = 'Changelog · change ' + str(number)
            matches = [m for m in self.history() if m['author']['id'] == self.bot and
                       m.get('embeds') and m['embeds'][0].get('title') == marker]
            pointer = (hint or {}).get('message')
            if pointer and not any(m['id'] == pointer for m in matches):
                try:
                    fetched = self.api.request('GET', self.root + '/' + pointer)
                except HTTPFailure as exc:
                    if exc.status != 404:
                        raise
                else:
                    if fetched['author']['id'] != self.bot or fetched.get('embeds', [{}])[0].get('title') != marker:
                        raise NoticeProblem('The saved notice link is wrong. Ask the owner to restore the Changelog comment.')
                    matches.append(fetched)
            if not matches and hint:
                recovered = self.recover(number)
                matches = [m for m in recovered if m.get('author', {}).get('id') == self.bot and
                           m.get('embeds') and m['embeds'][0].get('title') == marker]
            self.affected[number] = matches
            if len(matches) > 1:
                raise NoticeProblem('More than one notice exists. Ask the owner to keep the original notice and remove the duplicate, preserving all stop reactions.')
            if not matches:
                return None, None
            message = matches[0]
            embed = message['embeds'][0]
            prefix = 'https://github.com/' + REPO + '/pull/' + str(number) + '#changelog-'
            require(embed.get('url', '').startswith(prefix), 'Invalid Discord review record')
            packed = embed['url'][len(prefix):]
            require(len(packed) <= 1800, 'Review record too large')
            raw = zlib.decompressobj().decompress(base64.urlsafe_b64decode(packed + '=' * (-len(packed) % 4)), 8192)
            state = json.loads(raw)
            require(state['version'] == 1 and state['number'] == number, 'Invalid Discord state')
            state['start'] = stamp(max(date(state['start']), date(message['timestamp'])))
            return message, state
        except HTTPFailure as exc:
            if exc.status in (403, 404):
                raise NoticeProblem('Changelog cannot read this channel. Ask the owner to restore View Channel and Read Message History and check the channel setting.') from None
            raise
        except (KeyError, TypeError, json.JSONDecodeError, zlib.error):
            raise NoticeProblem('The saved review record is damaged. Ask the owner to restore the original notice.') from None

    def pending_clear(self):
        return len(self.history()) < 100

    def holders(self, message):
        users = {}
        for kind in (0, 1):
            after = ''
            for _ in range(100):
                path = self.root + '/' + message + '/reactions/' + urllib.parse.quote(STOP) + f'?limit=100&type={kind}'
                try:
                    batch = self.api.request('GET', path + ('&after=' + after if after else ''))
                except HTTPFailure as exc:
                    if exc.status in (403, 404):
                        raise NoticeProblem('Changelog cannot read the stop reactions. Ask the owner to restore channel access.') from None
                    raise
                for user in batch:
                    if user['id'] != self.bot:
                        users[user['id']] = safe(user.get('global_name') or user['username'])[:60]
                if len(batch) < 100:
                    break
                after = batch[-1]['id']
            else:
                raise NoticeProblem('Too many stop reactions to read safely. Ask the owner to check this notice.')
        return users

    def post(self, number, state, text, message=None):
        embed = state_embed(number, state)
        payload = {'content': text, 'allowed_mentions': {'parse': [], 'users': [], 'roles': [], 'replied_user': False},
                   'embeds': [embed]}
        require(len(text.encode('utf-16-le')) // 2 <= 2000 and len(embed['url']) <= 2048, 'Notice too long; holding')
        try:
            if message:
                returned = message.get('embeds', [{}])[0]
                if (message.get('content') == text and returned.get('title') == embed['title'] and
                        returned.get('url') == embed['url'] and returned.get('footer', {}).get('text') == embed['footer']['text']):
                    return message
                return self.api.request('PATCH', self.root + '/' + message['id'], payload)
            payload.update(nonce=hashlib.sha256((REPO + '#' + str(number) + ':' + state.get('ready', 'initial')).encode()).hexdigest()[:24], enforce_nonce=True)
            return self.api.request('POST', self.root, payload)
        except HTTPFailure as exc:
            if exc.status in (403, 404):
                raise NoticeProblem('Changelog cannot write to this channel. Ask the owner to restore Send Messages and Embed Links and check the channel setting.') from None
            raise

    def seed(self, message):
        for emoji in (STOP, '👍'):
            try:
                self.api.request('PUT', self.root + '/' + message + '/reactions/' + urllib.parse.quote(emoji) + '/@me')
            except HTTPFailure as exc:
                if exc.status in (403, 404):
                    raise NoticeProblem('Changelog cannot add the stop buttons. Ask the owner to restore Add Reactions and channel access.') from None
                raise

    def problem(self, number, text):
        for message in self.affected.get(number, []):
            try:
                self.api.request('PATCH', self.root + '/' + message['id'],
                                 {'content': text, 'allowed_mentions': {'parse': [], 'users': [], 'roles': [], 'replied_user': False}})
            except Refused:
                pass


def eligible(pr):
    return (pr['head']['repo'] is not None and pr['head']['repo']['full_name'] == REPO and
            pr['base']['repo']['full_name'] == REPO and pr['base']['ref'] == 'main' and
            pr['user']['login'] not in ('dependabot[bot]', 'dependabot'))


def local_time(value, style='F'):
    return '<t:' + str(int(date(value).timestamp())) + ':' + style + '>'


def render(pr, state, text, status):
    waiting = pr['state'] == 'open' and not pr['draft'] and not state.get('exempt') and not state.get('finished')
    lines = ['Changelog · ' + clip(safe(pr['title']), 140), text, status]
    if waiting:
        deadline = stamp(date(state['start']) + WEEK)
        lines.append('Earliest merge: ' + local_time(deadline) + ' · ' + local_time(deadline, 'R') +
                     '\n🛑 Hold this change · 👍 Thanks (the week stays)')
    lines.append('https://github.com/' + REPO + '/pull/' + str(pr['number']))
    return '\n\n'.join(lines)


def ready_event(timeline):
    transitions = [e for e in timeline if e.get('event') in ('ready_for_review', 'converted_to_draft', 'reopened')]
    return str(transitions[-1]['id']) if transitions else 'initial'


def notice_text(message, state):
    return message.get('content', '').split('\n\n', 1)[-1][:state.get('note_length', 0)] if message else ''


def prepare_state(pr, old, fingerprint, ready, text, current, now):
    state = copy.deepcopy(old) if old else {'version': 1, 'number': pr['number'], 'start': stamp(now), 'holds': {}}
    restarted = bool(old and (old.get('fingerprint') != fingerprint or old.get('ready') != ready or old.get('cancelled') or old.get('exempt')))
    if restarted:
        state['start'] = stamp(now)
    state.update(fingerprint=fingerprint, ready=ready, cancelled=pr['draft'], note_length=len(text),
                 exempt=False, finished=False)
    state['holds'] = {uid: old.get('holds', {}).get(uid, stamp(now)) if old else stamp(now) for uid in sorted(current)[:8]}
    return state, restarted


def waiting_status(pr, state, error, current, restarted, mode, now):
    # One precedence order for reader-facing state. Terminal states are handled
    # before this function; holds never hide a restart or shorten a deadline.
    if pr['draft']:
        return 'The change is being worked on again. The wait is cancelled; a full week starts when it is shared again.'
    if error:
        return 'Waiting for the author: ' + error + '.'
    prefix = 'The change was updated, so the seven days start again.\n' if restarted else ''
    if current:
        names = ', '.join(current[uid] + ' (since ' + local_time(state['holds'][uid], 'R') + ')' for uid in state['holds'])
        return prefix + 'HELD by ' + str(len(current)) + ' people: ' + clip(names, 220) + '. Remove 🛑 to release; the original deadline stays.'
    if state['fingerprint'].startswith('head:'):
        prefix += 'This is a large change, so any new commit restarts the seven days.\n'
    if now < date(state['start']) + WEEK:
        return prefix + 'Waiting for the full seven days.'
    if mode == 'post':
        return 'The week has passed. Automatic merging is paused; waiting for the owner.'
    if pr['user']['login'] != 'LLRHook':
        return 'The week has passed. This one was opened by someone else, so the owner merges it by hand.'
    return 'The week has passed. Waiting for the owner to configure the merge account.'


def attempt_merge(gh, dc, pr, state, fingerprint, ready, message, status, now, dry_run, mode):
    fresh = gh.pr(pr['number'])
    if (not eligible(fresh) or fresh['draft'] or fresh['state'] != 'open' or
            fresh['head']['sha'] != pr['head']['sha'] or fresh['base']['sha'] != pr['base']['sha'] or
            fresh.get('body') != pr.get('body') or ready_event(gh.timeline(pr['number'])) != ready or gh.change(fresh)[0] != fingerprint):
        return 'The change was updated during this check. Changelog will check it again shortly.'
    elif not gh.green(fresh):
        return 'The week has passed. Waiting for this check: ' + safe(gh.waiting_check) + '.'
    elif fresh.get('mergeable') is not True or fresh.get('mergeable_state') != 'clean':
        return 'The week has passed. The change cannot be combined safely yet; its author needs to resolve that.'
    elif dc.holders(message['id']):
        return 'HELD: a stop reaction just arrived. The change will wait.'
    if mode != 'merge' or pr['user']['login'] != 'LLRHook' or not gh.identity(pr):
        return status
    try:
        gh.merge(fresh)
    except MergeBlocked as exc:
        return str(exc)
    if dry_run:
        return 'Would squash merge now.'
    state.update(finished=True, audited=True)
    return 'Merged. It will be in the next app build.'


def finish_notice(gh, dc, pr, message, old, text, exempt, dry_run):
    state = dict(old or {}, exempt=exempt, finished=pr['state'] != 'open')
    if pr.get('merged'):
        status = 'Merged. It will be in the next app build.'
    elif pr['state'] != 'open':
        status = 'Closed without merging.'
    elif pr['base']['ref'] != 'main':
        status = 'This no longer waits here: it is no longer planned for the main app.'
    elif pr['user']['login'] in ('dependabot', 'dependabot[bot]'):
        status = 'This no longer needs the review week: it is an automatic dependency update.'
    else:
        status = 'This no longer needs the review week: it only changes the tracking lists.'
    if pr.get('merged') and not state.get('audited') and not state.get('incident'):
        try:
            gh.audit(pr)
            state['audited'] = True
        except IdentityIncident as exc:
            state['incident'] = str(exc)
    if state.get('incident'):
        gh.prepare_check(pr)
        status = state['incident']
    if not dry_run:
        if message:
            dc.post(pr['number'], state, render(pr, state, text, status), message)
        gh.mirror(pr['number'], state, message['id'] if message else None, status)
        if state.get('incident'):
            gh.check(pr, status)
            raise IdentityIncident(status)
    return 'closed' if pr['state'] != 'open' else 'exempt'


def reconcile(gh, dc, number, mode, now, dry_run=False):
    require(mode in ('post', 'merge'), 'Changelog is OFF: set CHANGELOG_MODE to post or merge')
    pr = gh.pr(number)
    # Outsiders never reach Discord, checks or comment writes, even on old events.
    if not pr['head']['repo'] or pr['head']['repo']['full_name'] != REPO:
        return 'exempt'
    hint = gh.hint(number)
    if pr['state'] != 'open' and not hint:
        return 'closed'
    error = None
    try:
        text = note(pr.get('body'))
    except Refused as exc:
        text, error = '', str(exc)
    if pr['state'] == 'open':
        gh.prepare_check(pr)
    if pr['draft'] and not hint:
        if not dry_run:
            gh.check(pr, error)
        return 'draft'
    paths = gh.files(pr) if pr['state'] == 'open' and eligible(pr) else []
    exempt = not eligible(pr) or bool(paths and set(paths) <= {'bugs.md', 'features.md', 'CHANGELOG.md'})
    if exempt and not hint:
        return 'exempt'
    timeline = gh.timeline(number) if pr['state'] == 'open' else []
    ready = ready_event(timeline)
    notice_id = hint.get('message')
    try:
        message, old = dc.find(number, hint)
        if message:
            notice_id = message['id']
        if not message and (pr['state'] != 'open' or exempt):
            return finish_notice(gh, dc, pr, message, old, text, exempt, dry_run)
        if not message and hint and not hint.get('message') and not dc.pending_clear():
            raise NoticeProblem('An earlier notice may be outside recent messages. Owner: find its Discord message link and restore it in the Changelog comment, keeping its stop reactions. If it cannot be recovered, close this change and open a new one with a full week.')
        if not message and hint and hint.get('message'):
            reset = (not pr['draft'] and ready != hint.get('ready') and
                     any(e.get('event') == 'converted_to_draft' for e in timeline) and
                     any(str(e.get('id')) == ready and e.get('event') == 'ready_for_review' for e in timeline))
            if not reset:
                raise NoticeProblem('The Discord notice was deleted or could not be recovered. Mark the change as draft, then ready again, to post a new notice and start a full week.')
        if not text:
            text = notice_text(message, old or {})
        if pr['state'] != 'open' or exempt:
            return finish_notice(gh, dc, pr, message, old, text, exempt, dry_run)
        if not message and (error or pr['draft']):
            if not dry_run:
                gh.check(pr, error)
            return 'missing-note'
        fingerprint, _ = gh.change(pr)
        current = dc.holders(message['id']) if message else {}
        state, restarted = prepare_state(pr, old, fingerprint, ready, text, current, now)
        status = waiting_status(pr, state, error, current, restarted, mode, now)
        due = now >= date(state['start']) + WEEK
        can_merge = due and not current and not error and not pr['draft']
        incident = None
        if can_merge:
            try:
                status = attempt_merge(gh, dc, pr, state, fingerprint, ready, message, status, now, dry_run, mode)
            except IdentityIncident as exc:
                incident = str(exc)
                state.update(incident=incident, finished=True)
                status = incident
        if dry_run:
            print('DRY RUN: PR #' + str(number) + ': ' + status)
            return status
        # All reads, including final checks/reactions, have completed. A failed
        # read above therefore performs no check/comment/notice mutation.
        gh.check(pr, incident or error)
        if not message:
            gh.mirror(number, {'ready': ready}, None, 'Preparing the Discord notice. If interrupted, the next run recovers it.')
        posted = dc.post(number, state, render(pr, state, text, status), message)
        notice_id = posted['id']
        if not message:
            gh.mirror(number, state, notice_id, status)
            state['start'] = stamp(max(date(state['start']), date(posted['timestamp'])))
            posted = dc.post(number, state, render(pr, state, text, status), posted)
        if not state.get('seeded'):
            dc.seed(posted['id'])
            state['seeded'] = True
            posted = dc.post(number, state, render(pr, state, text, status), posted)
        gh.mirror(number, state, posted['id'], status)
        if incident:
            raise IdentityIncident(incident)
        return status
    except NoticeProblem as exc:
        if not dry_run:
            gh.mirror(number, {'ready': ready, 'cancelled': pr['draft']}, notice_id, str(exc))
            dc.problem(number, str(exc))
        raise


def reconcile_all(gh, dc, mode, now, dry_run=False):
    failed = False
    for pr in gh.pulls(now):
        try:
            print('PR #' + str(pr['number']) + ': ' + reconcile(gh, dc, pr['number'], mode, now, dry_run))
        except Refused as exc:
            failed = True
            if isinstance(exc, IdentityIncident):
                mode = 'post'  # Do not cascade an observed author failure to other merges.
            print('::error::PR #' + str(pr['number']) + ': ' + str(exc))
    require(not failed, 'Some changes could not be checked; their previous review windows were preserved')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--rehearse', type=int, metavar='NUMBER', help='Locally rehearse one PR through the full gate; never available in Actions')
    args = parser.parse_args()
    env = os.environ
    require(args.rehearse is None or (args.rehearse > 0 and env.get('GITHUB_ACTIONS') != 'true'), 'Rehearsal is local only and needs a positive pull request number')
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
    gh = GitHub(gh_api, merge_api, args.dry_run)
    dc = Discord(API('https://discord.com/api/v10', env['CHANGELOG_DISCORD_BOT_TOKEN'], 'Bot', args.dry_run), env['CHANGELOG_DISCORD_CHANNEL_ID'])
    now = datetime.now(timezone.utc)
    if args.rehearse:
        print(reconcile(gh, dc, args.rehearse, env['CHANGELOG_MODE'], now, args.dry_run))
    else:
        reconcile_all(gh, dc, env['CHANGELOG_MODE'], now, args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except (Refused, KeyError, TypeError, ValueError) as exc:
        print('::error::' + (str(exc) if isinstance(exc, Refused) else 'Invalid API data or configuration; no unsafe fallback'), file=sys.stderr)
        sys.exit(1)
