#!/usr/bin/env python3
"""Cycle-file tooling for bugs.md, features.md and CHANGELOG.md (stdlib only).

  trackers.py merge O A B PATH        git merge driver: per-entry three-way merge
  trackers.py lint [--fix] [--staged] [PATH]  integrity + format-2 schema; exit 1 on errors
  trackers.py install [--auto]        set up the repo and this clone (driver, hooks, docs)
  trackers.py add|set|log|migrate|close|show|export|adopt   writers (tracker_ops.py)
  trackers.py branch ID [ID...]                            branch name: feature|bugfix|hotfix|bundle/KEY-slug
  trackers.py bundle create|add|remove|sync                 a Jira bundle for a batch (implements links)
  trackers.py commit-msg FILE                               git commit-msg hook: KEY on line 1 (Jira enforce)
  trackers.py jira doctor|push FILE|sync                    Jira issue creation + key write-back
  trackers.py worklog state|mode|start|pause|resume|retarget|finish|log|backfill|undo|sync|status
                                                            opt-in Jira worklogs (worklog.py, worklog_time.py)

Format and command reference: .cycle/TRACKERS.md.

Entries are keyed by id (`### [BUG-n]` in trackers, `- [FEAT-n]` bullets in the
changelog), so a status edit or a move between sections merges as one change
instead of being duplicated the way `merge=union` duplicates it.
"""
import os, re, shutil, subprocess, sys, tempfile

BUNDLE_VERSION = '2026.10.30'  # bump with every change that projects must re-vendor (bundle_check.py)

TRK_ID = re.compile(r'^###\s+\[((?:BUG|FEAT)-\d+[a-z]*)\]')
CL_ID = re.compile(r'^[-*]\s+\[((?:BUG|FEAT)-\d+[a-z]*)\]')
BULLET = re.compile(r'^[-*] ')
FENCE = re.compile(r'^\s*(```|~~~)')
STATUS = re.compile(r'^\s*[-*]\s+(?:\[[ xX]\]\s+)?\*\*Status:\*\*\s*(.*)')
ARCHIVE = re.compile(r'shipped|migrated|archive|released|closed', re.I)
MARK = re.compile(r'^(<{7}|={7}|>{7})(\s|$)')
BUMP_MARK = re.compile(r'\[(major|minor|patch)\]\s*$', re.M)
TRACKERS = ('bugs.md', 'features.md', 'CHANGELOG.md')


def mode_of(path):
    return 'changelog' if os.path.basename(path).lower().startswith('changelog') else 'tracker'


class Doc:
    def __init__(self):
        self.pre = ''
        self.secs = []    # [key, line, intro, subs]; sub = [key, line, intro, [item keys]]
        self.items = {}   # key -> [h2key, h3key, text]
        self.line = {}    # key -> 1-based line number


def _uniq(key, taken):
    if key not in taken:
        return key
    n = 2
    while '%s#%d' % (key, n) in taken:
        n += 1
    return '%s#%d' % (key, n)


def parse(text, mode):
    d = Doc()
    sec = sub = None
    tgt = ['pre']
    fence = False

    def ensure_sec():
        nonlocal sec
        if sec is None:
            sec = [None, '', '', []]
            d.secs.append(sec)

    def ensure_sub():
        nonlocal sub
        ensure_sec()
        if sub is None:
            sub = [None, '', '', []]
            sec[3].append(sub)

    for n, line in enumerate(text.splitlines(keepends=True), 1):
        is_fence = bool(FENCE.match(line))
        live = not fence and not is_fence
        if live and line.startswith('## '):
            sec = [_uniq(line.strip(), {s[0] for s in d.secs}), line, '', []]
            d.secs.append(sec)
            sub = None
            tgt = ['sec', sec]
            continue
        if live and mode == 'changelog' and line.startswith('### '):
            ensure_sec()
            sub = [_uniq(line.strip(), {s[0] for s in sec[3]}), line, '', []]
            sec[3].append(sub)
            tgt = ['sub', sub]
            continue
        key = None
        if live and mode == 'tracker' and line.startswith('### '):
            m = TRK_ID.match(line)
            key = m.group(1) if m else 'h:' + line.strip()
        elif live and mode == 'changelog' and BULLET.match(line):
            m = CL_ID.match(line)
            # an id may appear once per change type (Added + Changed); a release move keeps the key
            key = '%s|%s' % (m.group(1), sub[0] if sub else '') if m else 't:' + line.strip()
        if key is not None:
            ensure_sub()
            key = _uniq(key, d.items)
            d.items[key] = [sec[0], sub[0], '']
            d.line[key] = n
            sub[3].append(key)
            tgt = ['item', key]
        if tgt[0] == 'pre':
            d.pre += line
        elif tgt[0] in ('sec', 'sub'):
            tgt[1][2] += line
        else:
            d.items[tgt[1]][2] += line
        if is_fence:
            fence = not fence
    return d


