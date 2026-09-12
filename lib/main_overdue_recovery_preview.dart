import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_calendar_agenda_presentation.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_week_agenda.dart';
import 'package:flutter/material.dart';

/// Local in-memory preview for Home vs Calendar jobs.
///
/// Launch:
///   flutter run -d web-server --web-port 4174 -t lib/main_overdue_recovery_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const _HomeCalendarJobsPreview()),
  );
}

class _HomeCalendarJobsPreview extends StatefulWidget {
  const _HomeCalendarJobsPreview();

  @override
  State<_HomeCalendarJobsPreview> createState() =>
      _HomeCalendarJobsPreviewState();
}

class _HomeCalendarJobsPreviewState extends State<_HomeCalendarJobsPreview> {
  String? _expandedRowId = 'occ-incomplete';

  @override
  Widget build(BuildContext context) {
    final calendar = _previewCalendar();
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: calendar,
      weekStart: DateTime(2026, 9, 7),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('TODAY', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: 8),
                const CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thursday 10 September',
                        style: CohortTextStyles.muted,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Apollo Strength',
                        style: CohortTextStyles.cardTitle,
                      ),
                      SizedBox(height: 4),
                      Text('Begin', style: CohortTextStyles.body),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CURRENT PROGRAMME',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: 8),
                CohortCard(
                  child: Text(
                    '${calendar.programmeName}\nWeek 1 · Day 4',
                    style: CohortTextStyles.body,
                  ),
                ),
                const SizedBox(height: 36),
                const Text('CALENDAR', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: 4),
                Text(
                  AthleteProgrammeDateFormatter.dateRange(
                    DateTime(2026, 9, 7),
                    DateTime(2026, 9, 13),
                  ),
                  style: CohortTextStyles.small,
                ),
                const SizedBox(height: 12),
                AthleteProgrammeWeekAgenda(
                  rows: rows,
                  expandedRowId: _expandedRowId,
                  onToggleRow: (row) {
                    setState(() {
                      _expandedRowId = _expandedRowId == row.rowId
                          ? null
                          : row.rowId;
                    });
                  },
                  onOpenSession: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

FixedProgrammeCalendarProjection _previewCalendar() {
  FixedProgrammeOccurrenceProjection session({
    required String id,
    required String date,
    required FixedProgrammeOccurrenceState state,
    required String title,
    required String type,
    int order = 1,
    String? originalDate,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: 'preview',
      occurrenceId: id,
      sessionSlotId: 'slot-$id',
      programmeVersionId: 'version',
      protocolId: 'APOLLO',
      programmedSessionKey: 'preview-$id',
      weekNumber: 1,
      dayKey: 'day_$order',
      sessionOrder: order,
      scheduledDate: date,
      originalScheduledDate: originalDate ?? date,
      state: state,
      sessionTitle: title,
      sessionType: type,
    );
  }

  return FixedProgrammeCalendarProjection(
    assignmentId: 'preview',
    programmeName: 'Apollo Build — 12-Week Initial Block',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-01',
    today: '2026-09-10',
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    occurrences: [
      session(
        id: 'occ-complete',
        date: '2026-09-07',
        state: FixedProgrammeOccurrenceState.completed,
        title: 'Apollo Strength',
        type: 'Strength · Gym',
      ),
      session(
        id: 'occ-incomplete',
        date: '2026-09-08',
        state: FixedProgrammeOccurrenceState.overdue,
        title: 'Apollo Intervals',
        type: 'Run',
      ),
      session(
        id: 'occ-zone2',
        date: '2026-09-09',
        state: FixedProgrammeOccurrenceState.completed,
        title: 'Zone 2 Run',
        type: 'Endurance',
      ),
      session(
        id: 'occ-today-a',
        date: '2026-09-10',
        state: FixedProgrammeOccurrenceState.today,
        title: 'Apollo Strength',
        type: 'Strength · Gym',
      ),
      session(
        id: 'occ-today-b',
        date: '2026-09-10',
        state: FixedProgrammeOccurrenceState.planned,
        title: 'Evening Mobility Flow With Extended Recovery Notes',
        type: 'Recovery',
        order: 2,
      ),
      session(
        id: 'occ-interval',
        date: '2026-09-11',
        state: FixedProgrammeOccurrenceState.planned,
        title: 'Interval Run',
        type: 'Run',
      ),
      session(
        id: 'occ-mobility',
        date: '2026-09-12',
        state: FixedProgrammeOccurrenceState.planned,
        title: 'Mobility',
        type: 'Recovery',
      ),
    ],
    currentWeek: const [],
  );
}
