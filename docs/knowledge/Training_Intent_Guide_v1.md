# Training Intent Guide v1

Practical guide for curators and engineers working on the Phase 3 training intent engine.

## Intent philosophy

A **training intent** describes the *training stimulus category* that closes a capability gap — not sets, reps, or exercise names.

Good intents:

- Aerobic base development
- Tempo development
- Grip endurance
- Loaded carry development

Poor intents (wrong layer):

- “3×10 goblet squat”
- “Week 3 day 2”
- “Replace pull-up with banded pull-up”

## Capability mapping

1. Start from an active **capability** node in `capabilities.yaml`.
2. Add one or more rows in `capability_intent_mappings.yaml` with explicit **rationale**.
3. Set **suitability** relative to other mappings for the same capability (not absolute truth).
4. Use **progression_stage** to order options:
   - `foundation` — prerequisites and base work
   - `development` — primary adaptive stimulus
   - `emphasis` — concentrated blocks
   - `peaking` / `taper` / `recovery` — phase-specific (use sparingly in reference data)

### Example (threshold)

| Intent | Stage | Suitability | When |
|--------|-------|-------------|------|
| Aerobic base | foundation | (on aerobic cap) | Weak aerobic evidence |
| Tempo development | development | 0.88 | First threshold-adjacent work |
| Cruise intervals | emphasis | 0.82 | After tempo exposure |
| Threshold progression | emphasis | 0.90 | Mesocycle progression |

Always declare **prerequisite_intent_ids** when an intent assumes prior work (see threshold → aerobic base).

## Progression

- **Within capability:** filter with `progressionOptions(capabilityId, progressionStage: 'foundation')`.
- **Across gaps:** `TrainingIntentFromGapsService` multiplies gap `priorityScore × mapping.suitability` and takes top mappings per gap.
- Do not encode periodisation calendars in YAML — only *characteristics* (`typical_progression_characteristics`).

## Fatigue and recovery

Each intent and archetype carries opaque but comparable strings:

- `fatigue_characteristics` — e.g. `local:high;systemic:moderate`
- `recovery_characteristics` — e.g. `48-72h_local`

Future sprints may parse these for weekly load caps; v1 is documentation + consistency.

## Session archetypes

Archetypes bridge intents to future session plans:

- One archetype may list **multiple** primary training intents (e.g. Mixed engine).
- Every active archetype must be referenced from at least one intent’s `common_session_archetype_ids` or have non-empty `primary_training_intent_ids`.

Keep archetypes **equipment-agnostic** where possible (“Heavy lower”, not “Barbell back squat day”).

## Common mistakes

1. **Orphan intents** — every active intent must appear in mappings, exercises, capabilities, archetypes, or substitutions graph (validator enforces).
2. **Exercise as intent** — use `supports_training_intents` on exercises, not new intent labels per movement.
3. **Circular prerequisite intents** — mapping prerequisite chains must be acyclic.
4. **Confusing session intent enum with taxonomy** — platform `SessionIntent` is narrower; add YAML intents first, reconcile enum second.
5. **Suitability without spread** — if all mappings are 0.95, ranking becomes noise; differentiate.

## Extension strategy

1. Add intent entity to `training_intents.yaml` with full metadata.
2. Add mappings + update capability `related_training_intent_ids` if broadly applicable.
3. Link archetypes on both sides (intent common archetypes + archetype primary intents).
4. Run `flutter test test/knowledge/`.
5. Bump manifest patch version when changing required fields.

## Validation

`KnowledgeOntologyValidator` checks:

- Unique ids
- Valid capability and intent references
- Orphan active intents/archetypes
- Mapping suitability range
- Intent prerequisite cycles (via mappings)

Tests: `test/knowledge/training_intent_engine_test.dart`

## Limitations (v1)

- No athlete fatigue history or weekly budget
- No automatic prerequisite gating in `TrainingIntentFromGapsService` (gap blockers only in gap layer)
- Session intent enum not fully synced to taxonomy
- No programme or exercise generation

## Related docs

- [Training_Intent_Ontology_v1.md](./Training_Intent_Ontology_v1.md)
- [Capability_Gap_Analysis_v1.md](./Capability_Gap_Analysis_v1.md)
- [Capability_Ontology_v1.md](./Capability_Ontology_v1.md)
