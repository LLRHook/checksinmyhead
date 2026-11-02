"""Tracker writers, schema and Jira sync for the dev-cycle trackers (stdlib only).

Imported by trackers.py; run everything through `python .cycle/trackers.py <cmd>`.
Format reference: .cycle/TRACKERS.md (source: trackers/references/tracker-format.md).
"""
import base64, datetime, fnmatch, http.client, json, os, re, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

HEAD_RE = re.compile(r'^### \[((?:BUG|FEAT)-\d+[a-z]*)\] (\S.*?)\s*$')
FIELD_RE = re.compile(r'^- (\[[ xX]\] )?\*\*(.+?):\*\*(?: (.*?))?\s*$')
FENCE_RE = re.compile(r'^(\s*)(```|~~~)')
KEY_RE = re.compile(r'^[A-Z][A-Z0-9]+-\d+$')
ANYKEY_RE = re.compile(r'\b[A-Z][A-Z0-9]+-\d+\b')
DATE_RE = re.compile(r'\b(\d{4}-\d{2}-\d{2})\b')
LEVELS = ('crit', 'high', 'med', 'low')
BUMPS = ('major', 'minor', 'patch')
ACTIVE = {'bug': ('open', 'in-progress', 'fixed-pending-migration'),
          'feature': ('open', 'in-progress', 'shipped-pending-migration')}
CLOSE_REASONS = ('duplicate', 'wontfix', 'superseded', 'cannot-reproduce', 'not-a-defect')
CLOSED_RE = re.compile(r'migrated|shipped(?!-pending)|fixed(?!-pending)|closed|released|done|won.?t|wontfix|'
                       r'duplicate|superseded|rejected|cannot-reproduce|not-a-defect|obsolete|withdrawn|invalid', re.I)
SCHEMA = {
    'bug': ['Severity', 'Area', 'File(s)', 'Observation', 'Expected', 'Req', 'Depends on', 'Repro / Notes',
            'Bump', 'Jira', 'Jira parent?', 'Bundle?', 'Assignee?', 'Status', 'Fix?', 'Docs?', 'Cross-ref?', 'Log?'],
    'feature': ['Priority', 'Area', 'File(s)', 'Req', 'Depends on', 'UI', 'Why', 'Approach',
                'Library / dependency notes', 'Acceptance criteria', 'Test plan', 'Out of scope',
                'Bump', 'Jira', 'Jira parent?', 'Bundle?', 'Assignee?', 'Status', 'Implementation?', 'Docs?', 'Cross-ref?', 'Log?'],
}
ENUMS = {'Severity': LEVELS, 'Priority': LEVELS, 'Bump': BUMPS}
NO_UNKNOWN = {'Severity', 'Priority', 'Bump', 'Status', 'Jira', 'Jira parent', 'Bundle', 'Area'}
ISSUE_TYPES = {'bug': 'Bug', 'feature': 'Story', 'bundle': 'Task'}  # jira.issueTypes overrides each
BUNDLE_LABEL = 'cycle-bundle'
ALIASES = {'Blocked-on': 'Depends on', 'Blocked on': 'Depends on', 'Blocked by': 'Depends on',
           'Docs (required — do not close without them)': 'Docs', 'Parent': 'Jira parent',
           'Files': 'File(s)', 'File': 'File(s)', 'Repro': 'Repro / Notes', 'Notes': 'Repro / Notes',
           'Acceptance Criteria': 'Acceptance criteria', 'Test Plan': 'Test plan'}
PRIORITY_JIRA = {'crit': 'Highest', 'high': 'High', 'med': 'Medium', 'low': 'Low'}
TRACKER_FILES = ('bugs.md', 'features.md')


def fields_of(kind):
    return [f.rstrip('?') for f in SCHEMA[kind]]


def required_of(kind, jira=None):
    req = [f for f in SCHEMA[kind] if not f.endswith('?')]
    if not (jira_mode() == 'enforce' if jira is None else jira):
        req.remove('Jira')  # Jira stays an allowed, ordered field; required only when enforced
    return req


def kind_of(path):
    b = os.path.basename(path).lower()
    return 'bug' if b == 'bugs.md' else 'feature' if b == 'features.md' else None


def today():
    return datetime.date.today().isoformat()


# ---------------------------------------------------------------- entry model

class Entry:
    def __init__(self, eid, title):
        self.id, self.title = eid, title
        self.fields = []     # [name, [inline, cont...]]
        self.box = None      # ' ' / 'x' on the first field, None when absent
        self.stray = []      # lines before the first field
        self.boxes = 0       # fields carrying a checkbox

    def find(self, name):
        for f in self.fields:
            if f[0] == name:
                return f
        return None

    def value(self, name):
        f = self.find(name)
        return f[1][0].strip() if f else None

    def text(self, name):
        f = self.find(name)
        if not f:
            return None
        cont = [l[2:] if l.startswith('  ') else l for l in f[1][1:]]
        return '\n'.join([f[1][0]] + cont).strip('\n')

    def set(self, kind, name, value):
        lines = value_lines(value)
        f = self.find(name)
        if f:
            f[1] = lines
            return
        order = fields_of(kind)
        pos = order.index(name) if name in order else len(order)
        idx = len(self.fields)
        for i, (n, _) in enumerate(self.fields):
            if n in order and order.index(n) > pos:
                idx = i
                break
        self.fields.insert(idx, [name, lines])

    def drop(self, name):
        self.fields = [f for f in self.fields if f[0] != name]

    def status(self):
        v = self.value('Status')
        return (v or '').strip('`* ').lower()

    def render(self):
        out = ['### [%s] %s' % (self.id, self.title)]
        for i, (name, lines) in enumerate(self.fields):
            box = '[%s] ' % (self.box or ' ') if i == 0 else ''
            inline = lines[0] if lines else ''
            out.append(('- %s**%s:** %s' % (box, name, inline)).rstrip())
            cont = list(lines[1:])
            while cont and not cont[-1].strip():
                cont.pop()
            out += cont
        return '\n'.join(out) + '\n'


def value_lines(value):
    value = (value or '').replace('\r\n', '\n').strip('\n')
    parts = value.split('\n')
    if re.match(r'^\s*([-*] |\d+\. |```|~~~)', parts[0]):
        parts = [''] + parts  # a list or a code block starts on its own line under the field
    first, rest = parts[0].strip(), parts[1:]
    return [first] + [('  ' + l if l.strip() and not l.startswith('  ') else l.rstrip()) for l in rest]


def parse_entry(text):
    lines = text.rstrip('\n').split('\n')
    m = HEAD_RE.match(lines[0])
    if m:
        e = Entry(m.group(1), m.group(2))
    else:
        m2 = re.match(r'^###\s+\[([^\]]+)\]\s*(.*)$', lines[0])
        e = Entry(m2.group(1) if m2 else '?', (m2.group(2) if m2 else lines[0]).strip())
        e.badhead = True
    cur, fence = None, False
    for line in lines[1:]:
        fm = FENCE_RE.match(line)
        if not fence:
            m = FIELD_RE.match(line)
            if m:
                cur = [m.group(2).strip(), [m.group(3) or '']]
                if m.group(1):
                    e.boxes += 1
                    if not e.fields:
                        e.box = 'x' if 'x' in m.group(1).lower() else ' '
                e.fields.append(cur)
                continue
        (cur[1] if cur else e.stray).append(line)
        if fm:
            fence = not fence
    if cur is None:
        e.stray = [l for l in e.stray]
    return e


# ---------------------------------------------------------------- lint

def lint_entry(e, kind):
    """Return [(code, severity, message)]; severity is 'E' or 'W'."""
    out = []
    if getattr(e, 'badhead', False):
        out.append(('HEAD', 'E', 'heading must be "### [BUG|FEAT-<digits>] <title>"'))
    if kind == 'bug' and not e.id.startswith('BUG-') or kind == 'feature' and not e.id.startswith('FEAT-'):
        out.append(('KIND', 'E', '%s filed in the %s tracker' % (e.id, kind)))
    if any(l.strip() for l in e.stray):
        out.append(('STRAY', 'E', 'text between the heading and the first field'))
    names = [f[0] for f in e.fields]
    allowed = fields_of(kind)
    for n in names:
        if n not in allowed:
            out.append(('FIELD', 'E', 'unknown field "%s" (fold it into Log)' % n))
    for n in set(names):
        if names.count(n) > 1:
            out.append(('DUPFIELD', 'E', 'field "%s" appears %d times' % (n, names.count(n))))
    for n in required_of(kind):
        if n not in names:
            out.append(('MISSING', 'E', 'required field "%s" missing' % n))
    known = [n for n in names if n in allowed]
    if known != sorted(known, key=allowed.index):
        out.append(('ORDER', 'E', 'fields out of canonical order (fixable)'))
    if e.box is None or e.boxes != 1:
        out.append(('BOX', 'E', 'exactly the first field carries the checkbox (fixable)'))
    st = e.status()
    if st and st not in ACTIVE[kind]:
        if CLOSED_RE.search(st):
            out.append(('CLOSED', 'E', 'status "%s": remove with `migrate` or `close`' % st))
        else:
            out.append(('STATUS', 'E', 'status "%s" not in %s' % (st, '|'.join(ACTIVE[kind]))))
    elif st and e.box is not None and (e.box == 'x') != st.endswith('pending-migration'):
        out.append(('BOX', 'E', 'checkbox must be ticked exactly when the status is *-pending-migration (fixable)'))
    for n, vals in ENUMS.items():
        v = e.value(n)
        if v is not None and n in allowed and v not in vals:
            out.append(('ENUM', 'E', '%s "%s" not in %s' % (n, v, '|'.join(vals))))
    j = e.value('Jira')
    if j is not None and j != 'pending' and not KEY_RE.match(j):
        out.append(('JIRA', 'E', 'Jira must be a key or `pending`, got "%s"' % j[:40]))
    area = e.value('Area') or ''
    if re.search(r'\s/\s|[()—]', area):
        out.append(('AREA', 'W', 'Area is comma-separated tags; move notes to Log ("%s")' % area[:40]))
    if epics_required() and not e.value('Jira parent'):
        out.append(('NOEPIC', 'W', 'no `Jira parent` (epic); pick one from `jira epics`'))
    if j == 'pending' and jira_mode() == 'enforce':
        out.append(('PENDING', 'W', 'no Jira issue yet: run `jira sync`'))
    for n in ('Jira parent', 'Bundle'):
        v = e.value(n)
        if v is not None and not KEY_RE.match(v):
            out.append(('JIRA', 'E', '%s must be a key, got "%s"' % (n, v[:40])))
    for name, lines in e.fields:
        if (lines[0] if lines else '').strip().lower() == 'unknown':
            out.append(('UNKNOWN' if name not in NO_UNKNOWN else 'ENUM', 'W' if name not in NO_UNKNOWN else 'E',
                        '%s is `unknown` (pre-schema entry)' % name))
        fence_indent = None
        for l in lines[1:]:
            fm = FENCE_RE.match(l)
            if fence_indent is not None:
                if fm and len(fm.group(1)) <= fence_indent:
                    fence_indent = None
                continue
            if fm:
                if not fm.group(1):
                    out.append(('INDENT', 'E', '%s: fenced block must be indented two spaces (fixable)' % name))
                fence_indent = len(fm.group(1))
                continue
            if l.strip() and not l.startswith((' ', '\t')):
                out.append(('INDENT', 'E', '%s: continuation line not indented (fixable)' % name))
                break
    if not e.title.strip():
        out.append(('HEAD', 'E', 'empty title'))
    return [(c, s, m) for c, s, m in dict.fromkeys(out)]


def fix_entry(e, kind):
    """Safe mechanical repairs: order, checkbox, indentation, blank runs."""
    allowed = fields_of(kind)
    known = [f for f in e.fields if f[0] in allowed]
    other = [f for f in e.fields if f[0] not in allowed]
    known.sort(key=lambda f: allowed.index(f[0]))
    e.fields = known + other
    st = e.status()
    e.box = 'x' if st.endswith('pending-migration') else ' '
    e.boxes = 1
    for f in e.fields:
        f[1] = [f[1][0]] + indent_cont(f[1][1:])
    return e


def indent_cont(lines):
    out, fence_pad = [], None
    for l in lines:
        fm = FENCE_RE.match(l)
        if fence_pad is not None:
            out.append(fence_pad + l if l.strip() else l)
            if fm and not fm.group(1):
                fence_pad = None
            continue
        if fm and not fm.group(1):
            fence_pad = '  '
            out.append('  ' + l)
            continue
        if fm:
            out.append(l)
            continue
        out.append('  ' + l if l.strip() and not l.startswith((' ', '\t')) else l.rstrip())
    while out and not out[-1].strip():
        out.pop()
    # collapse 2+ blank lines
    res = []
    for l in out:
        if not l.strip() and res and not res[-1].strip():
            continue
        res.append(l)
    return res


# ---------------------------------------------------------------- adopt (legacy -> format 2)

