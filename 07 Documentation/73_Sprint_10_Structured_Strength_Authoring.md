# Sprint 10 — Structured Strength Authoring

## Hierarchy

Programme → Version → Week → Day → Slot → Session → **Blocks** → **Exercise prescriptions**

Blocks remain first-class session containers. For Strength and Accessory blocks, ordered **structured exercise prescriptions** live on `session_block_exercises.prescription` (JSONB).

## Strength prescription model

Each exercise link may carry a `StrengthExercisePrescription`:

| Field | Required | Notes |
|-------|----------|-------|
| Sets | Yes | Single value applied to all working sets (V1) |
| Reps | Yes | Typed rep prescription |
| Load | No | Typed load method + value |
| Rest | No | Seconds |
| Tempo | No | e.g. `31X1` |
| Coach cue | No | Athlete-facing instruction (not private block coach notes) |

### Rep types

- Exact reps (`5`)
- Rep range (`8–10`)
- Duration (`30 seconds`)
- Distance (`20 metres`)
- Max effort / AMRAP
- Free text fallback

### Load types

- Bodyweight
- Fixed kg
- Percentage of 1RM
- RPE
- RIR
- Athlete selected
- Free text fallback

Methods are not silently converted between each other.

## Limitations (V1)

### Set-by-set programming

Not supported. One prescription applies to all working sets (e.g. `5 × 5 @ RPE 8`). Use separate exercise prescriptions for warm-up or ramp sets.

### Grouping / supersets

No superset/tri-set/circuit grouping engine in V1. Exercises are strictly ordered. Optional `group_id` on the prescription model is reserved for future grouping without schema churn.

## Legacy compatibility

Existing Strength blocks with only free-text `content` and reference-only exercise links continue to load unchanged. Coaches may add structured prescriptions without losing legacy prose. Preview and athlete views may show both block instructions and structured exercises.

## Persistence

- Table: `session_block_exercises`
- Column: `prescription JSONB` (migration `20260722170000_add_session_block_exercise_prescriptions.sql`)
- Save path: `SessionBlockRepository.replaceSessionBlocks`
- Legacy bridge: `BlockToLegacyStepProjector` emits one `protocol_steps` row per structured exercise with metadata for capture

## Coach editor

- `SessionBlockEditorCard` dispatches to structured strength UI when block type is **Strength** or **Accessory**
- Generic blocks keep the existing free-text + link editor
- Strength blocks label free text as **Block instructions (optional)**

## Preview and athlete rendering

- `StrengthPrescriptionList` / `StrengthPrescriptionDisplay` render ordered prescriptions
- Optional fields are omitted when empty
- Block-level `coachNotes` are not shown to athletes on structured strength blocks

## Performance capture compatibility

Structured prescriptions project to `protocol_steps.metadata` (`sets`, `reps`, `load`, `rest`, `tempo`) for the legacy strength player and `training_session_sets.protocol_step_id` linkage.

M8 block capture (`training_set_results`) remains compatible via JSON snapshots; full block-native capture wiring is future work.

**Prescribed today:** sets, reps, load method/value, rest, tempo, coach cue  
**Captured today (legacy path):** completed sets/reps/load/RPE per `protocol_step_id`

## Future specialised block editors

Pattern: block-type dispatch in `SessionBlockEditorCard` → specialised editor section → generic fallback.

Candidates: Running intervals, Circuit blocks, Mobility flows.

## Manual acceptance — Upper Body Strength

See sprint completion report for the step-by-step checklist.
