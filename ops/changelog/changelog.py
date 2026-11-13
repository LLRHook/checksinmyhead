"""Changelog: trusted-main, API-only Discord notice and approval-or-seven-day squash gate.

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
APPROVE = '👍'
THUMBS = (APPROVE,) + tuple(APPROVE + chr(tone) for tone in range(0x1f3fb, 0x1f400))
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
        self.waiting = False
        self.root = '/repos/' + REPO

    def schedule(self, enabled):
        action = 'enable' if enabled else 'disable'
        if self.dry_run:
            print('DRY RUN: schedule ' + action)
            return
        self.api.request('PUT', self.root + '/actions/workflows/changelog-schedule.yml/' + action)

    def open_pulls(self):
        return self.api.pages(self.root + '/pulls?state=open&sort=updated&direction=desc')

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
        fallback = 'head:' + head
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
        return hashlib.sha256(compact([sorted(changes), own]).encode()).hexdigest()

    def files(self, pr):
        key = (pr['number'], pr['head']['sha'])
        if key not in self._files:
            self._files[key] = self.api.pages(self.root + '/pulls/' + str(pr['number']) + '/files') if pr['changed_files'] <= 3000 else []
        files = self._files[key]
        paths = [f['filename'] for f in files]
        return paths, len(files) == pr['changed_files']

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
        # Required and note checks must succeed on this exact commit. Optional
        # delivery jobs may skip on PRs; the running Changelog job cannot gate itself.
        mandatory = [REQUIRED_CHECK, CHECK]
        self._runs[head] = runs
        for name in mandatory:
            if not any(r['name'] == name and r['app']['slug'] == 'github-actions' and
                       r.get('head_sha') == head and r.get('status') == 'completed' and
                       r.get('conclusion') == 'success' for r in runs):
                self.waiting_check = name
                return False
        bad = [r for r in runs if not (r['name'] == 'changelog' and r['app']['slug'] == 'github-actions') and
               (r.get('head_sha') != head or r.get('status') != 'completed' or
                r.get('conclusion') not in ('success', 'skipped', 'neutral'))]
        if bad:
            self.waiting_check = bad[0]['name']
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
        pointers = re.findall(r'(?m)^Discord message: ([0-9]+)$', comments[0]['body'])
        return {'message': pointers[-1] if pointers else None, 'ready': data.get('ready'), 'exists': True}

    def mirror(self, number, state, message, text):
        if self.dry_run:
            print('DRY RUN: mirror PR #' + str(number))
            return
        candidates = self.comments(number)
        pointer = '\n\nDiscord message: ' + message if message else ''
        body = COMMENT + '\nChangelog: ' + plain_dates(text) + pointer + '\n\n```json\n' + compact(state) + '\n```'
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
            raise IdentityIncident('MERGE IDENTITY INCIDENT: the commit on main for this change is not authored by Victor Ivanov <victor.n.ivanov@gmail.com>; if Changelog merged it, set CHANGELOG_MODE to post and check whose token it is.')

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
            raise MergeBlocked('GitHub declined the merge; mergeable_state is ' + str(pr.get('mergeable_state')) + '. Check repository rules and the merge account permissions.')
        merged = result['data']['mergePullRequest']['pullRequest']
        if not merged['merged']:
            raise MergeBlocked('GitHub has not accepted the merge; mergeable_state is ' + str(pr.get('mergeable_state')) + '. Check repository rules and retry on a later run.')
        commit = merged['mergeCommit']
        self.audit(dict(pr, merge_commit_sha=commit['oid']))
        return commit['oid']


def state_embed(number, state):
    # Store full-strength state in the embed link fragment, outside the phone
    # reader's text. The bot-owned message alone still recovers all clock data.
    packed = base64.urlsafe_b64encode(zlib.compress(compact(state).encode())).decode().rstrip('=')
    return {'url': 'https://github.com/' + REPO + '/pull/' + str(number) + '#changelog-' + packed}


def plain_dates(text):
    text = re.sub(r'(<t:[0-9]+:F>) \(<t:[0-9]+:R>\)', r'\1', text)
    return re.sub(r'<t:([0-9]+):[FR]>', lambda m: datetime.fromtimestamp(int(m[1]), timezone.utc).strftime('%d %B %Y at %H:%M:%S UTC'), text)


class Discord:
    PAGE_LIMIT = 20

    def __init__(self, api, channel):
        self.api, self.channel = api, channel
        self.root = '/channels/' + channel + '/messages'
        self.bot = None

    def record(self, message, number):
        for embed in message.get('embeds', []):
            prefix = 'https://github.com/' + REPO + '/pull/' + str(number) + '#changelog-'
            if not embed.get('url', '').startswith(prefix):
                continue
            try:
                packed = embed['url'][len(prefix):]
                require(len(packed) <= 1800, 'Review record too large')
                raw = zlib.decompressobj().decompress(base64.urlsafe_b64decode(packed + '=' * (-len(packed) % 4)), 8192)
                state = json.loads(raw)
                require(state['version'] == 1 and state['number'] == number, 'Invalid review record')
                state['start'] = stamp(max(date(state['start']), date(message['timestamp'])))
                return state
            except (KeyError, ValueError, TypeError, zlib.error):
                raise NoticeProblem('The saved review record is damaged. Ask the owner to restore the original notice or close this change and open a new one.') from None
        return None

    def find(self, pr, hint=None):
        if self.bot is None:
            self.bot = self.api.request('GET', '/users/@me')['id']
        number, created = pr['number'], date(pr['created_at'])
        pointer = (hint or {}).get('message')
        if pointer:
            try:
                fetched = self.api.request('GET', self.root + '/' + pointer)
            except HTTPFailure as exc:
                if exc.status not in (403, 404):
                    raise
            else:
                if fetched['author']['id'] == self.bot and fetched.get('channel_id') == self.channel:
                    state = self.record(fetched, number)
                    if state is not None:
                        return fetched, state
        matches, before = [], ''
        for _ in range(self.PAGE_LIMIT):
            try:
                batch = self.api.request('GET', self.root + '?limit=100' + ('&before=' + before if before else ''))
            except HTTPFailure as exc:
                if exc.status in (403, 404):
                    raise NoticeProblem('Changelog cannot read this channel. Ask the owner to restore View Channel and Read Message History and check the channel setting.') from None
                raise
            complete = len(batch) < 100
            for message in batch:
                if date(message['timestamp']) < created:
                    complete = True
                    break
                if message['author']['id'] == self.bot and message.get('channel_id') == self.channel:
                    state = self.record(message, number)
                    if state is not None:
                        matches.append((message, state))
            if len(matches) > 1:
                raise NoticeProblem('More than one notice exists. Ask the owner to keep the original notice and remove the duplicate, preserving all stop reactions.')
            if complete:
                return matches[0] if matches else (None, None)
            before = batch[-1]['id']
        raise NoticeProblem('There are too many messages to find the original notice safely. Close this pull request and open the change as a new one; it will get a full new week. Keep any unresolved objection in its description.')

    def holders(self, message, emoji=STOP, people=False):
        users = {}
        reaction_name = 'approval' if people else 'stop'
        for kind in (0, 1):
            after = ''
            for _ in range(100):
                path = self.root + '/' + message + '/reactions/' + urllib.parse.quote(emoji) + f'?limit=100&type={kind}'
                try:
                    batch = self.api.request('GET', path + ('&after=' + after if after else ''))
                except HTTPFailure as exc:
                    if exc.status in (403, 404):
                        raise NoticeProblem('Changelog cannot read the ' + reaction_name + ' reactions. Ask the owner to restore channel access.') from None
                    raise
                for user in batch:
                    if user['id'] != self.bot and not (people and user.get('bot')):
                        if people:
                            require(isinstance(user['id'], str) and re.fullmatch('[0-9]{1,24}', user['id']), 'Invalid approval actor; retry safely')
                        users[user['id']] = safe(user.get('global_name') or user['username'])[:60]
                if len(batch) < 100:
                    break
                after = batch[-1]['id']
            else:
                raise NoticeProblem('Too many ' + reaction_name + ' reactions to read safely. Ask the owner to check this notice.')
        return users

    def fresh(self, pr, message):
        fresh = self.api.request('GET', self.root + '/' + message['id'])
        require(fresh['id'] == message['id'] and fresh['author']['id'] == self.bot and fresh.get('channel_id') == self.channel and
                self.record(fresh, pr['number']) is not None, 'Notice changed during the final read; retry safely')
        return fresh

    @staticmethod
    def others(message, emoji):
        # Missing legacy count metadata is not evidence of an empty reaction.
        for reaction in message.get('reactions', []):
            if reaction['emoji'].get('id') is None and reaction['emoji']['name'] == emoji:
                count = reaction.get('count')
                if type(count) is not int or count > int(bool(reaction.get('me'))) + int(bool(reaction.get('me_burst'))):
                    return True
        return False

    def stops(self, message):
        if not self.others(message, STOP):
            return {}
        users = self.holders(message['id'])
        require(users, 'Stop reactions changed during the read; retry safely')
        return users

    def has_approval_reactions(self, message):
        return any(self.others(message, emoji) for emoji in THUMBS)

    def approvers(self, message):
        users = {}
        for emoji in THUMBS:
            if self.others(message, emoji):
                users.update(self.holders(message['id'], emoji, people=True))
        return users

    def post(self, pr, state, text, message=None):
        embed = dict(state_embed(pr['number'], state), title=clip(safe(pr['title']), 256), description=text)
        payload = {'content': '', 'allowed_mentions': {'parse': [], 'users': [], 'roles': [], 'replied_user': False}, 'embeds': [embed]}
        require(len(text.encode('utf-16-le')) // 2 <= 4096 and len(embed['url']) <= 2048, 'Notice too long; holding')
        try:
            if message:
                returned = message.get('embeds', [{}])[0]
                same_record = self.record(message, pr['number']) == state
                if (not message.get('content') and len(message.get('embeds', [])) == 1 and returned.get('title') == embed['title'] and
                        returned.get('description') == text and same_record and not returned.get('footer')):
                    return message
                return self.api.request('PATCH', self.root + '/' + message['id'], payload)
            payload.update(nonce=hashlib.sha256((REPO + '#' + str(pr['number']) + ':' + state.get('ready', 'initial')).encode()).hexdigest()[:24], enforce_nonce=True)
            return self.api.request('POST', self.root, payload)
        except HTTPFailure as exc:
            if exc.status in (403, 404):
                raise NoticeProblem('Changelog cannot write to this channel. Ask the owner to restore Send Messages and Embed Links and check the channel setting.') from None
            raise

    def seed(self, message):
        own = {r['emoji']['name'] for r in message.get('reactions', []) if r.get('me')}
        for emoji in (STOP, '👍'):
            if emoji not in own:
                try:
                    self.api.request('PUT', self.root + '/' + message['id'] + '/reactions/' + urllib.parse.quote(emoji) + '/@me')
                except HTTPFailure as exc:
                    if exc.status in (403, 404):
                        raise NoticeProblem('Changelog cannot add the stop buttons. Ask the owner to restore Add Reactions and channel access.') from None
                    raise


def eligible(pr):
    return (pr['head']['repo'] is not None and pr['head']['repo']['full_name'] == REPO and
            pr['base']['repo']['full_name'] == REPO and pr['base']['ref'] == 'main' and
            pr['user']['login'] not in ('dependabot[bot]', 'dependabot'))


def waiting(pr, state=None, message=None):
    """A live unfinished notice; without notice data, a conservative recheck.

    Keep exemptions in eligible/reconciliation. The post-disable recheck may
    include never-posted/broken-note/tracker-only PRs rather than risk a stuck stop.
    """
    if pr['state'] != 'open' or pr['draft'] or not eligible(pr):
        return False
    return state is None or bool(message and not any(state.get(k) for k in ('finished', 'exempt', 'cancelled')))


def local_time(value, style='F'):
    return '<t:' + str(int(date(value).timestamp())) + ':' + style + '>'


MERGED = "It's in. You'll see it in the next app build."
GITHUB_WAIT = "The week is up, but GitHub isn't ready to take it yet. Changelog will keep checking."


def ready_event(timeline):
    transitions = [e for e in timeline if e.get('event') in ('ready_for_review', 'converted_to_draft', 'reopened')]
    return str(transitions[-1]['id']) if transitions else 'initial'


def notice_text(message, state):
    return message.get('embeds', [{}])[0].get('description', '')[:state.get('note_length', 0)] if message else ''


def prepare_state(pr, old, fingerprint, ready, text, current, now):
    state = copy.deepcopy(old) if old else {'version': 1, 'number': pr['number'], 'start': stamp(now), 'holds': {}}
    restarted = bool(old and not pr['draft'] and (old.get('fingerprint') != fingerprint or old.get('ready') != ready or old.get('cancelled') or old.get('exempt')))
    if restarted:
        state['start'] = stamp(now)
    state.update(fingerprint=fingerprint, ready=ready, cancelled=pr['draft'], note_length=len(text),
                 exempt=False, finished=False)
    state['holds'] = {uid: old.get('holds', {}).get(uid, stamp(now)) if old else stamp(now) for uid in sorted(current)[:8]}
    return state, restarted


def prepare_approvals(state, current, reset=False):
    stale = state.get('stale_approvals')
    known = (type(state.get('approval_policy')) is int and state['approval_policy'] == 1 and type(stale) is list and len(stale) <= 8 and
             all(isinstance(uid, str) and re.fullmatch('[0-9]{1,24}', uid) for uid in stale) and
             type(state.get('approval_overflow')) is bool and type(state.get('approval_reset')) is bool)
    reset = reset or not known or state.get('approval_reset', False)
    stale = set(current) if reset else set(stale) & current.keys()
    overflow = len(stale) > 8 or bool(known and state['approval_overflow'] and current)
    if overflow:
        stale = set(current)
    state.update(approval_policy=1, stale_approvals=sorted(stale)[:8], approval_overflow=overflow, approval_reset=reset)
    return {} if reset or overflow else {uid: current[uid] for uid in sorted(current) if uid not in stale}


def thumb_reactions(message):
    return [r for r in message.get('reactions', []) if r['emoji'].get('id') is None and r['emoji']['name'] in THUMBS]


def approval_names(approved):
    return clip(', '.join(approved[uid] for uid in sorted(approved)[:8]), 300)


def approval_status(names, reason, check=''):
    if reason == 'checks':
        return names + ' tapped 👍. It goes live as soon as an automatic test (' + safe(check) + ') passes, unless someone taps 🛑.'
    if reason == 'conflict':
        return names + ' tapped 👍, but it clashes with another change; the author is fixing that.'
    if reason == 'github':
        return names + " tapped 👍, but GitHub isn't ready to take it yet. Changelog will keep checking."
    if reason == 'other':
        return names + ' tapped 👍. Someone else wrote this one, so the owner will put it live by hand.'
    return names + ' tapped 👍. It goes live once the owner switches it on. Tapping 🛑 still stops it.'


def waiting_status(pr, state, error, current, restarted, now, approved=None):
    if pr['draft']:
        return "Back to work in progress: the wait is off. It gets a fresh week when it's shared again."
    ahead = now < date(state['start']) + WEEK
    lines = ['The change was updated, so the week starts again.'] if restarted else []
    if state['fingerprint'].startswith('head:'):
        lines.append('This is a big change, so any update to it restarts the week.')
    if current:
        names = ', '.join(current[uid] + ' tapped 🛑 (' + local_time(state['holds'][uid], 'R') + ')' for uid in state['holds'])
        ending = "It won't go live until every 🛑 is removed; removing one doesn't change the date." if ahead else 'It goes live once every 🛑 is removed.'
        lines.append('On hold: ' + clip(names, 450) + '. ' + ending)
        if error:
            lines.append("Paused: the author needs to fix this change's description.")
        elif ahead:
            deadline = stamp(date(state['start']) + WEEK)
            lines.append('Goes live ' + local_time(deadline) + ' (' + local_time(deadline, 'R') + ') unless someone stops it.')
        return '\n'.join(lines)
    if error:
        return "Paused: the author needs to fix this change's description."
    if approved:
        return approval_status(approval_names(approved), 'other' if pr['user']['login'] != 'LLRHook' else 'post')
    if not ahead:
        if pr['user']['login'] != 'LLRHook':
            return 'The week is up. Someone else wrote this one, so the owner will put it live by hand.'
        return 'The week is up. It goes live once the owner switches it on. Tapping 🛑 still stops it.'
    if state.get('stale_approvals') or state.get('approval_overflow'):
        lines = ["Earlier 👍 don't count for this version. To approve it, remove your 👍, wait 15 minutes, then tap 👍 again."] + [line for line in lines if line != 'The change was updated, so the week starts again.']
    deadline = stamp(date(state['start']) + WEEK)
    lines += ['Goes live as soon as one of you taps 👍, or on ' + local_time(deadline) + ' (' + local_time(deadline, 'R') + ') if nobody stops it.',
              'Tap 👍 to approve it. Tap 🛑 to stop it.']
    return '\n'.join(lines)


def attempt_merge(gh, dc, pr, state, fingerprint, ready, message, status, dry_run, mode, now, approved):
    fresh = gh.pr(pr['number'])
    if (not eligible(fresh) or fresh['draft'] or fresh['state'] != 'open' or
            fresh['head']['sha'] != pr['head']['sha'] or fresh['base']['sha'] != pr['base']['sha'] or
            fresh.get('body') != pr.get('body') or ready_event(gh.timeline(pr['number'])) != ready or gh.change(fresh) != fingerprint):
        return 'The change was updated during this check. Changelog will check it again shortly.'
    if approved and (mode != 'merge' or pr['user']['login'] != 'LLRHook' or not gh.merge_api):
        return status
    if not gh.green(fresh):
        return approval_status(approval_names(approved), 'checks', gh.waiting_check) if approved else "The week is up, but an automatic test (" + safe(gh.waiting_check) + ") hasn't passed yet. It goes live once it does, unless someone taps 🛑."
    elif fresh.get('mergeable') is not True or fresh.get('mergeable_state') != 'clean':
        if fresh.get('mergeable_state') == 'dirty':
            return approval_status(approval_names(approved), 'conflict') if approved else 'The week is up, but it clashes with another change; the author is fixing that.'
        if mode != 'merge' or pr['user']['login'] != 'LLRHook':
            return status  # The owner puts this one live by hand and sees GitHub's state there.
        raise MergeBlocked('GitHub mergeable_state is ' + str(fresh.get('mergeable_state')) + '; mergeable is ' + str(fresh.get('mergeable')) + '. Check repository rules or wait for GitHub to recalculate.')
    final = dc.fresh(pr, message)
    record = dc.record(final, pr['number'])
    require(record.get('fingerprint') == fingerprint and record.get('ready') == ready and record.get('start') == state['start'],
            'Notice changed during the final read; retry safely')
    # Keep removals observed this run, but reject changed approval knowledge.
    initial = dc.record(message, pr['number'])
    proof_changed = any(record.get(key) != initial.get(key) for key in ('approval_policy', 'stale_approvals', 'approval_overflow', 'approval_reset'))
    approved = prepare_approvals(state, dc.approvers(final), reset=proof_changed)
    last = dc.fresh(pr, message)
    require(dc.record(last, pr['number']) == record, 'Notice changed during the final read; retry safely')
    stops = dc.stops(last)
    if stops:
        state['holds'] = {uid: state['holds'].get(uid, stamp(now)) for uid in sorted(stops)[:8]}
        return waiting_status(pr, state, None, stops, False, now)
    if not dc.has_approval_reactions(last):
        approved = prepare_approvals(state, {})
    # A 👍 withdrawn while its people were being listed must not count; the next run lists them afresh.
    require(not approved or thumb_reactions(last) == thumb_reactions(final), 'Approval reactions changed during the final read; retry safely')
    if now < date(state['start']) + WEEK and not approved:
        return waiting_status(pr, state, None, {}, False, now)

    if mode != 'merge' or not gh.identity(pr):
        return status
    try:
        gh.merge(fresh)
    except IdentityIncident:
        if approved:
            state['approved_by'] = approval_names(approved)
        raise
    if dry_run:
        return 'Would squash merge now.'
    state.update(finished=True, audited=True, approval_reset=False)
    if approved:
        state['approved_by'] = approval_names(approved)
    return ('Approved by ' + state['approved_by'] + '. ' if approved else '') + MERGED


def finish_notice(gh, dc, pr, message, old, text, exempt, dry_run):
    state = dict(old or {}, exempt=exempt, finished=pr['state'] != 'open')
    if pr.get('merged'):
        status = ('Approved by ' + state['approved_by'] + '. ' if state.get('approved_by') else '') + MERGED
    elif pr['state'] != 'open':
        status = "Dropped: this change won't go live."
    elif pr['base']['ref'] != 'main':
        status = 'No longer headed for the app, so no week needed.'
    else:
        status = 'No week needed: this now only updates the to-do lists.'
    if pr.get('merged') and pr['user']['login'] == 'LLRHook' and (pr.get('merged_by') or {}).get('login') == 'LLRHook' and not state.get('audited') and not state.get('incident'):
        try:
            gh.audit(pr)
            state['audited'] = True
        except IdentityIncident as exc:
            state['incident'] = str(exc)
    if not dry_run:
        if message:
            dc.post(pr, state, text + '\n\n' + status, message)
        gh.mirror(pr['number'], state, message['id'] if message else None, state.get('incident') or status)
        if state.get('incident'):
            gh.check(pr, state['incident'])
            raise IdentityIncident(state['incident'])
    return 'closed' if pr['state'] != 'open' else 'exempt'


def reconcile(gh, dc, number, mode, now, dry_run=False):
    gh.waiting = False
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
    paths, complete = gh.files(pr) if pr['state'] == 'open' and eligible(pr) else ([], True)
    exempt = not eligible(pr) or bool(complete and paths and set(paths) <= {'bugs.md', 'features.md', 'CHANGELOG.md'})
    if exempt and not hint.get('message'):
        return 'exempt'
    if pr['draft'] and not hint:
        if not dry_run:
            gh.check(pr, error)
        return 'draft'
    timeline = gh.timeline(number) if pr['state'] == 'open' else []
    ready = ready_event(timeline)
    notice_id = hint.get('message')
    try:
        message, old = dc.find(pr, hint)
        if message:
            notice_id = message['id']
        if not text:
            text = notice_text(message, old or {})
        if pr['state'] != 'open' or exempt:
            return finish_notice(gh, dc, pr, message, old, text, exempt, dry_run)
        if not message and hint.get('message'):
            reset = (not pr['draft'] and ready != hint.get('ready') and
                     any(e.get('event') == 'converted_to_draft' for e in timeline) and
                     any(str(e.get('id')) == ready and e.get('event') == 'ready_for_review' for e in timeline))
            if not reset:
                raise NoticeProblem('The Discord notice was deleted. Mark the change as draft, then ready again, to post a new notice and start a full week.')
        if not message and (error or pr['draft']):
            if not dry_run:
                gh.check(pr, error)
            return 'missing-note'
        fingerprint = gh.change(pr)
        current = dc.stops(message) if message else {}
        thumbs = dc.approvers(message) if message else {}
        state, restarted = prepare_state(pr, old, fingerprint, ready, text, current, now)
        if not message:
            state.update(approval_policy=1, stale_approvals=[], approval_overflow=False, approval_reset=False)
        approved = prepare_approvals(state, thumbs, restarted)
        status = waiting_status(pr, state, error, current, restarted, now, approved)
        due = now >= date(state['start']) + WEEK
        can_merge = (due or bool(approved)) and not current and not error and not pr['draft']
        incident = detail = None
        if can_merge:
            try:
                status = attempt_merge(gh, dc, pr, state, fingerprint, ready, message, status, dry_run, mode, now, approved)
            except MergeBlocked as exc:
                status, detail = approval_status(approval_names(approved), 'github') if approved else GITHUB_WAIT, str(exc)
            except IdentityIncident as exc:
                incident = str(exc)
                state.update(incident=incident, finished=True, approval_reset=False)
                status = ('Approved by ' + state['approved_by'] + '. ' if state.get('approved_by') else '') + MERGED
        if dry_run:
            print('DRY RUN: PR #' + str(number) + ': ' + status)
            return status
        # All reads, including final checks/reactions, have completed. A failed
        # read above therefore performs no check/comment/notice mutation.
        gh.check(pr, incident or error)
        posted = dc.post(pr, state, text + '\n\n' + status, message)
        dc.seed(posted)
        if state['approval_reset']:
            observed = dc.approvers(dc.fresh(pr, posted))
            prepare_approvals(state, observed, reset=True)
            state['approval_reset'] = False
            status = waiting_status(pr, state, error, current, restarted, now)
            posted = dc.post(pr, state, text + '\n\n' + status, posted)
        state['start'] = stamp(max(date(state['start']), date(posted['timestamp'])))
        gh.mirror(number, state, posted['id'], incident or error or detail or status)
        if incident:
            raise IdentityIncident(incident)
        gh.waiting = waiting(pr, state, posted)
        return status
    except NoticeProblem as exc:
        if not dry_run:
            gh.mirror(number, {'ready': ready, 'cancelled': pr['draft']}, notice_id, str(exc))
        raise


def reconcile_event(gh, dc, number, mode, now, dry_run=False):
    status = reconcile(gh, dc, number, mode, now, dry_run)
    if gh.waiting and not dry_run:
        gh.schedule(True)
    return status


def idle_schedule(gh, dry_run=False):
    if dry_run:
        return
    try:
        gh.schedule(False)
    except Exception:
        # A lost reply may have disabled it. Restore active even in that case.
        print('::warning::Could not confirm schedule disable; keeping sweeps enabled')
        gh.schedule(True)
        return
    try:
        resume = any(waiting(pr) for pr in gh.open_pulls())
    except Exception:
        # Unknown work is not idle. Compensate before reporting the read failure.
        gh.schedule(True)
        raise
    if resume:
        gh.schedule(True)


def reconcile_all(gh, dc, mode, now, dry_run=False):
    failed = pending = False
    for pr in gh.pulls(now):
        try:
            print('PR #' + str(pr['number']) + ': ' + reconcile(gh, dc, pr['number'], mode, now, dry_run))
            pending = pending or gh.waiting
        except Exception as exc:
            failed = True
            if isinstance(exc, IdentityIncident):
                mode = 'post'  # Do not cascade an observed author failure to other merges.
            print('::error::PR #' + str(pr['number']) + ': ' + type(exc).__name__ + (': ' + str(exc) if isinstance(exc, Refused) else ''))
    require(not failed, 'Some changes could not be checked; their previous review windows were preserved')
    if not pending:
        idle_schedule(gh, dry_run)


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
        origin = event['pull_request']['head']['repo']
        if not origin or origin['full_name'] != REPO:
            print('Exempt event; no API calls made')
            return
    gh_api = API('https://api.github.com', env['GITHUB_TOKEN'], dry_run=args.dry_run)
    merge_api = API('https://api.github.com', env['CHANGELOG_MERGE_TOKEN'], dry_run=args.dry_run) if env.get('CHANGELOG_MERGE_TOKEN') else None
    gh = GitHub(gh_api, merge_api, args.dry_run)
    dc = Discord(API('https://discord.com/api/v10', env['CHANGELOG_DISCORD_BOT_TOKEN'], 'Bot', args.dry_run), env['CHANGELOG_DISCORD_CHANNEL_ID'])
    now = datetime.now(timezone.utc)
    if env['GITHUB_EVENT_NAME'] == 'pull_request_target':
        print(reconcile_event(gh, dc, event['number'], env['CHANGELOG_MODE'], now, args.dry_run))
    else:
        reconcile_all(gh, dc, env['CHANGELOG_MODE'], now, args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except (Refused, KeyError, TypeError, ValueError) as exc:
        print('::error::' + (str(exc) if isinstance(exc, Refused) else 'Invalid API data or configuration; no unsafe fallback'), file=sys.stderr)
        sys.exit(1)
