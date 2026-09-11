import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/widgets/fixed_programme_week_view.dart';
import 'package:flutter/material.dart';

/// Local in-memory preview for overdue recovery surfaces.
///
/// Does not contact hosted Supabase, mutate production data, or install over
/// Lee's device build.
///
/// Launch:
///   flutter run -d web-server --web-port 4174 -t lib/main_overdue_recovery_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const _OverdueRecoveryPreview()),
  );
}

class _OverdueRecoveryPreview extends StatelessWidget {
  const _OverdueRecoveryPreview();

  @override
  Widget build(BuildContext context) {
    final today = DateTime(2026, 9, 10);
    final tuesday = DateTime(2026, 9, 8);
    final friday = DateTime(2026, 9, 11);
    final week = AthleteProgrammeWeekPresentation(
      heading: 'THIS WEEK',
      dateRangeLabel: '8–14 September',
      days: [
        for (var i = 0; i < 7; i++)
          AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 8).add(Duration(days: i)),
            state: i == 0
                ? FixedProgrammeOccurrenceState.overdue
                : i == 2
                ? FixedProgrammeOccurrenceState.today
                : FixedProgrammeOccurrenceState.rest,
            occurrence: i == 0 || i == 2
                ? FixedProgrammeOccurrenceProjection(
                    assignmentId: 'preview',
                    occurrenceId: 'occ-$i',
                    sessionSlotId: 'slot-$i',
                    programmeVersionId: 'version',
                    protocolId: 'APOLLO',
                    programmedSessionKey: 'preview-$i',
                    weekNumber: 1,
                    dayKey: 'day_${i + 1}',
                    sessionOrder: 1,
                    scheduledDate: DateTime(
                      2026,
                      9,
                      8,
                    ).add(Duration(days: i)).toIso8601String().substring(0, 10),
                    originalScheduledDate: DateTime(
                      2026,
                      9,
                      8,
                    ).add(Duration(days: i)).toIso8601String().substring(0, 10),
                    state: i == 0
                        ? FixedProgrammeOccurrenceState.overdue
                        : FixedProgrammeOccurrenceState.today,
                    sessionTitle: i == 0
                        ? 'Apollo Intervals'
                        : 'Apollo Strength',
                  )
                : null,
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Overdue recovery preview')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Calendar · overdue remains tappable'),
                const SizedBox(height: 12),
                FixedProgrammeWeekView(presentation: week, onDayTap: (_) {}),
                const SizedBox(height: 28),
                const Text('TODAY', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: 8),
                const CohortCard(child: Text('Apollo Strength · Today')),
                const SizedBox(height: 20),
                const Text(
                  '1 SESSION TO RESOLVE',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: 8),
                CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apollo Intervals',
                        style: CohortTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Overdue · ${AthleteProgrammeDateFormatter.dayMonth(tuesday)}',
                        style: CohortTextStyles.muted,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: const [
                          Text('Train now'),
                          Text('Reschedule'),
                          Text('Skip'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Late-session confirmation'),
                const SizedBox(height: 8),
                CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled for ${AthleteProgrammeDateFormatter.weekdayDayMonth(tuesday)}',
                        style: CohortTextStyles.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Training today, ${AthleteProgrammeDateFormatter.weekdayDayMonth(today)}',
                        style: CohortTextStyles.body,
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      const Text('Start Tuesday’s session now?'),
                      const Text(
                        'Your Thursday session will remain scheduled.',
                      ),
                      const SizedBox(height: 12),
                      const CohortButton(
                        label: 'Start this session',
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Move-to-date'),
                const SizedBox(height: 8),
                CohortCard(
                  child: Text(
                    'Move Apollo Intervals from Tuesday 8 Sep to Friday 11 Sep?',
                    style: CohortTextStyles.body,
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Swap confirmation'),
                const SizedBox(height: 8),
                const CohortCard(
                  child: Text(
                    'Swap:\nTuesday — Apollo Intervals\nFriday — Apollo Strength?',
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Completed late'),
                const SizedBox(height: 8),
                CohortCard(
                  child: Text(
                    'Scheduled ${AthleteProgrammeDateFormatter.shortDayMonth(tuesday)} · '
                    'Completed ${AthleteProgrammeDateFormatter.shortDayMonth(today)}',
                    style: CohortTextStyles.body,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Friday ${AthleteProgrammeDateFormatter.shortDayMonth(friday)} remains available for reschedule.',
                  style: CohortTextStyles.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
