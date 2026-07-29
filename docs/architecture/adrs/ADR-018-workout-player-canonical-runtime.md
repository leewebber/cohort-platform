# ADR-018: WorkoutPlayer is the canonical runtime state machine

**Status:** Accepted (Phase 2 complete)  
**Date:** 2026-07-29

## Context

M7 `ActiveSessionState` and `SessionExecutionController` predated domain execution. Phase 2 required a single runtime authority for programme launches without rewriting athlete UI.

## Decision

For programme Home launches with `WorkoutSessionLaunchContext`:

- **`WorkoutPlayer`** owns in-session transitions: activate, pause, navigate steps/blocks, finish, abandon.
- **`SessionExecutionController`** is a **UI adapter** that delegates mutations to the player and projects `ActiveSessionState` via `WorkoutPlayerActiveSessionProjection`.
- **`SessionExecutionController.completeSession`** must **not** be the terminal authority on the programme finish path; finish review uses orchestrator completion then `applyDomainCompletionProjection`.

Without launch context, the controller retains legacy plan-owned state (manual / preview compatibility).

## Consequences

- Block completion in M7 UI calls `markBlockComplete` → player navigation + overlay `completedBlockIds`.
- Player must be **active** when `completeTodayWorkout` runs; projection syncs finished player afterward.
- Abandon on player path: `SessionExecutionController.abandonSession` → `player.abandon` (no domain occurrence terminal workflow wired in Sprint 10 — see completion report limitations).

## Alternatives considered

- **Replace M7 UI with player-native screens** — deferred; violates Phase 2 “no UX change” constraint.
- **Dual ownership (controller + player)** — rejected after Sprint 9; duplicated finish transitions.

## Migration implications

- Phase 4+: optional retirement of legacy `ActiveSessionState` mutations when all entry points supply launch context.
- Resume across app restart requires rehydrating player + occurrence from persistence (not implemented).
