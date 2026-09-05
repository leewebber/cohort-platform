import 'dart:io';

import 'package:cohort_platform/features/performance/models/interval_work_result.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/services/interval_pace_format.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/repositories/performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/performance/services/endurance_metrics_calculator.dart';
import 'package:cohort_platform/features/performance/services/performance_correction_service.dart';
import 'package:cohort_platform/features/performance/services/running_pace_plausibility.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/widgets/implausible_running_pace_warning.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('correction migration does not add a broad completed-set UPDATE policy', () {
    final sql = File(
      'supabase/migrations/20260904120000_correct_completed_performance_record.sql',
    ).readAsStringSync();
    expect(sql, contains('correct_completed_performance_record'));
    expect(sql, contains('performance_result_corrections'));
    expect(sql, isNot(contains('CREATE POLICY performance_set_results')));
    expect(sql, contains("status IS DISTINCT FROM 'completed'"));
  });

  test('9 km in 5:00 is an implausible running pace', () {
    final warning = RunningPacePlausibility.warning(
      distance: 9,
      distanceUnit: 'km',
      durationSeconds: 300,
      blockTitle: 'Easy run',
    );
    expect(warning, isNotNull);
    expect(
      warning!.message,
      'This result implies an average pace of 0:33/km. '
      'Check your duration and distance.',
    );
  });

  test('cycling and rowing are not judged by the running threshold', () {
    expect(
      RunningPacePlausibility.warning(
        distance: 9,
        distanceUnit: 'km',
        durationSeconds: 300,
        blockTitle: 'Bike',
      ),
      isNull,
    );
    expect(
      RunningPacePlausibility.warning(
        distance: 2000,
        distanceUnit: 'm',
        durationSeconds: 360,
        blockTitle: 'Rowing',
      ),
      isNull,
    );
  });

  test('plausible running pace does not warn', () {
    expect(
      RunningPacePlausibility.warning(
        distance: 9,
        distanceUnit: 'km',
        durationSeconds: 3000,
        blockTitle: 'Easy run',
      ),
      isNull,
    );
  });

  testWidgets('completed result is read-only until Edit results', (tester) async {
    final record = _apolloBase(durationSeconds: 300);
    await tester.pumpWidget(_app(record: record));

    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const ValueKey('edit-results')), findsOneWidget);
    expect(find.textContaining('0:33'), findsOneWidget);
    expect(find.text('Completed · Completed as prescribed'), findsNothing);
  });

  testWidgets('athlete can enter and cancel correction mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = _apolloBase(durationSeconds: 300);
    await tester.pumpWidget(_app(record: record));

    await tester.ensureVisible(find.byKey(const ValueKey('edit-results')));
    await tester.tap(find.byKey(const ValueKey('edit-results')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('correction-duration')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('cancel-edit-results')));
    await tester.tap(find.byKey(const ValueKey('cancel-edit-results')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('correction-duration')), findsNothing);
    expect(find.textContaining('0:33'), findsOneWidget);
  });

  testWidgets('correction pace field accepts 410 without completing a new row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(record: _apolloEngineCompleted()));
    await tester.ensureVisible(find.byKey(const ValueKey('edit-results')));
    await tester.tap(find.byKey(const ValueKey('edit-results')));
    await tester.pumpAndSettle();
    expect(find.text(IntervalPaceFormat.helperCopy), findsWidgets);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '4');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '4');
    await tester.enterText(field, '410');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '4:10');
    expect(find.byType(TextField), findsWidgets);
  });

  test('valid correction updates the existing result and audit', () async {
    final store = InMemoryPerformanceRecordStore();
    final original = _apolloBase(durationSeconds: 300);
    store.put(original);
    final draft = PerformanceCorrectionDraft(original);
    draft.blockResults = [
      original.blockResults.single.copyWith(
        resultData: const EnduranceResultData(
          distance: 9,
          distanceUnit: 'km',
          durationSeconds: 3000,
          averageHeartRate: 145,
        ),
      ),
    ];

    final corrected = await store.correctCompleted(draft);
    final relaunched = await store.getById(original.recordId);

    expect(corrected.recordId, original.recordId);
    expect(corrected.status, TrainingSessionRecordStatus.completed);
    expect(corrected.completedAt, original.completedAt);
    expect(corrected.trainingSessionId, original.trainingSessionId);
    final data = corrected.blockResults.single.resultData as EnduranceResultData;
    expect(data.durationSeconds, 3000);
    expect(data.distance, 9);
    expect(data.averageHeartRate, 145);
    expect(
      EnduranceMetricsCalculator.formatPaceOrSpeed(
        distance: 9,
        distanceUnit: 'km',
        durationSeconds: 3000,
      ),
      'Avg pace 5:33/km',
    );
    expect(relaunched!.recordId, original.recordId);
    expect(
      (relaunched.blockResults.single.resultData as EnduranceResultData)
          .durationSeconds,
      3000,
    );
    expect(store.corrections, hasLength(1));
    expect((await store.listHistory(athleteId: original.athleteId)), hasLength(1));
  });

  test('anonymous and other-athlete corrections are denied', () async {
    final store = InMemoryPerformanceRecordStore();
    final original = _apolloBase(durationSeconds: 300);
    store.put(original);
    final draft = PerformanceCorrectionDraft(original);
    draft.blockResults = [
      original.blockResults.single.copyWith(
        resultData: const EnduranceResultData(
          distance: 9,
          durationSeconds: 3000,
        ),
      ),
    ];

    store.authenticated = false;
    expect(
      () => store.correctCompleted(draft),
      throwsA(
        isA<PerformanceCorrectionException>().having(
          (error) => error.code,
          'code',
          'authentication_required',
        ),
      ),
    );

    store.authenticated = true;
    store.actingAthleteId = 'other-athlete';
    expect(
      () => store.correctCompleted(draft),
      throwsA(
        isA<PerformanceCorrectionException>().having(
          (error) => error.code,
          'code',
          'not_performance_owner',
        ),
      ),
    );
  });

  test('malformed fields are rejected and audit stays append-only', () async {
    final store = InMemoryPerformanceRecordStore();
    final original = _apolloBase(durationSeconds: 3000);
    store.put(original);
    final draft = PerformanceCorrectionDraft(original)
      ..overallRpe = 99;
    expect(
      () => store.correctCompleted(draft),
      throwsA(isA<PerformanceCorrectionException>()),
    );
    expect(store.corrections, isEmpty);

    final valid = PerformanceCorrectionDraft(original)..overallRpe = 8;
    await store.correctCompleted(valid);
    await store.correctCompleted(PerformanceCorrectionDraft(original)..overallRpe = 7);
    expect(store.corrections, hasLength(2));
  });

  test('bodyweight correction cannot persist fabricated external load', () {
    const service = PerformanceCorrectionService();
    final record = _bodyweightHang();
    final draft = PerformanceCorrectionDraft(record);
    draft.blockResults = [
      record.blockResults.single.copyWith(
        exerciseResults: [
          record.blockResults.single.exerciseResults.single.copyWith(
            setResults: [
              record.blockResults.single.exerciseResults.single.setResults.single
                  .copyWith(reps: 15, load: 40, loadUnit: 'kg'),
            ],
          ),
        ],
      ),
    ];
    service.validate(draft);
    final payload = service.toPayload(draft);
    expect(payload['sets'], isNotEmpty);
  });

  test('strength comparison metrics refresh after a load correction', () async {
    final store = InMemoryPerformanceRecordStore();
    final previous = _strength(recordId: 'prev', load: 80, completedAt: DateTime.utc(2026, 9, 1));
    final current = _strength(recordId: 'curr', load: 70, completedAt: DateTime.utc(2026, 9, 3));
    store
      ..put(previous)
      ..put(current);
    final before = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: [previous, current],
    );
    expect(before.blocks.last.exercises.single.comparisonStatus.label, 'Below previous');

    final draft = PerformanceCorrectionDraft(current);
    draft.blockResults = [
      for (final block in current.blockResults)
        block.copyWith(
          exerciseResults: [
            for (final exercise in block.exerciseResults)
              exercise.copyWith(
                setResults: [
                  for (final set in exercise.setResults)
                    set.copyWith(load: 90, loadUnit: 'kg'),
                ],
              ),
          ],
        ),
    ];
    final corrected = await store.correctCompleted(draft);
    final after = CompletedSessionResultProjection.fromRecords(
      record: corrected,
      athleteHistory: [previous, corrected],
    );
    expect(after.blocks.last.exercises.single.comparisonStatus.label, 'Improved');
    expect(after.blocks.last.exercises.single.estimated1RmLabel, isNotNull);
  });

  testWidgets('implausible correction warns and explicit override is audited', (
    tester,
  ) async {
    final store = InMemoryPerformanceRecordStore();
    final record = _apolloBase(durationSeconds: 3000);
    store.put(record);
    await tester.pumpWidget(_app(record: record, store: store));

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.tap(find.byKey(const ValueKey('edit-results')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('correction-duration')), '5:00');
    await tester.pump();
    expect(
      find.textContaining('This result implies an average pace of 0:33/km'),
      findsWidgets,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('save-corrected-results')));
    await tester.tap(find.byKey(const ValueKey('save-corrected-results')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('implausible-pace-save-anyway')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('implausible-pace-save-anyway')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('correction-confirmation')), findsOneWidget);
    expect(store.corrections.single['implausible_running_pace_acknowledged'], isTrue);
    final saved =
        (store.corrections.single['after'] as Map)['blocks'] as List;
    expect(saved, isNotEmpty);
  });

  testWidgets('implausible pace dialog offers edit and save anyway', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                confirmImplausibleRunningPace(
                  context: context,
                  warning: const RunningPaceWarning(
                    secondsPerKm: 33,
                    paceLabel: '0:33/km',
                    message:
                        'This result implies an average pace of 0:33/km. '
                        'Check your duration and distance.',
                  ),
                );
              },
              child: const Text('Warn'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Warn'));
    await tester.pumpAndSettle();
    expect(find.text('Edit result'), findsOneWidget);
    expect(find.text('Save anyway'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}

Widget _app({
  required TrainingSessionRecord record,
  PerformanceRecordStore? store,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CompletedSessionResultView(
        record: record,
        performanceRecordStore: store,
      ),
    ),
  );
}

TrainingSessionRecord _apolloEngineCompleted() {
  const result = IntervalResultData(
    totalIntervals: 5,
    workSeconds: 180,
    paceUnit: IntervalPaceUnit.secondsPerKm,
    comparisonFamily: 'intervals:run:180s:sec_per_km',
    intervals: [
      IntervalWorkResult(
        ordinal: 1,
        workSeconds: 180,
        paceSecondsPerKm: 265,
        state: IntervalWorkState.completed,
      ),
      IntervalWorkResult(
        ordinal: 2,
        workSeconds: 180,
        paceSecondsPerKm: 262,
        state: IntervalWorkState.completed,
      ),
      IntervalWorkResult(
        ordinal: 3,
        workSeconds: 180,
        paceSecondsPerKm: 260,
        state: IntervalWorkState.completed,
      ),
      IntervalWorkResult(
        ordinal: 4,
        workSeconds: 180,
        paceSecondsPerKm: 258,
        state: IntervalWorkState.completed,
      ),
      IntervalWorkResult(
        ordinal: 5,
        workSeconds: 180,
        paceSecondsPerKm: 255,
        state: IntervalWorkState.completed,
      ),
    ],
  );
  return TrainingSessionRecord(
    recordId: 'engine-1',
    athleteId: 'athlete-1',
    trainingSessionId: 44,
    sourceProtocolId: 'APOLLO-W1-THU-R1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'APOLLO-W1-THU-R1',
      sessionTitle: 'Apollo Engine',
    ),
    startedAt: DateTime.utc(2026, 8, 29, 10),
    completedAt: DateTime.utc(2026, 8, 29, 10, 48),
    blockResults: [
      TrainingBlockResult(
        blockResultId: 'engine-block',
        sessionRecordId: 'engine-1',
        sourceBlockId: 'engine',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'engine',
          title: '5K-effort intervals',
          blockType: SessionBlockType.conditioning,
          content: '5 x 3 minutes',
          workoutFormat: WorkoutFormat.intervals,
          workSeconds: 180,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.interval,
        position: 1,
        resultData: result,
      ),
    ],
  );
}

