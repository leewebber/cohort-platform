# Programme Semantics Guide v1

Curator and engineer guide for long-horizon programme semantics (no scheduling).

## Philosophy

Programme semantics describe **what should be emphasised when**, not **which day** or **which exercise**. The engine supports reasoning about:

- Phase-appropriate **capabilities** and **training intents**
- **Blocks** that encapsulate mesocycle intent
- **Week types** that modulate fatigue within a phase
- **Progression paths** that encode acceptable phase order

Athlete-specific calendars, session counts, and exercise prescriptions belong in later layers (Coach Brain, session generation).

## Adaptation over time

1. **Goal** sets required capabilities (existing goal requirements).
2. **Gap analysis** ranks current deficits (Sprint 4).
3. **Training intents** suggest stimulus types (Sprint 5).
4. **Programme phase** sets macro emphasis and fatigue class.
5. **Training block** narrows mesocycle focus (e.g. threshold block during specific preparation).
6. **Week type** adjusts weekly accumulation vs intensification.

Do not duplicate capability lists across layers without reason: phases are broad priorities; blocks are operational mesocycles; week types are weekly modulation.

## Progression

- Edit **allowable_next_phase_ids** on phases for valid transitions.
- Edit **programme_progression.yaml** for canonical paths and duration **ranges** (not fixed calendars).
- Validator ensures:
  - Phase graph is **acyclic**
  - Sequential path steps respect **allowable next**
  - No **orphan** active phases (every phase appears in a path step or alternate)

Optional branches (deload, transition) appear as `optional_alternate_phase_ids` on steps — not as mandatory sequence unless promoted to a primary step.

## Periodisation assumptions

- Durations are **ranges**, not prescriptions.
- Fatigue/recovery fields are comparable strings until a load parser exists.
- Multiple sports/goals share phases; goal-specific emphasis comes from capability priorities + block choice, not duplicate phase taxonomies.
- **No scheduling engine** — never add calendar dates to YAML in this layer.

## Adding new sports / goals

1. Confirm goal capabilities exist in `goal_requirements.yaml`.
2. Add or reuse **training blocks** that cover those capabilities.
3. Map blocks to **suitable programme phases**.
4. If the macro arc differs (e.g. no taper), add a new **progression path** rather than overloading defaults.
5. Add **week types** only if existing types cannot express weekly emphasis.

## Common mistakes

1. Putting **exercises** or **session templates** in programme YAML.
2. **Orphan phases** not referenced in any progression path.
3. **Invalid transitions** in paths (step B not in allowable next of step A).
4. Blocks with **empty** `suitable_programme_phase_ids`.
5. Confusing **training intent** priorities with **session intent** enum values without reconciliation.

## Extension strategy

1. Add phase/block/week entities with full metadata.
2. Wire into progression path or alternates.
3. Run `flutter test test/knowledge/`.
4. Bump manifest patch version when schema fields change.

## Validation

`KnowledgeOntologyValidator` + `test/knowledge/programme_semantics_test.dart`.

## Limitations

- No athlete persistence or training history
- No automatic block selection from gaps (manual composition or future service)
- No Coach Brain or session generation
- Duration ranges are not enforced at runtime

## Related

- [Programme_Semantics_v1.md](./Programme_Semantics_v1.md)
- [Training_Intent_Ontology_v1.md](./Training_Intent_Ontology_v1.md)
- [Capability_Gap_Analysis_v1.md](./Capability_Gap_Analysis_v1.md)