def render(d, mode, tidy=False):
    out = [d.pre]
    for si, (_, line, intro, subs) in enumerate(d.secs):
        out += [line, intro]
        for ui, (_, l3, i3, keys) in enumerate(subs):
            out += [l3, i3]
            for ki, k in enumerate(keys):
                t = d.items[k][2]
                if tidy:
                    last_in_sub = ki == len(keys) - 1
                    more = not (last_in_sub and ui == len(subs) - 1 and si == len(d.secs) - 1)
                    if not t.endswith('\n'):
                        t += '\n'
                    if more and (mode == 'tracker' or last_in_sub) and not t.endswith('\n\n'):
                        t += '\n'
                out.append(t)
    return ''.join(out)


def status_of(text):
    fence = False
    found = []
    for line in text.splitlines():
        if FENCE.match(line):
            fence = not fence
            continue
        if not fence:
            m = STATUS.match(line)
            if m:
                found.append(m.group(1).strip())
    return found


def rank(text, section):
    st = status_of(text)
    s = ' '.join(st).lower()
    if 'pending-migration' in s:
        r = 3
    elif re.search(r'migrated|shipped|closed|released|won.?t|wontfix|duplicate|superseded|rejected|\bdone\b', s):
        r = 4
    elif re.search(r'in.progress|blocked|review|started', s):
        r = 2
    elif 'open' in s:
        r = 1
    else:
        r = 0
    if section and ARCHIVE.search(section):
        r = max(r, 4)
    return r


def merge_file(o, a, b):
    with tempfile.TemporaryDirectory() as td:
        paths = []
        for name, t in (('a', a), ('o', o), ('b', b)):
            p = os.path.join(td, name)
            with open(p, 'w', encoding='utf-8', newline='\n') as f:
                f.write(t)
            paths.append(p)
        r = subprocess.run(['git', 'merge-file', '-p', '-L', 'ours', '-L', 'base', '-L', 'theirs'] + paths,
                           capture_output=True)
        if r.returncode < 0 or r.returncode > 127:
            raise RuntimeError('git merge-file failed: %s' % r.stderr.decode(errors='replace'))
        return r.stdout.decode('utf-8', errors='replace'), r.returncode


def m3(o, a, b):
    if a == b or b == o:
        return a, 0
    if a == o:
        return b, 0
    return merge_file(o, a, b)


def field_merge(o, a, b):
    """Three-way merge of one format-2 entry by field; Log lines from both sides are kept.
    Returns the merged text, or None when both sides changed the same field."""
    try:
        T = _ops()
    except Exception:
        return None
    eo, ea, eb = T.parse_entry(o) if o.strip() else None, T.parse_entry(a), T.parse_entry(b)
    if any(getattr(x, 'badhead', False) or (x is not None and x.stray and any(l.strip() for l in x.stray))
           for x in (eo, ea, eb)):
        return None
    kind = 'bug' if ea.id.startswith('BUG') else 'feature'
    fo = {n: l for n, l in eo.fields} if eo else {}
    fa, fb = {n: l for n, l in ea.fields}, {n: l for n, l in eb.fields}
    to = eo.title if eo else None
    title = ea.title if eb.title == to else eb.title if ea.title == to else ea.title if ea.title == eb.title else None
    if title is None:
        return None
    out = T.Entry(ea.id, title)
    for n in dict.fromkeys([x for x, _ in ea.fields] + [x for x, _ in eb.fields]):
        vo, va, vb = fo.get(n), fa.get(n), fb.get(n)
        if va == vb or vb == vo:
            v = va
        elif va == vo:
            v = vb
        elif n == 'Log':
            base = vo or ['']
            v = base + [l for l in (va or [])[1:] if l not in base] + [l for l in (vb or [])[1:] if l not in base and l not in (va or [])]
        else:
            return None
        if v is not None:
            out.fields.append([n, list(v)])
    T.fix_entry(out, kind)
    return out.render() + ('\n' if a.endswith('\n\n') else '')


