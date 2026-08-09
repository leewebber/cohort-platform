# Phase 2 Consolidation Safety Gate v1

**Status:** Binding for Phase 2 consolidation (Phase 2.3+)  
**Established:** Phase 2.3 — Phase 1 Invariant Freeze and Consolidation Safety Gate  
**Authoritative command:**

```bash
./tool/testing/run_phase2_consolidation_safety_gate.sh
```

This gate freezes the Phase 1 behavioural contract as executable evidence. It
must remain independent of hosted staging/production, fail closed when required
evidence is absent, and stay suitable for repeated local use.

A green gate is **necessary** before consolidation, migration, or deletion work.
It does **not alone** prove that a legacy path is dead or safe to delete.

---

## When the gate must run

| Moment | Required |
|--------|----------|
| Before a consolidation sprint | Yes |
| After implementation in a consolidation sprint | Yes |
| Before its commit | Yes |
| After conflict resolution affecting protected paths | Yes |
| Before removing a legacy path | Yes |
| At final Phase 2 closure | Yes |

Harness and diagnosis groups remain separate:

```bash
./tool/testing/run_phase2_harness_tests.sh
./tool/testing/run_phase2_diagnosis_tests.sh
```

Environment-gated diagnosis debt (e.g. nontest `8-12` stall-stage) is **not**
part of this mandatory gate.

---

## Deletion / migration evidence (later Phase 2)

Before removing or migrating a legacy path, record:

```text
all callers identified
replacement path proven
tests migrated to contract-level assertions
legacy runtime registrations removed
no required invariant depends exclusively on deleted code
default suite green
consolidation safety gate green
analyze has no new errors
```

---

## Coverage classes

| Class | Meaning |
|-------|---------|
| **DIRECT** | Test asserts the invariant outcome on the production seam |
| **COMPOSITE** | Multiple tests together prove the contract |
| **INDIRECT** | Nearby execution supports the contract but does not alone freeze it |
| **MISSING** | No adequate executable evidence (gate incomplete) |
| **OBSOLETE** | Evidence targets a superseded structure; behaviour must be remapped |

---

## Invariant manifest (INV-01 … INV-20)

