# Exercise curation playbook v1

**Status:** Phase 3 Sprint 2  
**Audience:** Coaches, founders, engineers curating `knowledge/reference/`  
**Scope:** Representative reference dataset and future library migration — **not** automated bulk import

---

## 1. Principles

1. **Curated beats generated** — do not add exercises to the ontology without human review; set `curation_status: reference_only | curated | provisional`.  
2. **Stable ids** — never rename an id; deprecate and add `replaces_id`.  
3. **Same vocabulary as domain** — movement patterns and training intents use ids aligned with `MovementPattern.dbValue` and `SessionIntent.dbValue` (see [Vocabulary_Reconciliation_v1.md](./Vocabulary_Reconciliation_v1.md)).  
4. **Coaching copy stays on platform Exercise** — ontology holds semantics; Supabase `exercises_v2` holds setup/cues until explicitly linked via `platform_exercise_id`.  
5. **Substitutions are contextual** — never “A equals B”; always document constraints, preserved intent, and compromised qualities.

---

## 2. Adding an entity

1. Pick entity kind (equipment, muscle group, exercise, substitution, …).  
2. Choose id: `cohort.<kind>.<canonical_name>` (snake_case, no spaces).  
3. Set `ontology_version` to match [knowledge/manifest.yaml](../../knowledge/manifest.yaml).  
4. Set `status: draft` until reviewed, then `active`.  
5. Run `flutter test test/knowledge/ontology_validation_test.dart`.  
6. Document provenance (`founder_review`, `phase3_sprint2_reference`, etc.).

---

## 3. Stable ids

| Good | Bad |
|------|-----|
| `cohort.exercise.back_squat` | `cohort.exercise.backSquat` |
| `cohort.equipment.squat_rack` | `cohort.equipment.rack1` |
| ids unchanged forever | reusing id for a different movement |

**Platform link:** optional `platform_exercise_id` when a row in `exercises_v2` is verified to match semantics (not just name similarity).

---

## 4. Aliases

- List legacy or common names in `aliases` on **exercise** records only (loader indexes aliases for exercises).  
- Aliases are **namespace-scoped** (`core:` prefix internally); avoid generic aliases like `core` that collide across entity types.  
- Prefer `barbell_back_squat` over ambiguous `squat` unless context is explicit.

---

## 5. Uncertain knowledge

Use field values explicitly:

| Situation | Field approach |
|-----------|----------------|
| Unknown | omit field or use `confidence: unknown` |
| Not applicable | `technical_demand: not_applicable` (or band enums with `not_applicable`) |
| Provisional | `confidence: provisional`, `curation_status: provisional` |
| Inferred from analyzer | `confidence: inferred`, cite `evidence` string |

Do not invent precise loads, reps, or medical contraindications.

---

## 6. Provenance and confidence

| Field | Use |
|-------|-----|
| `provenance` | Who/when/how (e.g. `founder_sarah_2026_07`, `domain.MovementPattern`) |
| `confidence` | `curated` \| `inferred` \| `provisional` \| `unknown` |
| `evidence` | Optional free-text citation (doc, video review, consensus) |

---

## 7. Modelling costs

Use ordinal bands only in reference data:

- `local_fatigue`, `systemic_fatigue`, `recovery_cost`: `low` \| `moderate` \| `high` \| `very_high` \| `unknown` \| `none` \| `not_applicable`

Costs are **relative within Cohort programming**, not absolute physiology.

---

## 8. Contextual substitutions

Use [substitution_rule.schema.yaml](../../knowledge/schemas/substitution_rule.schema.yaml).

**Required:** `source_exercise_id`, `candidate_exercise_id`, `explanation`, preserved/compromised semantics, `applicable_constraints` tags.

**Good example:** [substitutions_reference.yaml](../../knowledge/reference/substitutions_reference.yaml) — `back_squat_to_goblet_squat`.

**Bad example:**

```yaml
# BAD — equality, no context
source_exercise_id: cohort.exercise.back_squat
candidate_exercise_id: cohort.exercise.front_squat
explanation: "Same exercise."
```

Constraint tags are **convention strings** (e.g. `no_barbell`, `hotel_gym`) until a constraint catalog exists in a later sprint.

---

## 9. Review requirements

Before setting `status: active` and `curation_status: curated`:

- [ ] Validator tests pass  
- [ ] All refs resolve to existing ids  
- [ ] No equipment listed as both required and optional  
- [ ] Substitution has non-empty explanation and at least one preserved dimension  
- [ ] Peer review by second curator or engineer  

---

## 10. Deprecation

1. Set `status: deprecated` on old entity.  
2. Set `replaces_id` to the new canonical id (validator enforces).  
3. Keep old id in files until consumers migrate.  
4. Update substitutions to point at new ids.

---

## 11. Mapping legacy free-text exercise names

1. Normalize: lowercase, trim, replace spaces with underscores.  
2. Resolve via alias index (`KnowledgeEntityResolver.resolveExerciseId`).  
3. If no match, **do not guess** — create provisional exercise or leave platform text unmapped.  
4. Record mapping in spreadsheet or future `legacy_alias_map.yaml` (Sprint 3+).

Common legacy fields on `Exercise`: `movement_pattern`, `equipment`, `primary_capability` — map to ontology refs incrementally per [Vocabulary_Reconciliation_v1.md](./Vocabulary_Reconciliation_v1.md).

---

## 12. Examples

### Good exercise record (abbreviated)

```yaml
id: cohort.exercise.back_squat
canonical_name: back_squat
label: Back squat
aliases: [barbell_back_squat]
curation_status: reference_only
confidence: curated
movement_patterns:
  - { id: cohort.movement_pattern.squat, role: primary }
required_equipment: [cohort.equipment.barbell, cohort.equipment.squat_rack]
supports_training_intents:
  - cohort.training_intent.squat_strength
recovery_cost: moderate
```

### Bad exercise record

```yaml
# BAD — invented coaching, duplicate taxonomy, missing version
id: squat
name: Back Squat
coach_cue: "Sit back and down..."
movement_pattern: legs
```

---

## 13. Validation command

```bash
flutter test test/knowledge/ontology_validation_test.dart
```

Fix all reported orphan refs and duplicate aliases before merging curation PRs.
