# Trackers: format and commands

`bugs.md` and `features.md` hold **active work only**. Write them with
`python .cycle/trackers.py`; hand edits are blocked by the Claude Code hook and the
pre-commit lint. `CHANGELOG.md` is the ledger of shipped work and
`trackers.py show <id>` recovers any removed entry from git history. Jira is used
in the mode the project chose at its first `/protocol-v-and-v` run (Jira modes, below).

**Setup, once per clone:** `python .cycle/trackers.py install` (PowerShell:
`python .cycle\trackers.py install`). It sets the merge driver and the pre-commit lint, which
git never commits. Claude Code sessions (SessionStart hook) and every other `trackers.py`
command run it automatically when it is missing; `lint` warns `NODRIVER` until it has run.

## Entry shape

```
### [BUG-1792636958] Short title
- [ ] **Severity:** crit | high | med | low
- **Area:** comma-separated tags
- **Field:** single-line value
- **Field:**
  multi-line values continue on lines indented two spaces
  ```lang
  fenced blocks are indented two spaces too
  ```
```

- One `## Open` section per file; entries separated by one blank line.
- Exactly the first field carries the checkbox; it is `[x]` only at `*-pending-migration`.
- Fields appear in this order. `?` marks optional; every other field is required.

| bugs.md | features.md |
|---|---|
| Severity, Area, File(s), Observation, Expected, Req, Depends on, Repro / Notes, Bump, Jira¹, Jira parent?, Bundle?, Assignee?, Status, Fix?, Docs?, Cross-ref?, Log? | Priority, Area, File(s), Req, Depends on, UI, Why, Approach, Library / dependency notes, Acceptance criteria, Test plan, Out of scope, Bump, Jira¹, Jira parent?, Bundle?, Assignee?, Status, Implementation?, Docs?, Cross-ref?, Log? |

¹ Required in `enforce` mode, optional otherwise.

