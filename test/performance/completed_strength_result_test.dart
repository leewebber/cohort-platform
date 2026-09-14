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
import 'package:cohort_platform/core/theme/colors.dart';
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

  test('exercises render in authored order when stored reversed', () {
    final record = _multiExerciseRecord(
      recordId: 'r-order',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      exercises: [
        _exercise(
          recordId: 'r-order',
          exerciseId: 'EX-ROW',
          name: 'Chest-supported row',
          position: 3,
          load: 70,
          reps: 8,
        ),
        _exercise(
          recordId: 'r-order',
          exerciseId: 'EX-SQUAT',
          name: 'Back squat',
          position: 1,
          load: 100,
          reps: 5,
        ),
        _exercise(
          recordId: 'r-order',
          exerciseId: 'EX-BENCH',
          name: 'Incline bench',
          position: 2,
          load: 80,
          reps: 6,
        ),
      ],
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: record,
    );
    expect(
      projection.blocks
          .firstWhere((block) => block.title == 'Strength')
          .exercises
          .map((exercise) => exercise.displayName),
      ['Back squat', 'Incline bench', 'Chest-supported row'],
    );
  });

  test('first performance is labeled First performance', () {
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
          .comparisonStatus,
      StrengthExerciseComparisonStatus.baseline,
    );
    expect(
      projection.blocks
          .firstWhere((block) => block.title == 'Strength')
          .exercises
          .single
          .comparisonLabel,
      'First performance',
    );
  });

  test('heavier load with fewer reps is Mixed, not estimated-1RM Improved', () {
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
      reps: 3,
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous, current],
    );
    final exercise = projection.blocks
        .firstWhere((block) => block.title == 'Strength')
        .exercises
        .single;

    expect(exercise.comparisonStatus, StrengthExerciseComparisonStatus.mixed);
    expect(exercise.comparisonLabel, 'Mixed');
    expect(exercise.bestSetLabel, contains('90 kg'));
    expect(exercise.estimated1RmLabel, contains('Est. 1RM'));
    expect(exercise.volumeLabel, contains('270 kg'));
    expect(exercise.sets, hasLength(1));
    expect(exercise.sets.single.loadLabel, '90 kg');
    expect(exercise.sets.single.repsLabel, '3 reps');
    expect(exercise.previousSets.single.loadLabel, '80 kg');
  });

  test('maintained stays within the 1RM tolerance', () {
    final previous = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 100,
      reps: 5,
    );
    final current = _completedStrengthRecord(
      recordId: 'r2',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 100.4,
      reps: 5,
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous],
    );
    expect(
      projection.blocks
          .firstWhere((block) => block.title == 'Strength')
          .exercises
          .single
          .comparisonStatus,
      StrengthExerciseComparisonStatus.maintained,
    );
  });

  test('lower estimated 1RM is Below previous', () {
    final previous = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 100,
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
      athleteHistory: [previous],
    );
    expect(
      projection.blocks
          .firstWhere((block) => block.title == 'Strength')
          .exercises
          .single
          .comparisonStatus,
      StrengthExerciseComparisonStatus.belowPrevious,
    );
  });

  test('incompatible load kinds are Not comparable, not a decline', () {
    final previous = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 100,
      reps: 5,
    );
    final current = _completedStrengthRecord(
      recordId: 'r2',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: null,
      reps: 8,
      loadKind: StrengthActualLoadKind.bodyweight,
      exerciseId: 'EX-SQUAT',
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous],
    );
    final exercise = projection.blocks
        .firstWhere((block) => block.title == 'Strength')
        .exercises
        .single;
    expect(
      exercise.comparisonStatus,
      StrengthExerciseComparisonStatus.notComparable,
    );
    expect(exercise.sets.single.loadLabel, 'Bodyweight');
    expect(exercise.sets.single.loadLabel?.contains('0.0'), isFalse);
  });

  test('missing external load is Not comparable and never shows 0.0 kg', () {
    final previous = _completedStrengthRecord(
      recordId: 'r1',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 80,
      reps: 5,
    );
    final current = _completedStrengthRecord(
      recordId: 'r2',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: null,
      reps: 5,
    );
    final projection = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous],
    );
    final exercise = projection.blocks
        .firstWhere((block) => block.title == 'Strength')
        .exercises
        .single;
    expect(
      exercise.comparisonStatus,
      StrengthExerciseComparisonStatus.notComparable,
    );
    expect(exercise.sets.single.loadLabel, isNull);
    expect(exercise.estimated1RmLabel, isNull);
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

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
      expect(find.text('Back squat'), findsOneWidget);
      expect(find.text('First performance'), findsOneWidget);
      expect(find.textContaining('8 reps'), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.textContaining('90 min estimated'), findsNothing);
      expect(find.textContaining('0.0 kg'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Checkbox), findsNothing);

      await tester.ensureVisible(
        find.byKey(const ValueKey('completed-exercise-EX-SQUAT')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('completed-exercise-EX-SQUAT')));
      await tester.pumpAndSettle();
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('8 ×'), findsOneWidget);
      expect(find.text('60 kg'), findsOneWidget);
      expect(find.text('8 reps · 60 kg · Completed'), findsNothing);
      expect(find.text('BEST SET'), findsOneWidget);
      expect(find.text('ESTIMATED 1RM'), findsOneWidget);
      expect(find.text('WORKING VOLUME'), findsOneWidget);
    },
  );

  testWidgets('accordion starts collapsed and expands the tapped exercise', (
    tester,
  ) async {
    final record = _multiExerciseRecord(
      recordId: 'r-ui-acc',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      exercises: [
        _exercise(
          recordId: 'r-ui-acc',
          exerciseId: 'EX-SQUAT',
          name: 'Back squat',
          position: 1,
          load: 100,
          reps: 5,
          extraSets: const [(2, 5, 105.0)],
        ),
        _exercise(
          recordId: 'r-ui-acc',
          exerciseId: 'EX-BENCH',
          name: 'Incline bench',
          position: 2,
          load: 70,
          reps: 6,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CompletedSessionResultView(record: record)),
      ),
    );

    expect(find.text('Back squat'), findsOneWidget);
    expect(find.text('Incline bench'), findsOneWidget);
    expect(find.textContaining('105 kg'), findsNothing);
    expect(find.textContaining('70 kg'), findsNothing);

    await tester.tap(find.text('Back squat'));
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('105 kg'), findsOneWidget);
    expect(find.textContaining('5 reps · 100 kg · Completed'), findsNothing);
    expect(find.text('70 kg'), findsNothing);
  });

  testWidgets('badge meaning is not colour-only and is announced', (
    tester,
  ) async {
    final previous = _completedStrengthRecord(
      recordId: 'r-prev',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 80,
      reps: 5,
    );
    final current = _completedStrengthRecord(
      recordId: 'r-now',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 95,
      reps: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedSessionResultView(
            record: current,
            athleteHistory: [previous],
          ),
        ),
      ),
    );

    expect(find.text('Improved'), findsOneWidget);
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Improved compared with the previous')),
      findsWidgets,
    );
  });

  testWidgets('keyboard activate expands a collapsed exercise', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final record = _completedStrengthRecord(
      recordId: 'r-key',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 80,
      reps: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CompletedSessionResultView(record: record)),
      ),
    );

    final row = find.byKey(const ValueKey('completed-exercise-EX-SQUAT'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final inkWell = find.descendant(of: row, matching: find.byType(InkWell));
    Actions.invoke<ActivateIntent>(
      tester.element(inkWell),
      const ActivateIntent(),
    );
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
  });

  testWidgets('expanded strength result uses Today, Last Time, and metric tiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previous = _multiExerciseRecord(
      recordId: 'r-pull-prev',
      completedAt: DateTime.utc(2026, 8, 28, 18),
      exercises: [
        _exercise(
          recordId: 'r-pull-prev',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 90,
          reps: 5,
        ),
      ],
    );
    final current = _multiExerciseRecord(
      recordId: 'r-pull-now',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      exercises: [
        _exercise(
          recordId: 'r-pull-now',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 100,
          reps: 5,
          extraSets: const [(2, 5, 105.0)],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedSessionResultView(
            record: current,
            athleteHistory: [previous],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Weighted Pull-Up'));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-set-EX-095-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-set-EX-095-2')), findsOneWidget);
    expect(find.text('LAST TIME'), findsOneWidget);
    expect(
      find.text(formatCompletedDate(DateTime.utc(2026, 8, 28, 18))),
      findsOneWidget,
    );
    expect(find.text('100 kg'), findsOneWidget);
    expect(find.text('105 kg'), findsOneWidget);
    expect(find.text('90 kg'), findsOneWidget);
    expect(find.text('Set 3'), findsNothing);
    expect(find.textContaining('5 reps · 100 kg · Completed'), findsNothing);
    expect(find.text('BEST SET'), findsOneWidget);
    expect(find.text('5 × 105 kg'), findsOneWidget);
    expect(find.text('ESTIMATED 1RM'), findsOneWidget);
    expect(find.text('122.5 kg'), findsOneWidget);
    expect(find.text('+17.5 kg'), findsOneWidget);
    expect(find.text('WORKING VOLUME'), findsOneWidget);
    expect(find.text('1,025 kg'), findsOneWidget);
    expect(find.text('+575 kg'), findsOneWidget);
    expect(find.text('Improved'), findsOneWidget);

    final bestRow = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('today-set-EX-095-2')),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    expect((bestRow.decoration as BoxDecoration).color, CohortColors.oliveSoft);

    final todayRow = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('today-set-EX-095-1')),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    expect((todayRow.decoration as BoxDecoration).color, Colors.transparent);

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('today-set-EX-095-1'))).dx,
      tester.getTopLeft(find.byKey(const ValueKey('today-set-EX-095-2'))).dx,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Resume'), findsNothing);
  });

  testWidgets('narrow layout stacks Last Time under Today without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previous = _multiExerciseRecord(
      recordId: 'r-n-prev',
      completedAt: DateTime.utc(2026, 8, 28, 18),
      exercises: [
        _exercise(
          recordId: 'r-n-prev',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 90,
          reps: 5,
        ),
      ],
    );
    final current = _multiExerciseRecord(
      recordId: 'r-n-now',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      exercises: [
        _exercise(
          recordId: 'r-n-now',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 100,
          reps: 5,
          extraSets: const [(2, 5, 105.0)],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CompletedSessionResultView(
              record: current,
              athleteHistory: [previous],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Weighted Pull-Up'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('LAST TIME')).dy,
      greaterThan(tester.getTopLeft(find.text('TODAY')).dy),
    );
    expect(find.text('—'), findsNothing);
    expect(find.textContaining('0.0 kg'), findsNothing);
  });

  testWidgets('expanded result respects large text scale without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previous = _multiExerciseRecord(
      recordId: 'r-ts-prev',
      completedAt: DateTime.utc(2026, 8, 28, 18),
      exercises: [
        _exercise(
          recordId: 'r-ts-prev',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 90,
          reps: 5,
        ),
      ],
    );
    final current = _multiExerciseRecord(
      recordId: 'r-ts-now',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      exercises: [
        _exercise(
          recordId: 'r-ts-now',
          exerciseId: 'EX-095',
          name: 'Weighted Pull-Up',
          position: 1,
          load: 100,
          reps: 5,
          extraSets: const [(2, 5, 105.0)],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
            ),
            child: child!,
          );
        },
        home: Scaffold(
          body: CompletedSessionResultView(
            record: current,
            athleteHistory: [previous],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Weighted Pull-Up'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('122.5 kg'), findsOneWidget);
  });

  testWidgets('bodyweight remains Not comparable and never shows 0.0 kg', (
    tester,
  ) async {
    final previous = _completedStrengthRecord(
      recordId: 'r-bw-prev',
      completedAt: DateTime.utc(2026, 9, 1, 18),
      load: 10,
      reps: 12,
    );
    final current = _completedStrengthRecord(
      recordId: 'r-bw-now',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: null,
      reps: 12,
      loadKind: StrengthActualLoadKind.bodyweight,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompletedSessionResultView(
            record: current,
            athleteHistory: [previous],
          ),
        ),
      ),
    );

    expect(find.text('Not comparable'), findsOneWidget);
    await tester.tap(find.text('Back squat'));
    await tester.pumpAndSettle();
    expect(find.text('Bodyweight'), findsWidgets);
    expect(find.textContaining('0.0 kg'), findsNothing);
    expect(find.text('ESTIMATED 1RM'), findsNothing);
    expect(find.text('WORKING VOLUME'), findsNothing);
  });

  testWidgets('warm-up shows a single concise completion state', (tester) async {
    final record = _completedStrengthRecord(
      recordId: 'r-wu',
      completedAt: DateTime.utc(2026, 9, 3, 18),
      load: 80,
      reps: 5,
      warmUpTitle: 'Apollo Shoulder Balance Warm-Up',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CompletedSessionResultView(record: record)),
      ),
    );

    final warmUp = find.byKey(
      const ValueKey('completed-block-Apollo Shoulder Balance Warm-Up'),
    );
    expect(warmUp, findsOneWidget);
    expect(
      find.descendant(of: warmUp, matching: find.text('Completed')),
      findsOneWidget,
    );
    expect(find.text('Completed · Completed'), findsNothing);
    expect(find.textContaining('Completed — Completed'), findsNothing);
  });
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

