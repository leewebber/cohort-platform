# M8 — Performance Capture and Training History

## Product objective

M8 introduces a durable athlete performance domain that records what was actually performed, independently from coach-authored training content, execution UI state, and programme assignment metadata.

Coach-authored content defines what was prescribed. Athlete-generated performance data records what happened.

## Canonical terminology

| Term | Meaning |
|------|---------|
| `TrainingSession` | Existing assignment/runtime row in `training_sessions` (planned/in-progress/completed metadata) |
| `TrainingSessionRecord` | Immutable athlete performance record with prescription snapshot |
| `TrainingBlockResult` | Block-level performed outcome linked to a session record |
| `TrainingExerciseResult` | Exercise-level performed outcome within a block |
| `TrainingSetResult` | Queryable set row for strength progression |
| `ActivePerformanceDraft` | Mutable in-session performance capture state |
| `SessionExecutionPlan` | Immutable execution projection (unchanged from M7) |

Do not store performance results inside `SessionBlock`, `ProtocolDraft`, `SessionExecutionPlan`, or authoring models.

## Architecture boundary

```
Coach content (Programme → Session → Block → Linked Exercise)
        ↓ snapshot at start/completion
Athlete performance (TrainingSessionRecord → BlockResult → ExerciseResult → SetResult)
```

Historical records use embedded snapshots (`SessionPerformanceSnapshot`, `BlockPerformanceSnapshot`, `ExercisePerformanceSnapshot`) so later coach edits do not rewrite history.

## Persistence schema

Migration: `supabase/migrations/20260719160000_add_training_session_records.sql`

Tables:

- `training_session_records`
- `training_block_results`
- `training_exercise_results`
- `training_set_results`

Idempotency:

- Unique in-progress record per `(athlete_id, training_session_id)`
- Terminal completion returns existing record on retry (`complete_training_session_record` RPC + store guard)

## Result variants

Typed application models in `lib/features/performance/models/performance_result_data.dart`:

- `CompletionResultData`
- `StrengthResultData`
- `AmrapResultData`
- `ForTimeResultData`
- `IntervalResultData`
- `DistanceResultData`
- `DurationResultData`
- `RoundsResultData`
- `CustomMetricResultData`

Capture mode defaults are resolved by `BlockCaptureModeResolver` from block type, workout format, and linked exercises. Workout text is never parsed into sets/reps.

## Runtime flow

1. Home → `SessionOverviewScreen`
2. Start creates/resumes `TrainingSessionRecord` draft via `PerformanceRecordSaveCoordinator`
3. `ActiveSessionScreen` coordinates:
   - `SessionExecutionController` (navigation/completion markers)
   - `PerformanceCaptureController` (result drafts)
4. Finish → `SessionFinishReviewScreen` (RPE, note, review)
5. Save coordinator persists terminal record, then updates `training_sessions` and programme progression
6. History → `TrainingHistoryScreen` → `TrainingHistoryDetailScreen` (snapshot-based)

## Key implementation paths

| Area | Path |
|------|------|
| Draft controller | `lib/features/performance/controllers/performance_capture_controller.dart` |
| Snapshot builder | `lib/features/performance/services/performance_snapshot_builder.dart` |
| Validation | `lib/features/performance/services/performance_validation_service.dart` |
| Save orchestration | `lib/features/performance/services/performance_record_save_coordinator.dart` |
| Supabase store | `lib/features/performance/repositories/supabase_performance_record_store.dart` |
| In-memory store (tests) | `lib/features/performance/repositories/in_memory_performance_record_store.dart` |
| Capture widgets | `lib/features/performance/widgets/performance_capture_widgets.dart` |
| Finish review | `lib/features/performance/screens/session_finish_review_screen.dart` |
| History | `lib/features/performance/screens/training_history_screen.dart` |

## RLS (development)

Dev athlete allowlist policies mirror programme engine conventions (`cohort_programme_dev_athlete_ids()`).

Completed records are read-only in athlete UI for M8. In-progress records remain updatable.

## Legacy compatibility

Legacy sessions converted to a single execution block use the same performance architecture and snapshot pipeline.

## Known limitations

- No GPS, wearables, analytics dashboards, or PR detection
- No historical editing workflow
- Timer elapsed time is not auto-applied without athlete confirmation
- Timer restoration after app restart may be approximate
- Completion RPC persists session header atomically; child rows use staged upserts with idempotent keys
- No coach-facing athlete analytics in M8

## M9 readiness

M9 should attach content versioning and relationship graph without changing the performance record boundary established here.
