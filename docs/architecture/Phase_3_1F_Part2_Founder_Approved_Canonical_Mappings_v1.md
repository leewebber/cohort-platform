# Phase 3.1F Part 2 — Founder-Approved Canonical Exercises and Identity Mappings

**Status:** COMPLETE and **FOUNDER-ACCEPTED** (Lee Webber)  
**Recorded:** 2026-08-09  
**Part 1b commit:** `a53ba7c789a5ed8a7c716780a0ed6319cb910e07`  
**Baseline (post–Part 1b):** `a53ba7c789a5ed8a7c716780a0ed6319cb910e07`  
**Acceptance:** mechanical reproduction of diff, architectural boundaries, and
automated tests; SQL seed corrected to fail closed (no silent `ON CONFLICT`).

```text
PHASE_3_1F_PART_2_ACCEPTED=true
PHASE_3_1F_PART_2_COMPLETE=true
PHASE_3_1F_COMPLETE=true
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
FOUNDER_MAPPING_DECISIONS_RECORDED=true
BATCH_A_APPROVED=true
RUNNING_DECISION=generic_canonical_exercise
SKIERG_MAPPING_APPROVED=true
SKIERG_CANONICAL_ID=EX-050
WALL_BALL_MAPPING_APPROVED=true
WALL_BALL_CANONICAL_ID=EX-052
NEW_CANONICAL_EXERCISES_CREATED=5
IMPLEMENTED_MAPPING_COUNT=21
ALL_TRANSITIONAL_IDS_RESOLVE_EXACTLY_ONCE=true
HEURISTIC_IDENTITY_MATCHING_USED=false
MAPPING_IMPLIES_SUBSTITUTION=false
MAPPING_IMPLIES_COMPARABILITY=false
COMPARISON_PROTOCOL_REMAINS_SOLE_POSITIVE_AUTHORITY=true
HISTORICAL_EVIDENCE_REWRITTEN=false
HOSTED_ENVIRONMENT_CONTACTED=false
HOSTED_MUTATION_PERFORMED=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
MANUAL_TESTING_APPLICABILITY=deferred
```

---

## 1. Founder decisions implemented

| Decision | Outcome |
|----------|---------|
| Batch A (14 direct mappings) | Implemented exactly as Part 1b matrix |
| F-01 A Running | Created generic `EX-129` Running; mapped `cohort.exercise.running` → `EX-129` |
| F-02 SkiErg | Mapped → `EX-050` with device/protocol/banded-ski boundary notes |
| F-03 Wall Ball | Mapped → `EX-052`; load/height/sex/HYROX remain prescription/protocol |
| Create five canonicals | `EX-128`…`EX-132` authored in local migration |
| Rejections | None |

---

## 2. Five canonical definitions created

Local migration (hosted apply **not** authorised):

`supabase/migrations/20260809160000_founder_exercise_library_phase_3_1f_part2.sql`

| ID | Name | Notes |
|----|------|-------|
| `EX-128` | Lat Pulldown | Cable vertical pull; not Pull Up |
| `EX-129` | Running | Generic locomotion; not intensity-specific; not outdoor/treadmill-only |
| `EX-130` | Burpee Broad Jump | Combined; distinct from EX-009 / EX-024 |
| `EX-131` | Sled Push | Distinct from Sled Pull |
| `EX-132` | Sled Pull | Distinct from Sled Push |

Allocation: next contiguous ids after Part 1b export max `EX-127`. Collision check:
unused in Wave 1 and all other local migrations; Part 1b meta max=`EX-127`.

---

## 3. Complete 21-item implemented mapping table

Artifact:
`lib/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart`

