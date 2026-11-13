# Changelog

Changelog tells Billington's friends and testers what an app change does and why,
then waits for **one person’s 👍 approval or seven days**, with **any 🛑 always stopping it**. Going live means squash-merging
to main; main's existing CI owns delivery to an app build.

Authors open drafts and keep the opening note current. The driver or owner marks
a change ready after green checks and independent review. Only text between the
markers in [the PR template](../../.github/pull_request_template.md) is forwarded.
Missing, template or overlong text fails **Changelog note**, including while draft.
The escaped note must fit 1100 UTF-16 units; shorten it rather than truncate it.
Drafts have no initial Discord post.

## What friends see

One embed contains the clickable PR title, explanation and status; there is no
separate message text, footer or bare URL. Waiting notices say a change goes live as soon as one person taps 👍, or at its
seven-day deadline if nobody stops it. Dates are local and relative. A merged notice says “It's
in. You'll see it in the next app build.” Final, draft and overdue notices have no
deadline. GitHub's comment uses written UTC dates instead of Discord time markup.

Tap **🛑** to hold indefinitely. Every person's or other bot's normal or super stop
reaction counts; only Changelog's own seed is ignored. Every holder must release.
Removing a stop leaves the original deadline intact. **One person’s 👍 can skip the remaining wait.**
While changes wait, the schedule requests a run every 15 minutes; reactions are
read at that run and immediately before merging. GitHub can delay or drop ticks. Up to eight names and their
first-observed hold times appear, without mentions or IDs. Discord provides no
reaction timestamp; open its reaction list for all holders.

If a holder leaves the server, a moderator with **Manage Messages** can resolve the
objection and remove the reaction. Changelog does not get that permission.
Otherwise close this PR and open a new one, explain the unresolved objection, and
wait a full new week. A reaction arriving after the final read but before GitHub
accepts a merge remains an accepted cross-service window.

A fresh/full week below names the fallback deadline; a new counting 👍 can still
send the change sooner.

The week starts at the later of controller time and Discord's actual posting time.
Note-only edits update the same post. Own commits or net changes restart the week
and say “The change was updated, so the week starts again.” A clean merge-main
update preserving the own commits and net patch keeps the deadline; resolutions
and rebases conservatively restart it. Draft cancels the wait; ready or reopen
starts a full week. The GitHub timeline recovers transitions from missed events.

Binary files and pure renames use filename, previous filename, status and blob SHA.
Commits and files are paged. Compare's 300-file cap falls back to PR files (up to
GitHub's 3000-file cap). Truncated text patches, larger lists or more than 1000
comparison commits use the **exact current commit** instead. The notice says
“This is a big change, so any update to it restarts the week.” That clock stays
stable between runs and can finish; a new head then always restarts it. Transient
read failures before publication leave that PR's notice, checks, mirror and
clock untouched; other PRs proceed and Actions fails for a later retry.

A merge requires a counting approval or the full seven days, plus an open, ready, unheld PR, GitHub's clean mergeability, exact-head
Actions successes for **Required delivery checks** and **Changelog note**, and no
other incomplete or failing checks. Optional **skipped** and **neutral** checks are
allowed; only the current Actions job named `changelog` is excluded. Failure,
cancelled, timed_out, action_required, stale, startup_failure and unknown results
block. The latest legacy status per context must also succeed. Missing or failing
checks are named after the week. Final reads verify head, base, note, ready
transition, checks and holds; GraphQL also conditions the merge on the exact head.
GitHub rules still apply. Tracker-only (`bugs.md`, `features.md`, `CHANGELOG.md`),
Dependabot and fork changes are exempt. Existing notices finish when a PR becomes
exempt, leaves main, or a person merges or closes it. Agents cannot bypass the week.

## What a 👍 means

The owner's correction was: “no the thumbs up does speed it up once one person
says its good it goes to main”. The version, polling and recovery rules below are
the driver agent's interpretation, not additional owner statements.

