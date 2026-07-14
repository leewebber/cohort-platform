# 40 — Session Player Component Architecture

**Status:** Implemented (v0.1)  
**Related:** `38_Execution_Engine_Architecture.md`, `35_Strength_Performance_Logging.md`, `37_Interval_Execution_Engine.md`, `39_Circuit_Execution_Engine.md`

---

## 1. Purpose

Strength and interval execution views share the same **session lifecycle** — header, progress summary, notes, finish actions, leave dialogs, previous performance framing, and progress cards — but differ sharply in **mode-specific work UI** (sets vs phases vs future circuit clocks).

This document defines the shared presentation layer extracted before `CircuitSessionView` so new modes can reuse visual and interaction patterns without duplicating widgets or merging business models.

---

## 2. What is shared

Shared components live under `lib/features/session/widgets/shared/`. They accept **display data and callbacks only** — no strength or interval model imports.

| Component | Role |
|-----------|------|
| `SessionExecutionHeader` | Mode eyebrow + optional session title |
| `SessionProgressSummary` | Completed/total label + optional step progress bar |
| `SessionNoteField` | Optional session note with shared styling; caller owns value |
| `SessionFinishActions` | Finish Session + End Session Early buttons |
| `SessionLeaveDecision` | Typed leave-dialog result (`resumeLater`, `endEarly`, `cancel`) |
| `EarlySessionEndDialog` | Shared early-finish confirmation + optional reason |
| `EarlySessionEndResult` | Dialog result carrying optional `EarlySessionEndReason` |
| `PreviousPerformanceShell` | Loading / empty / content / opportunity layout shell |
| `TodaysOpportunitySection` | Reusable opportunity bullet block |
| `ProgressResultCard` | Title, message, reasons, accent styling (container or card) |
| `PreviewModeBanner` | Non-persistent preview warning |

### Shared models

| Model | Location |
|-------|----------|
| `SessionLeaveDecision` | `lib/features/session/models/session_leave_decision.dart` |
| `EarlySessionEndResult` | `lib/features/session/models/early_session_end_result.dart` |
| `EarlySessionEndReason` | `lib/features/session/models/early_session_end_reason.dart` (pre-existing) |

---

## 3. What remains mode-specific

Each execution view keeps its own:

| Concern | Strength | Intervals | Future circuit |
|---------|----------|-----------|----------------|
| Execution state | `_StrengthExerciseLog`, set entries | `IntervalSessionExecutionState` | `CircuitSessionExecutionState` |
| Work UI | Set rows, rest timer, exercise cards | Phase cards, recovery timer, plan overview | Movement list, format clocks |
| Hydration / persistence | `StrengthSessionHydrator`, set repository | `IntervalSessionHydrator`, interval repository | Circuit hydrator (future) |
| Progress services | `StrengthProgressService` | `IntervalProgressService` | `CircuitProgressService` (future) |
| Previous performance data | Per-exercise `PreviousExercisePerformance` | Session `PreviousIntervalPerformance` | Session circuit history (future) |
| Leave coordinators | `StrengthSessionLeaveCoordinator` | `IntervalSessionLeaveCoordinator` | `CircuitSessionLeaveCoordinator` (future) |
| Finish summaries | `StrengthSessionFinishSummary` | `IntervalSessionFinishSummary` | Circuit finish summary (future) |

Mode views **map** their progress results to `ProgressResultCard` display props. They do **not** pass `ExerciseProgressResult` or `IntervalProgressResult` into shared widgets.

---

## 4. Composition principles

1. **Thin shared widgets** — layout and styling only; no repositories, services, or persistence.
2. **Callbacks outward** — buttons and fields invoke caller handlers; shared layer never finishes sessions.
3. **Display props inward** — pass strings, counts, colors, and child widgets; not domain types.
4. **Extract when genuinely shared** — if only one mode uses a pattern, keep it local.
5. **Preserve per-mode copy** — configurable labels (`exercises` vs `work intervals`, note hints, helper text) avoid forced normalisation.
6. **No universal player** — shared components compose inside mode-specific views; there is no single `UniversalSessionPlayer` widget.

### Example: strength header + progress

```dart
SessionExecutionHeader(
  modeLabel: 'STRUCTURED STRENGTH',
  sessionTitle: widget.sessionTitle,
),
SessionProgressSummary(
  completedCount: completedCount,
  totalCount: totalSteps,
  summaryLabel: '$completedCount of $totalSteps exercises complete',
  showProgressBar: true,
),
```

### Example: interval progress result mapping

```dart
ProgressResultCard(
  eyebrow: 'TODAY\'S RESULT',
  title: result.headline,
  message: result.message,
  accentColor: _intervalProgressAccent(result.progressType),
  variant: ProgressResultCardVariant.card,
),
```