TrainingExerciseResult _exercise({
  required String recordId,
  required String exerciseId,
  required String name,
  required int position,
  required double? load,
  required int reps,
  StrengthActualLoadKind loadKind = StrengthActualLoadKind.external,
  List<(int setNumber, int reps, double? load)> extraSets = const [],
}) {
  final sets = [
    TrainingSetResult(
      setResultId: '$recordId-$exerciseId-1',
      exerciseResultId: '$recordId-$exerciseId',
      setNumber: 1,
      position: 1,
      reps: reps,
      load: load,
      loadUnit: load == null || loadKind != StrengthActualLoadKind.external
          ? null
          : 'kg',
      completed: true,
    ),
    for (final extra in extraSets)
      TrainingSetResult(
        setResultId: '$recordId-$exerciseId-${extra.$1}',
        exerciseResultId: '$recordId-$exerciseId',
        setNumber: extra.$1,
        position: extra.$1,
        reps: extra.$2,
        load: extra.$3,
        loadUnit: extra.$3 == null || loadKind != StrengthActualLoadKind.external
            ? null
            : 'kg',
        completed: true,
      ),
  ];
  return TrainingExerciseResult(
    exerciseResultId: '$recordId-$exerciseId',
    blockResultId: '$recordId-s',
    sourceExerciseId: exerciseId,
    exerciseSnapshot: ExercisePerformanceSnapshot(
      sourceExerciseId: exerciseId,
      displayName: name,
      position: position,
      loadKind: loadKind,
    ),
    position: position,
    setResults: sets,
  );
}

