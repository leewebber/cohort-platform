# Architecture documentation index

**Phase 2 is CLOSED. Phase 3 — Exercise Database: Phase 3.1F is COMPLETE
(founder-accepted local mappings + catalogue seed). Phase 3.1 rollout
(hosted deploy + first consumer) remains separately authorised.**
Start from
[`../checkpoints/CURRENT_CHECKPOINT.md`](../checkpoints/CURRENT_CHECKPOINT.md)
and
[`Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](./Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md).

The July 2026 document
[Phase_2_Architecture_Consolidation_Completion.md](./Phase_2_Architecture_Consolidation_Completion.md)
is **historical pre–Phase 1 architecture alignment** (then also labeled
“Phase 2”). It is not authoritative for the current programme path.

| Document | Purpose |
|----------|---------|
| [Canonical_Programme_Architecture_Freeze_v1.md](./Canonical_Programme_Architecture_Freeze_v1.md) | **Binding** — frozen programme athlete architecture (Phase 2.10) |
| [Phase_2_Closure_v1.md](./Phase_2_Closure_v1.md) | Phase 2 closure record (2.1–2.10) |
| [Phase_3_1A_Exercise_Database_Discovery_v1.md](./Phase_3_1A_Exercise_Database_Discovery_v1.md) | Phase 3.1A — Exercise Database discovery (accepted; docs only) |
| [Phase_3_1B_Exercise_Knowledge_Contracts_v1.md](./Phase_3_1B_Exercise_Knowledge_Contracts_v1.md) | Phase 3.1B — Canonical Exercise Knowledge domain contracts |
| [Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md](./Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md) | Phase 3.1C — Exercise Knowledge repository / publication boundary |
| [Phase_3_1D_Canonical_Exercise_Identity_Bridge_v1.md](./Phase_3_1D_Canonical_Exercise_Identity_Bridge_v1.md) | Phase 3.1D — Canonical exercise identity bridge (`cohort.exercise.*` → `EX-*`) |
| [Phase_3_1E_Exercise_Relationship_Graph_v1.md](./Phase_3_1E_Exercise_Relationship_Graph_v1.md) | Phase 3.1E — Structured Exercise Relationship Graph |
| [Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md](./Phase_3_1F_Part1_Founder_Identity_Mapping_Review_v1.md) | Phase 3.1F Part 1/1b — Founder identity-mapping review + decision matrix |
| [Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md](./Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md) | Phase 3.1F Part 2 — Founder-approved canonicals + 21 identity mappings |
| [Phase_3_1F_Pending_Migration_Reconciliation_v1.md](./Phase_3_1F_Pending_Migration_Reconciliation_v1.md) | Phase 3.1F — Pending migration reconciliation (Option C) |
| [Phase_3_1F_Hosted_Catalogue_Deployment_Checkpoint_v1.md](./Phase_3_1F_Hosted_Catalogue_Deployment_Checkpoint_v1.md) | Phase 3.1F — Hosted catalogue deployment STOP checkpoint |
| [Phase_1_2_to_1_7_Staging_Uplift_Plan_v1.md](./Phase_1_2_to_1_7_Staging_Uplift_Plan_v1.md) | Phase 1.2–1.7 — Cohort Staging uplift plan (accepted; schema already present) |
| [Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md](./Phase_1_2_to_1_7_Staging_Manual_Verification_v1.md) | Phase 1.2–1.7 — Staging Athlete E manual verification (STOPPED; accepted) |
| [Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md](./Phase_1_2_to_1_7_Staging_Verification_Prerequisites_v1.md) | Phase 1.2–1.7 — Staging verification prerequisites (logical backup + Athlete E bootstrap) |
| [Phase_1_2_to_1_7_Staging_Gate_1_Verification_v1.md](./Phase_1_2_to_1_7_Staging_Gate_1_Verification_v1.md) | Phase 1.2–1.7 — Staging Gate 1 backend/RPC verification (complete; product-UI Gate 2 remains unverified) |
| [Phase_1_2_to_1_7_Field_Manual_Uplift_Verification_v1.md](./Phase_1_2_to_1_7_Field_Manual_Uplift_Verification_v1.md) | Phase 1.2–1.7 — Cohort Field Manual nine-migration uplift verification (complete; founder-accepted permanent evidence) |
| [Phase_3_1F_Canonical_Deployment_and_First_Consumer_Plan_v1.md](./Phase_3_1F_Canonical_Deployment_and_First_Consumer_Plan_v1.md) | Phase 3.1F — Hosted deploy + first-consumer rollout plan (accepted) |
| [Architecture_Blueprint_v2.md](./Architecture_Blueprint_v2.md) | Primary technical reference — layers, pipelines, ports, ADR index |
| [Authored_Plan_Package_v1.md](./Authored_Plan_Package_v1.md) | Phase 1 Sprint 1.1–1.2 — Authored Plan Package compile/import/catalogue |
| [Athlete_Catalogue_Enrolment_v1.md](./Athlete_Catalogue_Enrolment_v1.md) | Phase 1 Sprint 1.3 — non-commercial athlete catalogue enrolment |
| [Athlete_Plan_Materialisation_v1.md](./Athlete_Plan_Materialisation_v1.md) | Phase 1 Sprint 1.4A — exact authored plan materialisation and cursor authority |
| [Athlete_First_Prepared_Session_v1.md](./Athlete_First_Prepared_Session_v1.md) | Phase 1 Sprint 1.4B — deterministic first prepared session |
| [Sprint_1_4B_Staging_Self_Test_1.md](./Sprint_1_4B_Staging_Self_Test_1.md) | Phase 1 Sprint 1.4B — retained staging Self-Test 1 closure |
| [Athlete_Programme_Completion_Advancement_v1.md](./Athlete_Programme_Completion_Advancement_v1.md) | Phase 1 Sprint 1.5A — atomic completion and authored cursor advancement |
| [Sprint_1_5A_Staging_Self_Test_2.md](./Sprint_1_5A_Staging_Self_Test_2.md) | Phase 1 Sprint 1.5A — staging Self-Test 2 closure at `4365568` |
| [Athlete_Programme_Acceptance_Gated_Adaptation_v1.md](./Athlete_Programme_Acceptance_Gated_Adaptation_v1.md) | Phase 1 Sprint 1.6A — programme-backed acceptance-gated adaptation authority |
| [Athlete_Controlled_Programme_Scheduling_v1.md](./Athlete_Controlled_Programme_Scheduling_v1.md) | Phase 1 Sprint 1.7 — athlete-controlled programme scheduling (1.7A–1.7F complete: restore, Move/Swap/Push/Skip/Undo, durable horizon, calendar) |
| [Sprint_1_7_Athlete_D_Staging_Harness.md](./Sprint_1_7_Athlete_D_Staging_Harness.md) | Phase 1 Release Gate B4a — Athlete D staging harness (local); hosted create/verify remains B4b |
| [Planning_Engine_v1.md](./Planning_Engine_v1.md) | **Phase 3.5** — planning pipeline, contracts, ownership (canonical for Phase 4) |
| [Architecture_Freeze_v1.md](./Architecture_Freeze_v1.md) | **Phase 4.5** — freeze, readiness, architecture tests, Phase 5 recommendation |
| [../product/Workout_Player_MVP.md](../product/Workout_Player_MVP.md) | **Phase 5 Sprint 1** — athlete Workout Player vertical slice |
| [../product/Athlete_Creation_MVP.md](../product/Athlete_Creation_MVP.md) | **Phase 5 Sprint 2** — athlete onboarding → Coach Brain programme |
| [../product/Plan_Library_MVP.md](../product/Plan_Library_MVP.md) | **Phase 5 Sprint 3** — Plan library & active plan assignment |
| [../product/Adaptive_Progression_MVP.md](../product/Adaptive_Progression_MVP.md) | **Phase 5 Sprint 4** — completion → evidence → next session |
| [../product/Progress_Experience_MVP.md](../product/Progress_Experience_MVP.md) | **Phase 5 Sprint 5** — Progress experience (“Am I getting better?”) |
| [../product/Daily_Briefing_MVP.md](../product/Daily_Briefing_MVP.md) | **Phase 5 Sprint 6** — Home daily coaching briefing |
| [../reviews/Cohort_MVP_Design_Review_v1.md](../reviews/Cohort_MVP_Design_Review_v1.md) | **Phase 6 Sprint 1** — Athlete MVP UX design review (recommendations) |
| [Local_Persistence_v1.md](./Local_Persistence_v1.md) | **Phase 6 Sprint 3** — local athlete memory technology + hydration |
| [Local_Persistence_Inventory_v1.md](./Local_Persistence_Inventory_v1.md) | **Phase 6 Sprint 3** — stored aggregates inventory |
| [../product/Cohort_Product_Constitution_v1.md](../product/Cohort_Product_Constitution_v1.md) | **Phase 6 Sprint 3** — athlete product surface principles |
| [Coaching_Constitution_v1.md](./Coaching_Constitution_v1.md) | **Phase 6 Sprint 4** — coach authority & programme integrity |
| [Session_Authority_Model_v1.md](./Session_Authority_Model_v1.md) | **Phase 6 Sprint 4** — programmed / prepared / completed |
| [Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md) | **Phase 6 Sprint 4** — explicit adaptation rules (general; programme path refined by 1.6A) |
| [Connected_Data_Privacy_v1.md](./Connected_Data_Privacy_v1.md) | **Phase 6 Sprint 4** — connected data & no-location policy |
| [../planning/Planning_Engine_Implementation_v1.md](../planning/Planning_Engine_Implementation_v1.md) | Phase 4 Sprint 1 — `PlanningEngineService` merge policies |
| [../planning/Session_Blueprint_Implementation_v1.md](../planning/Session_Blueprint_Implementation_v1.md) | Phase 4 Sprint 2 — `SessionBlueprint` generator |
| [Phase_2_Architecture_Consolidation_Completion.md](./Phase_2_Architecture_Consolidation_Completion.md) | **Historical** pre–Phase 1 architecture alignment (2026-07-29); not current Phase 2 authority |
| [adrs/](./adrs/) | Standalone architecture decision records (ADR-017+) |

**Companion product docs** (under `07 Documentation/`):

| Doc | Topic |
|-----|--------|
| `41_Programme_Engine.md` | Programme schedule and assignment |
| `52_M8_Performance_Capture_and_Training_History.md` | M8 performance tree |
| `66_V2_0_End_To_End_Execution_And_Adaptation.md` | Completion + post-completion adaptation |
| `79_Adaptation_Ontology_V1.md` | Domain adaptation vocabulary |

**Historical:** Pre–Phase 2A behaviour (e.g. `AdaptationDecisionService`) is noted in those docs where relevant; it is not the current architecture.

**Current delivery checkpoint:** Phase 1 is **CLOSED** at `e034ea9`. Phase 2 is
**CLOSED**. Phase 3.1F is **COMPLETE** (founder-accepted). Hosted catalogue
deployment and first-consumer migration are **not** started. Phase 3.1 is
**not** complete. See
[`Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](./Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md)
and [`../checkpoints/CURRENT_CHECKPOINT.md`](../checkpoints/CURRENT_CHECKPOINT.md).