def adopt_entry(e, kind, notes):
    """Normalize a legacy entry in place. Appends human follow-ups to notes."""
    allowed = fields_of(kind)
    log = []
    kept = {}
    old_log = None
    if any(l.strip() for l in e.stray):
        txt = ' '.join(l.strip().lstrip('> ').strip() for l in e.stray if l.strip())
        log.append(['Note: ' + txt, []])
    e.stray = []
    for name, lines in e.fields:
        canon = name if name in allowed else ALIASES.get(name)
        base = re.sub(r'\s*\(.*\)\s*$', '', name).strip()
        if not canon and base in allowed and base not in kept and base != 'Log':
            canon, q = base, name[len(base):].strip()
            lines = [('%s %s' % (q, lines[0])).strip()] + lines[1:]
        if name == 'Dependencies' and kind == 'feature':
            canon = 'Library / dependency notes'
        if canon == 'Log' and canon not in kept:
            old_log = lines
            kept['Log'] = True
            continue
        if canon and canon not in kept:
            kept[canon] = lines
        elif canon == 'Depends on' and canon in kept:
            kept[canon] = [kept[canon][0].rstrip('. ') + ', ' + lines[0]] + kept[canon][1:] + lines[1:]
        else:
            log.append([name + ': ' + (lines[0] or ''), lines[1:]])
    kept.pop('Log', None)

    def enum_field(fname, allowed_vals, remap=None):
        lines = kept.get(fname)
        if lines is None:
            return
        raw = lines[0].strip()
        m = re.match(r'^[`*\s]*([A-Za-z][A-Za-z-]*)', raw)
        tok = (m.group(1).lower() if m else '')
        if remap:
            tok = remap.get(tok, tok)
        rest = raw[m.end():].strip(' `*—–-:;,.()') if m else raw
        if tok in allowed_vals:
            kept[fname] = [tok]
            if rest or any(l.strip() for l in lines[1:]):
                log.append(['%s note: %s' % (fname, rest), lines[1:]])
        elif fname == 'Bump':
            kept[fname] = ['patch' if kind == 'bug' else 'minor']
            log.append(['Bump note: %s (defaulted at adoption)' % raw, lines[1:]])
        else:
            notes.append('%s: %s "%s" needs a hand decision' % (e.id, fname, raw[:60]))

    enum_field('Severity' if kind == 'bug' else 'Priority', LEVELS,
               {'critical': 'crit', 'medium': 'med', 'blocker': 'crit', 'major': 'high', 'minor': 'low'})
    enum_field('Bump', BUMPS)
    enum_field('Status', ACTIVE[kind], {'shipped-pending-migration': ACTIVE[kind][2],
                                        'fixed-pending-migration': ACTIVE[kind][2], 'inprogress': 'in-progress',
                                        'in_progress': 'in-progress', 'blocked': 'in-progress'})
    # Area: comma-separated tags; "a / b" splits, a parenthetical or dash note goes to Log
    al = kept.get('Area')
    if al is not None:
        raw = ' '.join([al[0]] + [l.strip() for l in al[1:]]).strip()
        m = re.search(r'\s*[(—].*$', raw)
        tags = [t.strip(' `*') for t in re.split(r',|\s/\s', raw[:m.start()] if m else raw) if t.strip(' `*')]
        kept['Area'] = [', '.join(dict.fromkeys(tags)) or 'unknown']
        if m:
            log.append(['Area note: ' + m.group(0).strip(' ()—'), []])
    # Jira
    jl = kept.get('Jira')
    if jl is not None:
        raw = ' '.join([jl[0]] + [l.strip() for l in jl[1:]]).strip()
        m = re.match(r'^[`*\s]*([A-Z][A-Z0-9]+-\d+)\b\.?', raw)
        if m:
            key, rest = m.group(1), raw[m.end():].strip(' .—–-:;,')
            kept['Jira'] = [key]
            m2 = re.search(r'\bepic\s+(%s-\d+)' % re.escape(key.split('-')[0]), rest, re.I)
            if m2 and 'Jira parent' not in kept:  # bundles are links, not parents: only an epic counts
                kept['Jira parent'] = [m2.group(1)]
            if rest:
                log.append(['Jira note: ' + rest.strip('()'), []])
        else:
            kept['Jira'] = ['pending']
            info = raw.strip('() ')
            if info and not re.fullmatch(r'(unfiled|tbd|pending|new ticket to be raised|none|n/a)\.?', info, re.I):
                log.append(['Jira note: ' + info, []])
    jp = kept.get('Jira parent')
    if jp is not None:
        m = ANYKEY_RE.search(' '.join(jp))
        if m and re.match(r'(BUG|FEAT)-', m.group(0)):
            m = None  # a tracker id, not a Jira key
        if m:
            rest = ' '.join(jp).replace(m.group(0), '').strip(' .—–-:;,()')
            kept['Jira parent'] = [m.group(0)]
            if rest:
                log.append(['Jira parent note: ' + rest, []])
        else:
            log.append(['Parent: ' + ' '.join(jp), []])
            kept.pop('Jira parent')
    # defaults for missing required fields
    for n in required_of(kind):
        if n in kept:
            continue
        if n == 'Status':
            kept[n] = ['open']
            log.append(['Status note: no Status line; set `open` at adoption (entry sat under ## Open)', []])
        elif n == 'Bump':
            kept[n] = ['patch' if kind == 'bug' else 'minor']
        elif n == 'Jira':
            kept[n] = ['pending']
        elif n in NO_UNKNOWN:
            kept[n] = ['unknown']
            notes.append('%s: missing %s needs a hand decision' % (e.id, n))
        else:
            kept[n] = ['unknown']
    # rebuild
    log_lines = list(old_log[1:]) if old_log else []
    items, cur = [], None
    for l in log_lines:
        if l.startswith('  - '):
            cur = [l]
            items.append(cur)
        elif cur is not None:
            cur.append(l)
        else:
            items.append([l])
    keep_items = []
    for it in items:
        m = re.match(r'^  - ([^:(]+?) ?(\([^)]*\))?\s*:\s?(.*)$', it[0])
        name = m.group(1).strip() if m else ''
        if m and name in allowed and name != 'Log' and \
                (name not in kept or (kept[name][0] or '').strip().lower() in ('unknown', '')):
            q = (m.group(2) or '').strip()
            kept[name] = [('%s %s' % (q, m.group(3))).strip()] + [l[2:] if l.startswith('    ') else l for l in it[1:]]
            continue
        keep_items.append(it)
    log_lines = [l for it in keep_items for l in it]
    e.fields = [[n, kept[n]] for n in allowed if n in kept]
    if old_log and old_log[0].strip():
        log_lines.insert(0, '  - ' + old_log[0].strip())
    for head, cont in log:
        log_lines.append('  - ' + head.strip())
        log_lines += ['  ' + l if l.strip() else '' for l in indent_cont(cont)]
    if log_lines:
        e.fields.append(['Log', [''] + log_lines])
    e.fields = [f for f in e.fields]
    if getattr(e, 'badhead', False):
        notes.append('%s: malformed heading needs a hand fix' % e.id)
    fix_entry(e, kind)
    return e


# ---------------------------------------------------------------- repo + files

def git(*args, cwd=None, binary=False):
    r = subprocess.run(['git'] + list(args), capture_output=True, cwd=cwd)
    if r.returncode != 0:
        return None
    return r.stdout if binary else r.stdout.decode('utf-8', errors='replace').strip()


_ROOT = []


def repo_root():
    if not _ROOT:
        _ROOT.append(git('rev-parse', '--show-toplevel') or os.getcwd())
    return _ROOT[0]


def load_config(root):
    p = os.path.join(root, '.cycle', 'tracker.json')
    if os.path.exists(p):
        with open(p, encoding='utf-8') as f:
            return json.load(f)
    return {}


_MODE = {}


def jira_mode(root=None):
    """'enforce' | 'optional' | 'off', from .cycle/tracker.json (set at protocol bootstrap)."""
    root = root or repo_root()
    if root not in _MODE:
        j = load_config(root).get('jira')
        _MODE[root] = 'off' if not j else ('enforce' if j.get('enforce', True) else 'optional')
    return _MODE[root]


def epics_required(root=None):
    root = root or repo_root()
    key = ('epics', root)
    if key not in _MODE:
        j = load_config(root).get('jira') or {}
        _MODE[key] = jira_mode(root) != 'off' and bool((j.get('epics') or {}).get('required'))
    return _MODE[key]


def strict(root):
    return load_config(root).get('format') == 2


def tracker_files(root):
    ls = git('ls-files', cwd=root)
    names = ls.splitlines() if ls is not None else []
    out = [os.path.join(root, f) for f in names if os.path.basename(f) in TRACKER_FILES and 'node_modules/' not in f]
    return sorted(out)


def app_of(root, path, cfg):
    rel = os.path.relpath(os.path.dirname(os.path.abspath(path)), root).replace('\\', '/')
    apps = cfg.get('apps', {})
    if rel in apps:
        return apps[rel]
    return os.path.basename(os.path.abspath(root)) if rel == '.' else os.path.basename(rel)


def read(path):
    with open(path, 'rb') as f:
        raw = f.read().decode('utf-8', errors='replace')
    return raw.replace('\r\n', '\n')


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


class TrackerFile:
    """A format-2 tracker: preamble, `## Open`, entries."""

    def __init__(self, path):
        self.path, self.kind = path, kind_of(path)
        text = read(path)
        m = re.search(r'(?m)^## Open\s*$', text)
        if m:
            self.pre, body = text[:m.start()], text[m.end():]
        else:
            self.pre, body = text.rstrip('\n') + '\n\n', ''
        self.tail = ''
        parts = re.split(r'(?m)^(?=### \[)', body)
        self.intro = parts[0]
        self.entries = [parse_entry(p) for p in parts[1:]]

    def get(self, eid):
        hits = [e for e in self.entries if e.id == eid]
        return hits[0] if hits else None

    def remove(self, eid):
        self.entries = [e for e in self.entries if e.id != eid]

    def render(self):
        intro = self.intro.strip('\n')
        out = self.pre.rstrip('\n') + '\n\n## Open\n\n'
        if intro and not re.fullmatch(r'[-\s]*', intro):
            out += intro + '\n\n'
        out += '\n'.join(e.render() for e in self.entries)
        return out

    def save(self):
        write(self.path, self.render())


def all_ids(root):
    ids = {}
    for p in tracker_files(root):
        for m in re.finditer(r'(?m)^### \[((?:BUG|FEAT)-\d+[a-z]*)\]', read(p)):
            ids.setdefault(m.group(1), []).append(p)
    return ids


def locate(root, eid, tracker=None, app=None):
    cfg = load_config(root)
    if tracker:
        paths = [os.path.abspath(tracker)]
    else:
        paths = [p for p in tracker_files(root) if ('### [%s]' % eid) in read(p)]
        if app:
            paths = [p for p in paths if app_of(root, p, cfg) == app]
    if not paths:
        sys.exit('%s: not found in any tracker' % eid)
    if len(paths) > 1:
        sys.exit('%s is filed in %d trackers (%s); pass --tracker or --app' % (
            eid, len(paths), ', '.join(app_of(root, p, cfg) for p in paths)))
    tf = TrackerFile(paths[0])
    e = tf.get(eid)
    if not e:
        sys.exit('%s: not found in %s' % (eid, paths[0]))
    return tf, e


def opts(argv, flags=(), multi=()):
    """Tiny parser: --name value / --flag; returns (dict, positionals)."""
    o, pos, i = {}, [], 0
    while i < len(argv):
        a = argv[i]
        if a.startswith('--'):
            k = a[2:]
            if '=' in k:
                k, v = k.split('=', 1)
            elif k in flags:
                v = True
            else:
                i += 1
                if i >= len(argv):
                    sys.exit('--%s needs a value' % k)
                v = argv[i]
            if k in multi:
                o.setdefault(k, []).append(v)
            else:
                o[k] = v
        elif a == '-o':
            i += 1
            o['out'] = argv[i]
        else:
            pos.append(a)
        i += 1
    return o, pos


def check_or_die(e, kind):
    errs = [x for x in lint_entry(e, kind) if x[1] == 'E']
    if errs:
        sys.exit('%s rejected:\n%s' % (e.id, '\n'.join('  %s %s' % (c, m) for c, _, m in errs)))


# ---------------------------------------------------------------- commands: writers

def cmd_add(argv):
    """add --tracker PATH (--json FILE|- | --field 'Name=value'...) [--id ID] [--no-jira]"""
    o, _ = opts(argv, flags=('no-jira', 'dry-run'), multi=('field',))
    root = repo_root()
    if 'tracker' not in o:
        sys.exit('add: --tracker PATH is required')
    path = os.path.abspath(o['tracker'])
    kind = kind_of(path)
    if not kind:
        sys.exit('add: --tracker must be a bugs.md or features.md')
    data = {}
    if 'json' in o:
        src = sys.stdin.read() if o['json'] == '-' else read(o['json'])
        data = json.loads(src)
    for f in o.get('field', []):
        k, _, v = f.partition('=')
        data[k.strip()] = v
    title = (data.pop('title', None) or data.pop('Title', '') or '').strip()
    if not title:
        sys.exit('add: a title is required')
    pref = 'BUG' if kind == 'bug' else 'FEAT'
    taken = all_ids(root)
    if o.get('id'):
        eid = o['id']
        if not eid.startswith(pref + '-'):
            sys.exit('add: %s does not belong in the %s tracker' % (eid, kind))
        if path in [os.path.abspath(p) for p in taken.get(eid, [])]:
            sys.exit('add: %s already exists in this tracker' % eid)
    else:
        n = int(time.time())
        while '%s-%d' % (pref, n) in taken:
            n += 1
        eid = '%s-%d' % (pref, n)
    e = Entry(eid, title)
    for k, v in data.items():
        k = ALIASES.get(k, k)
        if k in ('Status', 'Jira'):
            continue
        e.set(kind, k, str(v))
    mode = jira_mode(root)
    if mode == 'enforce':
        e.set(kind, 'Jira', 'pending')
    e.set(kind, 'Status', 'open')
    if not e.value('Bump'):
        e.set(kind, 'Bump', 'patch' if kind == 'bug' else 'minor')
    e.box = ' '
    e.boxes = 1
    fix_entry(e, kind)
    check_or_die(e, kind)
    if o.get('dry-run'):
        print(e.render())
        return 0
    tf = TrackerFile(path)
    tf.entries.append(e)
    tf.save()
    print('added %s to %s' % (eid, os.path.relpath(path, root)))
    if mode != 'off' and not o.get('no-jira'):
        jira_for_entries(root, [(path, eid)], dry=False, quiet_missing_creds=True)
    return 0


def cmd_set(argv):
    """set ID FIELD (VALUE | --file F | -) [--tracker P | --app A] [--no-jira]"""
    o, pos = opts(argv, flags=('no-jira',))
    if len(pos) < 2:
        sys.exit('usage: set ID FIELD VALUE|-|--file F')
    eid, field = pos[0], ALIASES.get(pos[1], pos[1])
    if 'file' in o:
        value = read(o['file'])
    elif len(pos) > 2 and pos[2] == '-':
        value = sys.stdin.read()
    elif len(pos) > 2:
        value = ' '.join(pos[2:])
    else:
        sys.exit('set: missing value')
    root = repo_root()
    tf, e = locate(root, eid, o.get('tracker'), o.get('app'))
    take = field == 'Assignee' and value.strip().lower() == 'me'
    start = field == 'Status' and value.strip().strip('`* ').lower() == 'in-progress'
    jira = None if o.get('no-jira') or not (take or field == 'Status') else jira_or_none(root)
    if field.lower() == 'title':
        e.title = value.strip()
    elif not take:
        e.set(tf.kind, field, value)
    fix_entry(e, tf.kind)
    check_or_die(e, tf.kind)
    key = e.value('Jira') or ''
    jira = jira if jira and KEY_RE.match(key) else None
    if take or start:
        claim_entry(e, tf.kind, jira and jira_claim(jira, key, force=take), whoami(jira), take)
    tf.save()
    print('%s: %s set' % (eid, field))
    if not jira:
        return 0
    if field == 'Status':
        wf = fit_workflow(jira, workflow(load_config(root)))
        target = status_target(e.status(), wf)
        if target:
            jira_move(jira, key, target, wf)
        if KEY_RE.match(e.value('Bundle') or ''):
            if start:
                jira_claim(jira, e.value('Bundle'))
            bundle_follow(root, jira, wf, e.value('Bundle'))
    return 0


def whoami(jira):
    """Who starts the work: the Jira token's user when Jira is reachable, else git user.name."""
    if jira:
        try:
            return jira.myself()[1]
        except NET_ERRORS as ex:
            print('  warning: Jira user not read (%s); using git user.name' % ex)
    return git('config', 'user.name') or None


def claim_entry(e, kind, holder, me, take):
    """Write Assignee. HOLDER (the Jira issue's assignee after the claim) wins when Jira answered;
    otherwise starting work fills an empty Assignee with ME and never overwrites a teammate's."""
    held = e.value('Assignee')
    name = holder or (me if take or not held else None)
    if take and not name:
        sys.exit('set: no Jira user or git user.name to assign')
    if held and not name and held != me:
        print('  %s: left assigned to %s (`set %s Assignee me` takes it)' % (e.id, held, e.id))
    if name and name != held:
        e.set(kind, 'Assignee', name)
        print('  %s: Assignee %s' % (e.id, name))


