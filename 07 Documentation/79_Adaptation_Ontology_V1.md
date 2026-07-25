# 79 — Adaptation Ontology V1

**Status:** Canonical foundation (Milestone 2A Task 2)  
**Related:** Adaptation Readiness Audit, `41_Programme_Engine.md`, `20_Protocol_Metadata_Standard.md`, `66_V2_0_End_To_End_Execution_And_Adaptation.md`  
**Code:** `lib/domain/adaptation/`

---

## 1. Locked principles

1. **Preserve intent before format** — substitution must match training purpose, not only session shape.
2. **Smallest valid change** — prefer prescription tweaks before swaps; swaps before block replacement; block replacement before full-session replacement.
3. **Hard constraints eliminate** — infeasible candidates never rank.
4. **Soft preferences rank** — similarity, equipment fit, and duration guide ordering among feasible options.
5. **Prescription adaptation before exercise swap**
6. **Exercise swap before block replacement**
7. **Block replacement before full-session replacement**
8. **All adaptations must be explainable** — athlete- and coach-visible rationale.
9. **Pain flows must not diagnose or claim medical safety** — discomfort constraints adjust load/movement; no clinical claims.
10. **Progression guidance is qualitative** — not exact load prescription unless explicitly authored and captured in performance history.

---

## 2. Training hierarchy

```
Programme
  └── Training day (programme version day + ProgrammeIntent)
        └── Session (performance_protocol / session revision)
              └── Block (session_blocks + SessionBlockType)
                    └── Exercise placement (session_block_exercises)
                          └── Prescription (JSON strength prescription / step metadata)
```

**Adaptation scope increases down the tree; fidelity checks bubble up.**

---

## 3. Session intent taxonomy (V1)

Canonical enum: **`SessionIntent`** (`lib/domain/adaptation/vocabulary/session_intent.dart`).

| Family | Values |
|--------|--------|
| **Strength** | upper/lower/full-body strength; push/pull/squat/hinge strength; unilateral lower-body strength; strength endurance |
| **Hypertrophy** | upper/lower/full-body; push/pull; shoulder/arm/chest/back/leg/glute hypertrophy |
| **Running** | aerobic base; recovery running; steady aerobic endurance; tempo; threshold; VO₂ max; running economy; race pace; long run; hills; sprint development; technique and drills |
| **Conditioning** | aerobic/anaerobic/mixed-modal conditioning; muscular endurance; work capacity; high-intensity intervals; HYROX-specific; compromised running; station-specific |
| **Recovery / movement** | active recovery; mobility; flexibility; movement quality; prehabilitation; breathing and recovery; skill development |

**Distinct from `ProgrammeIntent`** (build/maintain/deload/test/recover/technique) which describes macro calendar intent, not session stimulus.

---

## 4. Canonical vocabulary (Dart)

| Concept | Type | Notes |
|---------|------|--------|
| Session intent | `SessionIntent` | New |
| Session modality | `SessionModality` | New; maps from legacy `session_type` |
| Physiological emphasis | `PhysiologicalEmphasis` | New; successor to loose demand labels |
| Session difficulty | `SessionDifficulty` | New |
| Technical complexity | `CanonicalTechnicalComplexity` | New; maps legacy Beginner/Intermediate/Advanced |
| Impact | `ImpactLevel` | New |
| Training environment | `TrainingEnvironment` | Extends questionnaire + protocol environments |
| Block type | **`SessionBlockType`** | **Reused** — mapping policy in `SessionBlockTypeAdaptationPolicy` |
| Block priority | `BlockPriority` | New |
| Exercise placement role | `ExercisePlacementRole` | New |
| Exercise category | `ExerciseCategory` | New (structured) |
| Movement pattern | `MovementPattern` | New (structured) |
| Training effect | `ExerciseTrainingEffect` | New |
| Loading potential | `ExerciseLoadingPotential` | New (qualitative) |
| Movement characteristic | `MovementCharacteristic` | New |
| Constraint scope | `AdaptationConstraintScope` | New |
| Constraint severity | `AdaptationConstraintSeverity` | New |
| Action type | `AdaptationActionType` | New (ordered ladder) |
| Fidelity | `AdaptationFidelity` | New |
| Audit event type | `AdaptationAuditEventType` | New; mirrors persisted audit CHECK constraint |

---

## 5. Core contracts

| Contract | Purpose |
|----------|---------|
| `AdaptationConstraint` | Hard/soft limit with scope, severity, structured values |
| `AdaptationConstraintKind` | Domain superset of athlete reasons |
| `BlockAdaptationPolicy` | Allowed operations + minimum viable prescription |
| `MinimumViablePrescription` | Qualitative floor for block/session |
| `AdaptationAction` | Explainable step with target entity |
| `AdaptationFidelityAssessment` | Intent retention assessment |
| `AdaptationValidationResult` | Plan validation against constraints |
| `SessionAdaptationMetadata` / `BlockAdaptationMetadata` / `ExercisePlacementAdaptationMetadata` / `ExerciseAdaptationMetadata` | Minimum metadata shapes per level |

---

## 6. Adaptation reason mapping policy

Three layers — **do not conflate**:

| Layer | Enum(s) | Role |
|-------|---------|------|
| **Athlete input** | `AdaptationReason`, `AdaptationRequest`, `RecoveryState`, `AdaptationSessionEnvironment` | Questionnaire → domain constraints |
| **Domain** | `AdaptationConstraint`, `AdaptationConstraintKind` | Hard/soft gating + explainability |
| **Legacy scoring** | `AdaptationScoringReason` | Rank protocols in global pool (transitional) |
| **Audit output** | `ProgrammeAdaptationType` / `AdaptationAuditEventType` | Post-completion persisted events only |

