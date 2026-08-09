# Cohort Platform repository guidance

This file applies to the entire repository. A more deeply nested `AGENTS.md`
or `AGENTS.override.md`, if one is added later, governs only its subtree.

## Start-of-task continuity

Before changing the repository:

1. Read [`docs/checkpoints/CURRENT_CHECKPOINT.md`](docs/checkpoints/CURRENT_CHECKPOINT.md).
2. Read the architecture and product documents it identifies as binding.
3. Inspect the current branch, `HEAD`, worktree, and relevant verification
   commands.
4. Treat existing uncommitted changes as user-owned. Do not discard, clean,
   stage, or rewrite them unless explicitly authorised.

Phase 1 product Sprints **1.1–1.7** are **closed** at `e034ea9`
(`PHASE_1_GO=true`, `PHASE_1_CLOSED=true`, `B4e=complete`). Phase 2 —
Architecture Consolidation is **CLOSED** (`PHASE_2_CLOSED=true`,
`CANONICAL_ARCHITECTURE_FROZEN=true`). Programme Athlete runtime is the sole
operational athlete authority. Phase 3 — Exercise Database has **started**.
Phase 3.1A discovery is complete; Phase 3.1 implementation has **not** started.
Binding freeze:
[`docs/architecture/Canonical_Programme_Architecture_Freeze_v1.md`](docs/architecture/Canonical_Programme_Architecture_Freeze_v1.md),
closure:
[`docs/architecture/Phase_2_Closure_v1.md`](docs/architecture/Phase_2_Closure_v1.md),
discovery:
[`docs/architecture/Phase_3_1A_Exercise_Database_Discovery_v1.md`](docs/architecture/Phase_3_1A_Exercise_Database_Discovery_v1.md).
Architecture-affecting work must still pass
`./tool/testing/run_phase2_consolidation_safety_gate.sh`.
Do not reopen Phase 1 staging or fixture work. Do not implement the Exercise
Database until Phase 3.1B contracts are approved and a later sprint authorises
code. Historical Phase 5 MVP numbering must not be treated as the current
delivery sequence. The July 2026 “Phase 2 completion” document is historical
pre–Phase 1 alignment — not current Phase 2 authority.

## Authority and product invariants

- Authored programme prescription remains the prescription authority.
- Home runtime authority is classified by
  `AthleteHomeRuntimeAuthorityResolver`: materialised programme athletes use
  Programme Athlete runtime exclusively; no-programme / loading / unavailable
  never mount Plan Library / Coach Brain Home runtime (deleted in Phase 2.9).
- Adaptation is a proposal, not a second prescription authority.
- Programme-backed adaptation reuses `SessionAdaptationPipeline` through a
  Plan-Package-native adapter and must not depend on the legacy generative
  Plan Library / Coach Brain product path.
- Adaptation may apply at whole-session and individual-exercise granularity.
- An adaptation must be shown for review and requires explicit athlete
  acceptance before it may alter prepared execution state.
- Acceptance mutates only the current prepared executable session.
- Dismissal, keep original, cancel, reject, or ignore make no durable
  adaptation change.
- Do not automatically rewrite the programme, advance an athlete, change later
  sessions, or apply post-completion progression (closed for Phase 1).
- Rescheduling (when / placement / skip disposition) is a separate authority
  under Sprint 1.7 and must not be implemented through the adaptation
  acceptance path. Binding detail:
  [`docs/architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](docs/architecture/Athlete_Controlled_Programme_Scheduling_v1.md).
- Do not invent coaching content. Reuse representative protocol and exercise
  data where it exists; otherwise use neutral labels and request direction.

Binding detail lives in
[`docs/architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](docs/architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
and
[`docs/architecture/Adaptation_Policy_v1.md`](docs/architecture/Adaptation_Policy_v1.md).

## Repository safety

- Never print or commit credentials, tokens, passwords, connection strings, or
  generated staging secret values.
- Keep `.env` and all environment-specific secrets out of Git.
- Leave `supabase/.temp/*` untouched and uncommitted. Its local drift is not a
  cleanup task.
- Preserve the Cohort Staging Athlete C fixture and its committed Sprint 1.5A
  completion. Do not reset, recreate, replay, or mutate it without a separately
  authorised staging operation.
- Do not contact staging or production unless the task explicitly authorises
  that environment and operation.
- Do not run migrations, merge, fetch, push, commit, or modify `origin/main`
  without explicit task authority.
- Verify the exact target before any remote or destructive operation.

## Verification

Use the narrowest relevant checks first, then broaden in proportion to the
change. Test topology (Phase 2.3):

| Group | Command |
|-------|---------|
| **DEFAULT** (authoritative green suite) | `flutter test` |
| **SAFETY GATE** (Phase 1 invariant freeze) | `./tool/testing/run_phase2_consolidation_safety_gate.sh` |
| **HARNESS** (fake-port Journey D) | `./tool/testing/run_phase2_harness_tests.sh` |
| **DIAGNOSIS** (nontest Flutter launcher) | `./tool/testing/run_phase2_diagnosis_tests.sh` |

`dart_test.yaml` skips tags `harness` and `diagnosis` in the default suite.
The consolidation safety gate is mandatory before consolidation commits,
legacy removal, and Phase 2 closure. Existing repository verification entry
points also include:

```bash
flutter analyze
flutter test test/architecture/ test/planning/ test/knowledge/
flutter test test/programme/athlete_programme_completion_self_test_2_test.dart
flutter test test/phase6/coaching_integrity_test.dart
./supabase/tests/run_local_db_gate.sh
```

The Supabase gate is local and Docker-backed. Staging scripts under
`tool/staging/` are guarded remote operations, not routine local verification.
Do not run them merely because they exist.

Never claim a check passed unless it was actually run successfully in the
current task or is clearly attributed to an immutable, committed checkpoint
record.

## Current delivery sequence

The exact next sequence is:

1. **Phase 2.9 — Delete Unreachable Legacy Runtime and Persistence Code**
   (next authorised Phase 2 sprint).
2. Later Phase 2 consolidation sprints per the Phase 2.5 retirement plan —
   each must pass the consolidation safety gate.
3. Production rollout and remote migration application remain separately
   controlled.
4. Do not allocate or begin Sprint 1.8 or another product phase without
   explicit authority.
5. Future package-authored bounded horizons require a separate authorised
   contract/schema change.
6. Do not reopen Phase 1 staging or fixture work unless a new authority
   explicitly allocates it.

Acceptance mutates only the current prepared executable session. Scheduling must
not rewrite Plan Packages, fabricate completion, or invoke Coach Brain /
Adaptive Progression / the adaptation pipeline.