def cmd_log(argv):
    """log ID TEXT [--label L] [--date YYYY-MM-DD] [--tracker P | --app A]"""
    o, pos = opts(argv)
    if len(pos) < 2:
        sys.exit('usage: log ID TEXT')
    root = repo_root()
    tf, e = locate(root, pos[0], o.get('tracker'), o.get('app'))
    head = o.get('date', today()) + (' ' + o['label'] if o.get('label') else '') + ': '
    f = e.find('Log')
    lines = (f[1] if f else ['']) + ['  - ' + head + ' '.join(pos[1:])]
    e.set(tf.kind, 'Log', '')
    e.find('Log')[1] = lines
    fix_entry(e, tf.kind)
    tf.save()
    print('%s: logged' % pos[0])
    return 0


CL_SECTIONS = ('Added', 'Changed', 'Fixed', 'Removed', 'Security')


def changelog_line(e):
    req = e.value('Req') or ''
    req = '' if req.lower().startswith(('none', 'unknown')) else ' (Req: %s)' % req
    key = e.value('Jira') or ''
    key = key + ' ' if KEY_RE.match(key) else ''
    return '- [%s] %s%s%s [%s]' % (e.id, key, e.title, req, e.value('Bump'))


def changelog_insert(path, line, section, eid):
    text = read(path) if os.path.exists(path) else '# Changelog\n\n## Unreleased\n'
    lines = text.split('\n')
    u = next((i for i, l in enumerate(lines) if re.match(r'^## \[?Unreleased\]?\s*$', l, re.I)), None)
    if u is None:
        h = next((i for i, l in enumerate(lines) if l.startswith('## ')), len(lines))
        lines[h:h] = ['## Unreleased', '']
        u = h
    end = next((i for i in range(u + 1, len(lines)) if lines[i].startswith('## ')), len(lines))
    if any(l.startswith(('- [%s]' % eid, '* [%s]' % eid)) for l in lines):
        return False  # already in the ledger (a hotfix line, or a re-run)
    s = next((i for i in range(u + 1, end) if re.match(r'^### %s\s*$' % section, lines[i])), None)
    if s is None:
        ins = end
        while ins > u + 1 and not lines[ins - 1].strip():
            ins -= 1
        lines[ins:ins] = ['', '### ' + section, '']
        s = ins + 1
        end += 3
    se = next((i for i in range(s + 1, end) if lines[i].startswith(('### ', '## '))), end)
    last = s
    for i in range(s + 1, se):
        if lines[i].strip():
            last = i
    if last == s:
        lines[s + 1:s + 1] = ['', line] if (s + 1 >= len(lines) or lines[s + 1].strip()) else [line]
        if lines[s + 1] == '':
            pass
    else:
        lines[last + 1:last + 1] = [line]
    out = '\n'.join(lines)
    out = re.sub(r'(### [A-Za-z]+)\n(- \[)', r'\1\n\n\2', out)
    write(path, out if out.endswith('\n') else out + '\n')
    return True


def cmd_migrate(argv):
    """migrate [ID...] [--all] [--section S] [--tracker P | --app A] [--skip-gate] [--no-jira]"""
    o, pos = opts(argv, flags=('all', 'skip-gate', 'no-jira'))
    root = repo_root()
    targets = []
    if o.get('all'):
        paths = [os.path.abspath(o['tracker'])] if o.get('tracker') else tracker_files(root)
        for p in paths:
            for e in TrackerFile(p).entries:
                if e.status().endswith('pending-migration'):
                    targets.append((p, e.id))
    else:
        for eid in pos:
            tf, e = locate(root, eid, o.get('tracker'), o.get('app'))
            targets.append((tf.path, eid))
    done, refused, keys = [], [], []
    wf = workflow(load_config(root))
    jira = None if o.get('no-jira') else jira_or_none(root)
    if jira:
        wf = fit_workflow(jira, wf)
    gate = wf['gate'] and not o.get('skip-gate')
    check = (gate or wf['review']) and jira and not o.get('skip-gate')
    st = {}
    bundles = set()
    if check:
        want = []
        for p, eid in targets:
            ent = TrackerFile(p).get(eid)
            for k in (ent.value('Jira') or '', ent.value('Bundle') or ''):
                if KEY_RE.match(k):
                    want.append(k)
        try:
            st = jira.statuses(want)
        except NET_ERRORS as ex:
            sys.exit('migrate: cannot read Jira statuses for the QA gate (%s); retry, or --skip-gate' % ex)
    waiting = []
    for p, eid in targets:
        tf = TrackerFile(p)
        e = tf.get(eid)
        if not e.status().endswith('pending-migration'):
            refused.append('%s (status %s)' % (eid, e.status()))
            continue
        if jira_mode(root) == 'enforce' and not KEY_RE.match(e.value('Jira') or ''):
            refused.append('%s (no Jira key: run `jira sync` first)' % eid)
            continue
        key = e.value('Jira') or ''
        cl = os.path.join(os.path.dirname(p), 'CHANGELOG.md')
        shipped = os.path.exists(cl) and re.search(r'(?m)^[-*] \[%s\]' % re.escape(eid), read(cl))
        if gate and not jira and not shipped:
            refused.append('%s (QA gate: Jira credentials missing; run `jira doctor`, or --skip-gate)' % eid)
            continue
        if check and not shipped:  # a hotfix line in the ledger: already shipped, no QA gate
            gk = gate_key(e)  # a bundle member's QA position is its bundle's
            if KEY_RE.match(gk):
                if gk not in st:
                    refused.append('%s (QA gate: %s not found in Jira)' % (eid, gk))
                    continue
                v = gate_verdict(jira, wf, gk, st[gk])
                if v == 'rejected':
                    demote(root, p, eid, st[gk])
                    refused.append('%s (Jira %s moved back to "%s"; set back to in-progress)' % (eid, gk, st[gk][0]))
                    continue
                if v == 'waiting':
                    waiting.append('%s %s "%s"' % (eid, gk, st[gk][0]))
                    continue
        section = o.get('section') or ('Fixed' if tf.kind == 'bug' else 'Added')
        if section not in CL_SECTIONS:
            sys.exit('--section must be one of %s' % ', '.join(CL_SECTIONS))
        changelog_insert(os.path.join(os.path.dirname(p), 'CHANGELOG.md'), changelog_line(e), section, eid)
        tf.remove(eid)
        tf.save()
        done.append('%s -> %s/CHANGELOG.md %s' % (eid, os.path.relpath(os.path.dirname(p), root), section))
        if KEY_RE.match(key):
            keys.append(key)
        if KEY_RE.match(e.value('Bundle') or ''):
            bundles.add(e.value('Bundle'))
    for d in done:
        print('migrated ' + d)
    for r in refused:
        print('refused ' + r)
    for w in waiting:
        print('waiting on QA (gate: %s): %s' % (' / '.join(wf['gate']), w))
    if o.get('skip-gate') and wf['gate'] and done:
        print('note: migrated without the QA gate (--skip-gate)')
    if jira and keys:
        print('Jira -> %s:' % wf['done'])
        bad = sum(0 if jira_move(jira, k, wf['done'], wf) else 1 for k in keys)
        if bad:
            print('%d issue(s) not moved; `trackers.py jira done` retries' % bad)
    if jira:
        for b in sorted(bundles):
            if not bundle_follow(root, jira, wf, b):
                print('bundle %s not moved; `trackers.py bundle sync %s` retries' % (b, b))
    return 1 if refused and not done else 0


def cmd_close(argv):
    """close ID --reason R [--force] [--tracker P | --app A] [--no-jira]"""
    o, pos = opts(argv, flags=('force', 'no-jira'))
    if not pos or o.get('reason') not in CLOSE_REASONS:
        sys.exit('usage: close ID --reason %s [--force]' % '|'.join(CLOSE_REASONS))
    root = repo_root()
    tf, e = locate(root, pos[0], o.get('tracker'), o.get('app'))
    key = e.value('Jira') or ''
    if jira_mode(root) == 'enforce' and not KEY_RE.match(key) and not o.get('force'):
        sys.exit('%s has no Jira key; run `jira sync` first (or --force to drop it with no Jira record)' % e.id)
    tf.remove(e.id)
    tf.save()
    print('closed %s (%s)' % (e.id, o['reason']))
    jira = None if o.get('no-jira') else jira_or_none(root)
    if KEY_RE.match(key):
        wf = fit_workflow(jira, workflow(load_config(root))) if jira else workflow(load_config(root))
        if not jira or not jira_move(jira, key, wf['done'], wf, wf['resolutions'].get(o['reason'])):
            print('resolve %s in Jira as %s' % (key, o['reason']))
        if jira and KEY_RE.match(e.value('Bundle') or ''):
            bundle_follow(root, jira, wf, e.value('Bundle'))
    return 0


def cmd_show(argv):
    """show ID [--app A]"""
    o, pos = opts(argv)
    if not pos:
        sys.exit('usage: show ID')
    eid, root = pos[0], repo_root()
    cfg = load_config(root)
    hits = [p for p in tracker_files(root) if ('### [%s]' % eid) in read(p)]
    if o.get('app'):
        hits = [p for p in hits if app_of(root, p, cfg) == o['app']]
    for p in hits:
        print('# %s (current)\n' % os.path.relpath(p, root))
        print(TrackerFile(p).get(eid).render())
    if hits:
        return 0
    revs = git('log', '--format=%H', '-S', '### [%s]' % eid, '--', '*bugs.md', '*features.md', cwd=root) or ''
    for rev in revs.split():
        for ref in (rev, rev + '^'):
            files = git('diff-tree', '--no-commit-id', '--name-only', '-r', rev, cwd=root) or ''
            for f in files.split():
                if os.path.basename(f) not in TRACKER_FILES:
                    continue
                blob = git('show', '%s:%s' % (ref, f), cwd=root)
                if not blob or ('### [%s]' % eid) not in blob:
                    continue
                part = re.split(r'(?m)^(?=### \[)', blob)
                for chunk in part:
                    if chunk.startswith('### [%s]' % eid):
                        chunk = re.split(r'(?m)^## ', chunk)[0]
                        print('# %s at %s (removed later; see CHANGELOG.md / Jira)\n' % (f, ref[:10]))
                        print(chunk.rstrip() + '\n')
                        return 0
    sys.exit('%s: not in any tracker or its history' % eid)


# ---------------------------------------------------------------- export

def cmd_export(argv):
    """export [--status open|todo|in-progress|pending|all] [--type bug|feature] [--area A] [--app A]
              [--ids I,J] [--no-key] [-o FILE]"""
    o, _ = opts(argv, flags=('no-key',))
    root = repo_root()
    cfg = load_config(root)
    want = o.get('status', 'open')
    ids = set(x.strip() for x in o.get('ids', '').split(',') if x.strip())
    groups, n = [], {'bug': 0, 'feature': 0}
    for p in tracker_files(root):
        kind = kind_of(p)
        if o.get('type') and o['type'] != kind:
            continue
        if o.get('app') and app_of(root, p, cfg) != o['app']:
            continue
        sel = []
        for e in TrackerFile(p).entries:
            st = e.status()
            if ids and e.id not in ids:
                continue
            if not ids:
                if want == 'todo' and st != 'open':
                    continue
                if want == 'in-progress' and st != 'in-progress':
                    continue
                if want == 'pending' and not st.endswith('pending-migration'):
                    continue
                if want == 'open' and st.endswith('pending-migration'):
                    continue
            if o.get('area') and o['area'] not in [a.strip() for a in (e.value('Area') or '').split(',')]:
                continue
            if o.get('no-key') and KEY_RE.match(e.value('Jira') or ''):
                continue
            sel.append(e)
        if sel:
            groups.append((p, sel))
            n[kind] += len(sel)
    desc = ', '.join('%s=%s' % (k, v) for k, v in sorted(o.items()) if k != 'out') or 'status=open'
    out = ['# Jira export: %s' % desc, '',
           'Generated %s. Edit freely, then create the issues with:' % today(), '',
           '    python .cycle/trackers.py jira push <this file>', '',
           'Totals: %d stories (features) + %d bugs = %d issues.' % (n['feature'], n['bug'], n['feature'] + n['bug']), '']
    for p, sel in groups:
        out += ['## %s' % os.path.relpath(p, root).replace('\\', '/'), '']
        out += [e.render() for e in sel]
    text = '\n'.join(out).rstrip('\n') + '\n'
    dest = o.get('out') or 'jira-export-%s.md' % today()
    write(dest, text)
    print('wrote %s (%d stories + %d bugs)' % (dest, n['feature'], n['bug']))
    return 0


def parse_export(path):
    """Yield (tracker_rel, Entry) from an export file."""
    text = read(path)
    res, cur = [], None
    for chunk in re.split(r'(?m)^(?=## |### \[)', text):
        if chunk.startswith('## '):
            cur = chunk[3:].split('\n')[0].strip()
        elif chunk.startswith('### [') and cur:
            res.append((cur, parse_entry(re.split(r'(?m)^## ', chunk)[0])))
    return res


# ---------------------------------------------------------------- Jira

class JiraError(Exception):
    def __init__(self, code, body):
        Exception.__init__(self, 'HTTP %s: %s' % (code, body))
        self.code, self.body = code, body


