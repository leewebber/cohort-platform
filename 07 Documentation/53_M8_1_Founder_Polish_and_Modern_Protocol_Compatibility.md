# M8.1 — Founder Polish and Modern Protocol Compatibility

## Founder acceptance findings (M8)

**Passed:** Home → Session Overview → Active Session, in-progress record creation, save indicator, legacy conversion, block completion, Session Review, RPE/note capture, terminal completion, programme progression, Training History, snapshot-backed historical detail, idempotent completion.

**Issues addressed in M8.1:**

| # | Issue | Fix |
|---|-------|-----|
| 1 | Session Complete Done did not navigate | Done now navigates from `SessionCompleteScreen` using its own mounted `context` |
| 2 | Context-after-unmount on Done | Removed stale Review-screen callback closure |
| 3 | Running/endurance used completion-only capture | Added `EnduranceResultData` editor with distance, duration, pace, optional HR |
| 4 | History showed “1 sets logged” for runs | Centralised `PerformanceResultSummaryFormatter` keyed by result type |
| 5 | Single-block session duplicated Current/All Blocks | Single-block sessions hide Previous/Next and All Blocks |
| 6 | Previous/Next visible for one-block sessions | Hidden when `totalBlocks <= 1` |
| 7 | Duplicate completion controls | Completion capture shows helper text; block card owns Mark complete |
| 8 | ListTile ink/background debug warnings | `SwitchListTile` wrapped in transparent `Material` |
| 9 | Numeric digit reversal | Preserved via `PerformanceNumericField`; regression tests added |
| 10 | Legacy protocols lack modern metadata | Explicit `performance_capture_mode` on blocks + conservative legacy resolver |

## Completion navigation

Stack: Home → Overview → Active → Review → (replace) Complete.

`SessionCompleteScreen` Done calls `Navigator.popUntil((route) => route.isFirst)` from its own widget context. Review no longer passes a callback that captures a disposed context.

## Endurance capture model

`EnduranceResultData` (`PerformanceResultType.endurance`):

- `completed`
- `distance`, `distanceUnit` (`km`, `mi`, `m`)
- `durationSeconds`
- `averageHeartRate` (optional)
- `note` (optional)

Pace/speed is derived at display time via `EnduranceMetricsCalculator` — not stored redundantly.

Partial entry and completion without metrics are allowed.

## Modern performance capture metadata

`session_blocks.performance_capture_mode` (migration `20260719170000_add_block_performance_capture_mode.sql`).

Coach-facing options in Session Builder:

Automatic, Completion, Strength, Endurance, AMRAP, For Time, Intervals, Rounds, Custom metric.

Defaults resolve from block type and workout format when set to Automatic.

Snapshots include `performanceCaptureMode` on `BlockPerformanceSnapshot` (additive, schema-version-safe decode).

## Capture-mode resolution priority

1. Explicit `performance_capture_mode` on block (when not Automatic)
2. Workout format (AMRAP, For Time, Intervals, Rounds, …)
3. Block type + linked exercise count (strength blocks only)
4. Structured legacy labels (`Sets:`, `Reps:`, `Load:`, `Duration:`, `Distance:`)
5. Conservative completion fallback

Linked exercise alone does **not** imply strength capture.

## Legacy compatibility policy

**Legacy protocols:**

- Remain executable and loggable
- Use structured metadata where present
- Receive conservative capture defaults
- Are not guaranteed every modern feature
- May be rebuilt later (see backlog)

**Modern app-authored protocols:**

- Use explicit blocks, workout format, timer configuration
- Persist explicit or defaulted performance capture mode
- Produce adaptive execution editors and historical summaries
- Do not rely on free-text inference

## Adaptive history summaries

`PerformanceResultSummaryFormatter` produces typed summaries:

- Completion → “Completed as prescribed” / “Not completed” / “Skipped”
- Strength → set count + concise load/rep summary
- Endurance → distance, duration, pace, optional HR
- AMRAP / For Time / Intervals / Rounds / Custom → type-specific lines
- Unknown → “Performance recorded”

Historical detail reads snapshot + recorded result type only.

## Single-block execution UX

