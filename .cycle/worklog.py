"""Opt-in Jira worklogs for dev-cycle runs (stdlib only). Run through `python .cycle/trackers.py worklog ...`.

Rules (.cycle/TRACKERS.md, "Worklogs"): nothing is tracked or posted unless the person whose
time it is chose it, for this run (`start --consent run`) or for themselves in this clone
(`mode auto`, stored in the clone's git config and tied to their Jira account). The repo can
only turn the feature off (`jira.worklog: "off"`), never on for anyone. A worklog over 8 hours
is never posted without `--confirm-long`, and one that overlaps the person's other Jira
worklogs never without `--confirm-overlap`; a command passes either only after the person
confirms. Runs that overlap in time (two repos, two worktrees) split each shared active minute
evenly. Time math: worklog_time.py.

  worklog state                          off | unavailable | never | ask | auto, plus unposted time
  worklog mode auto|ask|never [--preview on|off] [--idle MIN]
  worklog start LABEL --consent run|auto [--command C]
  worklog pause LABEL | resume LABEL     stop / restart the clock (waiting on the person)
  worklog retarget OLD NEW               `run` gets its ticket or bundle (OLD stays an alias)
  worklog finish LABEL [--app A | --tracker P] [--yes] [--minutes N] [--started ISO]
                 [--comment-file F|-] [--confirm-long] [--confirm-overlap] [--force]
  worklog log KEY --started ISO --minutes N [--comment-file F|-] [--exact] [--yes] [--confirm-…]
  worklog backfill KEY --transcript F [--since ISO] [--until ISO] [--branch B] [--yes] [--confirm-…]
  worklog drop LABEL                     discard an open session, post nothing
  worklog undo LABEL|KEY                 delete every worklog block of the last post there
  worklog sync                           refresh this clone's posted worklogs from Jira
  worklog status                         open and posted sessions in this clone
  worklog notice                         unposted time, one line each (SessionStart; silent otherwise)
  worklog hook                           Claude Code hook (stdin event): activity and busy time

LABEL is a tracker id (its `Jira:` key; a cross-app id: every slice, by changed-file share, or one
with --app), a Jira key (a bundle Task), or `run`.
Exit codes: 0 done or preview printed; 3 needs the person's confirmation (over 8 hours, or
overlapping their other Jira worklogs).
"""
import datetime, json, os, re, secrets, subprocess, sys, time

import tracker_ops as T
import worklog_time as W

STATE = 'cycle-worklog.json'
EVENTS = 'cycle-worklog.events'        # append-only activity log: safe under parallel hooks
BG = 'cycle-worklog.bg.json'           # background tasks: output file -> last write seen
TRANSCRIPTS = 'cycle-worklog.transcripts'  # Claude Code transcripts seen by the hooks, one per line
FOLLOWUP_TTL_S = 7 * 86400             # an idle follow-up / implicit session is dropped after this
PREVIEW_HOLD_S = 2 * 3600              # a preview's numbers are what --yes posts, within this time
OUTPUT_RE = re.compile(r'((?:[A-Za-z]:)?[\\/][^\s"\'<>|*?]+?\.output)(?![\w.])')
HOOK_EVENTS = ('PreToolUse', 'PostToolUse', 'PostToolUseFailure', 'SubagentStart', 'SubagentStop',
               'Stop', 'UserPromptSubmit', 'SessionEnd')
LOCAL_SETTINGS = os.path.join('.claude', 'settings.local.json')
IDLE_MIN = 30
LONG_S = 8 * 3600          # fixed: a longer worklog always needs the person's confirmation
NEEDS_CONFIRM = 3
KEEP_POSTED_S = 14 * 86400  # posted runs stay in the personal registry this long for overlap splits
CFG = 'cycle.worklog.'
ACTIVITY_KINDS = ('followup', 'implicit')  # sessions finished on activity, not on a commit


# ------------------------------------------------------------------ local state

_COMMON = {}


def state_path(root=None, name=STATE):
    """One file per clone, shared by its worktrees, never committed (.git/cycle-worklog.*).
    The git lookup runs once per process (a hook calls this several times per tool call)."""
    k = root or os.getcwd()
    if k not in _COMMON:
        common = T.git('rev-parse', '--git-common-dir', cwd=root)
        _COMMON[k] = os.path.abspath(os.path.join(k, common)) if common else None
    return os.path.join(_COMMON[k], name) if _COMMON[k] else None


def load(root):
    p = state_path(root)
    if p and os.path.exists(p):
        with open(p, encoding='utf-8') as f:
            st = json.load(f)
    else:
        st = {}
    st.setdefault('open', {})
    st.setdefault('posted', [])
    st.setdefault('alias', {})
    return st


def save(root, st):
    p = state_path(root)
    tmp = p + '.%d.tmp' % os.getpid()
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(st, f, indent=1)
    os.replace(tmp, p)


def record(root, kind, key='-', at=None):
    """Append one activity line `<epoch> <kind> <key> <branch>` while a session is open. Never raises.
    M = mark, B/E = busy span begin/end (tool:<id>, agent:<id>, bg:<id>), C = close open spans
    (tool|all), X = a background task's output was still being written then, P = a prompt."""
    try:
        sp = state_path(root)
        if not (sp and os.path.exists(sp)):
            return
        with open(state_path(root, EVENTS), 'a', encoding='utf-8') as f:
            f.write('%d %s %s %s\n' % (int(at or time.time()), kind, key, current_branch(root)))
    except Exception:
        pass


def beat(root):
    """Activity mark; called on any trackers.py command."""
    record(root, 'M')


def read_events(root):
    p = state_path(root, EVENTS)
    out = []
    if p and os.path.exists(p):
        with open(p, encoding='utf-8', errors='replace') as f:
            for line in f:
                parts = line.split()
                if len(parts) in (3, 4) and parts[0].isdigit():
                    out.append((int(parts[0]), parts[1], parts[2], parts[3] if len(parts) == 4 else '-'))
    return out


def events_for(s, events):
    """Activity sessions (follow-up, implicit) count only activity on their own branch."""
    b = s.get('branch') if s.get('kind') in ACTIVITY_KINDS else None
    return events if not b else [e for e in events if e[3] in (b, '-')]


def prune_events(root, st):
    """Keep only lines a still-open session can use; drop the logs when none is open."""
    p = state_path(root, EVENTS)
    starts = [s['intervals'][0][0] for s in st['open'].values()]
    if not starts:
        for name in (EVENTS, BG, TRANSCRIPTS):
            q = state_path(root, name)
            if q and os.path.exists(q):
                os.remove(q)
        return
    if p and os.path.exists(p):
        keep = [e for e in read_events(root) if e[0] >= min(starts)]
        with open(p, 'w', encoding='utf-8') as f:
            f.writelines('%d %s %s %s\n' % e for e in keep)


