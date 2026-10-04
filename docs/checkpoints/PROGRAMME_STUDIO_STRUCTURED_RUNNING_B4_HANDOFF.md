# Programme Studio structured running B4 handoff

**Status:** `IMPLEMENTED_LOCALLY_AWAITING_FOUNDER_VISUAL_REVIEW`

**Base:** `f7297751e9fa5b047a2c9e5e279366de27b12f5c`

**Branch:** `codex/b4-programme-studio-structured-running`

## Contract delivered

- Canonical Plan Package v2 `authored_running_v1` is retained in deterministic
  Studio review JSON.
- A publication artifact must attest the exact compiled package hash, reviewed
  graph path, and graph SHA-256 before the shared publisher graph validator is
  allowed to provide executable review data.
- Coach Review shows ordered one-level repeats, work/recovery roles, time
  durations, authored guidance, exact advisory target scope, authored policy,
  intent-only/no-evidence behaviour, and current execution status.
- IDs, binding UUIDs, package/mapping/graph hashes, and policy identities remain
  under Technical Integrity.
- Hypothetical pace calculation starts blank, accepts only explicit coach input,
  uses existing B2 exact arithmetic plus authored rounding, is not persisted,
  and is labelled as not an athlete target or occurrence snapshot.
- Invalid/missing reviewed evidence fails closed. Unattached v2 remains visible
  as authored but not executable. Apollo, Bali, Spartan, and v1 retain their
  existing derived paths.
- The B3 device-validation package is available only as a developer fixture;
  it is excluded from real inventory and production entrypoints.

## Deliberately unresolved authority gap

Cross-attachment advisory step overlap requires a coordinated Dart/SQL
authority correction and therefore a migration. No partial compiler or schema
change was made. The concrete proposal is
[`B4_Overlapping_Running_Advisory_Scope_Authority_Proposal.md`](../architecture/B4_Overlapping_Running_Advisory_Scope_Authority_Proposal.md).

Studio detects and labels overlap as invalid review evidence, while existing B3
snapshot/runtime checks remain fail closed. Publication-time parity is not yet
closed.

## Founder visual walkthrough

Use the isolated Programme Studio preview and select **B4 structured run
review**:

1. Confirm the primary surface shows `Repeat 3 times`, Work 20 seconds,
   Recovery 15 seconds, final recovery, and authored developer-only guidance.
2. Confirm only Work step 1 carries `Advisory pace policy`; Recovery has no
   numeric scope.
3. Confirm the 90%–100% values are explicitly TEST ONLY authored fixture data,
   not approved commercial bands.
4. Expand **Hypothetical preview — not an athlete target**. It must be empty.
   Enter `22:00`; the ephemeral result is `4:24/km–4:53/km`.
5. Confirm the no-evidence message says Cohort does not estimate a pace.
6. Open Technical Integrity and expand Structured running evidence to review
   exact workout, block, step, policy, mapping, and graph identities.

## Verification

- Focused Studio, developer-fixture, and B2 calculation/golden tests:
  **47 passed**.
- Canonical Plan Package v2 authored-running package tests: **8 passed**.
- Changed-file `flutter analyze`: **13 files, no issues**.
- Phase 2 consolidation safety gate: **6 groups passed, 0 failed**.
- `git diff --check origin/main...HEAD`: passed at the final documentation
  commit.
- Isolated local preview: `http://127.0.0.1:4197/` using
  `lib/main_programme_studio_preview.dart`; no hosted service is contacted.

No full Flutter suite was run: the task requested focused verification and the
mandatory safety gate, and this local Studio-only surface remains isolated from
the production entrypoint.

## Boundaries

No hosted system, programme publication, assignment, athlete snapshot, phone
build, metrics profile, Garmin path, commercial programme, or production entry
point is changed. B4 remains a read-only derived review surface and never
becomes canonical authoring authority.
