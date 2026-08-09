# Phase 3.1F Part 1 — Founder Canonical Catalogue and Identity-Mapping Review

**Status:** COMPLETE for Part 1 scope — **STOPPED before mapping proposals**  
**Reason:** Authoritative complete local `EX-*` catalogue unavailable  
**Recorded:** 2026-08-09  
**Baseline (post–3.1E commit):** `b03faa9d656d2a4fc3005d79205796f0abe07f56`

```text
PHASE_3_1E_ACCEPTED=true
PHASE_3_1E_COMMITTED=true
PHASE_3_1E_COMMIT=b03faa9d656d2a4fc3005d79205796f0abe07f56
COMPARISON_PROTOCOL_REMAINS_SOLE_POSITIVE_AUTHORITY=true
PHASE_3_1F_PART_1_REVIEW_PACKET_COMPLETE=true
AUTHORITATIVE_CANONICAL_CATALOGUE_AVAILABLE=false
CANONICAL_EXERCISE_ID=EX-*
TRANSITIONAL_EXERCISE_COUNT=21
PROPOSED_MAPPING_COUNT=0
AMBIGUOUS_MAPPING_COUNT=0
MISSING_CANONICAL_COUNT=0
SPLIT_REQUIRED_COUNT=0
PRODUCTION_MAPPINGS_IMPLEMENTED=false
CANONICAL_EXERCISES_CREATED=false
HEURISTIC_IDENTITY_MATCHING_USED=false
HISTORICAL_EVIDENCE_REWRITTEN=false
LIVE_CONSUMERS_MIGRATED=false
PRODUCT_BEHAVIOUR_CHANGED=false
SCHEMA_CHANGED=false
HOSTED_ENVIRONMENT_CONTACTED=false
MANUAL_TESTING_APPLICABILITY=deferred
PHASE_3_1F_COMPLETE=false
PHASE_3_1_COMPLETE=false
PHASE_3_2_STARTED=false
```

**Note:** Full founder mapping matrix (Sections E–H) is **not** filled with
speculative rows. All 21 transitional ids are classified
`INSUFFICIENT_AUTHORITATIVE_EVIDENCE` / blocked until catalogue export.

---

## 1. Purpose

Prepare founder decisions to map 21 transitional `cohort.exercise.*` knowledge
ids → canonical `EX-*`. Part 1 is **review and decision preparation only**.
No mappings are published, operationalised, or guessed.

---

## 2. Phase 3.1E close-out (Section A)

| Item | Result |
|------|--------|
| Commit | `b03faa9d656d2a4fc3005d79205796f0abe07f56` |
| ComparabilityFirewall correction | Negative firewall only; removed competing `areDirectlyComparable`; same-exercise comparison does **not** require a graph edge; protocol resolution not reproduced |
| Safety gate | PASS 6/6 |
| Worktree after commit | clean |

---

## 3. Catalogue authority search (Section C)

| # | Source | Classification | Count / note | Sufficient for identity review? |
|---|--------|----------------|--------------|----------------------------------|
| 1 | Checked-in full catalogue dump/export | **Not found** | — | No |
| 2 | `supabase/migrations/20260724140000_founder_exercise_library_wave1.sql` | **Partial seed / expansion** (not full catalogue) | **55** rows `EX-073`…`EX-127` | **No** — incomplete vs production; missing running, SkiErg, wall ball, goblet, sleds, etc. |
| 3 | `supabase/tests/fixtures/local_test_baseline_prereq.sql` | DDL only (`exercises_v2` schema) | 0 rows | No |
| 4 | Session template seeds referencing `EX-073/078/083` | Derived programme usage | Sample ids only | No |
| 5 | Phase 3.1B–E fixtures `EX-900x` | **Fixture-only** | Test ids | **Forbidden** as production targets |
| 6 | Hosted Supabase `exercises_v2` | Documented production authority | Unknown locally | **Not contacted** (excluded) |

**Authoritative production catalogue location (documented):**

- Table: `public.exercises_v2`
- Identity column: `exercise_id` (`EX-*`)
- App access: `ExerciseRepository` / `ExerciseCatalogueService`
- Docs: Phase 3.1A discovery; `Exercise_Curation_Playbook_v1.md`; Architecture Blueprint

**Verdict:** No complete authoritative catalogue is available locally without hosted
read-only retrieval. Per sprint rules, Part 1 **STOPS before Sections E–H**
mapping proposals.

---

## 4. Required read-only export plan (for Lee)

When separately authorised, retrieve **published** rows from staging or a
founder-approved snapshot (not production write):

```sql
SELECT
  exercise_id,
  name,
  slug,
  published,
  category,
  movement_pattern,
  movement_plane,
  exercise_type,
  equipment,
  equipment_category,
  environment,
  technical_complexity,
  primary_muscles,
  secondary_muscle_groups,
  primary_capability,
  unilateral,
  loading_options,
  purpose,
  setup,
  execution,
  coaching_cues,
  regression,
  progression,
  related_protocols,
  notes_internal
FROM public.exercises_v2
WHERE published IS TRUE
ORDER BY exercise_id;
```

Export as a repository-owned review artifact (e.g. under
`docs/architecture/reviews/` or a private path Lee designates) marked
**REVIEW_ONLY — NOT A RUNTIME SEED**. Do not load into the identity bridge.

---

## 5. Transitional inventory (complete — 21)

Source: `knowledge/reference/exercises_reference.yaml` (`ontology_version` 1.3.0).  
`platform_exercise_id`: **0** authored links.

