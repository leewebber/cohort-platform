import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/features/programme/services/programme_progress_summary_service.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import '../support/programme_schedule_test_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ProgrammeProgressSummaryService();

  group('ProgrammeProgressSummaryService', () {
    test('counts required sessions and terminal outcomes', () {
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final outcomes = [
        ProgrammeSlotOutcome(
          id: 'outcome-1',
          assignmentId: 'assignment-1',
          sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
        ),
        ProgrammeSlotOutcome(
          id: 'outcome-2',
          assignmentId: 'assignment-1',
          sessionSlotId: ProgrammeScheduleTestFixtures.slot2Id,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.inProgress,
        ),
      ];

      final summary = service.summarize(
        tree: tree,
        outcomes: outcomes,
        currentWeek: 1,
      );

      expect(summary, isNotNull);
      expect(summary!.totalWeeks, 2);
      expect(summary.currentWeek, 1);
      expect(summary.totalSessions, 4);
      expect(summary.completedSessions, 1);
      expect(summary.displayLabel, 'Week 1 of 2 • 1 / 4 sessions completed');
    });

    test('returns null when template has no required sessions', () {
      final tree = ProgrammeTemplateTree(
        template: ProgrammeScheduleTestFixtures.singleWeekTree(days: [
          ProgrammeScheduleTestFixtures.restDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
          ),
        ]).template,
        weekNodes: ProgrammeScheduleTestFixtures.singleWeekTree(days: [
          ProgrammeScheduleTestFixtures.restDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
          ),
        ]).weekNodes,
      );

      final summary = service.summarize(
        tree: tree,
        outcomes: const [],
        currentWeek: 1,
      );

      expect(summary, isNull);
    });
  });
}
