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

Sprint C's revised contract architecture is **founder-approved**.
**C1 is integrated** on `origin/main` at
`72c1281f0966f2a6485873f6071b0e000ba1e000`; all seven reviewed commits,
including both audits and implementation, are preserved.
See [C1 handoff](docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_HANDOFF.md),
[proposal](docs/architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md)
and [audit](docs/checkpoints/PROGRAMME_PERFORMANCE_METRICS_PROFILE_SPRINT_C_AUDIT.md).
The [C1 review](docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C1_REVIEW.md) records
scoped reference/coverage fixes at `2b241347ef543148474c5fbca2f550cb3764f726`.
**C2's reviewed four-commit independent History range is integrated** on
origin/main through `144ba110f8de938dc3fbd3e9cbb9a83fd21cf4ba`. The exact
`20261005130000_performance_tracking_coherent_history_read.sql` migration is
applied and SELECT-verified on Cohort Field Manual, ledger 115; see
[deployment closeout](docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md),
[reader handoff](docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_COHERENT_READER_HANDOFF.md),
[independent review](docs/checkpoints/PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md)
and [read-boundary proposal](docs/architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md).
Existing hydration is not coherent tracking authority. The independent adapter/
bridge remain unwired; no production consumer is authorised. Programme attribution
remains blocked in the deployed independent reader; the reviewed combined
continuation is integrated and hosted SELECT-verified below.
Hosted already grants training_sessions SELECT with RLS disabled; the local test
baseline denies SELECT. Both facts are preserved; do not repair permissions or
admit claims from the hosted grant. No restricted validator execution/bypass.
Tracking cannot change programming, insert tests, reconstruct unavailable
historical inputs or grant prescription eligibility. Schema v3 remains outside
C1/C2. Persistence, selection storage, manual entry, calculations, UI, real
profiles/tests, content authoring, witness expansion and further hosted operations
remain separately scoped. Deployment documentation is integrated at
`005d53dc9b822d7e8075c75e5679324b93edebf2`.
The [bounded programme-attribution authority proposal](docs/architecture/Performance_Tracking_C2_Programme_Attribution_Authority_Proposal_v1.md)
is founder-approved, **integrated and hosted SELECT-verified** through
`79e4d9154c6d1dc6f6e69a468e917d6d00186cf0`; see the
[programme-attribution handoff](docs/checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HANDOFF.md)
and [deployment record](docs/checkpoints/PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_DEPLOYMENT.md).
Both approved additive migrations are applied on Cohort Field Manual, ledger
117 / 20261005141000. Exact function security/grants, artifact immutability,
unchanged evidence/authority digests and final empty dry-run are SELECT-verified.
The combined owner-gated read and future-only trusted private-publication
canonical artifact/separate authored-scope seal capture remain unwired.
Artifact table is empty; legacy scope without retained proof remains unproven,
with no backfill. Package v1/v2 hashes, original publication entrypoints and
independent/correction authorities are preserved; tracking grants no prescription
eligibility. Existing permission discrepancy is preserved. No real publication,
permission remediation, production wiring or next slice is authorised by this
closeout. Deployment documentation is integrated at
`66e94e010cef40d1743694371bb59b0940b3eb72`.
The [C3 read-only evaluation proposal](docs/architecture/Performance_Tracking_C3_Read_Only_Evaluation_Proposal_v1.md)
was founder-approved for bounded pure extraction/comparability. C3 is now
**implemented, reviewed and integrated** through
`ee2ebaeb14a809628a031b428ff9fee87b0c5e06`. The original local work was on
`codex/c3-tracking-evaluation`. Original implementation
`c70a02a097c47ff74e57d132acfc6fd0876f8f00` and proposal `b1a7ffd` are preserved;
review fix `1f46a9247e3484b115ea1197b92fa37380dc7658` rejects contradictory alias
capture states/coverage/known units and malformed unmeasured coverage.
48 affected C3 tests, zero changed-file diagnostics and six safety groups passed.
See [C3 handoff](docs/checkpoints/PERFORMANCE_TRACKING_C3_EVALUATION_HANDOFF.md).
It projects trusted C2 outcomes onto exact profiles and explicit comparable pairs;
no numeric differences, source reads, storage or production consumer. Programme
attribution and prescription eligibility remain separate; legacy scope unproven.
Further implementation, wiring and hosted operations remain unauthorised.
Earlier C3 integration pauses in handoffs are historical; no production wiring
or further implementation is authorised.