TrainingSessionRecord _multiExerciseRecord({
  required String recordId,
  required DateTime completedAt,
  required List<TrainingExerciseResult> exercises,
  String athleteId = 'athlete-1',
}) {
  final snapshotExercises = List<ExercisePerformanceSnapshot>.from(
    exercises.map((exercise) => exercise.exerciseSnapshot),
  )..sort((a, b) => a.position.compareTo(b.position));
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: athleteId,
    trainingSessionId: 41,
    sourceProtocolId: 'APOLLO-W1-MON-R1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: SessionPerformanceSnapshot(
      sourceProtocolId: 'APOLLO-W1-MON-R1',
      sessionTitle: 'Apollo Strength',
      blocks: [
        BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Authored strength',
          workoutFormat: WorkoutFormat.none,
          position: 2,
          exercises: snapshotExercises,
        ),
      ],
    ),
    startedAt: completedAt.subtract(const Duration(seconds: 2400)),
    completedAt: completedAt,
    durationSeconds: 2400,
    overallRpe: 7,
    blockResults: [
      TrainingBlockResult(
        blockResultId: '$recordId-s',
        sessionRecordId: recordId,
        sourceBlockId: 'strength',
        blockSnapshot: BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Authored strength',
          workoutFormat: WorkoutFormat.none,
          position: 2,
          exercises: snapshotExercises,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 2,
        exerciseResults: exercises,
      ),
    ],
  );
}

TrainingSessionRecord _completedStrengthRecord({
  required String recordId,
  required DateTime completedAt,
  required double? load,
  required int reps,
  String athleteId = 'athlete-1',
  int durationSeconds = 2400,
  int rpe = 7,
  String exerciseId = 'EX-SQUAT',
  StrengthActualLoadKind loadKind = StrengthActualLoadKind.external,
  String warmUpTitle = 'Warm-up',
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
        blockSnapshot: BlockPerformanceSnapshot(
          sourceBlockId: 'warmup',
          title: warmUpTitle,
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
            sourceExerciseId: exerciseId,
            exerciseSnapshot: ExercisePerformanceSnapshot(
              sourceExerciseId: exerciseId,
              displayName: 'Back squat',
              position: 1,
              loadKind: loadKind,
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
                loadUnit: load == null || loadKind != StrengthActualLoadKind.external
                    ? null
                    : 'kg',
                completed: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