| ID | Invariant | Canonical source | Production symbols/path | Executable tests | Required result | Coverage |
| -- | --------- | ---------------- | ----------------------- | ---------------- | --------------- | -------- |
| INV-01 | Authored programme remains prescription authority; adaptation is not a second authoring path | `Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`; `Authored_Plan_Package_v1.md`; `AGENTS.md` | `ProgrammeAdaptation*Service`; `PlanPackageSessionAdaptationAdapter`; `AthleteProgrammeAuthoredSlotResolver` | `test/architecture/architecture_dependency_test.dart` (programme adaptation path); `test/phase6/coaching_integrity_test.dart` (programmed session integrity); `test/application/adaptation/programme_adaptation_*` | Programme structure/identity preserved; no generative reauthoring imports on programme adapt path | DIRECT |
| INV-02 | Completion values originate from athlete-entered records | `Athlete_Programme_Completion_Advancement_v1.md`; `Coaching_Constitution_v1.md` | `AthleteProgrammeCompletionService`; execution result models; Self-Test 2 path | `test/programme/athlete_programme_completion_self_test_2_test.dart`; `test/phase6/coaching_integrity_test.dart` (completed session linkage) | Completion retains athlete actuals + programmed identity; no fabricated completion via adapt/schedule | COMPOSITE |
| INV-03 | Canonical programmed-session identity (`ProgrammedSessionKey`) is stable across prepare/adapt/complete | `Session_Authority_Model_v1.md`; ADR-017; acceptance-gated adaptation contract | `ProgrammedSessionKey`; `PreparedExecutionPackage.programmedSessionKey` | `programme_adaptation_acceptance_service_test.dart`; `coaching_integrity_test.dart`; completion Self-Test 2 | Key unchanged by accept/revert/complete | DIRECT |
| INV-04 | Assignment / programme version / package hash / occurrence identity integrity | Acceptance-gated adaptation; Local Persistence; scheduling contract | `PreparedExecutionPackage` identity fields; `ProgrammeExecutionContext` | acceptance + reversion + hardening suites; completion Self-Test 2 | assignmentId, programmeVersionId, packageContentHash preserved across adapt/revert | DIRECT |
| INV-05 | Restore and reconstruction preserve identity (accepted adapt or original) | `Local_Persistence_v1.md`; acceptance-gated adaptation | `AthleteLocalRepository`; `ProgrammeAdaptationReversionService`; hydrator | `coaching_integrity_test.dart` (reconstruction after restart); reversion service tests; hardening restore cases | Restart restores accepted decision or original programmed session with same identity | COMPOSITE |
| INV-06 | Previous-performance comparison is like-for-like / descriptive only; never becomes prescription | `Coaching_Constitution_v1.md`; workout player previous-performance rules | `PreviousPerformanceFromResults`; `PreviousPerformanceResolver` | `coaching_integrity_test.dart` (previous performance descriptive; history does not alter prescription); tripwire on `previous_performance_from_results.dart` | Uses athlete results; rejects invention; does not alter programmed prescription | COMPOSITE |
| INV-07 | Scheduling and adaptation are separate authorities | `Athlete_Controlled_Programme_Scheduling_v1.md`; `AGENTS.md` | scheduling preview/apply owners vs `ProgrammeAdaptation*` / `ProgrammeAdaptFlow` | `programme_scheduling_ownership_dependency_test.dart` | Adaptation owners forbid schedule mutate APIs; schedule owners forbid adapt pipeline / completion fabrication | DIRECT |
| INV-08 | Authored adaptation permissions bound lawful change kinds | `Adaptation_Policy_v1.md`; authored package permissions | `AdaptationPolicyGate`; package adaptation permissions | hardening `policy / no-safe cases`; equipment B4d.19 permission cases | Unsupported / rewrite kinds denied | DIRECT |
| INV-09 | Protected adaptation invariants (no rewrite plan / later sessions / force deload / move week via day-of) | `Adaptation_Policy_v1.md`; Coaching Constitution | `AdaptationPolicyGate.kindsForDayOf`; proposal/acceptance services | hardening policy tests; `coaching_integrity_test.dart` unsupported rejection | Prohibited kinds absent/rejected | DIRECT |
| INV-10 | Recommendations are policy-gated | Adaptation Policy; acceptance-gated adaptation | `AdaptationPolicyGate`; `ProgrammeAdaptationProposalService` | proposal + hardening + equipment suites | Non-policy outcomes are no-safe / not acceptable | COMPOSITE |
| INV-11 | Freshness fails closed | Acceptance-gated adaptation | acceptance freshness revalidation; `freshness_invalid` / `stale_plan` | `equipment_adaptation_b4d19_test.dart` freshness cases; `stale_plan` accept test | Stale / invalid freshness rejected; package unchanged | DIRECT |
| INV-12 | Athlete agreement precedes application | Acceptance-gated adaptation; Coaching Constitution | review → accept; `athlete_agreement_required`; sheet Accept control | equipment `athlete_agreement_required=false` rejected; `programme_adapt_flow_widget_test.dart` Accept only for reviewable; coaching integrity recommendation-before-accept | No durable adapt without explicit accept | COMPOSITE |
| INV-13 | Recommendation / acceptance / application context identity must match | Acceptance-gated adaptation (`_identityMatches`) | `ProgrammeAdaptationAcceptanceService`; reversion identity checks | **accept** `stale_identity` test; reversion `stale_identity` tests; hardening identity retention | Mismatch → `stale_identity`; no mutation | DIRECT |
| INV-14 | CURRENT-only adaptation scope | Acceptance-gated adaptation | `withAcceptedAdaptation` on current prepared package only | acceptance “replaces only executable plan”; hardening CURRENT scope cases | Only current prepared plan mutates | DIRECT |
| INV-15 | LATER occurrence integrity | Acceptance-gated adaptation; scheduling separation | no later-session rewrite kinds; schedule projection untouched by accept | hardening prohibited later-session kinds; scheduling ownership; acceptance identity preservation | Later sessions / schedule not mutated by adapt accept | COMPOSITE |
| INV-16 | Programme-authored source immutability | Authored Plan Package; acceptance-gated adaptation | package graph / version stores; prepare from authored slot | acceptance/reversion preserve hash/version; architecture dependency forbids generative reauthoring | Authored source unchanged by adapt | COMPOSITE |
| INV-17 | Idempotency and duplicate prevention | Acceptance-gated adaptation | consumed proposal set; `already_adapted` | accept `proposal_consumed` / `already_adapted`; hardening replay; equipment duplicate cases | Second apply fails closed | DIRECT |
| INV-18 | No unrelated mutation (dismiss/reject/cancel leave state unchanged) | Acceptance-gated adaptation | proposal dismiss; reject paths; reversion cancel | equipment reject unchanged; widget cancel no-op; coaching integrity dismiss | Non-accept paths leave prepared package unchanged | COMPOSITE |
| INV-19 | Connected-data privacy constraints (no location/travel categories) | `Connected_Data_Privacy_v1.md` | `lib/core/privacy/connected_data_contracts.dart` | `coaching_integrity_test.dart` privacy contracts; **tripwire** source freeze on contracts file | Forbidden kinds absent from enum/fields | DIRECT |
| INV-20 | Staging/production isolation | `Sprint_1_7_Athlete_D_Staging_Harness.md`; staging guard | `tool/staging/lib/s17_staging_guard.py`; `journey_d_non_test_runtime.dart` | `test/staging/s17_staging_guard_test.dart`; tripwire staging_tooling isolation + production refuse token | Production refused; product code does not import staging harness | COMPOSITE |

