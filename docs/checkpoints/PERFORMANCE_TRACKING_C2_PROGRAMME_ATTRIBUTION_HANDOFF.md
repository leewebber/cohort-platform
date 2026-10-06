# Performance Tracking C2 — local programme-attribution handoff

**Date:** 2026-10-05. **Current status (2026-10-06):** INTEGRATED_HOSTED_APPLIED_SELECT_VERIFIED; production unwired.
The implementation/review sections below preserve their dated evidence; the deployment closeout supersedes their pending integration/apply wording.
Founder approved the [bounded proposal](../architecture/Performance_Tracking_C2_Programme_Attribution_Authority_Proposal_v1.md): owner-gated combined read and future-only publication retention; legacy scope stays unproven, with no backfill.

## Integration boundary

Repository `/Users/leewebber/Developer/cohort_platform`; branch
`codex/c2-programme-attribution-authority`.
Clean start/proposal commit: `45dc57a14efbcbcce74dfef9c2d17cf5d7ffd355`.
Cached origin/main remained `005d53dc9b822d7e8075c75e5679324b93edebf2`;
no fetch, push or hosted contact in this implementation task.
Implementation commit: `d0fef6d0e9f7ae3420bce3237dab7cc15265c58a`.
Original closeout commit: `f52f9fa07930306e8b163c7285b46ea0f01b87a0`.
The initial implementation integration range starts
at the exclusive origin/main base above and includes the preserved proposal,
implementation and documentation: three linear commits, no merges.
Both Sprint C audits and the reviewed C1/independent C2 implementations remain
ancestors. No hosted migrations were applied: recorded hosted ledger remains
115 / 20261005130000, not refreshed here.

| Additive migration | SHA-256 |
|---|---|
| `20261005140000_tracking_publication_artifact_retention.sql` | `b0380ba02c0e778b505019a7dc55e62a7d2c7a7642c4c9b454d5b595a62c4cdb` |
| `20261005141000_tracking_programme_coherent_read.sql` | `a603d560108cc6a2d75f915e710948951e3a6c9ed5042f371d57af838583931d` |

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

## Initial implementation verification (recorded at f52f9fa)

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

## Pre-integration review — 2026-10-06

**Verdict:** scoped defects fixed; local review gates pass. Stop for founder
integration approval. Started on exact expected branch/clean HEAD
`f52f9fa07930306e8b163c7285b46ea0f01b87a0`, with cached origin/main/base
`005d53dc9b822d7e8075c75e5679324b93edebf2`. No fetch or hosted refresh.
All prior commits are preserved; no amend, rebase, merge or permission remediation.

### Findings and separate fixes

1. **Missing versus contradictory source proof:** a completed History record
   with NULL outcome completion_record_id returned conflict, contrary to the
   approved legacy-unproven contract. Duplicate exact History source blocks
   were likewise labelled unproven rather than an ambiguous conflict.
   `c338472d6378266db0618e2ffa9cf4ddf7e2537d` fixes both. A present wrong
   completion link still fails explicitly. Synthetic authenticated regressions
   cover absent/wrong completion and duplicate source identity. The missing-link
   regression failed before the fix and passed afterward.
2. **Bridge lacked resolved programme evidence:** the response echoed a claim
   plus artifact/seal, but omitted the resolved assignment/projection/occurrence/
   outcome/actual-session links needed for independent bridge validation. SQL
   still checked those joins; no SQL ownership escape was found. A changed
   occurrence echoed in both request and response could nevertheless be admitted
   by a fake reader frame. That regression failed before the fix.
   `7e1b12259a25364cf716d02d308e262d23d92160` returns closed minimal projections
   of those already-authorised rows and the relevant owned frozen-source links,
   all from the original statement snapshot. The bridge now checks every pin,
   parent, athlete, authored order/programmed-session key and completion link
   against History and the independently validated artifact/seal. Missing proof
   remains unproven, contradictions fail, integer types stay strict, and sealed
   exercise row identities cannot repeat across blocks. No extra read, ledger,
   permission, production consumer or historical reconstruction was introduced.

### Authority and publication conclusions

