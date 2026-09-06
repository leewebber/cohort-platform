import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/circuit_round_actual.dart';
import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/circuit_result_comparison.dart';
import 'package:cohort_platform/features/performance/services/circuit_set_sync.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/widgets/circuit_capture_editor.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionExecutionPlan _w1Athletic() {
  return SessionExecutionPlan(
    sessionId: 'APOLLO-W1-SAT-R1',
    sessionTitle: 'Apollo Athletic',
    blocks: [
      SessionExecutionBlock(
        blockId: 'b1100016-0000-4000-8000-000000000016',
        title: 'Alternating EMOM',
        blockType: SessionBlockType.conditioning,
        content: 'Minute 1: RowErg 12 calories. Minute 2: Burpees 8 reps.',
        workoutFormat: WorkoutFormat.emom,
        position: 1,
        timerConfiguration: TimerConfiguration.fromJson({
          'duration_seconds': 480,
          'interval_seconds': 60,
          'alternating': [
            {'minute': 1, 'exercise': 'EX-049', 'calories': 12},
            {'minute': 2, 'exercise': 'EX-009', 'reps': 8},
          ],
        }),
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-049',
            displayName: 'RowErg',
            position: 1,
            prescription: StrengthExercisePrescription.fromJson({
              'calories': 12,
              'minute': 1,
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-009',
            displayName: 'Burpees',
            position: 2,
            prescription: StrengthExercisePrescription.fromJson({
              'reps': 8,
              'minute': 2,
            }),
          ),
        ],
      ),
    ],
  );
}