---

## Architectural drift tripwires (Phase 2.3 / 2.4)

Implemented in
`test/architecture/phase2_consolidation_safety_tripwires_test.dart`:

1. **Home dual-path freeze** — Home consumes
   `AthleteHomeRuntimeAuthorityResolver`; `programme` authority exposes
   `AthleteProgrammeTodaySection` / `ProgrammeAdaptFlow` only; legacy
   compatibility and loading/unavailable must not activate `HomeAdaptFlow`
   for programme athletes.
2. **Staging harness isolation** — `lib/features`, `lib/application`,
   `lib/domain`, `lib/planning`, `lib/core` must not import `staging_tooling`
   or product `staging/` harness modules; Journey D entrypoints remain under
   `lib/staging_tooling/` with production-refusal guard present.
3. **Connected-data privacy source freeze** — contracts file must not introduce
   prohibited location/travel categories on the allowed enum.
4. **Previous-performance authority freeze** — results-derived previous
   performance must not call generative / day-of adaptation rewrite paths.

Existing complementary tripwires remain in
`architecture_dependency_test.dart` and
`programme_scheduling_ownership_dependency_test.dart`.

---

## Gate groups (command topology)

| Group | Evidence |
|-------|----------|
| `architectural_boundaries` | architecture dependency, ownership, scheduling ownership, Phase 2.3 tripwires |
| `coaching_integrity` | Phase 6 coaching integrity |
| `adaptation_contracts` | proposal / accept / revert / 1.6E hardening / equipment B4d.19 |
| `programme_adapt_ui_contract` | `programme_adapt_flow_widget_test.dart` |
| `completion_identity` | Self-Test 2 local completion suite |
| `staging_production_isolation` | `s17_staging_guard_test.dart` (local; no hosted contact) |

The gate prints grouped PASS/FAIL and a final
`PHASE2_CONSOLIDATION_SAFETY_GATE=PASS|FAIL` summary. Missing required evidence
files exit non-zero before tests run.

---

## Binding companions

- [`Athlete_Programme_Acceptance_Gated_Adaptation_v1.md`](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md)
- [`Athlete_Controlled_Programme_Scheduling_v1.md`](./Athlete_Controlled_Programme_Scheduling_v1.md)
- [`Adaptation_Policy_v1.md`](./Adaptation_Policy_v1.md)
- [`Connected_Data_Privacy_v1.md`](./Connected_Data_Privacy_v1.md)
- [`../checkpoints/CURRENT_CHECKPOINT.md`](../checkpoints/CURRENT_CHECKPOINT.md)
