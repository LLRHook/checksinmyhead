This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Dependency maintenance

Use Node 24 (see `.node-version`) and npm 11. Install the committed resolution with
`npm ci`. Next is pinned to 16.4.5; the sharp override requires at least 0.35.5.
Keep security patch updates narrow and run `npm run lint`, `npm test`,
`npm run build` and `npm audit --audit-level=moderate` after resolution. Check the
current [Next.js security advisories](https://github.com/vercel/next.js/security/advisories)
and [stable release](https://registry.npmjs.org/next/latest) before release;
successful local checks do not establish the deployed Vercel revision.

## Private viewer privacy

This application serves private bill and tab links and the independently authored
public homepage and complete `/privacy-policy` in `src/app/(public)`. Its canonical
origin is `https://billingtonapp.vercel.app`. The separate legacy public host/repository
is unchanged. PR #149's removed `/privacy` route stays absent.

The root layout supplies a generic Billington title and description with
`noindex, nofollow`. Bill and tab metadata needs no authorized API lookup and contains
no resource names, bearer URLs, canonical/social URLs or resource preview assets.
The default `X-Robots-Tag: noindex, nofollow` covers unknown/error routes. Private
`/b` and `/t` rules also specify `nosnippet, noimageindex`, including access errors.
Only `/` and `/privacy-policy` override the header and metadata to `index, follow`.
These crawler directives do not authorize access or revoke an old link.

`Referrer-Policy: no-referrer` prevents the private page URL from being sent as a
browser `Referer`, including on same-origin navigation. Authorized bill, tab, member
and settlement reads use `cache: "no-store"` for both Next's server fetch cache and
the browser HTTP cache, retaining the per-request Bearer header and existing API
paths. Dynamic private page responses remain private/no-store. Authorized names and
credentials required by client components can still appear in body/RSC data; do not
treat an absence check over the entire HTML as a metadata privacy test.

### Local privacy verification

Use Node 24/npm 11 and the committed lock, with a task-owned synthetic API on loopback.
Set `NEXT_PUBLIC_API_URL` explicitly for **both** `npm run build` and
`npm run start -- --hostname 127.0.0.1 --port <owned-port>`; do not point this exercise
at live hosting. Run `npm ci`, `npm run lint`, `npm test`, `npm run build` and
`npm audit --audit-level=moderate`. Retain full test case identities and raw results.

For `/b/[id]` and `/t/[id]`, request valid, invalid and missing-token links from the
actual production server. Inspect response headers and parsed title/robots/canonical/
Open Graph/Twitter tags separately from the body. Require generic metadata,
noindex/nofollow, no-referrer and private/no-store, including tab not-found/API-error
responses. Missing-token pages must make no resource request; an invalid tab token
must not load its member/settlement collections. Valid tab names remain server
rendered. Bill data loads in the client: HTTP returns its loading body and client
props, then the browser must show the authorized bill or access error. No bill API
request is needed to construct its metadata.

In one owned browser tab, follow a test-only anchor from a synthetic private page
to a second owned loopback origin. Record the destination's actual request headers
and require no `Referer`; do not give the anchor its own referrer override. Keep
the existing CSP, images/fonts, body authorization and manual payment handoff intact.
Retain before/healthy/guard-removal failures and restoration hashes, then stop only
the exact owned process groups/ports and close the owned tab. Local evidence is not
deployed-hosting, whole-security or release acceptance. See the
[dated implementation evidence](../docs/reviews/2026-11-04-private-viewer-privacy.md).

## Maintained public pages

The public layout and pages render complete semantic HTML without JavaScript or an
API. Keep Inter/JetBrains Mono and existing teal/light/dark tokens; public CSS stays
scoped. The labeled receipt is a static example, not customer data or a simulated
payment. Every download action opens `https://apps.apple.com/app/id6746379502` directly.
Payments are external and paid status is manual. Contact links are exactly
`mailto:checkmateapp@duck.com`, without link/token prefill.

Each public document owns its canonical/title/description/social cards. A static
1200×630 brand image is served at `/social-image.png`; only the homepage emits
escaped SoftwareApplication JSON-LD. `robots.ts` allows crawling (including private
noindex responses) and advertises `sitemap.xml`, which contains only home and policy.
Do not move canonical/social metadata to the private root or enumerate API records.

After the locked checks, run the standard-library verifier against an owned local
production server (never customer URLs):

```bash
python3 ../scripts/verify_web_routes.py --base-url http://127.0.0.1:<owned-port> \
  --output <new-evidence-directory> --fixtures <owned-fixture-records.json> \
  --api-log <owned-api-requests.jsonl> --build-dir .next
```

The verifier checks actual public HTML/cards/CTAs/schema/robots/sitemap/image and
alternating private HTML/RSC capabilities. It neither starts nor replaces the real
Go/PostgreSQL fixture or headed browser walkthrough. Fixture JSON has a `records`
array with `kind` (`bill`/`tab`), `id`, `label`, `name`, `token`, and optional
`visibleName` for historical lazy tabs whose existing heading shows the receipt.
The API-log option expects owned JSONL method/path/query/headers/status observations.
Retain raw failures, no-API/JavaScript-disabled checks, error cases, browser and cleanup
evidence separately; see [current scoped evidence](../docs/reviews/2026-11-05-public-web.md).

The Settings source points to the canonical `/privacy-policy`. Serve and verify
that route before shipping a client that depends on it. Reconcile actual released
flows, establish an operative notice date, verify mailbox control and complete store
privacy/destination review separately. The page contains no preparation-date claim.
Source implementation does not change provider settings, logs, the legacy host,
App Store metadata, entitlements or custom-scheme behavior.

## Getting Started

From the repository root, prepare explicitly, then start the backend and viewer:

```bash
./dev.sh setup --no-mobile  # npm ci; create only missing local env examples
./dev.sh --no-mobile        # PostgreSQL/API + Next.js, no dependency installation
```

For manual startup after setup, run `npm run dev` here and open
[http://localhost:3100](http://localhost:3100). The package script fixes that port.
Keep `NEXT_PUBLIC_API_URL=http://localhost:8080` in `.env.local` for the local API;
existing files are preserved. The root script refuses occupied ports, waits for HTTP
readiness, retains private per-run logs, and stops its exact npm/Next process group on
exit. See the [root workflow](../README.md#quickstart). Next.js is the maintained
bill and tab viewer; the legacy Go renderer has been removed.

Edit the public homepage in `src/app/(public)/page.tsx`; keep bill/tab body and
capability transport in their existing owners.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
