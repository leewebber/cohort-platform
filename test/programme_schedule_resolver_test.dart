import 'package:cohort_platform/features/programme/errors/programme_schedule_exception.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_resolution.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';
import 'support/programme_schedule_test_fixtures.dart';

void main() {
  const resolver = ProgrammeScheduleResolverImpl();

  group('ProgrammeScheduleResolverImpl', () {
    test('returns first required slot on day_1', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: const [],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.executableSlot);
      expect(resolution.slot?.id, 'slot-1');
      expect(resolution.plannedProtocolId, 'BW-001');
      expect(resolution.effectiveProtocolId, 'BW-001');
      expect(resolution.outcomeStatus, ProgrammeSlotOutcomeStatus.scheduled);
    });

    test('in-progress slot takes priority over next required slot', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-2',
            status: ProgrammeSlotOutcomeStatus.inProgress,
          ),
        ],
      );

      expect(resolution.slot?.id, 'slot-2');
      expect(resolution.outcomeStatus, ProgrammeSlotOutcomeStatus.inProgress);
    });

    test('completed_partial counts as resolved and advances within day', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completedPartial,
          ),
        ],
      );

      expect(resolution.slot?.id, 'slot-2');
    });

    test('multiple required slots stay on same day until all resolved', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
      );

      expect(resolution.weekNumber, 1);
      expect(resolution.dayKey, 'day_1');
      expect(resolution.slot?.id, 'slot-2');
    });

    test('optional slot does not block day advancement', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.optionalSlotDayTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.dayComplete);
      expect(resolution.suggestedNextCursor?.dayKey, 'day_2');
      expect(resolution.optionalUnresolvedSlots, hasLength(1));
    });

    test('advances to next day when all required slots resolved', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.dayComplete);
      expect(resolution.suggestedNextCursor?.dayKey, 'day_2');
      expect(resolution.suggestedNextCursor?.weekNumber, 1);
    });

    test('returns programme complete when final day slots are resolved', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-2',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.programmeComplete);
      expect(resolution.suggestedNextCursor, isNull);
    });

    test('rolls suggested cursor across week boundary', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_4'),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-4',
            status: ProgrammeSlotOutcomeStatus.completed,
            dayKey: 'day_4',
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.dayComplete);
      expect(resolution.suggestedNextCursor?.weekNumber, 2);
      expect(resolution.suggestedNextCursor?.dayKey, 'day_1');
    });

    test('returns rest day without protocol', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_3'),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: const [],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.restDay);
      expect(resolution.effectiveProtocolId, isNull);
      expect(resolution.day?.dayType, ProgrammeDayType.rest);
      expect(resolution.suggestedNextCursor?.dayKey, 'day_4');
    });

    test('replaced outcome maps replacement protocol in resolution DTO', () {
      final assignment = ProgrammeScheduleTestFixtures.assignment();
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      final dayNode = tree.weekNodes.first.sortedDays.first;
      final slot = dayNode.sortedSlots.first;
      final outcome = ProgrammeScheduleTestFixtures.outcome(
        slotId: slot.id,
        status: ProgrammeSlotOutcomeStatus.replaced,
        replacementProtocolId: 'FG-009',
      );

      final resolution = ProgrammeScheduleResolution(
        kind: ProgrammeScheduleResolutionKind.executableSlot,
        assignment: assignment,
        tree: tree,
        weekNumber: 1,
        dayKey: 'day_1',
        day: dayNode.day,
        slot: slot,
        slotOutcome: outcome,
        outcomeStatus: ProgrammeSlotOutcomeStatus.replaced,
        plannedProtocolId: slot.protocolId,
        effectiveProtocolId: 'FG-009',
      );

      final session = ResolvedTodaySession.fromResolution(resolution);

      expect(session.effectiveProtocolId, 'FG-009');
      expect(session.plannedProtocolId, 'BW-001');
    });

    test('unresolved rescheduled slot remains current required slot', () {
      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.rescheduled,
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.executableSlot);
      expect(resolution.slot?.id, 'slot-1');
      expect(resolution.outcomeStatus, ProgrammeSlotOutcomeStatus.rescheduled);
    });

    test('returns programme complete on final day of single-day programme', () {
      final tree = ProgrammeScheduleTestFixtures.singleWeekTree(
        days: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: 'slot-1',
                dayId: 'day-1',
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
            ],
          ),
        ],
      );

      final resolution = resolver.resolve(
        assignment: ProgrammeScheduleTestFixtures.assignment(),
        tree: tree,
        outcomes: [
          ProgrammeScheduleTestFixtures.outcome(
            slotId: 'slot-1',
            status: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
      );

      expect(resolution.kind, ProgrammeScheduleResolutionKind.programmeComplete);
      expect(resolution.suggestedNextCursor, isNull);
    });

    test('throws for missing week', () {
      expect(
        () => resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(week: 99),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (error) => error.code,
            'code',
            ProgrammeScheduleErrorCode.missingCurrentWeek,
          ),
        ),
      );
    });

    test('throws for missing day', () {
      expect(
        () => resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_99'),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (error) => error.code,
            'code',
            ProgrammeScheduleErrorCode.missingCurrentDay,
          ),
        ),
      );
    });

    test('throws for malformed cursor', () {
      final assignment = ProgrammeAssignment(
        id: 'assignment-1',
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
        currentDayKey: 'monday',
      );

      expect(
        () => resolver.resolve(
          assignment: assignment,
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (error) => error.code,
            'code',
            ProgrammeScheduleErrorCode.malformedAssignmentCursor,
          ),
        ),
      );
    });

    test('throws for duplicate day key', () {
      final tree = ProgrammeScheduleTestFixtures.singleWeekTree(
        days: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: 'slot-1',
                dayId: 'day-1',
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
            ],
          ),
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-1b',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 2,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: 'slot-2',
                dayId: 'day-1b',
                sessionOrder: 1,
                protocolId: 'RN-006',
              ),
            ],
          ),
        ],
      );

      expect(
        () => resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: tree,
          outcomes: const [],
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (error) => error.code,
            'code',
            ProgrammeScheduleErrorCode.duplicateDayKey,
          ),
        ),
      );
    });

    test('throws for duplicate slot order', () {
      final tree = ProgrammeScheduleTestFixtures.singleWeekTree(
        days: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: 'slot-1',
                dayId: 'day-1',
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: 'slot-2',
                dayId: 'day-1',
                sessionOrder: 1,
                protocolId: 'RN-006',
              ),
            ],
          ),
        ],
      );

      expect(
        () => resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: tree,
          outcomes: const [],
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (error) => error.code,
            'code',
            ProgrammeScheduleErrorCode.duplicateSlotOrder,
          ),
        ),
      );
    });

    test('does not mutate assignment during resolve', () {
      final assignment = ProgrammeScheduleTestFixtures.assignment();
      final beforeWeek = assignment.currentWeek;
      final beforeDay = assignment.currentDayKey;
      final beforeSlot = assignment.currentSessionOrder;

      resolver.resolve(
        assignment: assignment,
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        outcomes: const [],
      );

      expect(assignment.currentWeek, beforeWeek);
      expect(assignment.currentDayKey, beforeDay);
      expect(assignment.currentSessionOrder, beforeSlot);
    });

    test('resolveInitialCursor returns first required slot on flat programme', () {
      final cursor = resolver.resolveInitialCursor(
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );

      expect(cursor.weekNumber, 1);
      expect(cursor.dayKey, 'day_1');
      expect(cursor.slotOrder, 1);
    });

    test('resolveInitialCursor returns rest day when programme begins with rest', () {
      final cursor = resolver.resolveInitialCursor(
        tree: ProgrammeScheduleTestFixtures.singleWeekTree(
          days: [
            ProgrammeScheduleTestFixtures.restDay(
              id: 'day-1',
              weekId: 'week-1',
              dayKey: 'day_1',
              dayOrder: 1,
            ),
            ProgrammeScheduleTestFixtures.trainingDay(
              id: 'day-2',
              weekId: 'week-1',
              dayKey: 'day_2',
              dayOrder: 2,
              slots: [
                ProgrammeScheduleTestFixtures.requiredSlot(
                  id: 'slot-2',
                  dayId: 'day-2',
                  sessionOrder: 1,
                  protocolId: 'RN-006',
                ),
              ],
            ),
          ],
        ),
      );

      expect(cursor.dayKey, 'day_1');
      expect(cursor.slotOrder, 1);
    });

    test('resolveInitialCursor does not assume week 1 exists', () {
      final weekTwo = ProgrammeVersionWeek(
        id: 'week-2',
        versionId: 'version-1',
        weekNumber: 2,
      );
      final day = ProgrammeScheduleTestFixtures.trainingDay(
        id: 'day-10',
        weekId: 'week-2',
        dayKey: 'day_1',
        dayOrder: 1,
        slots: [
          ProgrammeScheduleTestFixtures.requiredSlot(
            id: 'slot-10',
            dayId: 'day-10',
            sessionOrder: 3,
            protocolId: 'FG-009',
          ),
        ],
      );
      final tree = ProgrammeTemplateTree(
        template: ProgrammeTemplate(
          version: ProgrammeScheduleTestFixtures.version(),
          weeks: [weekTwo],
        ),
        weekNodes: [ProgrammeTemplateWeekNode(week: weekTwo, days: [day])],
      );

      final cursor = resolver.resolveInitialCursor(tree: tree);

      expect(cursor.weekNumber, 2);
      expect(cursor.slotOrder, 3);
    });
  });

  group('TodaySessionServiceImpl', () {
    test('returns no active programme when assignment missing', () async {
      final tables = InMemoryProgrammeTables();
      final service = TodaySessionServiceImpl(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        scheduleResolver: resolver,
      );

      final result = await service.resolveForAthlete('lee');

      expect(result.kind, ResolvedTodaySessionKind.noActiveProgramme);
    });

    test('resolves first required slot for active assignment', () async {
      final tables = InMemoryProgrammeTables();
      final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree();
      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: tree,
      );
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      final service = TodaySessionServiceImpl(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        scheduleResolver: resolver,
      );

      final result = await service.resolveForAthlete('lee');

      expect(result.kind, ResolvedTodaySessionKind.executable);
      expect(result.effectiveProtocolId, 'BW-001');
      expect(result.lineageCode, 'COHORT-FOUNDATION-TEST');
    });
  });

  group('AthleteStateSyncServiceImpl', () {
    test('projects executable session into athlete_state', () async {
      final tables = InMemoryProgrammeTables();
      final service = AthleteStateSyncServiceImpl(
        athleteStateStore: InMemoryAthleteStateStore(tables),
      );

      final resolution = ResolvedTodaySession.fromResolution(
        resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      await service.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      final state = tables.athleteStates.first;
      expect(state.programmeId, 'COHORT-FOUNDATION-TEST');
      expect(state.currentWeek, 1);
      expect(state.currentDay, 'day_1');
      expect(state.currentProtocolId, 'BW-001');
      expect(state.sessionStatus, 'scheduled');
    });

    test('clears protocol projection on rest day', () async {
      final tables = InMemoryProgrammeTables()
        ..athleteStates.add(
          const AthleteState(
            athleteId: 'lee',
            programmeId: 'OLD',
            currentWeek: 1,
            currentDay: 'day_1',
            currentProtocolId: 'BW-001',
            sessionStatus: 'in_progress',
          ),
        );
      final service = AthleteStateSyncServiceImpl(
        athleteStateStore: InMemoryAthleteStateStore(tables),
      );

      final resolution = ResolvedTodaySession.fromResolution(
        resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_3'),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      await service.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      final state = tables.athleteStates.first;
      expect(state.programmeId, 'COHORT-FOUNDATION-TEST');
      expect(state.currentDay, 'day_3');
      expect(state.currentProtocolId, isNull);
      expect(state.sessionStatus, isNull);
    });

    test('clears protocol projection on programme complete', () async {
      final tables = InMemoryProgrammeTables()
        ..athleteStates.add(
          const AthleteState(
            athleteId: 'lee',
            programmeId: 'COHORT-FOUNDATION-TEST',
            currentWeek: 1,
            currentDay: 'day_1',
            currentProtocolId: 'BW-001',
            sessionStatus: 'completed',
          ),
        );
      final service = AthleteStateSyncServiceImpl(
        athleteStateStore: InMemoryAthleteStateStore(tables),
      );

      final resolution = ResolvedTodaySession.fromResolution(
        resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.twoSlotDayTree(),
          outcomes: [
            ProgrammeScheduleTestFixtures.outcome(
              slotId: 'slot-1',
              status: ProgrammeSlotOutcomeStatus.completed,
            ),
            ProgrammeScheduleTestFixtures.outcome(
              slotId: 'slot-2',
              status: ProgrammeSlotOutcomeStatus.completed,
            ),
          ],
        ),
      );

      await service.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      final state = tables.athleteStates.first;
      expect(state.programmeId, 'COHORT-FOUNDATION-TEST');
      expect(state.currentProtocolId, isNull);
      expect(state.sessionStatus, isNull);
    });

    test('sync is idempotent', () async {
      final tables = InMemoryProgrammeTables();
      final service = AthleteStateSyncServiceImpl(
        athleteStateStore: InMemoryAthleteStateStore(tables),
      );
      final resolution = ResolvedTodaySession.fromResolution(
        resolver.resolve(
          assignment: ProgrammeScheduleTestFixtures.assignment(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
          outcomes: const [],
        ),
      );

      await service.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );
      await service.syncFromResolvedSession(
        athleteId: 'lee',
        resolution: resolution,
      );

      expect(tables.athleteStates, hasLength(1));
    });
  });
}
