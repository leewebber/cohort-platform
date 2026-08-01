import 'package:cohort_platform/features/programme/services/athlete_programme_authored_cursor_traversal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_schedule_test_fixtures.dart';

void main() {
  const traversal = AthleteProgrammeAuthoredCursorTraversal();

  AuthoredProgrammeCursor cursor({
    required int week,
    required String day,
    required int slot,
  }) => AuthoredProgrammeCursor(weekNumber: week, dayKey: day, slotOrder: slot);

  group('AthleteProgrammeAuthoredCursorTraversal', () {
    test('returns the next slot within the same authored day', () {
      final next = traversal.nextExecutableSlot(
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        current: cursor(week: 1, day: 'day_1', slot: 1),
      );

      expect(next?.weekNumber, 1);
      expect(next?.dayKey, 'day_1');
      expect(next?.slotOrder, 2);
      expect(next?.sessionSlotId, ProgrammeScheduleTestFixtures.slot2Id);
    });

    test('returns the first slot on the next authored day', () {
      final next = traversal.nextExecutableSlot(
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        current: cursor(week: 1, day: 'day_1', slot: 1),
      );

      expect(next?.weekNumber, 1);
      expect(next?.dayKey, 'day_2');
      expect(next?.slotOrder, 1);
      expect(next?.sessionSlotId, ProgrammeScheduleTestFixtures.slot2Id);
    });

    test('returns the first slot of the next authored week', () {
      final next = traversal.nextExecutableSlot(
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        current: cursor(week: 1, day: 'day_4', slot: 1),
      );

      expect(next?.weekNumber, 2);
      expect(next?.dayKey, 'day_1');
      expect(next?.slotOrder, 1);
      expect(next?.sessionSlotId, ProgrammeScheduleTestFixtures.slot5Id);
    });

    test(
      'retains package-authored day ordering instead of day-key ordering',
      () {
        final tree = ProgrammeScheduleTestFixtures.singleWeekTree(
          days: [
            ProgrammeScheduleTestFixtures.trainingDay(
              id: ProgrammeScheduleTestFixtures.day2Id,
              weekId: ProgrammeScheduleTestFixtures.week1Id,
              dayKey: 'day_20',
              dayOrder: 1,
              slots: [
                ProgrammeScheduleTestFixtures.requiredSlot(
                  id: ProgrammeScheduleTestFixtures.slot1Id,
                  dayId: ProgrammeScheduleTestFixtures.day2Id,
                  sessionOrder: 1,
                  protocolId: 'BW-001',
                ),
              ],
            ),
            ProgrammeScheduleTestFixtures.trainingDay(
              id: ProgrammeScheduleTestFixtures.day1Id,
              weekId: ProgrammeScheduleTestFixtures.week1Id,
              dayKey: 'day_3',
              dayOrder: 2,
              slots: [
                ProgrammeScheduleTestFixtures.requiredSlot(
                  id: ProgrammeScheduleTestFixtures.slot2Id,
                  dayId: ProgrammeScheduleTestFixtures.day1Id,
                  sessionOrder: 1,
                  protocolId: 'RN-006',
                ),
              ],
            ),
          ],
        );

        final next = traversal.nextExecutableSlot(
          tree: tree,
          current: cursor(week: 1, day: 'day_20', slot: 1),
        );

        expect(next?.dayKey, 'day_3');
      },
    );

    test('throws for an invalid current cursor', () {
      expect(
        () => traversal.nextExecutableSlot(
          tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
          current: cursor(week: 1, day: 'day_1', slot: 99),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('returns null from the terminal authored slot', () {
      final next = traversal.nextExecutableSlot(
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        current: cursor(week: 1, day: 'day_1', slot: 2),
      );

      expect(next, isNull);
    });
  });
}
