import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/widgets/fixed_programme_week_view.dart';
import 'package:flutter/material.dart';

/// Local in-memory preview for incomplete-session surfaces.
///
/// Does not contact hosted Supabase, mutate production data, or install over
/// Lee's device build.
///
/// Launch:
///   flutter run -d web-server --web-port 4174 -t lib/main_overdue_recovery_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const _IncompleteSessionPreview()),
  );
}

class _IncompleteSessionPreview extends StatelessWidget {
  const _IncompleteSessionPreview();

  @override
  Widget build(BuildContext context) {
    final today = DateTime(2026, 9, 10);
    final tuesday = DateTime(2026, 9, 8);
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
                  child: Text(
                    'Apollo Strength',
                    style: CohortTextStyles.cardTitle,
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: IncompleteSessionAthleteCopy.countPhrase(1),
                  child: Text(
                    IncompleteSessionAthleteCopy.sectionHeading(1),
                    style: CohortTextStyles.sectionLabel,
                  ),
                ),
                const SizedBox(height: 8),
                CohortCard(
                  onTap: () {},
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apollo Intervals',
                              style: CohortTextStyles.cardTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              IncompleteSessionAthleteCopy.scheduledLine(
                                tuesday,
                              ),
                              style: CohortTextStyles.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              IncompleteSessionAthleteCopy.statusLabel,
                              style: CohortTextStyles.small,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FixedProgrammeWeekView(presentation: week, onDayTap: (_) {}),
                const SizedBox(height: 28),
                const Text(
                  'SCHEDULED SESSION',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: 8),
                Text('Apollo Intervals', style: CohortTextStyles.h1),
                const SizedBox(height: 12),
                CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        IncompleteSessionAthleteCopy.statusLabel,
                        style: CohortTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        IncompleteSessionAthleteCopy.scheduledForLine(tuesday),
                        style: CohortTextStyles.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        IncompleteSessionAthleteCopy.stillCompletable,
                        style: CohortTextStyles.body,
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      const CohortButton(
                        label: IncompleteSessionAthleteCopy.doThisSession,
                        onPressed: null,
                      ),
                      const SizedBox(height: 8),
                      const CohortButton(
                        label: 'Reschedule',
                        variant: CohortButtonVariant.secondary,
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                CohortCard(
                  child: Text(
                    IncompleteSessionAthleteCopy.completedLater(
                      scheduled: tuesday,
                      completed: today,
                    ),
                    style: CohortTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
