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

Phase 1 product Sprints **1.1–1.7** are **closed** (`PHASE_1_GO=true`,
`PHASE_1_CLOSED=true`, `B4e=complete`). Staging evidence was reviewed at
harness HEAD `7ba8455`; that closeout was recorded at docs commit `e034ea9`.
Post-close dogfood integration (calendar month grid, Backfill, Train today,
Home today-only, programme Progress, circuit/EMOM capture, founder iPhone
workflow) lives on `codex/apollo-dogfood` through `969ef5b` plus Integration
Closeout docs. Binding checkpoint:
[`docs/checkpoints/PHASE_1_INTEGRATION_CLOSEOUT.md`](docs/checkpoints/PHASE_1_INTEGRATION_CLOSEOUT.md).
Phase 2 — Architecture Consolidation is **CLOSED** (`PHASE_2_CLOSED=true`,
`CANONICAL_ARCHITECTURE_FROZEN=true`). Programme Athlete runtime is the sole
operational athlete authority.

Phase 3.1A–3.1F local Exercise Database work is accepted. The 132-row
`public.exercises_v2` catalogue, including `EX-128`–`EX-132`, is applied and
verified on Cohort Field Manual. All 21 transitional → `EX-*` mappings exist.
Phase 3.1 is complete and founder-accepted. Its selected first consumer,
`founder_programme_yaml_import`, resolves explicit transitional exercise IDs
through the repository bridge to caller-supplied published canonical Exercise
Definitions before any write. The accepted implementation checkpoint is
`fb724d2f7a854bd4a36cbb45c884adcb82222765`. The trusted Plan Package import
runtime does not close Phase 3.1 because Plan Package v1 has no exercise
identities. Fixture `EX-900x` ids are not production. Binding:
[`docs/architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](docs/architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md),
[`docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md`](docs/architecture/Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md),
freeze:
[`docs/architecture/Canonical_Programme_Architecture_Freeze_v1.md`](docs/architecture/Canonical_Programme_Architecture_Freeze_v1.md).

Phase 3.2B movement-content contracts and Phase 3.2D's founder-approved,
versioned, immutable eight-exercise text-only pilot are complete. The pilot is
local/in-memory and has no production consumer, persistence, media, or athlete
UI. Phase 3.2C means the completed Exercise Knowledge audit and founder review.
Phase 3.2E/F/G are unallocated. The repository-wide 423-warning analysis
baseline remains unresolved. The accepted Phase 3.1 checkpoint observed 415
issues; its bounded exception is consumed. A new task-scoped bounded
baseline-tolerant gate is authorised only for the selected Exercise Knowledge
text-guidance application read projection. It requires a fresh pre-edit count,
zero repository errors, zero changed-file diagnostics, and no issue-count
increase; it does not establish a reusable baseline. That local projection
implementation is complete and founder-accepted at
`9bc5cd7cc78d0fe771aa7608ba717ec88787a0c2`; the exception is consumed and
does not carry forward.

Architecture-affecting work must still pass
`./tool/testing/run_phase2_consolidation_safety_gate.sh`.
Do not reopen Phase 1 staging or fixture work. Do not migrate live exercise
consumers, push hosted catalogue mutations, change schema, rewrite historical
evidence, map identities by name similarity, treat relationship adjacency as
substitution/comparison authority, or begin another phase without explicit
authority.

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

The active product sequence is
[`docs/planning/Delivery_Roadmap_v1.md`](docs/planning/Delivery_Roadmap_v1.md):
Phase 1 Integration Closeout → Progression Mechanics Validation → M9 →
catalogue/enrolment → M10 isolation → adaptation integrity → closed beta →
entitlements → wearables/media.

The Exercise Knowledge text-guidance application read projection is complete
and founder-accepted at `9bc5cd7`. It is **not** the next product milestone.
Phase 3.2E/F/G remain unallocated. Do not begin them, Product-UI Gate 2, or
hosted catalogue mutations without separate authority.

Integration Closeout must not push or fast-forward `origin/main` without
founder approval. Applied Backfill schema is
`supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql`,
not `Proposed_Backfill_Programme_Session_Schema_v1.md`.

Do not allocate Phase 3.2E/F/G, treat Coaching Glossary or Session Templates as
the next numerical phase, change Plan Package v1 to manufacture an exercise-ID
dependency, begin Product-UI Gate 2, add Exercise Knowledge
persistence/media/UI, compose the selected projection into production, or
contact hosted systems without separate explicit authority. The projection
must not change identity, prescription, actuals, adaptation, comparison,
substitution, Plan Package, or coaching content.

Acceptance mutates only the current prepared executable session. Scheduling must
not rewrite Plan Packages, fabricate completion, or invoke Coach Brain /
Adaptive Progression / the adaptation pipeline.
