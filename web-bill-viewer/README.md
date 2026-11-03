This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Dependency maintenance

Use Node 24 (see `.node-version`) and npm 11. Install the committed resolution with
`npm ci`. Next is pinned to 16.4.4; the sharp override requires at least 0.35.5.
Keep security patch updates narrow and run `npm run lint`, `npm test`,
`npm run build` and `npm audit --audit-level=moderate` after resolution. Check the
current [Next.js security advisories](https://github.com/vercel/next.js/security/advisories)
and [stable release](https://registry.npmjs.org/next/latest) before release;
successful local checks do not establish the deployed Vercel revision.

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
