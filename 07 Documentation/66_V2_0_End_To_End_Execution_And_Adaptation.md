# 66 — V2.0 End-to-End Execution and Adaptation

**Status:** Implemented (Sprint 3)  
**Related:** `43_Programme_Engine_Service_Contracts.md`, `52_M8_Performance_Capture_and_Training_History.md`, `65_V2_0_Athlete_Management_And_Assignment.md`

---

## Goal

Complete the first true coaching loop:

```
Coach assigns programme
  → athlete completes today's session
  → performance saved
  → assignment progress advances
  → deterministic adaptation executes
  → future prescriptions update
```

---

## Phase 0 findings

| Area | Status before Sprint 3 |
|------|------------------------|
| M8 completion pipeline | Live — `SessionFinishReviewScreen` → `PerformanceRecordSaveCoordinator` |
| Training session record | Live — immutable M8 performance tree |
| Assignment progression | Live — `ProgrammeSessionProgressionCoordinator` |
| Schedule resolution | Live — `ProgrammeScheduleResolver` (read-only) |
| Pre-session adaptation | Evaluate only — `AdaptationDecisionService` + Home sheet |
| Post-completion adaptation | **Missing** — no execution bridge |
| `replaceSession` / slot outcomes | Service live; no post-completion caller |
| Adaptation audit | **Missing** |

**Exact gap:** After `ProgrammeProgressionService.completeSession`, no service evaluated completed performance and mutated future programme slots.

---

## Execution flow

```
SessionFinishReviewScreen._saveAndFinish
  → PerformanceRecordSaveCoordinator.completeSession
      1. M8 completeRecord
      2. training_sessions.complete
      3. ProgrammeSessionProgressionCoordinator.handleSessionCompleted
      4. AdaptationExecutionCoordinator.executeAfterSessionCompleted   ← NEW
  → SessionCompleteScreen (adaptation message)
```

---

## Adaptation bridge

| Component | Role |
|-----------|------|
| `PostCompletionAdaptationEvaluator` | Deterministic rules on completed M8 record |
| `ProgrammeFutureSlotFinder` | Locates unresolved future slots (same protocol) |
| `AdaptationExecutionService` | Evaluate → apply → audit |
| `AdaptationExecutionCoordinator` | Programme-backed guard + idempotency entry |
| `AdaptationPrescriptionService` | Read load overrides for future slot execution |

### Rules (v1)

1. **Load progression** — full completion + all prescribed strength sets completed + ≥1 prior completed slot with same protocol → +2.5 kg on next matching future slot
2. **Recovery substitution** — session ended early + future same-protocol slot exists → `AdaptationService` recovery protocol on future slot

If no rule matches: clean exit, athlete sees *"Programme continues as planned."*

---

## Transaction and idempotency

Steps run sequentially (matching programme progression v0.1):

1. Idempotency check — `programme_adaptation_events (assignment_id, trigger_training_session_id)` unique
2. Upsert future `programme_slot_outcomes` (scheduled + explanation; optional `replacement_protocol_id`)
3. Insert adaptation audit event

Duplicate completion for the same `trainingSessionId` returns the existing event — no double apply.

---

## Immutability

| Record | Mutated? |
|--------|----------|
| Completed M8 record | Never |
| Completed slot outcome | Never |
| Completed training session | Never |
| Future unresolved slot outcome | Yes — pre-applied adaptation |
| Published programme template | Never |

`ProgrammeScheduleResolver` honours pre-applied `replacement_protocol_id` on `scheduled` outcomes for future protocol substitutions.

---

## Transparency

### Athlete

`SessionCompleteScreen` shows:

- Adaptation applied → deterministic summary (e.g. *"Next Strength target increased to 62.5 kg."*)
- No adaptation → *"Programme continues as planned."*

### Coach

`AthleteDetailScreen` read-only **Latest adaptation** card:

- Explanation from deterministic rules
- Count of affected future sessions

Audit source: `programme_adaptation_events`.

---

## Database

Migration: `supabase/migrations/20260721160000_add_programme_adaptation_events.sql`

---

## Services reused

- `ProgrammeProgressionService` / `ProgrammeSessionProgressionCoordinator`
- `ProgrammeSlotOutcomeStore` / `ProgrammeScheduleResolver`
- `AdaptationService` (recovery protocol ranking)
- `StrengthProgressService` patterns (performance comparison logic)
- `TodaySessionService` / `AthleteStateSyncService` (unchanged — progression still owns cursor)

---

## Tests

| File | Coverage |
|------|----------|
| `test/adaptation/post_completion_adaptation_evaluator_test.dart` | Rules, consecutive completion, partial recovery |
| `test/adaptation/adaptation_execution_service_test.dart` | Apply, skip, idempotency, completed slot immutability |

---

## Known limitations

- No single Postgres transaction wrapping progression + adaptation (same as progression v0.1)
- Load override application depends on M8 strength capture blocks with logged sets
- Pre-session "Need to Adapt?" sheet still evaluate-only (separate from post-completion bridge)
- Protocol substitution pool uses existing `AdaptationService` scoring — not programme-intent constrained yet
- Hosted Supabase requires migration `20260721160000` applied

---

## Remaining blocker before daily real-world use

Apply hosted migrations (`20260721140000`, `20260721150000`, `20260721160000`) and verify a coach-assigned athlete completes a full week without DEBUG actions on a physical device.