TrainingSessionRecord _apolloBase({required int durationSeconds}) {
  return TrainingSessionRecord(
    recordId: 'base-1',
    athleteId: 'athlete-1',
    trainingSessionId: 42,
    sourceProtocolId: 'APOLLO-W1-WED-R1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'APOLLO-W1-WED-R1',
      sessionTitle: 'Apollo Base',
    ),
    startedAt: DateTime.utc(2026, 9, 4, 11, 55),
    completedAt: DateTime.utc(2026, 9, 4, 12),
    durationSeconds: durationSeconds,
    overallRpe: 6,
    blockResults: [
      TrainingBlockResult(
        blockResultId: 'base-block',
        sessionRecordId: 'base-1',
        sourceBlockId: 'base',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'base',
          title: 'Easy run',
          blockType: SessionBlockType.conditioning,
          content: 'Easy aerobic run',
          workoutFormat: WorkoutFormat.steadyState,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.endurance,
        position: 1,
        resultData: EnduranceResultData(
          distance: 9,
          distanceUnit: 'km',
          durationSeconds: durationSeconds,
          averageHeartRate: 145,
        ),
      ),
    ],
  );
}

TrainingSessionRecord _bodyweightHang() {
  return TrainingSessionRecord(
    recordId: 'hang-1',
    athleteId: 'athlete-1',
    trainingSessionId: 9,
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'core',
      sessionTitle: 'Core',
    ),
    startedAt: DateTime.utc(2026, 9, 1),
    completedAt: DateTime.utc(2026, 9, 1, 1),
    blockResults: [
      TrainingBlockResult(
        blockResultId: 'hang-b',
        sessionRecordId: 'hang-1',
        sourceBlockId: 'core',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'core',
          title: 'Core',
          blockType: SessionBlockType.accessory,
          content: 'Hang',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 1,
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: 'hang-e',
            blockResultId: 'hang-b',
            sourceExerciseId: 'EX-HANG',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'EX-HANG',
              displayName: 'Dead hang',
              position: 1,
              loadKind: StrengthActualLoadKind.bodyweight,
            ),
            position: 1,
            setResults: const [
              TrainingSetResult(
                setResultId: 'hang-s',
                exerciseResultId: 'hang-e',
                setNumber: 1,
                position: 1,
                reps: 15,
                completed: true,
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

TrainingSessionRecord _strength({
  required String recordId,
  required double load,
  required DateTime completedAt,
}) {
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: 'athlete-1',
    trainingSessionId: 41,
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'strength',
      sessionTitle: 'Apollo Strength',
    ),
    startedAt: completedAt.subtract(const Duration(minutes: 40)),
    completedAt: completedAt,
    blockResults: [
      TrainingBlockResult(
        blockResultId: '$recordId-b',
        sessionRecordId: recordId,
        sourceBlockId: 'strength',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Squat',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 1,
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: '$recordId-e',
            blockResultId: '$recordId-b',
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
                setResultId: '$recordId-s',
                exerciseResultId: '$recordId-e',
                setNumber: 1,
                position: 1,
                reps: 5,
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
