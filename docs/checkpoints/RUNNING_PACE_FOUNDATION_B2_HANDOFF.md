# Running Pace Foundation B2 — integration handoff

**Recorded:** 2026-09-28
**Status:** Implemented and locally integration-verified; not deployed
**Branch:** `feat/running-pace-foundation-b2`
**Implementation range:** local `origin/main` `eed04352e00f3d2605507ce8bf9711d2de8b4030` through `5416155cc62380d5b3928cd7a02476b1f64c676e`, plus the review fixes recorded in this handoff
**Contract:**
[`../architecture/Running_Pace_Foundation_B2_Implementation_v1.md`](../architecture/Running_Pace_Foundation_B2_Implementation_v1.md)

```text
RUNNING_PACE_FOUNDATION=B2_IMPLEMENTED_LOCAL_INTEGRATION_VERIFIED
PLAN_PACKAGE_V2_AUTHORED_RUNNING=IMPLEMENTED_LOCAL_UNPUBLISHED
RUNNING_TARGET_OCCURRENCE_FREEZE=IMPLEMENTED_LOCAL_UNPUBLISHED
APPROVED_PERCENTAGE_BANDS=false
ATHLETE_PACE_TARGET_UI=false
COHORT_5K_TEST_INGESTION=BLOCKED
RUNNING_DEVICE_EXPORT=false
RUNNING_TARGET_OVERRIDES=false
B3_STARTED=false
HOSTED_MIGRATIONS_APPLIED=false
```

## What works

- Plan Package v1 canonical bytes and publication remain unchanged. Plan
  Package v2 optionally hashes a strict `authored_running_v1` slot document
  containing stable workout/step identities and explicit advisory policy
  attachments. Publication verifies the exact canonical bytes and hash before
  atomically persisting the immutable slot document. Only `service_role` may
  publish v2.
- Athlete-owned manual benchmark evidence requires an explicit completed 5 km
  test declaration, exactly 5,000 m, elapsed time including pauses,
  athlete-local civil date, valid IANA timezone, provenance, and treadmill or
  outdoor context. Stable evidence identity is preserved while corrections
  append immutable revisions. Athlete ownership, RLS, idempotency, and command
  grants fail closed.
- Dart and SQL implement the same percentage-of-benchmark-speed calculation,
  civil-day freshness, source eligibility, deterministic latest-evidence
  tie-break, inverse pace range, reduced rational values, and explicit display
  rounding. Shared golden vectors cover day 90/day 91 and exact results. A 5 km
  result is benchmark evidence; it is not labelled threshold pace.
- On successful first in-app start, a published v2 slot with an explicit
  hashed attachment freezes one immutable advisory aggregate per occurrence in
  the existing fixed-occurrence transaction. Retry returns the stored snapshot
  without reselection. Missing or stale eligible manual evidence freezes an
  honest `intent_only` target. Transaction failure rolls back session, outcome,
  and snapshot; the occurrence lock serialises concurrent starts.
- Snapshot rows are insert-once, update/delete protected, occurrence- and
  athlete-scoped, and unavailable through direct client grants. Internal
  selector, calculator, builder, and start functions are not executable by
  athlete or anonymous roles; athletes use the existing authenticated wrapper.
- Plan Package v1, Bali-shaped v1, and v2 slots without an attachment retain
  the pre-B2 start path and response and create no advisory snapshot. Apollo
  and Bali package hash regressions remain unchanged.

## Not available

- No percentage bands are approved or defaulted. Every numeric attachment must
  explicitly author its method version, exact percentage range, freshness,
  eligibility, rounding, and stable step scope.
- No athlete UI reads or presents the advisory snapshot.
- Cohort-session 5 km ingestion is blocked until authored-step to executable-
  block mapping and server-validated completion exist. The command returns
  `cohort_test_completion_unproven`; arbitrary 5 km activities never qualify.
- No external import, device export, Garmin integration, export-time freeze,
  treadmill/outdoor cross-context rule, or target override exists.
- No programme content, including Lee's Bali programme, uses B2. B3 has not
  started.

## Migrations

| Migration | SHA-256 |
|---|---|
| `20260927120000_plan_package_v2_authored_running.sql` | `7cef5322f08ec7094cc4a38d8957a0d89913b60d8796edf8d942611e1764512d` |
| `20260927130000_running_5k_benchmark_evidence.sql` | `7bb140e6da1588ffabc3589c264fc87c468b550cc1f92ee0dde8ad2ea84745c9` |
| `20260927140000_running_pace_sql_foundation.sql` | `443c0b7c8701c422a0280da0201b206f9e5de44ecb9158657ef4d8e998053e74` |
| `20260927150000_occurrence_running_target_snapshot.sql` | `a377bab8e9ade2f879fca6efa2f6ae24fc7fa535fd545c43710a8685e6de3c13` |

## Integration verification

- Full disposable local DB gate: pass, including two fresh resets, schema lint,
  concurrency, HTTP/RLS controls, and the negative control.
- Focused disposable B2 publication, evidence, SQL calculation, and occurrence
  freeze gates: pass, including rollback, grants, and immutability cases.
- Full Flutter suite: 3,412 passed, 6 skipped.
- Changed-file analysis: 21 Dart files, zero issues.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Package compiler regressions verify the exact Apollo and Bali v1 hashes and
  the v2 canonical golden hash.

No hosted system was contacted, no migration was applied remotely, no
programme or assignment was changed, and nothing was pushed.
