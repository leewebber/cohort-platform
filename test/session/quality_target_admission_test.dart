import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/running_workout/alpha_quality_targets.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/screens/quality_target_review_screen.dart';
import 'package:cohort_platform/features/session/screens/structured_running_timer_screen.dart';
import 'package:cohort_platform/features/session/services/running_target_admission_store.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';

const owner = 'athlete-a';
const contextFixture = ProgrammeExecutionContext(
  assignmentId: 'assignment',
  programmeVersionId: 'version',
  sessionSlotId: 'slot',
  weekNumber: 1,
  dayKey: 'day_1',
  sessionOrder: 1,
  plannedProtocolId: 'quality-fixture',
  effectiveProtocolId: 'quality-fixture',
  packageContentHash:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  occurrenceId: 'occurrence',
  programmedSessionKey: 'key',
  packageSchemaVersion: 1,
);
SessionExecutionPlan fixturePlan() => SessionExecutionPlan(
  sessionId: 'quality-fixture',
  sessionTitle: '[FIXTURE ONLY] Quality run',
  blocks: [
    SessionExecutionBlock(
      blockId: 'block',
      title: '[FIXTURE ONLY] Quality run',
      blockType: SessionBlockType.conditioning,
      content: 'Software fixture only; not approved Hybrid 10K content',
      workoutFormat: WorkoutFormat.steadyState,
      position: 1,
      timerConfiguration: TimerConfiguration(
        durationSeconds: 1140,
        runningWorkout: const RunningWorkoutCodec().decode(
          File(
            'test/session/fixtures/quality_admission/quality_run.json',
          ).readAsStringSync(),
        ),
      ),
    ),
  ],
);
Map<String, dynamic> fixtureDocument({
  String source = 'five_k',
  bool frozen = false,
}) {
  final window = source == 'authored_rpe'
      ? null
      : alphaQualityPaceWindow(
          seconds: source == 'five_k' ? 1500 : 300,
          category: 'threshold',
          manualThreshold: source == 'manual_threshold',
        );
  final rule = source == 'five_k'
      ? alphaFiveKRuleId
      : source == 'manual_threshold'
      ? alphaManualThresholdRuleId
      : authoredRpeRuleId;
  return {
    'schema_version': 1,
    'athlete_id': owner,
    'assignment_id': 'assignment',
    'programme_version_id': 'version',
    'package_hash': contextFixture.packageContentHash,
    'protocol_id': 'quality-fixture',
    'occurrence_id': 'occurrence',
    'blocks': [
      {
        'block_id': 'block',
        'workout': fixturePlan().blocks.single.timerConfiguration!
            .toJson()['running_workout'],
      },
    ],
    'quality': {
      'rule_id': rule,
      'rounding': 'nearest_second_half_up',
      'selected_source': source,
      'freshness_days': source == 'five_k' ? 56 : null,
      'cutoff_inclusive': source == 'five_k' ? true : null,
      'evaluation_local_date': '2026-10-27',
      'evaluation_timezone': 'Europe/London',
      'input': source == 'authored_rpe'
          ? null
          : {
              'athlete_id': owner,
              'revision': 'input-a',
              'confirmed_at': '2026-10-27T00:00:00Z',
              'five_k_seconds': 1500,
              'five_k_date': '2026-10-20',
              'sustained': true,
              'five_k_timezone': 'Europe/London',
              'five_k_withdrawn': false,
              'manual_seconds_per_km': 300,
              'manual_origin': 'garmin_read_manually',
              'manual_withdrawn': false,
            },
    },
    'quality_targets': [
      {
        'block_id': 'block',
        'step_id': 'effort',
        'category': 'threshold',
        'source': source,
        'rule_id': rule,
        'target': window == null
            ? {'unit': 'rpe_cr10', 'value': 7}
            : {
                'unit': 'seconds_per_kilometre',
                'lower': window.lower,
                'upper': window.upper,
              },
      },
    ],
    if (frozen) 'training_session_id': 17,
    if (frozen) 'review_hash': 'a' * 64,
    if (frozen) 'accepted_at': '2026-10-27T01:00:00Z',
  };
}

