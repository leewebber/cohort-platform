# Capability Gap Analysis v1

Phase 3 Sprint 4 — deterministic semantic reasoning between **goal capability requirements** and **in-memory athlete evidence**. Output is ranked capability priorities and explanations, not workouts.

## Philosophy

- Goals declare **required** and **optional** capabilities (see `knowledge/reference/goal_requirements.yaml`).
- Athletes are represented only as an ephemeral **`AthleteCapabilityEvidenceProfile`** for a single analysis run — no persistence in this sprint.
- A capability is a **gap** when estimated **adequacy** falls below **0.75** for a goal-relevant capability.
- Ranking is **transparent and reproducible**: same inputs always yield the same order (tie-break: ascending `capabilityId`).
- This layer stops before **Coach Brain**, **programme generation**, and **exercise selection**.

## Evidence model

Each `CapabilityEvidenceItem` carries:

| Field | Role |
|--------|------|
| `capabilityId` | Ontology id |
| `state` | `assessed`, `estimated`, `inferred`, `coachObservation`, `unknown` |
| `confidence` | 0–1 confidence in the item |
| `source` | Provenance label (test name, coach note, etc.) |
| `recordedAt` | Optional timestamp |
| `notes` | Optional free text |

**Quality weights** (used in scoring):

| State | Weight |
|--------|--------|
| assessed | 1.0 |
| coachObservation | 0.85 |
| estimated | 0.65 |
| inferred | 0.45 |
| unknown | 0.0 |

**Adequacy** (per capability):

```
adequacy = clamp(qualityWeight(state) * 0.7 + confidence * 0.3, 0, 1)
```

**Decay policy (documentation only):** Evidence is not aged in v1. A future persistence layer may apply half-life or reassessment windows per `source`; document policy on the stored record, not in this prototype.

Reference scenarios: `knowledge/reference/gap_analysis_scenarios.yaml`.

## Gap model

`CapabilityGap` includes:

- `capabilityId`, `capabilityLabel`
- `goalImportance` (1.0 required, 0.55 optional)
- `evidenceState`, `supportingEvidence`
- `severity` (`low` | `moderate` | `high` | `critical`)
- `priorityScore` (ranking key)
- `confidence` (analysis confidence in the gap)
- `rationale` (human-readable)
- `blockerCapabilityIds` (weak prerequisites)
- `prerequisiteCapabilityIds` (from ontology)

## Priority scoring

For each gap:

```
deficiency = 1 - adequacy
evidenceQuality = qualityWeight(state) * clamp(confidence, 0, 1)
base = goalImportance * deficiency * (1 - evidenceQuality * 0.5)
prerequisiteBoost = blockerCount * 0.12 * goalImportance
supportingPenalty = (weakSupporting / totalSupporting) * 0.15   // if any supporting caps in ontology
priorityScore = clamp(base + prerequisiteBoost + supportingPenalty, 0, 2)
```

**Severity:**

- `critical`: weak prerequisites and deficiency > 0.4
- `high`: deficiency > 0.65
- `moderate`: deficiency > 0.35
- else `low`

**Analysis confidence** (gap-level): higher when evidence is assessed/coach-observed; lower when unknown (floor ~0.35).

## Algorithm (deterministic)

1. Load goal required/optional capability ids from knowledge graph.
2. For each requirement, compute adequacy from evidence profile (missing → unknown).
3. Skip capabilities at or above adequacy threshold (0.75).
4. Evaluate ontology **prerequisites**; record blockers whose adequacy is also below threshold.
5. Apply **supporting capability** penalty when linked supporting caps are weak.
6. Build `CapabilityGap` with rationale string.
7. Sort by `priorityScore` descending, then `capabilityId` ascending.

No LLMs or stochastic steps.

## Read-only application seam

Port: `lib/application/ports/capability_gap_analysis_reader.dart`

Implementation: `CapabilityGapAnalysisService` in `lib/knowledge/gap_analysis/capability_gap_analysis_service.dart`

| Method | Purpose |
|--------|---------|
| `analyseGoal(...)` | Full result: gaps + ranked priorities + metadata |
| `identifyCapabilityGaps(...)` | Unranked gap list |
| `rankTrainingPriorities(...)` | Gaps sorted for training focus |

Inject `KnowledgeGraphReader` (capabilities + goals). Do not wire to Coach Brain in v1.

## Representative scenarios

| Scenario id | Goal | Intent |
|-------------|------|--------|
| `cohort.scenario.hyrox_athlete_a` | HYROX Sub-60 | Strong engine; grip/stations unknown → station gaps rise |
| `cohort.scenario.general_fat_loss_a` | General fat loss | Complete evidence → no gaps |
| `cohort.scenario.military_selection_a` | Military selection | Carry/resilience unknown → load and durability priorities |
| `cohort.scenario.hyrox_prerequisite_chain` | HYROX Sub-60 | Weak aerobic → threshold flagged with prerequisite blockers |

## Limitations

- Single evidence item per capability (last-write in profile list; no merge rules).
- Adequacy is a proxy, not a performance prediction.
- Optional goal capabilities use a fixed importance (0.55); no per-goal weight overrides yet.
- No temporal decay applied despite documented future policy.
- Prerequisites only block when **both** parent and prerequisite are under threshold.
- No integration with session logs, wearables, or Supabase athlete tables.

## Future Coach Brain integration (Sprint 5+)

Recommended handoff:

1. **Coach Brain** consumes `rankTrainingPriorities` as structured input (capability ids + scores + rationale).
2. Map gaps to **training intents** and **session templates** via ontology links (not exercise picks in gap layer).
3. Persist evidence through athlete domain with explicit decay/reassessment policy.
4. Close loop: programme execution → new evidence → re-run gap analysis.

## Validation

Tests: `test/knowledge/capability_gap_analysis_test.dart` — complete/partial/unknown evidence, prerequisites, deterministic ranking, scenario-based goal differentiation.
