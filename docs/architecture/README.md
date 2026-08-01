# Architecture documentation index

**Phase 2 (Architecture Consolidation)** closed on branch `refactor/architecture-alignment`. Start here for orientation.

| Document | Purpose |
|----------|---------|
| [Architecture_Blueprint_v2.md](./Architecture_Blueprint_v2.md) | Primary technical reference — layers, pipelines, ports, ADR index |
| [Authored_Plan_Package_v1.md](./Authored_Plan_Package_v1.md) | Phase 1 Sprint 1.1–1.2 — Authored Plan Package compile/import/catalogue |
| [Athlete_Catalogue_Enrolment_v1.md](./Athlete_Catalogue_Enrolment_v1.md) | Phase 1 Sprint 1.3 — non-commercial athlete catalogue enrolment |
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
| [Adaptation_Policy_v1.md](./Adaptation_Policy_v1.md) | **Phase 6 Sprint 4** — explicit adaptation rules |
| [Connected_Data_Privacy_v1.md](./Connected_Data_Privacy_v1.md) | **Phase 6 Sprint 4** — connected data & no-location policy |
| [../planning/Planning_Engine_Implementation_v1.md](../planning/Planning_Engine_Implementation_v1.md) | Phase 4 Sprint 1 — `PlanningEngineService` merge policies |
| [../planning/Session_Blueprint_Implementation_v1.md](../planning/Session_Blueprint_Implementation_v1.md) | Phase 4 Sprint 2 — `SessionBlueprint` generator |
| [Phase_2_Architecture_Consolidation_Completion.md](./Phase_2_Architecture_Consolidation_Completion.md) | Sprint 10 closure report — verification, adapters, limitations, DoD |
| [adrs/](./adrs/) | Standalone architecture decision records (ADR-017+) |

**Companion product docs** (under `07 Documentation/`):

| Doc | Topic |
|-----|--------|
| `41_Programme_Engine.md` | Programme schedule and assignment |
| `52_M8_Performance_Capture_and_Training_History.md` | M8 performance tree |
| `66_V2_0_End_To_End_Execution_And_Adaptation.md` | Completion + post-completion adaptation |
| `79_Adaptation_Ontology_V1.md` | Domain adaptation vocabulary |

**Historical:** Pre–Phase 2A behaviour (e.g. `AdaptationDecisionService`) is noted in those docs where relevant; it is not the current architecture.
