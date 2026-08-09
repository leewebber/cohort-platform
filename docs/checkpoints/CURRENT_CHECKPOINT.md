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
CONSOLIDATION_SAFETY_GATE_ESTABLISHED=true
PRODUCT_BEHAVIOUR_CHANGED=false
```

Phase 1 closed at `e034ea9`. Phase 2.1 inventory complete. Phase 2.2
authority/suite clearance complete. Phase 2.3 freezes Phase 1 protected
invariants into the consolidation safety gate — docs/tests/tooling only;
product behaviour unchanged.

**Authoritative consolidation safety gate:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

Manifest and policy:
[`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)
(INV-01 … INV-20). Every later Phase 2 consolidation sprint must pass this
gate. A green gate is necessary but does not alone prove code is dead or safe
to delete.

Next authorised task: **Phase 2.4 — Canonical Runtime Authority Decision and
First Caller Migration**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 1 — Core Domain Architecture | **CLOSED** at `e034ea9` |
| Phase 2 — Architecture Consolidation | **CURRENT** |
| Phase 2.1 — Architecture Inventory and Consolidation Plan | **COMPLETE** |
| Phase 2.2 — Architecture Authority Reset and Full-Suite Debt Clearance | **COMPLETE** |
| Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate | **COMPLETE** |
| Phase 2.4 — Canonical Runtime Authority Decision and First Caller Migration | Next |

Programme-athlete adaptation authority remains Sprint 1.6
(`ProgrammeAdaptFlow` / `ProgrammeAdaptation*Service`). Historical
“Coach Brain sole day-of” claims in the July 2026 architecture-alignment
report are **not** authoritative for materialised programme athletes.

## Test topology (Phase 2.3)

| Group | Command | Notes |
|-------|---------|-------|
| **DEFAULT** | `flutter test` | Authoritative green suite; skips `harness` + `diagnosis` via `dart_test.yaml` |
| **SAFETY GATE** | `./tool/testing/run_phase2_consolidation_safety_gate.sh` | Mandatory Phase 1 invariant freeze for consolidation |
| **HARNESS** | `./tool/testing/run_phase2_harness_tests.sh` | Fake-port Journey D entrypoints (separate) |
| **DIAGNOSIS** | `./tool/testing/run_phase2_diagnosis_tests.sh` | Nontest Flutter launcher proofs; `8-12` stall-stage ENV-BLOCKED / tooling debt |

Remaining diagnosis tooling debt (`8-12` nontest stall-stage) does not reopen
Phase 1 and is not a Phase 2.3 blocker.

## Phase 1 closure (retained)

Closing product/harness HEAD reviewed for B4e: `7ba8455`  
Phase 1 docs closure commit: `e034ea9`

```text
PHASE_1_GO=true
PHASE_1_CLOSED=true
B4e=complete
```

## Binding contracts

- [`../architecture/Phase_2_Consolidation_Safety_Gate_v1.md`](../architecture/Phase_2_Consolidation_Safety_Gate_v1.md)
- [`../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](../architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`../architecture/Athlete_Controlled_Programme_Scheduling_v1.md`](../architecture/Athlete_Controlled_Programme_Scheduling_v1.md)
- [`../architecture/Sprint_1_7_Athlete_D_Staging_Harness.md`](../architecture/Sprint_1_7_Athlete_D_Staging_Harness.md)

Historical (not current Phase 2 authority):
[`../architecture/Phase_2_Architecture_Consolidation_Completion.md`](../architecture/Phase_2_Architecture_Consolidation_Completion.md)

## Preserved state

- Do not reopen Phase 1 staging, fixture, validation or hardening work.
- Leave `supabase/.temp/*` untouched and uncommitted.
- Do not push without explicit authority.
- Do not contact staging or production unless explicitly authorised.
- Do not begin architectural migration or deletion until Phase 2.4+.

## Exact next sequence

1. **Phase 2.4 — Canonical Runtime Authority Decision and First Caller Migration**
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
