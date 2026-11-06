# Complete finalization-row conversion checkpoint

This change continues BUG-1793644504 from base `f4abc78`. Finalization keeps its
two complete, scoped, ordered `FOR UPDATE` reads and the same transaction, context,
accounting, paid guards and stored retry. Private typed `database/sql` conversion
replaces GORM's reflected field conversion. All 23 participant and 11 share columns
remain; nullable references/timestamps, SQL/JSON null, allocated empty item arrays,
unknown JSON fields and nullable paid behavior are preserved. Query, scan, JSON,
iteration and close failures retain their causes and abort before grouping/writes.

The initial source-only review found one P2 test regression: SQL assertions observed
direct helper calls rather than `FinalizeOnce`. The corrected test keeps its observer
over actual finalization. A controlled actual-path lock fault passes the predecessor,
fails the corrected guard, and passes with the correct reader. An independent manager
recheck approved this exact correction; reviewer application execution was NOT RUN.

Source-bound focused evidence covers 50 distinct Go leaves. The changed rollback
parent's eight cases include both query-cancellation/closure-before-rollback checks.
Seven independent reader removals produced 18 intended failing and 14 healthy leaves.
The original control wrapper's error-wording failure remains recorded separately from
its independently reconciled seventh result. No historical result was rewritten.

Physical-source verification passed Go 1.27.3 build, vet, integration vet and format.
Gosec 2.30.0 analyzed the maintained files under normal and integration builds, without
loader errors. An unused MD5 source canary produced G401/G501 and was restored
byte-for-byte before final analysis/build; it was never executed. Raw final exits
remain 1: two normal and three tagged candidates. The three unique sites are synthetic
victim snapshot equality checks (G117, original lines 89/103) and intentional GORM
error injection (`AddError(marker)`, G104, current line 252). No new production
vulnerability was confirmed; no suppression was added. This is scoped analysis.
Current four-file Semgrep and package secret scans reported zero findings.

The report controller passed 42 methods / 910 records. Five ordinary test families
are required in both default and tagged reports; one extra PG oracle is tagged-only.
Every inherited obligation and non-row manifest field remains. All 42 old methods
and their per-family multiplicities remain; the manifest-family proof gains 11
records. Cross-run generated subtest ordinals/synthetic Git identities differ, so
no exact cross-run raw-ID equivalence is claimed.

All owned static groups ended and the temporary controller environment was removed.
PG correctness/control fixtures were separately audited absent; shared PG and normal
volumes were preserved. Raw commands, bindings, triage, controls and independent
reviews are retained in the task scratch `complete-row-scan-{candidate,correction,
physical-integration}-20261105/` packets.

**Full acceptance stays RED.** Candidate performance has not been measured and no
improvement percentage is claimed. Current full ordinary/mandatory PG, rebuilt images,
runtime and unchanged numerical gates still need qualification. Retain the hosted
startup 60-second build failure, creation/tab 600-second alarms, 750-ms tab misses,
separate 50,000-update/JSON/resource gates and receipt-I/O full-row failures. This
checkpoint does not establish old-reader/writer safety, rollout, source completion of
identity clients/self participation, release acceptance or tracker migration.
