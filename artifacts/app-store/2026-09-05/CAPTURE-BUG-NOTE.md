# Currency display issue discovered during actual simulator capture

Fresh iPhone walkthrough of a saved EUR bill showed a EUR header and item list but dollar symbols on participant shares (for example, EUR 40.70 appeared as $40.70). The campaign therefore uses native USD data throughout and excludes all diagnostic EUR captures from export.

Source inspection identifies the data loss in `SortedParticipantsCard.build` in `mobile/lib/screens/recent_bills/billDetails/bill_details_screen.dart` around line 988: it constructs a reordered `RecentBillModel` without passing `currencyCode`, `usdExchangeRate`, `exchangeRateDate` or `exchangeRateSource`. The model defaults to USD. `ParticipantsCard` does use `widget.bill.currencyCode`; it receives the defaulted currency from the wrapper.

The same file's bill-name editing callback around line 164 reconstructs a model without its currency fields as well. This can temporarily lose currency display metadata after a rename.

No source change was made for this screenshot task. The diagnostic EUR API state and both simulator DB snapshots are preserved separately in the artifact folder. Final USD records were created through the real local API and seeded only after restoring each dedicated simulator's verified empty preseed database backup.

Suggested follow-up for the app owner: preserve all currency metadata when reconstructing saved-bill models, or add a model copy method that preserves unchanged fields. Verify saved non-USD bill header, item list, participant totals, expanded shares and rename behavior agree before making currency claims in a submission campaign.
