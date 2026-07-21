import 'package:cohort_platform/data/repositories/programme_adaptation_event_supabase_store.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_execution_service.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

void main() {
  group('AdaptationExecutionService', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeAdaptationEventStore adaptationEvents;
    late AdaptationExecutionService service;

    const slot1Id = '00000000-0000-4000-8000-000000000001';
    const slot2Id = '00000000-0000-4000-8000-000000000002';
    const slot5Id = '00000000-0000-4000-8000-000000000005';

    ProgrammeExecutionContext contextForSlot({
      required String slotId,
      required int week,
      required String dayKey,
      required int order,
    }) {
      return ProgrammeExecutionContext(
        assignmentId: 'assignment-1',
        programmeVersionId: 'version-1',
        sessionSlotId: slotId,
        weekNumber: week,
        dayKey: dayKey,
        sessionOrder: order,
        plannedProtocolId: 'BW-001',
        effectiveProtocolId: 'BW-001',
      );
    }

    TrainingSessionRecord strengthCompletionRecord() {
      return TrainingSessionRecord(
        recordId: 'record-1',
        athleteId: 'lee',
        status: TrainingSessionRecordStatus.completed,
        sessionSnapshot: const SessionPerformanceSnapshot(
          sourceProtocolId: 'BW-001',
          sessionTitle: 'Strength',
        ),
        startedAt: DateTime.utc(2026, 7, 1),
        blockResults: [
          TrainingBlockResult(
            blockResultId: 'block-1',
            sessionRecordId: 'record-1',
            sourceBlockId: 'source-block-1',
            blockSnapshot: BlockPerformanceSnapshot(
              sourceBlockId: 'source-block-1',
              title: 'Squat',
              blockType: SessionBlockType.strength,
              content: 'Sets: 2',
              workoutFormat: WorkoutFormat.none,
              position: 1,
            ),
            status: TrainingBlockResultStatus.completed,
            resultType: PerformanceResultType.strength,
            position: 1,
            resultData: const StrengthResultData(),
            exerciseResults: [
              TrainingExerciseResult(
                exerciseResultId: 'exercise-result-1',
                blockResultId: 'block-1',
                sourceExerciseId: 'squat-001',
                exerciseSnapshot: const ExercisePerformanceSnapshot(
                  sourceExerciseId: 'squat-001',
                  displayName: 'Back Squat',
                  position: 1,
                ),
                position: 1,
                setResults: const [
                  TrainingSetResult(
                    setResultId: 'set-1',
                    exerciseResultId: 'exercise-result-1',
                    setNumber: 1,
                    position: 1,
                    reps: 8,
                    load: 60,
                    loadUnit: 'kg',
                    completed: true,
                  ),
                  TrainingSetResult(
                    setResultId: 'set-2',
                    exerciseResultId: 'exercise-result-1',
                    setNumber: 2,
                    position: 2,
                    reps: 8,
                    load: 60,
                    loadUnit: 'kg',
                    completed: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    setUp(() async {
      tables = InMemoryProgrammeTables();
      adaptationEvents = InMemoryProgrammeAdaptationEventStore([]);

      final tree = ProgrammeScheduleTestFixtures.twoWeekTree(
        weekOneDays: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-1',
            weekId: 'week-1',
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: slot1Id,
                dayId: 'day-1',
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
            ],
          ),
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-2',
            weekId: 'week-1',
            dayKey: 'day_2',
            dayOrder: 2,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: slot2Id,
                dayId: 'day-2',
                sessionOrder: 1,
                protocolId: 'BW-001',
              ),
            ],
          ),
        ],
        weekTwoDays: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: 'day-5',
            weekId: 'week-2',
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: slot5Id,
                dayId: 'day-5',
                sessionOrder: 1,
                protocolId: 'BW-001',
                displayTitle: 'Strength repeat',
              ),
            ],
          ),
        ],
      );

      await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: tree,
      );
      tables.assignments.add(ProgrammeScheduleTestFixtures.assignment());

      tables.outcomes.add(
        ProgrammeSlotOutcome(
          id: 'prior-outcome',
          assignmentId: 'assignment-1',
          sessionSlotId: slot2Id,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
        ),
      );

      service = AdaptationExecutionService(
        adaptationEventStore: adaptationEvents,
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
      );
    });

    test('applies load progression to a future slot', () async {
      final result = await service.executeAfterSessionCompletion(
        athleteId: 'lee',
        record: strengthCompletionRecord(),
        programmeContext: contextForSlot(
          slotId: slot1Id,
          week: 1,
          dayKey: 'day_1',
          order: 1,
        ),
        trainingSessionId: 9001,
        endedEarly: false,
      );

      expect(result.applied, isTrue);
      expect(result.event, isNotNull);
      expect(adaptationEvents.events, hasLength(1));

      final futureOutcome = tables.outcomes.firstWhere(
        (outcome) => outcome.sessionSlotId == slot5Id,
      );
      expect(futureOutcome.outcomeStatus, ProgrammeSlotOutcomeStatus.scheduled);
      expect(futureOutcome.resolutionNote, contains('Progression rule'));
    });

    test('duplicate completion is idempotent', () async {
      await service.executeAfterSessionCompletion(
        athleteId: 'lee',
        record: strengthCompletionRecord(),
        programmeContext: contextForSlot(
          slotId: slot1Id,
          week: 1,
          dayKey: 'day_1',
          order: 1,
        ),
        trainingSessionId: 9002,
        endedEarly: false,
      );

      final second = await service.executeAfterSessionCompletion(
        athleteId: 'lee',
        record: strengthCompletionRecord(),
        programmeContext: contextForSlot(
          slotId: slot1Id,
          week: 1,
          dayKey: 'day_1',
          order: 1,
        ),
        trainingSessionId: 9002,
        endedEarly: false,
      );

      expect(second.applied, isTrue);
      expect(adaptationEvents.events, hasLength(1));
    });

    test('skips when no adaptation rules match', () async {
      final result = await service.executeAfterSessionCompletion(
        athleteId: 'lee',
        record: TrainingSessionRecord(
          recordId: 'record-2',
          athleteId: 'lee',
          status: TrainingSessionRecordStatus.completed,
          sessionSnapshot: const SessionPerformanceSnapshot(
            sourceProtocolId: 'BW-001',
            sessionTitle: 'Strength',
          ),
          startedAt: DateTime.utc(2026, 7, 1),
        ),
        programmeContext: contextForSlot(
          slotId: slot1Id,
          week: 1,
          dayKey: 'day_1',
          order: 1,
        ),
        trainingSessionId: 9003,
        endedEarly: false,
      );

      expect(result.applied, isFalse);
      expect(result.athleteMessage, 'Programme continues as planned.');
    });

    test('completed slot outcome remains terminal', () async {
      tables.outcomes.add(
        ProgrammeSlotOutcome(
          id: 'completed-slot',
          assignmentId: 'assignment-1',
          sessionSlotId: slot1Id,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
          trainingSessionId: 9004,
        ),
      );

      await service.executeAfterSessionCompletion(
        athleteId: 'lee',
        record: strengthCompletionRecord(),
        programmeContext: contextForSlot(
          slotId: slot1Id,
          week: 1,
          dayKey: 'day_1',
          order: 1,
        ),
        trainingSessionId: 9004,
        endedEarly: false,
      );

      final completed = tables.outcomes.firstWhere(
        (outcome) => outcome.sessionSlotId == slot1Id,
      );
      expect(completed.outcomeStatus, ProgrammeSlotOutcomeStatus.completed);
    });
  });
}
