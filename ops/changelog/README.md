# Changelog

Changelog tells Billington's friends and testers what a ready pull request changes
and why, then gives everyone **seven full days** to stop it. Going live here means a
squash merge to main. Existing main CI owns any later delivery.

Authors open drafts and keep the opening note current. The driver or owner marks a
PR ready after green checks and independent review. The bot reads the note between
`<!-- changelog:start -->` and `<!-- changelog:end -->`. It sends that note, a short
PR heading, deadline and status to one Discord message. Changes outside those note
markers are never forwarded. A missing, placeholder or overlong note fails the
`Changelog note` check and prevents posting/merging; shorten the note rather than
silently truncating it. Its escaped text must fit 1100 UTF-16 code units.

## Hold, release and clock

Tap **🛑** on the notice to hold the PR indefinitely. Anyone's reaction counts,
including other bots; only Changelog's own seed reaction is ignored. Normal and
super reactions both count. Remove your stop reaction to release your hold. Every
holder must release before merging. 👍 is a thank-you; it never shortens the week.
Holds are polled hourly, so their displayed status can lag. Just before merging the
bot reads reactions again. A reaction arriving after that last read and before
GitHub accepts the merge cannot be made atomic across the two services.

The post shows the exact holder count and up to eight names/Discord user IDs with
their **first observed** hold time. Discord's REST reaction list has no reaction
timestamp; actual hold time may be earlier. Additional holders remain visible by
opening the reaction list. Removing a hold keeps the original deadline. No reaction
can approve, alter code, close a PR, or merge it early.

The clock starts at Discord's actual message timestamp, with a deadline seven days
later. New own commits or a changed net diff restart the week. A clean merge of main
that preserves the PR's own commits and patch keeps the deadline, even if hunk line
numbers move. Conflict resolutions change the diff and restart. Rebases/squashes
replace own commit IDs and conservatively restart; patch context changes may also
restart. Binary/rename-without-patch, missing/truncated comparisons, 300+ files or
100+ ahead commits cannot prove unchanged code: **each run restarts** and explains
why. Large or ambiguous PRs need a person to resolve the comparison; they never
inherit an old deadline. Editing only the note updates the same post without a
restart. Back to draft cancels the clock; ready again (or reopen) starts a full week.
The timeline catches draft/ready transitions even when an event run was replaced.

At the deadline the PR must still be ready, unheld, cleanly mergeable, and have every
reported check/status green on its exact head, including the Actions check named
`Required delivery checks`. Skipped, neutral, pending, missing or unknown checks do
not count. A changed head, base, description or ready transition during a run waits
for a later run. The GraphQL mutation also requires the observed head OID. GitHub
rules still apply. A failed merge says why and retries later; there is no bypass.
Tracker-only (`bugs.md`, `features.md`, `CHANGELOG.md`), Dependabot and fork PRs are
outside Changelog. This bot does not enforce the manual policy against a human
using another merge route; agents must never merge around it.

## Setup (owner/driver only)

No setup was performed by the implementation. Do not give credentials to agents.

1. Create a Discord application named **Changelog**, use application ID **1570549785583419514**, add its bot and invite it with
   the `bot` OAuth scope. In channel **1366910615188406494**, allow **View Channel,
   Send Messages, Embed Links, Read Message History, Add Reactions**. No Administrator,
   Manage Messages, gateway connection or privileged intents are needed. Reading
   this bot's own messages works without Message Content intent. Deny access to
   unrelated channels. The bot must retain read history access for crash recovery.
2. Add Actions secret `CHANGELOG_DISCORD_BOT_TOKEN`: the application's bot token, a
   nonempty opaque credential. Never put it in a workflow file, command line or log.
3. Add repository variable `CHANGELOG_DISCORD_CHANNEL_ID`: decimal string
   `1366910615188406494`. Add variable `CHANGELOG_MODE`: initially `post`.
   Missing, `off` or any unrecognized value stops **all API calls** and fails loudly.
   `post` posts/updates notices and checks but never merges. `merge` permits
   merging only with the separate identity prerequisites below.
4. Leave `CHANGELOG_MERGE_TOKEN` and `CHANGELOG_IDENTITY_PROOF_PR` unset until the
   driver/owner chooses and qualifies the identity path. With either missing, a
   PR past its week says it is waiting for a person.

Both workflows share a fixed noncancelling concurrency group. GitHub keeps only one
pending run, so the scheduled full reconciliation recovers replaced event runs.
The event workflow uses `pull_request_target` on main, excludes forks before a job
starts, checks out **only main** with persisted credentials disabled, and reads PRs
through APIs. No branch names, notes or PR values become shell source. The schedule
runs at minute 17 each hour on the default branch. Only the built-in token gets
`contents: read`, `pull-requests: write` (state mirror), `checks: write` (note check).
The merge PAT is passed separately and never used as a checkout credential.

## Merge identity: qualify before enabling