def merge_docs(o, a, b, mode):
    """Return (text, conflicts, notes)."""
    if a == b or b == o:
        return a, 0, []
    if a == o:
        return b, 0, []
    O, A, B = parse(o, mode), parse(a, mode), parse(b, mode)
    conflicts, notes = 0, []
    pre, c = m3(O.pre, A.pre, B.pre)
    conflicts += c

    def pick3(vo, va, vb):
        if va == vb or vb == vo:
            return va, None
        if va == vo:
            return vb, None
        return None, (va, vb)

    final = {}  # key -> [h2, h3, text]
    for k in list(A.items) + [k for k in B.items if k not in A.items]:
        ia, ib, io = A.items.get(k), B.items.get(k), O.items.get(k)
        if ia and ib:
            t, clash = pick3(io[2] if io else None, ia[2], ib[2])
            loc, lclash = pick3(tuple(io[:2]) if io else None, tuple(ia[:2]), tuple(ib[:2]))
            ra, rb = rank(ia[2], ia[0]), rank(ib[2], ib[0])
            if clash:
                mt, c = merge_file(io[2] if io else '', ia[2], ib[2])
                fm = field_merge(io[2] if io else '', ia[2], ib[2]) if mode == 'tracker' and c else None
                if c == 0 and len(status_of(mt)) <= 1:
                    t = mt
                elif fm is not None:
                    t = fm
                    notes.append('%s: both sides edited; merged field by field' % k)
                elif mode == 'tracker' and ra != rb:
                    t = ia[2] if ra > rb else ib[2]
                    notes.append('%s: both sides edited; kept the %s copy (further along)' % (k, 'ours' if ra > rb else 'theirs'))
                else:
                    t = mt
                    conflicts += max(c, 1)
                    notes.append('%s: conflicting edits at the same status' % k)
            if lclash:
                loc = tuple(ia[:2]) if (mode != 'tracker' or ra >= rb) else tuple(ib[:2])
            final[k] = [loc[0], loc[1], t]
        else:
            it = ia or ib
            if io and it[2] == io[2] and tuple(it[:2]) == tuple(io[:2]):
                continue  # deleted on one side, untouched on the other
            final[k] = list(it)

    # containers: A's order, B's new ones after their predecessor
    def merge_order(la, lb, lo):
        res = list(la)
        for i, x in enumerate(lb):
            if x in res:
                continue
            if x in lo:
                continue  # deleted on the A side
            prev = next((y for y in reversed(lb[:i]) if y in res), None)
            res.insert(res.index(prev) + 1 if prev is not None else 0, x)
        return res

    def index(doc):
        secs = {s[0]: s for s in doc.secs}
        subs = {(s[0], u[0]): u for s in doc.secs for u in s[3]}
        return secs, subs

    (Asec, Asub), (Bsec, Bsub), (Osec, Osub) = index(A), index(B), index(O)
    used = {(v[0], v[1]) for v in final.values()}
    sec_order = merge_order([s[0] for s in A.secs], [s[0] for s in B.secs], set(Osec))
    for k2 in {v[0] for v in final.values()}:
        if k2 not in sec_order:
            sec_order.append(k2)
    M = Doc()
    M.pre = pre
    for k2 in sec_order:
        sa, sb, so = Asec.get(k2), Bsec.get(k2), Osec.get(k2)
        src = sa or sb or so
        line, c1 = m3(so[1] if so else '', (sa or src)[1], (sb or src)[1])
        intro, c2 = m3(so[2] if so else '', (sa or src)[2], (sb or src)[2])
        conflicts += c1 + c2
        sub_order = merge_order([u[0] for u in (sa[3] if sa else [])], [u[0] for u in (sb[3] if sb else [])],
                                {u[0] for u in (so[3] if so else [])})
        for (x2, x3) in used:
            if x2 == k2 and x3 not in sub_order:
                sub_order.append(x3)
        subs = []
        for k3 in sub_order:
            ua, ub, uo = Asub.get((k2, k3)), Bsub.get((k2, k3)), Osub.get((k2, k3))
            usrc = ua or ub or uo
            l3, c3 = m3(uo[1] if uo else '', (ua or usrc)[1], (ub or usrc)[1])
            i3, c4 = m3(uo[2] if uo else '', (ua or usrc)[2], (ub or usrc)[2])
            conflicts += c3 + c4
            keys = [k for k in (ua[3] if ua else []) if k in final and tuple(final[k][:2]) == (k2, k3)]
            keys += [k for k in (ub[3] if ub else []) if k in final and tuple(final[k][:2]) == (k2, k3) and k not in keys]
            keys += sorted(k for k, v in final.items() if tuple(v[:2]) == (k2, k3) and k not in keys)
            if not keys and uo and not (ua and ub) and i3 == uo[2]:
                continue
            subs.append([k3, l3, i3, keys])
        if not any(u[3] for u in subs) and so and not (sa and sb) and intro == so[2]:
            continue
        M.secs.append([k2, line, intro, subs])
    M.items = final
    return render(M, mode, tidy=True), conflicts, notes