def current_branch(root):
    """The checked-out branch, read from HEAD without running git (hooks run on every tool call)."""
    try:
        g = os.path.join(root or os.getcwd(), '.git')
        if os.path.isfile(g):  # worktree: `gitdir: <path>`
            line = open(g, encoding='utf-8').read().strip()
            g = line.split(':', 1)[1].strip() if line.startswith('gitdir:') else g
            if not os.path.isabs(g):
                g = os.path.join(root or os.getcwd(), g)
        head = open(os.path.join(g, 'HEAD'), encoding='utf-8').read().strip()
        return head[len('ref: refs/heads/'):] if head.startswith('ref: refs/heads/') else 'detached'
    except OSError:
        return '-'


# ------------------------------------------------------------------ background tasks

def track_background(root, key, response):
    """A background task returns at once; its work goes to an output file. Remember the file so
    its later writes count as busy time (refresh_background)."""
    m = OUTPUT_RE.search(json.dumps(response) if not isinstance(response, str) else response)
    if not m:
        return False
    path = m.group(1).replace('\\\\', '\\')
    bg = _json_file(root, BG)
    bg[key] = [path, int(time.time())]
    _write_json(root, BG, bg)
    record(root, 'B', key)
    return True


def refresh_background(root):
    """Record an X line for every tracked background output file written since last seen; forget
    files that are gone. One stat per running background task."""
    bg = _json_file(root, BG)
    if not bg:
        return
    changed = False
    for key, (path, last) in list(bg.items()):
        try:
            m = int(os.path.getmtime(path))
        except OSError:
            del bg[key]
            changed = True
            continue
        if m > last:
            record(root, 'X', key, at=m)
            bg[key] = [path, m]
            changed = True
    if changed:
        _write_json(root, BG, bg)


def _json_file(root, name):
    p = state_path(root, name)
    try:
        with open(p, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, TypeError, ValueError):
        return {}


def _write_json(root, name, obj):
    p = state_path(root, name)
    if p:
        with open(p, 'w', encoding='utf-8') as f:
            json.dump(obj, f)


def note_transcript(root, path):
    """Remember the Claude Code transcript a hook came from (background notifications, containers)."""
    p = state_path(root, TRANSCRIPTS)
    if not (path and p and os.path.exists(state_path(root))):
        return
    have = open(p, encoding='utf-8').read().split('\n') if os.path.exists(p) else []
    if path not in have:
        with open(p, 'a', encoding='utf-8') as f:
            f.write(path + '\n')


_PARSED = {}


def transcript_activity(root, branch=None):
    """Background spans, detached-container spans and tool spans from the transcripts this clone's
    hooks saw. Parsed at most once per file version per process."""
    p = state_path(root, TRANSCRIPTS)
    paths = [l for l in open(p, encoding='utf-8').read().split('\n') if l] if p and os.path.exists(p) else []
    out = {'marks': [], 'busy': []}
    for path in paths:
        try:
            k = (path, os.path.getmtime(path), branch)
        except OSError:
            continue
        if k not in _PARSED:
            with open(path, encoding='utf-8', errors='replace') as f:
                a = W.parse_transcript(f, branch)
            busy = a['tools'] + a['background'] + [container_span(t, cid, a['prompts']) for t, cid in a['containers']]
            _PARSED[k] = {'marks': a['marks'], 'busy': [b for b in busy if b]}
        out['marks'] += _PARSED[k]['marks']
        out['busy'] += _PARSED[k]['busy']
    return out


def container_span(launch, cid, prompts):
    """A detached container started by the session is busy until it exits (docker inspect); a
    container already removed counts like a background task with no end signal."""
    try:
        r = subprocess.run(['docker', 'inspect', '-f', '{{.State.Running}}|{{.State.FinishedAt}}', cid],
                           capture_output=True, text=True, timeout=10)
        running, fin = (r.stdout.strip().split('|') + [''])[:2] if r.returncode == 0 else ('', '')
    except (OSError, subprocess.SubprocessError):
        running, fin = '', ''
    now = int(time.time())
    if running == 'true':
        return (launch, now)
    end = W.iso(fin[:26].rstrip('Z') + 'Z' if fin and not fin.startswith('0001') else None)
    if end and end > launch:
        return (launch, end)
    return (launch, W.unended_end(launch, prompts, now))


# ------------------------------------------------------------------ Claude Code hooks

def cmd_hook(root, o, pos):
    """Claude Code hook: activity, tool calls, sub-agents and background tasks. Always exit 0."""
    try:
        ev = json.load(sys.stdin)
    except ValueError:
        return 0
    maybe_implicit(root)
    note_transcript(root, ev.get('transcript_path'))
    name = ev.get('hook_event_name', '')
    tid = 'tool:%s' % (ev.get('tool_use_id') or '-')
    aid = 'agent:%s' % (ev.get('agent_id') or '-')
    refresh_background(root)
    if name == 'PreToolUse':
        record(root, 'B', tid)
    elif name in ('PostToolUse', 'PostToolUseFailure'):
        record(root, 'E', tid)
        if (ev.get('tool_input') or {}).get('run_in_background') or 'background' in json.dumps(
                ev.get('tool_response') or '')[:2000].lower():
            track_background(root, 'bg:%s' % (ev.get('tool_use_id') or int(time.time())), ev.get('tool_response'))
    elif name == 'SubagentStart':
        record(root, 'B', aid)
    elif name == 'SubagentStop':
        record(root, 'E', aid)
    elif name == 'Stop':
        record(root, 'C', 'tool')
    elif name == 'UserPromptSubmit':
        record(root, 'C', 'tool')
        record(root, 'P')
    elif name == 'SessionEnd':
        record(root, 'C', 'all')
        _autopost(root)
    return 0


def _saved_mode(root):
    """The person's saved mode, read from the clone's git config file without running git."""
    common = state_path(root, '')
    try:
        text = open(os.path.join(common, 'config'), encoding='utf-8', errors='replace').read()
    except (OSError, TypeError):
        return 'ask'
    sec = re.search(r'\[cycle "worklog"\](.*?)(?=^\s*\[|\Z)', text, re.S | re.M)
    m = re.search(r'^\s*mode\s*=\s*(\w+)', sec.group(1), re.M) if sec else None
    return m.group(1).lower() if m else 'ask'


