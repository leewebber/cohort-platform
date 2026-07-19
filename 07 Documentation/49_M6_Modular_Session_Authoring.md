# M6 — Modular Session Authoring

## Product principle

Blocks are semantically typed but editorially flexible. Cohort provides structure without restricting creativity.

- **Workout text** is the primary coaching instruction and is **not parsed** into structured prescriptions.
- **Linked exercises** are athlete reference metadata only — not sets, reps, or load.
- **Workout format** describes execution style (AMRAP, EMOM, etc.) separately from block purpose.
- **Timer configuration** supports athlete execution tools and is stored separately from workout content.

## Content hierarchy

```
Programme
└── Session
    └── Session Blocks (ordered)
        ├── Warm-up
        ├── Strength
        ├── Skill
        ├── Accessory
        ├── Conditioning
        ├── Core
        ├── Cool-down
        └── Custom
```

## Domain models

| Model | Purpose |
| --- | --- |
| `SessionBlock` | Ordered modular unit with title, content, format, timer, links |
| `SessionBlockType` | Semantic block purpose |
| `WorkoutFormat` | Execution style badge and timer driver |
| `TimerConfiguration` | Typed timer JSON (format-aware validation) |
| `SessionBlockExerciseLink` | Canonical exercise reference + optional label override |

## Persistence

### Tables

- `session_blocks` — block content, format, timer JSON, coach notes, position
- `session_block_exercises` — ordered exercise links per block

Legacy `protocol_steps` remain intact for compatibility.

### Source of truth

During M6 transition:

1. **Authoring** uses `ProtocolDraft.blocks` exclusively in the Session Builder UI.
2. **Load** prefers persisted blocks; falls back to in-memory legacy conversion from steps.
3. **Save** persists blocks and projects blocks → legacy steps for execution routing.
4. **Never** mutate blocks and steps independently in the builder.

Supporting services:

- `SessionBlockRepository`
- `ProtocolDraftBlockResolver`
- `LegacyStepToBlockConverter`
- `BlockToLegacyStepProjector`

## Migration strategy

Migration `20260719140000_add_session_blocks.sql`:

1. Adds block tables (additive).
2. Backfills one default `custom` block titled **Session** per protocol with legacy steps.
3. Backfills exercise links from step `exercise_id` values.
4. Leaves original `protocol_steps` unchanged.

Conversion is idempotent — sessions with blocks are not duplicated.

Saving through the new builder persists blocks even when content was initially loaded via legacy fallback.

## Clone behaviour

`SessionCloneService` deep-clones:

- Blocks, timer settings, linked exercises, label overrides, coach notes, ordering
- Generates new local IDs; clears persisted block/link IDs
- Preserves lineage at Session level (`source_content_id`, etc.)
- Does not link copied blocks back to source block IDs

## Execution projection

`SessionExecutionPlan` / `SessionExecutionPlanBuilder` render athlete-facing block summaries for preview.

Legacy execution engines continue to receive projected `protocol_steps` until a dedicated block execution milestone.

## Compatibility path

| Workflow | M6 behaviour |
| --- | --- |
| Load legacy Session | Convert steps → blocks in memory (or read backfilled blocks) |
| Preview | Block list + existing execution preview |
| Save | Blocks + projected steps |
| Copy & Customise | Block deep clone |
| Programme attach | Unchanged |
| Cohort Protocol immutability | Unchanged |

## Known limitations

- Workout content uses plain multiline text (rich text deferred).
- Block drag-and-drop not implemented; move up/down controls used instead.
- Session Library live-reference warning from M4 still applies — no versioning in M6.
- Full athlete block execution UI deferred; projected steps power existing player routes.
- Supabase Flutter client still lacks multi-table transactions on save.

## Future removal

Legacy `protocol_steps` authoring UI is replaced by blocks. Step rows remain until a later milestone confirms all content is block-native and execution no longer requires projection.
