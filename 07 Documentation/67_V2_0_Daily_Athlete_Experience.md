# 67 — V2.0 Daily Athlete Experience

Sprint 4 improves the athlete-facing daily loop without new backend architecture. Today's training is the centre of Home; the athlete should never wonder what to do today.

## Scope

### In scope

- Today's card enrichment (programme, week/day, duration, goal, progress, adaptation notice)
- Empty and loading states (no programme, rest day, programme complete, errors)
- Session overview readability (goal, adaptation, blocks, notes)
- Session completion celebration (saved, progress, adaptation, next session)
- Programme progress display (`Week X of Y • A / B sessions completed`)
- One-tap start from Home → Active Session

### Out of scope

- AI, messaging, notifications, videos, social, gamification, marketplace, coach dashboards
- New backend services or schema

## Architecture

### Programme progress (UI-only)

`ProgrammeProgressSummaryService` computes progress from:

- `ProgrammeTemplateTree` — counts required session slots
- `ProgrammeSlotOutcome` list — counts terminal outcomes per slot

Loaded in `HomeTodaySessionLoader` and attached to programme-backed Home states.

### Session launch

`SessionExecutionLauncher` centralises the path from Home or Session Overview into `ActiveSessionScreen` (plan load, prescription overrides, performance draft, controller restore).

Home **START SESSION** / **RESUME SESSION** uses the launcher directly (one tap). **VIEW SESSION** (completed today) opens Session Overview.

### Labels

`HomeTodaySessionLabels` provides display helpers:

- `programmeName`, `weekLabel`, `sessionGoal`, `adaptationNotice`
- `progressLabel`, `estimatedDuration`

## User flows

### Home — executable session

1. Athlete opens app → Today section
2. Card shows session title, programme, week/day, duration, goal, progress, adaptation if substituted
3. **START SESSION** → Active Session (single tap)

### Home — non-training states

| State | Card |
|-------|------|
| Loading | CohortCard shell |
| No programme | Explains coach assignment |
| Rest day | Recovery copy + continue CTA |
| Day complete | Continue programme CTA |
| Programme complete | Congratulations + progress |
| Error | Retry + connectivity hint |

### Session complete

After finish review:

- SESSION COMPLETE header
- Block summary + duration
- Session saved card
- Programme progress (when available)
- Adaptation line (always shown; defaults to "Programme continues as planned.")
- Next scheduled session preview from `ProgrammeProgressionResult`

## Files

| Area | Path |
|------|------|
| Today card | `lib/core/widgets/today_session_card.dart` |
| Home section | `lib/features/home/widgets/home_today_session_section.dart` |
| Loader + labels | `lib/features/home/services/home_today_session_loader.dart` |
| Progress model | `lib/features/programme/models/programme_progress_summary.dart` |
| Progress service | `lib/features/programme/services/programme_progress_summary_service.dart` |
| Session launcher | `lib/features/session/services/session_execution_launcher.dart` |
| Session overview | `lib/features/session/screens/session_overview_screen.dart` |
| Session complete | `lib/features/session/screens/session_complete_screen.dart` |

## Tests

- `test/programme/programme_progress_summary_service_test.dart`
- `test/home/athlete_daily_experience_test.dart`

Covers today's card, empty/rest/complete states, completion screen, adaptation messaging, and progress labels.

## Remaining UX gap before beta

Coach assignment and programme visibility still depend on backend data quality. Athletes without an assigned programme see a static empty state with no in-app path to request a programme (by design for this sprint — no messaging).
