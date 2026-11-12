# Currency support matrix and display immutability — 2026-11-09

Scope: BUG-1793644515 on branch `sweep/mobile-currency` (`e0a2c18` base). Tests and
documentation only; no production code, currency set, provider or schema changed.
The ticket stays `in-progress`: whole-yen accounting needs an owner decision (below)
and combined, signed rollout evidence is outside this repository.

## What Expected still lacked

| Expected | Found | Added |
|---|---|---|
| One approved support matrix | The rules were correct but spread over prose in two documents | [Currency support matrix](../backend-api.md#currency-support-matrix) in the API contract, linked from the technical overview. It records the approved twelve receipt codes and existing behaviour; it approves nothing new |
| History cannot be overwritten by display conversion | Reads and finalization were proven against stored rows; live display conversion and a changed trip display currency were not, and never with a moving rate | `TestPostgresDisplayConversionNeverRewritesFrozenQuote` (PostgreSQL, production router) |
| Identical service instances, distinct adapters | Already true: `newCurrencyHandlers` gives one `exchange.Client` to creation, USD preview and display; there is no cache to share (approved no-TTL decision) | The matrix test counts provider calls per request on that one client |
| Tests: supported non-USD, same currency, ambiguous/PEN, outage/cache, immutability | Present except: same-currency and malformed codes on the live route, success-then-outage with no stale answer, and the mobile trip display | `TestProductionCurrencySupportMatrix` (5 subtests) and mobile `tab_display_conversion_test.dart` |

Already present and unchanged: the twelve codes through production composition
(`TestProductionCurrencyComposition`), independent display pair and source
(`…DisplayHasIndependentPairAndSourceOwnership`), failures never persisted
(`…QuoteFailuresNeverPersistOrLeak`), the mobile rate decoder, and the scan
confirmation cases for an ambiguous `$` and for PEN (`save_receipt_widget_test.dart`).

## Evidence

- `go test -race -count=1 ./cmd/bill-service -run '^TestProductionCurrencySupportMatrix$'`:
  5 subtests pass. PEN is created and previewed as a receipt currency; ZAR is quoted
  for display and refused (400) as a receipt currency with no provider call; eight
  requests across a healthy, failed and recovered provider make eight provider calls
  and the failed ones return 503 with `Retry-After`, never the earlier 1.25.
- With the shared fixture DSN,
  `go test -race -count=1 -tags=integration ./cmd/bill-service -run '^TestPostgresDisplayConversionNeverRewritesFrozenQuote$'`:
  pass. An EUR 20.00 receipt frozen at 1.25 with a ZAR display stays byte-identical in
  `bills`, `bill_items` and `person_shares` while live rates move to 1.31 and 23, the
  provider returns 503, the trip's display currency becomes JPY and the trip is
  finalized. The settlement is 25.00. Six provider calls: two at creation, three live,
  one failed.
- `flutter test --no-pub test/tab_display_conversion_test.dart`: pass. A trip showing a
  frozen USD 31.25 in PEN follows a live rate (4, then 3.2), shows "PEN conversion
  unavailable" during an outage with no amount, asks the server once per visit and
  leaves the stored receipt row unchanged.
- Removal controls, source restored after each: replacing PEN with ZAR in the receipt
  policy fails two matrix subtests; a trip display change that also updates its
  receipts fails the PostgreSQL case at the first read; dropping the mobile
  unavailable guard fails the mobile case.
- A read-only check of the public provider on 2026-11-09 returned 200 for PEN/USD,
  JPY/USD and EUR/ZAR and 422 for an unknown code.

Whole rows after the change: `gofmt`, `go vet` and tagged `go vet` clean;
`flutter analyze` clean; full `flutter test --no-pub` 604 visible cases pass and the
collector accepts the report against the manifest; gate controller 42 methods pass.
Ordinary `go test -race -count=1 ./...`: 1207 terminals pass and 2 fail, both
`TestServiceHealthcheckMode` (parent and `bill-service` child), which cannot bind
127.0.0.1:8080 on this host because another project's container owns the port. That
case is unrelated and unchanged, and the row is therefore not green here. A tagged
selection of the new and neighbouring currency and identity families passes 34
terminals. The full eight-package PostgreSQL row was not run here.

## Decision needed: whole-yen accounting ("versioned JPY step")

Today every currency is split in hundredths. A JPY receipt can therefore store and
show shares such as JPY 333.33, which do not exist as money. USD settlement is not
affected: it uses the frozen USD cents. PEN needs no decision: it is in the approved
receipt set, both mobile selectors and the provider.

| Option | What changes | Cost and risk |
|---|---|---|
| 1. Keep hundredths for JPY and say so | Nothing in code; the limitation is documented | None. Yen shares can show two decimals |
| 2. Versioned whole-unit accounting for JPY | New receipts in JPY are entered, split and stored in whole yen; existing JPY receipts keep their stored fractional values under the old version | A new accounting version on the frozen creation contract, a per-receipt version marker (migration), server allocation, mobile entry and formatting, web formatting and shared fixtures. Old and new clients must agree, so it rides on the rollout gates |
| 3. Withdraw JPY from the receipt set until option 2 exists | JPY can no longer be selected for new receipts | Small change, but it removes a currency users can pick today and still leaves existing JPY receipts fractional |

Recommendation: **option 1 now, option 2 as its own feature** once the current
contract is rolled out, since it is a versioned change to a frozen contract plus a
migration and three clients. Do not take option 3: it shrinks the approved set without
fixing anything already saved.

## Still open on this ticket

The JPY decision; the odd-cent rule under BUG-1793644500; identity under
BUG-1793644505; combined and signed rollout evidence.
