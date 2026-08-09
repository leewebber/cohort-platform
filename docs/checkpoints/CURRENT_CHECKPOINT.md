# Current repository checkpoint

**Recorded:** 2026-08-09  
**Status:** Phase 2 — Architecture Consolidation **in progress**.

```text
PHASE_1_CLOSED=true
PHASE_1_REOPENED=false
PHASE_2_STARTED=true
PHASE_2_1_INVENTORY_COMPLETE=true
PHASE_2_2_COMPLETE=true
```

Phase 1 closed at `e034ea9`. Phase 2.1 inventory complete. Phase 2.2
(Architecture Authority Reset and Full-Suite Debt Clearance) complete on this
tip — documentation authority reset; default suite green; harness/diagnosis
groups explicitly runnable.

Next authorised task: **Phase 2.3 — Phase 1 Invariant Freeze and Consolidation
Safety Gate**.

## Delivery sequence (authoritative)

| Stage | Status |
|-------|--------|
| Phase 1 — Core Domain Architecture | **CLOSED** at `e034ea9` |
| Phase 2 — Architecture Consolidation | **CURRENT** |
| Phase 2.1 — Architecture Inventory and Consolidation Plan | **COMPLETE** |
| Phase 2.2 — Architecture Authority Reset and Full-Suite Debt Clearance | **COMPLETE** |
| Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate | Next |

Programme-athlete adaptation authority remains Sprint 1.6
(`ProgrammeAdaptFlow` / `ProgrammeAdaptation*Service`). Historical
“Coach Brain sole day-of” claims in the July 2026 architecture-alignment
report are **not** authoritative for materialised programme athletes.

## Test topology (Phase 2.2)

| Group | Command | Notes |
|-------|---------|-------|
| **DEFAULT** | `flutter test` | Authoritative green suite; skips `harness` + `diagnosis` tags via `dart_test.yaml` (`+2319 ~6` at Phase 2.2 close) |
| **HARNESS** | `./tool/testing/run_phase2_harness_tests.sh` | Fake-port Journey D entrypoints (2 tests; PASS) |
| **DIAGNOSIS** | `./tool/testing/run_phase2_diagnosis_tests.sh` | Nontest Flutter launcher proofs; 3/4 PASS at close; `8-12` stall-stage proof ENV-BLOCKED / flaky on this host |

`flutter analyze` at Phase 2.2 close: exit 0, 423 infos/warnings (no new errors; Phase 1 baseline had 425).

## Phase 1 closure (retained)

Closing product/harness HEAD reviewed for B4e: `7ba8455`  
Phase 1 docs closure commit: `e034ea9`

```text
PHASE_1_GO=true
PHASE_1_CLOSED=true
B4e=complete
```

Journey D proof boundary remains local prepared-package accept (no new server
adaptation table). Full-suite debt accepted at Phase 1 closure was cleared in
Phase 2.2 without reopening Phase 1 staging/fixture work.

## Binding contracts

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

## Exact next sequence

1. **Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate**
2. Later Phase 2 consolidation sprints per the Phase 2.1 plan
3. Production rollout remains separately controlled

## Resume checks

```bash
git branch --show-current
git rev-parse HEAD
git status --short --branch
flutter test
```
