# Daily Briefing MVP — Phase 5 Sprint 6

**Date:** 2026-07-29  
**Status:** Home as coaching briefing  
**Engine:** Unchanged — reads existing Coach Brain brief fields only

---

## Product intent

Opening Cohort should feel like meeting your coach each morning.

Home answers:

**What should I know before I train today?**

Not a dashboard. Not a chat. A briefing.

---

## Briefing contents

| Element | Source |
|---------|--------|
| Greeting | Time of day + athlete first name |
| Session headline | Engine session name / focus |
| Estimated duration | `WorkoutSessionBrief.estimatedDurationMinutes` |
| Training focus | `trainingIntent` → `primaryFocus` → objective |
| Current plan / week / day | Active `PlanDefinition` + `PlanAssignment` |
| Yesterday | Prior-day `SessionCompletion` |
| Today's standards | Curated checklist (hydration, nutrition, sleep, recovery) |
| Motivation | Deterministic rotation from curated library |
| Execute CTA | Dominant — launches Workout Player |

Rest days (Recovery / deload intent) hide Execute and show a calm rest card.

No active plan → invite to browse plans.

---

## Dependencies

- `AthleteProfileSession` (profile, programme, plan, assignment)  
- `WorkoutSessionBrief` from Coach Brain projection  
- `SessionCompletionStore` (yesterday)  

No planning logic duplication. No LLM.

---

## Known limitations

- Rest day inferred from brief language, not a calendar schedule  
- Standards are product reminders, not personalised labs  
- Motivation rotates by calendar day only  
- Memory-only completions for Yesterday  

---

## Tests

`test/daily_briefing/daily_briefing_test.dart`