class Jira:
    def __init__(self, cfg):
        j = cfg.get('jira', {})
        self.cfg = j
        # Every value comes from this repo's .cycle/tracker.json, so each project can point
        # at its own Jira (any Cloud site or a Data Center server). The JIRA_SITE /
        # JIRA_PROJECT variables only fill a value the config leaves out.
        self.site = (j.get('site') or os.environ.get('JIRA_SITE') or '').rstrip('/')
        if self.site and not self.site.startswith('http'):
            self.site = 'https://' + self.site
        self.project = j.get('project') or os.environ.get('JIRA_PROJECT', '')
        a = j.get('auth') or {}
        self.auth_type = a.get('type', 'basic')            # basic: Cloud email + API token; bearer: Data Center PAT
        # Several Jira accounts on one machine: the repo may name its variables; otherwise a
        # site-specific pair (JIRA_EMAIL_<SITE>, JIRA_API_TOKEN_<SITE>, SITE = first label of the
        # host, e.g. PARADIGMTEST_DEV1) wins over the plain JIRA_EMAIL / JIRA_API_TOKEN.
        host = urllib.parse.urlparse(self.site).hostname or ''
        self.site_tag = re.sub(r'[^A-Z0-9]+', '_', host.split('.')[0].upper()).strip('_')
        self.email_env = self._pick(a.get('emailEnv'), 'JIRA_EMAIL')
        self.token_env = self._pick(a.get('tokenEnv'), 'JIRA_API_TOKEN')
        self.email = os.environ.get(self.email_env, '')
        self.token = os.environ.get(self.token_env, '')

    def _pick(self, named, base):
        if named:
            return named
        tagged = '%s_%s' % (base, self.site_tag) if self.site_tag else None
        return tagged if tagged and os.environ.get(tagged) else base

    def missing(self):
        need = [(self.token_env, self.token), ('jira.site', self.site), ('jira.project', self.project)]
        if self.auth_type == 'basic':
            need.insert(0, (self.email_env, self.email))
        return [n for n, v in need if not v]

    def req(self, method, path, body=None):
        if self.auth_type == 'bearer':
            header = 'Bearer ' + self.token
        else:
            header = 'Basic ' + base64.b64encode(('%s:%s' % (self.email, self.token)).encode()).decode()
        data = json.dumps(body).encode() if body is not None else None
        for attempt in range(4):
            r = urllib.request.Request(self.site + path, data=data, method=method, headers={
                'Authorization': header, 'Accept': 'application/json',
                'Content-Type': 'application/json'})
            try:
                with urllib.request.urlopen(r, timeout=60) as resp:
                    raw = resp.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < 3:
                    time.sleep(float(e.headers.get('Retry-After') or 2 ** attempt))
                    continue
                raise JiraError(e.code, e.read().decode('utf-8', errors='replace')[:800])

    def search(self, jql, fields, limit):
        """JQL search: Cloud's /rest/api/3/search/jql, falling back to v2 /search (Data Center)."""
        body = {'jql': jql, 'fields': fields, 'maxResults': limit}
        try:
            return self.req('POST', '/rest/api/3/search/jql', body)
        except JiraError as e:
            if e.code not in (404, 405, 410):
                raise
            return self.req('POST', '/rest/api/2/search', body)

    def field_id(self, name):
        return (self.cfg.get('fields') or {}).get(name)

    def find_existing(self, ext_id, labels):
        fid = self.field_id('externalId')
        if fid:
            num = fid.replace('customfield_', '')
            jql = 'project = "%s" AND cf[%s] ~ "\\"%s\\""' % (self.project, num, ext_id)
            res = self.search(jql, [fid], 20)
            for iss in res.get('issues', []):
                if str((iss.get('fields') or {}).get(fid) or '').strip() == ext_id:
                    return iss['key']
            return None
        jql = 'project = "%s" AND %s' % (self.project, ' AND '.join('labels = "%s"' % l for l in labels))
        res = self.search(jql, ['summary'], 2)
        iss = res.get('issues', [])
        return iss[0]['key'] if len(iss) == 1 else None

    def meta(self, kind):
        """The project's create screen for this issue type: {field id: {name, required, schema,
        allowed}}. Project-scoped, so same-named fields elsewhere on the site never confuse it."""
        self._meta = getattr(self, '_meta', {})
        if kind in self._meta:
            return self._meta[kind]
        want = self.issue_type(kind)
        out = {}
        try:
            proj = urllib.parse.quote(self.project)
            r = self.req('GET', '/rest/api/2/issue/createmeta/%s/issuetypes?maxResults=200' % proj)
            types = r.get('issueTypes') or r.get('values') or []
            t = next((x for x in types if x.get('name', '').lower() == want.lower()), None)
            if t:
                start = 0
                while True:
                    r = self.req('GET', '/rest/api/2/issue/createmeta/%s/issuetypes/%s?maxResults=200&startAt=%d'
                                 % (proj, t['id'], start))
                    rows = r.get('fields') or r.get('values') or []
                    for f in rows:
                        out[f.get('fieldId') or f.get('key')] = f
                    start += len(rows)
                    if not rows or start >= r.get('total', start):
                        break
        except JiraError as e:
            if e.code not in (404, 405):
                raise
            r = self.req('GET', '/rest/api/2/issue/createmeta?projectKeys=%s&issuetypeNames=%s'
                         '&expand=projects.issuetypes.fields' % (urllib.parse.quote(self.project),
                                                                urllib.parse.quote(want)))
            for pr in r.get('projects', []):
                for it in pr.get('issuetypes', []):
                    for fid, f in (it.get('fields') or {}).items():
                        out[fid] = dict(f, fieldId=fid)
        self._meta[kind] = {fid: {'name': f.get('name', fid), 'required': bool(f.get('required')),
                                  'schema': f.get('schema') or {},
                                  'allowed': [v.get('value') or v.get('name') for v in f.get('allowedValues') or []
                                              if isinstance(v, dict)]}
                            for fid, f in out.items() if fid}
        return self._meta[kind]

    def issue_type(self, kind):
        return dict(ISSUE_TYPES, **(self.cfg.get('issueTypes') or {}))[kind]

    # ------------------------------------------------------------ issue links (bundles)

    def link_type(self):
        return (self.cfg.get('bundles') or {}).get('link') or 'Implements'

    def links_of(self, key):
        """[(link id, type name, side, other key)]: side 'outward' = KEY <outward> other."""
        r = self.req('GET', '/rest/api/2/issue/%s?fields=issuelinks' % urllib.parse.quote(key))
        out = []
        for l in (r.get('fields') or {}).get('issuelinks') or []:
            side = 'outward' if 'outwardIssue' in l else 'inward'
            out.append((l.get('id'), (l.get('type') or {}).get('name', ''), side,
                        (l.get('outwardIssue') or l.get('inwardIssue') or {}).get('key')))
        return out

    def _post_link(self, src, dst, swapped):
        out, inw = (dst, src) if swapped else (src, dst)
        self.req('POST', '/rest/api/2/issueLink', {'type': {'name': self.link_type()},
                                                   'outwardIssue': {'key': out}, 'inwardIssue': {'key': inw}})

    def link(self, src, dst):
        """SRC <outward> DST (the bundle implements the member). Which body side is which is easy
        to get backwards, so the first link of a run is checked on DST and redone if reversed."""
        name = self.link_type().lower()
        side = lambda: next((s for _, t, s, k in self.links_of(dst) if t.lower() == name and k == src), None)
        if side() == 'inward':
            return 'already linked'
        first = getattr(self, '_swap', None)
        self._post_link(src, dst, bool(first))
        if first is None:
            self._swap = False
            if side() == 'outward':
                self.unlink(dst, src)
                self._post_link(src, dst, True)
                self._swap = True
        return 'linked'

    def unlink(self, a, b):
        """Delete every link of the bundle type between A and B; returns how many."""
        name = self.link_type().lower()
        ids = [i for i, t, _, k in self.links_of(a) if t.lower() == name and k == b]
        for i in ids:
            self.req('DELETE', '/rest/api/2/issueLink/%s' % i)
        return len(ids)

    def epics(self):
        """Open epics of the project: [(key, summary)]."""
        jql = ('project = "%s" AND issuetype = Epic AND statusCategory != Done ORDER BY key'
               % self.project)
        res = self.search(jql, ['summary'], 200)
        return [(i['key'], (i.get('fields') or {}).get('summary', '')) for i in res.get('issues', [])]

    def epic_for(self, e, app):
        """The entry's epic: its `Jira parent:`, else the first jira.epics.rules match, else default."""
        own = e.value('Jira parent') or ''
        if KEY_RE.match(own):
            return own, 'entry'
        cfg = self.cfg.get('epics') or {}
        areas = [a.strip().lower() for a in (e.value('Area') or '').split(',')]
        req = e.value('Req') or ''
        for r in cfg.get('rules') or []:
            m = r.get('match') or {}
            if 'app' in m and m['app'] != app:
                continue
            if 'area' in m and m['area'].lower() not in areas:
                continue
            if 'req' in m and not re.search(r'\b%s' % re.escape(m['req']), req):
                continue
            if 'title' in m and not re.search(m['title'], e.title, re.I):
                continue
            if 'kind' in m and m['kind'] != ('bug' if e.id.startswith('BUG') else 'feature'):
                continue
            return r['epic'], 'rule'
        if cfg.get('default'):
            return cfg['default'], 'default'
        return None, None

    def set_parent(self, key, epic):
        fld = (self.cfg.get('epics') or {}).get('field', 'parent')
        val = {'key': epic} if fld == 'parent' else epic
        self.req('PUT', '/rest/api/2/issue/%s' % urllib.parse.quote(key), {'fields': {fld: val}})

    def parent_of(self, key):
        fld = (self.cfg.get('epics') or {}).get('field', 'parent')
        r = self.req('GET', '/rest/api/2/issue/%s?fields=%s' % (urllib.parse.quote(key), fld))
        v = (r.get('fields') or {}).get(fld)
        return (v or {}).get('key') if isinstance(v, dict) else v

    def field_map(self, kind):
        """jira.fields.map.<kind>: {field id: source}; acceptanceCriteria/testPlan keys still honoured."""
        fields = self.cfg.get('fields') or {}
        m = dict((fields.get('map') or {}).get(kind) or {})
        if kind == 'feature':
            for key, src in (('acceptanceCriteria', 'Acceptance criteria'), ('testPlan', 'Test plan')):
                if fields.get(key) and fields[key] not in m:
                    m[fields[key]] = src
        return m

    def create(self, fields):
        optional = ['parent', 'components', 'priority']
        tried = set()
        while True:
            try:
                return self.req('POST', '/rest/api/2/issue', {'fields': fields})['key']
            except JiraError as e:
                if e.code != 400:
                    raise
                try:
                    errs = (json.loads(e.body).get('errors') or {})
                except ValueError:
                    raise e
                bad = [k for k in errs if k in optional and k in fields and k not in tried]
                if not bad:
                    raise
                for k in bad:
                    tried.add(k)
                    fields.pop(k)
                    sys.stderr.write('jira: retrying without %s (%s)\n' % (k, errs[k]))

    # ------------------------------------------------------------ workflow (status moves)

    def project_statuses(self):
        """{status name lower: (name, category key)} across the project's issue types (cached)."""
        if getattr(self, '_st', None) is None:
            self._st = {}
            for it in self.req('GET', '/rest/api/2/project/%s/statuses' % urllib.parse.quote(self.project)) or []:
                for s in it.get('statuses', []):
                    self._st[s['name'].lower()] = (s['name'], (s.get('statusCategory') or {}).get('key', 'indeterminate'))
        return self._st

    def status(self, key):
        s = self.req('GET', '/rest/api/2/issue/%s?fields=status' % key)['fields']['status']
        return s['name'], s['statusCategory']['key']

    def myself(self):
        """(assign body, display name) for the token's user: accountId on Cloud, name on Data Center."""
        if getattr(self, '_me', None) is None:
            u = self.req('GET', '/rest/api/2/myself')
            ref = {'accountId': u['accountId']} if u.get('accountId') else {'name': u['name']}
            self._me = (ref, u.get('displayName') or u.get('name') or u.get('accountId'))
        return self._me

    def assignee(self, key):
        return (self.req('GET', '/rest/api/2/issue/%s?fields=assignee' % key).get('fields') or {}).get('assignee')

    def assign(self, key, ref):
        self.req('PUT', '/rest/api/2/issue/%s/assignee' % key, ref)

    def statuses(self, keys):
        """{key: (status, category)}; one search per 50 keys, one GET per key if a search is refused."""
        out = {}
        keys = sorted(set(keys))
        for i in range(0, len(keys), 50):
            chunk = keys[i:i + 50]
            try:
                res = self.search('key in (%s)' % ','.join(chunk), ['status'], len(chunk))
                for iss in res.get('issues', []):
                    s = iss['fields']['status']
                    out[iss['key']] = (s['name'], s['statusCategory']['key'])
            except JiraError:
                for k in chunk:
                    try:
                        out[k] = self.status(k)
                    except JiraError:
                        pass  # deleted or moved issue: reported as not found
        return out

    def rank(self, name, cat, wf):
        """Position on the board: category first (new < indeterminate < done), then workflow.order."""
        order = [s.lower() for s in wf.get('order') or []]
        r = CAT_RANK.get(cat, 1) * 1000
        return r + (order.index(name.lower()) + 1 if name.lower() in order else 500)

    def target_rank(self, target, wf):
        if target in CAT_RANK:
            return CAT_RANK[target] * 1000 + (0 if target != 'done' else 1)
        name, cat = self.project_statuses().get(target.lower(), (target, 'indeterminate'))
        return self.rank(name, cat, wf)

    def move(self, key, target, wf, resolution=None):
        """Move KEY forward to TARGET (a status name, or a category: 'indeterminate', 'done').
        Never moves an issue backwards. Returns (result, status): moved | already | ahead."""
        hit = (lambda n, c: c == target) if target in CAT_RANK else (lambda n, c: n.lower() == target.lower())
        goal = self.target_rank(target, wf)
        name, cat = self.status(key)
        start = name
        for hop in range(9):
            if hit(name, cat):
                return ('already' if hop == 0 else 'moved'), name
            cur = self.rank(name, cat, wf)
            if cur >= goal and target not in CAT_RANK:
                return 'ahead', name
            if cat == 'done':
                return 'ahead', name
            ts = self.req('GET', '/rest/api/2/issue/%s/transitions?expand=transitions.fields' % key).get('transitions', [])
            def dest(t):
                to = t.get('to') or {}
                return to.get('name', ''), (to.get('statusCategory') or {}).get('key', 'indeterminate')
            direct = [t for t in ts if hit(*dest(t))]
            if direct and target == 'done':  # prefer a status literally named Done / Complete / Resolved / Closed
                direct.sort(key=lambda t: next((i for i, w in enumerate(DONE_NAMES) if w == dest(t)[0].lower()), 9))
            fwd = [t for t in ts if cur < self.rank(*dest(t), wf) < goal and dest(t)[1] != 'done']
            pick = direct[0] if direct else (max(fwd, key=lambda t: self.rank(*dest(t), wf)) if fwd else None)
            if not pick:
                raise JiraError('no-path', 'no transition from "%s" toward "%s" (available: %s)' % (
                    name, target, ', '.join(dest(t)[0] for t in ts) or 'none'))
            body = {'transition': {'id': pick['id']}}
            rf = (pick.get('fields') or {}).get('resolution')
            if rf and (resolution or rf.get('required')):
                allowed = [v.get('name', '') for v in rf.get('allowedValues') or []]
                want = next((a for a in allowed if a.lower() == (resolution or '').lower()), None) or \
                    next((a for a in allowed if a.lower() == 'done'), None) or (allowed[0] if allowed else None)
                if want:
                    body['fields'] = {'resolution': {'name': want}}
            self.req('POST', '/rest/api/2/issue/%s/transitions' % key, body)
            name, cat = dest(pick)
        raise JiraError('no-path', 'gave up after 8 moves from "%s" toward "%s"' % (start, target))

    def add_fix_version(self, keys, version):
        proj = self.req('GET', '/rest/api/2/project/%s' % urllib.parse.quote(self.project))
        names = [v.get('name') for v in self.req('GET', '/rest/api/2/project/%s/versions' % urllib.parse.quote(self.project)) or []]
        if version not in names:
            self.req('POST', '/rest/api/2/version', {'name': version, 'projectId': int(proj['id'])})
        done = []
        for k in keys:
            self.req('PUT', '/rest/api/2/issue/%s' % k, {'update': {'fixVersions': [{'add': {'name': version}}]}})
            done.append(k)
        return done


# ---------------------------------------------------------------- Jira workflow: tracker -> board

