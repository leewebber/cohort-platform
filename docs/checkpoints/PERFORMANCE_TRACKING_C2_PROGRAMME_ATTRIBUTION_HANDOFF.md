# Performance Tracking C2 — local programme-attribution handoff

**Date:** 2026-10-05. **Status:** LOCAL_IMPLEMENTED_VERIFIED_AWAITING_FOUNDER_REVIEW.
Founder approved the [bounded proposal](../architecture/Performance_Tracking_C2_Programme_Attribution_Authority_Proposal_v1.md): owner-gated combined read and future-only publication retention; legacy scope stays unproven, with no backfill.

## Integration boundary

Repository `/Users/leewebber/Developer/cohort_platform`; branch
`codex/c2-programme-attribution-authority`.
Clean start/proposal commit: `45dc57a14efbcbcce74dfef9c2d17cf5d7ffd355`.
Cached origin/main remained `005d53dc9b822d7e8075c75e5679324b93edebf2`;
no fetch, push or hosted contact in this implementation task.
Implementation commit: `d0fef6d0e9f7ae3420bce3237dab7cc15265c58a`.
The following documentation commit closes this local slice. Integration starts
at the exclusive origin/main base above and includes the preserved proposal,
implementation and documentation: three linear commits, no merges.
Both Sprint C audits and the reviewed C1/independent C2 implementations remain
ancestors. No hosted migrations were applied: recorded hosted ledger remains
115 / 20261005130000, not refreshed here.

| Additive migration | SHA-256 |
|---|---|
| `20261005140000_tracking_publication_artifact_retention.sql` | `b0380ba02c0e778b505019a7dc55e62a7d2c7a7642c4c9b454d5b595a62c4cdb` |
| `20261005141000_tracking_programme_coherent_read.sql` | `8ac03ecbe3c8829bc73d60c2c8c83990e74fbb3c8f6ec03d3a433925fac95dc6` |

## Retention and precise seal meaning

New service-role-only `publish_private_exact_programme_version_retained_v1`
validates compact canonical UTF-8 bytes against the approved SHA-256 and
transport graph, then delegates unchanged private v1/v2 publication. The CLI
uses a separate retention payload builder; existing import builder, canonical
hashes and authored parser remain unchanged. Capture and publication share one
transaction; failed capture rolls the publication back. Retained retries keep
`already_published`; changed bytes or supported authored body conflict. Existing
unretained retries never manufacture artifacts.

`programme_publication_artifacts` retains original canonical text/schema/hash,
server compiler/capture provenance, separately canonicalized scope seal and
seal SHA-256. Clients/service_role have no direct table reads or writes; RLS is
on and normal UPDATE/DELETE is rejected even for the migration owner. Internal
helpers are not client-executable. Capture is future-only through the new
trusted **coach-owned private/org** publication boundary. Original entrypoints
are preserved for compatibility; versions published through other paths remain
unproven until separately authorised retention exists. No global publisher
upgrade or universal artifact admission is claimed.

The seal attests the publication transaction's observed exact protocol ID,
lineage/revision; block UUID/parent/order/type/title/content/format/timer/notes/
capture mode; exercise UUID/parent/exercise identity/order/display label/
prescription/execution group; and persisted slot UUID/key/week/day/order/protocol/
authored-running document. Requested supported bodies must match those rows.
It is a separate publication-time attestation, **not a claim that the existing
package hash covers protocol bodies**, an entire protocol archive, or proof an
assessment was performed. Later supported-body drift makes attribution conflict.
Unsealed legacy versions stay `programme_scope_unproven`; no inferred bytes,
backfill, client-byte upload or hash-string-only authority.

## Owner-gated coherent read and bridge

`read_performance_tracking_programme_history_v1(uuid,jsonb)` is one SQL STABLE
SECURITY DEFINER statement, owned by the trusted migration owner, fixed
`pg_catalog, pg_temp` search path and qualified relations/helpers. Authenticated
EXECUTE only; no PUBLIC/anon/service_role execution or broad table grants. RLS
is not its isolation guarantee. Identity comes solely from `auth.uid()`; exact
owned History is the anchor. Assignment, projection, actual session, frozen
snapshot and correction athlete/actor links are checked explicitly; all result
children follow exact parents. A coach cannot override ownership.