| Transitional ID | Canonical EX-* | Name |
|-----------------|----------------|------|
| `cohort.exercise.back_squat` | `EX-073` | Back Squat |
| `cohort.exercise.front_squat` | `EX-074` | Front Squat |
| `cohort.exercise.goblet_squat` | `EX-030` | Goblet Squat |
| `cohort.exercise.romanian_deadlift` | `EX-078` | Romanian Deadlift |
| `cohort.exercise.walking_lunge` | `EX-025` | Walking Lunge |
| `cohort.exercise.pull_up` | `EX-053` | Pull Up |
| `cohort.exercise.lat_pulldown` | `EX-128` | Lat Pulldown |
| `cohort.exercise.bench_press` | `EX-083` | Bench Press |
| `cohort.exercise.strict_press` | `EX-088` | Strict Press |
| `cohort.exercise.push_up` | `EX-012` | Push Up |
| `cohort.exercise.running` | `EX-129` | Running |
| `cohort.exercise.rowing` | `EX-049` | Row Erg |
| `cohort.exercise.ski_erg` | `EX-050` | Ski Erg |
| `cohort.exercise.burpee_broad_jump` | `EX-130` | Burpee Broad Jump |
| `cohort.exercise.sled_push` | `EX-131` | Sled Push |
| `cohort.exercise.sled_pull` | `EX-132` | Sled Pull |
| `cohort.exercise.farmer_carry` | `EX-101` | Farmer Carry |
| `cohort.exercise.wall_ball` | `EX-052` | Wall Ball |
| `cohort.exercise.plank` | `EX-021` | Plank |
| `cohort.exercise.dead_bug` | `EX-022` | Dead Bug |
| `cohort.exercise.box_jump` | `EX-059` | Box Jump |

---

## 4. Mapping provenance

- Owner: `founder`
- Lifecycle: `published` (domain bridge seed; not a hosted mapping table)
- Provenance string records Lee Webber Phase 3.1F approval
- Explicit transitional → `EX-*` only; no name/heuristic/graph/substitution derivation

---

## 5. Running ontology (F-01 A)

`EX-129` is the generic Running identity. Intensity labels (Easy/Threshold/Sprint)
remain separate catalogue rows. Outdoor vs treadmill vs curved treadmill remain
environment/equipment/context. Pace/distance/duration/intensity remain
prescription. Same canonical id does **not** auto-merge comparison histories;
protocol authority governs comparability.

---

## 6. SkiErg boundary (F-02)

`EX-050` is SkiErg exercise/device identity. Resistance/distance/calories/pace are
prescription/scoring. Banded ski-pattern work is a different identity and must not
share SkiErg performance history. Graph relationships cannot grant identity or
comparability.

---

## 7. Wall-ball boundary (F-03)

`EX-052` is the single Wall Ball identity. Ball load, target height, sex/category,
HYROX competition rules and valid-rep scoring remain prescription / movement-standard
/ comparison-protocol layers. Two prescriptions resolving to `EX-052` are not
automatically comparable.

---

## 8. Prescription / comparison / history / consumers

| Boundary | Status |
|----------|--------|
| Prescription authored by programme/session | Unchanged |
| Comparison protocol sole positive authority | Preserved (`ComparabilityFirewall.bridgeMappingImpliesComparability()==false`) |
| Historical evidence rewrite | **Not performed** |
| Live consumer migration | **Not performed** |
| Bridge as automatic runtime path | **Not wired** outside `exercise_knowledge` |

---

## 9. SQL seed safety

`20260809160000_founder_exercise_library_phase_3_1f_part2.sql` is a catalogue
**data seed only** (no DDL). It uses a fail-closed `DO` block:

- exact match of all five approved rows → idempotent no-op;
- partial or mismatched rows for `EX-128`…`EX-132` → `RAISE EXCEPTION` (no overwrite);
- absent rows → single multi-row `INSERT` with **no** `ON CONFLICT` clause.

---

## 10. Hosted-deployment exclusion

- Local migration + Dart seed authored
- No `supabase db push`, hosted INSERT/UPDATE/UPSERT/DELETE, or RPC mutation
- Hosted catalogue still ends at `EX-127` until a separately authorised deploy

---

## 11. Acceptance validation (reproduced)

| Check | Result |
|-------|--------|
| Five canonicals `EX-128`…`EX-132` | Validated |
| 21 mappings resolve exactly once | Validated |
| No live consumer wired to founder seed | Validated |
| Full Flutter suite | See commit-time report |
| Phase 2 safety gate | PASS 6/6 |
| Hosted contact / mutation | None |
| Manual testing | Deferred |

---

## 12. Remaining work (after Part 2 commit)

Phase 3.1F is **complete** at the local-implementation checkpoint. Phase 3.1 remains
**incomplete** until separately authorised rollout:

1. Founder review of deployment + first-consumer plan
2. Narrowly authorised hosted catalogue deployment (`EX-128`–`EX-132`)
3. Separately authorised first-consumer implementation

See uncommitted plan (founder review):  
`Phase_3_1F_Canonical_Deployment_and_First_Consumer_Plan_v1.md`

Manual testing: deferred to first live consumer integration of approved mappings.