def maybe_implicit(root):
    """Ticket work outside a dev-cycle command (a plain "fix the pipeline" request): for a person
    who chose `auto`, activity on a branch named for a Jira key with no session covering it opens
    an implicit session for that key, finished on activity like a follow-up. Never raises."""
    try:
        if _saved_mode(root) != 'auto':
            return
        cfg = T.load_config(root)
        if not cfg.get('jira') or (cfg.get('jira') or {}).get('worklog') == 'off':
            return
        branch = current_branch(root)
        key, _ = T.branch_key(branch, (cfg.get('jira') or {}).get('project'))
        if not key:
            return
        sp = state_path(root)
        if not sp:
            return
        st = load(root)
        for s in st['open'].values():
            if s.get('kind') not in ACTIVITY_KINDS or s.get('key') == key:
                return  # a command's run covers all activity; or this key is already tracked
        now = int(time.time())
        sid = secrets.token_hex(4)
        st['open'][key] = {'id': sid, 'consent': 'auto', 'command': 'implicit', 'kind': 'implicit', 'key': key,
                           'branch': branch, 'head': T.git('rev-parse', 'HEAD', cwd=root) or '',
                           'upstream': _upstream(root), 'intervals': [[now, None]], 'marks': [now]}
        save(root, st)
        reg_open(sid, root)
    except Exception:
        pass


def _autopost(root):
    """At session end, `auto` with preview off posts unposted follow-up / implicit time (the person
    chose that); anything that needs a confirmation (over 8 h, overlap) waits for the next session."""
    try:
        p = personal(root)
        if p['mode'] != 'auto' or p['preview'] != 'off' or effective(root)[0] != 'auto':
            return
        for label, _, _ in pending(root):
            try:
                cmd_finish(root, {'yes': True}, [label])
            except SystemExit:
                pass
    except Exception:
        pass


def _hook_command():
    return T.PY_SH + ' "$CLAUDE_PROJECT_DIR/.cycle/trackers.py" worklog hook' if hasattr(T, 'PY_SH') else \
        '"$(command -v python3 || command -v python)" "$CLAUDE_PROJECT_DIR/.cycle/trackers.py" worklog hook'


def set_hooks(root, on):
    """Add (or remove) the activity hooks in this person's .claude/settings.local.json, which is
    personal and kept out of git (.git/info/exclude). Only people who opted in get them."""
    p = os.path.join(root, LOCAL_SETTINGS)
    try:
        cfg = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
    except ValueError:
        print('worklog: %s is not valid JSON; activity hooks not changed' % LOCAL_SETTINGS)
        return
    hooks = cfg.setdefault('hooks', {})
    probe = 'trackers.py" worklog hook'
    changed = False
    for event in HOOK_EVENTS:
        lst = hooks.get(event, [])
        mine = [h for h in lst if any(probe in c.get('command', '') for c in h.get('hooks', []))]
        if on and not mine:
            hooks.setdefault(event, []).append(
                {'hooks': [{'type': 'command', 'command': _hook_command(),
                            'timeout': 60 if event == 'SessionEnd' else 10}]})
            changed = True
        elif not on and mine:
            hooks[event] = [h for h in lst if h not in mine]
            if not hooks[event]:
                del hooks[event]
            changed = True
    if not changed:
        return
    if not hooks:
        cfg.pop('hooks')
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(cfg, f, indent=2)
        f.write('\n')
    if on:
        _exclude(root, '/' + LOCAL_SETTINGS.replace(os.sep, '/'))
    print('worklog: activity hooks %s %s' % ('added to' if on else 'removed from', LOCAL_SETTINGS))


def _exclude(root, pattern):
    common = state_path(root, '')
    if not common:
        return
    ex = os.path.join(common, 'info', 'exclude')
    have = open(ex, encoding='utf-8').read().split('\n') if os.path.exists(ex) else []
    if pattern not in have:
        os.makedirs(os.path.dirname(ex), exist_ok=True)
        with open(ex, 'a', encoding='utf-8') as f:
            f.write(('' if not have or have[-1] == '' else '\n') + pattern + '\n')


# ------------------------------------------------------------- personal setting

def personal(root):
    def g(k, d):
        return T.git('config', '--local', CFG + k, cwd=root) or d
    try:
        idle = int(g('idle', str(IDLE_MIN)))
    except ValueError:
        idle = IDLE_MIN
    return {'mode': g('mode', 'ask'), 'preview': g('preview', 'on'), 'idle': idle, 'account': g('account', '')}


def me_of(jira):
    ref, name = jira.myself()
    return (ref.get('accountId') or ref.get('name')), name


def policy_off(root):
    """Why worklogs cannot run here by the repo's choice, or None."""
    if T.jira_mode(root) == 'off':
        return 'Jira is off for this repo'
    if (T.load_config(root).get('jira') or {}).get('worklog') == 'off':
        return 'worklogs are off for this repo (jira.worklog)'
    return None


def jira_for(root):
    """(Jira, None) when Jira can be reached with credentials, else (None, reason)."""
    off = policy_off(root)
    if off:
        return None, off
    j = T.Jira(T.load_config(root))
    if j.missing():
        return None, '%s not set' % ', '.join(j.missing())
    return j, None


def effective(root):
    """(state, detail): off | unavailable | never | ask | auto.

    off = the repo's choice; unavailable = credentials not loaded (tracking still works locally;
    posting waits for them); auto only while the saved account is the token's."""
    off = policy_off(root)
    if off:
        return 'off', off
    p = personal(root)
    if p['mode'] == 'never':
        return 'never', 'you chose never in this clone'
    jira, why = jira_for(root)
    if not jira:
        return 'unavailable', '%s: tracking continues locally; posting waits for credentials (saved mode %s)' % (
            why, p['mode'])
    if p['mode'] != 'auto':
        return 'ask', 'no saved choice in this clone'
    try:
        acct, _ = me_of(jira)
    except T.NET_ERRORS as ex:
        return 'ask', 'Jira user not read (%s)' % ex
    if acct != p['account']:
        return 'ask', 'the saved auto belongs to another Jira account'
    return 'auto', 'preview %s, idle cap %d min' % (p['preview'], p['idle'])


def cmd_state(root, o, pos):
    st, detail = effective(root)
    print('%s  (%s)' % (st, detail))
    for label, key, sec in pending(root):
        print('unposted %s (%s): %s; `worklog finish %s` (posting rules as usual) before new work'
              % (label, key, _hm(sec), label))
    return 0