The combined SQL remains one STABLE SECURITY DEFINER statement deriving actor
only from auth.uid(), with qualified objects/fixed path and authenticated-only
execution. All raw child rows follow owned parents; correction athlete/actor/
record/session coherence is checked without silently filtering membership.
The new witness projections come only from those same owner-gated joins.
Foreign/absent records return identical bounded failures; no private artifacts
are returned on failure. The 4 MiB final bound includes the witness projections.
The local gate executes under authenticated roles with direct training_sessions
SELECT denied; hosted permissiveness is not relied on or remediated.

Retention required no code change. Exact canonical bytes/hash, separate supported
scope seal, transactional rollback, retry/body conflicts and normal immutability
were reconfirmed by the affected local gate. Unchanged original entrypoints
create no artifacts for unretained versions; a legacy retry cannot backfill a
seal. Supported live graph drift fails against a retained seal. Protocol bodies
remain outside the original package hash. B2 prescription/ingestion and History
mutation authorities remain unchanged; both eligibility/reconstruction flags
stay false. This does not promise resistance to out-of-band privileged corruption.

### Review verification and final range

Current review verification: **51 affected programme bridge/transport tests
passed**, two changed Dart files analysed with **zero issues**; corrected local
DB/security gate passed, including ownership denial, complete collections,
response bounds, absent legacy artifacts, original entrypoints and immutable
capture/retry/rollback. **Three correction races and one publication race passed**
on the final response contract; no torn committed actual/audit or version/artifact
frames. **Safety gate: 6 groups passed, 0 failed**. Diff and documentation links
checked. Disposable containers/workdirs were removed; repository environment
files and supabase/.temp are untouched.

Reuse the initial 32 compiler compatibility tests and unaffected tracking tests
recorded at f52f9fa: no compiler, canonicaliser, publisher or existing independent
reader/mutation changes in this review. No full Flutter suite or build: no shared
runtime path changed and the reader remains unwired. Failures above were focused
regressions proving defects, followed by passing affected gates.

Reviewed implementation range (exclusive base through second fix):
`005d53dc9b822d7e8075c75e5679324b93edebf2..7e1b12259a25364cf716d02d308e262d23d92160`.
Five linear commits: preserved proposal, implementation, original closeout and
two scoped fixes. The following review documentation closeout is the sixth
commit; final branch HEAD identifies that complete integration tip. Zero merges.
The migration hashes in the table above are final: retention unchanged, new
unapplied combined-read migration updated for these fixes. Previous read hash
at f52f9fa was `8ac03ecbe3c8829bc73d60c2c8c83990e74fbb3c8f6ec03d3a433925fac95dc6`;
it is superseded for any future separately approved local integration/preflight.

Remaining limits are unchanged: future trusted private publication only, legacy
scope unproven, no general historical recovery, no hosted deployment or app
wiring. No real publication/athlete-data writes, selection/manual storage, UI,
scoring or next slice. Stop for founder integration approval; no push.

## Hosted deployment closeout — 2026-10-06

The complete six-commit reviewed range
`005d53dc9b822d7e8075c75e5679324b93edebf2..79e4d9154c6d1dc6f6e69a468e917d6d00186cf0`
is integrated. Both exact migration hashes above were applied to Cohort Field
Manual after clean exact HEAD/origin main, ACTIVE_HEALTHY, ledger 115, unchanged
compatibility/security baselines and exact two-file dry-run guards. **43 SELECT-only
postchecks passed**, ledger **117 / 20261005141000**, exact function bodies/security/
grants and artifact immutability metadata; all 24 evidence counts/digests unchanged,
zero retained artifacts, unchanged existing authorities and permission discrepancy.
Final health ACTIVE_HEALTHY and dry-run up to date. CLI cache warning independently
verified; no bypass. Disposable files removed; repository supabase/.temp unchanged.
See [deployment record](./PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_DEPLOYMENT.md)
for hashes, source/authority digests, baselines and limitations. No tests/builds
rerun, production wiring, publication/backfill, athlete writes, permission widening
or next slice. Documentation committed locally; stop before push.