| Field | Allowed values |
|---|---|
| Severity / Priority | `crit`, `high`, `med`, `low` |
| Bump | `major`, `minor`, `patch` (bug default `patch`, feature default `minor`) |
| Status | `open`, `in-progress`, `fixed-pending-migration` (bugs) / `shipped-pending-migration` (features) |
| Jira | one issue key (`PROJ-123`) or `pending`; required only in `enforce` mode |
| Jira parent | the epic's key (pick from `trackers.py jira epics`); sets the issue's parent in Jira |
| Bundle | the bundle Task's key; written only by `trackers.py bundle` ("Bundles") |
| Assignee | who is building it: written by `set <ID> Status in-progress` (the Jira issue's assignee with Jira on, else `git config user.name`); `set <ID> Assignee me` takes it over |
| Req, Depends on | ids, or `none` with the source; `unknown` only on pre-schema entries |
| Log | bullets `  - YYYY-MM-DD <label>: <text>`: sightings, decisions, audit notes |

Any other field name is an error: put that content in `Log`.

## Ids and cross-app work

- New ids are epoch seconds (`BUG-$(date +%s)`); `add` mints them. Never reuse an id.
- A cross-app item is filed in each app's tracker under the **same id** (`add --id`).
  Each app's slice gets **its own Jira issue**; its External ID is `<app>:<id>`.

## Lifecycle

| Step | Command |
|---|---|
| File | `trackers.py add --tracker apps/<app>/bugs.md --json entry.json` (with Jira on, creates the issue and fills `Jira:`) |
| Start | `trackers.py set <ID> Status in-progress` (moves the issue to In Progress; assigns it, and its bundle Task, to the Jira token's user when unassigned, and writes `Assignee`; an issue a teammate holds stays theirs: `set <ID> Assignee me` takes it) |
| Finish | `set <ID> Status fixed-pending-migration` (or `shipped-…`; moves the issue to the review status, if any), then `set <ID> Fix "<summary>"` (`Implementation` for features) and `set <ID> Docs "<files or none>"` |
| Migrate (protocol only, after a green run) | `trackers.py migrate <ID>` or `migrate --all`: appends `- [ID] KEY Title (Req: …) [bump]` to `CHANGELOG.md / Unreleased / Fixed\|Added` (`--section Changed` etc.) and removes the entry; moves the issue to Done (QA gate: "Jira workflow") |
| Close without shipping | `trackers.py close <ID> --reason duplicate\|wontfix\|superseded\|cannot-reproduce\|not-a-defect` (Done, with the matching resolution) |
| Note | `trackers.py log <ID> "<text>" [--label Sighting]` |

In `enforce` mode, `migrate` and `close` refuse an entry whose `Jira:` is `pending`: run `jira sync` first.

## Commands

| Command | Does |
|---|---|
| `add --tracker P (--json F\|- \| --field "Name=value"…) [--id ID] [--no-jira] [--dry-run]` | validate, append to `## Open`, create the Jira issue |
| `set ID FIELD VALUE\|-\|--file F [--app A] [--no-jira]` | replace one field (or `title`); `-` reads stdin; a `Status` change moves the issue; `in-progress` assigns it (Lifecycle) |
| `log ID TEXT [--label L] [--date D]` | append a Log bullet |
| `migrate ID… \| --all [--section S] [--skip-gate] [--no-jira]` | ledger line + removal + Done; entries waiting on the QA gate stay |
| `close ID --reason R [--force] [--no-jira]` | removal without a ledger line; Done with a resolution |
| `show ID [--app A]` | current entry, or the last version in git history |
| `branch ID [ID…] [--type feature\|bugfix\|hotfix\|bundle] [--slug S] [--max N]` | the branch name for these tickets |
| `worklog state\|mode\|start\|pause\|resume\|retarget\|finish\|log\|backfill\|drop\|undo\|sync\|status` | opt-in Jira worklogs ("Worklogs") |
| `bundle create ID ID… --summary S [--dry-run]` | Jira Task for a batch: creates it, links it to each member, writes `Bundle:`, prints the branch |
| `bundle add BKEY ID…` / `bundle remove ID…` | join or leave a bundle (link and `Bundle:` field) |
| `bundle sync BKEY` | move the bundle level with its members (retries) |
| `commit-msg FILE` | the git commit-msg hook ("Branches and commits") |
| `export [--status open\|todo\|in-progress\|pending\|all] [--type bug\|feature] [--app A] [--area T] [--ids I,J] [--no-key] [-o F]` | entries to a Markdown file for review |
| `jira push FILE [--dry-run]` | create issues for an export file's entries; keys go back into the trackers and the file |
| `jira sync [--app A] [--dry-run] [--limit N]` | create or link issues for every entry with `Jira: pending` |
| `jira doctor [--write]` | check credentials, create screens, statuses and permissions; `--write` saves the field map and `jira.workflow` |
| `jira status [--apply] [--app A]` | pending entries against the board: ready, waiting (QA), rejected; `--apply` sets rejected ones back to `in-progress` |
| `jira done [--dry-run]` | move every issue on a CHANGELOG ledger line that is not Done to Done (catch-up, retries) |
| `jira release VERSION [--dry-run]` | set fix version VERSION on the issues of that CHANGELOG section |
| `jira epics` | list the project's open epics (key, name) |
| `jira parents [--dry-run] [--force]` | reconcile epics: set Jira's from `Jira parent` (or a rule) where Jira has none; take Jira's into the entry where the entry names none or a non-epic |
| `lint [--fix] [--staged]` | schema + integrity; `--fix` applies order, checkbox and indent repairs |
| `adopt [--dry-run] [--report F]` | one-time upgrade of legacy trackers to this format |
| `install [--auto] [--no-config] [--no-docs]` | vendor to `.cycle/`; `.gitattributes`; Claude hooks (block hand edits, set up the clone at session start); git hooks (pre-commit lint, commit-msg key check); merge driver; `CLAUDE.md` and `README.md` setup blocks. `--auto`: clone setup only, quiet |

`--app` picks one tracker when a cross-app id is filed in several. Before any
issue is created, `jira push` and `jira sync` look the External ID up in Jira, so
re-running them links issues that already exist instead of making duplicates.

## Jira modes

Chosen when `/cycle-init` sets the project up (or upgrades it) and stored in
`.cycle/tracker.json`. Change it later with `/cycle-init jira enforce|optional|off`, which
runs `trackers.py jira configure`.

| Mode | `tracker.json` | `add` | `Jira:` field | `migrate` / `close` |
|---|---|---|---|---|
| `enforce` | `jira` block, `"enforce": true` | creates the issue; `pending` when offline | required; lint warns `PENDING` | refuse `pending` |
| `optional` | `jira` block, `"enforce": false` | creates the issue when credentials are set | optional | no Jira check |
| `off` | no `jira` block | no Jira call | optional | no Jira check |

`jira push`, `jira sync` and `jira doctor` work in `enforce` and `optional`.

## Field map

Required custom fields on the project's create screen (Steps to Reproduce, Components,
Acceptance Criteria, …) are filled from tracker fields through `jira.fields.map`, per
issue kind. `jira doctor` reads the project's create screen, lists every required field
and suggests a source; `jira doctor --write` saves the suggestions.

```json
"fields": {
  "externalId": "customfield_10247",
  "map": {
    "bug":     {"customfield_10251": "Repro / Notes",
                "customfield_10246": {"from": "@areas", "valueMap": {"frontend": "ui"}, "default": "tooling"}},
    "feature": {"customfield_10248": "Acceptance criteria", "customfield_10249": "Test plan",
                "customfield_10246": {"from": "@areas", "default": "tooling"}}
  }
}
```

Sources: a tracker field name, `@areas` (Area tags, also split on `/`), `@title`, `@id`,
`@app`, `@external`, or `=literal`. Values are shaped by the field's type (text,
single or multi select, labels, number). Select options are matched case-insensitively;
`valueMap` renames tags first; `default` fills a field when nothing matches. A mapped
tracker field is left out of the description. `jira sync --dry-run` (with credentials)
lists each entry that would still miss a required field.

