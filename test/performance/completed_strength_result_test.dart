import 'dart:io';

import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'entered strength loads survive autosave, completion, and relaunch',
    () async {
      final store = InMemoryPerformanceRecordStore();
      final controller = _strengthController();
      final squatId = controller
          .draft
          .blockDrafts
          .firstWhere((block) => block.sourceBlockId == 'strength')
          .exerciseResults
          .single
          .sets
          .single
          .setResultId;
      controller
        ..updateSet(
          'strength',
          'EX-SQUAT',
          squatId,
          (set) => set.copyWith(reps: 5, load: 100, completed: true),
        )
        ..markBlockComplete('strength')
        ..markBlockComplete('warmup')
        ..updateSessionRpe(7);

      await store.saveDraft(controller.draft);
      final completed = await store.completeRecord(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.completed,
          completedAt: controller.draft.startedAt.add(
            const Duration(minutes: 54, seconds: 12),
          ),
        ),
      );
      final relaunched = await store.getTerminalForTrainingSession(
        athleteId: 'athlete-1',
        trainingSessionId: 41,
      );

      expect(completed.recordId, relaunched?.recordId);
      final set = relaunched!.blockResults
          .firstWhere((block) => block.sourceBlockId == 'strength')
          .exerciseResults
          .single
          .setResults
          .single;
      expect(set.reps, 5);
      expect(set.load, 100);
      expect(relaunched.overallRpe, 7);
      expect(relaunched.durationSeconds, 54 * 60 + 12);
    },
  );

  test('bodyweight completion does not persist fabricated 0.0 kg', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: SessionExecutionPlan(
        sessionId: 'bodyweight',
        sessionTitle: 'Core',
        blocks: [
          SessionExecutionBlock(
            blockId: 'core',
            title: 'Core',
            blockType: SessionBlockType.accessory,
            content: 'Hang',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'EX-HANG',
                displayName: 'Dead hang',
                prescription: StrengthExercisePrescription(
                  sets: 2,
                  reps: StrengthRepPrescription.exact(15),
                  load: StrengthLoadPrescription(
                    type: StrengthLoadType.bodyweight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      athleteId: 'athlete-1',
      trainingSessionId: 9,
    );
    final setId = controller
        .draft
        .blockDrafts
        .single
        .exerciseResults
        .single
        .sets
        .first
        .setResultId;
    controller.updateSet(
      'core',
      'EX-HANG',
      setId,
      (set) => set.copyWith(reps: 15, load: 0, completed: true),
    );

    final record = const PerformanceRecordMapper().fromDraft(
      controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
    final persisted = record.blockResults.single.exerciseResults.single.setResults
        .first;

    expect(persisted.reps, 15);
    expect(persisted.load, isNull);
    expect(persisted.loadUnit, isNull);

    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
    );
    expect(projection.blocks.single.exercises.single.sets.first.loadLabel, 'Bodyweight');
    expect(
      projection.blocks.single.exercises.single.sets.first.repsLabel,
      '15 reps',
    );
    expect(
      projection.blocks.single.exercises.single.sets.any(
        (set) => set.loadLabel?.contains('0.0') == true,
      ),
      isFalse,
    );
  });

  test('first performance is labeled First recorded session', () {
    final record = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 80,
      reps: 5,
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
    );

    expect(
      projection.blocks
          .firstWhere((block) => block.title == 'Strength')
          .exercises
          .single
          .comparisonLabel,
      'First recorded session',
    );
  });

  test('later performance compares against the prior completed result', () {
    final previous = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 80,
      reps: 5,
    );
    final current = _completedStrengthRecord(
      recordId: 'r2',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 90,
      reps: 5,
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous, current],
    );
    final exercise = projection.blocks
        .firstWhere((block) => block.title == 'Strength')
        .exercises
        .single;

    expect(exercise.comparisonLabel, contains('+10 kg best load'));
    expect(exercise.bestSetLabel, contains('90 kg'));
    expect(exercise.volumeLabel, contains('450 kg'));
    expect(exercise.sets, hasLength(1));
    expect(exercise.sets.single.loadLabel, '90 kg');
    expect(exercise.sets.single.repsLabel, '5 reps');
  });

  test('listHistory stays athlete-isolated', () async {
    final store = InMemoryPerformanceRecordStore();
    await store.completeRecord(
      PerformanceCaptureController(
        draft: const PerformanceRecordMapper().toDraft(
          _completedStrengthRecord(
            recordId: 'mine',
            athleteId: 'athlete-1',
            completedAt: DateTime.utc(2026, 9, 3),
            load: 100,
            reps: 3,
          ),
        ),
      ).buildPersistableDraft(status: TrainingSessionRecordStatus.completed),
    );
    await store.completeRecord(
      PerformanceCaptureController(
        draft: const PerformanceRecordMapper().toDraft(
          _completedStrengthRecord(
            recordId: 'theirs',
            athleteId: 'athlete-2',
            completedAt: DateTime.utc(2026, 9, 3),
            load: 200,
            reps: 3,
          ),
        ),
      ).buildPersistableDraft(status: TrainingSessionRecordStatus.completed),
    );

    final mine = await store.listHistory(athleteId: 'athlete-1');
    expect(mine, hasLength(1));
    expect(mine.single.athleteId, 'athlete-1');
    expect(
      mine.single.blockResults
          .firstWhere((block) => block.sourceBlockId == 'strength')
          .exerciseResults
          .single
          .setResults
          .single
          .load,
      100,
    );
  });

  test('production performance RLS remains athlete-scoped', () {
    final sql = File(
      'supabase/migrations/20260722130000_production_identity_rls_lockdown.sql',
    ).readAsStringSync();
    expect(sql, contains('performance_set_results_athlete_all'));
    expect(sql, contains('athlete_id = auth.uid()::TEXT'));
    expect(sql, contains("r.status = 'in_progress'"));
  });

  testWidgets(
    'completed result is results-first, read-only, and shows duration/RPE',
    (tester) async {
      final record = _completedStrengthRecord(
        recordId: 'r-ui',
        completedAt: DateTime.utc(2026, 9, 3, 18, 12),
        load: 60,
        reps: 8,
        durationSeconds: 3240,
        rpe: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedSessionResultView(
              record: record,
              statusMessage:
                  'This assigned session has been completed and cannot be restarted.',
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('completed-session-result')), findsOneWidget);
      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
      expect(find.textContaining('Duration'), findsOneWidget);
      expect(find.textContaining('Set 1 · 8 reps · 60 kg · Completed'), findsOneWidget);
      expect(find.text('First recorded session'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.textContaining('estimated'), findsNothing);
      expect(find.textContaining('0.0 kg'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );
}

PerformanceCaptureController _strengthController() {
  return PerformanceCaptureController.initializeFromExecutionPlan(
    plan: SessionExecutionPlan(
      sessionId: 'APOLLO-W1-MON-R1',
      sessionTitle: 'Apollo Strength',
      blocks: [
        SessionExecutionBlock(
          blockId: 'warmup',
          title: 'Warm-up',
          blockType: SessionBlockType.warmUp,
          content: 'Raise temperature',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        SessionExecutionBlock(
          blockId: 'strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Squat',
          workoutFormat: WorkoutFormat.none,
          position: 2,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'EX-SQUAT',
              displayName: 'Back squat',
              prescription: StrengthExercisePrescription(
                sets: 1,
                reps: StrengthRepPrescription.exact(5),
                load: StrengthLoadPrescription(
                  type: StrengthLoadType.athleteSelected,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    athleteId: 'athlete-1',
    trainingSessionId: 41,
  );
}

TrainingSessionRecord _completedStrengthRecord({
  required String recordId,
  required DateTime completedAt,
  required double load,
  required int reps,
  String athleteId = 'athlete-1',
  int durationSeconds = 2400,
  int rpe = 7,
}) {
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: athleteId,
    trainingSessionId: 41,
    sourceProtocolId: 'APOLLO-W1-MON-R1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'APOLLO-W1-MON-R1',
      sessionTitle: 'Apollo Strength',
    ),
    startedAt: completedAt.subtract(Duration(seconds: durationSeconds)),
    completedAt: completedAt,
    durationSeconds: durationSeconds,
    overallRpe: rpe,
    blockResults: [
      TrainingBlockResult(
        blockResultId: '$recordId-w',
        sessionRecordId: recordId,
        sourceBlockId: 'warmup',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'warmup',
          title: 'Warm-up',
          blockType: SessionBlockType.warmUp,
          content: 'Raise temperature for 8 minutes',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.completion,
        position: 1,
      ),
      TrainingBlockResult(
        blockResultId: '$recordId-s',
        sessionRecordId: recordId,
        sourceBlockId: 'strength',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Squat 4 x 5',
          workoutFormat: WorkoutFormat.none,
          position: 2,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 2,
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: '$recordId-e',
            blockResultId: '$recordId-s',
            sourceExerciseId: 'EX-SQUAT',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'EX-SQUAT',
              displayName: 'Back squat',
              position: 1,
              loadKind: StrengthActualLoadKind.external,
            ),
            position: 1,
            setResults: [
              TrainingSetResult(
                setResultId: '$recordId-set',
                exerciseResultId: '$recordId-e',
                setNumber: 1,
                position: 1,
                reps: reps,
                load: load,
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
