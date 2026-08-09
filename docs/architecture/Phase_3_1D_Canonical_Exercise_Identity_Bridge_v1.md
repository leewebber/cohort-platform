# Phase 3.1D — Canonical Exercise Identity Bridge

**Status:** COMPLETE and **COMMITTED**  
**Recorded:** 2026-08-09  
**Commit:** `38f27ca478779903fc1d93bca5368daed87388f2`  
**Baseline (post–3.1C commit):** `957a63d9809e8291b8715e3743feccb93a798eee`  
**Fixture correction before commit:** retired mapping uses
`cohort.exercise.back_squat_legacy → EX-9001` (same back squat), not a false
`pull_up → back squat` identity.  
**Repository boundary:** [`Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md`](./Phase_3_1C_Exercise_Knowledge_Repository_Boundary_v1.md)

```text
PHASE_3_1C_ACCEPTED=true
PHASE_3_1D_IDENTITY_BRIDGE_COMPLETE=true
CANONICAL_EXERCISE_ID=EX-*
THIRD_EXERCISE_ID_INTRODUCED=false
HEURISTIC_IDENTITY_MATCHING_USED=false
TRANSITIONAL_IDS_AUTHORITATIVE=false
SUBSTITUTION_IMPLIES_COMPARABILITY=false
HISTORICAL_EVIDENCE_REWRITTEN=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=deferred
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

---

## 1. Why the bridge exists

Cohort has two identifier systems today:

| System | Identity | Role |
|--------|----------|------|
| Platform catalogue | `EX-*` | Canonical athlete/founder catalogue |
| Knowledge ontology | `cohort.exercise.*` | Transitional semantics for policy/adaptation |

Phase 3.1D provides one explicit, deterministic, auditable bridge:
**transitional → canonical `EX-*`**, without inventing a third identity or
guessing from names.

---

## 2. Canonical identity

`EX-*` remains the sole canonical exercise identity (`ExerciseId`).
Runtime and downstream consumers must never receive a transitional id as
canonical.

---

## 3. Transitional-ID semantics

`TransitionalExerciseId` accepts only `cohort.exercise.<snake_case>`.
Transitional ids are source identifiers for knowledge facts — never
authoritative runtime identity.

---

## 4. Mapping direction and invariants

Direction: `cohort.exercise.*` → `EX-*` only.

Protected invariants (see `ExerciseIdentityMappingValidator`):

* valid transitional source + valid canonical target;
* at most one active canonical target per transitional id;
* missing canonical target fails closed;
* duplicate / conflicting active mappings fail closed;
* blank or heuristic provenance (`name_match`, `guess`, …) rejected;
* draft mappings are not operational;
* founder authority required to publish/retire;
* mapping ≠ substitution / comparability / shared history.

---

## 5. Explicit mapping versus aliases / name matching

| Mechanism | Establishes identity? |
|-----------|------------------------|
| `ExerciseIdentityMapping` with provenance | **Yes** (only) |
| Search aliases on `ExerciseDefinition` | No |
| Display names / labels | No |
| Movement family / pattern | No |
| `platform_exercise_id` in YAML (when authored) | Yes — future seed into bridge |

---

## 6. Canonicalised knowledge adapter

`CanonicalisedExerciseKnowledgeAdapter`:

* resolves identity through the bridge;
* preserves existing `ExerciseKnowledge` facts;
* exposes `ExerciseId` + transitional provenance;
* quarantines unmapped/conflicting entries with structured issues;
* never grants substitution or comparison;
* is not a second knowledge authority.

---

## 7. Unmapped and conflicting identity handling

| Outcome | Behaviour |
|---------|-----------|
| Unmapped | `TransitionalIdentityUnmapped` / quarantine; original knowledge retained |
| Invalid | `TransitionalIdentityInvalid` |
| Conflict | `TransitionalIdentityConflict`; `toCanonical` returns null |
| Missing target | Validation issue `missing_canonical_target` |

Partial honest coverage is required — do not force incorrect consolidation.

---

## 8. Publication and founder authority

`ExerciseIdentityMappingPublicationService`:

Draft → validate → founder publish → retire (historically resolvable).

---

## 9. Historical resolution

Retired mappings are excluded from operational `toCanonical` but remain
resolvable via `resolve(..., includeHistorical: true)`.

---

## 10. Mapping does not imply substitution or comparison

Mapping only answers “which canonical id names this knowledge record?”.
Substitution permission, comparison protocols, and performance series remain
separate authorities (unchanged in 3.1D).

---

## 11. Consumers integrated

**None.** Bridge and adapter are proven via isolated domain/tests only.
No Workout Player, Plan Package, adaptation, previous-performance, or
Progress wiring.

---

## 12. Consumers deferred

* Exercise Policy / day-of adaptation knowledge resolution
* Workout Player hydration
* Plan Package `exercise_id` validation
* Previous-performance / completion identity
* Production `platform_exercise_id` population in YAML

---

## 13. Migration implications

Historical completion evidence is **not** rewritten.
Programme prescriptions are **not** modified.
Transitional catalogue is **not** deleted.

---

## 14. Production-persistence implications

Bridge uses in-memory mapping sets only. Production persistence still requires
an authorised schema sprint. Do not improvise storage.

**Phase 3.1F Part 2 update:** Founder-approved production mapping seed lives at
`lib/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart`
(21 published mappings). Local catalogue additions `EX-128`–`EX-132` are in
`supabase/migrations/20260809160000_founder_exercise_library_phase_3_1f_part2.sql`
(hosted apply separately authorised). See
[`Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md`](./Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md).
Live consumers remain unwired.

---

## 15. Identity inventory (deterministic, local)

### Canonical `EX-*` in-repo

No full production `exercises_v2` dump is present in the worktree (hosted
inventory not contacted). Local Exercise Knowledge fixtures define
`EX-9001`…`EX-9009` for contract tests. Live catalogue ids remain in Supabase
and are out of scope for hosted contact in this sprint.

### Transitional `cohort.exercise.*` (21 in `exercises_reference.yaml`)

```
back_squat, front_squat, goblet_squat, romanian_deadlift, walking_lunge,
pull_up, lat_pulldown, bench_press, strict_press, push_up, running, rowing,
ski_erg, burpee_broad_jump, sled_push, sled_pull, farmer_carry, wall_ball,
plank, dead_bug, box_jump
```

### Existing explicit links

* YAML `platform_exercise_id`: **0** authored links in reference ontology.
* Phase 3.1B fixture `transitionalAliasIds`:
  * `cohort.exercise.back_squat` ↔ `EX-9001`
  * `cohort.exercise.goblet_squat` ↔ `EX-9002`

### Clear fixture targets (test mappings only)

| Transitional | Canonical | Notes |
|--------------|-----------|-------|
| `back_squat` | EX-9001 | From 3.1B transitionalAliasIds |
| `bb_back_squat_alt` | EX-9001 | Explicit multi-map fixture (not in YAML) |
| `goblet_squat` | EX-9002 | From 3.1B transitionalAliasIds |
| `ski_erg` | EX-9006 | Fixture; ≠ comparison grant |
| `wall_ball` | EX-9008 | Fixture; HYROX standard separate |
| `back_squat_legacy` | EX-9001 | Retired prior label for same back squat |

### Unmapped production transitional ids (19 remaining in YAML)

All YAML entities lack `platform_exercise_id`. Unmapped for operational
canonicalisation until founder authors explicit links against real `EX-*`
catalogue rows — **not** via name similarity.

### Potential collisions (do not auto-map)

* `running` vs outdoor vs treadmill (`EX-9004`/`EX-9005` fixtures) — standards/setup differ; founder must choose.
* `wall_ball` vs HYROX wall-ball protocol — sport standard is not a second id, but careless merge risks false comparability.
* `ski_erg` vs banded ski simulation — related for adaptation, not identity.
* Name-similar squats (`back` / `front` / `goblet`) — distinct identities.

### Current consumers

| Identity system | Consumers (unchanged) |
|-----------------|------------------------|
| `EX-*` | `ExerciseRepository` / catalogue / Workout Player hydrate |
| `cohort.exercise.*` | YAML ontology, Exercise Policy, day-of adaptation substitutions |

---

## 16. Manual testing

```text
MANUAL_TESTING_APPLICABILITY=DEFERRED_TO_FIRST_LIVE_CONSUMER_INTEGRATION
MANUAL_TEST_PLAN=documented
APP_LAUNCHED_IN_CHROME=false
MANUAL_TESTS_COMPLETED=false
USER_JOURNEYS_PASSED=0
USER_JOURNEYS_FAILED=0
USER_JOURNEYS_BLOCKED=0
REGRESSIONS_FOUND=0
DEFERRED_TEST_TRIGGER=First live consumer integration of TransitionalExerciseIdBridge (expected Phase 3.1E+ or dedicated integration sprint)
```

Prepared Chrome regression sequence (run when a live seam is wired):

1. Launch app (safe local/test config)
2. Sign in via existing safe path
3. Open programme/training catalogue
4. Inspect session with exercises — names/order
5. Open Workout Player — programmed exercises resolve
6. Enter representative performance (safe test context)
7. Refresh/restore — session state survives
8. Completion/history attributes correct exercise
9. Previous-performance presentation unchanged
10. No `cohort.exercise.*` shown to athlete
11. No new runtime exceptions / broken routes

---

## 17. Founder decisions required

1. Author `platform_exercise_id` (or bridge mapping records) for each of the 21
   reference ontology exercises against the live `EX-*` catalogue — **without**
   name-only matching.
2. Decide outdoor vs treadmill identity for `cohort.exercise.running`.
3. Confirm HYROX wall-ball / SkiErg mappings do not silently share comparison
   protocols with modified or hotel alternatives.

---

## 18. Exact next sprint

**Phase 3.1E — Structured Exercise Relationship Graph**

---

## Implementation map

| Area | Path |
|------|------|
| Bridge port | `ports/transitional_exercise_id_bridge.dart` |
| In-memory bridge | `in_memory/in_memory_transitional_exercise_id_bridge.dart` |
| Mapping model | `models/exercise_identity_mapping.dart` |
| Transitional id VO | `value_objects/transitional_exercise_id.dart` |
| Validator / publication | `validation/…`, `services/exercise_identity_mapping_publication_service.dart` |
| Adapter | `adapters/canonicalised_exercise_knowledge_adapter.dart` |
| Tests | `test/domain/exercise_knowledge/exercise_identity_bridge_*.dart` |
