# Version policy public-availability gate (BUG-1793644511)

Point-in-time record, 2026-11-09. Source control only; no deploy, App Store Connect
action or production configuration change was made.

## Observed (read-only GETs, 2026-11-09 21:00 UTC)

| Source | Result |
|--------|--------|
| `GET https://billington-api.onrender.com/api/app/version-policy` | 200, `Cache-Control: no-store`, `{"minimum_supported_version":"2.0.3","store_url":"https://apps.apple.com/app/id6746379502"}` (no `capabilities`: an older deploy) |
| `GET https://itunes.apple.com/lookup?id=6746379502&country=us` | 1 result: Billington, `com.checksinmyhead-vng.app`, version `1.4.0`, released `2026-08-26T18:23:06Z`, `minimumOsVersion` `15.5` |
| same lookup, `country=ca` and `country=gb` | identical version, release time and minimum OS |

The served minimum (2.0.3) is above the only public binary (1.4.0). Nobody is locked out
today because 1.4.0 predates the client gate (commit `3b7cc4f`, 2026-10-12). The first
public binary that contains the gate would obey whatever the server says.

## Control

`backend/internal/versionpolicy/public_availability.json` is a reviewed, compiled-in
record of the release each targeted platform/storefront serves. The service serves a
configured `MINIMUM_SUPPORTED_APP_VERSION` only when every recorded release satisfies
it, and otherwise the non-blocking `0.0.0`; the source default is `0.0.0`. The contract
and the two-step raise procedure are in
[docs/backend-api.md](../backend-api.md#get-apiappversion-policy).

The record lists the three storefronts checked above. The full territory list lives in
App Store Connect and was not read: the owner must add any other targeted storefront.

## Evidence

- Regression first: the new handler tests failed on the previous source
  (`source default minimum 2.0.3 exceeds publicly available 1.4.0`;
  `configured 1.4.1 above public 1.4.0 was served as 1.4.1`) and pass with the gate.
- `go test -race -count=1 ./internal/versionpolicy/`: 10 test families pass, including
  an exhaustive grid asserting no served minimum exceeds any recorded release and 23
  invalid-record shapes that each serve `0.0.0`.
- `flutter test --no-pub test/services/version_policy_service_test.dart`: 12 pass.
  Client fail-open is proven for ten non-200 statuses, three transport exceptions,
  twelve unusable bodies and the two-second timeout, and at the splash screen (a 503
  reaches onboarding; a reachable higher minimum still shows the update screen). A
  temporary mutant that ignored status and timeout failed two of these tests.

## Remaining (not provable from this repository)

1. Owner: production still serves 2.0.3 until a build with this gate is deployed. If
   `MINIMUM_SUPPORTED_APP_VERSION` is set on the host, the new build serves `0.0.0` and
   logs the refusal; unset it or leave it until the record supports it.
2. Owner: before raising the minimum for a public 2.x release, update the record from
   live storefront lookups, deploy, then set the variable and re-read the endpoint.
3. Ticket Expected bullet 2: an installed public binary exercising the live API,
   invite and payment compatibility, with version/build/storefront recorded. It needs
   a device with the store binary (1.4.0 today, and the first public 2.x before its
   minimum is raised); it was not run.