CAT_RANK = {'new': 0, 'indeterminate': 1, 'done': 2}
NET_ERRORS = (JiraError, OSError, http.client.HTTPException, ValueError, KeyError)  # OSError covers URLError
DONE_NAMES = ('done', 'complete', 'completed', 'resolved', 'closed')
RESOLUTIONS = {'duplicate': 'Duplicate', 'wontfix': "Won't Do", 'superseded': "Won't Do",
               'cannot-reproduce': 'Cannot Reproduce', 'not-a-defect': "Won't Do"}
CL_KEY = re.compile(r'^[-*] \[(?:BUG|FEAT)-\d+[a-z]*\] ([A-Z][A-Z0-9]+-\d+) ')


def workflow(cfg):
    """jira.workflow: inProgress / review / gate / done / order / resolutions (TRACKERS.md, "Jira workflow")."""
    w = dict((cfg.get('jira') or {}).get('workflow') or {})
    w['inProgress'] = w.get('inProgress') or 'indeterminate'
    w['review'] = w.get('review') or None
    g = w.get('gate') or []
    w['gate'] = [g] if isinstance(g, str) else list(g)
    w['done'] = w.get('done') or 'done'
    w['order'] = w.get('order') or []
    w['resolutions'] = dict(RESOLUTIONS, **(w.get('resolutions') or {}))
    return w


def fit_workflow(jira, wf):
    """Drop configured statuses this project does not have, so one mapping works on any board:
    no review status = no review move, no gate status = no gate, no inProgress/done = the category."""
    try:
        have = jira.project_statuses()
    except NET_ERRORS:
        return wf
    w, gone = dict(wf), []
    for k, fallback in (('inProgress', 'indeterminate'), ('done', 'done'), ('review', None)):
        if w[k] and w[k] not in CAT_RANK and w[k].lower() not in have:
            gone.append(w[k])
            w[k] = fallback
    w['gate'] = [g for g in wf['gate'] if g.lower() in have or gone.append(g)]
    w['order'] = [x for x in wf['order'] if x.lower() in have]
    if gone and not getattr(jira, '_warned', False):
        jira._warned = True
        print('note: %s has no status %s; skipped (TRACKERS.md, "Jira workflow")' % (
            jira.project, ', '.join('"%s"' % g for g in gone)))
    return w


def jira_or_none(root):
    if jira_mode(root) == 'off':
        return None
    j = Jira(load_config(root))
    return None if j.missing() else j


def status_target(status, wf):
    if status == 'in-progress':
        return wf['inProgress']
    if status.endswith('pending-migration'):
        return wf['review']
    return None


def jira_move(jira, key, target, wf, resolution=None):
    """Move one issue; print the outcome; never raise. Returns True when the board matches."""
    try:
        res, st = jira.move(key, target, wf, resolution)
        print('  %s: %s' % (key, {'moved': 'moved to %s' % st, 'already': 'already %s' % st,
                                  'ahead': 'left at %s (already past %s)' % (st, target)}[res]))
        return True
    except NET_ERRORS as ex:
        print('  warning: %s not moved to %s: %s' % (key, target, ex))
        return False


def jira_claim(jira, key, force=False):
    """Assign KEY to the token's user; an issue someone else holds is left unless FORCE.
    Prints the outcome; never raises. Returns the holder's display name afterwards, None on error."""
    try:
        ref, me = jira.myself()
        cur = jira.assignee(key)
        if cur and all(cur.get(k) == v for k, v in ref.items()):
            print('  %s: already assigned to %s' % (key, me))
            return me
        if cur and not force:
            other = cur.get('displayName') or cur.get('name') or '?'
            print('  %s: left assigned to %s (`set <ID> Assignee me` takes it)' % (key, other))
            return other
        jira.assign(key, ref)
        print('  %s: assigned to %s' % (key, me))
        return me
    except NET_ERRORS as ex:
        print('  warning: %s not assigned: %s' % (key, ex))
        return None


def gate_verdict(jira, wf, key, st):
    """For a pending entry: ready | waiting | rejected (Jira moved back before review)."""
    name, cat = st
    if cat == 'done' or name.lower() in [g.lower() for g in wf['gate']]:
        return 'ready'
    if not wf['gate'] and not wf['review']:
        return 'ready'
    back = wf['review'] or wf['inProgress']
    if back in CAT_RANK:
        rejected = CAT_RANK[cat] < CAT_RANK[back] or (back == 'indeterminate' and cat == 'new')
    else:
        rejected = jira.rank(name, cat, wf) < jira.target_rank(back, wf)
    return 'rejected' if rejected else ('waiting' if wf['gate'] else 'ready')


def gate_key(e):
    """The issue whose board position gates an entry: its bundle's, else its own."""
    b = e.value('Bundle') or ''
    return b if KEY_RE.match(b) else (e.value('Jira') or '')


def demote(root, path, eid, st):
    tf = TrackerFile(path)
    e = tf.get(eid)
    e.set(tf.kind, 'Status', 'in-progress')
    e.box = ' '
    f = e.find('Log')
    lines = (f[1] if f else ['']) + ['  - %s Jira: moved back to "%s"; set back to in-progress' % (today(), st[0])]
    e.set(tf.kind, 'Log', '')
    e.find('Log')[1] = lines
    fix_entry(e, tf.kind)
    tf.save()


def pending_entries(root, app=None):
    cfg = load_config(root)
    out = []
    for p in tracker_files(root):
        if app and app_of(root, p, cfg) != app:
            continue
        for e in TrackerFile(p).entries:
            if e.status().endswith('pending-migration'):
                out.append((p, e))
    return out


def jira_status(root, o):
    """jira status [--apply] [--app A]: pending entries vs the board; --apply demotes rejected ones."""
    jira = jira_or_none(root)
    if not jira:
        sys.exit('jira status: Jira is off or credentials are missing (jira doctor)')
    wf = fit_workflow(jira, workflow(load_config(root)))
    pend = pending_entries(root, o.get('app'))
    keys = [gate_key(e) for _, e in pend if KEY_RE.match(gate_key(e))]
    try:
        st = jira.statuses(keys)
    except NET_ERRORS as ex:
        sys.exit('jira status: %s' % ex)
    counts = {}
    for p, e in pend:
        k = gate_key(e)
        if k not in st:
            v, shown = 'no-issue', k or 'pending'
        else:
            v, shown = gate_verdict(jira, wf, k, st[k]), '%s "%s"%s' % (
                k, st[k][0], ' (bundle of %s)' % e.value('Jira') if k != e.value('Jira') else '')
        counts[v] = counts.get(v, 0) + 1
        print('%-9s %-18s %s' % (v, e.id, shown))
        if v == 'rejected' and o.get('apply'):
            demote(root, p, e.id, st[k])
            print('          -> set back to in-progress')
    print('jira status: %s%s' % (', '.join('%d %s' % (n, v) for v, n in sorted(counts.items())) or 'nothing pending',
                                 '' if o.get('apply') or not counts.get('rejected') else '; --apply sets rejected entries back to in-progress'))
    return 0


def changelog_keys(root, section=None):
    """Jira keys on ledger lines; SECTION limits to one '## <version>' block (e.g. v1.4.0 or Unreleased)."""
    paths = {os.path.join(os.path.dirname(p), 'CHANGELOG.md') for p in tracker_files(root)}
    paths.add(os.path.join(root, 'CHANGELOG.md'))
    keys = []
    for p in sorted(paths):
        if not os.path.exists(p):
            continue
        cur = None
        for line in read(p).split('\n'):
            if line.startswith('## '):
                cur = line[3:].strip().strip('[]').split(']')[0].split(' ')[0]
                continue
            m = CL_KEY.match(line)
            if m and (section is None or (cur or '').lstrip('v') == section.lstrip('v')):
                keys.append(m.group(1))
    return sorted(set(keys))


def jira_done(root, o):
    """jira done [--dry-run]: every issue on a CHANGELOG ledger line that is not Done is moved to Done."""
    jira = jira_or_none(root)
    if not jira:
        sys.exit('jira done: Jira is off or credentials are missing (jira doctor)')
    wf = fit_workflow(jira, workflow(load_config(root)))
    proj = jira.project + '-'
    keys = [k for k in changelog_keys(root) if k.startswith(proj)]
    try:
        st = jira.statuses(keys)
    except NET_ERRORS as ex:
        sys.exit('jira done: %s' % ex)
    todo = [k for k in keys if k in st and st[k][1] != 'done']
    print('jira done: %d ledger keys, %d already done, %d to move%s' % (
        len(keys), len(keys) - len(todo) - (len(keys) - len(st)), len(todo),
        ', %d not found' % (len(keys) - len(st)) if len(keys) != len(st) else ''))
    if o.get('dry-run'):
        for k in todo:
            print('  %s: %s -> %s' % (k, st[k][0], wf['done']))
        return 0
    bad = sum(0 if jira_move(jira, k, wf['done'], wf) else 1 for k in todo)
    return 1 if bad else 0


def jira_release(root, o, pos):
    """jira release VERSION: set fixVersion VERSION on the issues of that CHANGELOG section."""
    if not pos:
        sys.exit('usage: jira release VERSION   (the CHANGELOG section, e.g. v1.4.0)')
    jira = jira_or_none(root)
    if not jira:
        sys.exit('jira release: Jira is off or credentials are missing (jira doctor)')
    keys = [k for k in changelog_keys(root, pos[0]) if k.startswith(jira.project + '-')]
    if not keys:
        print('jira release: no Jira keys in CHANGELOG section %s' % pos[0])
        return 0
    if o.get('dry-run'):
        print('jira release: would set fixVersion %s on %s' % (pos[0], ', '.join(keys)))
        return 0
    try:
        done = jira.add_fix_version(keys, pos[0])
    except NET_ERRORS as ex:
        sys.exit('jira release: %s' % ex)
    print('jira release: fixVersion %s set on %d issues' % (pos[0], len(done)))
    return 0


def doctor_workflow(jira, j, write_it):
    """Check jira.workflow against the project's statuses; propose one when missing. Returns (ok, changed, wf)."""
    st = jira.project_statuses()
    names = {v[0] for v in st.values()}
    print('statuses    %s' % ', '.join('%s (%s)' % v for v in sorted(st.values(), key=lambda v: (CAT_RANK.get(v[1], 1), v[0]))))
    try:
        perm = jira.req('GET', '/rest/api/2/mypermissions?projectKey=%s&permissions=TRANSITION_ISSUES,RESOLVE_ISSUES,EDIT_ISSUES'
                        % urllib.parse.quote(jira.project)).get('permissions', {})
        for p in ('TRANSITION_ISSUES', 'RESOLVE_ISSUES', 'EDIT_ISSUES'):
            print('permission  %-18s %s' % (p, 'yes' if (perm.get(p) or {}).get('havePermission') else 'NO'))
        ok = (perm.get('TRANSITION_ISSUES') or {}).get('havePermission', True)
    except JiraError:
        ok = True
    w = dict(j.get('workflow') or {})
    changed = False
    if not w:
        pick = lambda rx, cat=None: next((v[0] for v in sorted(st.values()) if re.search(rx, v[0], re.I)
                                          and (cat is None or v[1] == cat)), None)
        w = {k: v for k, v in {
            'inProgress': pick(r'progress', 'indeterminate'),
            'review': pick(r'review', 'indeterminate'),
            'gate': [g for g in [pick(r'awaiting migration|ready for (migration|release|prod)', 'indeterminate')] if g],
            'done': pick(r'^(done|complete|completed|resolved|closed)$', 'done'),
        }.items() if v}
        qa = [v[0] for v in st.values() if v[1] == 'indeterminate' and re.search(r'\bqa\b|test|staging|verif', v[0], re.I)
              and v[0] not in w.get('gate', [])]
        w['order'] = [x for x in [pick(r'to ?do|backlog|open', 'new'), w.get('inProgress'), w.get('review')] + qa
                      + w.get('gate', []) + [w.get('done')] if x]
        changed = True
        print('workflow    proposed: %s' % json.dumps(w))
    else:
        for k in ('inProgress', 'review', 'done'):
            if w.get(k) and w[k] not in CAT_RANK and w[k] not in names:
                print('workflow    %s "%s" is not a status in %s' % (k, w[k], jira.project))
                ok = False
        gates = [w['gate']] if isinstance(w.get('gate'), str) else list(w.get('gate') or [])
        for g in dict.fromkeys(gates + list(w.get('order') or [])):
            if g not in names:
                print('workflow    "%s" is not a status in %s' % (g, jira.project))
                ok = False
        print('workflow    %s' % json.dumps(w))
    return ok, changed, w


def wiki(text):
    """Markdown-ish tracker text to Jira wiki markup (code fences only)."""
    out, fence = [], False
    for l in (text or '').split('\n'):
        m = FENCE_RE.match(l)
        if m:
            lang = l.strip()[3:].strip()
            out.append('{code}' if fence else ('{code:%s}' % lang if lang else '{code}'))
            fence = not fence
            continue
        out.append(l)
    if fence:
        out.append('{code}')
    return '\n'.join(out).strip()


SYSTEM_FIELDS = {'project', 'issuetype', 'summary', 'description', 'reporter', 'priority', 'labels',
                 'parent', 'components', 'assignee', 'attachment', 'issuelinks'}


def _source(e, app, src):
    """A field-map source: a tracker field name, @areas, @title, @id, @app, @external, or =literal."""
    if src.startswith('='):
        return src[1:]
    if src == '@areas':
        return [a.strip() for a in (e.value('Area') or '').split(',') if a.strip() and a.strip() != 'unknown']
    if src in ('@title', '@id', '@app', '@external'):
        return {'@title': e.title, '@id': e.id, '@app': app, '@external': '%s:%s' % (app, e.id)}[src]
    v = e.text(src)
    if v is None or v.strip().lower() in ('none', 'unknown', 'n/a', ''):
        return None
    return wiki(v)


def _convert(value, spec, meta):
    """Shape a value for the field's schema (text, option, multi-option, component, labels, number)."""
    vmap = {k.lower(): v for k, v in (spec.get('valueMap') or {}).items()}
    if isinstance(value, list) and spec.get('from') == '@areas':
        # match option lists on tag parts too ("build / tooling" -> build, tooling)
        value = list(dict.fromkeys(value + [w.strip() for a in value for w in re.split(r'[/()]', a) if w.strip()]))
    vals = value if isinstance(value, list) else ([] if value is None else [value])
    vals = [vmap.get(str(v).lower(), v) for v in vals]
    schema = (meta or {}).get('schema') or {}
    typ, items = schema.get('type'), schema.get('items')
    allowed = (meta or {}).get('allowed') or []
    if allowed:
        low = {a.lower(): a for a in allowed if a}
        vals = [low[str(v).lower()] for v in vals if str(v).lower() in low]
    if not vals and spec.get('default') is not None:
        vals = spec['default'] if isinstance(spec['default'], list) else [spec['default']]
    if not vals:
        return None
    if typ == 'array' and items in ('option', 'component', 'version'):
        key = 'value' if items == 'option' else 'name'
        return [{key: v} for v in vals]
    if typ == 'array':
        return [re.sub(r'\s+', '-', str(v)) for v in vals]
    if typ == 'option':
        return {'value': vals[0]}
    if typ == 'number':
        try:
            return float(vals[0])
        except ValueError:
            return None
    return ', '.join(str(v) for v in vals) if len(vals) > 1 else str(vals[0])