Recommended conditional path: a **fine-grained PAT owned by LLRHook (Victor)**,
restricted to **LLRHook/checksinmyhead only**, with **Contents: read and write** and
**Pull requests: read and write** (GraphQL merge operation), plus automatic Metadata
read. No Actions, Administration, Issues, Checks or account Email write permissions
are requested. `/user` needs no fine-grained permissions. Store it as Actions secret
`CHANGELOG_MERGE_TOKEN`. Use a short expiry and rotate it. PAT expiry/revocation
stops merging. Organization approval/rulesets may further restrict it.

GitHub documents GraphQL `MergePullRequestInput.authorEmail`, `expectedHeadOid`,
`mergeMethod` and `commitHeadline`; REST merge lacks an author-email parameter.
The implementation sets Victor's email, SQUASH and `<title> (#<number>)` explicitly,
with an empty body (no co-author trailers). GitHub does **not** offer `authorName`
in this mutation. Profile name alone is not proof of a future author name.

Before enabling automatic merging, the driver must qualify the exact account/API
path using a separately authorized rehearsal or matching prior merge and observe
both the raw commit author **Victor Ivanov <victor.n.ivanov@gmail.com>** and main's
push-triggered CI starting. Set `CHANGELOG_IDENTITY_PROOF_PR` to that merged PR's
positive decimal number. This is an **operator attestation**, not a secret or a
cryptographic guarantee. The bot rechecks the proof PR's `merged_by` login, its
single-parent commit's raw author, the current PAT account/profile, and requires
the candidate PR author and all its commit authors to be Victor too. Other authors
wait for a person. The actual merge response is also checked; any unexpected author
is an identity incident: set mode `off`, inspect main, and do not treat that late
observation as prevention. Do not enable `merge` until the driver accepts the
remaining GitHub author-name boundary. Absent qualification, **post is the
supported fail-closed configuration** and a person merges after the full week.

Options and trade-offs:

- Built-in `GITHUB_TOKEN`: deliberately unavailable for merging. Its identity is an
  app, and its pushes normally do not trigger other workflows.
- Victor's fine-grained PAT: smallest practical account credential; permits normal
  push events and explicit author email, but expires, carries repository write
  authority, and needs the identity qualification above.
- GitHub App installation token: short lived and good repository scoping, but its
  app identity does not satisfy Victor's human author requirement by itself. A user
  access token adds an app/OAuth lifecycle and still needs author qualification.
- Human merge with Victor's existing `gh` login/author email: keeps the current
  proven procedure; no automation credential, but requires a person after the week.
- Constructing a Git commit/ref with an explicit name could set author metadata,
  but bypasses the PR squash-merge/rules path. It is deliberately not implemented.

