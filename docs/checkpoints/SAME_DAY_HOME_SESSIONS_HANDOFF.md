# Same-day Home sessions — handoff

**Recorded:** 2026-09-26
**Branch:** `fix/home-same-day-sessions-v1`
**Base:** `origin/main` `e3bf1a237f63f806a7b3ce0f8387a7004d16a288`
**Contract:**
[`../architecture/Same_Day_Home_Sessions_v1.md`](../architecture/Same_Day_Home_Sessions_v1.md)

```text
BALI_SAME_DAY_HOME=COMPLETE
LEE_BALI_HYBRID_BASE=ACTIVE_PRIVATE
LEE_BALI_CURRENT_ASSIGNMENT_APPLIED=true
NEXT_IMPLEMENTATION_AUTHORISED=false
```

Home already listed every occurrence on the civil date. Each Today
card still painted its own TODAY / date / programme chrome, so Sunday
AM and PM looked like two programme days. Generic `todayOccurrence`
could silently pick AM.

Home now groups authored non-rest occurrences for the assignment
timezone date. One heading. One card per occurrence. Display order is
`session_order`. AM/PM comes from authored `time_of_day` only. Generic
`prepareForAthlete` returns `ambiguous_same_day_today` when more than
one incomplete occurrence exists today. Each card prepares and opens
its own occurrence ID. Completing AM does not complete PM and does not
advance Home to Monday.

Read-projection only:
`supabase/migrations/20260926190000_fixed_occurrence_time_of_day.sql`

That function replace adds `time_of_day` to occurrence JSON. It does
not change dates, assignments, or Saturday Strength A evidence.

Preview (not production `main`):

```bash
flutter run -d chrome --web-port 4174 -t lib/main_same_day_home_preview.dart
```

Do not re-enrol Bali. Do not begin Sunday sessions during phone check.
Do not move PM to Monday.
