# Driver acceptance of server replay/display0002 — November 4, 2026

**The bounded server source and clean Go correctness/security gate are accepted.**
Whole security, performance, integrated and release acceptance remain RED. This
record changes no production schema, hosting configuration or client release.

Source implementation is `a47eeca727807e485a5be891e8405f0d27cd4673`, published
through `865b8978a2f7b6cb0d82ccf45a253aa1e93a8e63`. Later changes at that published
head affect only evidence, tracker fields and timing descriptions. All158 final
application/image input hashes still match the reviewed implementation and both
qualified static image labels. All three commits have personal Victor Ivanov
author and committer identities; published ancestry is preserved.

The independent exact51-path review approves Standards and Spec with zero
findings. Reviewer execution was NOT RUN. Driver evidence below is separate from
that source review and from the owner's local qualification.

## Fresh committed-snapshot execution

The driver created its own isolated worktree of published865b8978, used pinned
Go1.27.3 with GOTOOLCHAIN=local and read-only modules, and executed the affected
maintained matrix once. PostgreSQL used the existing dedicated loopback PG17.11
fixture and strict random-schema harness. No application cache, source edit,
customer/provider request, normal-volume reset or additional replay measurement
was needed.

| Check | Actual result |
| --- | --- |
| Formatting, build, vet and mandatory integration vet | Pass |
| Ordinary uncached race/JSON suite | 905 leaves,1000 test nodes;0 failed/skipped/cached/missing/duplicate cases |
| Full mandatory8-package PostgreSQL race/JSON suite | 843 leaves,926 test nodes;0 failed/skipped/cached/missing/duplicate cases |
| Leaf overlap / distinct cases | 480 /1268;1748 leaf occurrences |
| Owner case-set comparison | Exact match for both selections; all prior1146 leaves and1268 prior raw nodes preserved |
| Pinned govulncheck@v1.7.0 | Pass; no reachable finding reported |
| Source-before/after and tracked state | All158 inputs unchanged; committed snapshot clean |
| Cleanup | All304 generated schemas absent;0 owned named sessions; QA worktree removed |

The same two explicit ordinary packages have no test files; neither is a skipped
test case. All four historical numerical parents/children ran in the full
mandatory command, preserving their actual sample counts. Their33 numerical
output rows remain in the raw evidence. Authorization uses10 creation and10
attachment observations per fixture, rather than3x100.

Raw driver records are retained in scratch `backend-replay-driver-clean-865b8978/`;
result SHA256 `8b21b1867d23f2030f6169655aebe8869cd5eaf9f84d487a2faf76080301a8cf`.
The separate root clean-acceptance receipt records fresh schema/session absence.

## Attributed qualification and limits

The owner separately proved15 meaningful guard removals, actual uncertain COMMIT
and recovery over HTTP/TCP/PostgreSQL, winner-only complete graph creation,
rollback and old/new actual0002 compatibility. Final-image runtime checks pass
75/75 with the approved private exact1,2 registry expectation and pinned compiler
acquisition adapter. This is attributed owner execution; root verified its source,
binary/image bindings, receipts and retained raw results.

Root independently parsed the owner's sole approved48x100 observations. The
selected fixed targets hold: keyed creation7/16 data statements, established
replay1 indexed scalar read with0 providers/writes/transaction, all4 actual plans
using the digest index, and no selected latency/noise-rule miss. These are native
in-process HTTP, loopback PG and synthetic-provider observations. They are not a
production/cold-start result or a general performance pass. Historical concurrent
race-instrumented unkeyed maximum-USD p95 values225–232ms remain disclosed in their
different context; faster non-race keyed measurements do not erase them.

ProviderNS measures WroteRequest-to-first-response-byte only. ApplicationNS is
total elapsed minus that interval, not CPU. TransactionHeldNS covers BEGIN through
COMMIT/ROLLBACK, not only row locks. Preserve these labels when using the evidence.

The original runtime unavailable-DB1.619804s versus<1.5s remains RED/flaky. The
separate50,000-update latency gate remains RED/unselected. Mobile retained-memory
qualification, durable save/checkpoint/Keychain work, stable identity, precision,
allowanceB, old-writer drain, production adoption/restore, signed-client and clean
integrated journeys remain open. Old binaries demonstrably ignore keys; neither
health nor capability reporting proves their exclusion.

One token-free post-push viewer request returned200/access-token-required with
private/no-store controls; the API health request timed out. These establish no
feature-branch deployment identity. No authenticated Vercel/Render action, live
SQL, paid inference, merge or store publication occurred. BUG4500/4515 stay
in-progress; no CHANGELOG migration or Verified entry follows.

Doc impact: this new acceptance supplement and scoped tracker references record
driver execution. The existing API/architecture/replay procedure already describe
the source change; prior dated reports and VERIFICATION/Last verified are preserved.