def _read(p):
    with open(p, 'rb') as f:
        raw = f.read().decode('utf-8', errors='replace')
    return raw.replace('\r\n', '\n'), '\r\n' in raw


def cmd_merge(argv):
    o_p, a_p, b_p = argv[:3]
    path = argv[3] if len(argv) > 3 else a_p
    (o, _), (a, crlf), (b, _) = _read(o_p), _read(a_p), _read(b_p)
    try:
        out, c, notes = merge_docs(o, a, b, mode_of(path))
    except Exception as e:  # never break a merge: fall back to a plain text merge
        out, c = merge_file(o, a, b)
        notes = ['per-entry merge failed (%s); fell back to a text merge' % e]
        c = max(c, 1) if c else 0
    if crlf:
        out = out.replace('\n', '\r\n')
    with open(a_p, 'w', encoding='utf-8', newline='') as f:
        f.write(out)
    for n in notes:
        sys.stderr.write('tracker-merge %s: %s\n' % (path, n))
    return 1 if c else 0


def git(*args, cwd=None):
    r = subprocess.run(['git'] + list(args), capture_output=True, text=True, cwd=cwd)
    return r.stdout.strip() if r.returncode == 0 else None


def find_files(root):
    ls = git('ls-files', cwd=root)
    if ls is not None:
        files = [f for f in ls.splitlines() if os.path.basename(f) in TRACKERS and 'node_modules/' not in f]
        return [os.path.join(root, f) for f in files]
    out = []
    for dp, dn, fn in os.walk(root):
        dn[:] = [x for x in dn if not x.startswith('.') and x != 'node_modules']
        out += [os.path.join(dp, f) for f in fn if f in TRACKERS]
    return out


def lint_file(path, fix):
    mode = mode_of(path)
    text, crlf = _read(path)
    d = parse(text, mode)
    errs, warns = [], []
    fence = False
    for n, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            fence = not fence
        elif not fence and MARK.match(line):
            errs.append((n, 'MARKER', '-', 'merge conflict marker'))
    groups = {}
    for k in d.items:
        base = k.split('#')[0].split('|')[0]
        if re.match(r'(BUG|FEAT)-\d+[a-z]*$', base):
            groups.setdefault(base, []).append(k)
    drop, changed = set(), False
    for base, ks in groups.items():
        if mode == 'tracker':
            for k in ks:
                st = status_of(d.items[k][2])
                in_archive = bool(ARCHIVE.search(d.items[k][0] or ''))
                if len(st) > 1 or (not st and not in_archive):
                    errs.append((d.line[k], 'STATUS', base, '%d Status lines (expected 1)' % len(st)))
                elif len(ks) == 1:
                    r, sec = rank(d.items[k][2], None), d.items[k][0] or ''
                    if r == 4 and not ARCHIVE.search(sec):
                        warns.append((d.line[k], 'PLACE', base, 'closed status outside an archive section'))
                    elif r in (1, 2) and ARCHIVE.search(sec):
                        warns.append((d.line[k], 'PLACE', base, 'open status inside an archive section'))
        if len(ks) < 2:
            continue
        if mode == 'changelog':
            # distinct change types or releases are legitimate; same container or identical text is not
            seen, dupk = {}, []
            for k in ks:
                sig = (tuple(d.items[k][:2]), d.items[k][2].rstrip())
                if tuple(d.items[k][:2]) in {x[0] for x in seen} or sig[1] in {x[1] for x in seen}:
                    dupk.append(k)
                seen[sig] = k
            if not dupk:
                continue
        where = ', '.join('%d' % d.line[k] for k in ks)
        if not fix:
            errs.append((d.line[ks[1]], 'DUP', base, 'id appears %d times (lines %s)' % (len(ks), where)))
            continue
        texts = {d.items[k][2].rstrip() for k in ks}
        locs = {tuple(d.items[k][:2]) for k in ks}
        keep = None
        if len(texts) == 1:
            if mode == 'tracker':
                keep = max(ks, key=lambda k: rank(d.items[k][2], d.items[k][0]))
            else:  # prefer the copy already frozen in a release over an Unreleased resurrection
                rel = [k for k in ks if not re.search(r'unreleased', d.items[k][0] or '', re.I)]
                keep = (rel or ks)[0]
        elif mode == 'tracker':
            ranks = sorted(((rank(d.items[k][2], d.items[k][0]), k) for k in ks), reverse=True)
            if ranks[0][0] > ranks[1][0]:
                keep = ranks[0][1]
        if keep is None and mode == 'changelog':
            # same id twice in one change-type section (union-merge residue): keep the copy that
            # carries the bump marker, else the first; copies in other sections stay
            bycont = {}
            for k in ks:
                bycont.setdefault(tuple(d.items[k][:2]), []).append(k)
            for cks in bycont.values():
                if len(cks) < 2:
                    continue
                best = min(cks, key=lambda k: (not BUMP_MARK.search(d.items[k][2]), d.line[k]))
                drop.update(k for k in cks if k != best)
                changed = True
                warns.append((d.line[best], 'FIXED', base, 'kept line %d, removed %d duplicate(s) in its section' % (d.line[best], len(cks) - 1)))
            continue
        if keep is None:
            errs.append((d.line[ks[1]], 'AMBIGUOUS', base, 'copies differ at the same status (lines %s); resolve by hand' % where))
        else:
            drop.update(k for k in ks if k != keep)
            changed = True
            warns.append((d.line[keep], 'FIXED', base, 'kept line %d, removed %d other copies' % (d.line[keep], len(ks) - 1)))
    if changed:
        for s in d.secs:
            for u in s[3]:
                u[3] = [k for k in u[3] if k not in drop]
        out = render(d, mode)
        if crlf:
            out = out.replace('\n', '\r\n')
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(out)
    return errs, warns


