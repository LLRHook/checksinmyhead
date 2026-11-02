"""Time math for dev-cycle worklogs (stdlib only, no I/O except reading a transcript file).

Pure functions so the rules are testable on their own: busy spans from activity lines, active
time with an idle cap, posting windows, the even split between concurrent runs, and the
activity a Claude Code transcript shows (tool calls, background tasks, detached containers).
Times are UNIX epoch seconds; a segment is (begin, end) with begin < end.
"""
import datetime, json, re

BG_CAP_S = 4 * 3600   # a background task with no end signal counts at most this long
BG_ID_RES = (re.compile(r'running in (?:the )?background with ID:\s*([\w.-]+)', re.I),
             re.compile(r'moved to the background \(ID:\s*([\w.-]+)\)', re.I),
             re.compile(r'background (?:task|shell) (?:ID|id):?\s*([\w.-]+)'))
NOTIFY_RE = re.compile(r'<task-notification>.*?<task-id>\s*([\w.-]+)\s*</task-id>', re.S)
DOCKER_DETACHED_RE = re.compile(r'\bdocker(?:\s+compose)?\s+(?:container\s+)?(?:run|up|start)\b[^|;&]*\s(?:-d|--detach)\b')
CONTAINER_ID_RE = re.compile(r'\b([0-9a-f]{64}|[0-9a-f]{12})\b')


# ------------------------------------------------------------------ segments

def merge(segs):
    """Union of segments, sorted and non-overlapping."""
    out = []
    for x, y in sorted(segs):
        if y <= x:
            continue
        if out and x <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], y))
        else:
            out.append((x, y))
    return out


def total(segs):
    return sum(y - x for x, y in segs)


def covers(segs, x, y):
    return any(a <= x and y <= b for a, b in segs)


def clip(segs, a, b):
    return [(max(x, a), min(y, b)) for x, y in segs if y > a and x < b]


# ------------------------------------------------------------------ activity lines

def spans(events, now, extra=()):
    """Busy spans from activity lines (t, kind, key, branch), plus EXTRA spans (from transcripts).

    Tool and sub-agent spans: B .. E. A tool span left open (interrupted call) ends at the next
    Stop or prompt (C tool); a sub-agent span at its SubagentStop or the session end (C all).
    Background spans (bg:*): B at launch .. the last X (a write of its output file); with no X,
    until the next prompt (P), at most BG_CAP_S."""
    open_, out, bg, prompts = {}, [], {}, []
    for t, kind, key, _ in sorted(events):
        if kind == 'P':
            prompts.append(t)
        if key.startswith('bg:'):
            if kind == 'B':
                bg.setdefault(key, [t, None])
            elif kind == 'X' and key in bg:
                bg[key][1] = max(bg[key][1] or t, t)
            continue
        if kind == 'B':
            open_.setdefault(key, t)
        elif kind == 'E' and key in open_:
            out.append((open_.pop(key), t))
        elif kind == 'C':
            for k in [k for k in open_ if key == 'all' or k.startswith(key + ':')]:
                out.append((open_.pop(k), t))
    out += [(b, now) for b in open_.values()]
    for b, e in bg.values():
        out.append((b, min(e if e else unended_end(b, prompts, now), now)))
    return out + list(extra)


def unended_end(begin, prompts, now):
    """End of a background span with no end signal (reaped shell, lost notification): the next
    prompt after it, bounded by BG_CAP_S."""
    nxt = next((p for p in sorted(prompts) if p > begin), None)
    return min(nxt if nxt else now, begin + BG_CAP_S)


def active_segments(intervals, marks, idle_s, now, busy=()):
    """(active segments, elapsed, dropped) within INTERVALS (pauses excluded).

    Active = union of (a) gaps between activity marks no longer than IDLE_S and (b) busy spans,
    which count in full however long they run. dropped = idle gaps not covered by a busy span.
    O(n log n) in marks and spans."""
    out, elapsed, dropped = [], 0, 0
    for a, b in intervals:
        b = now if b is None else b
        if b <= a:
            continue
        elapsed += b - a
        segs = clip(busy, a, b)
        busy_here = merge(segs)
        pts = sorted({a, b} | {m for m in marks if a < m < b} | {p for seg in segs for p in seg})
        for x, y in zip(pts, pts[1:]):
            if y - x <= idle_s:
                segs.append((x, y))
            elif not covers(busy_here, x, y):
                dropped += 1
        out += merge(segs)
    return merge(out), elapsed, dropped


# ------------------------------------------------------------------ windows and sharing

def windows(segs, gap_s, tz=None):
    """Split active segments into posting windows: a new window wherever activity stops for more
    than GAP_S or the local date changes. [(start, end, [segments])]."""
    out = []
    for x, y in merge(segs):
        for a, b in _by_day(x, y, tz):
            if out and a - out[-1][1] <= gap_s and _day(a, tz) == _day(out[-1][0], tz):
                out[-1] = (out[-1][0], b, out[-1][2] + [(a, b)])
            else:
                out.append((a, b, [(a, b)]))
    return out


def _day(t, tz):
    return datetime.datetime.fromtimestamp(t, tz).date()