def pending(root):
    """[(label, key, active seconds)] for open sessions with at least a minute of activity: follow-up
    and implicit ones, and runs a command left open (an interrupted /implement). Follow-up and
    implicit ones idle past FOLLOWUP_TTL_S are dropped."""
    try:
        st = load(root)
    except (OSError, ValueError):
        return []
    now, out, stale = int(time.time()), [], []
    for label, s in st['open'].items():
        segs, _, _ = segments(root, s, now)
        sec = W.total(segs)
        last = segs[-1][1] if segs else s['intervals'][0][0]
        if s.get('kind') in ACTIVITY_KINDS and sec < 60 and now - last > FOLLOWUP_TTL_S:
            stale.append(label)
        elif sec >= 60:
            out.append((label, s.get('key', label), sec))
    for label in stale:
        reg_close(st['open'].pop(label)['id'])
    if stale:
        save(root, st)
    return out


def cmd_notice(root, o, pos):
    for label, key, sec in pending(root):
        print('worklog: %s of time on %s (%s) is not posted yet. Tell the person; post it with '
              '`python .cycle/trackers.py worklog finish %s` (.cycle/TRACKERS.md, "Worklogs").'
              % (_hm(sec), key, label, label))
    return 0


def cmd_mode(root, o, pos):
    if not pos or pos[0] not in ('auto', 'ask', 'never'):
        sys.exit('usage: worklog mode auto|ask|never [--preview on|off] [--idle MIN]')
    mode = pos[0]
    if mode == 'auto':
        jira, why = jira_for(root)
        if not jira:
            sys.exit('worklog mode auto: %s' % why)
        try:
            acct, name = me_of(jira)
        except T.NET_ERRORS as ex:
            sys.exit('worklog mode auto: Jira user not read: %s' % ex)
        T.git('config', '--local', CFG + 'account', acct, cwd=root)
        print('auto for %s, in this clone only' % name)
    T.git('config', '--local', CFG + 'mode', mode, cwd=root)
    if mode == 'never':
        set_hooks(root, False)
    elif mode == 'auto':
        set_hooks(root, True)
    if o.get('preview') in ('on', 'off'):
        T.git('config', '--local', CFG + 'preview', o['preview'], cwd=root)
    if o.get('idle'):
        T.git('config', '--local', CFG + 'idle', str(int(o['idle'])), cwd=root)
    p = personal(root)
    print('worklog mode %s (preview %s, idle cap %d min): stored in .git/config, never committed' % (
        p['mode'], p['preview'], p['idle']))
    return 0


# --------------------------------------------- personal registry (all repos on this machine)

def registry_path():
    """Per person, outside every repo: this person's open and recently posted runs, so runs in
    different repos or worktrees can split the minutes they share."""
    return os.environ.get('CYCLE_WORKLOG_REGISTRY') or os.path.join(
        os.path.expanduser('~'), '.claude', 'cycle-worklog-registry.json')


def reg_load():
    try:
        with open(registry_path(), encoding='utf-8') as f:
            r = json.load(f)
    except (OSError, ValueError):
        r = {}
    r.setdefault('open', {})
    r.setdefault('posted', [])
    return r


def reg_save(r):
    p = registry_path()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + '.%d.tmp' % os.getpid()
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(r, f, indent=1)
    os.replace(tmp, p)  # atomic: a reader never sees half a file


def reg_open(sid, root):
    r = reg_load()
    r['open'][sid] = {'root': os.path.abspath(root)}
    reg_save(r)


def reg_close(sid, posted=None):
    r = reg_load()
    r['open'].pop(sid, None)
    cutoff = int(time.time()) - KEEP_POSTED_S
    r['posted'] = [x for x in r['posted'] if x.get('at', 0) >= cutoff and x.get('sid') != sid]
    if posted:
        r['posted'].append(posted)
    reg_save(r)


def other_runs(sid, now):
    """[(name, active segments)] for this person's other runs: open ones measured live from their
    repo, posted ones from the segments they recorded. Stale open entries are dropped."""
    r = reg_load()
    out, stale = [], []
    for osid, x in r['open'].items():
        if osid == sid:
            continue
        found = _find_session(x['root'], osid)
        if not found:
            stale.append(osid)
            continue
        label, sess = found
        segs, _, _ = segments(x['root'], sess, now)
        out.append(('%s in %s' % (label, os.path.basename(x['root'])), segs))
    for x in r['posted']:
        if x.get('sid') != sid:
            out.append(('%s (posted)' % x.get('key', '?'), [tuple(g) for g in x.get('segs', [])]))
    if stale:
        for osid in stale:
            r['open'].pop(osid, None)
        reg_save(r)
    return out


def _find_session(root, sid):
    if not os.path.isdir(root):
        return None
    try:
        st = load(root)
    except (OSError, ValueError):
        return None
    for label, s in st['open'].items():
        if s.get('id') == sid:
            return label, s
    return None


# ---------------------------------------------------------------------- sessions

def _resolve(st, label):
    """A label, following retarget aliases (`run` -> the ticket it became)."""
    seen = set()
    while label in st['alias'] and label not in st['open'] and label not in seen:
        seen.add(label)
        label = st['alias'][label]
    return label


def _open(st, label):
    real = _resolve(st, label or '')
    s = st['open'].get(real)
    if not s:
        sys.exit('worklog: no open session %s (worklog status)' % (label or '?'))
    return real, s


def _upstream(root):
    return T.git('rev-parse', '@{u}', cwd=root) or ''


def cmd_start(root, o, pos):
    if not pos:
        sys.exit('usage: worklog start LABEL --consent run|auto')
    label, consent = pos[0], o.get('consent')
    if consent not in ('run', 'auto'):
        sys.exit('worklog start: --consent run (the person said yes for this run) or auto is required')
    state, detail = effective(root)
    if state in ('off', 'never'):
        sys.exit('worklog start: %s' % detail)
    if consent == 'auto' and not (state == 'auto' or (state == 'unavailable' and personal(root)['mode'] == 'auto')):
        sys.exit('worklog start: --consent auto, but this clone is %s (%s): ask the person' % (state, detail))
    st = load(root)
    if label in st['open']:
        return cmd_resume(root, o, pos)
    st['alias'].pop(label, None)  # a new run reusing a label (`run`) is new, not the old alias
    now = int(time.time())
    sid = secrets.token_hex(4)
    st['open'][label] = {'id': sid, 'consent': consent, 'command': o.get('command', ''),
                         'head': T.git('rev-parse', 'HEAD', cwd=root) or '', 'upstream': _upstream(root),
                         'intervals': [[now, None]], 'marks': [now]}
    _absorb_implicit(st, label, current_branch(root))
    save(root, st)
    reg_open(sid, root)
    set_hooks(root, True)
    print('worklog: tracking %s (%s consent)%s' % (
        label, consent, '; credentials not loaded: posting waits for them' if state == 'unavailable' else ''))
    return 0


