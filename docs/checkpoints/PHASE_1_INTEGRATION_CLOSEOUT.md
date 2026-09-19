# Phase 1 Integration Closeout

**Recorded:** 2026-09-14  
**Status:** Phase 1 Integration Closeout documentation and lifecycle prevention
are complete locally. Integration into `origin/main` and any push remain
**paused for founder approval**.

This is the current repository checkpoint for dogfood Phase 1. It supersedes
`CURRENT_CHECKPOINT.md` as the live delivery pointer. That file remains the
historical atomic-resume / Phase 3 record and is not rewritten as if those
tasks were the next work.

**M9 is closed.** See
[`M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md`](./M9_CONTENT_RELATIONSHIP_GRAPH_CLOSEOUT.md).
The next numerical milestone is M10. Founder phone **build 7** is current; M9
did not require a phone release.

```text
PHASE_1_SPRINTS_1_1_TO_1_7_CLOSED=true
PHASE_1_CLOSED_AT_DOCS_COMMIT=e034ea9
PHASE_1_HARNESS_HEAD_REVIEWED=7ba8455
PHASE_1_INTEGRATION_CLOSEOUT_AUTHORISED=true
PHASE_1_INTEGRATION_BASE=origin/main
PHASE_1_INTEGRATION_BASE_HEAD=fe7576d76fcaf72388c05cbee32e4315e93cd5b8
PHASE_1_DOGFOOD_HEAD_AT_START=969ef5bddf143bbdd44383bd740fcb65a669dc51
POST_PHASE_1_INTEGRATION_COMMITS_FROM_MAIN=138
CANONICAL_ARCHITECTURE_FROZEN=true
PHASE_2_CLOSED=true
LEE_FOUNDER_BUILD=1.0.0+4
LEE_FOUNDER_BUNDLE=uk.cohortperformance.cohort
LEE_FOUNDER_BUILD_COMMIT=969ef5bddf143bbdd44383bd740fcb65a669dc51
PUBLIC_LAUNCH_READY=false
PRODUCT_UI_GATE_2_VERIFIED=false
MULTI_ATHLETE_BETA_READY=false
WEARABLES=false
EXERCISE_VIDEO_LIBRARY=false
PAYMENTS=false
HOSTED_MUTATIONS_IN_THIS_TASK=0
NOTHING_PUSHED=true
NEXT_MILESTONE=PROGRESSION_MECHANICS_VALIDATION
NEXT_TASK_IMPLEMENTATION_AUTHORISED=false
```

## Binding sources of truth

| Layer | Document |
|-------|----------|
| Implemented architecture | [Phase_1_Implemented_Architecture_v1.md](../architecture/Phase_1_Implemented_Architecture_v1.md) |
| Commit / capability map | [Phase_1_Dogfood_Commit_Chain_v1.md](../architecture/Phase_1_Dogfood_Commit_Chain_v1.md) |
| Calendar / incomplete recovery | [Athlete_Calendar_Month_Grid_and_Recovery_v1.md](../architecture/Athlete_Calendar_Month_Grid_and_Recovery_v1.md) |
| Backfill | [Backfill_Fixed_Programme_Session_Results_v1.md](../architecture/Backfill_Fixed_Programme_Session_Results_v1.md) |
| Circuit / EMOM capture | [Athletic_Circuit_and_EMOM_Capture_v1.md](../architecture/Athletic_Circuit_and_EMOM_Capture_v1.md) |
| Lifecycle diagnosis | [Phase_1_Lifecycle_Inconsistencies_v1.md](../architecture/Phase_1_Lifecycle_Inconsistencies_v1.md) |
| Preview inventory | [Phase_1_Preview_Inventory_v1.md](../architecture/Phase_1_Preview_Inventory_v1.md) |
| Migration chain | [Phase_1_Migration_Chain_v1.md](../architecture/Phase_1_Migration_Chain_v1.md) |
| Tests | [Phase_1_Test_Suite_Inventory_v1.md](../architecture/Phase_1_Test_Suite_Inventory_v1.md) |
| Dev baseline | [Phase_1_Development_Baseline_v1.md](../architecture/Phase_1_Development_Baseline_v1.md) |
| Integration readiness | [Phase_1_Integration_Readiness_v1.md](../architecture/Phase_1_Integration_Readiness_v1.md) |
| Roadmap | [../planning/Delivery_Roadmap_v1.md](../planning/Delivery_Roadmap_v1.md) |
| Frozen programme architecture | [Canonical_Programme_Architecture_Freeze_v1.md](../architecture/Canonical_Programme_Architecture_Freeze_v1.md) |

## Founder build (recorded; not re-installed)

Cohort Platform **1.0.0 (4)** on bundle `uk.cohortperformance.cohort`, signed
with the existing Apple development team, from commit
`969ef5bddf143bbdd44383bd740fcb65a669dc51`. This closeout does not install
another phone build and does not mutate Field Manual.

## What Phase 1 now includes

Canonical plan-package compiler; Apollo v2 assignment/materialisation;
schedule occurrences and Calendar; Home as today-only command centre;
persistent execution and resume; strength accordion and result capture;
intervals / endurance / circuits / EMOM capture; session completion and
correction; Progress evidence; incomplete-session Train today; Backfill
results; explicit Reschedule; late-completion chronology; safe seven-day
move/swap; production athlete shell; founder iPhone deployment workflow.

## Explicitly not claimed

Launch readiness, public-auth production hardening, wearables, full exercise
video, notifications, payments, external coach authoring, advanced
adaptation, or controlled multi-athlete beta. Those remain later milestones.

## Follow-on: hosted lifecycle reconciliation (2026-09-14)

Authorised separately from this closeout document. Field Manual received
only `20260914120000` (trigger, zero historical rows) and `20260914121000`
(generic parent close). Three parents (33, 34, 39) became `completed` from
existing live records. Sessions 30 and 31 remain `in_progress`. Result
trees, occurrences, slot outcomes, schedule operations, and the assignment
cursor were unchanged. Founder build 1.0.0 (4) was not reinstalled.
Progression Mechanics Validation remains paused until founder approval.