Any person in the channel, including the change's author, can approve with 👍,
any skin tone or a super reaction. Changelog's seed and other bots do not approve.
A normal or super 🛑 from anyone still holds, regardless of approvals. A counting
approval lets the bot merge at its next run without waiting; nobody approving
keeps the seven-day path. Reactions do not wake Actions: approval is acted on by the next actual run,
whose timing GitHub does not guarantee. A nominal 15-minute tick is not a
15-minute response promise; see the measured delays below.

A 👍 cannot merge red/incomplete checks, a held change, a draft, a broken note,
a version nobody has approved since it changed, or anything while mode is off or
post. The owner-opener/account, token, expected-head and clean-merge gates remain.
Post mode, a missing merge token or another PR opener only changes the notice;
Changelog does not merge in those cases.

On every code/ready restart, all 👍 present are for the old version. A person must
remove every tone/type of their 👍, let a run see it gone, then add it again. A
new person's approval at a later non-restarting run counts. Note-only edits keep
approvals. Returning to draft stops approval; ready again requires fresh approvals.
Names are sanitized and never ping anyone.

The bot stores at most eight stale approver IDs. If a restart has more than eight,
it conservatively requires all human 👍 to be seen gone before approvals can count
again; the seven-day path still works. It never drops old IDs or treats forgotten
people as fresh. The first rollout onto old notices treats their existing 👍 as
old-version reactions. Missing/damaged approval knowledge also requires re-giving;
a damaged full record fails closed through the existing recovery instruction.

A restart first publishes the new notice with approval invalidation pending, then
reads reactions again and confirms the baseline in its bot-owned record. This
catches a 👍 arriving while the old notice was being replaced. If that write/read
is interrupted, the next run conservatively invalidates present reactions again.
Valid records recover through deleted comments or lost posting replies without
forgetting which version was shown. Duplicates and damaged records do not approve.
The final fresh message read rechecks the exact notice record, 🛑 and counting 👍
before merging. After listing approvals, it takes another fresh message snapshot
and reads stops last; an empty approval count there also prevents an early merge.

## Driver setup: main-only environment

These are driver decisions. No setup, token inspection or real Discord/merge call
was performed by the implementation agent. Do not give credentials to an agent.

Invite Discord application **Changelog**, ID **1570549785583419514**, using scope
`bot`. In channel **1366910615188406494**, grant exactly **View Channel, Send
Messages, Embed Links, Read Message History, Add Reactions**. No privileged intents,
Administrator, Manage Messages or gateway connection are needed. Recovery uses
ordinary channel history and works with these grants.

1. In repository Settings → Environments, create **`changelog`** with selected
   deployment branches limited to **`main`** only; no wildcard or tag allowance.
   Verify this restriction before storing secrets. Do not add custom deployment
   protection rules. Both jobs use `environment: {name: changelog, deployment: false}`:
   secrets and branch restrictions apply without quarter-hour deployment objects.
2. Add environment secret **`CHANGELOG_DISCORD_BOT_TOKEN`** privately. Optionally
   create **`CHANGELOG_MERGE_TOKEN`**, a fine-grained PAT owned by **LLRHook**, scoped
   only to **LLRHook/checksinmyhead** with **Contents read and write, Pull requests
   read and write, Workflows read and write**, and automatic **Metadata read**.
   Workflows write permits workflow-touching changes. Choose a short expiry and
   renew or revoke privately. Without it the bot posts and holds but never merges.
3. Delete any repository-level copies of **both secrets** after placing them in
   the restricted environment. The driver handles that private transition.
4. Set repository variables **`CHANGELOG_DISCORD_CHANNEL_ID=1366910615188406494`**
   and **`CHANGELOG_MODE=post`**. Verify posting, holds, updates and scheduled runs.
5. To enable automatic merges, create/store the merge token above if still absent,
   then set **`CHANGELOG_MODE=merge`**. For the **first automatic merge**, a person
   inspects the raw commit on main for **Victor Ivanov <victor.n.ivanov@gmail.com>**,
   the expected title and one parent, and confirms main's push CI started and passes.
   Prefer a reviewed workflow-touching change to exercise that permission. Observe
   the full real week; do not change recorded dates or make an agent perform a merge.

