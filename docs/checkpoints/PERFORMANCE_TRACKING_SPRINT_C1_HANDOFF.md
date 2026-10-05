# Performance tracking Sprint C1 — local implementation handoff

**Recorded:** 2026-10-05
**Status:** IMPLEMENTED_LOCAL_VERIFIED; awaiting founder review. C2 not authorised.
**Branch:** `codex/sprint-c1-tracking-contracts`
**Clean authorised base:** `335c768345084d9185b2280026dc53b3b1cb1bd3`
**Implementation:** `ac47f2a` (pure contracts, synthetic tests and domain README).
**Preserved audit commits:** `8347480`, `335c768`, unchanged and linear ancestors.
**Contract:** [revised Sprint C architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
**Audit:** [Sprint C audit](./PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md)

```text
PERFORMANCE_TRACKING_CONTRACT_ARCHITECTURE=FOUNDER_APPROVED
PROGRAMME_METRICS_PROFILE_C1_AUTHORISED=true
PROGRAMME_METRICS_PROFILE_C1=IMPLEMENTED_LOCAL_VERIFIED_AWAITING_FOUNDER_REVIEW
PROGRAMME_METRICS_PROFILE_C2_AUTHORISED=false
PROGRAMME_METRICS_PROFILE_AUTHORISED=false
COHORT_5K_TEST_INGESTION=BLOCKED
PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false
NEXT_IMPLEMENTATION_AUTHORISED=false
```

The broad `PROGRAMME_METRICS_PROFILE_AUTHORISED=false` flag means no authority
for the remaining tracking product, persistence or later slices; C1 alone was
authorised. The founder approved immutable definitions/profiles and explicit
upgrades, versioned custom compositions/selections, references to existing
History actuals/corrections, append-only future manual revisions, no package
changes in C1 and observational tracking without prescription eligibility.
That approval superseded the prior pause for C1 only.

## Delivered boundary

The [pure domain library](../../lib/domain/performance_tracking/performance_tracking.dart)
contains immutable method/metric definitions, curated/custom profile
compositions, athlete selection revisions, measurement/source/revision values,
explicit quality states, standalone assessment references and optional
programme-binding/scope values. There is no production consumer.

- Supported units and extraction/difference **signatures** are closed typed
  contracts; methods are exact ID/version/digest references, not calculations.
- Strict schema-1 tracking JSON rejects unknown fields/vocabulary, arbitrary
  formula/scoring/target fields, invalid types and ambiguous nullable encoding.
  Sorted canonical UTF-8 JSON and SHA-256 cover exact dependency digests.
  Profile display and method argument order remain meaningful.
- Validation requires the caller's full supplied dependency closure. Invalid
  references, duplicate identities, conflicting digests, incompatible units,
  missing context and invalid revision lineage produce deterministic issues.
- Custom composition/selection revisions preserve ownership/predecessors;
  version upgrades require explicit upgrade actions and cannot silently follow
  the newest registry/profile content.
- A History reference identifies record, block-result/source-block, field path,
  optional exercise/set or exact workout/step/repeat, selected-input digest and
  optional existing correction audit ID. History actual values cannot be copied
  into the measurement contract. Source aliases cannot create another observation
  of the same History field for the same athlete/metric version.
- Correction lineage preserves origin/ownership/metric and History event
  chronology. Changed History input digests require a new correction reference.
  Source identity reuse cannot reclassify a result as a test or change programme
  attribution through a correction.
- Manual existing-result values are canonical nonnegative decimal strings;
  observed values are distinct from missing, partial, skipped, unavailable,
  ineligible and incomparable states. Manual entry cannot claim executed test
  or programme completion authority. Corrections are provenance, not an alternate
  evidence state.
- UTC timestamps, civil-date precision, performed-versus-recorded chronology
  and caller-supplied known IANA zone IDs are explicit. Standalone attempts have
  no invented programme links; programme claims require the complete declared
  assignment/occurrence/session and exact scope envelope.

See the [domain README](../../lib/domain/performance_tracking/README.md) for
wire-format and caller obligations. All supplied definitions, profiles, athletes
and procedures in new tests are synthetic; no real catalogue content was added.

## What validation does not prove

Structural consistency is not an authenticated ownership decision, registry
publication approval, live source lookup, freshness evaluation, executed test
proof or prescription eligibility. Supplied programme scopes are declarations;
C1 does not query/attest that referenced content exists. A future supported
adapter must resolve exact field paths/result shapes and detect ambiguous scopes.
C1 cannot discover an undeclared manual duplicate of a History result.

`canReconstructHistoricalInputs` is always false for History sources. Existing
correction IDs plus input digests identify observed source state; they do not
prove complete as-of reconstruction. `grantsPrescriptionEligibility` is always
false for measurement contracts. B2 benchmark eligibility, manual revisions,
Cohort ingestion rejection and frozen target semantics are unchanged.

No metric calculation, derivation engine, source importer, persistence, SQL,
Plan Package field/schema change, UI, standalone assessment execution, scheduling,
real profiles/tests, scoring, programme/assignment changes or hosted operation.
The optional binding artifact format is independent of Plan Package and is not
an implementation of future schema v3.

## Current-task verification at implementation `ac47f2a`

| Check | Evidence |
|---|---|
| Final focused C1 domain tests | **41 passed**, including fixed synthetic canonical/hash golden, round trips, invalid references/duplicates, method/unit compatibility, source field/correction IDs, correction chains, explicit upgrades, chronology, quality states and scope isolation |
| Existing compiler/B2 compatibility | Combined C1 + compiler/benchmark-policy/snapshot/golden run: **79 passed** before the final C1 golden addition; final C1 rerun above passed. Existing compatibility sources unchanged |
| Canonical package compatibility | **25 passed**: v1/v2 golden bytes/hash, B3 mapping, Apollo and Bali canonical hashes |
| Changed-file Dart analysis | All six added Dart files (four domain, two test): **No issues found** |
| Phase 2 consolidation safety gate | Final code: **6 groups passed, 0 failed** |
| Diff / links / boundaries | `git diff --check` and changed-document relative file links checked; package/B2/programme/SQL paths unchanged from base |

Commands used: `flutter --suppress-analytics test --no-pub test/performance_tracking`;
focused compiler/B2 tests; `dart --suppress-analytics test` for five canonical
package compatibility files; changed-path `dart --suppress-analytics analyze`;
`FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`.
No full Flutter suite was run: the library has no runtime consumers, and no
concrete cross-app concern arose. Formatting and checks required only local SDK
cache access. No remote fetch, hosted service, local DB migration, build or push.
`origin/main` remains the cached `031edc5da5d0b9961fb5030e0762f15e978e3f32`;
no current remote-state claim is made. `.env` and `supabase/.temp` untouched.

## Proposed C2 boundary — PROPOSED_NOT_AUTHORISED

Recommend a narrowly scoped **read-only History source adapter** against existing
result/correction authority. First design its authenticated input port and
supported exact field mappings. Resolve owner, record/block/exercise/set or
running repetition identities and, when supplied, assignment/version/hash/
occurrence links. Return current source references, coherent correction IDs and
input digests plus honest unavailable/ambiguous states; deduplicate by actual
source identity. Do not label a result an authored test without separately
validated exact assessment/completion links. No historical replay claim unless
a complete reconstruction mechanism is separately proved.

C2 acceptance should cover cross-athlete denial, correction races/coherent reads,
ambiguous fields, unsupported units/result shapes, incomplete old links,
missing/partial/skipped results, exact programme scope and unchanged B2 authority.
Use fake-port tests first; any real hosted access needs separate authority.

Keep manual-entry storage/RLS and append-only write enforcement, profile selection
persistence, calculations, Studio/athlete UI, real definitions/profiles/tests,
assessment execution and optional v3 programme packaging in separately allocated
later work. C1 does not establish those implementations or release the strategic
pause before content creation. Stop here for founder review before C2.
