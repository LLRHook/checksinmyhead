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

This application serves private bill and tab links. The public marketing and policy
site lives in a separate repository; its search acquisition policy does not apply
here. PR #149 intentionally removed the viewer's `/privacy` route. Privacy disclosure
destinations and contact ownership remain separate verification obligations.

The root layout supplies a generic Billington title and description with
`noindex, nofollow`. Bill and tab metadata needs no authorized API lookup and contains
no resource names, bearer URLs, canonical/social URLs or resource preview assets.
The global `X-Robots-Tag: noindex, nofollow` also covers access-required and error
responses. These crawler directives do not authorize access or revoke an old link.

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
exit. See the [root workflow](../README.md#quickstart). The legacy Go renderer on
8081 is retained under the explicit `legacy-web` Compose profile.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
