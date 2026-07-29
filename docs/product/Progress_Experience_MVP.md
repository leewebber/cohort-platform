# Progress Experience MVP — Phase 5 Sprint 5

**Date:** 2026-07-29  
**Status:** Calm Progress screen — “Am I getting better?”  
**Data:** In-memory completions + capability timeline from Sprint 4

---

## Product intent

Not an analytics dashboard. A Progress experience that answers one question:

**Am I getting better?**

Prefer plain language over charts. Encouragement and clarity over density.

---

## Navigation

Bottom nav **Progress** (replaces disabled Analytics) → `ProgressScreen`.

---

## Sections

| Section | Source |
|---------|--------|
| Current Plan / Week / Phase | Active `PlanAssignment` + `PlanDefinition` |
| Sessions Completed | `SessionCompletionStore` |
| Current / Longest Streak | Calendar-day streak from completions |
| Compliance | Completed vs planned-to-date + % |
| Upcoming Assessment / Milestone | Deterministic from plan duration + week |
| Recent Improvements | Upward capability timeline + consistency cues |
| Capability Timeline | Date · Capability · Direction (↑↓→) |
| Session History | Date, plan, name, duration, RPE, completion |

---

## Evidence → improvements

Sprint 4 `TrainingEvidenceUpdateService.applyWithEvents` writes `CapabilityTimelineEvent`s into `CapabilityTimelineStore`.

Progress maps those into lines such as:

- Threshold Capacity ↑  
- Upper Body Strength ↑  
- Training Consistency ↑ (streak ≥ 2)  
- Recovery Compliance ↑ (recent mid-range RPE)

---

## Compliance

```
plannedToDate = (week - 1) × daysPerWeek + (day - 1)
percentage = completed / planned × 100
```

Streaks: consecutive UTC calendar days with ≥1 completion.

---

## Known limitations

- Memory only — clears on app restart  
- No graphs, wearables, cloud, or AI summaries  
- Assessment / milestone copy is product-side, not ontology assessments  
- Empty Progress until an active plan exists  

---

## Tests

`test/progress/progress_experience_test.dart` — history, compliance, timeline, summaries, UI.
