# Current repository checkpoint

> **Live delivery pointer:** Phase 1 Integration Closeout is
> [`PHASE_1_INTEGRATION_CLOSEOUT.md`](./PHASE_1_INTEGRATION_CLOSEOUT.md).
> **M9 authority:** [`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).
> **M10 authority (closed):** [`M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md`](./M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md).
> **Next-task authority:** [`ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md`](./ATHLETE_PRODUCT_COMPLETION_PLAN_HANDOFF.md)
> and [`../planning/Athlete_Product_Completion_Plan_v1.md`](../planning/Athlete_Product_Completion_Plan_v1.md).
> **Daily Journey Integrity is COMPLETE.** Closeout:
> [`./DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md`](./DAILY_JOURNEY_INTEGRITY_CLOSEOUT.md)
> (`DAILY_JOURNEY_INTEGRITY=COMPLETE`). Complete Athlete Experience is
> **COMPLETE**. Closeout:
> [`./COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md`](./COMPLETE_ATHLETE_EXPERIENCE_CLOSEOUT.md)
> (`COMPLETE_ATHLETE_EXPERIENCE=COMPLETE`,
> `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_1=COMPLETE`,
> `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_2=COMPLETE`,
> `COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3=COMPLETE`,
> `HOSTED_MIGRATION_APPLIED=true`,
> `SPRINT_2_HOSTED_MIGRATION_APPLIED=true`,
> `SPRINT_3_HOSTED_MIGRATION_APPLIED=true`,
> `NEXT_IMPLEMENTATION_AUTHORISED=false`).
> Closeout base `fc73ae0`. This does **not** make the Cohort product
> launch-ready. Launch programme library strategy is **approved**.
> Infrastructure architecture is **approved**. Programme Studio Stage 1
> is **approved, not started**
> ([`./LAUNCH_PROGRAMME_LIBRARY_AUDIT.md`](./LAUNCH_PROGRAMME_LIBRARY_AUDIT.md),
> [`../architecture/Launch_Programme_Library_v1.md`](../architecture/Launch_Programme_Library_v1.md),
> [`../architecture/Programme_Studio_v1.md`](../architecture/Programme_Studio_v1.md);
> `LAUNCH_PROGRAMME_LIBRARY=STRATEGY_APPROVED`,
> `LAUNCH_PROGRAMME_LIBRARY_INFRASTRUCTURE=APPROVED_NOT_STARTED`,
> `PROGRAMME_STUDIO_STAGE_1=APPROVED_NOT_STARTED`,
> `PROGRAMME_CONTENT_AUTHORING_AUTHORISED=false`,
> `NEXT_IMPLEMENTATION_AUTHORISED=false`).
> Programme content is **not** authorised. Binding:
> [`../architecture/Complete_Athlete_Experience_v1.md`](../architecture/Complete_Athlete_Experience_v1.md),
> [`../architecture/Complete_Athlete_Experience_Sprint_3_v1.md`](../architecture/Complete_Athlete_Experience_Sprint_3_v1.md).
> Historical Sprint 3 evidence:
> [`./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_AUDIT.md),
> [`./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md`](./COMPLETE_ATHLETE_EXPERIENCE_SPRINT_3_HANDOFF.md).
> Daily Journey Sprint 1 `e646f11`, Sprint 2
> `5b584a6`, Sprint 3 `5329343`, whitespace `6796cb2`. Contracts:
> [`../architecture/Daily_Journey_Integrity_v1.md`](../architecture/Daily_Journey_Integrity_v1.md),
> [`../architecture/Daily_Journey_Execution_Reliability_v1.md`](../architecture/Daily_Journey_Execution_Reliability_v1.md),
> [`../architecture/Daily_Journey_Accessibility_and_Interaction_Integrity_v1.md`](../architecture/Daily_Journey_Accessibility_and_Interaction_Integrity_v1.md).
> Historical M10 sprint / preflight / hardening records remain evidence only.
> This file remains the historical atomic-resume / Phase 3 checkpoint. It is
> not the next-task authority.

**Recorded:** 2026-08-13
**Status:** `PROGRAMME_SESSION_ATOMIC_RESUME_AND_EXECUTION_PROVENANCE_CORRECTION`
is complete and locally verified. The retained vertical-slice base
`6ee30d7ec9ba5e9a77dd2f4fed2d6c15ec3534c8` was not independently dogfood-safe:
its application-side create/link sequence was neither atomic nor concurrency
safe, and it did not compare prepared package provenance with execution-context
provenance. That premature checkpoint is superseded by this correction.