| # | Transitional ID | Label (YAML) | Wave 1 seed has clear same-name row? |
|---|-----------------|--------------|--------------------------------------|
| 1 | `cohort.exercise.back_squat` | Back squat | Yes — `EX-073` Back Squat (name only; not sufficient alone) |
| 2 | `cohort.exercise.front_squat` | Front squat | Yes — `EX-074` |
| 3 | `cohort.exercise.goblet_squat` | Goblet squat | **No** |
| 4 | `cohort.exercise.romanian_deadlift` | Romanian deadlift | Yes — `EX-078` (barbell RDL in seed) |
| 5 | `cohort.exercise.walking_lunge` | Walking lunge | **No** (lateral lunge `EX-098` is different) |
| 6 | `cohort.exercise.pull_up` | Pull-up | **Ambiguous / incomplete** (weighted/chin variants only) |
| 7 | `cohort.exercise.lat_pulldown` | Lat pulldown | **No** |
| 8 | `cohort.exercise.bench_press` | Bench press | Yes — `EX-083` |
| 9 | `cohort.exercise.strict_press` | Strict press | Yes — `EX-088` |
| 10 | `cohort.exercise.push_up` | Push-up | **Ambiguous** (weighted/ring/HSPU only) |
| 11 | `cohort.exercise.running` | Running | **No** |
| 12 | `cohort.exercise.rowing` | Rowing | **No** |
| 13 | `cohort.exercise.ski_erg` | SkiErg | **No** |
| 14 | `cohort.exercise.burpee_broad_jump` | Burpee broad jump | **No** |
| 15 | `cohort.exercise.sled_push` | Sled push | **No** |
| 16 | `cohort.exercise.sled_pull` | Sled pull | **No** |
| 17 | `cohort.exercise.farmer_carry` | Farmer carry | Yes — `EX-101` |
| 18 | `cohort.exercise.wall_ball` | Wall ball | **No** |
| 19 | `cohort.exercise.plank` | Plank | **Ambiguous** (side/Copenhagen only) |
| 20 | `cohort.exercise.dead_bug` | Dead bug | **No** |
| 21 | `cohort.exercise.box_jump` | Box jump | **No** |

Even where Wave 1 has a same-name row, Part 1 **does not** propose a mapping:
name similarity is not identity proof, and the Wave 1 set is not the complete
authoritative catalogue.

---

## 6. Assessment status (all 21)

Every transitional id is assigned:

**`BLOCKED_AUTHORITATIVE_CATALOGUE_UNAVAILABLE`**

No `EXPLICIT_MATCH_READY_FOR_FOUNDER_APPROVAL` rows.  
No draft mapping manifest created (would risk accidental load / guessed targets).

---

## 7. Special decision frameworks (pending catalogue)

Prepared for Part 2 once the full catalogue export exists — **options only**,
no recommendation that implies approval.

### Decision F-01 — `cohort.exercise.running`

| Option | Meaning |
|--------|---------|
| A | Map to outdoor-running canonical id (when present) |
| B | Map to treadmill-running canonical id (when present) |
| C | Split transitional knowledge into outdoor + treadmill definitions |
| D | Leave intentionally unmapped pending new canonical definition(s) |
| E | Introduce context-neutral running knowledge that never owns a performance series alone |

**Do not decide automatically.** Outdoor vs treadmill pace must not be collapsed.

### Decision F-02 — `cohort.exercise.ski_erg`

| Option | Meaning |
|--------|---------|
| A | Map to a single SkiErg canonical exercise; HYROX rules live in comparison protocol |
| B | Distinct canonical ids for generic SkiErg vs HYROX station (unlikely — prefer protocol) |
| C | Leave unmapped until SkiErg exists in catalogue |

Mapping must not merge SkiErg vs banded-ski performance history.

### Decision F-03 — `cohort.exercise.wall_ball`

| Option | Meaning |
|--------|---------|
| A | One canonical wall-ball exercise; HYROX height/mass/division in protocol |
| B | Separate canonical ids for generic vs HYROX-standard wall balls |
| C | Leave unmapped until wall ball exists in catalogue |

### Other likely collisions (after catalogue arrives)

Barbell vs DB RDL; bodyweight vs weighted pull-up/push-up; plank vs side plank;
walking vs lateral lunge; farmer carry variants.

---

## 8. Founder decision required to unblock Part 2

**Smallest decision:** Authorise a **read-only** export of published
`exercises_v2` (fields in §4) into a review-only artifact, **or** confirm that
Wave 1 + an additional checked-in dump Lee provides is the complete authority
(it currently is not).

Without that, Part 2 cannot implement approved mappings.

---

## 9. Non-authorities / protections

- Review artifacts are documentation only.
- No operational bridge load of Part 1 proposals (none created).
- `EX-900x` fixtures remain non-production.
- Relationship adjacency / comparison compatibility ≠ identity.
- Historical evidence not rewritten.

Architecture tripwire: review doc exists; no `DRAFT_NOT_APPROVED` mapping
fixture is imported by `lib/`.

---

## 10. Manual testing

```text
MANUAL_TESTING_APPLICABILITY=not_applicable
MANUAL_TESTS_COMPLETED=false
```

No executable journey changed.

---

## 11. Exact next sprint

**Phase 3.1F Part 2 — Implement founder-approved identity mappings**  
(only after catalogue export + founder decisions on the matrix).

If catalogue retrieval is authorised first as a micro-task:

**Phase 3.1F Part 1b — Import read-only catalogue snapshot and complete Sections E–H.**
