# Prescription Engine implementation v1

Phase 4 Sprint 4 — transforms `SemanticSessionExecutionPlan` + `SessionBlueprint` into fully prescribed sessions. Does **not** select exercises or alter planning semantics.

## Responsibilities

`DeterministicPrescriptionEngine`:

- Reads archetype **template bands** (sets, reps, duration, distance, RPE, rest, intervals)
- Applies **semantic modifiers** from blueprint intensity, volume, density, progression emphasis, fatigue tags
- Emits `ExercisePrescription` per policy-selected movement
- Builds `PrescriptionResult` with explainability
- Adapter maps to M7 `SessionExecutionPlan` via `PrescriptionExecutionPlanAdapter`

Port: `PrescriptionEngine.prescribe(PrescriptionRequest)`.

## Input contract

`PrescriptionRequest`:

- `SemanticSessionExecutionPlan executionPlan` — ordered selections from Exercise Policy
- `SessionBlueprint blueprint` — semantic bands, progression context, constraints

## Prescription algorithm

1. Validate plan/blueprint alignment  
2. Load `PrescriptionTemplateLibrary.forArchetype(archetypeId)`  
3. Compute volume/intensity scale factors from semantic targets + week emphasis + `fatigueReduced`  
4. For each `ExerciseSelection`:
   - Pick role band (preparation / primary / secondary / recovery)
   - Scale band (`PrescriptionProgressionBand.scaled`)
   - Adjust rest for density; cap for poor recovery constraints
   - Resolve modality (strength / endurance / carry / intervals / mobility / assessment) via template + movement patterns
   - Materialise sets, reps text, duration/distance, RPE band, intervals, rest
5. Aggregate duration estimate + narrative explainability  

No athlete history, no adaptive loading, no AI.

## Template system

`lib/planning/prescription/prescription_templates.dart` — parameterised bands for all nine session archetypes:

| Archetype | Modality | Primary band (example) |
|-----------|----------|-------------------------|
| Heavy lower/upper | strength | 3–5 × 4–8 @ RPE 7–9 |
| Tempo run | endurance | 20–35 min @ RPE 7–8 |
| Long easy run | endurance | 45–75 min @ RPE 5–6 |
| Carry session | carry | 4–6 × 20–40 m @ RPE 7–8 |
| Recovery / mobility | mobility | 15–25 min low effort |
| Technique | assessment | 3–5 × 3–6 quality reps |
| Mixed engine | intervals | 6–8 rounds, 1:1 work:rest |

Templates are code-local (migrate to ontology later).

## Progression policy

Semantic scaling only:

- **Volume level** → `volumeFactor` 0.7–1.2  
- **Intensity level** → `intensityFactor` 0.85–1.15  
- **Deload / recovery week** → additional −25% volume, −15% intensity  
- **Intensification** → +5% intensity, −5% volume  
- **Dense/continuous density** → −15% rest  
- **fatigueReduced tag** → −15% volume, −10% intensity  

Strength uses set/rep/RPE bands; running uses duration bands; carries use distance bands; mixed engine uses interval rounds + work:rest ratio text.

## Explainability

Per-exercise factors: `progression_band`, `movement_role`, template-specific (`strength_structure`, `endurance_duration`, `carry_distance`, `interval_structure`). Run-level `semantic_modifiers` + narrative summary.

## Validation

`PrescriptionValidator` — non-empty selections, blueprint id match, intent/archetype preservation, all selections prescribed when status is `complete`, component coverage.

## M7 adapter

`PrescriptionExecutionPlanAdapter.toExecutionPlan` builds `SessionExecutionBlock` list with `SessionExecutionExerciseSummary` + `StrengthExercisePrescription` (duration/distance/rep-range/RPE-as-text). Does not change Workout Player architecture.

## Future adaptive loading

Sprint 4 uses static bands only. Future sprints may replace scale factors with athlete history, e1RM, and pace anchors while keeping template shape.

## Known limitations

- RPE ranges stored as min/max text on load prescription (no auto-regulation loop)  
- Running prescriptions require policy to have selected locomotion exercises  
- Interval timings are descriptive strings, not timer configs  
- No persistence or calendar scheduling  

## Pipeline position

```
PlanningRecommendation → SessionBlueprint → SemanticSessionExecutionPlan → PrescriptionResult → SessionExecutionPlan (adapter)
```

Coach Brain not wired in this sprint.