SessionExecutionPlan _w5Athletic() {
  return SessionExecutionPlan(
    sessionId: 'APOLLO-W5-SAT-R1',
    sessionTitle: 'Apollo Athletic',
    blocks: [
      SessionExecutionBlock(
        blockId: 'b1500016-0000-4000-8000-000000000016',
        title: 'Three-round sled/SkiErg circuit',
        blockType: SessionBlockType.conditioning,
        content: 'Three rounds',
        workoutFormat: WorkoutFormat.rounds,
        position: 1,
        timerConfiguration: TimerConfiguration.fromJson({
          'rounds': 3,
          'between_round_recovery_seconds': 90,
          'round_sequence': ['EX-131', 'EX-132', 'EX-050', 'EX-009'],
          'capture_strategy': 'fixed_work',
        }),
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-131',
            displayName: 'Sled Push',
            position: 1,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 20,
              'round_position': 1,
              'load': {'type': 'athleteSelected'},
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-132',
            displayName: 'Sled Pull',
            position: 2,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 20,
              'round_position': 2,
              'load': {'type': 'athleteSelected'},
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-050',
            displayName: 'SkiErg',
            position: 3,
            prescription: StrengthExercisePrescription.fromJson({
              'distance_m': 250,
              'round_position': 3,
            }),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'EX-009',
            displayName: 'Burpees',
            position: 4,
            prescription: StrengthExercisePrescription.fromJson({
              'reps': 8,
              'round_position': 4,
            }),
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('W1 Athletic authors eight station occurrences not interval counts', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 21,
    );
    final result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    expect(result.stations, hasLength(8));
    expect(result.stations.map((row) => row.stationId).take(2), [
      'EX-049',
      'EX-009',
    ]);
    expect(result.stations.first.primaryMetric, CircuitStationMetric.calories);
    expect(result.stations[1].primaryMetric, CircuitStationMetric.reps);
    expect(controller.draft.blockDrafts.single.exerciseResults, hasLength(2));
    expect(
      controller.draft.blockDrafts.single.exerciseResults
          .expand((exercise) => exercise.sets)
          .length,
      8,
    );
  });

  test('W1 partial capture resume and relaunch keep identities', () async {
    final store = InMemoryPerformanceRecordStore();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 22,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    final firstSetId = controller
        .draft
        .blockDrafts
        .single
        .exerciseResults
        .first
        .sets
        .first
        .setResultId;
    result = result.replaceStation(
      result.stations.first.copyWith(
        calories: 12,
        state: CircuitOccurrenceState.recorded,
      ),
    );
    result = result.replaceStation(
      result.stations[1].copyWith(
        reps: 8,
        state: CircuitOccurrenceState.recorded,
      ),
    );
    controller.updateBlockResultData(blockId, result);
    await store.saveDraft(controller.draft);

    final resumed = await store.getInProgressForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 22,
    );
    final resumedResult =
        resumed!.blockResults.single.resultData as CircuitResultData;
    expect(resumedResult.recordedCount, 2);
    expect(resumedResult.stations.first.calories, 12);
    expect(
      resumed.blockResults.single.exerciseResults.first.setResults.first.setResultId,
      firstSetId,
    );

    controller
      ..updateBlockResultData(
        blockId,
        resumedResult.replaceStation(
          resumedResult.stations[2].copyWith(
            calories: 11,
            state: CircuitOccurrenceState.recorded,
          ),
        ),
      )
      ..markBlockComplete(blockId);
    await store.completeRecord(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final relaunched = await store.getTerminalForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 22,
    );
    final done =
        relaunched!.blockResults.single.resultData as CircuitResultData;
    expect(done.stations.map((row) => row.calories).take(3).toList(), [
      12,
      null,
      11,
    ]);
    expect(
      relaunched.blockResults.single.exerciseResults
          .expand((exercise) => exercise.setResults)
          .map((set) => set.setResultId)
          .toSet()
          .length,
      8,
    );
  });

  test('W5 Athletic authors two load entries and three round timings', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w5Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 23,
    );
    final result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    expect(result.isFixedWork, isTrue);
    expect(result.stations, hasLength(4));
    expect(result.sharedSetup.map((row) => row.stationId), ['EX-131', 'EX-132']);
    expect(result.rounds, hasLength(3));
    expect(result.targetRounds, 3);
    expect(result.stations.any((row) => row.round == 3), isFalse);
  });

  test('farmer-carry distance persists on strength sets', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: SessionExecutionPlan(
        sessionId: 'carry',
        sessionTitle: 'Carry',
        blocks: [
          SessionExecutionBlock(
            blockId: 'carry-block',
            title: 'Carries',
            blockType: SessionBlockType.strength,
            content: 'Farmer carry',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'EX-101',
                displayName: 'Farmer Carry',
                position: 1,
                prescription: StrengthExercisePrescription.fromJson({
                  'sets': 3,
                  'distance_m': '30-40',
                  'load': 'heavy',
                }),
              ),
            ],
          ),
        ],
      ),
      athleteId: 'athlete-1',
      trainingSessionId: 29,
    );
    final exercise = controller.draft.blockDrafts.single.exerciseResults.single;
    expect(exercise.sets, hasLength(3));
    expect(exercise.sets.first.distanceUnit, 'm');
    controller.updateSet(
      'carry-block',
      'EX-101',
      exercise.sets.first.setResultId,
      (set) => set.copyWith(distance: 35, load: 24, completed: true),
    );
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final set = record.blockResults.single.exerciseResults.single.setResults.first;
    expect(set.distance, 35);
    expect(set.distanceUnit, 'm');
    expect(set.load, 24);
  });

  test('compatible EMOM families compare calories; incompatible stay honest', () {
    final first = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 24,
    ).draft.blockDrafts.single.resultData as CircuitResultData;
    final recorded = first.replaceStation(
      first.stations.first.copyWith(
        calories: 12,
        state: CircuitOccurrenceState.recorded,
      ),
    );
    expect(CircuitResultComparison.isComparable(first, recorded), isTrue);
    expect(CircuitResultComparison.primarySignal(recorded)?.value, 12);

    final longer = first.copyWith(
      stations: [
        ...first.stations,
        CircuitStationActual(
          ordinal: 9,
          round: 9,
          stationIndex: 1,
          stationId: 'EX-049',
          displayName: 'RowErg',
          primaryMetric: CircuitStationMetric.calories,
          prescribedCalories: 12,
        ),
      ],
    );
    expect(CircuitResultComparison.isComparable(first, longer), isFalse);
    expect(
      CircuitResultComparison.primarySignal(first),
      isNull,
    );

    final w3Family = first.copyWith(
      stations: [
        ...first.stations,
        CircuitStationActual(
          ordinal: 9,
          round: 9,
          stationIndex: 1,
          stationId: 'EX-049',
          displayName: 'RowErg',
          primaryMetric: CircuitStationMetric.calories,
          prescribedCalories: 12,
        ),
        CircuitStationActual(
          ordinal: 10,
          round: 10,
          stationIndex: 2,
          stationId: 'EX-009',
          displayName: 'Burpees',
          primaryMetric: CircuitStationMetric.reps,
          prescribedReps: 8,
        ),
      ],
    );
    expect(CircuitResultComparison.isComparable(first, w3Family), isFalse);
  });

  test('correction payload keeps circuit station actuals', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 25,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    result = result.replaceStation(
      result.stations.first.copyWith(
        calories: 10,
        state: CircuitOccurrenceState.recorded,
      ),
    );
    controller
      ..updateBlockResultData(blockId, result)
      ..markBlockComplete(blockId);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final service = const PerformanceCorrectionService();
    final draft = PerformanceCorrectionDraft(record);
    expect(
      () => service.validate(draft),
      returnsNormally,
    );
    expect(
      (draft.blockResults.single.resultData as CircuitResultData)
          .stations
          .first
          .calories,
      10,
    );
  });

  testWidgets('W1 editor shows stations and not Intervals completed', (
    tester,
  ) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 26,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockResultEditor(
              blockDraft: controller.draft.blockDrafts.single,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, _, _) {},
              onDuplicateSet: (_, _) {},
              onRemoveSet: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Intervals completed'), findsNothing);
    expect(find.byType(CircuitCaptureEditor), findsOneWidget);
    expect(find.textContaining('RowErg'), findsWidgets);
    expect(find.textContaining('Calories'), findsWidgets);
  });

  testWidgets('completed circuit dashboard lists rounds and stations', (
    tester,
  ) async {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w5Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 27,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    result = result.replaceRound(
      result.rounds.first.copyWith(
        elapsedSeconds: 95,
        state: CircuitRoundCompletionState.completed,
      ),
    );
    controller
      ..updateBlockResultData(blockId, result)
      ..markBlockComplete(blockId);
    final store = InMemoryPerformanceRecordStore();
    await store.completeRecord(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final record = await store.getTerminalForTrainingSession(
      athleteId: 'athlete-1',
      trainingSessionId: 27,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedSessionResultView(record: record!),
        ),
      ),
    );
    expect(find.textContaining('Round 1'), findsWidgets);
    expect(find.textContaining('Sled Push'), findsWidgets);
  });

  test('calories stay calories through sync, results, correction and comparison',
      () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _w1Athletic(),
      athleteId: 'athlete-1',
      trainingSessionId: 33,
    );
    final blockId = controller.draft.blockDrafts.single.sourceBlockId;
    var result =
        controller.draft.blockDrafts.single.resultData as CircuitResultData;
    expect(result.stations.first.primaryMetric, CircuitStationMetric.calories);
    result = result.replaceStation(
      result.stations.first.copyWith(
        calories: 12,
        state: CircuitOccurrenceState.recorded,
      ),
    );
    controller.updateBlockResultData(blockId, result);
    final synced = CircuitSetSync.ensureAuthoredRows(
      exercises: controller.draft.blockDrafts.single.exerciseResults,
      result: result,
    );
    expect(synced.first.sets.first.reps, 12);
    final hydrated = CircuitSetSync.hydrateFromSets(
      result: result,
      exercises: const PerformanceRecordMapper()
          .fromDraft(
            controller.buildPersistableDraft(
              status: TrainingSessionRecordStatus.inProgress,
            ),
          )
          .blockResults
          .single
          .exerciseResults,
    );
    expect(hydrated.stations.first.primaryMetric, CircuitStationMetric.calories);
    expect(hydrated.stations.first.calories, 12);
    expect(hydrated.stations.first.reps, isNull);

    controller.markBlockComplete(blockId);
    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
    );
    expect(projection.blocks.single.circuit, isNotNull);
    expect(
      projection.blocks.single.circuit!.result.stations.first.primaryMetric,
      CircuitStationMetric.calories,
    );
    expect(
      CircuitResultComparison.primarySignal(
        projection.blocks.single.circuit!.result,
      )?.label,
      'Total calories',
    );

    final draft = PerformanceCorrectionDraft(record);
    final corrected =
        (draft.blockResults.single.resultData as CircuitResultData)
            .stations
            .first;
    expect(corrected.primaryMetric, CircuitStationMetric.calories);
    expect(corrected.calories, 12);
    const PerformanceCorrectionService().validate(draft);
  });
}
