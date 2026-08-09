# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 3 — Exercise Database in progress (3.1A–3.1B committed; 3.1C
repository boundary complete pending review; Phase 3.1 not complete).

```text
PHASE_1_CLOSED=true
PHASE_1_REOPENED=false
PHASE_2_STARTED=true
PHASE_2_10_COMPLETE=true
PHASE_2_CLOSED=true
CANONICAL_ARCHITECTURE_FROZEN=true
ONE_OPERATIONAL_AUTHORITY_PER_RESPONSIBILITY=true
PHASE_3_STARTED=true
PHASE_3_1A_DISCOVERY_COMPLETE=true
PHASE_3_1A_ACCEPTED=true
PHASE_3_1B_CONTRACTS_COMPLETE=true
PHASE_3_1B_ACCEPTED=true
PHASE_3_1C_REPOSITORY_BOUNDARY_COMPLETE=true
PHASE_3_1_COMPLETE=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCTION_PERSISTENCE_ADDED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=not_applicable
LEGACY_DATA_DELETED=false
LEGACY_SCHEMA_CHANGED=false
PASSIVE_LEGACY_STATE_SELECTS_RUNTIME=false
```

Phase 2 remains closed at `71b5a54623e584fb667b96617178fe1af591b787`.
Phase 3.1A documentation: `5d05e66d6616090afe7408a2eb7ed14e6db94e2b`.
Phase 3.1B contracts: `b9952b69340d3150e6b62e06951aa2c5d90a1e38`.
Phase 3.1C adds repository / snapshot / publication boundaries under
`lib/domain/exercise_knowledge/` with an in-memory implementation only.
No production persistence, schema change, or live consumer migration.
Phase 3.1C must not be committed without review authority.

**Binding authority:**
- [`../architecture/Canonical_Programme_Architecture_Freeze_v1.md`](../architecture/Canonical_Programme_Architecture_Freeze_v1.md)
- [`../architecture/Phase_2_Closure_v1.md`](../architecture/Phase_2_Closure_v1.md)
- [`../architecture/Phase_3_1A_Exercise_Database_Discovery_v1.md`](../architecture/Phase_3_1A_Exercise_Database_Discovery_v1.md)
- [`../architecture/Phase_3_1B_Exercise_Knowledge_Contracts_v1.md`](../architecture/Phase_3_1B_Exercise_Knowledge_Contracts_v1.md)
- [`../architecture/Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md`](../architecture/Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md)

**Safety gate (still required before architecture-affecting work):**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 3.1D — Canonical Exercise Identity Bridge**
(after 3.1C review/commit authority).

## Delivery sequence

| Stage | Status |
|-------|--------|
| Phase 2 closed | **YES** |
| Phase 3.1A — Discovery | **COMPLETE** |
| Phase 3.1B — Domain contracts | **COMPLETE** (committed) |
| Phase 3.1C — Repository boundary | **COMPLETE** (pending review commit) |
| Phase 3.1D — Identity bridge | Next |
| Phase 3.1 complete | **NO** |

## Preserved state

- Do not clear passive legacy PlanAssignment / `hasActivePlan` without separate authority.
- Leave `supabase/.temp/*` untouched.
- Do not push without explicit authority.
- No staging/production contact unless authorised.
- Do not improvise production exercise persistence without a schema sprint.
- Do not migrate live `cohort.exercise.*` consumers without a later authorised sprint.

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
```