Programme Home now uses one authenticated transactional create-or-resume RPC.
The RPC validates exact assignment/version/cursor/slot authority, serialises
concurrent starts, and atomically creates and links one stable training session.
Canonical package hashes are compared exactly before create, resume, restore,
or Active Session launch; missing, malformed, or mismatched provenance fails
closed with typed retryable athlete-visible errors. The disposable local
Supabase gate, concurrency test, focused regressions, Phase 2 safety gate, full
Flutter suite, and static-analysis gate pass. No hosted system was contacted.
Lee remains not dogfood-ready until real-programme verification succeeds.

```text
PROGRAMME_ATHLETE_REAL_WORKOUT_EXECUTION_AND_ATOMIC_COMPLETION_VERTICAL_SLICE_AUTHORISED=true
PROGRAMME_ATHLETE_REAL_WORKOUT_EXECUTION_AND_ATOMIC_COMPLETION_VERTICAL_SLICE_COMPLETE=true
PROGRAMME_ATHLETE_VERTICAL_SLICE_BASE_COMMIT=6ee30d7ec9ba5e9a77dd2f4fed2d6c15ec3534c8
PROGRAMME_SESSION_ATOMIC_RESUME_AND_EXECUTION_PROVENANCE_CORRECTION_AUTHORISED=true
PROGRAMME_SESSION_ATOMIC_RESUME_AND_EXECUTION_PROVENANCE_CORRECTION_COMPLETE=true
ATOMIC_TRAINING_SESSION_CREATE_AND_LINK_VERIFIED=true
CONCURRENT_SESSION_DEDUPLICATION_VERIFIED=true
PREPARED_PACKAGE_PROVENANCE_VERIFIED=true
PROVENANCE_MISMATCH_FAILS_CLOSED=true
ATHLETE_PROGRAMME_HOME_EXECUTION_WIRED=true
BLOCK_AWARE_ACTUALS_CAPTURE_WIRED=true
AUTHORITATIVE_PROGRAMME_COMPLETION_WIRED=true
COMPLETION_FAILURE_FAILS_CLOSED=true
PROGRAMME_ADVANCEMENT_AFTER_RESTART_VERIFIED=true
PREVIOUS_PERFORMANCE_FROM_ATHLETE_ACTUALS_VERIFIED=true
SAFE_UNCONFIGURED_STARTUP_VERIFIED=true
LOCAL_APP_RUN_COMPLETED=true
LEE_DOGFOOD_READY=false
FAMILY_BETA_READY=false
ATHLETE_UI_CHANGED=true
PRODUCT_UI_GATE_2_VERIFIED=false
DATABASE_MIGRATIONS_ADDED=true
PLAN_PACKAGE_V1_CHANGED=false
EXERCISE_KNOWLEDGE_CHANGED=false
HOSTED_SYSTEMS_CONTACTED=false
HOSTED_MUTATIONS=0
STATIC_ANALYSIS_PRE_IMPLEMENTATION_ISSUES=410
STATIC_ANALYSIS_POST_IMPLEMENTATION_ISSUES=407
STATIC_ANALYSIS_POST_IMPLEMENTATION_ERRORS=0
CHANGED_DART_FILE_DIAGNOSTICS=0
TASK_SCOPED_BASELINE_TOLERANT_EXCEPTION_CONSUMED=true
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
NEXT_TASK_RECOMMENDED=LEE_REAL_PROGRAMME_DOGFOOD_VERIFICATION
```

The prior authority remains: Phase 3.1 is complete and founder-accepted. Its selected first
consumer, `founder_programme_yaml_import`, consumes the transitional-ID bridge;
implementation commit `fb724d2f7a854bd4a36cbb45c884adcb82222765` is accepted.
The Phase 3.1 acceptance checkpoint is
`5dc3cbdea3b454ff9d791563b20c977dfd6938a2`. The trusted Plan Package import
runtime remains a distinct local, undeployed consumer:
Plan Package v1 contains no exercise identities and does not close Phase 3.1.
Phase 3.2B–3.2D are complete; Phase 3.2D is founder-accepted at `6321dfc`.
The accepted allocation dossier's bounded local Exercise Knowledge
text-guidance application read projection is implemented and locally verified.
The implementation is founder-accepted at
`9bc5cd7cc78d0fe771aa7608ba717ec88787a0c2`.