When `totalBlocks <= 1`:

- Hide Previous / Next
- Hide ALL BLOCKS section
- Show only the active block card
- Retain progress indicator and Finish Session

## Completion control clarity

- Simple completion capture: helper text only; Mark block complete on block card
- Detailed editors: fields + Mark block complete
- Completed block: badge + Reopen (preserves entered data)
- `markBlockComplete` syncs `CompletionResultData` / `EnduranceResultData` completion flags

## Numeric input

`PerformanceNumericField` maintains stable controllers and cursor position across parent rebuilds.

## Test protocol

`test/support/m8_modern_capture_test_fixtures.dart` defines **M8 Modern Capture Test** with warm-up, strength, threshold run, AMRAP, and cool-down blocks for acceptance testing.

## Remaining limitations

- No GPS, wearables, or external integrations
- Legacy protocols not bulk-migrated
- For Time editor retains a Completed toggle (distinct from block completion semantics)

## M8.1.5 — Final founder acceptance cleanup

**Exercise label resolution (installed content):** Founder strength links now persist `displayLabelOverride` (`Back Squat`, `Bench Press`) from `FounderAcceptanceContent.exerciseDisplayNames`. Runtime resolution via `SessionExecutionBlock.fromSessionBlock()` → `AthleteExerciseLabelResolver.fromExerciseLink()` no longer depends on catalogue seed data for the founder programme.

**Athlete-facing wording:**

| Surface | Change |
|---------|--------|
| Home / Overview subtitle | “Required session” → “Today's session” |
| Home completed state | “Completed Today” → “Completed today”; “View Session” → “View summary” |
| Review save indicator | “Draft ready” → “Ready to save” |
| Review RPE | Helper: “How hard did the session feel? 1 = very easy, 10 = maximal.” |
| Session complete | “Saved to training history.” (status suffix removed) |

**Endurance derived metrics:** Pace shown only for `km` / `mi` / `m`; speed only for `km/h`, `kph`, `mph`. Unsupported units hide the live derived metric rather than inventing values such as `40.0 watts/h`.

**Tests:** `test/founder_acceptance/founder_acceptance_exercise_labels_test.dart` covers install → plan build → snapshot → active session UI using real `FounderAcceptanceContent`.

## M8.1.6 — Preserve exercise label overrides in execution projection

Installed founder content persists `display_label_override` on block exercise links. Runtime athlete execution now preserves that override on `SessionExecutionExerciseSummary.displayLabelOverride` and resolves labels via `AthleteExerciseLabelResolver.fromExecutionSummary`.

Performance snapshots copy override into `ExercisePerformanceSnapshot.labelOverride` at capture time.

**Reinstall required:** existing Supabase rows created before M8.1.5 may still have `display_label_override = NULL`. Run **Install Founder Acceptance Programme** once after deploying M8.1.6.

## Future legacy content migration backlog

High-value rebuild candidates after founder sign-off:

1. Cohort Foundation Test (early mixed legacy steps)
2. Threshold Run / aerobic sessions with free-text-only prescriptions
3. Any protocol relying on linked exercises without structured labels

## Files touched (M8.1)

- Navigation: `session_complete_screen.dart`, `session_finish_review_screen.dart`
- Endurance: `performance_result_data.dart`, `performance_capture_widgets.dart`, `endurance_metrics_calculator.dart`
- Summaries: `performance_result_summary_formatter.dart`
- Capture resolution: `block_capture_mode_resolver.dart`, `block_performance_capture_mode.dart`, `session_block.dart`
- UX: `active_session_screen.dart`, `home_today_session_section.dart`, `home_today_session_loader.dart`
- Labels: `founder_acceptance_content.dart`, `athlete_exercise_label_resolver.dart`
- Authoring: `session_block_editor_card.dart`
- Snapshots: `performance_snapshot.dart`, `performance_snapshot_builder.dart`
- Migration: `20260719170000_add_block_performance_capture_mode.sql`
- Tests: `test/m8/m8_1_founder_polish_test.dart`, `test/founder_acceptance/founder_acceptance_exercise_labels_test.dart`, `test/support/m8_modern_capture_test_fixtures.dart`
