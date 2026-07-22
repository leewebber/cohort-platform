# 69 — V2.0 Coach Daily Operations

Introduces a Coach Home dashboard so Lee can manage 5–10 athletes each morning without opening every athlete individually.

## User problem

The platform could coach athletes, but coaches lacked a practical operational view:

- Who trained yesterday
- Who has training today
- Who missed sessions
- Who needs attention

The athlete roster listed names and programme titles only — no today status, compliance, or last activity.

## Phase 0 findings

| Layer | State before Sprint 6 |
|-------|----------------------|
| **Coach entry** | `CoachStudioHomeScreen` → `AthleteRosterScreen` (basic list) |
| **Roster service** | `CoachAthleteService.listLinkedAthletes()` — name + programme only |
| **Athlete detail** | Assignment + latest adaptation only |
| **Reuse available** | `ProgrammeScheduleResolver`, `ProgrammeProgressSummaryService`, `HomeTodaySessionLabels`, `AdaptationPrescriptionService`, performance history |
| **Missing** | Compliance logic, behind-schedule mapping, dashboard UI, batch orchestration |

**Conclusion:** Data existed in services; Sprint 6 adds thin orchestration + card-based UI. No new backend schema.

## Coach Home dashboard

Entry points:

- Home → **My Athletes** (coach users)
- Coach Studio → **Athletes** section

Screen: `CoachHomeDashboardScreen`

Shows **My Athletes** as scrollable cards (mobile-first, no tables):

| Card field | Source |
|------------|--------|
| Display name | Roster entry |
| Active programme | Resolution / roster |
| Week/day | `HomeTodaySessionLabels.weekLabel` |
| Sessions completed | `ProgrammeProgressSummaryService` |
| Last activity | Latest terminal slot outcome or performance record |
| Today status | Schedule resolution + compliance |
| Compliance | `CoachComplianceSummaryService` |

Filter chips:

- All
- Needs Attention
- Training Today
- Completed Today
- No Programme

Primary actions per card: **Open athlete**, **Assign / Replace programme**.

## Today statuses

| Status | Meaning |
|--------|---------|
| Training today | Executable session on cursor |
| Completed today | Day complete or terminal outcome today |
| Rest day | Rest day on schedule |
| Behind schedule | Required slots before cursor incomplete |
| No active programme | No assignment |
| Programme paused | Assignment paused |

## Compliance (deterministic)

`CoachComplianceSummaryService` compares required template slots before the assignment cursor against terminal outcomes.

| Label | Rule |
|-------|------|
| On Track | No incomplete required slots before cursor |
| 1 Session Behind | Exactly one |
| N Sessions Behind | N > 1 |
| Completed Today | Day/programme complete or terminal outcome resolved today |

`needsAttention` = behind > 0, no programme, or paused.

No analytics, charts, or AI.

## Athlete detail improvements

`AthleteDetailScreen` now shows:

- Current programme summary (week/day, progress)
- Compliance summary
- Latest adaptation (existing)
- Recent sessions (performance history, limit 5)

Quick actions:

- Assign programme
- Replace programme
- View history

Uses `CoachAthleteDailyStatusService.loadSnapshotForAthlete` — same orchestration as dashboard cards.

## Service reuse

| Component | Role |
|-----------|------|
| `CoachAthleteDailyStatusService` | Per-athlete operational snapshot |
| `CoachComplianceSummaryService` | Deterministic compliance labels |
| `CoachHomeDashboardController` | Load roster snapshots + filter state |
| `CoachAthleteService` | Linked roster |
| `ProgrammeAssignmentStore` / `ProgrammeVersionStore` / `ProgrammeSlotOutcomeStore` | Assignment data |
| `ProgrammeScheduleResolverImpl` | Today resolution |
| `ProgrammeProgressSummaryService` | Session counts |
| `PerformanceRecordStore` | Last activity fallback |

No duplicate query layer — one orchestrator per athlete snapshot.

## Files added

```
lib/features/coach_operations/
  models/coach_athlete_daily_snapshot.dart
  services/coach_compliance_summary_service.dart
  services/coach_athlete_daily_status_service.dart
  services/coach_operations_services.dart
  controllers/coach_home_dashboard_controller.dart
  screens/coach_home_dashboard_screen.dart
  widgets/coach_athlete_operational_card.dart

test/coach_operations/
  coach_compliance_summary_service_test.dart
  coach_home_dashboard_test.dart
```

## Out of scope (Sprint 6)

Messaging, notifications, charts, AI, payments, marketplace, public coach discovery, organisations, Coach Studio redesign.

## Testing

| Suite | Coverage |
|-------|----------|
| `test/coach_operations/coach_compliance_summary_service_test.dart` | On track, behind, completed today |
| `test/coach_operations/coach_home_dashboard_test.dart` | Filters, controller, widget empty/ready/filter |
| Existing coach / assignment / progress tests | Regression |

Run:

```bash
flutter test test/coach_operations/
flutter test test/coach_athlete/
flutter test test/personal_training/
flutter test test/programme/programme_progress_summary_service_test.dart
flutter analyze
flutter test
```