```text
PHASE_2_CLOSED=true
CANONICAL_ARCHITECTURE_FROZEN=true
PHASE_3_STARTED=true
PHASE_3_1F_PART_2_ACCEPTED=true
PHASE_3_1F_PART_2_COMPLETE=true
PHASE_3_1F_COMPLETE=true
PHASE_3_1_LOCAL_FOUNDATION_COMPLETE=true
PHASE_3_1_HOSTED_CATALOGUE_SEED_COMPLETE=true
PHASE_3_1_HOSTED_CATALOGUE_ROWS=132
PHASE_3_1_FIRST_CONSUMER=founder_programme_yaml_import
PHASE_3_1_FIRST_CONSUMER_IMPLEMENTATION_DOSSIER_FOUNDER_ACCEPTED=true
PHASE_3_1_FIRST_CONSUMER_IMPLEMENTATION_AUTHORISED=true
D1_STATIC_ANALYSIS_GATE=TASK_SCOPED_BOUNDED_BASELINE_TOLERANT
PHASE_3_1_BASELINE_TOLERANT_ANALYSIS_APPROVED=true
STATIC_ANALYSIS_GATE_PASSED=true
STATIC_ANALYSIS_CHANGED_FILES_ISSUES=0
STATIC_ANALYSIS_BASELINE_ISSUES=423
STATIC_ANALYSIS_FINAL_ISSUES=415
STATIC_ANALYSIS_BASELINE_INCREASED=false
PHASE_3_1_FIRST_CONSUMER_IMPLEMENTATION_COMPLETE=true
PHASE_3_1_FIRST_CONSUMER_COMPLETE=true
PHASE_3_1_FIRST_CONSUMER_FOUNDER_ACCEPTED=true
PHASE_3_1_FOUNDER_ACCEPTED=true
PHASE_3_1_COMPLETE=true
PHASE_3_1_ACCEPTED_IMPLEMENTATION_COMMIT=fb724d2f7a854bd4a36cbb45c884adcb82222765
PHASE_3_1_ACCEPTANCE_CHECKPOINT_AUTHORISED=true
PHASE_3_1_ACCEPTANCE_CHECKPOINT_COMPLETE=true
PHASE_3_1_AUTHORITY_RECONCILED=true
TRANSITIONAL_EXERCISE_ID_FIELD_IMPLEMENTED=true
FOUNDER_APPROVED_MAPPINGS_VERIFIED=21
CANONICAL_TARGET_VALIDATION_IMPLEMENTED=true
IDENTITY_FAILURES_PREVENT_ALL_WRITES=true
LEGACY_SLUG_NAME_BEHAVIOUR_PRESERVED=true
PARALLEL_EXERCISE_CATALOGUE_CREATED=false
PLAN_PACKAGE_IMPORT_CLOSES_PHASE_3_1=false
PLAN_PACKAGE_V1_CHANGED=false
PLAN_PACKAGE_GOLDEN_HASH_CHANGED=false
EXERCISE_KNOWLEDGE_CHANGED=false
EXERCISE_KNOWLEDGE_CONSUMER_STARTED=true
PHASE_3_2_STARTED=true
PHASE_3_2B_COMPLETE=true
PHASE_3_2B_ACCEPTED_COMMIT=367a11c1c0200e94774233f25b72ca74fd914deb
PHASE_3_2C_MEANING=EXERCISE_KNOWLEDGE_AUDIT_AND_FOUNDER_REVIEW
PHASE_3_2C_COMPLETE=true
PHASE_3_2D_COMPLETE=true
PHASE_3_2D_FOUNDER_ACCEPTED=true
PHASE_3_2D_ACCEPTED_COMMIT=6321dfcd820c11697fcecf02a124e2be720e3280
PHASE_3_2D_SCOPE=EIGHT_TEXT_ONLY_LOCAL_IN_MEMORY_AGGREGATES
PHASE_3_2D_VERSIONED_IMMUTABLE=true
PHASE_3_2D_PRODUCTION_CONSUMER_ADDED=false
PHASE_3_2D_PERSISTENCE_ADDED=false
PHASE_3_2D_MEDIA_ADDED=false
PHASE_3_2D_ATHLETE_UI_CHANGED=false
PHASE_3_2E_ALLOCATED=false
PHASE_3_2F_ALLOCATED=false
PHASE_3_2G_ALLOCATED=false
NEW_CANONICAL_EXERCISES_CREATED=5
IMPLEMENTED_MAPPING_COUNT=21
ALL_TRANSITIONAL_IDS_RESOLVE_EXACTLY_ONCE=true
HEURISTIC_IDENTITY_MATCHING_USED=false
MAPPING_IMPLIES_SUBSTITUTION=false
MAPPING_IMPLIES_COMPARABILITY=false
COMPARISON_PROTOCOL_REMAINS_SOLE_POSITIVE_AUTHORITY=true
HISTORICAL_EVIDENCE_REWRITTEN=false
FIELD_MANUAL_UPLIFT_APPLIED=true
FIELD_MANUAL_UPLIFT_VERIFIED=true
FIELD_MANUAL_MIGRATIONS_APPLIED=9
FIELD_MANUAL_MIGRATION_LEDGER_COUNT=44
HOSTED_ENVIRONMENT_CONTACTED=true
HOSTED_MUTATION_PERFORMED=true
LIVE_CONSUMERS_MIGRATED=false
FIRST_CONSUMER_IMPLEMENTED=true
SHARED_PLAN_PACKAGE_COMPILER_EXTRACTED=true
TRUSTED_FOUNDER_IMPORT_RUNTIME_IMPLEMENTED=true
TRUSTED_FOUNDER_IMPORT_RUNTIME_DEPLOYED=false
TRUSTED_RUNTIME_HOSTED_PROJECTS_CONTACTED=0
TRUSTED_RUNTIME_HOSTED_PROJECTS_MUTATED=0
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=true
PHASE_3_1F_SEED_APPLIED=true
PHASE_3_1F_SEED_VERIFIED=true
PHASE_3_1F_ROWS_PRESENT=true
FIELD_MANUAL_CATALOGUE_COUNT=132
MANUAL_TESTING_APPLICABILITY=deferred
PRODUCT_UI_GATE_2_VERIFIED=false
VIDEO_PROVIDER_SELECTED=false
STATIC_ANALYSIS_BASELINE_RESOLVED=false
STATIC_ANALYSIS_ACCEPTED_CHECKPOINT_ISSUES=415
PHASE_3_1_BASELINE_TOLERANT_EXCEPTION_CONSUMED=true
NEW_STATIC_ANALYSIS_EXCEPTION_REQUIRED=true
NEW_STATIC_ANALYSIS_EXCEPTION_AUTHORISED=false
STATIC_ANALYSIS_PRE_IMPLEMENTATION_ISSUES=415
STATIC_ANALYSIS_POST_IMPLEMENTATION_ISSUES=415
STATIC_ANALYSIS_POST_IMPLEMENTATION_ERRORS=0
CHANGED_DART_FILE_DIAGNOSTICS=0
TASK_SCOPED_BASELINE_TOLERANT_EXCEPTION_CONSUMED=true
POST_3_2D_AUTHORITY_CHECKPOINT_RECONCILIATION_AUTHORISED=true
POST_3_2D_AUTHORITY_CHECKPOINT_RECONCILIATION_COMPLETE=true
POST_PHASE_3_1_AND_3_2D_NEXT_PHASE_ALLOCATION_DOSSIER_AUTHORISED=true
POST_PHASE_3_1_AND_3_2D_NEXT_PHASE_ALLOCATION_DOSSIER_COMPLETE=true
POST_PHASE_3_1_AND_3_2D_NEXT_PHASE_ALLOCATION_DOSSIER_FOUNDER_ACCEPTED=true
RECOMMENDED_NEXT_CANDIDATE=EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_IMPLEMENTATION
RECOMMENDED_NEXT_CANDIDATE_TYPE=BOUNDED_LOCAL_IMPLEMENTATION
RECOMMENDED_NEXT_CANDIDATE_SELECTED=true
RECOMMENDED_NEXT_CANDIDATE_IMPLEMENTATION_READY=true
EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_IMPLEMENTATION_AUTHORISED=true
EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_IMPLEMENTATION_COMPLETE=true
EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_FOUNDER_ACCEPTED=true
EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_IMPLEMENTATION_COMMIT=9bc5cd7cc78d0fe771aa7608ba717ec88787a0c2
EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_ACCEPTANCE_COMMIT=none
NEXT_PHASE_ALLOCATED=false
NEXT_TASK_RECOMMENDED=POST_EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_PROJECTION_NEXT_TASK_ALLOCATION_DOSSIER
NEXT_TASK_STATUS=PROPOSED_NOT_AUTHORISED
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
DATABASE_MIGRATIONS_ADDED=false
ATHLETE_UI_CHANGED=false
CLOUD_RUN_CONTACTED=false
SUPABASE_CONTACTED=false
HOSTED_MUTATIONS=0
FILES_CHANGED=4
COMMITS_CREATED=1
PHASE_3_1_FIRST_CONSUMER_COMMIT=fb724d2f7a854bd4a36cbb45c884adcb82222765
PHASE_3_1_ACCEPTANCE_COMMIT=5dc3cbdea3b454ff9d791563b20c977dfd6938a2
AUTHORITY_RECONCILIATION_COMMIT=78088b93c15d8e9e3b71a71494cfa0e1ff2f32c6
```