One variable is the switch: **off** makes no controller API calls; **post** tracks
notices, holds and deadlines without merging; **merge** enables merging. Missing
or unknown mode behaves as off and fails loudly in the run log. Missing Discord
setup also stops. To stop an already-running job, also cancel that run; a changed
variable cannot revoke a value it already read. There is no dispatch trigger.

Only the separate PAT merges; the built-in token cannot. The bot requires its
`/user` to report login **LLRHook** and profile name **Victor Ivanov**. Automatic
merging is limited to PRs opened by that account. For other authors the notice says
“The week is up. Someone else wrote this one, so the owner will put it live by
hand.” The owner/driver manual path still requires a current approval or the full week, no holds and
green checks; agents do not perform it. A person's merge gets an ordinary final
notice. When both the PR opener and merger are LLRHook, the raw author is audited,
including hand-merges. Another person's PR is never audited by this bot.

The GraphQL mutation uses **SQUASH**, `expectedHeadOid`, Victor's `authorEmail`,
headline **`<title> (#<number>)`**, and an empty body without co-author trailers.
Every bot merge reads the raw Git author. If the merge reply or audit read is
lost, later runs derive the audit requirement from GitHub's opener and merger
identities and retry until a read succeeds; a successful audit is saved once. A
wrong author fails Actions, the note check and the PR comment; Discord still
shows the ordinary merged notice. The instruction names the commit on main and
asks for mode `post` and a token identity check if Changelog merged it.
Investigate main. Detection cannot undo a merge. Relevant references:
[GraphQL input](https://docs.github.com/en/graphql/reference/input-objects#mergepullrequestinput),
[PAT permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens),
[workflow triggering](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[environment syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idenvironment).

## Sweep only while a change is waiting

The owner's instruction, verbatim: “stop sweeping when we have no work that has
been done, only start sweeping when a new feature is implemented or a library got
a version bump”. The waiting definition and control sequence here are driver
decisions, not further owner statements.

Waiting means an open, eligible, ready PR with a live unfinished notice: its
fallback deadline is pending, it is held, it is approved but not merged, its week
is up, or its existing notice is paused for a broken note. Exempt PRs (including
Dependabot and tracker-only), closed changes, drafts and broken notes without a
notice do not start sweeps. Eligibility remains unchanged; a library bump opened
by Dependabot stays exempt pending a separate owner decision. The definition is
in the controller's `waiting` function, using the existing eligibility and saved
exemption rules. Marking a draft ready again can start sweeps.

After a successful sweep with no waiting notices, Changelog disables **only
Changelog schedule**, then lists open PRs again. If any is eligible and ready, it
re-enables the schedule. This deliberately conservative final check may keep it
active for a ready tracker-only PR or broken note without a notice; it avoids
another Discord/history pass while protecting work arriving during the stop.
If any PR failed reconciliation, the sweep fails and never attempts to disable.
An event that successfully leaves its own PR waiting enables the schedule after
its normal notice, check and comment work. It does not sweep other PRs. Dry runs
never enable or disable anything.

The disable/read/enable sequence closes the idle/event race: if an event enables
before disable, its ready PR is in the subsequent read; if it enables after
disable, its enable wins. An event arriving after the read also enables. The
shared non-cancelling queue remains an additional guard, not the proof of this
sequence. No new workflow or dispatch trigger is introduced.

A failed event enable fails the run visibly **after** the notice and mirror were
written. They are not rewritten as schedule errors. Retry the event or enable
by hand. A failed disable logs a warning and requests enable, since a lost reply
may mean GitHub already disabled it. A failed post-disable listing also requests
enable, then fails the run. If that recovery enable itself fails before taking
effect, the schedule can remain disabled: the failed run needs operator recovery
or a new successful waiting event. No API client can guarantee availability
through an outage. Do not rely on a disabled schedule to retry itself.

The owner can control it without changing the cron:

```sh
gh workflow enable "Changelog schedule" --repo LLRHook/checksinmyhead
gh workflow disable "Changelog schedule" --repo LLRHook/checksinmyhead
```

Enabling allows future scheduled ticks; it does not dispatch a run. A successful
waiting PR event restarts a manually stopped schedule. To stop all bot activity,
use the existing off-mode switch and cancel an active run as needed. Enabling
while idle leads to the next successful idle sweep disabling it again.

Both jobs add **Actions write** to their repository-scoped `GITHUB_TOKEN`; every
other permission stays pinned. GitHub documents `GITHUB_TOKEN` as a GitHub App
installation access token, and both [disable](https://docs.github.com/en/rest/actions/workflows#disable-a-workflow)
and [enable](https://docs.github.com/en/rest/actions/workflows#enable-a-workflow)
accept installation tokens with Actions write. Together these document support
for these calls with that token; this pass has not exercised it live. See
[GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token).
This permission is broader than a per-workflow grant: compromised trusted run
code could control other workflows/runs/artifacts in this repository, including
cancelling or deleting runs. The controller hardcodes only its schedule endpoint;
that is a code boundary, not token enforcement. Events still fetch and execute
main only, never PR code. The separate merge PAT and its gates remain unchanged.

At the driver's **2026-11-13 07:24:38Z** observation, this repository had **zero
scheduled runs** since the first tick at **02:17Z**. In the supplied week's
measurements, `LLRHook/LLRHook` (09:15 UTC cron) and `LLRHook/linky-web` (07:41 UTC)
started roughly **6.5–10.5 hours late**, every day. These are measured historical
facts from driver `evidence/driver/schedule-delay.txt`, not forecasts. GitHub
[documents delays and dropped scheduled jobs](https://docs.github.com/en/actions/how-tos/troubleshoot-workflows#scheduled-workflows-running-at-unexpected-times).
Its enable endpoint documents a transition to active, but no bound on the next
scheduled run after re-enabling; that delay is **unknown**. The driver is measuring
it. This design adds no timing assumption or alternate scheduler.

## Runs, state and recovery

Each event handles **only its event PR**. The scheduled run at minutes **7, 22, 37
and 52** of each hour sweeps open
PRs and closures from the last **24 hours**, stopping before old closures. A closure
missed for longer than a day needs manual notice cleanup. Both workflows retain
`queue: max` and never cancel a running job. Fork events use an isolated run-ID
group and are skipped. GitHub permits up to 100 pending runs; ordering and schedule
timing are best effort. While enabled, a later scheduled sweep can catch dropped/failed events; after an
idle stop, a missed or failed start event needs a new event or manual enable.
Schedules may be disabled after 60 days without activity; monitor successful runs
and recover in post mode before enabling merges again.

The PR comment is a readable mirror and an **untrusted message-ID hint**, never a
clock. First, fetch its last anchored `Discord message:` line. Accept the message
only in the configured channel, from this bot, with the exact PR's valid record.
Otherwise page backward through channel history, stopping at the first message
older than the PR's creation. Exactly one notice recovers; none permits creation;
multiple notices stop. At the **20-page cap**, fail closed and tell the driver to
close this PR and open the change as a new PR with a full week and any unresolved
objection explained. That lookup precedes every creation, so deleting, retitling
or forging the comment cannot abandon a held notice. A lost first POST reply is
recovered the same way. A deterministic ready-generation nonce adds short-lived
retry protection; it is not durable authority. There is no pending marker.

At 50 messages/day, exceptional history recovery for day/week/month-old PRs takes
**1/4/16 history requests**, plus one bot identity request, using a 30-day month and
an older sentinel. The direct hint makes this exceptional. A steady event costs
**7 GitHub / 2 Discord requests**; a sweep of ten open PRs costs **62 / 11**. An
hour with 15 such events plus four sweeps costs **353 / 74**, with no unchanged
notice edits or reaction writes, plus one idempotent workflow enable per waiting
event. An empty idle sweep costs four GitHub calls (two initial listings, disable,
open recheck) and no Discord calls; no further ticks run until re-enabled. The older regression with 300 old closed PRs,
seven open and 500 unrelated messages costs **44 / 8**, also without writes.
Initial creation needs one message POST and two seed reactions. Returned Discord
metadata is ignored when comparing the single embed the bot set.

The steady no-reaction budget is **353 GitHub requests/hour**, leaving 647 of
this repository's shared 1,000-request budget for delivery and other work. The
bot checks the message's reaction counts before listing users; seed-only reactions
need no listing. Active reactions, due merges and exceptional recovery cost more.
Initial posting needs a POST and two seeds. See Discord’s [reaction fields](https://docs.discord.com/developers/resources/message#reaction-object) for counts and super-reaction metadata. A version restart or legacy notice
upgrade also reads reactions after publishing and confirms its approval baseline;
these are bounded transition writes, not steady-state polling.

The authoritative record is compressed into the title link fragment, with its
clock, ready transition, change identity and observed holds. A writer editing the
PR comment can corrupt the hint or delay recovery, but cannot move merging sooner:
clock data comes from the bot's Discord record, clamped to the actual message time;
GitHub supplies the current PR, timeline, change and checks; Discord supplies holds.
Injected holder-name text cannot replace the last anchored pointer. Bot-token
holders and writers to main remain privileged trust boundaries. Do not edit the
hidden record to shorten a deadline.

A PR created more than **2,000 channel messages** before its notice would appear
cannot have that notice posted or recovered without a direct valid pointer. Close
it and open the change as a new pull request with a full week. The bot works best
in a channel where people mostly react; heavy chatter can exhaust this limit even
while a PR is a draft. The creation-time stop rule and 20-page cap are unchanged.

Never-posted Dependabot, non-main and tracker-only PRs return before Discord lookup
and get no comment. Existing notices still finish when a PR becomes exempt, as
long as its Changelog comment on the pull request is still there: without that
comment the bot does not look for a notice of an exempt PR (see the last row of
the table below). A
notice cancelled by draft stays unchanged on ordinary scheduled runs; marking it ready
starts a full week from that ready run. A broken posted note shows a short pause
in Discord with any holders above it; its exact repair instruction stays on GitHub.
Only `dirty` mergeability is called a clash. Other states and declined merge calls
use a neutral waiting message, with the actual developer state on the PR.

Persistent lookup/access instructions appear on the PR, not as operational alarms
in Discord. Actual channel-history 403/404 reports that the channel cannot be read;
a hint failure or bot-identity failure does not make that claim. A truly deleted
notice requires a fresh draft → ready transition and a full new week. Duplicate
notices require preserving the original and resolving any objection on a duplicate
before removing it. Reads that fail before publication preserve prior outputs. A confirmation read
that fails after publication may leave the changed notice and its new deadline
already written; its pending approval baseline prevents early approval on retry. Write failures
report missing Send Messages/Embed Links. Discord 429 honors one numeric retry
from zero to five seconds; otherwise the operation fails for a later run. An
unexpected per-PR error logs only the PR number and error type, continues the
sweep and fails Actions without leaking unknown response text.

## Failure messages and recovery

These messages appear in the PR mirror unless the row names Actions or the note
check instead. Restore access or data, then let the next run retry; do not shorten
the recorded week. Unknown service exception text is never copied into a comment.

| Message or stable prefix | Way out |
| --- | --- |
| `Start the description with the Changelog note markers` | Restore the template's opening markers; exact instruction is in the mirror/note check, while Discord stays paused. |
| `Fill in What changed and Why` | Supply both labelled paragraphs in the opening note. |
| `Replace the template text with a real note` | Replace short/template/placeholder text with a real explanation. |
| `Changelog note exceeds 1100 characters after escaping; shorten it` | Shorten the explanation until its escaped form fits. |
| `Changelog cannot read this channel` | Restore View Channel and Read Message History; verify the configured channel. |
| `Changelog cannot write to this channel` | Restore Send Messages and Embed Links; verify the channel. |
| `Changelog cannot add the stop buttons` | Restore Add Reactions and channel access; the next run adds missing seeds. |
| `Changelog cannot read the stop reactions` | Restore channel access so every normal and super stop can be read. |
| `Changelog cannot read the approval reactions` | Restore channel access so normal and super thumbs can be read; no unread approval counts. |
| `Too many approval reactions` | Ask the owner to inspect the notice and resolve/clear excess reactions with a moderator if necessary; the bounded read must succeed before proceeding. |
| `Too many stop reactions` | Ask the owner to inspect the notice and resolve objections; do not discard a stop to bypass the wait. The bot cannot proceed beyond its bounded reaction pages. |
| `The saved review record is damaged` | Restore the original bot-owned notice/record, or close this PR and open a new one with a full week and unresolved objections explained. |
| `More than one notice exists` | Keep the original, resolve objections on any duplicate, then remove the duplicate without abandoning a hold. |
| `There are too many messages to find the original notice safely` | Close this PR and open the change as a new PR; its notice gets a full new week. Prefer a channel where people mostly react. |
| `The Discord notice was deleted` | Mark the PR draft, then ready again; the new notice starts a full week. |
| `Duplicate Changelog comments` (Actions) | Keep one original mirror and its correct pointer; remove extra mirrors. The bot cannot safely choose a comment to overwrite. |
| `Stop reactions changed during the read; retry safely` (Actions) | Counts showed a stop but its user list disagreed; wait for the next complete read. An inconsistent read never clears a veto. |
| `Notice changed during the final read; retry safely` (Actions) | Let the next run re-read the original bot-owned record; a changed or missing version/approval baseline never authorizes an early merge. |
| `Approval reactions changed during the final read; retry safely` (Actions) | A 👍 was added or withdrawn while the approvers were being listed. Nothing merged; the next run lists them afresh. |
| `Notice too long; holding` (Actions) | Shorten the note/title as applicable; have the owner inspect a bloated saved record. Never trim the record to move a deadline sooner. |
| `GitHub mergeable_state is …; mergeable is …` | The mirror names the actual final-read state. Wait for recalculation or fix the repository rule/approval/update requirement; only a dirty state indicates a conflict. |
| `GitHub declined the merge` / `GitHub has not accepted the merge` | Check repository rules and merge-account permissions; keep the existing deadline and let the bot retry. |
| A notice still says `Goes live` for a change that was retargeted, reduced to tracker files or finished, and the PR has no Changelog comment | The comment was lost or deleted before the PR became exempt, so the bot no longer follows that notice. Nothing can merge from it. Ask a server moderator to delete the notice. |
| `MERGE IDENTITY INCIDENT` | The mirror and failing note check name the wrong raw author on main. If Changelog merged it, set mode `post` and check whose token it is. Investigate the commit; detection cannot undo it. |

Missing/off/unknown mode, missing credentials/channel, invalid API data, HTTP
failures, pagination limits and unexpected per-PR errors are Actions failures.
Correct configuration or restore service access and rerun naturally; reads that fail before publication preserve that PR's outputs. Interrupted
publication confirmation keeps approvals invalid until a later run establishes
the baseline; it does not restart an already published deadline. A draft with an invalid note gets the
repair instruction in its note check before any initial Discord post. A failing
or missing automatic test after the week is named in Discord; repair CI rather
than waiving the check.

## Offline proof and live smoke

Use **CPython 3.12**. Stateful service fakes forbid sockets; no token is needed:

```sh
python3 ops/changelog/test_changelog.py
CASE_REPORT="$REPORT_DIR/changelog.json" python3 ops/ci/unittest_report.py ops/changelog/test_changelog.py
python3 ops/ci/test_delivery_gate.py
python3 .cycle/trackers.py lint
```

The manifest requires every bot test and report. The delivery gate pins both new
workflows without weakening existing assertions. Evidence includes service
lifecycles, real saved check shapes, ten controller mutations and both reviewers'
workflow mutations. Live smoke must still prove environment isolation, actual
Discord permissions and layout, reaction access, check association, queue behavior,
API usage and a real seven-day post/hold/release/update lifecycle. The first
permitted automatic merge must prove PAT attribution and main CI triggering as
specified above. No fake result is claimed as a live service observation.