def _by_day(x, y, tz):
    parts, a = [], x
    while _day(a, tz) != _day(y - 1, tz):
        d = datetime.datetime.fromtimestamp(a, tz)
        nxt = int((d.replace(hour=0, minute=0, second=0, microsecond=0) + datetime.timedelta(days=1)).timestamp())
        parts.append((a, nxt))
        a = nxt
    parts.append((a, y))
    return [(p, q) for p, q in parts if q > p]


def share(own, others):
    """(seconds, shared_by): OWN active time, each piece shared with N other runs counted 1/(N+1)
    (an even split, the same whichever run finishes first). O(b * r), b boundaries, r runs."""
    pts = sorted({p for seg in own for p in seg} | {p for _, segs in others for seg in segs for p in seg})
    got, by = 0.0, {}
    for x, y in zip(pts, pts[1:]):
        if not covers(own, x, y):
            continue
        with_ = [name for name, segs in others if covers(segs, x, y)]
        got += (y - x) / (len(with_) + 1.0)
        for name in with_:
            by[name] = by.get(name, 0) + (y - x)
    return got, by


def scale_minutes(parts, target_min):
    """Distribute TARGET_MIN whole minutes over PARTS (weights) by largest remainder."""
    tot = float(sum(parts)) or 1.0
    raw = [p / tot * target_min for p in parts]
    mins = [int(r) for r in raw]
    for i in sorted(range(len(raw)), key=lambda i: raw[i] - mins[i], reverse=True)[:target_min - sum(mins)]:
        mins[i] += 1
    return mins


# ------------------------------------------------------------------ Claude Code transcripts

def iso(text):
    """Epoch from an ISO 8601 timestamp (Z or offset), else None."""
    if not text or not isinstance(text, str):
        return None
    try:
        return int(datetime.datetime.fromisoformat(text.replace('Z', '+00:00')).timestamp())
    except ValueError:
        return None


def _text(content):
    if isinstance(content, str):
        return content
    try:
        return json.dumps(content)
    except (TypeError, ValueError):
        return str(content)


def _is_prompt(items):
    """A line the person typed (not a tool result, not a background-task notification)."""
    for it in items:
        if isinstance(it, dict) and it.get('type') == 'tool_result':
            return False
        if '<task-notification>' in _text(it):
            return False
    return bool(items)


def parse_transcript(lines, branch=None):
    """Activity in a Claude Code transcript (JSONL lines): {'marks', 'tools', 'background',
    'containers', 'prompts'}. Tool spans pair each tool_use with its tool_result; background spans run
    from the result that says the task went to the background to its <task-notification> (or a
    TaskStop/KillShell naming it); detached containers are [(launch, container id)] for the caller
    to resolve. Lines whose gitBranch differs from BRANCH are skipped when BRANCH is given."""
    marks, tools, containers, prompts = [], [], [], []
    use_at, bg_at, bg_end, docker_use = {}, {}, {}, {}
    for line in lines:
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if not isinstance(obj, dict):
            continue
        t = iso(obj.get('timestamp'))
        if t is None:
            continue
        if branch and obj.get('gitBranch') and obj.get('gitBranch') != branch:
            continue
        marks.append(t)
        msg = obj.get('message') if isinstance(obj.get('message'), dict) else {}
        content = msg.get('content')
        items = content if isinstance(content, list) else [content] if content else []
        if obj.get('type') == 'user' and _is_prompt(items):
            prompts.append(t)
        for it in items:
            if isinstance(it, str):
                for tid in NOTIFY_RE.findall(it):
                    bg_end.setdefault(tid, t)
                continue
            if not isinstance(it, dict):
                continue
            kind = it.get('type')
            if kind == 'tool_use':
                use_at[it.get('id')] = t
                inp = it.get('input') or {}
                cmd = inp.get('command') if isinstance(inp, dict) else None
                if isinstance(cmd, str) and DOCKER_DETACHED_RE.search(cmd):
                    docker_use[it.get('id')] = t
                if it.get('name') in ('TaskStop', 'KillShell', 'KillBash') and isinstance(inp, dict):
                    for k in ('task_id', 'shell_id', 'bash_id', 'id'):
                        if inp.get(k):
                            bg_end.setdefault(str(inp[k]), t)
            elif kind == 'tool_result':
                uid = it.get('tool_use_id')
                if uid in use_at:
                    tools.append((use_at.pop(uid), t))
                body = _text(it.get('content'))
                for rx in BG_ID_RES:
                    for tid in rx.findall(body):
                        bg_at.setdefault(tid, t)
                if uid in docker_use:
                    m = CONTAINER_ID_RE.search(body)
                    if m:
                        containers.append((docker_use.pop(uid), m.group(1)))
            elif kind == 'text' and isinstance(it.get('text'), str):
                for tid in NOTIFY_RE.findall(it['text']):
                    bg_end.setdefault(tid, t)
    prompts.sort()
    last = max(marks) if marks else 0
    background = []
    for tid, b in bg_at.items():
        e = bg_end.get(tid)
        background.append((b, e if e and e > b else unended_end(b, prompts, max(last, b))))
    return {'marks': marks, 'tools': tools, 'background': background, 'containers': containers, 'prompts': prompts}