def issue_fields(e, kind, app, jira, cross):
    def t(n):
        v = e.text(n)
        return None if v is None or v.strip().lower() in ('none', 'unknown', 'n/a', '') else v

    fmap = jira.field_map(kind)
    try:
        meta = jira.meta(kind) if fmap and jira.site and jira.token else {}
    except (JiraError, urllib.error.URLError):
        meta = {}
    mapped = {v if isinstance(v, str) else v.get('from') for v in fmap.values()}
    sections = (['Observation', 'Expected', 'File(s)', 'Repro / Notes'] if kind == 'bug' else
                ['Why', 'UI', 'Approach', 'Library / dependency notes', 'Out of scope', 'File(s)',
                 'Acceptance criteria', 'Test plan'])
    desc = ['Tracker: %s %s (%s)' % (app, e.id, 'cross-app' if cross else 'single app')]
    for n, label in (('Req', 'Requirements'), ('Depends on', 'Blocked by')):
        if t(n):
            desc.append('%s: %s' % (label, t(n)))
    for n in sections:
        if t(n) and n not in mapped:
            desc.append('\n*%s:*\n%s' % (n, wiki(t(n))))
    areas = _source(e, app, '@areas')
    labels = [e.id.lower(), app] + [re.sub(r'[^A-Za-z0-9_.-]+', '-', a) for a in areas]
    if cross:
        labels.append('cross-app')
    level = e.value('Severity' if kind == 'bug' else 'Priority')
    summary = '%s (%s, %s)' % (e.title, app, e.id)
    f = {'project': {'key': jira.project}, 'issuetype': {'name': jira.issue_type(kind)},
         'summary': summary if len(summary) <= 255 else summary[:252] + '...',
         'description': '\n'.join(desc), 'labels': list(dict.fromkeys(labels))}
    if level in PRIORITY_JIRA:
        f['priority'] = {'name': PRIORITY_JIRA[level]}
    ext = jira.field_id('externalId')
    if ext:
        f[ext] = '%s:%s' % (app, e.id)
    for fid, spec in fmap.items():
        spec = {'from': spec} if isinstance(spec, str) else spec
        v = _convert(_source(e, app, spec['from']), spec, meta.get(fid))
        if v is not None:
            f[fid] = v
    epic, _ = jira.epic_for(e, app)
    if epic:
        fld = (jira.cfg.get('epics') or {}).get('field', 'parent')
        f[fld] = {'key': epic} if fld == 'parent' else epic
    if jira.cfg.get('components') and areas and 'components' not in f:
        f['components'] = [{'name': a} for a in areas]
    return f


def jira_for_entries(root, targets, dry, quiet_missing_creds=False, source=None, limit=None):
    """targets: [(tracker_path, id, Entry-or-None)]; creates or links issues, writes keys back."""
    cfg = load_config(root)
    if jira_mode(root) == 'off':
        if quiet_missing_creds:
            return 0
        sys.exit('jira: off for this repo (no `jira` block in .cycle/tracker.json; see .cycle/TRACKERS.md "Jira setup")')
    jira = Jira(cfg)
    miss = jira.missing()
    if miss and not dry:
        if quiet_missing_creds:
            print('jira: %s not set; saved without a Jira issue (`jira sync` creates it later)' % ', '.join(miss))
            return 0
        sys.exit('jira: %s not set in this terminal. Set them (.cycle/TRACKERS.md, "Jira setup"), '
                 'open a new terminal, then run `jira doctor`.' % ', '.join(miss))
    ids = all_ids(root)
    made = linked = failed = gaps = noepic = 0
    rows = []
    for item in targets[:limit] if limit else targets:
        path, eid = item[0], item[1]
        tf = TrackerFile(path)
        cur = tf.get(eid)
        if cur is None:
            print('skip %s: not in %s' % (eid, os.path.relpath(path, root)))
            continue
        e = item[2] if len(item) > 2 and item[2] is not None else cur
        if KEY_RE.match(cur.value('Jira') or ''):
            continue
        app = app_of(root, path, cfg)
        cross = len(ids.get(eid, [])) > 1
        fields = issue_fields(e, tf.kind, app, jira, cross)
        if dry:
            gap = ''
            if not jira.missing():
                try:
                    fmap = jira.field_map(tf.kind)
                    need = []
                    for fid, m in jira.meta(tf.kind).items():
                        if m['required'] and fid not in SYSTEM_FIELDS and not fields.get(fid):
                            src = fmap.get(fid)
                            src = src if isinstance(src, str) else (src or {}).get('from')
                            need.append('%s (%s)' % (m['name'], 'entry has no %s: `set %s "%s" …`' % (src, eid, src)
                                                     if src and not src.startswith(('@', '=')) else
                                                     'not in the field map: `jira doctor`' if not src else 'no value'))
                except (JiraError, urllib.error.URLError):
                    need = []
                if need:
                    gaps += 1
                    gap = '  MISSING: %s' % ', '.join(need)
            epic, how = jira.epic_for(e, app)
            if not epic:
                noepic += 1
            rows.append('%-28s %-5s %-7s %-9s %s%s' % ('%s:%s' % (app, eid), fields['issuetype']['name'],
                                                       (fields.get('priority') or {}).get('name', '-'),
                                                       epic or '-', fields['summary'][:72], gap))
            continue
        try:
            key = jira.find_existing('%s:%s' % (app, eid), [eid.lower(), app])
            if key:
                linked += 1
                how = 'linked existing'
            else:
                key = jira.create(fields)
                made += 1
                how = 'created'
        except (JiraError, urllib.error.URLError) as ex:
            failed += 1
            why = str(ex)
            if isinstance(ex, JiraError) and ex.code == 400:
                try:
                    errs = json.loads(ex.body).get('errors') or {}
                    why = '; '.join('%s (%s)' % (m.rstrip('.'), k) for k, m in errs.items()) or why
                except ValueError:
                    pass
            print('FAILED %s:%s %s' % (app, eid, why))
            continue
        cur.set(tf.kind, 'Jira', key)
        epic, why = jira.epic_for(e, app)
        if epic and why in ('rule', 'default') and not cur.value('Jira parent'):
            cur.set(tf.kind, 'Jira parent', epic)
        tf.save()
        print('%s %s -> %s' % (how, '%s:%s' % (app, eid), key))
        if source:
            set_export_key(source, path, root, eid, key)
    if dry:
        print('%-28s %-5s %-7s %-9s %s' % ('external id', 'type', 'prio', 'epic', 'summary'))
        print('\n'.join(rows))
        print('(each is looked up by External ID first; existing issues are linked, not duplicated)')
        print('dry run: %d issues would be created or linked' % len(rows))
        if noepic:
            print('%d have no epic: set `Jira parent` (pick from `jira epics`) or add jira.epics.rules' % noepic)
        if gaps:
            print('%d would fail: a required Jira field gets no value (see MISSING above)' % gaps)
        elif jira.missing():
            print('(credentials not set, so required Jira fields were not checked)')
        return 0
    print('jira: %d created, %d linked to existing issues, %d failed' % (made, linked, failed))
    if failed:
        print('a required Jira field got no value: `jira sync --dry-run` names it per entry (fill the entry'
              ' with `set`, or fix the field map with `jira doctor --write`)')
    return 1 if failed else 0


def set_export_key(source, path, root, eid, key):
    text = read(source)
    rel = os.path.relpath(path, root).replace('\\', '/')
    parts = re.split(r'(?m)^(?=## )', text)
    for i, part in enumerate(parts):
        if part.startswith('## ') and part[3:].split('\n')[0].strip() == rel:
            parts[i] = re.sub(r'(?m)(^### \[%s\][^\n]*\n(?:(?!### \[).*\n)*?- \*\*Jira:\*\*) \S+' % re.escape(eid),
                              r'\1 ' + key, part)
    write(source, ''.join(parts))


def cmd_jira(argv):
    if not argv or argv[0] not in ('doctor', 'push', 'sync', 'configure', 'epics', 'parents', 'status', 'done', 'release'):
        sys.exit('usage: jira doctor [--write] | jira push FILE [--dry-run] | jira sync [--app A] [--dry-run] [--limit N]\n'
                 '       jira epics | jira parents [--dry-run] [--force] [--app A]\n'
                 '       jira status [--apply] [--app A] | jira done [--dry-run] | jira release VERSION [--dry-run]\n'
                 '       jira configure --mode enforce|optional|off [--site URL --project KEY] [--auth basic|bearer]\n'
                 '                      [--email-env VAR --token-env VAR] [--bug-type T --feature-type T]')
    sub, rest = argv[0], argv[1:]
    root = repo_root()
    cfg = load_config(root)
    o, pos = opts(rest, flags=('dry-run', 'write', 'force', 'apply'))
    dry = bool(o.get('dry-run'))
    if sub == 'status':
        return jira_status(root, o)
    if sub == 'done':
        return jira_done(root, o)
    if sub == 'release':
        return jira_release(root, o, pos)
    limit = int(o['limit']) if o.get('limit') else None
    if sub == 'doctor':
        return jira_doctor(root, cfg, o)
    if sub == 'configure':
        return jira_configure(root, cfg, o)
    if sub in ('epics', 'parents'):
        jira = Jira(cfg)
        if jira_mode(root) == 'off' or jira.missing():
            sys.exit('jira: %s' % ('off for this repo' if jira_mode(root) == 'off'
                                   else '%s not set' % ', '.join(jira.missing())))
        if sub == 'epics':
            for key, summary in jira.epics():
                print('%-10s %s' % (key, summary))
            return 0
        return jira_parents(root, cfg, jira, o)
    if sub == 'push':
        if not pos:
            sys.exit('usage: jira push FILE.md [--dry-run]')
        targets = []
        for rel, e in parse_export(pos[0]):
            p = os.path.join(root, rel)
            if not os.path.exists(p):
                print('skip %s: tracker %s not found' % (e.id, rel))
                continue
            errs = [x for x in lint_entry(e, kind_of(p)) if x[1] == 'E' and x[0] not in ('ORDER', 'BOX', 'INDENT')]
            if errs:
                print('skip %s: %s' % (e.id, '; '.join(m for _, _, m in errs)))
                continue
            targets.append((p, e.id, e))
        return jira_for_entries(root, targets, dry, source=None if dry else pos[0], limit=limit)
    targets = []
    for p in tracker_files(root):
        if o.get('app') and app_of(root, p, cfg) != o['app']:
            continue
        for e in TrackerFile(p).entries:
            if not KEY_RE.match(e.value('Jira') or ''):
                targets.append((p, e.id, None))
    return jira_for_entries(root, targets, dry, limit=limit)


def jira_parents(root, cfg, jira, o):
    """Reconcile each linked issue's epic with its entry's `Jira parent`.

    Only open epics of the project count as parents. Jira has an epic and the entry names
    none or a non-epic -> the entry takes Jira's. Jira has none -> set from the entry (or a
    rule). Both name different epics -> kept as is unless --force (tracker wins)."""
    dry, force = bool(o.get('dry-run')), bool(o.get('force'))
    epics = {k for k, _ in jira.epics()}
    c = {'set': 0, 'pulled': 0, 'same': 0, 'kept': 0, 'none': 0, 'failed': 0}
    for p in tracker_files(root):
        app = app_of(root, p, cfg)
        if o.get('app') and app != o['app']:
            continue
        tf = TrackerFile(p)
        dirty = False
        for e in tf.entries:
            key = e.value('Jira') or ''
            if not KEY_RE.match(key):
                continue
            want, how = jira.epic_for(e, app)
            if want and want not in epics:
                want, how = None, None  # a bundle, a story or a stale id: not an epic
            try:
                cur = jira.parent_of(key)
                cur = cur if cur in epics else None
                if cur and cur == want:
                    c['same'] += 1
                elif cur and (not want or how != 'entry'):
                    c['pulled'] += 1
                    print('pull  %s:%s %s epic %s from Jira' % (app, e.id, key, cur))
                    if not dry and e.value('Jira parent') != cur:
                        e.set(tf.kind, 'Jira parent', cur)
                        dirty = True
                elif cur and want and not force:
                    c['kept'] += 1
                    print('keep  %s:%s %s (Jira %s, tracker %s; --force to move)' % (app, e.id, key, cur, want))
                elif want:
                    c['set'] += 1
                    print('%s %s:%s %s -> %s' % ('would set' if dry else 'set  ', app, e.id, key, want))
                    if not dry:
                        jira.set_parent(key, want)
                        if e.value('Jira parent') != want:
                            e.set(tf.kind, 'Jira parent', want)
                            dirty = True
                else:
                    c['none'] += 1
                    print('none  %s:%s %s has no epic: `set %s "Jira parent" <epic>` (see `jira epics`)'
                          % (app, e.id, key, e.id))
                    if not dry and e.value('Jira parent'):
                        e.drop('Jira parent')
                        dirty = True
            except (JiraError, urllib.error.URLError) as ex:
                c['failed'] += 1
                print('FAILED %s:%s %s %s' % (app, e.id, key, ex))
        if dirty:
            tf.save()
    print('epics: %(set)d set, %(pulled)d taken from Jira, %(same)d already right, %(kept)d kept (differ), '
          '%(none)d without an epic, %(failed)d failed' % c)
    return 1 if c['failed'] else 0


def jira_configure(root, cfg, o):
    """Write the jira block of .cycle/tracker.json (mode, site, project, auth); keeps other keys."""
    mode = o.get('mode')
    if mode not in ('enforce', 'optional', 'off'):
        sys.exit('jira configure: --mode enforce|optional|off is required')
    cfg = dict(cfg)
    cfg['format'] = cfg.get('format', 2)
    if mode == 'off':
        if cfg.get('jira'):
            cfg['jira_disabled'] = cfg.pop('jira')  # kept so re-enabling restores the settings
    else:
        j = dict(cfg.get('jira') or cfg.pop('jira_disabled', None) or {})
        cfg.pop('jira_disabled', None)
        for opt, key in (('site', 'site'), ('project', 'project')):
            if o.get(opt):
                j[key] = o[opt].rstrip('/')
        if not j.get('site') or not j.get('project'):
            sys.exit('jira configure: --site and --project are required the first time')
        j['enforce'] = mode == 'enforce'
        types = dict(j.get('issueTypes') or {'bug': 'Bug', 'feature': 'Story'})
        if o.get('bug-type'):
            types['bug'] = o['bug-type']
        if o.get('feature-type'):
            types['feature'] = o['feature-type']
        j['issueTypes'] = types
        auth = dict(j.get('auth') or {})
        for opt, key in (('auth', 'type'), ('email-env', 'emailEnv'), ('token-env', 'tokenEnv')):
            if o.get(opt):
                auth[key] = o[opt]
        if auth:
            j['auth'] = auth
        j.setdefault('fields', {'externalId': None, 'acceptanceCriteria': None, 'testPlan': None})
        j.setdefault('components', False)
        order = ['site', 'project', 'enforce', 'issueTypes', 'auth', 'fields', 'components']
        cfg['jira'] = {k: j[k] for k in order if k in j}
        cfg['jira'].update({k: v for k, v in j.items() if k not in order})
    p = os.path.join(root, '.cycle', 'tracker.json')
    os.makedirs(os.path.dirname(p), exist_ok=True)
    write(p, json.dumps(cfg, indent=2) + '\n')
    _MODE.pop(root, None)
    print('jira mode: %s (.cycle/tracker.json)' % mode)
    if mode != 'off':
        print('next: python .cycle/trackers.py jira doctor')
    return 0


