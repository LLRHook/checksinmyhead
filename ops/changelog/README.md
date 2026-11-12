# Changelog

Changelog tells Billington's friends and testers what a proposed app change does
and why, then gives everyone **seven full days** to stop it. Going live here means
squash-merging to main. Main's existing CI owns later delivery.

Authors open drafts and keep the opening note current. The driver or owner marks a
change ready after green checks and independent review. The unchanged note format
is in [the PR template](../../.github/pull_request_template.md). Only the text between
its markers is forwarded. Missing/template/overlong text fails the **Changelog note**
check, including while draft. Drafts post nothing. The escaped note must fit 1100
UTF-16 units; shorten it rather than letting the bot truncate what people read.

## What friends see and how to hold

One Discord notice carries the explanation and current outcome. While ready and
waiting, it shows a deadline in **your local time**, a relative time, and the
invitation to hold. A merged notice says **“Merged. It will be in the next app
build.”** Closed, exempt and back-to-draft notices have no deadline or hold invitation.
A back-to-draft notice says the wait is cancelled.

Tap **🛑** to hold indefinitely. Any person's or other bot's normal/super stop
reaction counts; Changelog ignores only its own seed. Remove your stop to release
your hold. Every holder must release. **👍 never shortens the week.** Holds are polled
hourly and read again immediately before merging. The displayed count is exact;
up to eight names and first-observed hold times are shown, without IDs or mentions.
Discord supplies no actual reaction timestamp. Open the reaction list for everyone.

If someone leaves the server with a stop still present, a server administrator or
moderator with **Manage Messages** can remove that reaction after resolving the
objection. Changelog itself never gets that permission. Otherwise close the change
and open a **new** PR, explain the unresolved objection, and wait a full new week.
The accepted cross-service window remains: a stop arriving after the final reaction
read but before GitHub accepts the merge cannot be made atomic with it.

The week starts at the later of the initial controller time and Discord's actual
posting time. Note-only edits update the same post without restarting. Own commits
or the net change restarting are announced as “The change was updated, so the seven
days start again.” A clean merge-main update preserving the own commits and patch
keeps the deadline; conflict resolutions and rebases conservatively restart it.
Returning to draft cancels the wait; ready/reopen starts a full week again. The
GitHub timeline recovers transitions even when an event run was replaced.