---

## 5. Why Cohort avoids one giant universal player

A single mega-widget would:

- Force lowest-common-denominator state (sets **and** phases **and** circuits in one object)
- Couple unrelated persistence paths
- Make preview, resume, and early-finish edge cases harder to reason about
- Slow iteration when one mode needs a UX change

Instead, Cohort shares **lifecycle chrome** and keeps **execution engines** separate — matching `SessionExecutionRouter` and `38_Execution_Engine_Architecture.md`.

```
SessionPlayerScreen
  └─ SessionExecutionRouter → mode
       ├─ StrengthSessionView   (sets UI + shared chrome)
       ├─ IntervalSessionView   (phase UI + shared chrome)
       └─ CircuitSessionView    (future: movement UI + shared chrome)
```

---

## 6. Per-mode shared component usage

### Strength (`StrengthSessionView`)

| Shared component | Usage |
|------------------|-------|
| `SessionExecutionHeader` | Structured strength eyebrow + title |
| `SessionProgressSummary` | Exercise count + step bar |
| `SessionNoteField` | End-of-session note with save helper |
| `SessionFinishActions` | Finish when complete; end early when partial |
| `SessionLeaveDecision` | Back-navigation leave dialog |
| `EarlySessionEndDialog` | `unitLabel: exercises`, warning confirm |
| `PreviousPerformanceShell` | Per-exercise previous performance + opportunity |
| `ProgressResultCard` | Per-exercise progress after completion |

### Intervals (`IntervalSessionView`)

| Shared component | Usage |
|------------------|-------|
| `SessionExecutionHeader` | Modality eyebrow (no title — preserves existing layout) |
| `SessionProgressSummary` | Work interval count; no bar |
| `SessionNoteField` | Optional note during/after work; filled style |
| `SessionFinishActions` | Finish / end early |
| `SessionLeaveDecision` | Back-navigation leave dialog |
| `EarlySessionEndDialog` | `unitLabel: work intervals` |
| `PreviousPerformanceShell` | Session-level previous card + opportunity |
| `ProgressResultCard` | Session-level today's result |

### Preview (`SessionPreviewScreen`)

| Shared component | Usage |
|------------------|-------|
| `PreviewModeBanner` | Non-persistent preview warning |

---

## 7. How `CircuitSessionView` should reuse the shared layer

When implementing circuit execution (see `39_Circuit_Execution_Engine.md`):

| Area | Reuse |
|------|-------|
| Header | `SessionExecutionHeader` — format label + session title |
| Progress | `SessionProgressSummary` — `rounds complete`, `movements complete`, or time-cap label |
| Note | `SessionNoteField` — post-session or end-of-work note |
| Finish | `SessionFinishActions` — finish + end early |
| Leave | `SessionLeaveDecision` + leave dialog (mode-specific copy in caller) |
| Early end | `EarlySessionEndDialog` — `unitLabel: rounds` or `movements` |
| Previous | `PreviousPerformanceShell` — AMRAP / for-time / EMOM previous score content |
| Progress card | `ProgressResultCard` — map `CircuitProgressResult` to display props |
| Preview | `PreviewModeBanner` in coach preview |

Keep in `CircuitSessionView` only:

- `CircuitSessionExecutionState` orchestration
- `CircuitTimerController` UI
- Full movement list
- Score entry fields
- `CircuitSessionLeaveCoordinator`
- `CircuitProgressService` evaluation

---

## 8. File map

```
lib/features/session/
  models/
    session_leave_decision.dart
    early_session_end_result.dart
    early_session_end_reason.dart
  widgets/
    shared/
      session_execution_header.dart
      session_progress_summary.dart
      session_note_field.dart
      session_finish_actions.dart
      early_session_end_dialog.dart
      previous_performance_shell.dart
      progress_result_card.dart
      preview_mode_banner.dart
    strength_session_view.dart
    interval_session_view.dart
```

---

## 9. Out of scope

- Merging strength/interval/circuit business models
- Shared progress or persistence services
- Universal session state object
- Changes to `SessionPlayerScreen` routing
- Database schema changes

---

## 10. Related code

| Artifact | Role |
|----------|------|
| `StrengthSessionView` | Strength execution + shared chrome |
| `IntervalSessionView` | Interval execution + shared chrome |
| `SessionPreviewScreen` | Preview banner + mode views |
| `SessionProgressBar` | Legacy step bar; still used by `SessionPlayerScreen` shell |

`SessionProgressSummary` inlines bar rendering for strength sessions. `SessionProgressBar` remains for the player shell until that screen migrates.