The PAT/App distinction for downstream CI is documented in GitHub's
[workflow triggering guide](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).
See the [GraphQL merge inputs](https://docs.github.com/en/graphql/reference/pulls#mergepullrequestinput),
[REST merge permissions and parameters](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request),
[authenticated user permissions](https://docs.github.com/en/rest/users/users#get-the-authenticated-user)
and [fine-grained permission reference](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens).

## State, recovery and threat boundary

There is one bot-owned PR comment with readable state and one bot-owned Discord
message. The Discord embed footer stores version, PR number, fingerprint, start,
latest ready/draft/reopen event, note, cancellation and observed holder times.
**Discord is the clock authority. The PR comment is only a mirror.** Reconciliation
scans paginated message history, verifies bot author and exact repository/PR marker,
and derives current head, diff, transitions, mergeability, checks and reactions from
fresh APIs. A writer editing/replaying the PR comment cannot move a deadline earlier,
change the fingerprint, remove a hold, or substitute a foreign Discord message.
A forged bot-comment marker can cause extra waiting if the Discord post is missing;
a writer may delete the mirror and it is recreated from Discord. Writers already
able to change main can replace the trusted controller; that is outside this bot's
trust boundary. Discord bot-token holders can edit authoritative messages, so keep
that secret scoped and private. Channel admins can delete posts/reactions; do not
grant Changelog Manage Messages. Lost notices with an existing mirror fail closed
and need a person, rather than silently dropping holds and posting again.

History recovery plus Discord's deterministic `nonce`/`enforce_nonce` handles a
create succeeding with its response lost. Nonce uniqueness alone lasts only a few
minutes; history is essential. Duplicate notices or state corruption stop that PR.
Shared concurrency serializes the workflows; a merge succeeding with its response
lost is discovered via the next fresh PR read. No write is retried within a run.
HTTP429 fails that reconciliation without printing credentials or response bodies;
a later hourly run recovers. Redirects are refused and response sizes are bounded.
No gateway or third-party Python package is used.

Notes/titles/names are untrusted text. The bot replaces mention syntax, strips
controls, escapes Markdown/links and sends an empty `allowed_mentions` list on
**both creates and edits**. It sends only the selected note text, with bot-controlled
status/link; note content cannot execute a command or inject another message.
Discord's [message API](https://docs.discord.com/developers/resources/message)
documents limits, mention control, nonce recovery and reaction pagination.

## Failure messages and pausing

- **OFF/unconfigured/missing credentials/channel:** no API activity; fix setup, then
  wait for the next normal event/schedule. The workflow fails so misconfiguration
  is visible in Actions. An absent merge credential alone permits observation.
- **Waiting for author:** fix the note; note check becomes green on the next run.
- **Restarted/comparison incomplete:** full new week; split the PR or make GitHub's
  full comparison available. A conservative restart is never an early merge.
- **HELD:** ask the named people about their stop reactions; do not remove them.
- **Week passed/paused/identity not proven:** keep observing, or qualify the identity
  path. A person still respects the recorded week and all checks/holds.
- **Green checks/clean merge/change during run:** resolve the failing check/conflict,
  or wait for GitHub; later runs retry with fresh data.
- **Missing/duplicate notice, corrupted state, pagination limit:** set mode `post`
  or `off`, inspect the bot-owned message and mirror, preserve all existing holds;
  resolve manually. Never manufacture an older start time.
- **HTTP429/503/unavailable:** a later run retries. If notice state cannot be read,
  nothing merges. **Identity incident** requires mode `off` and driver investigation.

One repository variable is the switch: `CHANGELOG_MODE=post` stops merging;
`CHANGELOG_MODE=off` stops everything. A value already read by a running job cannot
be retroactively revoked; for an immediate stop, also cancel the active Changelog
run in Actions. No config file, workflow dispatch or code change is needed.

Schedules are best effort, may run late, and GitHub can disable scheduled workflows
after 60 inactive days in a public repo. This delays merges; it never shortens a
week because recorded timestamps determine deadlines. Check the last successful
**Changelog schedule** run regularly. If disabled, re-enable it in Actions after
reviewing the state, keep mode `post` during recovery, and let the next scheduled
run reconcile before considering `merge`. There is intentionally no dispatch trigger.
See [GitHub event/schedule behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

## Offline proof and read-only dry run

Use CPython **3.12**, the interpreter pinned by the automation row:

```sh
python3 ops/changelog/test_changelog.py
CASE_REPORT="$REPORT_DIR/changelog.json" python3 ops/ci/unittest_report.py ops/changelog/test_changelog.py
python3 ops/ci/test_delivery_gate.py
python3 .cycle/trackers.py lint
```

Tests replace the GitHub/Discord APIs and forbid network sockets. They cover the
full lifecycle, exact deadline, fresh-head checks, note validation, exemptions,
restart and draft transitions, reaction pagination, races, lost responses, nonce,
mentions/limits, HTTP429, kill switches, dry-run boundaries and guard removal.
The automation manifest requires these methods and the additional report; the gate
pins both workflow files and rejects extra workflows/permissions.

For a driver-operated read-only rehearsal, run the **reviewed main script** locally
with credentials injected through the driver's existing private secret helper (no
shell tracing). Supply `GITHUB_REPOSITORY=LLRHook/checksinmyhead`,
`GITHUB_EVENT_NAME=schedule`, `GITHUB_EVENT_PATH` pointing to a local `{}` JSON file,
`CHANGELOG_MODE=post`, the configured channel and API credentials, then:

```sh
python3 ops/changelog/changelog.py --dry-run
```

It reads the real APIs and prints intended actions/statuses, suppressing every
GitHub/Discord mutation, including checks, comments, reactions and merges. It does
not load or print raw response bodies/credentials/notes. This procedure was **not
run by the implementation**; no real Discord call or merge was authorized.

## Driver smoke procedure after secrets exist

1. With mode `post`, use an authorized synthetic same-repo **draft** PR with a
   real opening note. Normal events should make no Discord post while draft.
2. After checks/review, mark ready. Observe one message, both seed reactions,
   valid note check, mirror and a deadline seven days after posting. Deliver a
   harmless edit twice: the message ID stays the same.
3. Edit only the note: same deadline/post. Add own code: same post, fresh week.
   Merge main without changing the PR's patch: unchanged deadline. Convert to
   draft and ready again: a full new week.
4. Add a stop reaction from another account. Next hourly run shows that holder;
   remove it and confirm the prior deadline stands. Try 👍 and confirm no early
   merge. Close a separate synthetic PR and observe the same post say closed.
5. Do not shorten seven days or edit persisted timestamps for testing. Keep mode
   `post` through an actual week; at the deadline verify the waiting-for-person
   status. Red checks/conflicts should also block when the identity path is enabled.
6. Separately qualify the selected merge identity as described above, with explicit
   driver/owner authorization. Confirm raw author, exact squash title and main CI
   starting. Only then consider setting proof PR, merge secret and mode `merge`.
   Check the next eligible authorized merge and its main CI. Return to `post`
   or `off` if any evidence is missing. The implementation did not perform this step.

Real Discord membership/permissions, hosted workflow activation, actual check names,
PAT/GraphQL permissions and author behavior, downstream CI/rulesets, seven elapsed
days and cross-service races remain external proof, not claims from offline tests.
