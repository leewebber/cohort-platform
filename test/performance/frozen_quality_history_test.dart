import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/running_workout/alpha_quality_targets.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/screens/training_history_detail_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../session/quality_target_admission_test.dart' as fixture;

const _title = 'Consolidation threshold';
const _draftNote =
    'Genuine selected draft. D8 full-programme content review pending.';
const _recorded = '7.6 km in 43:07 · Avg pace 5:40/km';
const _prescribed = 'Threshold work · 5:19–5:32/km';

void main() {
  final rows =
      jsonDecode(
            File(
              'docs/programmes/hybrid_10k/performance_selected_2026_11_03/'
              'RUNNING_BODIES.json',
            ).readAsStringSync(),
          )
          as List;
  final selected =
      rows.singleWhere((row) => row['source_session_id'] == 'LW10K-W04-D02')
          as Map<String, dynamic>;
  final body = selected['workout'] as Map<String, dynamic>;
  final workout = const RunningWorkoutCodec().decodeMap(body);
  final plan = SessionExecutionPlan(
    sessionId: 'LW10K-W04-D02',
    sessionTitle: _title,
    blocks: [
      SessionExecutionBlock(
        blockId: 'block',
        title: _title,
        blockType: SessionBlockType.conditioning,
        content: _draftNote,
        workoutFormat: WorkoutFormat.steadyState,
        position: 0,
        timerConfiguration: TimerConfiguration(
          durationSeconds: selected['fixed_seconds'] as int,
          runningWorkout: workout,
        ),
      ),
    ],
  );

  Map<String, dynamic> snapshot(int trainingId, int fiveKSeconds) {
    final document = fixture.fixtureDocument(frozen: true);
    final quality = document['quality'] as Map<String, dynamic>;
    (quality['input'] as Map<String, dynamic>)['five_k_seconds'] = fiveKSeconds;
    final window = alphaQualityPaceWindow(
      seconds: fiveKSeconds,
      category: 'threshold',
    );
    document
      ..['protocol_id'] = plan.sessionId
      ..['training_session_id'] = trainingId
      ..['blocks'] = [
        {'block_id': 'block', 'workout': body},
      ]
      ..['quality_targets'] = [
        for (final step in runningAtomicSteps(workout))
          if (step.target.kind == RunningTargetKind.qualityPaceRef)
            {
              'block_id': 'block',
              'step_id': step.stepId,
              'category': 'threshold',
              'source': 'five_k',
              'rule_id': alphaFiveKRuleId,
              'target': {
                'unit': 'seconds_per_kilometre',
                'lower': window.lower,
                'upper': window.upper,
              },
            },
      ];
    validateRunningTargetDocument(
      plan,
      document,
      athleteId: fixture.owner,
      occurrenceId: fixture.contextFixture.occurrenceId!,
      assignmentId: fixture.contextFixture.assignmentId,
      versionId: fixture.contextFixture.programmeVersionId,
      packageHash: fixture.contextFixture.packageContentHash!,
    );
    return document;
  }

  Future<TrainingSessionRecord> complete(
    InMemoryPerformanceRecordStore store,
    int trainingId, {
    Map<String, dynamic>? accepted,
  }) async {
    final capture = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: accepted == null
          ? plan
          : applyRunningTargetAdmission(plan, accepted),
      athleteId: fixture.owner,
      trainingSessionId: trainingId,
    );
    capture
      ..updateBlockResultData(
        'block',
        const EnduranceResultData(
          durationSeconds: 2587,
          distance: 7.6,
          distanceUnit: 'km',
        ),
      )
      ..markBlockComplete('block');
    expect(capture.validateForCompletion().isValid, isTrue);
    return store.completeRecord(
      capture.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      ),
    );
  }

  Future<void> open(
    WidgetTester tester,
    InMemoryPerformanceRecordStore store,
    TrainingSessionRecord record,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingHistoryDetailScreen(
          key: ValueKey(record.recordId),
          recordId: record.recordId,
          athleteId: fixture.owner,
          saveCoordinator: PerformanceRecordSaveCoordinator(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'History separates the frozen threshold range from actuals at 320×568',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = InMemoryPerformanceRecordStore();
      final original = await complete(store, 17, accepted: snapshot(17, 1500));
      final originalTree = original.toCompletionTreeMap();
      final later = await complete(store, 18, accepted: snapshot(18, 1440));

      await open(tester, store, later);
      expect(
        find.textContaining('Threshold work · 5:06–5:18/km'),
        findsOneWidget,
      );
      await open(tester, store, original);
      final block = find.byKey(const ValueKey('completed-block-$_title'));
      final actual = find.descendant(of: block, matching: find.text(_recorded));
      final prescribed = find.descendant(
        of: block,
        matching: find.text(_prescribed),
      );
      final heading = find.descendant(
        of: block,
        matching: find.text('Prescription'),
      );
      final detail = find.byKey(const ValueKey('completed-session-result'));
      final scrollable = find.descendant(
        of: detail,
        matching: find.byType(Scrollable),
      );
      for (final row in [actual, heading, prescribed]) {
        await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
        await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(row);
        final viewport = tester.getRect(detail);
        expect(bounds.left, greaterThanOrEqualTo(viewport.left));
        expect(bounds.right, lessThanOrEqualTo(viewport.right));
        expect(bounds.top, greaterThanOrEqualTo(viewport.top));
        expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
      }
      expect(
        tester.getTopLeft(actual).dy,
        lessThan(tester.getTopLeft(heading).dy),
      );
      expect(
        tester.getTopLeft(heading).dy,
        lessThan(tester.getTopLeft(prescribed).dy),
      );
      final text = tester
          .widget<Text>(find.textContaining('42:30 total'))
          .data!;
      expect(text, contains('10 min easy warm-up'));
      expect(
        text,
        contains('90 sec easy recovery between reps only (3 recoveries)'),
      );
      expect(text, contains('5 min very easy cooldown'));
      expect(prescribed, findsOneWidget);
      expect(find.textContaining('5:06–5:18/km'), findsNothing);
      expect(find.textContaining(_draftNote), findsNothing);
      expect(
        (await store.getById(original.recordId))!.toCompletionTreeMap(),
        originalTree,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final reviewOnly in [false, true]) {
    testWidgets(
      'History retains the prescription without an accepted range (review only: $reviewOnly)',
      (tester) async {
        final store = InMemoryPerformanceRecordStore();
        final record = await complete(
          store,
          17,
          accepted: reviewOnly
              ? (snapshot(17, 1500)..remove('accepted_at'))
              : null,
        );
        await open(tester, store, record);
        expect(find.text(_recorded), findsOneWidget);
        expect(find.text('Prescription'), findsOneWidget);
        expect(find.textContaining('5 min very easy cooldown'), findsOneWidget);
        expect(find.textContaining('Threshold work ·'), findsNothing);
        expect(find.textContaining(_draftNote), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