**C4's isolated synthetic visual-review surface is founder-approved**, including
refined presentation at `0638046b33e7173f48001f62d4ff6a598b780cd8` (2026-10-07).
See [C4 handoff](docs/checkpoints/PERFORMANCE_TRACKING_C4_VISUAL_REVIEW_HANDOFF.md).
Its dedicated entry uses actual C2/C3 evaluation for six synthetic scenarios and
remains unreachable from production and existing Studio entries. This is not
deployed athlete tracking: no arithmetic, prescription eligibility, persistence,
real profiles or production wiring. Preview is stopped. The approved five-commit
range was integrated by strict fast-forward through
`f316a48ba529e98d408bf0acefc9ea2798eb9726`; dated integration pauses are historical.
No hosted operation, production wiring or next-slice authority follows from it.

The [first athlete tracking slice proposal](docs/architecture/Performance_Tracking_First_Athlete_History_Slice_Proposal_v1.md)
is **PROPOSED_AWAITING_FOUNDER_APPROVAL** (2026-10-07). It audits missing real
profile approval/delivery, transient opening, exact source discovery, authenticated
C2/C3 wiring and athlete presentation. Recommend content approval before a bounded
independent History view; saved selection, manual entry, programme test integration
and arithmetic remain separate. Recorded training_sessions permissions require
separate target access/release review, not remediation in the proposal. No real
profile authoring, implementation, hosted contact or production wiring is authorised.

