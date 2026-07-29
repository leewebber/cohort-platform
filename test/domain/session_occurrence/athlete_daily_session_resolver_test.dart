import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  const resolver = AthleteDailySessionResolver();
  const factory = ProgrammeSessionOccurrenceFactory();
  final date = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 8, 1));
  final t0 = DateTime.utc(2026, 7, 28, 8);

  late ProgrammeSessionOccurrenceRegistry registry;
  late AthleteSessionOccurrenceIndex index;

  setUp(() {
    registry = InMemoryProgrammeSessionOccurrenceRegistry();
    index = AthleteSessionOccurrenceIndex();
  });

  SessionOccurrence _materialize({
    String athleteId = 'athlete-1',
    String slotId = 'slot-1',
    String protocolId = 'proto-1',
  }) {
    final result = factory.createFromScheduledSlot(
      input: ProgrammeScheduledSlotInput(
        programmeAssignmentId: 'asgn-1',
        programmeSessionSlotId: slotId,
        athleteId: athleteId,
        sourceSessionId: protocolId,
        plannedDate: date,
      ),
      recordedAt: t0,
      registry: registry,
      occurrenceRepository: index,
    );
    return result.occurrence!;
  }

  group('AthleteDailySessionResolver', () {
    test('no session scheduled returns explicit outcome', () {
      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.noSessionScheduled,
      );
      expect(result.hasSingleOccurrence, isFalse);
    });

    test('session planned when occurrence is scheduled', () {
      _materialize();
      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.sessionPlanned,
      );
      expect(result.occurrence!.occurrenceId, startsWith('pso:'));
    });

    test('adapted session returns snapshot reference', () {
      final draft = buildTimedPlanningSession(protocolId: 'proto-1');
      final snapshot = applyTimedSessionPlan(
        draft: draft,
        constraints: const AdaptationConstraintContext(
          availableDurationMin: 55,
        ),
        input: timedPlanningInputFromDraft(draft),
      ).snapshot!;
      final scheduled = _materialize();
      final adapted = scheduled
          .attachAdaptation(executionSnapshot: snapshot, recordedAt: t0)
          .occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: adapted);

      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.sessionAdapted,
      );
      expect(result.hasExecutionSnapshot, isTrue);
    });

    test('completed session outcome', () {
      final occurrence = _materialize()
          .startInProgress(recordedAt: t0)
          .occurrence!
          .complete(completedAt: t0)
          .occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: occurrence);

      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.sessionCompleted,
      );
    });

    test('skipped session outcome', () {
      final occurrence = _materialize().skip(recordedAt: t0).occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: occurrence);

      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.sessionSkipped,
      );
    });

    test('cancelled session outcome', () {
      final occurrence = _materialize().cancel(recordedAt: t0).occurrence!;
      index.upsert(athleteId: 'athlete-1', occurrence: occurrence);

      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.sessionCancelled,
      );
    });

    test('invalid lookup for empty athlete id', () {
      final result = resolver.resolve(
        athleteId: '  ',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.invalidLookup,
      );
    });

    test('multiple sessions on same day reported explicitly', () {
      _materialize(slotId: 'slot-a');
      _materialize(slotId: 'slot-b');
      final result = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.multipleSessionsScheduled,
      );
      expect(result.matchingOccurrences.length, 2);
      expect(result.occurrence, isNull);
    });

    test('deterministic resolution for identical inputs', () {
      _materialize();
      final a = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      final b = resolver.resolve(
        athleteId: 'athlete-1',
        date: date,
        occurrenceRepository: index,
      );
      expect(a, equals(b));
    });

    test('does not match different athlete on same date', () {
      _materialize(athleteId: 'athlete-1');
      final result = resolver.resolve(
        athleteId: 'athlete-2',
        date: date,
        occurrenceRepository: index,
      );
      expect(
        result.outcome,
        AthleteDailySessionResolutionOutcome.noSessionScheduled,
      );
    });

    test('factory registers into athlete index when provided', () {
      _materialize();
      expect(
        index
            .occurrencesOnDay(athleteId: 'athlete-1', calendarDate: date)
            .length,
        1,
      );
    });
  });
}