def config_warnings(root):
    warns = []
    ga = os.path.join(root, '.gitattributes')
    attrs = open(ga, encoding='utf-8', errors='replace').read() if os.path.exists(ga) else ''
    if re.search(r'^(\S*/)?(bugs|features|CHANGELOG)\.md\s.*merge=union', attrs, re.M):
        warns.append(('.gitattributes', 'UNION', 'trackers still use merge=union; run /cycle-init (tracker upgrade)'))
    if 'merge=tracker' in attrs:
        drv = git('config', '--get', 'merge.tracker.driver', cwd=root)
        if not drv:
            warns.append(('.gitattributes', 'NODRIVER', 'merge driver not set in this clone; run: python .cycle/trackers.py install'))
    return warns


def cmd_lint(argv):
    fix = '--fix' in argv
    staged = '--staged' in argv
    paths = [a for a in argv if a not in ('--fix', '--staged')]
    root = git('rev-parse', '--show-toplevel') or os.getcwd()
    files = []
    if staged:
        names = (git('diff', '--cached', '--name-only', '--diff-filter=ACMR', cwd=root) or '').splitlines()
        files = [os.path.join(root, f) for f in names if os.path.basename(f) in TRACKERS]
        paths = files or ['--none--']
    else:
        for p in paths or [root]:
            files += find_files(p) if os.path.isdir(p) else [p]
    ops = _ops()
    is_strict = ops.strict(root)
    ne = nw = nf = 0
    for f in files:
        errs, warns = lint_file(f, fix)
        if is_strict and os.path.basename(f) in ops.TRACKER_FILES:
            warns = [w for w in warns if w[1] != 'PLACE']
            e2, w2 = ops.schema_lint(f, fix)
            errs, warns = errs + e2, warns + w2
        rel = os.path.relpath(f, root)
        shown = {}
        for n, code, i, msg in sorted(errs) + sorted(warns):
            shown[code] = shown.get(code, 0) + 1
            if code in ('PLACE', 'UNKNOWN', 'PENDING', 'NOEPIC') and shown[code] > 5:
                continue
            print('%s:%d: %s %s %s' % (rel, n, code, i, msg))
        for code in ('PLACE', 'UNKNOWN', 'PENDING', 'NOEPIC'):
            if shown.get(code, 0) > 5:
                print('%s: %s ... %d more' % (rel, code, shown[code] - 5))
        ne += len(errs)
        nf += sum(1 for w in warns if w[1] == 'FIXED')
        nw += len(warns) - sum(1 for w in warns if w[1] == 'FIXED')
    if not paths:
        if not is_strict and files:
            print('.cycle/tracker.json: ADOPT trackers are not format 2; run: python .cycle/trackers.py adopt')
            nw += 1
        for where, code, msg in config_warnings(root):
            print('%s: %s %s' % (where, code, msg))
            nw += 1
    print('tracker-lint: %d files, %d errors, %d warnings%s' % (len(files), ne, nw, ', %d fixed' % nf if fix else ''))
    return 1 if ne else 0