The active product sequence is
[`docs/planning/Athlete_Product_Completion_Plan_v1.md`](docs/planning/Athlete_Product_Completion_Plan_v1.md)
and [`docs/planning/Delivery_Roadmap_v1.md`](docs/planning/Delivery_Roadmap_v1.md).
Daily Journey Integrity is **COMPLETE**
([`docs/checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](docs/checkpoints/DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md)).
Complete Athlete Experience is **COMPLETE**
([`docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md);
`COMPLETE_ATHLETE_EXPERIENCE=COMPLETE`,
`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE`,
`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE`,
`COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE`,
`HOSTED_MIGRATION_APPLIED=true`,
`SPRINT_2_HOSTED_MIGRATION_APPLIED=true`,
`SPRINT_3_HOSTED_MIGRATION_APPLIED=true`,
`NEXT_IMPLEMENTATION_AUTHORISED=false`).
Sprint 1 integrated at `a3cd351`, Sprint 2 at `8405421`, Sprint 3 at
`8dcf58e`, cleanup at `fc73ae0`. This does **not** mean the Cohort product
is launch-ready. The next sequenced item is **launch programme library**.
Strategy is **approved**. Infrastructure architecture is **approved**.
Programme Studio Stage 1 is **COMPLETE**. Structured running B1 is
**COMPLETE** on `origin/main` `ae5028a`. Running Pace Foundation B2
infrastructure is **COMPLETE**. Its implementation is integrated on
`origin/main` at `a275223`, and all four hosted migrations
(`20260927120000` through `20260927150000`) are applied on Cohort Field Manual.
Structured Running B3 slice 1 is integrated and its migration is applied on
Cohort Field Manual through `20260928120000`. B3 slice 2 is integrated on
`origin/main` at `a83583ef`. B3 slice 3 is integrated on `origin/main` at
`1f6017d`; its migration is applied on Cohort Field Manual
through `20260929120000`. The private TEST ONLY B3 device-validation programme
and device closeout are integrated on `origin/main` at `d1585af`. They prove
the verified v2 time-based path but do not establish commercial programme
adoption. B4 Programme Studio structured-running review is visually approved
at `993e516` and integrated on `origin/main` at `d6cea8bc`; its bounded
overlap-authority migration is applied and SELECT-only verified on Cohort Field
Manual through `20261005120000` (ledger 114). It remains a read-only derived surface and does
not author or approve programme content
([`docs/architecture/Programme_Studio_Structured_Running_B4_Proposal_v1.md`](docs/architecture/Programme_Studio_Structured_Running_B4_Proposal_v1.md),
[`docs/checkpoints/PROGRAMME_STUDIO_STRUCTURED_RUNNING_B4_HANDOFF.md`](docs/checkpoints/PROGRAMME_STUDIO_STRUCTURED_RUNNING_B4_HANDOFF.md)).
All four hosted authored-running documents remain valid with zero overlaps and
unchanged compatibility counts/digest. Further implementation and hosted
operations require separate authority.
Lee Bali Hybrid Base is **authored locally** and awaiting founder visual review
([`docs/checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md`](docs/checkpoints/PROGRAMME_STUDIO_STAGE_1_HANDOFF.md),
[`docs/checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md`](docs/checkpoints/RUNNING_WORKOUT_B1_HANDOFF.md),
[`docs/checkpoints/RUNNING_PACE_FOUNDATION_B2_HANDOFF.md`](docs/checkpoints/RUNNING_PACE_FOUNDATION_B2_HANDOFF.md),
[`docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_1_HANDOFF.md`](docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_1_HANDOFF.md),
[`docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_2_HANDOFF.md`](docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_2_HANDOFF.md),
[`docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_3_HANDOFF.md`](docs/checkpoints/STRUCTURED_RUNNING_B3_SLICE_3_HANDOFF.md),
[`docs/checkpoints/PRIVATE_PROGRAMME_INFRASTRUCTURE_HANDOFF.md`](docs/checkpoints/PRIVATE_PROGRAMME_INFRASTRUCTURE_HANDOFF.md),
[`docs/checkpoints/BALI_HYBRID_BASE_PROGRAMME_HANDOFF.md`](docs/checkpoints/BALI_HYBRID_BASE_PROGRAMME_HANDOFF.md),
[`docs/checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md`](docs/checkpoints/LEE_BALI_HYBRID_BASE_HANDOFF.md),
[`docs/checkpoints/LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md`](docs/checkpoints/LEE_BALI_HYBRID_BASE_PHASE_1_AUDIT.md),
[`docs/architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md`](docs/architecture/Lee_Bali_Hybrid_Base_Implementation_v1.md),
[`docs/architecture/Launch_Programme_Library_v1.md`](docs/architecture/Launch_Programme_Library_v1.md),
[`docs/architecture/Programme_Studio_v1.md`](docs/architecture/Programme_Studio_v1.md),
[`docs/architecture/Running_Workout_and_Device_Interop_v1.md`](docs/architecture/Running_Workout_and_Device_Interop_v1.md);
`LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED`,
`LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=IN_PROGRESS`,
`PROGRAMME_STUDIO_STAGE_1=COMPLETE`,
`RUNNING_PACE_FOUNDATION=B2_INFRASTRUCTURE_COMPLETE`,
`RUNNING_WORKOUT_B1=COMPLETE`,
`RUNNING_PACE_FOUNDATION_B2_HOSTED_MIGRATIONS_APPLIED=true`,
`APPROVED_PERCENTAGE_BANDS=false`,
`ATHLETE_PACE_TARGET_UI=IMPLEMENTED_LOCAL_VERIFIED_V2_ONLY`,
`COHORT_5K_TEST_INGESTION=BLOCKED`,
`RUNNING_DEVICE_EXPORT=false`,
`RUNNING_TARGET_OVERRIDES=false`,
`RUNNING_PACE_B2_PROGRAMME_ADOPTION=false`,
`B3_STARTED=true`,
`STRUCTURED_RUNNING_B3_SLICE_1=INTEGRATED`,
`B3_HOSTED_MIGRATION_APPLIED=true`,
`B3_SLICE_1_HOSTED_MIGRATION_APPLIED=true`,
`STRUCTURED_RUNNING_B3_SLICE_2=INTEGRATED`,
`STRUCTURED_RUNNING_B3_SLICE_3=INTEGRATED`,
`B3_SLICE_3_HOSTED_MIGRATION_APPLIED=true`,
`B3_ATHLETE_UI=VERIFIED_V2_ONLY`,
`B3_STRUCTURED_RUNNER=TIME_TARGETS_AND_ACTUALS`,
`B3_PROGRAMME_ADOPTION=false`,
`B3_DEVICE_VALIDATION=COMPLETE_INTEGRATED`,
`B3_DEVICE_VALIDATION_CORRECTION_AUDIT_DEVICE_VALIDATED=false`,
`B3_DISTANCE_EXECUTION=false`,
`B3_MANUAL_LAP_EXECUTION=false`,
`B3_SLICE_3_STARTED=true`,
`PROGRAMME_STUDIO_STRUCTURED_RUNNING_B4=VISUALLY_APPROVED_INTEGRATED`,
`PROGRAMME_STUDIO_STRUCTURED_RUNNING_B4_IMPLEMENTATION_AUTHORISED=true`,
`B4_OVERLAPPING_ADVISORY_SCOPE_CANONICAL_REJECTION=INTEGRATED_HOSTED_VERIFIED`,
`B4_OVERLAPPING_ADVISORY_SCOPE_MIGRATION_AUTHORISED=true`,
`B4_OVERLAPPING_ADVISORY_SCOPE_HOSTED_MIGRATION_APPLIED=true`,
`PRIVATE_PROGRAMME_INFRASTRUCTURE=APPROVED`,
`LEE_BALI_HYBRID_BASE=IMPLEMENTED_AWAITING_FOUNDER_VISUAL_APPROVAL`,
`LEE_BALI_HYBRID_BASE_PRIVATE=true`,
`LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=false`,
`BALI_PROGRAMME_CONTENT_AUTHORISED=true`,
`PACE_CALCULATION_B2=INFRASTRUCTURE_COMPLETE`,
`PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false`,
`COMMERCIAL_HYROX_BASE_AUTHORING_AUTHORISED=false`,
`PROGRAMME_METRICS_PROFILE_AUTHORISED=false`,
`STRUCTURED_AUTHORING_AUTHORISED=false`,
`RUNNING_DEVICE_INTEGRATION_AUTHORISED=false`,
`HOSTED_PROGRAMME_PUBLICATION_AUTHORISED=false`,
`NEXT_IMPLEMENTATION_AUTHORISED=false`).
Structured Running B3 slice 1 is integrated at `686ddcdf`; migration
`20260928120000_b3_running_execution_mapping.sql` is applied on Cohort Field
Manual. Slice 2, slice 3, and the private TEST ONLY device-validation closeout
are integrated; the time-only verified v2 runner remains commercially
unadopted. Do not extend B4, adopt the test fixture as commercial
content, add distance or manual-lap execution, or author commercial programme
content without separate authority.
Do not publish hosted Bali or change Lee’s assignment until visual approval.
Binding:
[`docs/architecture/Complete_Athlete_Experience_v1.md`](docs/architecture/Complete_Athlete_Experience_v1.md),
[`docs/architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](docs/architecture/Complete_Athlete_Experience_Sprint_3_v1.md).
Historical Sprint 3 evidence:
[`docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md`](docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md),
[`docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md`](docs/checkpoints/COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md).
M9 is **closed**
([`docs/checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](docs/checkpoints/M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md)).
M10 infrastructure is **closed**
([`docs/checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md`](docs/checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md)).
Deeper coach-platform development is **frozen**. Binding order: complete the
athlete experience → launch programme library → adaptation engine →
progression/tracking → exercise knowledge/media → wearables → onboarding →
commercial systems → staged betas → individual hybrid-athlete launch → Build
Your Own → coaching/publisher platform → B2B later. Do not start M10 Sprint
3, Build Your Own, or coaching-product work without separate authority.

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
