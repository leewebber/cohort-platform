import 'package:cohort_platform/features/coach_operations/services/coach_compliance_summary_service.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_schedule_test_fixtures.dart';

void main() {
  const service = CoachComplianceSummaryService();

  group('CoachComplianceSummaryService', () {
    test('returns On Track when cursor slots are complete', () {
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final assignment = ProgrammeScheduleTestFixtures.assignment(
        week: 1,
        dayKey: 'day_2',
        slotOrder: 1,
      );
      final outcomes = [
        ProgrammeScheduleTestFixtures.outcome(
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          status: ProgrammeSlotOutcomeStatus.completed,
          dayKey: 'day_1',
        ),
      ];
      final resolution = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        assignment: assignment,
        weekNumber: 1,
        dayKey: 'day_2',
      );

      final result = service.summarize(
        tree: tree,
        outcomes: outcomes,
        assignment: assignment,
        resolution: resolution,
      );

      expect(result.label, 'On Track');
      expect(result.sessionsBehind, 0);
      expect(result.needsAttention, isFalse);
    });

    test('counts sessions behind before cursor', () {
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final assignment = ProgrammeScheduleTestFixtures.assignment(
        week: 1,
        dayKey: 'day_4',
        slotOrder: 1,
      );
      final outcomes = [
        ProgrammeScheduleTestFixtures.outcome(
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          status: ProgrammeSlotOutcomeStatus.completed,
          dayKey: 'day_1',
        ),
      ];
      final resolution = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        assignment: assignment,
        weekNumber: 1,
        dayKey: 'day_4',
      );

      final result = service.summarize(
        tree: tree,
        outcomes: outcomes,
        assignment: assignment,
        resolution: resolution,
      );

      expect(result.label, '1 Session Behind');
      expect(result.sessionsBehind, 1);
      expect(result.needsAttention, isTrue);
    });

    test('returns Completed Today for day complete resolution', () {
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final assignment = ProgrammeScheduleTestFixtures.assignment(
        week: 1,
        dayKey: 'day_1',
        slotOrder: 1,
      );
      final resolution = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.dayComplete,
        assignment: assignment,
        weekNumber: 1,
        dayKey: 'day_1',
      );

      final result = service.summarize(
        tree: tree,
        outcomes: const [],
        assignment: assignment,
        resolution: resolution,
        referenceTime: DateTime.utc(2026, 7, 22, 12),
      );

      expect(result.label, 'Completed Today');
      expect(result.completedToday, isTrue);
    });

    test('returns Completed Today when terminal outcome resolved today', () {
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final assignment = ProgrammeScheduleTestFixtures.assignment();
      final today = DateTime.utc(2026, 7, 22, 8);
      final outcomes = [
        ProgrammeSlotOutcome(
          id: 'outcome-1',
          assignmentId: assignment.id,
          sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
          resolvedAt: today,
        ),
      ];
      final resolution = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.executable,
        assignment: assignment,
        weekNumber: 1,
        dayKey: 'day_2',
      );

      final result = service.summarize(
        tree: tree,
        outcomes: outcomes,
        assignment: assignment,
        resolution: resolution,
        referenceTime: today.add(const Duration(hours: 4)),
      );

      expect(result.label, 'Completed Today');
      expect(result.completedToday, isTrue);
    });
  });
}
