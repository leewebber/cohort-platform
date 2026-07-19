# M7 — Athlete Session Experience

## Product goals

Athletes experience Sessions as ordered Blocks with workout content, linked exercise guidance, and timer tools — without seeing database concepts, legacy steps, or authoring controls.

M7 focuses on execution experience. Detailed performance logging is deferred to M8.

## Navigation flow

```
Athlete Home (Today's Session)
  → SessionOverviewScreen
  → ActiveSessionScreen
  → SessionCompleteScreen
  → Home
```

Route arguments use stable identifiers (`protocolId`, `trainingSessionId`) — not mutable draft objects.

## Execution state architecture

| Component | Role |
| --- | --- |
| `SessionExecutionPlan` | Immutable athlete-facing projection from blocks |
| `ActiveSessionState` | Local execution progress (active block, completion, timestamps) |
| `SessionExecutionController` | Immutable state updates |
| `AthleteSessionMemoryStore` | In-memory restoration within app lifecycle |

Session status: `notStarted`, `inProgress`, `completed`, `abandoned`.

Authoring models and persistence rows are never mutated during athlete execution.

## SessionExecutionPlan usage

`SessionExecutionLoader` resolves content:

1. Load block-native rows when present
2. Fall back to legacy `protocol_steps` conversion
3. Hydrate linked exercises
4. Produce unified `SessionExecutionPlan`

Legacy and block-native Sessions render through the same athlete UI.

## Block execution model

- Binary block completion (not started / active / complete)
- Manual mark complete / reopen
- Skip forward without auto-completing previous blocks
- Finish confirmation when blocks remain incomplete

## Timer integration

`BlockTimerController` drives athlete timers from typed `TimerConfiguration`:

- AMRAP countdown
- EMOM interval progression
- For Time stopwatch (+ optional cap)
- Intervals / Tabata work-rest phases
- Rounds tracker

Timer settings are never inferred from workout text.

## Linked exercise navigation

Linked exercises open `ExerciseDetailScreen` via push navigation. Returning preserves active block, completion state, and timer pause state.

## Legacy compatibility

`SessionPlayerScreen` and step-based execution engines remain in the codebase for coach preview and adapter use. Athlete Home routes to the block-native flow via `SessionOverviewScreen`.

## Known limitations

- Completion state is in-memory only (no app-restart restoration)
- No set/rep/load/RPE logging (M8)
- Exercise video URLs exist on model but no video player UI yet
- No deep links into sessions

## M8 extension points

- Persistent execution and performance logging
- App-restart session restoration
- Block-level analytics
- Richer timer persistence and wearable integration