PY_SH = '"$(command -v python3 || command -v python)"'
BLOCKS = {  # managed blocks: (file, block name, template under references/templates)
    'claude': ('CLAUDE.md', 'project-cycle', 'instruction-appendix.md'),
    'readme': ('README.md', 'tracker-setup', 'readme-setup.md'),
}


def cmd_install(argv):
    """Set up this repo and clone for the trackers. Idempotent; safe to re-run.

    install            vendor .cycle/ (from the bundle), merge driver, .gitattributes,
                       pre-commit lint + commit-msg key check, Claude Code hooks, CLAUDE.md + README blocks
    install --auto     clone-only setup when missing (merge driver, local git hooks); quiet,
                       never fails. Run by the SessionStart hook and by every trackers.py command
    --no-config        skip git config and .git/hooks (repo files only)
    --no-docs          skip the CLAUDE.md / README blocks
    """
    root = git('rev-parse', '--show-toplevel')
    if '--auto' in argv:
        if root:
            try:
                _clone_setup(root, quiet=True)
            except Exception:
                pass
            _worklog_notice(root)
        return 0
    if not root:
        sys.exit('install: not inside a git repository')
    _vendor(root)
    _gitattributes(root)
    _repo_hooks(root)
    if '--no-docs' not in argv:
        for f, name, tpl in BLOCKS.values():
            _block(root, f, name, tpl)
    if '--no-config' not in argv:
        _clone_setup(root, quiet=False, force=True)
    return 0


def _vendor(root):
    here = os.path.dirname(os.path.abspath(__file__))
    cyc = os.path.join(root, '.cycle')
    os.makedirs(cyc, exist_ok=True)
    srcs = [(os.path.join(here, 'trackers.py'), os.path.join(cyc, 'trackers.py')),
            (os.path.join(here, 'tracker_ops.py'), os.path.join(cyc, 'tracker_ops.py')),
            (os.path.join(here, 'worklog.py'), os.path.join(cyc, 'worklog.py')),
            (os.path.join(here, 'worklog_time.py'), os.path.join(cyc, 'worklog_time.py')),
            (os.path.join(here, '..', 'references', 'tracker-format.md'), os.path.join(cyc, 'TRACKERS.md'))]
    for src, dest in srcs:
        if os.path.exists(src) and os.path.normcase(os.path.abspath(src)) != os.path.normcase(os.path.abspath(dest)):
            if not os.path.exists(dest) or open(src, 'rb').read() != open(dest, 'rb').read():
                shutil.copyfile(src, dest)
                print('vendored %s' % os.path.relpath(dest, root))


def _gitattributes(root):
    ga = os.path.join(root, '.gitattributes')
    attrs = open(ga, encoding='utf-8').read() if os.path.exists(ga) else ''
    new = re.sub(r'(?m)^((?:\S*/)?(?:bugs|features|CHANGELOG)\.md)[ \t]+merge=union[ \t]*$',
                 lambda m: '%-12s merge=tracker text eol=lf' % m.group(1), attrs)
    for name in TRACKERS:
        if not re.search(r'(?m)^(\S*/)?%s\s.*merge=tracker' % re.escape(name), new):
            new = new.rstrip('\n') + '\n%-12s merge=tracker text eol=lf\n' % name
    if new != attrs:
        with open(ga, 'w', encoding='utf-8', newline='\n') as f:
            f.write(new)
        print('.gitattributes: trackers use merge=tracker')