Exact assignment/pinned version/schema/hash, occurrence, outcome, actual-session,
slot/week/day, programmed-session key and completion-record links are compared.
Running claims additionally require exact authored bindings/repetition and owned
frozen snapshot links. Missing links/artifact produce unproven; contradictions
fail. Foreign and absent records return the same bounded failure without evidence
or artifacts. Supplied claims are closed and required; no independent fallback.

The single statement returns the complete raw result tree and correction
membership plus retained artifact/current scope. Limits: 16 KiB claim, 10,000
aggregate result-child/audit rows, 1 MiB canonical artifact and 1 MiB seal,
4 MiB entire response. Oversize fails explicitly; no silent truncation. Row/byte
limits are not a query-latency guarantee.

The unwired typed bridge checks actor continuity, strict envelope/counts/parents,
closed artifact provenance, independently recomputed canonical bytes/hash and
seal digest/body/identities. Artifact-only compiler verification removes the
known generated mapping digest, recomputes it, and requires exact byte equality;
ordinary authored parsing still rejects that generated input. Only then does it
produce the existing typed programme witness and reuse pure History decoding.
No second database request, copied results ledger or production registration.

Tracking remains observational. Programme scope does not prove test completion,
comparison eligibility or B2 prescription eligibility. Historical inputs missing
from old audits remain unavailable; timestamp ties do not establish commit order.
`canReconstructHistoricalInputs` and `grantsPrescriptionEligibility` remain false.

## Verification in this task

- Focused root tracking, bridge and private-publication compatibility: **152 tests passed**.
- Compiler golden/v2 authored-running/B3 mapping/UUID/retained transport tests: **32 passed**; original v1/v2 golden bytes/hashes unchanged.
- Changed-file analysis: **11 Dart files, zero issues**.
- Disposable local DB gate: **PASS**, including migration replay, synthetic v1/v2 capture, retry/body conflict/immutability, forced capture rollback, legacy no-backfill, exact and invalid scope claims, owner/foreign/coach isolation, denied direct SELECT, foreign audit rejection, 1,001-set completeness and row/byte bounds. Existing independent gate also preserves incomplete audit payloads and tied timestamps.
- Barrier-controlled two-session proof: **three correction/read races and one first-publication/read race passed**. Reads see entire committed before/after frames, never mixed actuals/audits or version/artifact visibility. Existing independent RPC, correction function and original permissions fingerprints remain unchanged.
- Final safety gate: **6 groups passed, 0 failed**. Diff check and shell/Python syntax checks passed. Documentation relative links checked.

Commands: `flutter --suppress-analytics test --no-pub test/performance_tracking/ test/supabase/plan_package_v2_private_publication_test.dart test/supabase/private_publication_migration_test.dart`;
package-local `dart test --no-chain-stack-traces` on the five compiler test files;
`./supabase/tests/run_c2_programme_attribution_gate.sh`;
`./tool/testing/run_phase2_consolidation_safety_gate.sh`; targeted `dart analyze`;
`git diff --check`. No full Flutter suite: ordinary compiler/import behavior is
unchanged, publication changes are confined to the separately tested admin path,
and the new application reader has no consumer. No broader runtime concern was
identified. Disposable DB/workdirs were stopped and removed; repository
`supabase/.temp` and environment files remain untouched.

## Remaining limits / founder review

Local infrastructure only; integration and hosted deployment require separate
approval. The [independent deployment record](./PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md)
continues to describe the only deployed reader. Its recorded permissive hosted
training_sessions grant/RLS discrepancy is neither refreshed, repaired nor used
as intended authority. Local owner-gated proof works while direct SELECT is denied.
Normal immutability and hashes do not defend against an out-of-band privileged
administrator changing database authority. No claim of general legacy recovery.

No real publication, athlete/programme changes, production consumer/UI, profile
storage, manual entry, scoring, calculation, prescription policy, benchmark
ingestion or next slice. Stop for founder review; no push.
