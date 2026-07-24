# Founder Exercise Library V1 — Wave 1

Canonical expansion of `exercises_v2` to support Cohort programme authoring, execution, and the Founder Programme Importer.

## Architecture

| Layer | Role |
|-------|------|
| **`exercises_v2`** | Canonical movement identity (`exercise_id`, `name`, `slug`, `published`) |
| **`ExerciseRepository` / `ExerciseCatalogueService`** | Published catalogue for library, picker, importer resolution |
| **`session_block_exercises`** | Programme sessions link blocks to `exercise_id` + optional `prescription` JSONB |
| **Running modalities** | Existing **Running** category exercises (`easy-run`, `threshold-run`, …) + **interval/running session types** — not separate “Zone 2 Run” exercise rows |

Importer resolution: exact `slug`, then exact `name` (`FounderProgrammeExerciseResolver`).

## Migration

**File:** `supabase/migrations/20260724140000_founder_exercise_library_wave1.sql`

- Inserts **55** new exercises (`EX-073` … `EX-127`)
- `ON CONFLICT (exercise_id) DO NOTHING` (idempotent)
- Sets `published = true`
- Populates category, movement pattern, equipment, primary muscles, `loading_options` (tracking hints)
- Does **not** populate cues, videos, regressions, or progressions (future milestones)

**Apply:**

```bash
supabase db push
```

## Existing exercises reused (Wave 1 — no duplicate rows)

| Programme label | Reuse canonical name | Slug |
|-----------------|----------------------|------|
| Goblet Squat | Goblet Squat | `goblet-squat` |
| Dumbbell Floor Press | Dumbbell Floor Press | `dumbbell-floor-press` |
| Push-up / Push Up | Push Up | `push-up` |
| Pull-up | Pull Up | `pull-up` |
| Dumbbell Shoulder Press | Dumbbell Strict Press | `dumbbell-strict-press` |
| Push Press | Barbell Push Press | `barbell-push-press` |
| Rear Delt Fly | Reverse Fly | `reverse-fly` |
| Lateral Raise | Lateral Raise | `lateral-raise` |
| Hammer Curl | Hammer Curl | `hammer-curl` |
| Bulgarian Split Squat | Bulgarian Split Squat | `bulgarian-split-squat` |
| Walking Lunge | Walking Lunge | `walking-lunge` |
| Reverse Lunge | Reverse Lunge | `reverse-lunge` |
| Step-up | Step Up | `step-up` |
| Sandbag Carry | Sandbag Carry | `sandbag-carry` |
| Pike Push-up | Pike Push Up | `pike-push-up` |
| Front Plank | Plank | `plank` |
| Dead Bug | Dead Bug | `dead-bug` |
| Barbell deadlift pattern | Deadlift | `deadlift` |
| Running (modality) | Easy Run, Threshold Run, Strides, … | `easy-run`, `threshold-run`, … |
| General mobility block | Full Body Mobility Flow | `full-body-mobility-flow` |

## Running recommendation

Do **not** add Zone 2 / Tempo / Long Run / Recovery Run as separate exercises.

**Prescribe running via:**

1. **Session** with `session_type: running` / `intervals` and coach notes (intent: zone 2, tempo, long easy).
2. **Catalogue link** to an existing Running exercise (e.g. `easy-run`, `threshold-run`) when the block needs a movement identity for history or capture.
3. **Interval execution engine** for structured work/rest (see `07 Documentation/37_Interval_Execution_Engine.md`).

## Week 1 importer audit (post–Wave 1)

After migration, structured strength/accessory movements in the founder week resolve via slug.

**Still not catalogue exercises (by design):**

| Item | Representation |
|------|----------------|
| Zone 2 / Tempo / Long run labels | Session notes + `easy-run` / `threshold-run` slugs |
| Stretching (generic) | Day or session `coach_notes` / mobility flow |
| GOWOD | Session or block `coach_notes` (optional link to `full-body-mobility-flow`) |

## Tests

- `test/supabase/founder_exercise_library_wave1_migration_test.dart`
- `test/founder_programme_import/founder_week1_exercise_resolution_test.dart`
