# Next.js 16.4.5 security patch — November 4, 2026

Owner: Billington implementation lead (`billington-next1645_implementation-20261104-v1`).
Base: `85fafc678709d8506dbc36bc34d5d0813eeb12dd`, program branch, BUG-1793644502.
Authorization: supplied `NEXT1645_PATCH_APPROVAL.md`, fresh implementation brief and
exclusive writer lease. This is affected viewer validation in the shared checkout;
independent clean acceptance is pending. Whole security/integrated/release acceptance
remains **RED**; B+/A− is a target.

## Current primary sources

Rechecked at 04:39 UTC. The [stable registry](https://registry.npmjs.org/next/latest)
reports 16.4.5. Exact-version registry metadata for Next, `@next/env` and eight SWC
packages agrees with every candidate tarball URL and integrity value. Next requires
Node >=20.9.0 and accepts React/ReactDOM ^19.0.0, compatible with retained 19.3.0.
The [official v16.4.5 tag](https://github.com/vercel/next.js/releases/tag/v16.4.5)
lists seven advisory links under Moderate.

The [November release article](https://nextjs.org/blog/november-2026-security-release)
names 16.4.5, describes one High and six Medium issues, and links six GHSA IDs. Web-tool
fetch failed; a separate unauthenticated HTTP fetch succeeded with status 200 and was
saved. The article and tag disagree on severity grouping/link count. Only two individual
advisory pages were fetched: [SVG optimization](https://github.com/vercel/next.js/security/advisories/GHSA-7qx7-33qx-rqx2)
and [Edge cookies](https://github.com/vercel/next.js/security/advisories/GHSA-f3mh-rxg3-f5g2).
Both currently show affected 16.x through 16.4.2 and no patched-version field value.
Preserve these observations; do not infer complete advisory-feed consistency or
Billington exploitability. The explicit release and approved narrow patch justify
upgrading without waiting for feed convergence.

Checked official [version 16 guidance](https://nextjs.org/docs/app/guides/upgrading/version-16)
(Node/TypeScript requirements, Turbopack) and [Image API](https://nextjs.org/docs/app/api-reference/components/image)
(`remotePatterns`, SVG defaults). Existing configuration remains compatible. Source
search finds `next/image` in BillHeader/TabHeader and configured remote patterns;
no `cacheComponents`, `use cache`, `unstable_cache`, Edge runtime declaration or
`NextResponse` matches in viewer source/config. This bounded search is not an exploit
test, browser journey or security audit.

## Exact dependency delta and binding

Manifest changes only `next: "16.4.4"` → `"16.4.5"`. Lock changes only 11 entries:
root, Next, `@next/env`, eight platform SWC entries. Package sets and unrelated
metadata remain identical. React/ReactDOM 19.3.0, sharp 0.35.5, all overrides,
Node24/npm11 declarations and other resolutions are retained. The approved candidate's
manifest/lock were verified before copying against the current 16.4.4 baseline.
The previously rejected resolver's six unrelated Tailwind WASI additions remain
historical acquisition evidence and are absent from this patch.

| SHA256 binding | Value |
| --- | --- |
| Pre-patch lock | `44afbdd819a2eb0aa5ba35be7aaaaa3e0704d7b4e461086b172e86e8391c36c3` |
| Patched manifest | `6965ed49d51a5fac7905590ca56f374b9de4fc5ba5321d168d98ac53c64e6132` |
| Patched lock | `a20e2a667cc99e66f7700a59a8abb504042399d02d234113b1c445de8362484e` |
| Tracked viewer SHA256 vector (`source-under-test.json`) | `f7312a19669462b4d92c58e61b9203b76fcc508e6ea986540b77b6205a50f934` |

## Executed local checks

Node **24.22.2**, npm **11.19.1**, macOS arm64; PATH explicitly starts with
`/tmp/billington-driver-tools/node-v24.22.2-darwin-arm64/bin`. Telemetry disabled.
Commands run in `web-bill-viewer`; each receipt binds the base SHA, complete tracked
viewer file hashes, manifest/lock hashes, tool versions, exit, time and raw log hashes.

| Command | Result |
| --- | --- |
| `npm ci` | Exit 0; 78 installed, 79 audited, zero reported vulnerabilities; lock byte-identical |
| `npm run lint` | Exit 0; Biome checked 36 files; no fixes |
| `npm test -- --reporter=default --reporter=json --outputFile=<scratch>/vitest.json` | Exit 0; 54/54 assertions across four files; failed/skipped/pending/todo 0; no rerun |
| `npm run build` | Exit 0; Next 16.4.5/Turbopack, TypeScript and production build complete |
| `npm audit --audit-level=moderate` | Exit 0; unsuppressed, zero reported vulnerabilities |
| `npm audit --audit-level=moderate --json` | Exit 0; raw structured report has zero at every severity |

Vitest reporting flags only add the native JSON artifact; selection/configuration are
unchanged from CI's `npm test`. Build output retains dynamic `/b/[id]`, `/t/[id]`
and static `/_not-found`. No changed behavior warranted new application tests.
Every command left tracked viewer files and the approved lock unchanged.

Warnings are retained: npm reported an unreviewed optional `fsevents@2.3.3` install
script; effective `ignore-scripts` is false and subsequent read-only
`npm install-scripts ls --json` reports an empty list. No script-approval setting was
changed. Vitest warned about future Vite native-config compatibility. These were
warnings, not failed tests; no suppression or retry was used. Ordinary `npm ci` under
npm's existing script policy is distinct from the candidate's earlier acquisition-only
`--ignore-scripts` run. Audit zero does not negate the official new security release.

Local gate: **GREEN**, scope=affected, clean=no, base=`85fafc6` plus bound patch.
Backend, mobile, container scans, provider calls, E2E/a11y and integrated protocol:
**NOT RUN** for this dependency-only patch. No hosted/deployed evidence is inferred.

## Documentation, preservation and remaining gates

Doc impact: three keys (`16.4.4`, `16.4.5`, `BUG-1793644502`), 29 living tracked
Markdown files searched; 28 historical/ledger files excluded. The viewer README's
dependency statement was the sole living match and is updated. This dated note adds
current evidence. Existing architecture/API/CLI interfaces and historical records
remain accurate for this change; no other doc edits are required.

Before/after SHA256 checks preserve all **336** original files, including ignored
artifacts and Android files. `VERIFICATION.md` remains 20,478 bytes; baseline,
CHANGELOG and past notes are preserved. Only BUG-1793644502 Fix/Docs fields are updated
through `python3 .cycle/trackers.py`; status remains in-progress. Independent clean
validation, source review, individual GitHub alert closure, current advisory
applicability and root's token-free post-push/deployed-identity checks remain pending.
No Vercel/Render authentication/settings/deployment, live database/customer access,
main/mirror/tag push, merge, store action or external review comment is authorized here.

Raw receipts, JSON test/audit reports, preservation vectors and registry/document
captures are in the supplied task scratch directory under
`next1645-implementation-20261104-v1/`; ignored log copies are under
`.vv/local-gate/next1645-20261104-v1/`. Final commit/push/remote evidence belongs to
the sibling scratch `NEXT1645_IMPLEMENTATION_RESULT.md`.