Binary files and pure renames use file name, previous name, status and blob SHA.
Commits and files are paged: GitHub exposes compare files only on the first compare
page, capped at 300, so the controller uses the paginated PR files list when needed
(up to GitHub's 3000-file limit). A truncated text patch, data beyond that limit, or
more than the bounded 1000-commit comparison allowance uses the **exact current
commit** instead. Its notice says “This is a large change, so any new commit restarts
the seven days.” That clock remains stable between runs and can finish; merging
main then also restarts it. A timeout, 5xx or rate limit is **not a change**: that
PR's saved notice, checks, mirror and clock stay untouched, others still reconcile,
and the overall run fails visibly for a later retry.

At the deadline, the change must still be open, ready, unheld, cleanly mergeable,
and green on its exact current commit, including the Actions check named
**Required delivery checks**. Missing/pending/skipped/neutral/failed checks do not
count. A missing check is named in the notice. The final reread checks the change,
base, note, ready transition, checks and reactions; GraphQL also conditions its
squash merge on the expected commit. GitHub rules continue to apply. Tracker-only
(`bugs.md`, `features.md`, `CHANGELOG.md`), Dependabot and fork changes are exempt.
Existing notices still finish if a change becomes exempt, stops targeting main,
or is merged/closed by a person. There is no agent bypass of the week.

## Driver setup: main-only environment

The implementation did not perform any setup, inspect tokens or call Discord.
These are **driver decisions**; account setup and the live rehearsal belong to the
driver/owner. Do not give credentials to an agent.

1. Open Discord application **Changelog**, ID **1570549785583419514**. Invite its
   bot using OAuth scope `bot`. In channel **1366910615188406494**, allow **View
   Channel, Send Messages, Embed Links, Read Message History, Add Reactions**.
   No Administrator, Manage Messages, privileged intent or gateway is needed.
2. In GitHub repository Settings → Environments, create **`changelog`**. Configure
   deployment branch rules to allow **only `main`** (selected branches/tags; no
   wildcard/tag allowance). Both jobs declare this environment. Verify the branch
   restriction before storing either secret; do not put them in repository secrets.
3. In that environment, set **`CHANGELOG_DISCORD_BOT_TOKEN`**, the opaque Discord bot
   token. If it was provisioned as a repository secret, move it privately and remove
   the repository copy. The driver performs that transition; this PR does not.
4. Repository variables remain non-secret: **`CHANGELOG_DISCORD_CHANNEL_ID`** =
   `1366910615188406494`; **`CHANGELOG_MODE`** = `post` initially.
5. Optional environment secret **`CHANGELOG_MERGE_TOKEN`**: a fine-grained PAT owned
   by **LLRHook**, restricted to **LLRHook/checksinmyhead only**, with **Contents read
   and write, Pull requests read and write, Workflows read and write**, and automatic
   **Metadata read**. Workflows write covers changes that update workflow files.
   Choose a short expiry; renew/revoke privately. No secret means post/hold only.
6. Leave repository mode `post` through the rehearsal below. There is no prior-merge
   proof variable and no requirement on the authors of the individual commits.

The environment uses **`deployment: false`**, documented by GitHub: secrets and
branch restrictions apply without creating a deployment object each hourly run.
Do not add custom deployment protection rules, which GitHub documents as incompatible
with this option. See [workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idenvironment).
The gate pins this setting, the main-only checkout and the exact permission grants.

One variable is the switch: `off` stops all controller API activity; `post` posts and
tracks holds/deadlines but never merges; `merge` enables the conditional merge path.
Missing/unknown mode behaves as off and logs a loud failure. Missing Discord setup
also stops. To stop an already-running job immediately, also cancel that Changelog
run: a variable cannot revoke a value the running job already read.

## Merge identity and one rehearsal

Only a separate merge token may merge. The built-in token cannot: its app identity
is unsuitable and its events normally do not start downstream workflows. The bot
reads `/user` to require login **LLRHook** and profile name **Victor Ivanov**. It
merges automatically only changes **opened by that account**; another author's
notice says “The week has passed. This one was opened by someone else, so the owner
merges it by hand.” That manual path still respects the recorded week, all holds
and green checks; agents do not take it themselves.

GitHub's [merge documentation](https://docs.github.com/en/enterprise-server%403.21/pull-requests/how-tos/merge-and-close-pull-requests/merging-a-pull-request)
explicitly credits the PR creator as squash author; current GitHub.com instructions
also limit the squash email selector to the PR author. This supports retaining the
PR-author guard, rather than attaching Victor's email to someone else's change.
The API still offers no author-name input, so the rehearsal remains essential.

The mutation sets **SQUASH**, `expectedHeadOid`, `authorEmail` equal to
`victor.n.ivanov@gmail.com`, headline **`<title> (#<number>)`**, and an explicitly empty
body (no co-author trailers). It then reads the raw Git commit and requires author
**Victor Ivanov <victor.n.ivanov@gmail.com>**. A wrong author fails Actions, the PR's
note check, its Changelog comment and the Discord notice with an identity incident.
Set mode off and investigate. This detects a bad result; it cannot undo a merge.
A later reconciliation audits a manually merged notice too.

Before enabling repository `CHANGELOG_MODE=merge`, rehearse one finished,
owner-opened change through this exact controller:

1. Choose its positive PR number. It must have completed its real seven-day window,
   have no stops, be ready, cleanly mergeable and green. Prefer a reviewed change
   touching a workflow to exercise the Workflows grant. Do not shorten its clock.
2. From the reviewed **main** checkout on the driver's machine, privately inject
   the Discord token, channel ID, built-in-compatible GitHub read/check/comment
   credential and separate PAT through the driver's secret helper, with no tracing.
   For this local process only set `GITHUB_REPOSITORY=LLRHook/checksinmyhead`,
   `GITHUB_EVENT_NAME=schedule`, `GITHUB_EVENT_PATH` to a local `{}` JSON file,
   and `CHANGELOG_MODE=merge`. The repository variable stays `post`.
3. Run `python3 ops/changelog/changelog.py --dry-run --rehearse NUMBER` first.
   It reads services and prints its proposed outcome, with every write suppressed.
4. With separate owner/driver authorization, run
   `python3 ops/changelog/changelog.py --rehearse NUMBER`. This local-only selector
   uses the full week/hold/check/identity gate and changes no other PR. It is refused
   inside Actions. Do not run a hand-written GraphQL shortcut.
5. Inspect the raw commit with
   `gh api repos/LLRHook/checksinmyhead/git/commits/SHA --jq '{author, message, parents}'`.
   Confirm the exact author name/email, expected title and single parent. Confirm
   main's push-triggered `ci.yml` run started for this SHA (and required checks pass).
   Verify a workflow-touching rehearsal accepted the listed permissions.
6. Only after those observations may the driver set the repository variable to
   `merge`. On failure, keep `post` and investigate. No proof PR is reread on future
   merges, and no broader credential is used as a fallback.

[GraphQL inputs](https://docs.github.com/en/graphql/reference/pulls#mergepullrequestinput),
[workflow-trigger behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens)
are the primary references. No rehearsal or real merge was performed here.

## Bounded runs, state and recovery

Every valid event/scheduled run reconciles the entire active set, not just its event
PR. Discovery lists open PRs (including followed notices retargeted away from main)
and closures from the last **24 hours**. It stops paging old closures and never
fetches their individual records again. A recent closed PR without a bot comment
is ignored. A closure after an outage longer than a day needs manual notice cleanup;
this bounded horizon is explicit rather than an unbounded historical sweep.

The PR comment supplies an **untrusted message-ID hint**, never a clock. The fetched
message must be Changelog's own and exactly name this repository/PR. A bounded
latest-100-message read is shared once per run for duplicate/create recovery; older
known notices are fetched directly by ID, regardless of channel chatter. Unchanged
messages compare only the fields the bot sends, ignoring Discord-added `type` and
other metadata. Seeds are added only during creation/recovery of incomplete creation.
A request-count regression with 300 old closed PRs, seven open and 500 unrelated
messages measures **44 GitHub / 23 Discord requests**, zero edits and reaction writes.

The authoritative record is compressed in the bot-owned embed's link fragment,
behind its clickable title. The full clock, PR number, change identity, last ready
transition and observed holds are recoverable from that message alone. Its visible
footer is just “Changelog · review record”; it contains no note copy or JSON. The
readable PR mirror cannot advance the clock. A write-capable account can corrupt a
hint and cause extra waiting; restoring a valid message always re-derives timing from
Discord and current facts from GitHub. Bot-token holders and main writers remain
privileged trust boundaries. Never edit the hidden record to move a deadline earlier.

Before creating a notice the bot records a pending mirror. The deterministic nonce
includes the ready generation; a lost create response is recovered from recent
history, or through restoring its direct message link if channel traffic hides it. An
uncertain create is never assumed deleted: a later draft/ready cycle cannot discard
an existing but hidden notice or its holds. The owner restores its message link,
or closes it and opens a new PR with the unresolved objection explained and a full week.
Discord's nonce uniqueness lasts only minutes. It is not the durable authority.
Discord HTTP429 honours one numeric `retry_after` between zero and five seconds;
a second 429, longer/invalid delay, other HTTP error or timeout stops that operation
without a loop. Failed **reads** perform no writes or clock changes for that PR.
Channel 403/404 errors are persistent setup failures and are surfaced on the PR.

The event queue places same-repo work in `changelog-reconcile`; fork events use a
run-ID group of their own before their job is skipped. Both use `queue: max` and
never cancel a running job. GitHub documents up to **100 pending runs**; overflow
runs can be cancelled and ordering is not guaranteed. Correctness does not depend
on each event running: any later valid run re-derives every active change. See
[concurrency syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#concurrency).

The schedule is hourly at minute 17, best effort, and may be disabled after 60 days
without repository activity. Late schedules delay merging rather than shorten the
week. Monitor the last successful Changelog schedule run. Re-enable a stopped
schedule in Actions with mode `post`; reconcile current notices before enabling
merges. There is intentionally no dispatch trigger.

## Visible stuck states and safe ways out

- **Deleted/unrecoverable notice:** the PR comment asks the driver to mark the change
  draft, then ready again. Those fresh transitions create a new notice and a full
  week; an old mirror does not permanently block recreation. No early merge follows.
- **Channel 403/404:** the PR comment asks the owner to restore View Channel/Read
  Message History or Send Messages/Embed Links and check the channel setting. The
  notice gets the instruction when it can still be edited. Restore access and let
  the next run recover; do not erase the clock.
- **Duplicate notices:** the comment and editable notices ask the owner to preserve
  the original and its stops, remove the duplicate and resolve any objection on it.
  Until resolved nothing merges. Do not discard a stop without talking to its holder.
- **A departed holder:** a server admin/moderator removes the reaction after resolving
  it; otherwise close and open a new PR with a new full week, as explained above.
- **Required check never appears:** after the week the notice names the check it is
  waiting for, such as Required delivery checks. The driver repairs that CI problem;
  the bot keeps the original deadline and retries. No check waiver exists.
- **Wrong merge author:** identity incident appears in Actions, the note check,
  Changelog comment and editable notice. Set mode off, investigate main, repeat the
  qualified rehearsal before restoring automatic merging.
- **Transient outage/rate limit:** Actions fails for visibility. That change's notice
  and clock stay as before while others proceed; the next run re-reads it.
- **Off/missing setup/bad note/conflict:** Actions/note check/notice names the missing
  input or check. Fix it; missing credentials never select a fallback merge identity.

## Offline proof and driver smoke

Use **CPython 3.12**. Tests use stateful fake GitHub/Discord APIs and forbid socket
connections; no production token or Discord call is needed:

```sh
python3 ops/changelog/test_changelog.py
CASE_REPORT="$REPORT_DIR/changelog.json" python3 ops/ci/unittest_report.py ops/changelog/test_changelog.py
python3 ops/ci/test_delivery_gate.py
python3 .cycle/trackers.py lint
```

The automation manifest requires every new method and its report. The delivery gate
pins the two new workflows without weakening the existing workflows' assertions.
The fake lifecycle/response-shape cases include a 300-closed/7-open/500-noise run,
transient failures, binary/rename/large comparisons, stale/exempt notices, local-time
messages, deleted/duplicate/access recovery, draft note validation and identity
incidents. The independent review's 13 code and nine workflow mutations are rerun.

Live smoke still belongs to the driver: with mode `post`, exercise draft → ready,
exactly one notice and both seeds, note edit (same deadline), own code edit (new
week), unchanged merge-main (same week), stop/release (deadline unchanged), 👍 (no
acceleration), back-to-draft (no deadline), closure/exemption (final notice), deleted
notice recovery, channel access failure, and a required check missing at the actual
deadline. Read the hourly API usage and confirm unchanged messages are not edited.
Let seven real days elapse without changing stored times. Then perform the single
identity/workflow-touching rehearsal above before enabling merges. Hosted parser,
environment restrictions, live Discord permissions, actual check association,
PAT attribution/CI triggering and queue behavior remain live proof, not fake claims.
