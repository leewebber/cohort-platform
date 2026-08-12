# Current repository checkpoint

**Recorded:** 2026-08-12
**Status:** Phase 3.1 local foundation and the verified 132-row hosted canonical
catalogue are complete. Phase 3.1 remains incomplete because its selected first
consumer, `founder_programme_yaml_import`, has not consumed the transitional-ID
bridge and passed its separately authorised verification gates. The trusted
Plan Package import runtime remains a distinct local, undeployed consumer:
Plan Package v1 contains no exercise identities and does not close Phase 3.1.
Phase 3.2B–3.2D are complete; Phase 3.2D is founder-accepted at `6321dfc`.

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
PHASE_3_1_FIRST_CONSUMER_COMPLETE=false
PHASE_3_1_COMPLETE=false
PLAN_PACKAGE_IMPORT_CLOSES_PHASE_3_1=false
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
FIRST_CONSUMER_IMPLEMENTED=false
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
STATIC_ANALYSIS_BASELINE_ISSUES=423
STATIC_ANALYSIS_BASELINE_RESOLVED=false
POST_3_2D_AUTHORITY_CHECKPOINT_RECONCILIATION_AUTHORISED=true
POST_3_2D_AUTHORITY_CHECKPOINT_RECONCILIATION_COMPLETE=true
NEXT_TASK_RECOMMENDED=PHASE_3_1_FIRST_CONSUMER_IMPLEMENTATION_DOSSIER
NEXT_TASK_STATUS=PROPOSED_NOT_AUTHORISED
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
DATABASE_MIGRATIONS_ADDED=false
ATHLETE_UI_CHANGED=false
PLAN_PACKAGE_V1_CHANGED=false
CLOUD_RUN_CONTACTED=false
SUPABASE_CONTACTED=false
HOSTED_MUTATIONS=0
FILES_CHANGED=4
COMMITS_CREATED=1
AUTHORITY_RECONCILIATION_COMMIT=none
```

| Milestone | Commit |
|-----------|--------|
| Phase 3.1E | `b03faa9d656d2a4fc3005d79205796f0abe07f56` |
| Phase 3.1F Part 1 | `216a9be2d06dd5be11862c3a8fda0062dde12e0e` |
| Phase 3.1F Part 1b | `a53ba7c789a5ed8a7c716780a0ed6319cb910e07` |
| Phase 3.1F Part 2 | `fe92a42da6f13dbfc4a06d4a2e9a2aa7d700c3bc` |
| Phase 3.2B | `367a11c1c0200e94774233f25b72ca74fd914deb` |
| Phase 3.2D | `6321dfcd820c11697fcecf02a124e2be720e3280` |

**Binding:** Phase 3.1 identity authority remains
[`Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](../architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md).
Movement-content authority is recorded in
[`Phase_3_2B_Canonical_Movement_Knowledge_Contracts_v1.md`](../architecture/Phase_3_2B_Canonical_Movement_Knowledge_Contracts_v1.md)
and
[`Phase_3_2D_Approved_Movement_Knowledge_Pilot_v1.md`](../architecture/Phase_3_2D_Approved_Movement_Knowledge_Pilot_v1.md).

**Next recommended task — `PROPOSED_NOT_AUTHORISED`:**
`PHASE_3_1_FIRST_CONSUMER_IMPLEMENTATION_DOSSIER`. Its future purpose is to
inspect `founder_programme_yaml_import`, the existing transitional-ID bridge,
canonical catalogue authority, failure modes, and any separately governed
deployment prerequisites, then propose a bounded implementation brief.

Do not implement the consumer, change Plan Package v1, contact a hosted system,
allocate Phase 3.2E/F/G, begin Product-UI Gate 2, add movement-knowledge
persistence/media/UI, or treat Coaching Glossary or Session Templates as an
automatically authorised next phase.

**Safety gate:** `./tool/testing/run_phase2_consolidation_safety_gate.sh`
