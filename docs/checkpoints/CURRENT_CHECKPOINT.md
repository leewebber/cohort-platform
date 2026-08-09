# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 2 — Architecture Consolidation **in progress**.

```text
PHASE_1_CLOSED=true
PHASE_1_REOPENED=false
PHASE_2_STARTED=true
PHASE_2_1_INVENTORY_COMPLETE=true
PHASE_2_2_COMPLETE=true
PHASE_2_3_COMPLETE=true
PHASE_2_4_COMPLETE=true
PHASE_2_5_COMPLETE=true
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
HOME_FIRST_CALLER_MIGRATED=true
LEGACY_RUNTIME_DECISION=RETIRE
LEGACY_RUNTIME_DELETED=false
CALLER_MIGRATION_EXECUTED=false
PRODUCT_BEHAVIOUR_CHANGED=false
```

Phase 2.5 completes the remaining-caller inventory and issues
`LEGACY_RUNTIME_DECISION=RETIRE`. No runtime migration or deletion was executed
in Phase 2.5.

**Decision document:**
[`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)

**Canonical runtime authority (Phase 2.4):**
[`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

**Consolidation safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Next authorised task: **Phase 2.6 — Stop New Legacy Starts and Align Athlete
Shell Catalogue Entry**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 1 — Core Domain Architecture | **CLOSED** at `e034ea9` |
| Phase 2 — Architecture Consolidation | **CURRENT** |
| Phase 2.1 — Architecture Inventory and Consolidation Plan | **COMPLETE** |
| Phase 2.2 — Architecture Authority Reset and Full-Suite Debt Clearance | **COMPLETE** |
| Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate | **COMPLETE** |
| Phase 2.4 — Canonical Runtime Authority Decision and First Caller Migration | **COMPLETE** |
| Phase 2.5 — Remaining Runtime Caller Inventory and Compatibility-Path Retirement Decision | **COMPLETE** (`RETIRE`) |
| Phase 2.6 — Stop New Legacy Starts and Align Athlete Shell Catalogue Entry | Next |

Programme Athlete runtime is canonical. Plan Library / Coach Brain athlete
runtime is marked for retirement via later migration sprints — not deleted yet.

Materialisation (`AthletePlanMaterialisationService`) is a
**MATERIALISATION_BRIDGE** into the canonical programme system — not a competing
runtime to delete for naming reasons.

## Test topology

| Group | Command |
|-------|---------|
| **DEFAULT** | `flutter test` |
| **SAFETY GATE** | `./tool/testing/run_phase2_consolidation_safety_gate.sh` |
| **HARNESS** | `./tool/testing/run_phase2_harness_tests.sh` |
| **DIAGNOSIS** | `./tool/testing/run_phase2_diagnosis_tests.sh` (`8-12` ENV-BLOCKED tooling debt) |

## Binding contracts

- [`../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md`](../architecture/Phase_2_Compatibility_Path_Retirement_Decision_v1.md)
- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)
- [`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)
- [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)

## Preserved state

- Do not reopen Phase 1 staging, fixture, validation or hardening work.
- Leave `supabase/.temp/*` untouched and uncommitted.
- Do not push without explicit authority.
- Do not contact staging or production unless explicitly authorised.
- Do not delete Plan Library / Coach Brain until callers are migrated and
  deletion prerequisites in the Phase 2.5 decision document are met.
- Runtime retirement ≠ persistence/schema deletion.

## Exact next sequence

1. **Phase 2.6 — Stop New Legacy Starts and Align Athlete Shell Catalogue Entry**
2. Phase 2.7–2.10 per the Phase 2.5 ordered plan
3. Phase 2 final gate
4. Production rollout remains separately controlled

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
flutter test
```