def _repo_hooks(root):
    """Committed hooks: Claude Code (block hand edits; set up the clone at session start), husky pre-commit."""
    import json
    sp = os.path.join(root, '.claude', 'settings.json')
    cfg = json.load(open(sp, encoding='utf-8')) if os.path.exists(sp) else {}
    hooks = cfg.setdefault('hooks', {})
    want = {
        'PreToolUse': ({'matcher': 'Edit|Write|MultiEdit'}, 'trackers.py" hook', ' hook'),
        'SessionStart': ({}, 'trackers.py" install --auto', ' install --auto'),
    }
    changed = []
    for event, (extra, probe, args) in want.items():
        lst = hooks.setdefault(event, [])
        if not any(probe in c.get('command', '') for h in lst for c in h.get('hooks', [])):
            cmd = PY_SH + ' "$CLAUDE_PROJECT_DIR/.cycle/trackers.py"' + args
            lst.append(dict(extra, hooks=[{'type': 'command', 'command': cmd}]))
            changed.append(event)
    if changed:
        os.makedirs(os.path.dirname(sp), exist_ok=True)
        with open(sp, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(cfg, f, indent=2)
            f.write('\n')
        print('.claude/settings.json: %s hook(s) added' % ', '.join(changed))
    if os.path.isdir(os.path.join(root, '.husky')):
        for name in GIT_HOOKS:
            _git_hook(os.path.join(root, '.husky', name), root, name)


GIT_HOOKS = {  # git hook -> (line, comment, what it does)
    'pre-commit': (PY_SH + ' .cycle/trackers.py lint --staged || exit $?',
                   'Trackers: format-2 schema and integrity (dev-cycle)', 'tracker lint'),
    'commit-msg': (PY_SH + ' .cycle/trackers.py commit-msg "$1" || exit $?',
                   'Jira key on line 1 of every work-branch commit, in Jira enforce mode (dev-cycle)', 'commit key check'),
}


def _git_hook(hp, root, name, quiet=False):
    line, comment, what = GIT_HOOKS[name]
    body = open(hp, encoding='utf-8').read() if os.path.exists(hp) else '#!/bin/sh\n'
    if line in body:
        return False
    os.makedirs(os.path.dirname(hp), exist_ok=True)
    with open(hp, 'w', encoding='utf-8', newline='\n') as f:
        f.write(body.rstrip('\n') + '\n\n# %s\n%s\n' % (comment, line))
    os.chmod(hp, 0o755)
    if not quiet:
        print('%s: %s added' % (os.path.relpath(hp, root), what))
    return True


def _driver_ok(drv):
    """True when the configured driver's interpreter still exists (only judged for this OS's path style)."""
    m = re.match(r'"([^"]+)"', drv or '')
    if not m:
        return bool(drv)
    exe = m.group(1)
    if (os.name == 'nt') != bool(re.match(r'^[A-Za-z]:[\\/]', exe)):
        return True  # another OS's clone config (WSL vs Windows): leave it alone
    return os.path.exists(exe)


def _clone_setup(root, quiet, force=False):
    """Per-clone state git never commits: the merge driver and, without husky, the local git hooks."""
    if os.environ.get('CYCLE_NO_AUTOSETUP') and not force:
        return
    done = []
    dest = os.path.join(root, '.cycle', 'trackers.py')
    cur = git('config', '--get', 'merge.tracker.driver', cwd=root)
    if force or not _driver_ok(cur):
        drv = '"%s" "%s" merge %%O %%A %%B %%P' % (sys.executable.replace('\\', '/'), dest.replace('\\', '/'))
        if drv != cur:
            git('config', 'merge.tracker.name', 'cycle tracker per-entry merge', cwd=root)
            git('config', 'merge.tracker.driver', drv, cwd=root)
            done.append('merge driver')
            if not quiet:
                print('merge.tracker.driver = %s' % drv)
    if not os.path.isdir(os.path.join(root, '.husky')):
        hd = git('rev-parse', '--git-path', 'hooks', cwd=root) or os.path.join('.git', 'hooks')
        hd = hd if os.path.isabs(hd) else os.path.join(root, hd)
        for name in GIT_HOOKS:
            if _git_hook(os.path.join(hd, name), root, name, quiet):
                done.append(GIT_HOOKS[name][2])
    if done and quiet:
        sys.stderr.write('trackers: set up this clone (%s)\n' % ', '.join(done))


def _block(root, fname, name, tpl):
    """Insert or refresh a managed block from references/templates/<tpl> (bundle runs only)."""
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'references', 'templates', tpl)
    if not os.path.exists(src):
        return  # vendored copy: the block is already committed
    begin, end = '<!-- cycle:%s begin (written by trackers.py install) -->' % name, '<!-- cycle:%s end -->' % name
    body = open(src, encoding='utf-8').read().strip()
    block = '%s\n%s\n%s' % (begin, body, end)
    p = os.path.join(root, fname)
    text = open(p, encoding='utf-8', newline='').read() if os.path.exists(p) else ''
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    pat = re.compile(r'<!-- cycle:%s begin[^>]*-->.*?<!-- cycle:%s end -->' % (name, name), re.S)
    if pat.search(text):
        new = pat.sub(lambda m: block, text, count=1)
    else:
        head = body.splitlines()[0]
        old = None
        if head.startswith('#'):  # an unmarked earlier copy of the same section: replace it
            lvl = len(head) - len(head.lstrip('#'))
            key = re.escape(head.split('(')[0].strip())
            old = re.search(r'(?ms)^%s[^\n]*\n.*?(?=^#{1,%d} |\Z)' % (key, lvl), text)
        if old:
            keep = _specifics(old.group(0), body)
            tail = '\n'.join(keep).strip('\n')
            new = text[:old.start()] + block + '\n\n' + (tail + '\n\n' if tail else '') + text[old.end():].lstrip('\n')
        elif fname == 'README.md':
            new = _readme_insert(text, block)
        else:
            new = text.rstrip('\n') + ('\n\n' if text.strip() else '') + block + '\n'
    if new != text:
        if crlf:
            new = new.replace('\n', '\r\n')
        with open(p, 'w', encoding='utf-8', newline='') as f:
            f.write(new)
        print('%s: %s block written' % (fname, name))