void validateFixture(Map<String, dynamic> doc) => validateRunningTargetDocument(
  fixturePlan(),
  doc,
  athleteId: owner,
  occurrenceId: 'occurrence',
  assignmentId: 'assignment',
  versionId: 'version',
  packageHash: contextFixture.packageContentHash!,
);
void main() {
  test(
    'approved formula vectors and deterministic half-up rounding use seconds/km',
    () {
      expect(alphaQualityPaceWindow(seconds: 1500, category: 'threshold'), (
        lower: 319,
        upper: 332,
      ));
      expect(alphaQualityPaceWindow(seconds: 1500, category: '10k_specific'), (
        lower: 310,
        upper: 319,
      ));
      expect(alphaQualityPaceWindow(seconds: 1500, category: 'short_5k'), (
        lower: 300,
        upper: 309,
      ));
      expect(alphaQualityPaceWindow(seconds: 1250, category: 'short_5k'), (
        lower: 250,
        upper: 258,
      ));
      expect(
        alphaQualityPaceWindow(
          seconds: 300,
          category: 'threshold',
          manualThreshold: true,
        ),
        (lower: 294, upper: 306),
      );
      expect(
        alphaQualityPaceWindow(
          seconds: 25,
          category: 'threshold',
          manualThreshold: true,
        ),
        (lower: 25, upper: 26),
      );
      expect(roundAlphaPace(249.499999), 249);
      expect(roundAlphaPace(249.5), 250);
      expect(roundAlphaPace(249.500001), 250);
    },
  );
  for (final today in ['2026-10-27', '2026-03-15', '2024-03-01']) {
    test('inclusive 56-day civil boundary and future exclusion for $today', () {
      final d = DateTime.parse('${today}T00:00:00Z');
      String ago(int n) =>
          d.subtract(Duration(days: n)).toIso8601String().substring(0, 10);
      expect(alphaFiveKDateEligible(today, today), true);
      expect(alphaFiveKDateEligible(ago(56), today), true);
      expect(alphaFiveKDateEligible(ago(57), today), false);
      expect(alphaFiveKDateEligible(ago(-1), today), false);
    });
  }
  test('invalid times/dates and manual use outside threshold are rejected', () {
    for (final n in [-1, 0, 1, 86401]) {
      expect(
        () => alphaQualityPaceWindow(seconds: n, category: 'threshold'),
        throwsFormatException,
      );
    }
    for (final category in ['10k_specific', 'short_5k', 'unknown']) {
      expect(
        () => alphaQualityPaceWindow(
          seconds: 300,
          category: category,
          manualThreshold: true,
        ),
        throwsFormatException,
      );
    }
    for (final date in ['2026-02-30', '2026-2-01', 'garbage']) {
      expect(
        () => alphaFiveKDateEligible(date, '2026-10-27'),
        throwsFormatException,
      );
    }
    for (final s in ['-1', '0', '1:60', '1:-1', 'abc', '24:00:01']) {
      expect(() => parseQualityTime(s), throwsFormatException);
    }
    expect(parseQualityTime('25:00'), 1500);
    expect(parseQualityTime('300'), 300);
  });
  for (final source in alphaQualitySources) {
    test(
      '$source is explicitly bound to exact step/source/rule and stays immutable',
      () {
        final doc = fixtureDocument(source: source, frozen: true);
        validateFixture(doc);
        final plan = applyRunningTargetAdmission(fixturePlan(), doc);
        final copy = const SessionExecutionPlanCodec().decodePlan(
          jsonDecode(
                jsonEncode(const SessionExecutionPlanCodec().encodePlan(plan)),
              )
              as Map<String, dynamic>,
        );
        final execution = AuthoredTimedRunningExecution.fromBlock(
          copy.blocks.single,
          admission: copy.runningTargetAdmissionSnapshot,
        );
        final steps = runningAtomicSteps(execution.workout).toList();
        expect(steps.first.target, const RunningTarget.none());
        expect(steps.last.target, const RunningTarget.none());
        final work = steps.singleWhere((s) => s.stepId == 'effort');
        expect(
          work.target.kind,
          source == 'authored_rpe'
              ? RunningTargetKind.rpe
              : RunningTargetKind.paceRange,
        );
        final controller = StructuredRunningController.fresh(
          execution: execution,
          elapsedTime: () => Duration.zero,
        );
        controller.start();
        controller.elapse(const Duration(seconds: 430));
        final cursor = controller.cursor;
        controller.dispose();
        final restored = StructuredRunningController.restore(
          execution: execution,
          cursor: cursor,
          wallClock: () => DateTime.utc(2099),
        );
        expect(restored.cursor.isPaused, true);
        expect(
          restored.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        expect(restored.cursor.authoredStepId, 'recover');
        restored.dispose();
        final changed = fixtureDocument(
          source: source == 'five_k' ? 'manual_threshold' : 'five_k',
          frozen: true,
        );
        expect(
          () => applyRunningTargetAdmission(copy, changed),
          throwsFormatException,
        );
        expect(
          execution.authoredGuidance,
          contains(
            source == 'five_k'
                ? '5K estimate'
                : source == 'manual_threshold'
                ? 'manually entered'
                : 'authored RPE',
          ),
        );
      },
    );
  }
  for (final corruption in [
    'owner',
    'source',
    'rule',
    'unit',
    'reversed',
    'scope',
    'stale',
    'future',
    'withdrawn',
    'sustained',
    'timezone',
  ]) {
    test('reject $corruption quality document', () {
      final d = fixtureDocument();
      final q = d['quality'] as Map;
      final row = d['quality_targets'].single as Map;
      switch (corruption) {
        case 'owner':
          q['input']['athlete_id'] = 'other';
        case 'source':
          q['selected_source'] = 'unknown';
        case 'rule':
          q['rule_id'] = 'unapproved-v2';
        case 'unit':
          row['target']['unit'] = 'mph';
        case 'reversed':
          row['target']['lower'] = 400;
        case 'scope':
          row['step_id'] = 'warm';
        case 'stale':
          q['input']['five_k_date'] = '2026-01-01';
        case 'future':
          q['input']['five_k_date'] = '2026-10-28';
        case 'withdrawn':
          q['input']['five_k_withdrawn'] = true;
        case 'sustained':
          q['input']['sustained'] = false;
        case 'timezone':
          q['input']['five_k_timezone'] = 'America/New_York';
      }
      expect(() => validateFixture(d), throwsFormatException);
    });
  }
  test(
    'no automatic pace or authored-RPE fallback, and no reference on recovery',
    () {
      expect(
        () => AuthoredTimedRunningExecution.fromBlock(
          fixturePlan().blocks.single,
        ),
        throwsFormatException,
      );
      final d = fixtureDocument(source: 'authored_rpe');
      d['quality_targets'].single['target']['value'] = 8;
      expect(() => validateFixture(d), throwsFormatException);
      final body =
          fixturePlan().blocks.single.timerConfiguration!
                  .toJson()['running_workout']
              as Map<String, dynamic>;
      body['steps'][1]['steps'][1]['target'] = {
        'kind': 'alpha_quality_pace_v1',
        'category': 'threshold',
      };
      expect(
        const RunningWorkoutValidator()
            .validate(const RunningWorkoutCodec().decodeMap(body))
            .isValid,
        false,
      );
    },
  );
  testWidgets(
    'input confirmation, manual source selection and acceptance are deliberate',
    (tester) async {
      final store = _QualityStore();
      String? acceptedSource;
      await tester.pumpWidget(
        MaterialApp(
          home: QualityTargetReviewScreen(
            athleteId: owner,
            plan: fixturePlan(),
            programmeContext: contextFixture,
            store: store,
            onAccepted: (source, _) => acceptedSource = source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Accept targets and start'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('quality-time')),
        '25:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('quality-date')),
        '2026-10-20',
      );
      await tester.ensureVisible(
        find.text('I confirm this was a representative sustained 5K effort'),
      );
      await tester.tap(
        find.text('I confirm this was a representative sustained 5K effort'),
      );
      await tester.ensureVisible(find.text('Confirm this input'));
      await tester.tap(find.text('Confirm this input'));
      await tester.pumpAndSettle();
      expect(store.confirmations, 1);
      expect(acceptedSource, isNull);
      await tester.scrollUntilVisible(
        find.text('Accept targets and start'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Accept targets and start'));
      expect(acceptedSource, 'five_k');
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final chosen in ['manual_threshold', 'authored_rpe']) {
    testWidgets('$chosen must be selected and accepted explicitly', (
      tester,
    ) async {
      final store = _QualityStore();
      String? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: QualityTargetReviewScreen(
            athleteId: owner,
            plan: fixturePlan(),
            programmeContext: contextFixture,
            store: store,
            onAccepted: (source, _) => accepted = source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quality-source')));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .text(
              chosen == 'manual_threshold'
                  ? 'Manually entered threshold pace'
                  : 'Authored RPE instead of pace',
            )
            .last,
      );
      await tester.pumpAndSettle();
      if (chosen == 'manual_threshold') {
        await tester.enterText(
          find.byKey(const ValueKey('quality-time')),
          '5:00',
        );
        await tester.tap(find.byKey(const ValueKey('manual-origin')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Read from Garmin and entered manually').last,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Confirm this input'));
        await tester.tap(find.text('Confirm this input'));
        await tester.pumpAndSettle();
        expect(store.lastKind, 'manual_threshold');
        expect(store.lastSeconds, 300);
        expect(store.lastOrigin, 'garmin_read_manually');
      } else {
        expect(find.text('Confirm this input'), findsNothing);
        expect(store.confirmations, 0);
      }
      expect(accepted, isNull);
      await tester.scrollUntilVisible(
        find.text('Accept targets and start'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Accept targets and start'));
      expect(accepted, chosen);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'frozen numerical targets display on work and no downtime is counted',
    (tester) async {
      final doc = fixtureDocument(frozen: true);
      final plan = applyRunningTargetAdmission(fixturePlan(), doc);
      final run = AuthoredTimedRunningExecution.fromBlock(
        plan.blocks.single,
        admission: plan.runningTargetAdmissionSnapshot,
      );
      final c = StructuredRunningController.fresh(
        execution: run,
        elapsedTime: () => Duration.zero,
      );
      c.start();
      c.elapse(const Duration(seconds: 300));
      final cursor = c.cursor;
      c.dispose();
      await tester.pumpWidget(
        MaterialApp(
          home: StructuredRunningTimerScreen(
            execution: run,
            initialCursor: cursor,
            onCheckpoint: (_) async => true,
          ),
        ),
      );
      expect(find.text('5:19–5:32 /km'), findsOneWidget);
      expect(find.textContaining('5K estimate'), findsOneWidget);
      expect(find.text('120 s'), findsOneWidget);
      await tester.pump(const Duration(hours: 1));
      expect(find.text('120 s'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _QualityStore implements QualityRunningTargetAdmissionStore {
  int confirmations = 0;
  String? lastKind, lastOrigin;
  int? lastSeconds;
  @override
  Future<void> confirmQuality({
    required String kind,
    int? seconds,
    String? date,
    bool? sustained,
    bool withdraw = false,
    String? manualOrigin,
  }) async {
    confirmations++;
    lastKind = kind;
    lastOrigin = manualOrigin;
    lastSeconds = seconds;
  }

  @override
  Future<Map<String, dynamic>> reviewQuality(String _, String source) async =>
      confirmations == 0 && source != 'authored_rpe'
      ? {
          'status': 'input_required',
          'reason': 'missing_5k',
          'evaluation_timezone': 'Europe/London',
          'authored_rpe_available': true,
        }
      : {
          'status': 'review_required',
          'document': fixtureDocument(source: source),
          'review_hash': 'a' * 64,
        };
}
