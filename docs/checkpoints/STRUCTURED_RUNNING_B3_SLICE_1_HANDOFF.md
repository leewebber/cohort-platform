# Structured Running B3 slice 1 — local implementation handoff

**Recorded:** 2026-09-28

**Status:** Implemented and locally verified; not deployed or adopted

**Branch:** `codex/b3-structured-running-slice-1`

**Base:** `bf5bcb298a7234bc1fcbad7e70263428434f2db5`

**Implementation commits:** `47d6c827ffc63b62cf5f219f62e32be438491cf5`,
`7dfd2714bbcd2d59fcfde0ada92f57cf1cea7289`

```text
STRUCTURED_RUNNING_B3_SLICE_1=IMPLEMENTED_LOCAL
B3_STARTED=true
B3_ATHLETE_UI=false
B3_STRUCTURED_RUNNER=false
B3_HOSTED_MIGRATION_APPLIED=false
B3_PROGRAMME_ADOPTION=false
```

## Delivered contract

- Plan Package v2 may optionally bind every authored running step, in exact
  authored order, to one canonical persisted `session_blocks.block_id`. The
  mapping excludes titles and positions and carries its own domain-separated
  SHA-256 attestation. Unattached v2 and every v1 package remain unchanged.
- The local-only publication migration validates the mapping hash, exact
  protocol/block scope, exact B1-derived workout identity, and exact B1 step
  identities before a slot can be persisted. It fails closed and keeps its
  validation helpers unavailable to athlete and anonymous roles.
- Prepared-session construction and local restore carry the immutable authored
  running authority. Stale cached authority forces reconstruction.
- The production launch boundary now offers a typed result containing the
  authoritative `TrainingSession`, resume state, authored running execution
  authority, and the B2 occurrence-owned frozen target snapshot.
- Launch validates athlete, fixed occurrence, assignment, programme version,
  session slot, package hash, workout, attachment/step scope, target state,
  benchmark athlete, timestamps, and canonical units. Create and resume use
  the snapshot returned by the same atomic start authority; mismatches fail
  closed before any future structured runner may consume the result.
- With no valid benchmark, the typed result carries the frozen B2
  `intent_only` state and its explicit reason, including `no_evidence`. No pace
  is manufactured.

## Compatibility boundary

- Existing v1, Apollo, Bali, and v2-without-execution-mapping paths retain
  their current runner. An unattached v2 slot may still return its B2 advisory
  snapshot, but it is not marked structured-running ready.
- No athlete UI, timer replacement, interval-transition change, result-capture
  change, programme content, programme publication, device export, Garmin
  work, or B3 slice 2 is included.

## Local migration

`20260928120000_b3_running_execution_mapping.sql`

SHA-256: `944ba45d84e179b2434e13e7470d92e49c89b0ae4613517dd79a6f9386e356c6`

This migration has been proved only in a disposable local database. It must
not be applied to Cohort Field Manual or any hosted environment without
separate authority.

## Verification

- Focused Plan Package v2/B3 compiler tests: 10 passed.
- Focused launch, persistence, publication, snapshot, protocol graph, first
  programme session, and B1 compatibility tests: 80 passed.
- Bali Plan Package compatibility: 2 passed; Apollo canonical hash remained
  unchanged in the focused compatibility run.
- Disposable B3 database gate: 5/5 passed, covering exact publication, hash
  tamper rejection, nonexistent-block rollback, and anon/athlete grant denial.
- Phase 2 consolidation safety gate: 6/6 groups passed.
- Changed-file Flutter and package analysis: zero issues.
- Full repository `flutter analyze`: 707 warnings/info in the repository-wide
  baseline; no changed-file diagnostic was reported.
- `git diff --check`: passed.

## Founder review / next authority

Review the stable-ID/hash contract, local migration, typed launch result, and
fail-closed snapshot checks. Hosted migration application, programme adoption,
athlete presentation, and B3 slice 2 remain separately gated. The repository
does not yet provide an athlete-facing structured running experience.