| Milestone | Commit |
|-----------|--------|
| Phase 3.1E | `b03faa9d656d2a4fc3005d79205796f0abe07f56` |
| Phase 3.1F Part 1 | `216a9be2d06dd5be11862c3a8fda0062dde12e0e` |
| Phase 3.1F Part 1b | `a53ba7c789a5ed8a7c716780a0ed6319cb910e07` |
| Phase 3.1F Part 2 | `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc` |
| Phase 3.1 first consumer | `fb724d2f7a854bd4a36cbb45c884adcb82222765` |
| Phase 3.2B | `367a11c1c0200e94774233f25b72ca74fd914deb` |
| Phase 3.2D | `6321dfcd820c11697fcecf02a124e2be720e3280` |

**Binding:** Phase 3.1 identity authority remains
[`Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md).
Movement-content authority is recorded in
[`Phase_3_2B_Canonical_Movement_Knowledge_Contracts_v1.md`](../architecture/Phase_3_2B_Canonical_Movement_Knowledge_Contracts_v1.md)
and
[`Phase_3_2D_Approved_Movement_Knowledge_Pilot_v1.md`](../architecture/Phase_3_2D_Approved_Movement_Knowledge_Pilot_v1.md).

The accepted first-consumer authority path is:

`founder YAML` → explicit `transitional_exercise_id` → repository-owned
transitional-ID bridge → caller-supplied authoritative published Exercise
Definition → canonical `EX-*` identity → immutable resolved programme →
persistence only after complete validation.

All 21 accepted mappings were verified. Any identity failure prevents every
write. Canonical Exercise Definition identity, transitional mapping authority,
programme prescription, Exercise Knowledge, and Plan Package v1 remain
distinct authorities.

Phase 3.1 closure does not make the historical 132-row review export runtime
authority, connect Exercise Knowledge to a consumer, modify Plan Package v1,
authorise hosted verification or deployment, authorise Product-UI Gate 2 or
athlete UI, or allocate Phase 3.2E/F/G. The accepted implementation observed
415 analysis issues against the pre-implementation count of 423. The repository
warning baseline remains unresolved; the bounded Phase 3.1 exception is
consumed and grants no authority to a later change.

The founder-accepted allocation dossier selected
`EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_APPLICATION_READ_PROJECTION_IMPLEMENTATION`
as a bounded local implementation. The completed, UI-neutral application query
boundary projects published `MovementStandard` and `CoachingContent` for a
caller-supplied canonical `EX-*` identity. It remains separate from canonical
identity, transitional mappings, founder YAML import, programme prescription
and structure, programmed-session resolution, Workout Player, athlete evidence
and actuals, adaptations, comparisons, substitutions, and Plan Package v1.

No production composition, feature/UI consumer, Workout Player hydration,
persistence, Supabase integration, hosted publication, video projection, or
new Exercise Knowledge content was added. Product-UI Gate 2 remains
unauthorised and unverified. Phase 3.2E/F/G remain unallocated. The
implementation is complete and founder-accepted at
`9bc5cd7cc78d0fe771aa7608ba717ec88787a0c2`, while remaining UI-neutral and
unwired to any production or feature consumer.

Canonical Exercise Definitions remain the sole canonical identity authority;
Exercise Knowledge cannot create or replace identity. A knowledge projection
cannot change programme prescription, overwrite athlete actuals, approve
adaptations, redefine comparisons, or authorise substitutions from movement
relationships. Plan Package v1 cannot gain exercise identity or knowledge
fields. This checkpoint authorises no athlete UI, persistence, hosted mutation,
or invented coaching content.

Its task-scoped static-analysis gate requires a fresh full `flutter analyze`
measurement before editing, zero pre-existing and final repository errors,
zero diagnostics in every changed Dart file, and no increase from the fresh
pre-edit issue count. Suppressions, exclusions, and analysis-configuration
changes are forbidden. The exception applies only to the selected projection
implementation, does not make 415 a new baseline, and does not carry forward.
The fresh pre-edit and final counts were both 415 with zero errors and zero
changed-file diagnostics; this task-scoped exception is consumed.

**Next recommended task — `PROPOSED_NOT_AUTHORISED`:**
`POST_EXERCISE_KNOWLEDGE_TEXT_GUIDANCE_PROJECTION_NEXT_TASK_ALLOCATION_DOSSIER`.
This future read-only repository-authority and product-sequencing review must
compare repository-supported candidates without assuming another Exercise
Knowledge consumer, production composition, VideoReference work, Product-UI
Gate 2, or a Phase 3.2E/F/G allocation. No downstream implementation is
authorised.

**Safety gate:** `./tool/testing/run_phase2_consolidation_safety_gate.sh`