## Epics

Every issue goes under an epic: the entry's `Jira parent`. Whoever files the entry picks
the epic from `trackers.py jira epics` by what each epic covers, and asks the user when
none clearly fits. Optional fallbacks in `.cycle/tracker.json`, first match wins:

```json
"epics": {
  "required": true,
  "rules": [{"match": {"app": "tlm"}, "epic": "KED-211"},
            {"match": {"area": "perf"}, "epic": "KED-221"},
            {"match": {"req": "SCORE-FR"}, "epic": "KED-623"}],
  "default": null,
  "field": "parent"
}
```

`match` keys: `app`, `area`, `req` (id prefix), `title` (regex), `kind` (`bug`/`feature`).
`required` makes lint warn `NOEPIC`. `field` is `parent` on Jira Cloud; on Data Center
use the Epic Link field id. Only open epics of the project count: a bundle, story or
tracker id in `Jira parent` is ignored. `jira sync --dry-run` shows each entry's epic;
`jira parents` reconciles existing issues (a differing epic on both sides is kept unless
`--force`, which makes the tracker win).

## Branches and commits

- Branch: `python .cycle/trackers.py branch <ID> [<ID>...] [--type hotfix|bundle] [--slug "<summary>"]`
  prints `feature/<KEY>-<summary>` (features), `bugfix/<KEY>-<summary>` (bugs),
  `hotfix/<KEY>-<summary>` (`/hotfix`) or `bundle/<KEY>-<summary>` (the bundle's key). `<KEY>` is
  the issue key in this project's own Jira (`ARC-42`, `LUM-7`), else the tracker id until the
  issue exists (then `git branch -m`); lowercase ASCII words, at most 60 characters (Bitbucket
  Data Center allows 89 for a branch name; Cloud documents no limit).
- Commit: line 1 is the branch's key, alone; line 2 blank; then the message,
  `<title> (<tracker id>)` plus any body. A commit for a ticket other than the branch's
  (a bundle member, a second ticket on one branch) starts the message with that ticket's key:

  ```
  ARC-310

  ARC-301 Reject expired invite tokens (BUG-1792636958)
  ```

  `git commit -m ARC-310 -m "ARC-301 Reject expired invite tokens (BUG-1792636958)"`.
  Jira links a commit to every key in its message, so it shows on both issues. With Jira
  off (no keys), the message alone.
- Enforced in `enforce` mode by the `commit-msg` hook (`install` adds it to every clone).
  Exempt: `main`, `master`, `trunk`, `release/*`, the remote's default branch
  (`jira.commits.exempt` replaces the list), detached HEAD, merges, `fixup!`/`squash!`/
  `amend!` and `Revert "` commits. A branch with no key, or still named for a tracker id, is
  refused. Never bypass it with `--no-verify`.
- Fix up an earlier commit by its SHA, not its subject (every subject on a branch is the
  same key): `git commit -m "fixup! <full sha>"`, then before pushing
  `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash <base>`.
- A PR title lists every key. Jira links commits, branches and PRs to issues only by key.

## Bundles

A batch (`/implement-batch`) is one Jira **bundle**: a Task (label `cycle-bundle`;
`jira.issueTypes.bundle`) that is linked `implements` to each member, so each member shows
"is implemented by <bundle>". Jira modes `enforce` and `optional`, with credentials.

- `bundle create <IDs> --summary "<summary>"` at plan approval (members without an issue get
  one first); the branch is `bundle/<KEY>-<summary>`. Required Task fields with no tracker
  source take literals: `jira.fields.map.bundle {"<field id>": "=<value>"}`.
- The bundle moves with its members: `set … Status` moves it to the least-advanced member's
  status; `migrate` gates each member on the **bundle's** status (QA moves only the bundle)
  and moves the bundle to Done once no member is left; `close` of the last member does too.
- `bundle remove <ID>` takes a ticket out (link and field). `jira doctor --write` checks the
  Task type and the link type (`jira.bundles.link`, default `Implements`) and saves them.

## Jira workflow

Status changes move the issue (Jira modes `enforce` and `optional`, with credentials; never
backwards, one transition at a time). Board setup and the Bitbucket rule for staging:
the bundle's `docs/jira-workflow.md`.

| Tracker | Jira (`jira.workflow`) |
|---|---|
| `set … Status in-progress` | `inProgress` (default: first In Progress-category status) |
| `set … Status *-pending-migration` | `review`, if set |
| `migrate` | `done` (default: the Done-category status). With `gate` set, only entries whose issue (a bundle member: the bundle) is in a `gate` status migrate; the others are reported "waiting on QA" |
| `close` | `done`, resolution from `resolutions` (`duplicate` → Duplicate, `wontfix` → Won't Do, …) |

```json
"workflow": {"inProgress": "IN PROGRESS", "review": "CODE REVIEW", "gate": ["AWAITING MIGRATION"],
             "done": "DONE", "order": ["TODO", "IN PROGRESS", "CODE REVIEW", "QA (STAGING)", "AWAITING MIGRATION", "DONE"]}
```

- Statuses the project does not have are skipped: no `review` status, no review move; no
  `gate` status, no gate. Leave them out for a small board.
- An issue moved back before `review` (or to To Do) means review or QA sent it back:
  `migrate` and `jira status --apply` set the entry back to `in-progress` and log it.
- A configured gate needs credentials: without them `migrate` refuses (`--skip-gate` overrides).
  An entry whose id is already in the CHANGELOG (a hotfix) skips the gate.
- A Jira error never undoes a migrate: the ledger line stays, and `jira done` retries.

## Worklogs

Opt-in per person: nothing is tracked or posted unless the person whose time it is chose it.
The repo can only turn worklogs off (`"jira": {"worklog": "off"}`), never on for anyone. Needs
Jira on and time tracking on the site (`jira doctor` reports it). Used by `/implement`,
`/implement-batch`, `/hotfix` and `/spec` (REVISION, ADOPT); `auto` also covers plain requests.

| When | Do |
|---|---|
| Start of the run, before other work | `worklog state`. It lists any `unposted` time: post it first (`worklog finish <label>`, posting rules below) |
| `off`, `never` | nothing; do not ask |
| `unavailable` (credentials not loaded) | say so in one line, then as for the saved mode (`ask` or `auto`): tracking is local; posting waits for the credentials |
| `ask` | ask once: "Log this run's time to Jira? 1) yes, this run 2) no 3) always for me in this repo 4) never for me in this repo". 1 → `worklog start run --consent run`; 3 → `worklog mode auto`, then `start run --consent auto`; 4 → `worklog mode never`. No answer (unattended run) → nothing |
| `auto` | `worklog start run --consent auto`; say so in one line |
| Ticket known | `worklog retarget run <ID>`; use `<ID>` from then on (`run` stays an alias). A batch: `retarget run <bundle KEY>` (one worklog on the bundle Task); `/spec`: the branch's key, none → `drop run` and say so |
| Waiting on the person (approval gate, question) | `worklog pause <label>` before asking, `resume <label>` on the answer |
| Work committed, pushed or rebased | `worklog finish <label>` prints the entry (batch: `--comment-file -` with the report's summary line). Work that leaves no git trace: `--force` |
| After `finish` posts | a follow-up session opens on its own (same ticket, branch and consent): push, PR, CI fixes, rebases, builds. A later run on the ticket joins it; its `finish` needs activity, not a commit |
| Run ends without any of that | `worklog drop <label>` |

`auto` also tracks work outside these commands: activity on a branch named for a Jira key with
no session open starts an implicit session for that key, finished like a follow-up. Unposted
follow-up and implicit time, and runs left open, are named at the next session start.

Posting:
- `run` consent, or `auto` with preview on (default): show the entry; on the person's go,
  `finish <label> --yes` (posts exactly what the preview showed, within 2 h; `--minutes N`
  when they edit the duration, `--started ISO` to post one block at a given time).
- `auto` with preview off (`worklog mode auto --preview off`): `finish <label> --yes` at once;
  report the posted line and `worklog undo <label>`. Unposted time also posts at session end.
- **Over 8 hours** (`OVER 8 HOURS`, exit 3): always ask the person, in every mode; post only
  after they confirm, with `--yes --confirm-long` (plus `--minutes N` if edited). Never pass
  `--confirm-long` without that answer.
- **Overlap with the person's other Jira worklogs** (`OVERLAPS your worklog …`, exit 3; any
  issue, machine or hand entry; checked on the blocks exactly as they will post, edits
  included): same rule, with `--confirm-overlap`. Not checkable → not posted, session kept.
- One worklog **per active window**: a quiet stretch over twice the idle cap, or a new day,
  starts a new block with its own start time. `undo` removes every block of that post.
- Runs of the same person that overlap in time (two repos, two worktrees, on this machine)
  split each shared active minute evenly, whichever finishes first; the entry lists
  `shared … with …`. Registry: `~/.claude/cycle-worklog-registry.json` (personal).
- **Cross-app id** (one id filed in several apps' trackers): every slice gets time, weighted by
  the share of changed files under its app folder (files elsewhere split evenly); `--app A` or
  `--tracker P` puts it all on one slice. Also accepted by `pause`, `resume`, `retarget`, `drop`.

After the fact: `worklog log <KEY> --started ISO --minutes N [--comment-file F]` (same checks,
marker and split; `--exact` skips the split); `worklog backfill <KEY> --transcript <session.jsonl>
[--since ISO] [--until ISO]` rebuilds untracked time from a Claude Code transcript;
`worklog sync` refreshes this clone's record of posted worklogs from Jira (edits, deletions).

Measured: active time only. Pauses are excluded. Time while a tool call or sub-agent runs
always counts; so does a background task (`run_in_background`, from launch to its completion
notification, or its output file's last write; with neither, to the next prompt, at most 4 h)
and a detached container the session started (`docker run -d`, until it exits). Between those,
activity (tool calls, `trackers.py` commands, commits, changed-file times) splits the time,
and a quiet gap longer than the idle cap (30 min; `worklog mode <mode> --idle MIN`) is
dropped. Follow-up and implicit sessions count only activity on their branch. The hooks that
see tool calls, sub-agents and transcripts are added by `start` / `mode auto` to this person's
`.claude/settings.local.json` (kept out of git; `mode never` removes them). The comment holds
the `Fix` / `Implementation` summary, the commit subjects, push / rebase notes and a
`[cycle-worklog …]` marker per block, so a re-run never posts twice. The personal choice lives
in this clone's `.git/config` (`cycle.worklog.*`, never committed) and is tied to the Jira
account that saved it; another account's token sees `ask`. Sessions: `.git/cycle-worklog.json`;
`worklog status` lists them.

## Jira setup

`.cycle/tracker.json` (committed):

```json
{
  "format": 2,
  "jira": {
    "site": "https://<site>.atlassian.net",
    "project": "KED",
    "enforce": true,
    "issueTypes": {"bug": "Bug", "feature": "Story", "bundle": "Task"},
    "bundles": {"link": "Implements"},
    "fields": {"externalId": "customfield_10247", "acceptanceCriteria": null, "testPlan": null},
    "components": false
  },
  "apps": {"apps/tlm": "tlm"}
}
```

Each repo points at its own Jira: any Atlassian Cloud site or a Data Center server.
Credentials live in each person's environment and are never committed: the Atlassian
login email and a classic API token from id.atlassian.com (no scopes).

**Credentials, in order of precedence** (`jira doctor` prints the variable it used):

1. Variables the repo names: `"auth": {"emailEnv": "X", "tokenEnv": "Y"}`.
2. Site-specific variables, so one person can hold several Jira accounts at once:
   `JIRA_EMAIL_<SITE>` / `JIRA_API_TOKEN_<SITE>`, where `<SITE>` is the first part of the
   host in capitals with `-` → `_` (`paradigmtest-dev1.atlassian.net` → `PARADIGMTEST_DEV1`).
3. `JIRA_EMAIL` / `JIRA_API_TOKEN`.

Data Center with a personal access token: `"auth": {"type": "bearer", "tokenEnv": "Y"}`.

The config's `site` and `project` always win; `JIRA_SITE` / `JIRA_PROJECT` only fill a
missing value. `jira doctor` prints the custom-field ids for the config (without an
External ID field, duplicates are found by the `<id>` + `<app>` labels instead). Without
credentials, `add` writes `Jira: pending` (enforce) and the next `jira sync` fills it in.
