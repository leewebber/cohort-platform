# Structured Running B3 slice 3 — local implementation handoff

**Recorded:** 2026-09-30

**Status:** Implemented locally; awaiting founder visual and integration review

**Branch:** `codex/b3-structured-running-slice-3`

**Base:** `a83583ef6e618ccaee7131e28d6cd0f087ad881a`

**Implementation commits:**
`f91484d` (typed frozen targets and timer presentation),
`54201ff` (exact repetition actuals, Review Session, and History),
`3b8aa77` (local server-authority migration and database gate), and
`8ae5df9` (review-surface coverage).

**Final code HEAD verified by the full Flutter suite:** `8ae5df9`

Binding contract:
[`../architecture/Structured_Running_B3_Slice_3_v1.md`](../architecture/Structured_Running_B3_Slice_3_v1.md).

```text
STRUCTURED_RUNNING_B3_SLICE_1=INTEGRATED
STRUCTURED_RUNNING_B3_SLICE_2=INTEGRATED
STRUCTURED_RUNNING_B3_SLICE_3=IMPLEMENTED_LOCAL
B3_SLICE_3_HOSTED_MIGRATION_APPLIED=false
B3_PROGRAMME_ADOPTION=false
B3_PHONE_REVIEW_COMPLETE=false
B3_DISTANCE_EXECUTION=false
B3_MANUAL_LAP_EXECUTION=false
```

## Delivered

- Verified v2 launches retain the complete frozen B2 calculated range,
  rounding policy, benchmark, and intent-only state in typed data.
- Target authority and actual rows are bound to exact workout, mapped block,
  authored step, and repeat identities. Duplicate, overlapping, stale,
  malformed, mismatched, or invalid-unit data fails closed.
- The structured timer shows authored role and guidance. Only explicitly
  scoped work shows an advisory numeric target. Intent-only work uses the one
  approved athlete message. Recovery and other non-work steps show no numeric
  target.
- Repetition review supports completed with pace, completed with pace
  unavailable, and skipped. Pending rows block completion; skipped work makes
  the session partially completed; timer expiry remains non-completing.
- Review Session and History keep target and actual/state separate. Actual
  corrections preserve all target and package authority.
- A local-only migration makes completed hosted History derive and verify its
  target from the occurrence snapshot rather than trusting the client copy.

## Local database migration

`20260929120000_b3_structured_running_targets_and_actuals.sql`

SHA-256:
`efc00c85ea9940c76ccc63934d330164080f9b74d655393d0549e9ad302acf4e`

The disposable database gate passed all seven B3 slice 3 cases: authoritative
target freeze, exact actual identity rejection, actual-only correction,
immutable target rejection, skipped-to-partial enforcement, unchanged legacy
completion, and denied direct athlete helper execution. The migration has not
been applied to a hosted project.

## Verification

- Focused launch, timer, restore, capture, Review Session, History, and
  correction set: 34 passed.
- Expanded production execution, legacy block timer, fixed/future scheduling,
  v1, Bali, Apollo, and unattached-v2 compatibility matrix: 146 passed.
- Canonical Plan Package package suite, including Bali and Apollo golden
  compatibility: 37 passed.
- Disposable B3 slice 3 database gate: 7/7 passed after a full local reset.
- Changed-file Flutter analysis: no issues.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Full authoritative `flutter test`: 3,441 passed with 6 expected
  environment-gated skips.
- `git diff --check origin/main...HEAD`: passed.

## Founder review boundary

Review the timer copy and target placement, recovery isolation, repetition
review choices, Review Session target/actual separation, and completed History.
No programme currently adopts this local feature. Do not apply the migration,
publish a programme or fixture, change Lee's assignment, build the phone app,
or begin distance/manual-lap/Garmin work without separate approval.