def _absorb_implicit(st, label, branch):
    """A command's run on a branch with an implicit session continues that session's time."""
    for k, s in list(st['open'].items()):
        if k != label and s.get('kind') == 'implicit' and s.get('branch') == branch:
            run = st['open'][label]
            run['intervals'] = sorted(_closed_before(s['intervals'], run['intervals'][0][0]) + run['intervals'])
            run['marks'] = sorted(s['marks'] + run['marks'])
            run['head'], run['upstream'] = s.get('head', run['head']), s.get('upstream', run['upstream'])
            st['open'].pop(k)
            reg_close(s['id'])


def _closed_before(intervals, t):
    return [[a, t if b is None or b > t else b] for a, b in intervals if a < t]


def cmd_pause(root, o, pos):
    st = load(root)
    label, s = _open(st, pos[0] if pos else '')
    if s['intervals'][-1][1] is None:
        s['intervals'][-1][1] = int(time.time())
        save(root, st)
    print('worklog: %s paused' % label)
    return 0


def cmd_resume(root, o, pos):
    st = load(root)
    label, s = _open(st, pos[0] if pos else '')
    if s['intervals'][-1][1] is not None:
        now = int(time.time())
        s['intervals'].append([now, None])
        s['marks'].append(now)
        save(root, st)
    print('worklog: %s resumed' % label)
    return 0


def cmd_retarget(root, o, pos):
    if len(pos) != 2:
        sys.exit('usage: worklog retarget OLD NEW')
    st = load(root)
    old, src = _open(st, pos[0])
    new = pos[1]
    if old == new:
        print('worklog: %s is already %s' % (pos[0], new))
        return 0
    dest = st['open'].get(new)
    if dest and dest.get('kind') in ACTIVITY_KINDS:
        # A new run on a ticket with follow-up or implicit time open: one session, from that
        # session's start, finished like any run.
        st['open'].pop(old)
        dest['intervals'] = sorted(_closed_before(dest['intervals'], src['intervals'][0][0]) + src['intervals'])
        dest['marks'] = sorted(dest['marks'] + src['marks'])
        dest['consent'] = src['consent']
        for k in ('kind', 'after', 'branch'):
            dest.pop(k, None)
        reg_close(src['id'])
        msg = 'worklog: %s joined the open time on %s; use %s from here on' % (old, new, new)
    elif dest:
        sys.exit('worklog: %s already has an open session' % new)
    else:
        st['open'][new] = st['open'].pop(old)
        msg = 'worklog: %s -> %s; use %s from here on (%s still works)' % (old, new, new, old)
    st['alias'][old] = new
    save(root, st)
    print(msg)
    return 0


def cmd_drop(root, o, pos):
    st = load(root)
    label, s = _open(st, pos[0] if pos else '')
    st['open'].pop(label)
    save(root, st)
    prune_events(root, st)
    reg_close(s['id'])
    print('worklog: %s dropped, nothing posted' % label)
    return 0


# ---------------------------------------------------------------------- measuring

def _changed_files(root, head):
    files = set()
    for args in (('diff', '--name-only', head) if head else ('diff', '--name-only'),
                 ('ls-files', '--others', '--exclude-standard')):
        files.update(l for l in (T.git(*args, cwd=root) or '').splitlines() if l)
    return files


def _changed_mtimes(root, head):
    out = []
    for f in _changed_files(root, head):
        try:
            out.append(int(os.path.getmtime(os.path.join(root, f))))
        except OSError:
            pass
    return out


def _commits(root, head):
    if not head:
        return []
    out = T.git('log', '--format=%ct\t%s', '%s..HEAD' % head, cwd=root) or ''
    return [(int(t), subj) for t, subj in (l.split('\t', 1) for l in out.splitlines() if '\t' in l)]


def segments(root, s, now):
    """A session's active segments from everything its clone recorded: hook lines, trackers.py
    calls, commits, changed files, and the transcripts the hooks saw."""
    refresh_background(root)
    ev = events_for(s, read_events(root))
    tr = transcript_activity(root, s.get('branch') if s.get('kind') in ACTIVITY_KINDS else None)
    marks = s['marks'] + [e[0] for e in ev] + [t for t, _ in _commits(root, s['head'])] + \
        _changed_mtimes(root, s['head']) + tr['marks']
    return W.active_segments(s['intervals'], marks, personal(root)['idle'] * 60, now,
                             W.spans(ev, now, tr['busy']))


def _hm(sec):
    m = max(1, int(round(sec / 60.0)))
    return '%dh %02dm' % divmod(m, 60) if m >= 60 else '%dm' % m


def _when(t):
    return datetime.datetime.fromtimestamp(t).astimezone().strftime('%Y-%m-%dT%H:%M:%S.000%z')


def targets(root, label, s, o):
    """[(Jira key, weight, entry)] the time goes to. A Jira key or a stored key: itself. A tracker id:
    its entry's key; a cross-app id: the slice named by --app/--tracker, or every slice weighted by
    the share of changed files under its app folder (files elsewhere split evenly)."""
    if s.get('key'):
        return [(s['key'], 1.0, None)]
    if label == 'run':
        sys.exit('worklog finish: `run` was never retargeted to a ticket or bundle (worklog retarget run <ID>)')
    if T.KEY_RE.match(label) and not label.startswith(('BUG-', 'FEAT-')):
        return [(label, 1.0, None)]
    if o.get('app') or o.get('tracker'):
        _, e = T.locate(root, label, o.get('tracker'), o.get('app'))
        return [(_key_of(label, e), 1.0, e)]
    cfg = T.load_config(root)
    paths = [p for p in T.tracker_files(root) if ('### [%s]' % label) in T.read(p)]
    if len(paths) <= 1:
        _, e = T.locate(root, label)
        return [(_key_of(label, e), 1.0, e)]
    slices = []
    for p in paths:
        e = T.TrackerFile(p).get(label)
        folder = os.path.relpath(os.path.dirname(p), root).replace(os.sep, '/')
        slices.append((_key_of(label, e), folder, e))
    files = _changed_files(root, s.get('head'))
    counts = [sum(1 for f in files if f.startswith(folder.rstrip('/') + '/')) for _, folder, _ in slices]
    rest = len(files) - sum(counts)
    weights = [c + rest / float(len(slices)) for c in counts] if files else [1.0] * len(slices)
    tot = sum(weights) or 1.0
    return [(k, w / tot, e) for (k, _, e), w in zip(slices, weights)]


