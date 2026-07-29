# Capability Model Guide v1

**Audience:** Curators and engineers extending `knowledge/reference/capabilities.yaml`  
**Ontology version:** 1.1.0

---

## How to add a capability

1. Confirm the concept is a **trainable quality**, not an exercise or muscle (see [Capability_Ontology_v1.md](./Capability_Ontology_v1.md)).  
2. Assign id: `cohort.capability.<canonical_name>`.  
3. Set `parent_ids` to one or more existing nodes (prefer single parent unless taxonomy genuinely multi-parent).  
4. Add optional `prerequisite_ids`, `supporting_capability_ids`, related intents/patterns.  
5. List `typical_assessment_methods` as evidence **types**, not scores.  
6. Set `confidence` and `provenance`.  
7. Run `flutter test test/knowledge/ontology_validation_test.dart`.

---

## Hierarchy rules

- **Root:** `cohort.capability.athletic_performance` (empty `parent_ids`).  
- **Every active capability** must be reachable from the root by following `parent_ids` downward (child → parent walk upward from root).  
- **No cycles** in `parent_ids` or `prerequisite_ids`.  
- **Depth:** prefer 3–5 levels max for reasoning clarity (Performance → domain → specific).  
- **Multi-parent:** use sparingly; document in `description` when used.

---

## Assessment philosophy

- **Capability** = what we want to develop.  
- **Assessment method** = how we might observe progress (1RM, pace/HR, plank hold, coach observation).  
- **Evidence** (future) = a single measurement instance tied to an athlete and date.  

Do not store athlete evidence in ontology YAML.

---

## Evidence vs capability

| Layer | Location | Example |
|-------|----------|---------|
| Capability | `capabilities.yaml` | `absolute_strength` |
| Method | `typical_assessment_methods` | `one_rm` |
| Evidence | future athlete store | “Back squat 140 kg on 2026-07-01” |

---

## Avoiding duplicates

- Search existing `canonical_name` and `aliases` before adding.  
- If renaming, **deprecate** old id with `replaces_id`.  
- Do not create parallel ids for the same quality (e.g. `max_strength` vs `absolute_strength` — use deprecation).  
- Distinguish **grip strength** vs **grip endurance** vs **loaded carry capacity**.

---

## Naming conventions

- Ids: `cohort.capability.snake_case`  
- Labels: human-readable Title Case  
- Aliases: legacy strings only when needed for migration  
- Extension capabilities: set `namespace` / `provenance` when sport-specific (e.g. `burpee_efficiency`)

---

## Exercise mapping rules

On each exercise in `exercises_reference.yaml` (or future curated rows):

```yaml
primary_capabilities:
  - cohort.capability.pulling_strength
secondary_capabilities:
  - cohort.capability.grip_strength
supporting_capabilities:
  - cohort.capability.scapular_control
  - cohort.capability.core_stability
```

- **Primary:** 1–3 capabilities typical for standard prescription.  
- **Secondary:** clear but subordinate emphasis.  
- **Supporting:** enablers (stability, control) — not the main intent.  
- Do not use primary for every minor contribution.

---

## Goal requirements

Add entries to `goal_requirements.yaml`:

```yaml
required_capability_ids:
  - cohort.capability.aerobic_capacity
```

Optional `optional_capability_ids` for nice-to-have qualities. All ids must exist in `capabilities.yaml`.

---

## Good vs bad records

**Good**

```yaml
- id: cohort.capability.threshold
  canonical_name: threshold
  label: Threshold
  parent_ids: [cohort.capability.endurance]
  prerequisite_ids: [cohort.capability.aerobic_capacity]
  typical_assessment_methods: [field_test, coach_assessment]
  status: active
  confidence: curated
```

**Bad**

```yaml
- id: cohort.capability.pull_up
  label: Pull-up
  description: An exercise
```

---

## Mapping legacy free text

Platform `Exercise.primary_capability` and `best_used_for` strings → use [Vocabulary_Reconciliation_v1.md](./Vocabulary_Reconciliation_v1.md). Map to **`cohort.capability.*`**, not to exercises. When uncertain, use `confidence: provisional` and avoid primary exercise mappings until reviewed.
