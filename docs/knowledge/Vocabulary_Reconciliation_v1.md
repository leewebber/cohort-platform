# Vocabulary reconciliation — Knowledge Blueprint vs platform (v1)

**Status:** Phase 3 Sprint 2  
**Purpose:** Align [Knowledge_Blueprint_v1.md](./Knowledge_Blueprint_v1.md) with existing code before machine-readable ontology IDs are curated at scale.

| Blueprint concept | Existing implementation | Canonical knowledge term (`knowledge/` id prefix) | Action | Migration implications |
|-------------------|-------------------------|---------------------------------------------------|--------|-------------------------|
| Exercise | `lib/models/exercise.dart`, `exercises_v2` | `cohort.exercise.*` | **Reuse** identity; knowledge metadata is additive | Map free-text fields → ontology refs via playbook; do not duplicate DB ids in ontology |
| Movement Pattern | `MovementPattern` enum | `cohort.movement_pattern.*` | **Reuse** — ids match `MovementPattern.dbValue` | Slug map for legacy `exercise.movement_pattern` strings |
| Session Intent / Training Intent (session) | `SessionIntent` enum | `cohort.training_intent.*` | **Reuse** — ids match `SessionIntent.dbValue` | Distinct from Programme Goal |
| Programme Goal | `ProgrammeIntent` enum | `cohort.programme_goal.*` | **Reuse** — defer full knowledge file to Phase 3+ | Not same as Session Intent |
| Training Environment | `TrainingEnvironment` enum | `cohort.environment.*` | **Reuse** — ids match `TrainingEnvironment.dbValue` | Map `AdaptationSessionEnvironment` at application layer |
| Equipment | Free-text on Exercise | `cohort.equipment.*` | **Supersede** strings with curated tokens | Alias table for legacy equipment strings |
| Muscle Group | Free-text `primary_muscles` | `cohort.muscle_group.*` | **Supersede** with structured refs | Curate per exercise |
| Joint Action | Not in domain enum | `cohort.joint_action.*` | **Defer** to knowledge layer only (Sprint 2 ref set) | Optional on exercises |
| Capability | Legacy `primary_capability` text | `cohort.capability.*` | **Rename/map** — not 1:1 with Session Intent | Founder mapping table per protocol (`79` §10) |
| Energy System | Implied via `PhysiologicalEmphasis` / intents | `cohort.energy_system.*` | **Defer** explicit refs on exercises | Can derive from intent until curated |
| Training effect | `ExerciseTrainingEffect` enum | Aligns with capability/effect edges | **Reuse** enum values as capability ids where overlap | Use `develops_capability` relationship |
| Technical demand | `CanonicalTechnicalComplexity` | `cohort.technical_demand.*` | **Reuse** enum names | Map legacy exercise strings |
| Recovery / fatigue cost | Not persisted on Exercise | Qualitative bands on knowledge exercise | **New** in ontology only | Feeds future planners; not M8 |
| Constraint | `AdaptationConstraint`, kinds | `cohort.constraint_kind.*` (future) | **Defer** full constraint catalog | Sprint 2: substitution `applicable_constraints` as strings/tags |
| Adaptation Rule | Domain pipeline + coordinator | `cohort.substitution.*` records | **Partial** — substitution schema only in Sprint 2 | Not full rule engine |
| Substitution relationship | Text regression/progression on Exercise | `substitutions_reference.yaml` | **Supersede** text with structured rules | Coach graph + knowledge graph parallel until merge |
| Athlete Capability | Projections (no enum) | `cohort.athlete_capability.*` | **Defer** — runtime profile, not reference ontology | Phase 3+ |
| Block Type | `SessionBlockType` | Authoring model | **Out of scope** Sprint 2 reference | Stays in session builder |
| Prescription Shape | Strength prescription JSON | Authoring model | **Out of scope** | Stays in blocks |
| Protocol | `Protocol` / performance_protocols | Curated content + intents | **Reuse** content; link intents via metadata | Not duplicated in reference dataset |
| knowledge_relationships (DB) | `KnowledgeRepository` contains edges | `contains` for protocol→exercise | **Reuse** persistence; ontology adds semantic edges | Two graphs until unified port |

**Rules applied**

- No second `MovementPattern` or `SessionIntent` taxonomy in YAML — reference files use the same stable string ids as domain `dbValue`.  
- `ExerciseTrainingEffect` values map to `cohort.capability.*` where semantics match; otherwise capability entities are separate.  
- Legacy `Capability` vocabulary (Capacity, Engine, …) → **defer** explicit enum; map in application when backfilling protocols.