def _key_of(label, e):
    key = (e.value('Jira') if e else '') or ''
    if not T.KEY_RE.match(key):
        sys.exit('worklog finish: %s has no Jira key (jira sync first)' % label)
    return key


def _summary(o, entries):
    if o.get('comment-file') == '-':
        return sys.stdin.read().strip()
    if o.get('comment-file'):
        return T.read(o['comment-file']).strip()
    for e in entries:
        v = e and (e.value('Fix') or e.value('Implementation'))
        if v:
            return v
    return ''


def plan(root, label, s, o, now, segs, tag):
    """The worklog blocks to post: one per active window (a new one after a quiet stretch longer than
    twice the idle cap, or a new day), each with this run's share of shared minutes, split over the
    targets. --minutes rescales the blocks, each still ending where its window's work ended (so an
    edit never reaches into the future or past the work); --started posts one block at that time."""
    idle = personal(root)['idle'] * 60
    others = other_runs(s['id'], now)
    wins = W.windows(segs, 2 * idle)
    got, ends, shared = [], [], {}
    for a, b, wsegs in wins:
        mine, by = W.share(wsegs, others)
        got.append((a, mine))
        ends.append(b)
        for k, v in by.items():
            shared[k] = shared.get(k, 0) + v
    if o.get('started'):
        t0 = W.iso(o['started'])
        if t0 is None:
            sys.exit('worklog: --started must be ISO 8601, e.g. 2026-10-29T13:17:00-04:00')
        mins = int(o['minutes']) if o.get('minutes') else max(1, int(round(sum(m for _, m in got) / 60.0)))
        got = [(t0, mins * 60.0)]
    elif o.get('minutes'):
        mins = W.scale_minutes([m for _, m in got] or [1], int(o['minutes']))
        base = list(zip(got, ends)) or [((now, 1), now)]
        got = [(min(a, b - m * 60), m * 60.0) for ((a, _), b), m in zip(base, mins)]
    blocks = []
    for key, weight, _ in targets(root, label, s, o):
        for i, (a, sec) in enumerate(got):
            m = int(round(sec * weight / 60.0))
            if m >= 1:
                blocks.append({'key': key, 'start': int(a), 'seconds': m * 60,
                               'marker': '[cycle-worklog %s %s#%d%s]' % (label, s['id'], i, tag(key))})
    return blocks, shared


def git_evidence(root, s):
    """(commits, notes): new commits since the start, and push / rebase evidence without one."""
    commits = _commits(root, s.get('head'))
    notes = []
    head = T.git('rev-parse', 'HEAD', cwd=root) or ''
    if s.get('head') and head and head != s['head'] and subprocess.run(
            ['git', 'merge-base', '--is-ancestor', s['head'], head], cwd=root, capture_output=True).returncode != 0:
        notes.append('HEAD rewritten (rebase or amend)')
    up = _upstream(root)
    if up and up != s.get('upstream', ''):
        notes.append('pushed %s' % (T.git('rev-parse', '--abbrev-ref', '@{u}', cwd=root) or 'upstream'))
    return commits, notes


# ---------------------------------------------------------------------- Jira

def jira_overlaps(jira, blocks, ours):
    """This person's other Jira worklogs (any issue, any machine, entered by hand or not) that overlap
    the blocks about to be posted, exactly as they will be posted (edited durations included).
    Worklogs this machine's runs posted (marker ids in OURS) are already split and skipped."""
    if not blocks:
        return []
    ref, _ = jira.myself()
    day = datetime.datetime.fromtimestamp(min(b['start'] for b in blocks) - 86400).strftime('%Y-%m-%d')
    res = jira.search('worklogAuthor = currentUser() AND worklogDate >= "%s"' % day, ['summary'], 50)
    out = []
    for issue in res.get('issues', []):
        logs = jira.req('GET', '/rest/api/2/issue/%s/worklog?maxResults=1000' % issue['key']).get('worklogs', [])
        for x in logs:
            a = x.get('author') or {}
            if not all(a.get(k) == v for k, v in ref.items()):
                continue
            c = str(x.get('comment') or '')
            if any(m in c for m in ours):
                continue
            b0 = W.iso(_iso_fix(x.get('started')))
            if b0 is None:
                continue
            b1 = b0 + int(x.get('timeSpentSeconds') or 0)
            ov = sum(min(b['start'] + b['seconds'], b1) - max(b['start'], b0) for b in blocks
                     if b['start'] + b['seconds'] > b0 and b['start'] < b1)
            if ov > 0:
                out.append((issue['key'], x.get('id'), ov))
    return out


def _iso_fix(text):
    """Jira's `2026-10-28T09:00:00.000-0400` -> ISO with a colon in the offset."""
    if isinstance(text, str) and re.search(r'[+-]\d{4}$', text):
        return text[:-2] + ':' + text[-2:]
    return text


def post_block(jira, b, comment):
    """Post once: a worklog already carrying this block's marker is not posted again. (id, new)."""
    logs = jira.req('GET', '/rest/api/2/issue/%s/worklog?maxResults=1000' % b['key']).get('worklogs', [])
    hit = next((x for x in logs if b['marker'] in str(x.get('comment') or '')), None)
    if hit:
        return hit['id'], False
    r = jira.req('POST', '/rest/api/2/issue/%s/worklog' % b['key'], {
        'started': _when(b['start']), 'timeSpentSeconds': b['seconds'], 'comment': comment + '\n' + b['marker']})
    return r.get('id'), True


