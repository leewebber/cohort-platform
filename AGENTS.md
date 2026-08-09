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
Architecture Consolidation is **current**. Phase 2.1–2.7 are complete.
Programme Athlete runtime is **canonical**. Plan Library / Coach Brain athlete
runtime decision is **`RETIRE`**. Athlete-shell new legacy starts are **closed**;
completion/progress/Home briefing for programme athletes no longer invoke
AdaptiveProgression, Plan-Library progress authority, or DailyBriefing.
Existing local `hasActivePlan` compatibility remains for pure-legacy state only.
See
[`docs/architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](docs/architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
and
[`docs/architecture/Athlete_Home_Runtime_Authority_v1.md`](docs/architecture/Athlete_Home_Runtime_Authority_v1.md).
Every later consolidation sprint must pass
`./tool/testing/run_phase2_consolidation_safety_gate.sh`.
Do not reopen Phase 1 staging or fixture work. No Sprint 1.8 or other product
phase has been allocated. Historical Phase 5 MVP numbering must not be treated
as the current delivery sequence. The July 2026 “Phase 2 completion” document
is historical pre–Phase 1 alignment — not current Phase 2 authority.

## Authority and product invariants

- Authored programme prescription remains the prescription authority.
- Home runtime authority is classified by
  `AthleteHomeRuntimeAuthorityResolver`: materialised programme athletes use
  Programme Athlete runtime exclusively; Plan Library / Coach Brain remains
  temporary compatibility only when there is no materialised programme.
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

1. **Phase 2.8 — Retire the Home Legacy Runtime Entry and Isolate Remaining
   Legacy Code** (next authorised Phase 2 sprint).
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