HINTS = [(r'steps to reproduce|\brepro', 'Repro / Notes'), (r'acceptance', 'Acceptance criteria'),
         (r'test plan|test strategy', 'Test plan'), (r'component|\barea', '@areas'),
         (r'observation|actual (result|behaviou?r)', 'Observation'), (r'expected', 'Expected'),
         (r'^files?\b|file\(s\)', 'File(s)'), (r'requirement', 'Req'), (r'approach|solution design', 'Approach'),
         (r'out of scope', 'Out of scope'), (r'^why\b|motivation|business value', 'Why')]


def _hint(name, kind):
    for rx, src in HINTS:
        if re.search(rx, name, re.I) and (src.startswith('@') or src in fields_of(kind)):
            return src
    return None


def jira_doctor(root, cfg, o=None):
    """Check credentials and the project's create screens; --write fills the field map."""
    o = o or {}
    jira = Jira(cfg)
    print('config      %s' % (os.path.join('.cycle', 'tracker.json') if cfg else 'MISSING .cycle/tracker.json'))
    print('mode        %s' % jira_mode(root))
    if jira_mode(root) == 'off':
        print('Jira is off for this repo; nothing to check')
        return 0
    print('site        %s' % (jira.site or 'MISSING'))
    print('project     %s' % (jira.project or 'MISSING'))
    print('auth        %s (%s)' % (jira.auth_type, 'Cloud email + API token' if jira.auth_type == 'basic' else 'Data Center personal access token'))
    if jira.auth_type == 'basic':
        print('%-11s %s' % (jira.email_env, 'set' if jira.email else 'MISSING'))
    print('%-11s %s' % (jira.token_env, 'set (%d chars)' % len(jira.token) if jira.token else 'MISSING'))
    if jira.missing():
        print('FAIL: set %s (see .cycle/TRACKERS.md, "Jira setup")' % ', '.join(jira.missing()))
        return 1
    ok, changed = True, False
    j = dict(cfg.get('jira') or {})
    fields_cfg = dict(j.get('fields') or {})
    fmap_all = dict(fields_cfg.get('map') or {})
    tags = sorted({a.strip() for p in tracker_files(root) for e in TrackerFile(p).entries
                   for a in (e.value('Area') or '').split(',') if a.strip() and a.strip() != 'unknown'})
    try:
        me = jira.req('GET', '/rest/api/2/myself')
        print('auth        OK as %s' % me.get('displayName', '?'))
        proj = jira.req('GET', '/rest/api/2/project/%s' % urllib.parse.quote(jira.project))
        print('project     OK: %s' % proj.get('name'))
        for kind in ('bug', 'feature'):
            tname = jira.issue_type(kind)
            meta = jira.meta(kind)
            if not meta:
                print('issue type  %-8s NOT ON THE PROJECT\'S CREATE SCREEN' % tname)
                ok = False
                continue
            print('issue type  %-8s OK (%d fields on the create screen)' % (tname, len(meta)))
            ext = next((fid for fid, m in meta.items() if m['name'].strip().lower() == 'external id'), None)
            if ext and fields_cfg.get('externalId') != ext:
                print('            External ID is %s on this screen (config: %s)' % (ext, fields_cfg.get('externalId') or '-'))
                fields_cfg['externalId'] = ext
                changed = True
            kmap = dict(jira.field_map(kind))
            kmap.update(fmap_all.get(kind) or {})
            for fid, m in sorted(meta.items(), key=lambda x: (not x[1]['required'], x[1]['name'])):
                if fid in SYSTEM_FIELDS or fid == fields_cfg.get('externalId'):
                    continue
                have = kmap.get(fid)
                hint = None if have else _hint(m['name'], kind)
                if not (m['required'] or have or hint):
                    continue
                state = 'mapped from %s' % (have if isinstance(have, str) else (have or {}).get('from')) if have else (
                    'suggest %s' % hint if hint else 'UNMAPPED')
                print('  %-9s %-34s %-18s %s' % ('required' if m['required'] else 'optional', m['name'][:34], fid, state))
                if hint:
                    kmap[fid] = hint
                    changed = True
                if m['required'] and not (have or hint):
                    ok = False
                src = have if isinstance(have, str) else (have or {}).get('from') if have else hint
                if src == '@areas' and m['allowed']:
                    low = {a.lower() for a in m['allowed']}
                    miss = [t for t in tags if t.lower() not in low and not any(
                        w.strip().lower() in low for w in re.split(r'[/()]', t))]
                    print('            allowed: %s' % ', '.join(m['allowed'][:30]))
                    if miss:
                        print('            %d Area tags match no option (%s%s): they are dropped; an entry with none'
                              ' left needs a "default" or "valueMap" (TRACKERS.md, "Field map")' % (
                                  len(miss), ', '.join(miss[:12]), ', …' if len(miss) > 12 else ''))
            fmap_all[kind] = kmap
        wok, wchanged, wfl = doctor_workflow(jira, j, o.get('write'))
        ok = ok and wok
        if wchanged:
            j['workflow'] = wfl
            changed = True
        if j.get('worklog') != 'off':
            tt = (jira.req('GET', '/rest/api/2/configuration') or {}).get('timeTrackingEnabled')
            print('worklogs    %s' % ('time tracking on (opt-in per person: TRACKERS.md, "Worklogs")' if tt else
                                      'time tracking OFF on the site: worklogs cannot post (a Jira admin turns it on)'))
        bl = doctor_bundles(jira, j, fmap_all)
        if bl and bl != j.get('bundles'):
            j['bundles'] = bl
            changed = True
    except (JiraError, urllib.error.URLError) as ex:
        print('FAIL: %s' % ex)
        return 1
    if changed and o.get('write'):
        fields_cfg['map'] = fmap_all
        j['fields'] = fields_cfg
        cfg = dict(cfg)
        cfg['jira'] = j
        write(os.path.join(root, '.cycle', 'tracker.json'), json.dumps(cfg, indent=2) + '\n')
        print('wrote the suggestions to .cycle/tracker.json (jira.fields, jira.workflow); review and commit it')
    elif changed:
        print('re-run with --write to save the suggestions to .cycle/tracker.json')
    print('doctor: %s' % ('OK' if ok and not (changed and not o.get('write')) else 'issues above'))
    return 0 if ok else 1

# ---------------------------------------------------------------- adopt + schema lint + hook

def adopt_file(path, root, report):
    kind = kind_of(path)
    text = read(path)
    h1 = next((l for l in text.split('\n') if l.startswith('# ')), '# %s' % os.path.basename(path))
    chunks = re.split(r'(?m)^(?=### \[|## )', text)
    entries, removed, section = [], [], ''
    fence_safe = []
    # re-split respecting fences: drop splits inside fenced blocks
    buf = ''
    for c in chunks:
        if buf and buf.count('```') % 2 == 1:
            buf += c
            continue
        if buf:
            fence_safe.append(buf)
        buf = c
    if buf:
        fence_safe.append(buf)
    for c in fence_safe:
        if c.startswith('## '):
            section = c.split('\n')[0]
            continue
        if not c.startswith('### ['):
            continue
        c = re.sub(r'(?m)^---\s*\n?', '', c)
        e = parse_entry(c)
        st = e.status() or ''
        archive = bool(re.search(r'shipped|migrated|archive|released|closed', section, re.I))
        if st and CLOSED_RE.search(st) and not st.endswith('pending-migration') or (not st and archive):
            removed.append((e.id, st or 'archived', e.value('Jira') or ''))
            continue
        adopt_entry(e, kind, report['manual'])
        entries.append(e)
    seen, uniq = set(), []
    for e in entries:
        if e.id in seen:
            report['manual'].append('%s: duplicate active copy in %s; second copy dropped' % (e.id, path))
            continue
        seen.add(e.id)
        uniq.append(e)
    rel_fmt = os.path.relpath(os.path.join(root, '.cycle', 'TRACKERS.md'), os.path.dirname(path)).replace('\\', '/')
    pre = ('%s\n\nActive work only. Format and rules: [`.cycle/TRACKERS.md`](%s). Write with '
           '`python .cycle/trackers.py`, never by hand. Shipped and closed entries are removed; '
           'their record is `CHANGELOG.md`, Jira, and `python .cycle/trackers.py show <id>`.\n') % (h1, rel_fmt)
    out = pre + '\n## Open\n\n' + '\n'.join(e.render() for e in uniq)
    report['files'].append((os.path.relpath(path, root), len(text), len(out), len(uniq), len(removed)))
    report['removed'] += [(os.path.relpath(path, root),) + r for r in removed]
    return out


def cmd_adopt(argv):
    """adopt [PATH...] [--dry-run] [--report FILE]: convert legacy trackers to format 2."""
    o, pos = opts(argv, flags=('dry-run',))
    root = repo_root()
    paths = [os.path.abspath(p) for p in pos] or tracker_files(root)
    report = {'files': [], 'removed': [], 'manual': []}
    for p in paths:
        out = adopt_file(p, root, report)
        if not o.get('dry-run'):
            write(p, out)
    cfgp = os.path.join(root, '.cycle', 'tracker.json')
    if not o.get('dry-run'):
        cfg = load_config(root)
        if cfg.get('format') != 2:
            cfg['format'] = 2
            os.makedirs(os.path.dirname(cfgp), exist_ok=True)
            write(cfgp, json.dumps(cfg, indent=2) + '\n')
    lines = ['# Tracker adoption report (%s)' % today(), '',
             '| tracker | bytes before | bytes after | active | removed |', '|---|---:|---:|---:|---:|']
    for f, b, a, n, r in report['files']:
        lines.append('| %s | %d | %d | %d | %d |' % (f, b, a, n, r))
    lines += ['', '## Removed (shipped or closed; recoverable with `trackers.py show <id>`)', '',
              '| tracker | id | status | Jira |', '|---|---|---|---|']
    lines += ['| %s | %s | %s | %s |' % r for r in report['removed']]
    lines += ['', '## Needs a hand decision', ''] + ['- ' + m for m in report['manual']] + ['']
    text = '\n'.join(lines)
    if o.get('report'):
        write(o['report'], text)
    tb = sum(f[1] for f in report['files'])
    ta = sum(f[2] for f in report['files'])
    print('adopt: %d files, %d KB -> %d KB, %d active, %d removed, %d hand decisions%s' % (
        len(report['files']), tb // 1024, ta // 1024, sum(f[3] for f in report['files']),
        len(report['removed']), len(report['manual']), ' (dry run)' if o.get('dry-run') else ''))
    return 0


def schema_lint(path, fix):
    """Format-2 checks for one tracker. Returns (errors, warnings) as (line, code, id, msg)."""
    kind = kind_of(path)
    if not kind:
        return [], []
    text = read(path)
    errs, warns = [], []
    heads = [l for l in text.split('\n') if l.startswith('## ')]
    if heads != ['## Open']:
        errs.append((1, 'SECTION', '-', 'only one `## Open` section allowed, found %s (run `adopt`)' % (heads or 'none')))
        fix = False  # never reshape a legacy file entry by entry; `adopt` converts it whole
    tf = TrackerFile(path)
    lineno = {}
    for n, l in enumerate(text.split('\n'), 1):
        m = HEAD_RE.match(l) or re.match(r'^### \[([^\]]+)\]', l)
        if m:
            lineno.setdefault(m.group(1), n)
    changed = False
    for e in tf.entries:
        if fix:
            before = e.render()
            fix_entry(e, kind)
            changed = changed or e.render() != before
        for code, sev, msg in lint_entry(e, kind):
            (errs if sev == 'E' else warns).append((lineno.get(e.id, 0), code, e.id, msg))
    if fix and (changed or tf.render() != text):
        tf.save()
        warns.append((0, 'FIXED', '-', 'mechanical fixes applied'))
    return errs, warns


def cmd_hook(argv):
    """Claude Code PreToolUse hook: block hand edits of format-2 trackers."""
    try:
        ev = json.load(sys.stdin)
    except ValueError:
        return 0
    ti = ev.get('tool_input') or {}
    p = ti.get('file_path') or ti.get('notebook_path') or ''
    if ev.get('tool_name') in ('Edit', 'Write', 'MultiEdit') and os.path.basename(p) in TRACKER_FILES:
        sys.stderr.write(
            'Hand edits of %s are blocked. Use the tracker tool instead:\n'
            '  python .cycle/trackers.py add --tracker %s --json -     (new entry; JSON on stdin)\n'
            '  python .cycle/trackers.py set <ID> "<Field>" <value>     (change a field; - reads stdin)\n'
            '  python .cycle/trackers.py log <ID> "<text>"              (dated note)\n'
            '  python .cycle/trackers.py migrate <ID> | close <ID> --reason <r>\n'
            'Format: .cycle/TRACKERS.md\n' % (os.path.basename(p), p))
        return 2
    return 0