def publish(root, o, label, s, blocks, comment, shared, info):
    """Preview, the confirmation rules, and posting, shared by finish, log and backfill.
    Returns (exit code, posted ids or None)."""
    total_s = sum(b['seconds'] for b in blocks)
    print('worklog %s: %s in %d block(s) (%s%s)' % (
        ', '.join(sorted({b['key'] for b in blocks})) or '-', _hm(total_s) if total_s else '0m', len(blocks), info,
        '; duration edited' if o.get('minutes') or o.get('started') else ''))
    for b in blocks:
        print('  %s  %s  %s' % (b['key'], _when(b['start']), _hm(b['seconds'])))
    for name, sec in sorted(shared.items()):
        print('  shared %s with %s: split evenly' % (_hm(sec), name))
    print('  ' + comment.replace('\n', '\n  '))
    if not blocks:
        print('nothing to post (under a minute)')
        return 0, None
    jira, why = jira_for(root)
    overlaps, checked = [], False
    if jira:
        ours = [' %s' % x.get('sid') for x in reg_load()['posted'] if x.get('sid')] + [' %s#' % s['id']]
        try:
            overlaps, checked = jira_overlaps(jira, blocks, ours), True
        except T.NET_ERRORS as ex:
            print('  overlap with your other Jira worklogs NOT CHECKED: %s' % ex)
    else:
        print('  not posted until Jira is reachable: %s' % why)
    for key, wid, sec in overlaps:
        print('OVERLAPS your worklog %s #%s by %s. Always ask the person; post only with `--confirm-overlap` '
              'after they confirm (or edit with --minutes N / --started ISO).' % (key, wid, _hm(sec)))
    long_ = total_s > LONG_S
    if long_:
        print('OVER 8 HOURS: %s. Always ask the person to confirm or edit the duration; post only with '
              '`--confirm-long` after they confirm.' % _hm(total_s))
    if not o.get('yes'):
        print('preview only (these numbers are what --yes posts for the next 2 h): add --yes [--minutes N]')
        return (NEEDS_CONFIRM if long_ or overlaps else 0), None
    if long_ and not o.get('confirm-long'):
        print('not posted: over 8 hours needs the person\'s confirmation (--confirm-long)')
        return NEEDS_CONFIRM, None
    if not jira:
        sys.exit('worklog: %s; session kept, post once credentials are loaded' % why)
    if not checked:
        sys.exit('worklog: not posted: overlap with your other worklogs could not be checked; session kept')
    if overlaps and not o.get('confirm-overlap'):
        print('not posted: overlaps your other Jira worklogs; needs the person\'s confirmation (--confirm-overlap)')
        return NEEDS_CONFIRM, None
    ids = []
    try:
        for b in blocks:
            wid, new = post_block(jira, b, comment)
            ids.append([b['key'], wid])
            print('  %s #%s %s%s' % (b['key'], wid, _hm(b['seconds']), '' if new else ' (already posted)'))
    except T.NET_ERRORS as ex:
        sys.exit('worklog: not posted: %s; session kept, retry (posted blocks are not posted twice)' % ex)
    print('worklog: posted %s; undo: worklog undo %s' % (_hm(total_s), label))
    return 0, ids


def _record_post(root, st, label, s, blocks, ids, segs, now):
    st['posted'] = (st.get('posted') or [])[-49:] + [
        {'label': label, 'key': blocks[0]['key'], 'ids': ids, 'seconds': sum(b['seconds'] for b in blocks),
         'at': now, 'sid': s['id']}]
    reg_close(s['id'], {'sid': s['id'], 'key': blocks[0]['key'], 'at': now, 'segs': [list(g) for g in segs]})


def cmd_finish(root, o, pos):
    if not pos:
        sys.exit('usage: worklog finish LABEL [--app A|--tracker P] [--yes] [--minutes N] [--started ISO] ...')
    st = load(root)
    label, s = _open(st, pos[0])
    now = int(time.time())
    if o.get('yes') and s.get('preview_at') and now - s['preview_at'] <= PREVIEW_HOLD_S and not o.get('minutes'):
        now = s['preview_at']  # post what the preview showed; later activity goes to the follow-up
    segs, elapsed, dropped = segments(root, s, now)
    commits, notes = git_evidence(root, s)
    activity = W.total(segs)
    if s.get('kind') in ACTIVITY_KINDS:
        if activity < 60 and not commits and not notes:
            print('worklog %s: no work recorded since %s; nothing to post' % (s.get('key', label), _when(s['intervals'][0][0])))
            return 0
    elif not commits and not notes and not o.get('force'):
        sys.exit('worklog finish: nothing committed, pushed or rebased since %s started; not logged '
                 '(commit or push first, or --force for work that leaves no git trace)' % label)
    entries = [e for _, _, e in targets(root, label, s, o)]
    summary = _summary(o, entries)
    if s.get('kind') == 'followup':
        summary = 'Follow-up after worklog #%s (push, PR, CI fixes, rebase, builds)%s' % (
            s.get('after', '?'), ': ' + summary if summary else '')
    elif s.get('kind') == 'implicit':
        summary = 'Work on %s outside a dev-cycle command%s' % (s.get('key'), ': ' + summary if summary else '')
    lines = ([summary] if summary else []) + (['Commits:'] + ['- %s' % subj for _, subj in commits[:15]] if commits else []) \
        + (['Git: %s' % '; '.join(notes)] if notes else [])
    blocks, shared = plan(root, label, s, o, now, segs, lambda k: '' if len({t[0] for t in targets(root, label, s, o)}) == 1 else '/' + k)
    info = 'active %s of %s elapsed; %d idle gap(s) over %d min dropped' % (
        _hm(activity), _hm(elapsed), dropped, personal(root)['idle'])
    code, ids = publish(root, o, label, s, blocks, '\n'.join(lines), shared, info)
    if ids is None:
        if not o.get('yes'):
            s['preview_at'] = now
            save(root, st)
        return code
    st['open'].pop(label)
    _record_post(root, st, label, s, blocks, ids, segs, now)
    # Work on the ticket rarely ends at this post (push, PR, CI fixes, rebases, builds): keep
    # tracking it on the same ticket and branch, with the same consent, until the next finish.
    fu = {'id': secrets.token_hex(4), 'consent': s['consent'], 'command': 'followup', 'kind': 'followup',
          'key': blocks[0]['key'], 'after': ids[0][1], 'branch': current_branch(root),
          'head': T.git('rev-parse', 'HEAD', cwd=root) or '', 'upstream': _upstream(root),
          'intervals': [[now, None]], 'marks': []}
    st['open'][label] = fu
    save(root, st)
    prune_events(root, st)
    reg_open(fu['id'], root)
    print('worklog: follow-up time on %s (%s) is tracked from now' % (fu['key'], fu['branch']))
    return 0


def _manual(root, o, key, segs, comment, info, kind):
    """Shared by log and backfill: a one-off post for KEY from explicit segments."""
    if not T.KEY_RE.match(key or ''):
        sys.exit('worklog %s: KEY must be a Jira key' % kind)
    state, detail = effective(root)
    if state in ('off', 'never'):
        sys.exit('worklog %s: %s' % (kind, detail))
    now = int(time.time())
    s = {'id': secrets.token_hex(4), 'key': key, 'intervals': [[segs[0][0], segs[-1][1]]] if segs else [[now, now]]}
    blocks, shared = plan(root, kind, s, o, now, segs, lambda k: '')
    code, ids = publish(root, o, kind, s, blocks, comment, shared, info)
    if ids:
        st = load(root)
        _record_post(root, st, kind, s, blocks, ids, segs, now)
        save(root, st)
    return code