def _units(text):
    """Split markdown into units: a bullet with its indented continuation, a paragraph, a heading."""
    units, cur = [], []
    for ln in text.split('\n'):
        starts = re.match(r'^(#|[-*] |> |\d+\. )', ln) or not ln.strip()
        if starts and cur:
            units.append(cur)
            cur = []
        if ln.strip():
            cur.append(ln)
        elif units and units[-1] != ['']:
            units.append([''])
    if cur:
        units.append(cur)
    return units


def _specifics(old, body):
    """Lines of an unmarked earlier section to keep: everything that is not its heading or a
    superseded copy of a template bullet (similarity >= 0.55). Project rules survive below the block."""
    import difflib
    norm = lambda u: re.sub(r'\s+', ' ', ' '.join(u)).strip().lower()
    tpl = [norm(u) for u in _units(body) if u != ['']]
    keep = []
    for u in _units(old)[1:]:
        if u == ['']:
            if keep and keep[-1] != '':
                keep.append('')
            continue
        t = norm(u)
        if any(difflib.SequenceMatcher(None, t, x).ratio() >= 0.55 for x in tpl):
            continue
        keep.extend(u)
    return keep


def _readme_insert(text, block):
    """Top of the Quick start / Getting started / Setup section; else before Contributing/License; else the end."""
    m = re.search(r'(?mi)^##+ .*(quick ?start|getting started|setup|installation).*\n', text)
    if m:
        return text[:m.end()] + '\n' + block + '\n' + text[m.end():]
    m = re.search(r'(?mi)^## .*(contributing|license)', text)
    sec = '## Setup\n\n' + block + '\n\n'
    if m:
        return text[:m.start()] + sec + text[m.start():]
    return text.rstrip('\n') + '\n\n' + sec.rstrip('\n') + '\n'


def _ops():
    sys.dont_write_bytecode = True
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import tracker_ops
    return tracker_ops


def _utf8_io():
    """Tracker text has non-ASCII (≤, →, —). A Windows console or pipe on cp1252 would raise
    UnicodeEncodeError: write UTF-8 when not a real console, and never fail on a character."""
    for s in (sys.stdout, sys.stderr):
        try:
            if (s.encoding or '').lower().replace('-', '') != 'utf8':
                s.reconfigure(encoding=s.encoding if s.isatty() else 'utf-8', errors='replace')
        except (AttributeError, ValueError, OSError):
            pass


def main(argv):
    _utf8_io()
    cmds = {'merge': cmd_merge, 'lint': cmd_lint, 'install': cmd_install}
    if argv and argv[0] not in cmds:
        cmds.update(_ops().COMMANDS)
    if not argv or argv[0] not in cmds:
        sys.exit(__doc__)
    if argv[:2] == ['worklog', 'hook']:  # Claude Code activity hook: no setup, no extra git calls
        return _ops().COMMANDS['worklog'](argv[1:])
    if argv[0] not in ('merge', 'install', 'hook', 'commit-msg'):
        root = git('rev-parse', '--show-toplevel')
        if root and os.path.exists(os.path.join(root, '.cycle', 'trackers.py')):
            try:
                _clone_setup(root, quiet=True)
            except Exception:
                pass
    if argv[0] not in ('merge', 'install', 'hook', 'worklog'):
        _worklog_beat()
    return cmds[argv[0]](argv[1:])


def _worklog_notice(root):
    """Session start: name unposted follow-up worklog time so Claude raises it (worklog.py)."""
    common = git('rev-parse', '--git-common-dir', cwd=root)
    if common and os.path.exists(os.path.join(root, common, 'cycle-worklog.json')):
        try:
            _ops()
            import worklog
            worklog.cmd_notice(root, {}, [])
        except Exception:
            pass


def _worklog_beat():
    """An open opt-in worklog session counts this command as activity (worklog.py)."""
    common = git('rev-parse', '--git-common-dir')
    if common and os.path.exists(os.path.join(common, 'cycle-worklog.json')):
        try:
            _ops()
            import worklog
            worklog.beat(None)
        except Exception:
            pass


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
