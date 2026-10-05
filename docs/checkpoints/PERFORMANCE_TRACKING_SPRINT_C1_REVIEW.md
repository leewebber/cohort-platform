# Performance tracking Sprint C1 — local review

**Recorded:** 2026-10-05  
**Status:** REVIEWED_LOCAL_VERIFIED; awaiting founder integration approval.  
**Branch:** `codex/sprint-c1-tracking-contracts`  
**Reviewed clean HEAD:** `7673ea89a1877260df9444766b4a09270859a62d`  
**Verified fixes:** `2b241347ef543148474c5fbca2f550cb3764f726`

Binding authority: [approved revised architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md).
Preserved evidence: [audit](./PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md)
and [original C1 handoff](./PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md).

## Findings and scoped fixes

Synthetic regressions reproduced eight failing cases at the reviewed HEAD and
one additional failing programme-origin case before its fix. The confirmed
defects are closed in the verified fix commit:

| Finding | Result after fix |
|---|---|
| Partial evidence with only a recorded count could throw through a null required count | Incomplete or invalid coverage returns validation issues for every evidence state; no forced nullable dereference |
| Duplicate dependency identities selected whichever artifact came first; source aliases blamed only the later measurement | Duplicate identities cannot resolve; every conflicting source alias is flagged. Diagnostics are independent of enumeration order |
| One field could declare both exercise/set and running repetition row scopes | Mixed scopes are rejected; supported set and running references remain separately valid |
| The same History record/block/exercise/set or audit identity could declare contradictory ownership/parents | Closure-wide declarations must agree on row parents, athlete and audit record. One audit can still cover distinct fields/blocks of one record |
| Distinct fields from one record could claim different programme origins | Supplied assignment, occurrence, session and programme-version/hash/slot/protocol declarations must agree. Absent links remain unknown |
| A stable profile ID could switch curated/custom authority across versions | The profile ID must retain its authority and custom owner; existing custom predecessor checks remain in force |

These are consistency checks over supplied values, not live source verification.
No result values, immutable artifacts, source rows, package hashes or existing
correction audit entries were rewritten. Only validation, a domain README and
synthetic tests changed in the fix commit.

## Contract review conclusions

- Immutable ID/version/digest dependencies and explicit selection upgrades are
  retained. Custom compositions and selection/correction predecessors pin exact
  versions, ownership and origins; unsupported dependencies fail validation.
- Closed units and method signatures reject incompatibility without conversion
  or calculation. Profile order and method argument order remain meaningful.
- Chronology distinguishes performance from recording/correction time. History
  corrections cannot change performed chronology or remove an existing audit
  reference; changed input digests require a different correction audit ID.
- Exact History record/block/field, optional exercise/set or running repetition,
  and correction audit references remain available. They do not manufacture a
  historical result version: `canReconstructHistoricalInputs` remains false,
  and the decoder rejects any historical-input reconstruction claim.
- Canonical serialization/hash code is unchanged. Existing round trips and
  synthetic hash goldens pass; hashing never substitutes for validation.
- Tracking cannot confer prescription eligibility; the contract getter remains
  false. B2 policies, manual benchmark revisions, occurrence target freezes and
  blocked Cohort ingestion remain unchanged. No runtime consumer was introduced.

## Verification and compatibility

Current review checks at fix commit `2b241347ef543148474c5fbca2f550cb3764f726`:

| Check | Result |
|---|---|
| `flutter --suppress-analytics test --no-pub test/performance_tracking/` | **52 passed**: original 41 plus 11 synthetic review regressions, including the legitimate multi-block audit case |
| Changed-file `dart --suppress-analytics analyze` | **No issues found** for the validator and both changed/new test files |
| `FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh` | **6 groups passed, 0 failed** |
| Formatting / diff / document links | Changed Dart files formatted; `git diff --check` and changed-document relative file links checked |
| Scope inspection | Package/compiler, B2, SQL, runtime, UI, programme and assignment paths unchanged from reviewed HEAD |

The original handoff's **25 canonical package compatibility tests** and the
**79-test combined compiler/B2/C1 run** are reused from immutable implementation
`ac47f2ae78c65bb6b694da7ed50f385ddc708022`; they were not rerun in this review.
Their sources and dependency paths are unchanged. The changed C1 validation is
covered by the fresh 52-test run above. No full Flutter suite was warranted for
the unwired domain-only fix. No DB gate, migration, build, hosted operation,
fetch or push was performed; `.env` and `supabase/.temp` were untouched.

## Integration record

Cached base/origin main: `031edc5da5d0b9961fb5030e0762f15e978e3f32`.
No remote-state freshness claim is made. Preserve this linear sequence:

| Order | Full commit SHA | Scope |
|---|---|---|
| 1 | `8347480c11cfb2b29cb90983f731f87bc251ece0` | Original Sprint C audit |
| 2 | `335c768345084d9185b2280026dc53b3b1cb1bd3` | Revised observational architecture audit |
| 3 | `ac47f2ae78c65bb6b694da7ed50f385ddc708022` | Original C1 implementation |
| 4 | `7673ea89a1877260df9444766b4a09270859a62d` | Original C1 handoff/live pointers |
| 5 | `2b241347ef543148474c5fbca2f550cb3764f726` | Verified review fixes and regressions |

This review documentation/live-pointer commit follows order 5. The final Git
report supplies its full integration-tip SHA, the six-commit count above the
cached base and post-commit worktree state. No rebase, amendment, squash, merge
or remote ref mutation is authorised by this closeout.

## Remaining limitations and revised C2 sequence

Validation proves declared consistency only. It cannot authenticate ownership,
resolve live field shapes/units, establish coherent source reads or audit order,
prove an authored assessment was performed, detect undeclared manual duplicates,
evaluate freshness/timezone offsets, or reconstruct unavailable historical
inputs. Digests identify content; they are not source-trust credentials.
Persistence immutability and append-only writes remain future enforcement.

**C2 is read-only History adaptation first, PROPOSED_NOT_AUTHORISED.** Design an
authenticated input port and supported exact field mappings, then prove them
with fake-port tests. Resolve current source ownership/parentage, field units,
coherent correction IDs/input digests, exact optional programme links and honest
missing/partial/skipped/unavailable/ambiguous states. Deny cross-athlete access
and unsupported shapes; do not label ordinary results authored tests by inference.
No historical replay claim without separately proven complete reconstruction.

Persistence/RLS, custom-composition and selection storage, manual entry and
append-only correction writes are separately scoped later work, not inherited
by C2. Calculation, scoring, real definitions/profiles/tests, UI, programme
content and schema v3 remain excluded. C2 implementation and hosted access each
require separate authority. Stop for founder integration approval here.