**Mapping implementation:** `AdaptationReasonMapping` in `lib/domain/adaptation/mapping/adaptation_reason_mapping.dart`.

| Athlete `AdaptationReason` | Domain kind | Primary `AdaptationScoringReason` | Notes |
|----------------------------|-------------|-------------------------------------|--------|
| recovery | recovery | poorRecovery | Severity from `RecoveryState` |
| environment | environment | travelling | Hotel/home mapped via `TrainingEnvironment`; not identical semantics |
| equipment | equipment | limitedEquipment | Equipment tokens from questionnaire |
| time | time | shortOnTime | Available minutes |

**Environment ≠ travelling** logically, but legacy scorer uses travelling heuristics for environment constraints until intent-scoped pools exist.

**ProgrammeAdaptationType** (`load_progression`, `protocol_substitution`) must never appear as athlete-facing reasons.

---

## 7. Transitional terminology map

| Existing term | Canonical term | Migration strategy | Temporary support |
|---------------|----------------|--------------------|-------------------|
| `ProgrammeIntent` | `ProgrammeIntent` (unchanged) | Keep for phase/week/day | ✔ |
| `programme_versions.primary_goal` | Programme goal text + future enum | Manual founder authoring | ✔ free text |
| `primary_capability` / `Protocol.goal` | `SessionIntent` + optional `SessionModality` | Backfill founder sessions | ✔ legacy columns |
| `secondary_capability` | `SessionIntent?` secondary | Same | ✔ |
| `purpose` (protocol/exercise) | `SessionAdaptationMetadata` + coach copy | Authoring | ✔ |
| `best_used_for` | `ExerciseTrainingEffect` list | Curate per exercise | ✔ text |
| `DominantStimulus` | Derived fingerprint; align to `SessionIntent` family | Analyzer mapping table (future) | ✔ fingerprint |
| `AdaptationReason` | → `AdaptationConstraintKind` (subset) | `AdaptationReasonMapping` | ✔ |
| `AdaptationScoringReason` | Scoring input only | Keep until ranker uses domain | ✔ |
| `ProgrammeAdaptationType` | `AdaptationAuditEventType` | 1:1 db values | ✔ |
| `SessionBlockType` | Same + `BlockPriority` / `BlockAdaptationPolicy` | Defaults via `SessionBlockTypeAdaptationPolicy` | ✔ |
| `technical_complexity` strings | `CanonicalTechnicalComplexity` | Parse legacy labels | ✔ |
| `AdaptationSessionEnvironment` | `TrainingEnvironment` | `mapAdaptationSessionEnvironmentToTrainingEnvironment` | ✔ |
| Exercise `movement_pattern` text | `MovementPattern` | Slug map in migration | ✔ text |
| `regression` / `progression` text | `ExerciseSubstitutionRelationship` | Manual graph authoring | ✔ text |

---

## 8. Minimum metadata contracts (summary)

### Session

Primary intent (required), secondary intent, modality, physiological emphasis, expected duration, minimum viable duration, environment(s), required equipment, difficulty, complexity, impact.

### Block

Type (`SessionBlockType`), intent, priority, adaptation policy, minimum viable prescription, dependencies.

### Exercise placement

Exercise ID, role, prescription reference, replaceable, removable, priority.

### Exercise library

Movement pattern(s), training effects, loading potential, equipment, environment, complexity, impact, movement characteristics, substitution relationships.

---

## 9. Recommended database migration plan (not executed in Task 2)

### Required for first deterministic family-beta adaptation

- `performance_protocols.primary_session_intent` (TEXT → `SessionIntent.dbValue`)
- `performance_protocols.secondary_session_intent` (nullable)
- `performance_protocols.minimum_viable_duration_min` (INT)
- `session_blocks.adaptation_policy` (JSONB → `BlockAdaptationPolicy`)
- `session_blocks.block_priority` (TEXT)
- `session_block_exercises.placement_role`, `replaceable`, `removable` (TEXT/BOOL)

### Useful but derivable

- `session_modality`, `physiological_emphasis`, `impact_level` on protocols (can infer from intent + blocks initially)
- `session_blocks.block_intent` (can inherit session primary)

### Deferred

- Exercise substitution graph tables
- Persisted `SessionFingerprint` snapshots
- Slot-level intent on `programme_version_session_slots`

### Manually curated (founder)

- `SessionIntent` per founder session
- `BlockAdaptationPolicy` overrides on key strength/conditioning blocks
- Exercise substitution relationships

**Suggested sequence:** protocol session intents → block policies → placement flags → exercise graph → slot intents → programme goal enum.

---

## 10. Risks and unresolved terminology

- **`primary_capability` vs `SessionIntent`** — legacy Capability vocabulary (Capacity, Engine, …) does not 1:1 map to session intents; requires founder mapping table per protocol.
- **Environment vs travelling** — scorer conflation is transitional.
- **Pain / discomfort** — `AdaptationConstraintKind.painOrDiscomfort` reserved; no athlete UI in v1.
- **Load progression** — remains qualitative in domain; post-completion +2.5 kg rule stays separate until prescription model unifies.

---

## 11. Next implementation task

**Milestone 2A Task 3 (recommended):** Persist session `SessionIntent` + block `BlockAdaptationPolicy` on founder programme sessions (migrations + authoring UI behind coach guard only), still **without** wiring global pre-session recommendations.

---

## 12. Fingerprint and similarity (transitional)

`SessionFingerprint` / `DominantStimulus` remain **derived analytics**. Future ranker should require:

`constraint pass` → `intent compatibility` → `ProtocolSimilarityService` soft score → explainable `AdaptationAction` list.

Do not use similarity alone as intent preservation.
