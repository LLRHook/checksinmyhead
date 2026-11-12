# Changelog

Changelog tells Billington's friends and testers what an app change does and why,
then gives everyone **seven full days** to stop it. Going live means squash-merging
to main; main's existing CI owns delivery to an app build.

Authors open drafts and keep the opening note current. The driver or owner marks
a change ready after green checks and independent review. Only text between the
markers in [the PR template](../../.github/pull_request_template.md) is forwarded.
Missing, template or overlong text fails **Changelog note**, including while draft.
The escaped note must fit 1100 UTF-16 units; shorten it rather than truncate it.
Drafts have no initial Discord post.

## What friends see

One embed contains the clickable PR title, explanation and status; there is no
separate message text, footer or bare URL. Waiting notices say “Goes live” with a
local and relative date and invite people to stop it. A merged notice says “It's
in. You'll see it in the next app build.” Final, draft and overdue notices have no
deadline. GitHub's comment uses written UTC dates instead of Discord time markup.

Tap **🛑** to hold indefinitely. Every person's or other bot's normal or super stop
reaction counts; only Changelog's own seed is ignored. Every holder must release.
Removing a stop leaves the original deadline intact. **👍 never shortens the week.**
Holds are polled hourly and immediately before merging. Up to eight names and their
first-observed hold times appear, without mentions or IDs. Discord provides no
reaction timestamp; open its reaction list for all holders.

If a holder leaves the server, a moderator with **Manage Messages** can resolve the
objection and remove the reaction. Changelog does not get that permission.
Otherwise close this PR and open a new one, explain the unresolved objection, and
wait a full new week. A reaction arriving after the final read but before GitHub
accepts a merge remains an accepted cross-service window.

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
read failures, rate limits and timeouts leave that PR's notice, checks, mirror and
clock untouched; other PRs proceed and Actions fails for a later retry.

A merge requires an open, ready, unheld PR, GitHub's clean mergeability, exact-head
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
   secrets and branch restrictions apply without hourly deployment objects.
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
hand.” The owner/driver manual path still requires the full week, no holds and
green checks; agents do not perform it. A person's merge gets an ordinary final
notice; its author is not audited by this bot.

The GraphQL mutation uses **SQUASH**, `expectedHeadOid`, Victor's `authorEmail`,
headline **`<title> (#<number>)`**, and an empty body without co-author trailers.
Every bot merge reads the raw Git author. A wrong author fails Actions, the note
check and the PR comment; Discord still shows the ordinary merged notice. Set mode
off and investigate main. Detection cannot undo a merge. Relevant references:
[GraphQL input](https://docs.github.com/en/graphql/reference/input-objects#mergepullrequestinput),
[PAT permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens),
[workflow triggering](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[environment syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idenvironment).

## Runs, state and recovery

Each event handles **only its event PR**. The hourly run at minute 17 sweeps open
PRs and closures from the last **24 hours**, stopping before old closures. A closure
missed for longer than a day needs manual notice cleanup. Both workflows retain
`queue: max` and never cancel a running job. Fork events use an isolated run-ID
group and are skipped. GitHub permits up to 100 pending runs; ordering and schedule
timing are best effort. The next hourly sweep catches dropped/failed events.
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
**6 GitHub / 4 Discord requests**; a sweep of ten open PRs costs **62 / 31**. An
hour with 15 such events plus that sweep costs **152 / 91**, with no unchanged
notice edits or reaction writes. The older regression with 300 old closed PRs,
seven open and 500 unrelated messages costs **44 / 22**, also without writes.
Initial creation needs one message POST and two seed reactions. Returned Discord
metadata is ignored when comparing the single embed the bot set.

The authoritative record is compressed into the title link fragment, with its
clock, ready transition, change identity and observed holds. A writer editing the
PR comment can corrupt the hint or delay recovery, but cannot move merging sooner:
clock data comes from the bot's Discord record, clamped to the actual message time;
GitHub supplies the current PR, timeline, change and checks; Discord supplies holds.
Injected holder-name text cannot replace the last anchored pointer. Bot-token
holders and writers to main remain privileged trust boundaries. Do not edit the
hidden record to shorten a deadline.

Persistent lookup/access instructions appear on the PR, not as operational alarms
in Discord. Actual channel-history 403/404 reports that the channel cannot be read;
a hint failure or bot-identity failure does not make that claim. A truly deleted
notice requires a fresh draft → ready transition and a full new week. Duplicate
notices require preserving the original and resolving any objection on a duplicate
before removing it. Failed reads do not write or change clocks. Write failures
report missing Send Messages/Embed Links. Discord 429 honors one numeric retry
from zero to five seconds; otherwise the operation fails for a later run. An
unexpected per-PR error logs only the PR number and error type, continues the
sweep and fails Actions without leaking unknown response text.

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
