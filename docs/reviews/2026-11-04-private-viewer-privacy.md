# Private viewer privacy — November 4, 2026

BUG-1793644518; approved implementation request
`billington-private_viewer_privacy-20261104-v1`, sole source-writer lease.
Base `566b0610040df847793703eb2c98f79bd8ac8319`, existing program branch/PR #159.
Brief SHA256 `6dc4a225d15c986975c33668e05b6fabc9695866e06a4ba847af0f8462b3125a`.
Local affected-web validation is **GREEN**; independent review/root acceptance and
public post-push checks remain pending. Whole security/integrated/release gates remain
**RED**. The ticket stays in-progress; no CHANGELOG migration or release action.

## Policy and implementation

The viewer serves private links; marketing/search acquisition and policy/contact
ownership belong to the separate site and verification gates. Viewer `/privacy`
remains intentionally absent (PR #149). The [viewer README](../../web-bill-viewer/README.md#private-viewer-privacy)
contains the maintained policy and local verification procedure.

Root metadata supplies generic Billington title/description and noindex/nofollow.
Removing both authorized `generateMetadata` lookups avoids resource names and bearer
URLs in acquisition metadata. Global X-Robots-Tag covers access-required/error
responses; Referrer-Policy is no-referrer. Both shared authorized **read** boundaries
explicitly use cache:no-store, retaining independent Bearer headers/API paths.
Page bodies, writes/member/source authorization, existing links, CSP, image/font
configuration and manual payment handoff are unchanged. No shared cache leak was
established: baseline private page responses already had private/no-store.

Checked installed Next **16.4.5** metadata types and current official
[metadata](https://nextjs.org/docs/app/api-reference/functions/generate-metadata),
[headers](https://nextjs.org/docs/app/api-reference/config/next-config-js/headers) and
[fetch](https://nextjs.org/docs/app/api-reference/functions/fetch) documentation.
Static layout metadata is inherited; no-store controls Next's persistent server cache
and the browser HTTP cache. Crawler directives remain separate from authorization.
No dependency, manifest/lock, hosting-control, backend/mobile or identity change.

## Executed checks and sensitivity controls

Pinned macOS arm64 Node **24.22.2** / npm **11.19.1** from the approved local toolchain.
Ordinary locked `npm ci` completed; manifest/lock bytes are unchanged. `npm run lint`,
full `npm test`, production `npm run build` (including TypeScript), and unsuppressed
`npm audit --audit-level=moderate` passed; audit reported zero vulnerabilities.
Biome only formatted/organized changed source/test files. No downloaded formatter.
Native Vitest JSON preserves all **54 original case identities/multiplicities**;
final **72/72** across six files, zero failures/skips/todos, adds 18 focused cases.

The first focused run had a CSS/PostCSS test-load error (four real read-cache
assertions failed separately). Mocking the unrelated global stylesheet corrected test
setup; that setup failure is retained and is not behavioral red. The corrected
before run executed **18 cases: 13 behavioral failures, five healthy body/access
controls**. Healthy implementation: 18/18. Tests now live in the existing
`src/lib/__tests__` location; the initial before run used `src/app/__tests__` before
that relocation. All original baseline identities are unaffected.

| Deliberately removed guard | Failed / executed | Healthy body controls |
| --- | --- | --- |
| Resource-free metadata (restore original two route metadata lookups) | 4 / 18 | 5 / 5 |
| Indexing metadata + HTTP directive | 7 / 18 | 5 / 5 |
| no-referrer (restore prior policy) | 1 / 18 | 5 / 5 |
| Explicit no-store read options | 4 / 18 | 5 / 5 |

Each removal ran once without changing authorization/predicates, then restored the
exact five production-source hashes. Raw failures/restoration vectors are retained.
After a later test-helper syntax change for scanner compatibility, lint/full72/build
were rerun successfully; this did not change HTTP-qualified production source.
Existing npm optional fsevents script-policy and Vite future-config warnings remain
unsuppressed. No latency/load/heap/retention campaign or timeout relaxation occurred.

## Actual built Next HTTP and browser evidence

Built and ran the maintained Next production server, with an explicit task-scoped
loopback API URL at **build and runtime**. No copied app/checkout or live API request.
Each phase has an owned fresh process group/port and source-after receipt.
Nine HTTP cases cover bill/tab valid, invalid, missing tokens; tab 404, API500 mapped
to its existing 404 fallback, and a Twitterbot valid tab request.

All final cases had title Billington, effective noindex/nofollow metadata and
X-Robots-Tag, no-referrer, generic description and no canonical/OG/Twitter resource
URLs/assets/names/tokens. Error shells include Next's own noindex plus inherited
noindex/nofollow. All retained `Cache-Control: private, no-cache, no-store,
max-age=0, must-revalidate` and existing security headers/CSP protections.
The baseline HTTP run retained 35 failed privacy predicates. Four initial body
control assumptions (exact loading copy and RSC 404 shell) were corrected against
those same hashed raw bytes, without repeating requests or changing privacy checks.
Final HTTP privacy and access controls all pass.

Bill HTTP returns the existing client loading body and bearer client props; final
metadata/SSR makes **zero bill API requests**. Its data/access result is client
rendered. Tab valid body is server rendered with authorized trip/member/settlement
names and manual payment handoff; exactly its three authorized read paths occur.
Invalid tab uses only its authorized tab read, no collections; both missing-token
routes make no API request. An absence assertion over whole HTML/RSC would be wrong.

One owned T3 Electron/Chromium tab followed unmodified-policy test-only anchors from
synthetic private bill pages to the second owned loopback origin. Baseline destination
raw headers included only the source **origin** as Referer; no full bearer URL leak
was observed in that cross-origin navigation. Corrected destination has **no Referer**
and document.referrer is empty. Authorized bill/participant names still render under
a generic browser title; an invalid bill bearer renders Invalid Access Token.
Document visibility was visible; preview's separate visible flag was false. This
proves the observed T3 browser journey, not every browser, OS-window focus, payment
app or a separately exercised same-origin destination. No per-anchor referrer override
or product UI was added. The tab was closed; only the owned groups were terminated.
Fresh PID/start/group/nonce/port checks preceded cleanup; all four owned ports closed
and no live owned process group remained. Next has a 30-minute group watchdog;
fixture/tab execution was explicitly closed within the bounded local exercise.

## Scoped scanner triage, preservation and receipt binding

Gitleaks **8.30.1**, default rules, no baseline/allow-comment suppression: nine changed
web inputs scanned as exact stdin bytes, **zero candidates**, all exits 0.
Semgrep **1.183.0**, pinned local rule revision
`16b9e6d45f10649f6a531ec4838ed9924372c3bc`, JavaScript/TypeScript rules,
203 applicable rules over all eight changed TS/TSX inputs, no nosem suppression.
Seven candidates are retained individually: six inherited English access/error-copy
localization suggestions (unchanged at base), and one mock-test taint false positive:
JSON response serialization reaches the mock object, but calls[index] uses numeric
Array.entries indexes, never serialized object keys. No added dependency/suppression.
Initial strict scan exit3/partial parser warning on the new test's typed import helper
is retained; one syntax-only change to vi.importActual allowed a complete strict scan,
exit0, no parse errors. This is scoped triage, not a whole-repository audit.

All **336 originals**, all **489 tracked paths outside the authorized tracked scope**,
and manifest/lock bytes are preserved. Only BUG-1793644518 changed in the tracker
through the official writer; siblings (including BUG-1793852257) are unchanged.
Existing generated .next/type files were restored; task build outputs/logs remain
only in scratch. The two independent read-only reviews/artifacts/registry fields
are outside this implementation and remain untouched.

Raw evidence is local scratch, not published bearer URLs. The
[qualification binding](/Users/victorivanov/.t3/scratch/2026-11-02-do-you-see-the-checks-a3e558c7/private-viewer-privacy-20261104/qualification-bindings.json)
SHA256 is `5a3749bb16a3eeef6bc6b3d5ff26067e27c4525b5bd3f48d506c0e8d9eb9e84b`; it binds source, full case lists, raw commands, HTTP bodies/
headers, browser observations, build artifacts, removals, scanner reports/triage and
cleanup receipts. Key raw receipt hashes:

| Receipt | SHA256 |
| --- | --- |
| `before-corrected-vitest.json` | `e113b16d87e92be0ac78820199dac83fb508b6b3ed2cb65dcb6509aa2733b0d4` |
| `final-case-accounting.json` | `6347985de6e5bfdfffea855cc0c5c6dff04685d60e06a2b3107d34371a242e94` |
| `removal-summary.json` | `49fb8b2993ac4e60de190f7dacaf6453071e515060c1cca30e1b8ae9b739fd0b` |
| `after-http.json` | `57a35421220face0298018134ae43fa69a4a0b22aad9479a59b0842cc88cc29d` |
| `browser-after-destination.json` | `eebfe438e5458525290568fcfb62a7646bf05d447960e2a9ce6b05f46a23dd7f` |
| `scanner-triage.json` | `f38ffa735e32040563b3afea0fa785516e453be11b4a870d861de59ab4d606bf` |
| `precommit-preservation.json` | `92970ac5ec053319144c20200f7731abd557d8962b978df2048c8bc504b4700d` |
