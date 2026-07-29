# ADR-017: SessionOccurrence is the canonical workout identity

**Status:** Accepted (Phase 2 complete)  
**Date:** 2026-07-29  
**Supersedes:** Implicit “training session row = workout identity” for programme Home flows

## Context

Programme athletes need a stable identity for “today’s workout” that survives day-of adaptation, in-session navigation, and completion without conflating protocol definition, Supabase `training_sessions`, or M8 performance records.

## Decision

`SessionOccurrence` (`lib/domain/session_occurrence/`) is the **canonical workout identity** for programme Home execution:

- One occurrence per resolved programme slot / calendar date (materialized via `ProgrammeOccurrenceMaterializer` and `AthleteTodayWorkoutResolutionService`).
- Lifecycle (`planned` → `inProgress` → `completed`) and attached `AdaptedSessionExecutionSnapshot` live on the occurrence.
- `WorkoutPlayer.occurrenceId` must match the active occurrence.

Supabase `training_sessions` remains the **M8 session instance** for persistence and analytics; it is linked at launch, not substituted for occurrence identity.

## Consequences

- Home holds `HomeWorkoutExecutionContext` (in-memory bridge) with `AthleteWorkoutResult` / occurrence repository — not raw programme DTOs as lifecycle owner.
- Occurrence index is **in-memory** until a production port exists (Phase 4+).
- Non-programme launches may omit occurrence context (compatibility path).

## Alternatives considered

- **Training session id only** — rejected; adaptation and completion need domain lifecycle separate from M8 row creation timing.
- **Protocol id + date string** — rejected; insufficient for reschedule/adaptation audit.

## Migration implications

- Phase 4: persist occurrence index and domain records without changing M8 schema initially.
- UI continues to use `WorkoutSessionLaunchContext.occurrence` for domain operations.