BRANCH_MAX = 60  # Bitbucket Data Center: 100 for refs/heads/<name> (89 for the name); Cloud: no documented limit
STOP = {'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'with', 'when', 'is', 'are', 'be', 'by', 'from', 'at', 'as'}


def branch_name(kind, key, title, maxlen=BRANCH_MAX, btype=None):
    """<feature|bugfix|hotfix>/<KEY>-<slug>: KEY is the issue key in this project's own Jira (else the
    tracker id); lowercase ASCII words, stop words dropped, cut at a word so the name fits MAXLEN."""
    import unicodedata
    prefix = '%s/%s' % (btype or ('bugfix' if kind == 'bug' else 'feature'), key)
    words = re.findall(r'[a-z0-9]+', unicodedata.normalize('NFKD', title).encode('ascii', 'ignore').decode().lower())
    words = [w for w in words if w not in STOP] or words
    slug = ''
    for w in words:
        nxt = (slug + '-' + w) if slug else w
        if len(prefix) + 1 + len(nxt) > maxlen:
            break
        slug = nxt
    if not slug and words:
        slug = words[0][:max(0, maxlen - len(prefix) - 1)]
    return (prefix + '-' + slug) if slug else prefix


def cmd_branch(argv):
    """branch ID [ID...] [--type feature|bugfix|hotfix|bundle] [--slug TEXT] [--max N] [--app A]"""
    o, pos = opts(argv)
    if not pos or o.get('type') not in (None, 'feature', 'bugfix', 'hotfix', 'bundle'):
        sys.exit('usage: branch ID [ID...] [--type feature|bugfix|hotfix|bundle] [--slug "short summary"] [--max N]')
    root = repo_root()
    found = [locate(root, i, None, o.get('app')) for i in pos]
    kinds = [tf.kind for tf, _ in found]
    kind = 'feature' if 'feature' in kinds else 'bug'
    tf, e = found[0]
    key = e.value('Bundle' if o.get('type') == 'bundle' else 'Jira') or ''
    if not KEY_RE.match(key):
        key = e.id  # no issue (or bundle) yet: rename the branch once it exists
    print(branch_name(kind, key, o.get('slug') or e.title, int(o.get('max') or BRANCH_MAX), o.get('type')))
    return 0



# ---------------------------------------------------------------- bundles (batchable clusters in Jira)

def bundle_members(root, bkey):
    """[(tracker path, entry)] for the entries whose `Bundle:` is BKEY, across every tracker."""
    return [(p, e) for p in tracker_files(root) for e in TrackerFile(p).entries if (e.value('Bundle') or '') == bkey]


def bundle_follow(root, jira, wf, bkey):
    """Keep bundle BKEY level with its members: the least-advanced member's board target, Done
    once no member is left in the trackers. Forward only. True when the board matches."""
    members = bundle_members(root, bkey)
    if not members:
        return jira_move(jira, bkey, wf['done'], wf)
    sts = [e.status() for _, e in members]
    if all(s.endswith('pending-migration') for s in sts):
        target = wf['review']
    elif all(s != 'open' for s in sts):
        target = wf['inProgress']
    else:
        target = None
    return jira_move(jira, bkey, target, wf) if target else True


def bundle_fields(jira, summary, members, root, cfg):
    """Create-issue fields for a bundle Task: label cycle-bundle, members listed, shared epic."""
    lines = ['Bundle: tickets implemented together on one branch (/implement-batch).',
             'Each member is linked "%s" from this issue and moves across the board with it.' % jira.link_type(), '',
             '*Members*']
    epics = set()
    for p, e in members:
        lines.append('* %s %s (%s)' % (e.value('Jira'), e.title, e.id))
        epics.add(jira.epic_for(e, app_of(root, p, cfg))[0])
    title = 'Bundle: ' + summary
    f = {'project': {'key': jira.project}, 'issuetype': {'name': jira.issue_type('bundle')},
         'summary': title if len(title) <= 255 else title[:252] + '...',
         'description': '\n'.join(lines), 'labels': [BUNDLE_LABEL]}
    if len(epics) == 1 and None not in epics:
        fld = (jira.cfg.get('epics') or {}).get('field', 'parent')
        f[fld] = {'key': epics.pop()} if fld == 'parent' else epics.pop()
    fmap = jira.field_map('bundle')  # literals only: a bundle has no tracker entry ("=value", @title)
    if fmap:
        try:
            meta = jira.meta('bundle')
        except NET_ERRORS:
            meta = {}
        pseudo = Entry('BUNDLE', summary)
        for fid, spec in fmap.items():
            spec = {'from': spec} if isinstance(spec, str) else spec
            v = _convert(_source(pseudo, '', spec['from']), spec, meta.get(fid))
            if v is not None:
                f[fid] = v
    return f


def _bundle_jira(root, verb):
    jira = jira_or_none(root)
    if not jira:
        sys.exit('bundle %s: needs Jira (mode enforce or optional, with credentials: `jira doctor`)' % verb)
    return jira, fit_workflow(jira, workflow(load_config(root)))


def _keyed(root, ids, app):
    """Locate IDS; create missing Jira issues first. Returns [(path, entry)]."""
    found = [(tf.path, e) for tf, e in (locate(root, i, None, app) for i in ids)]
    missing = [(p, e.id) for p, e in found if not KEY_RE.match(e.value('Jira') or '')]
    if missing:
        jira_for_entries(root, missing, dry=False)
        found = [(tf.path, e) for tf, e in (locate(root, i, None, app) for i in ids)]
    still = [e.id for _, e in found if not KEY_RE.match(e.value('Jira') or '')]
    if still:
        sys.exit('bundle: no Jira issue for %s (`jira sync --dry-run` says why)' % ', '.join(still))
    return found


def _join(jira, bkey, members):
    for p, e in members:
        print('  %s: %s %s' % (e.value('Jira'), jira.link(bkey, e.value('Jira')), bkey))
        tf = TrackerFile(p)
        cur = tf.get(e.id)
        cur.set(tf.kind, 'Bundle', bkey)
        fix_entry(cur, tf.kind)
        check_or_die(cur, tf.kind)
        tf.save()


def cmd_bundle(argv):
    """bundle create ID ID... --summary S | add BKEY ID... | remove ID... | sync BKEY   [--app A] [--dry-run]"""
    usage = ('usage: bundle create ID ID... --summary "short summary" [--dry-run] | bundle add BKEY ID... |\n'
             '       bundle remove ID... | bundle sync BKEY      (all take --app A)')
    if not argv or argv[0] not in ('create', 'add', 'remove', 'sync'):
        sys.exit(usage)
    sub = argv[0]
    o, pos = opts(argv[1:], flags=('dry-run',))
    root = repo_root()
    cfg = load_config(root)
    if sub == 'create':
        if len(pos) < 2 or not o.get('summary'):
            sys.exit('bundle create: two or more ids and --summary are required (one ticket: /implement)')
        if o.get('dry-run'):
            found = [(tf.path, e) for tf, e in (locate(root, i, None, o.get('app')) for i in pos)]
            for p, e in found:
                print('member %-18s %-10s %s' % (e.id, e.value('Jira') or 'pending', e.title))
            print('bundle "Bundle: %s" (%s, label %s); branch %s' % (
                o['summary'], ISSUE_TYPES['bundle'], BUNDLE_LABEL,
                branch_name('bug', '<KEY>', o['summary'], btype='bundle')))
            return 0
        jira, wf = _bundle_jira(root, 'create')
        members = _keyed(root, pos, o.get('app'))
        other = ['%s (in %s)' % (e.id, e.value('Bundle')) for _, e in members if e.value('Bundle')]
        if other:
            sys.exit('bundle create: already bundled: %s; `bundle remove` them first' % ', '.join(other))
        try:
            bkey = jira.create(bundle_fields(jira, o['summary'], members, root, cfg))
            print('created bundle %s "%s"' % (bkey, o['summary']))
            _join(jira, bkey, members)
        except NET_ERRORS as ex:
            sys.exit('bundle create: %s (`jira doctor` checks the %s type and the "%s" link type)' % (
                ex, jira.issue_type('bundle'), jira.link_type()))
        bundle_follow(root, jira, wf, bkey)
        print('branch: %s' % branch_name('bug', bkey, o['summary'], btype='bundle'))
        return 0
    if sub == 'add':
        if len(pos) < 2 or not KEY_RE.match(pos[0]):
            sys.exit(usage)
        jira, wf = _bundle_jira(root, 'add')
        members = _keyed(root, pos[1:], o.get('app'))
        other = ['%s (in %s)' % (e.id, e.value('Bundle')) for _, e in members if e.value('Bundle') not in (None, pos[0])]
        if other:
            sys.exit('bundle add: already bundled: %s; `bundle remove` them first' % ', '.join(other))
        try:
            _join(jira, pos[0], members)
        except NET_ERRORS as ex:
            sys.exit('bundle add: %s' % ex)
        bundle_follow(root, jira, wf, pos[0])
        return 0
    if sub == 'remove':
        if not pos:
            sys.exit(usage)
        jira = jira_or_none(root)
        touched = set()
        for eid in pos:
            tf, e = locate(root, eid, None, o.get('app'))
            b = e.value('Bundle')
            if not b:
                print('%s: not in a bundle' % eid)
                continue
            if jira and KEY_RE.match(e.value('Jira') or ''):
                try:
                    print('  %s: %d link(s) to %s removed' % (e.value('Jira'), jira.unlink(b, e.value('Jira')), b))
                except NET_ERRORS as ex:
                    print('  warning: unlink %s from %s in Jira by hand: %s' % (e.value('Jira'), b, ex))
            elif not jira:
                print('  unlink %s from %s in Jira by hand (Jira off or no credentials)' % (e.value('Jira'), b))
            e.drop('Bundle')
            tf.save()
            touched.add(b)
            print('%s: removed from bundle %s' % (eid, b))
        if jira:
            wf = fit_workflow(jira, workflow(cfg))
            for b in sorted(touched):
                if bundle_members(root, b):
                    bundle_follow(root, jira, wf, b)
                else:
                    print('bundle %s has no members left: close it in Jira' % b)
        return 0
    if len(pos) != 1 or not KEY_RE.match(pos[0]):
        sys.exit(usage)
    jira, wf = _bundle_jira(root, 'sync')
    n = len(bundle_members(root, pos[0]))
    print('bundle %s: %d member(s) in the trackers' % (pos[0], n))
    if not n:  # it would go to Done: make sure it is a bundle
        try:
            labels = jira.req('GET', '/rest/api/2/issue/%s?fields=labels' % pos[0])['fields'].get('labels') or []
        except NET_ERRORS as ex:
            sys.exit('bundle sync: %s' % ex)
        if BUNDLE_LABEL not in labels:
            sys.exit('bundle sync: %s has no label %s; not a bundle, left alone' % (pos[0], BUNDLE_LABEL))
    return 0 if bundle_follow(root, jira, wf, pos[0]) else 1


def doctor_bundles(jira, j, fmap_all):
    """Bundle Task type and link type. Returns the jira.bundles block to save, or None."""
    tname = jira.issue_type('bundle')
    try:
        meta = jira.meta('bundle')
    except JiraError:
        meta = {}
    fmap = fmap_all.get('bundle') or jira.field_map('bundle')
    if not meta:
        print('bundle type %-8s NOT ON THE PROJECT\'S CREATE SCREEN (set jira.issueTypes.bundle)' % tname)
    else:
        need = [m['name'] for fid, m in meta.items() if m['required'] and fid not in SYSTEM_FIELDS
                and fid != (j.get('fields') or {}).get('externalId') and fid not in fmap]
        print('bundle type %-8s OK%s' % (tname, '' if not need else '; required with no value: %s '
              '(add literals in jira.fields.map.bundle, e.g. {"<field id>": "=<value>"})' % ', '.join(need)))
    want = jira.link_type()
    try:
        lts = jira.req('GET', '/rest/api/2/issueLinkType').get('issueLinkTypes', [])
    except JiraError as ex:
        print('link type   cannot list link types: %s' % ex)
        return None
    lt = next((t for t in lts if t.get('name', '').lower() == want.lower()), None) or \
        next((t for t in lts if t.get('outward', '').lower() == 'implements'), None)
    if not lt:
        print('link type   "%s" MISSING: bundles cannot be linked. Jira settings > Issues > Issue linking: '
              'add name "%s", outward "implements", inward "is implemented by"' % (want, want))
        return None
    print('link type   %s (outward "%s", inward "%s") OK' % (lt['name'], lt.get('outward'), lt.get('inward')))
    return dict(j.get('bundles') or {}, link=lt['name'])


# ---------------------------------------------------------------- commit messages (git commit-msg hook)

COMMIT_EXEMPT = ('main', 'master', 'trunk', 'release/*')
BRANCH_KEY_RE = re.compile(r'(?:^|/)([A-Z][A-Z0-9]+-\d+)(?=-|/|$)')
PASS_RE = re.compile(r'^(?:(?:fixup|squash|amend)! |Merge |Revert ")')


def branch_key(branch, project=None):
    """(key, tracker id) the branch is named for: <type>/<KEY>-<summary>. A tracker id in the key
    slot (no issue yet) comes back as the second value."""
    m = BRANCH_KEY_RE.search(branch or '')
    if not m:
        return None, None
    k = m.group(1)
    if re.match(r'(BUG|FEAT)-\d+$', k) and k.split('-')[0] != project:
        return None, k
    return k, None


def _commit_lines(path, cc):
    lines = []
    for l in read(path).split('\n'):
        if l.startswith(cc + ' ------------------------ >8 ------------------------'):
            break
        if l.startswith(cc):
            continue
        lines.append(l.rstrip())
    while lines and not lines[0]:
        lines.pop(0)
    while lines and not lines[-1]:
        lines.pop()
    return lines


def cmd_commit_msg(argv):
    """commit-msg FILE: the git commit-msg hook. Jira `enforce` only: on a work branch, line 1 is
    the branch's Jira key, then a blank line, then the message (TRACKERS.md, "Branches and
    commits"). Trunk and release branches, detached HEAD, merges, fixups and reverts pass."""
    if not argv:
        return 0
    root = repo_root()
    if jira_mode(root) != 'enforce':
        return 0
    branch = git('symbolic-ref', '--quiet', '--short', 'HEAD', cwd=root)
    if not branch:
        return 0
    j = load_config(root).get('jira') or {}
    exempt = list((j.get('commits') or {}).get('exempt') or COMMIT_EXEMPT)
    default = git('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD', cwd=root)
    if default:
        exempt.append(default.split('/', 1)[-1])
    if any(fnmatch.fnmatchcase(branch, p) for p in exempt):
        return 0
    gd = git('rev-parse', '--git-dir', cwd=root) or '.git'
    if os.path.exists(os.path.join(root, gd, 'MERGE_HEAD')):
        return 0
    cc = git('config', '--get', 'core.commentChar', cwd=root) or '#'
    lines = _commit_lines(argv[0], cc if cc != 'auto' else '#')
    if not lines or PASS_RE.match(lines[0]):
        return 0  # empty: git aborts the commit itself
    key, tid = branch_key(branch, j.get('project'))
    if tid:
        why = ('branch "%s" is still named for tracker id %s. Create its issue and rename the branch:\n'
               '  python .cycle/trackers.py jira sync\n'
               '  git branch -m "$(python .cycle/trackers.py branch %s)"' % (branch, tid, tid))
    elif not key:
        why = ('branch "%s" carries no Jira key. Work happens on a branch named for its issue:\n'
               '  git branch -m "$(python .cycle/trackers.py branch <ID>)"   (or <type>/<KEY>-<summary>)' % branch)
    elif lines[0].strip() != key:
        why = 'line 1 must be the branch\'s Jira key, exactly "%s" (got "%s")' % (key, lines[0][:60])
    elif len(lines) < 3 or lines[1] or not lines[2].strip():
        why = 'line 2 must be blank and line 3 must start the message'
    else:
        return 0
    k = key or 'PROJ-123'
    sys.stderr.write('commit refused (Jira enforce): %s\n\nForm (.cycle/TRACKERS.md, "Branches and commits"):\n'
                     '  %s\n\n  <message>\n\nA commit for another ticket on this branch starts the message with that '
                     'ticket\'s key:\n  %s\n\n  PROJ-124 <title> (BUG-...)\n' % (why, k, k))
    return 1


def cmd_worklog(argv):
    import worklog  # opt-in Jira worklogs (worklog.py, next to this file)
    return worklog.main(argv)


COMMANDS = {'branch': cmd_branch, 'add': cmd_add, 'set': cmd_set, 'log': cmd_log, 'migrate': cmd_migrate, 'close': cmd_close,
            'show': cmd_show, 'export': cmd_export, 'jira': cmd_jira, 'adopt': cmd_adopt, 'hook': cmd_hook,
            'bundle': cmd_bundle, 'commit-msg': cmd_commit_msg, 'worklog': cmd_worklog}