def cmd_log(root, o, pos):
    """After the fact: KEY --started ISO --minutes N. Same checks, marker and split as a run
    (--exact skips the split with your other runs)."""
    if not pos or not o.get('started') or not o.get('minutes'):
        sys.exit('usage: worklog log KEY --started ISO --minutes N [--comment-file F|-] [--exact] [--yes] [--confirm-…]')
    t0 = W.iso(o['started'])
    if t0 is None:
        sys.exit('worklog log: --started must be ISO 8601, e.g. 2026-10-29T13:17:00-04:00')
    seg = [(t0, t0 + int(o['minutes']) * 60)]
    if o.get('exact'):
        o = dict(o, minutes=o['minutes'])
    else:
        o = dict(o)
        o.pop('minutes')
        o.pop('started')
    comment = _summary(o, []) or 'Logged after the fact'
    return _manual(root, o, pos[0], seg, comment, 'logged after the fact', 'log')


def cmd_backfill(root, o, pos):
    """Rebuild untracked time on KEY from a Claude Code transcript (tool calls, background tasks,
    detached containers), window it, split it, and post it like a run."""
    if not pos or not o.get('transcript'):
        sys.exit('usage: worklog backfill KEY --transcript F.jsonl [--since ISO] [--until ISO] [--branch B] [--yes]')
    lo, hi = W.iso(o.get('since')) or 0, W.iso(o.get('until')) or int(time.time())
    with open(o['transcript'], encoding='utf-8', errors='replace') as f:
        a = W.parse_transcript(f, o.get('branch'))
    marks = [m for m in a['marks'] if lo <= m <= hi]
    if not marks:
        sys.exit('worklog backfill: no activity in that window')
    busy = a['tools'] + a['background'] + [container_span(t, cid, a['prompts']) for t, cid in a['containers']]
    segs, elapsed, dropped = W.active_segments([[max(lo, min(marks)), min(hi, max(marks))]], marks,
                                               personal(root)['idle'] * 60, hi, [b for b in busy if b])
    comment = _summary(o, []) or 'Rebuilt from the session transcript'
    info = 'active %s of %s; %d idle gap(s) dropped; from %s' % (_hm(W.total(segs)), _hm(elapsed), dropped,
                                                                  os.path.basename(o['transcript']))
    return _manual(root, o, pos[0], segs, comment, info, 'backfill')


def cmd_undo(root, o, pos):
    if not pos:
        sys.exit('usage: worklog undo LABEL|KEY')
    st = load(root)
    want = {pos[0], _resolve(st, pos[0])}
    hit = next((p for p in reversed(st['posted']) if want & {p['label'], p['key']}), None)
    if not hit:
        sys.exit('worklog undo: nothing this clone posted for %s' % pos[0])
    jira, why = jira_for(root)
    if not jira:
        sys.exit('worklog undo: %s' % why)
    for key, wid in hit.get('ids') or [[hit['key'], hit.get('id')]]:
        try:
            jira.req('DELETE', '/rest/api/2/issue/%s/worklog/%s' % (key, wid))
            print('worklog %s: #%s deleted' % (key, wid))
        except T.NET_ERRORS as ex:
            sys.exit('worklog undo: %s #%s: %s' % (key, wid, ex))
    st['posted'].remove(hit)
    save(root, st)
    if hit.get('sid'):
        reg_close(hit['sid'])
    return 0


def cmd_sync(root, o, pos):
    """Refresh this clone's posted worklogs from Jira by id: edited durations, deleted blocks."""
    jira, why = jira_for(root)
    if not jira:
        sys.exit('worklog sync: %s' % why)
    st = load(root)
    for p in st['posted']:
        keep, total_s = [], 0
        for key, wid in p.get('ids') or [[p['key'], p.get('id')]]:
            try:
                x = jira.req('GET', '/rest/api/2/issue/%s/worklog/%s' % (key, wid))
                keep.append([key, wid])
                total_s += int(x.get('timeSpentSeconds') or 0)
            except T.JiraError as ex:
                if ex.code != 404:
                    raise
                print('worklog %s: #%s was deleted in Jira' % (key, wid))
            except T.NET_ERRORS as ex:
                sys.exit('worklog sync: %s' % ex)
        if total_s != p.get('seconds') and keep:
            print('worklog %s: %s -> %s (edited in Jira)' % (p['key'], _hm(p.get('seconds', 0)), _hm(total_s)))
        p['ids'], p['seconds'] = keep, total_s
    st['posted'] = [p for p in st['posted'] if p['ids']]
    save(root, st)
    print('worklog sync: %d post(s) up to date' % len(st['posted']))
    return 0


def cmd_status(root, o, pos):
    state, detail = effective(root)
    print('mode   %s (%s)' % (state, detail))
    st = load(root)
    now = int(time.time())
    for label, s in st['open'].items():
        segs, e, _ = segments(root, s, now)
        print('open   %-14s %s%s consent, active %s of %s%s' % (
            label, s.get('kind', 'run') + ', ' if s.get('kind') else '', s['consent'], _hm(W.total(segs)) if segs else '0m',
            _hm(e), '' if s['intervals'][-1][1] is None else ' (paused)'))
    for p in st['posted'][-5:]:
        print('posted %-14s %s %s in %d block(s)' % (p['label'], p['key'], _hm(p['seconds']), len(p.get('ids') or [1])))
    return 0


SUBS = {'hook': cmd_hook, 'state': cmd_state, 'mode': cmd_mode, 'start': cmd_start, 'pause': cmd_pause,
        'resume': cmd_resume, 'retarget': cmd_retarget, 'drop': cmd_drop, 'notice': cmd_notice,
        'finish': cmd_finish, 'log': cmd_log, 'backfill': cmd_backfill, 'undo': cmd_undo, 'sync': cmd_sync,
        'status': cmd_status}


def main(argv):
    if not argv or argv[0] not in SUBS:
        sys.exit(__doc__)
    if argv[0] == 'hook':
        try:
            return cmd_hook(os.environ.get('CLAUDE_PROJECT_DIR') or T.repo_root(), {}, [])
        except Exception:
            return 0
    o, pos = T.opts(argv[1:], flags=('yes', 'force', 'confirm-long', 'confirm-overlap', 'exact'))
    return SUBS[argv[0]](T.repo_root(), o, pos)
