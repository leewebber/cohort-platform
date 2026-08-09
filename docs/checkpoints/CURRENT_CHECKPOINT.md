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
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
CANONICAL_RUNTIME_AUTHORITY_ESTABLISHED=true
HOME_FIRST_CALLER_MIGRATED=true
LEGACY_RUNTIME_DELETED=false
APPROVED_BEHAVIOUR_PRESERVED=true
```

Phase 1 closed at `e034ea9`. Phase 2.1–2.3 complete. Phase 2.4 establishes
canonical Home runtime authority and migrates `HomeScreen` as the first caller.

**Canonical runtime authority**

| Runtime | Status |
|---------|--------|
| Programme Athlete runtime | Canonical |
| Plan Library / Coach Brain | Legacy compatibility only |

Decision owner: `AthleteHomeRuntimeAuthorityResolver`  
Contract: [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)

**Authoritative consolidation safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Manifest:
[`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)

Next authorised task: **Phase 2.5 — Remaining Runtime Caller Inventory and
Compatibility-Path Retirement Decision**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 1 — Core Domain Architecture | **CLOSED** at `e034ea9` |
| Phase 2 — Architecture Consolidation | **CURRENT** |
| Phase 2.1 — Architecture Inventory and Consolidation Plan | **COMPLETE** |
| Phase 2.2 — Architecture Authority Reset and Full-Suite Debt Clearance | **COMPLETE** |
| Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate | **COMPLETE** |
| Phase 2.4 — Canonical Runtime Authority Decision and First Caller Migration | **COMPLETE** |
| Phase 2.5 — Remaining Runtime Caller Inventory and Compatibility-Path Retirement Decision | Next |

Programme-athlete adaptation authority remains Sprint 1.6
(`ProgrammeAdaptFlow` / `ProgrammeAdaptation*Service`). Historical
“Coach Brain sole day-of” claims are **not** authoritative for materialised
programme athletes. Legacy Plan Library runtime is retained but not deleted.

## Test topology

| Group | Command |
|-------|---------|
| **DEFAULT** | `flutter test` |
| **SAFETY GATE** | `./tool/testing/run_phase2_consolidation_safety_gate.sh` |
| **HARNESS** | `./tool/testing/run_phase2_harness_tests.sh` |
| **DIAGNOSIS** | `./tool/testing/run_phase2_diagnosis_tests.sh` (`8-12` ENV-BLOCKED tooling debt) |

## Binding contracts

- [`../architecture/Athlete_Home_Runtime_Authority_v1.md`](../architecture/Athlete_Home_Runtime_Authority_v1.md)
- [`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)
- [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)

## Preserved state

- Do not reopen Phase 1 staging, fixture, validation or hardening work.
- Leave `supabase/.temp/*` untouched and uncommitted.
- Do not push without explicit authority.
- Do not contact staging or production unless explicitly authorised.
- Do not delete the Plan Library / Coach Brain compatibility path until Phase 2.5+ authorises retirement.
- Do not migrate remaining independent callers until Phase 2.5+.

## Exact next sequence

1. **Phase 2.5 — Remaining Runtime Caller Inventory and Compatibility-Path Retirement Decision**
2. Later Phase 2 consolidation sprints (each must pass the safety gate)
3. Production rollout remains separately controlled

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
./tool/testing/run_phase2_consolidation_safety_gate.sh
flutter test
```
