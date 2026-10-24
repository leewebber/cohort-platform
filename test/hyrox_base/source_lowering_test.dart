import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/application/exercise_knowledge/published_version_retention.dart';
import 'package:cohort_platform/application/hyrox_base/session_source_compiler.dart';
import 'package:cohort_platform/application/hyrox_base/duration_choice.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/domain/exercise_knowledge/in_memory/in_memory_exercise_knowledge_repository.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/domain/exercise_knowledge/value_objects/exercise_id.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_modality.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/models/strength_prescription_formatter.dart';

// Explicit software authority simulation, never production source candidates.
class _FixtureAuthority implements ExerciseVersionPublicationAuthority {
  bool available = true;
  @override
  Future<Map<String, Object?>?> verifiedPublicationFor(
    ExerciseDefinition d,
  ) async => available
      ? {
          'issuer': 'software-test-only',
          'event_id': 'fixture-${d.id.value}',
          'source_reference': 'synthetic-source-lowering-proof',
        }
      : null;
}

void main() {
  final bundle =
      jsonDecode(
            File('docs/programmes/hyrox_base/SESSIONS.json').readAsStringSync(),
          )
          as Map;
  final sources = (bundle['sessions'] as List).cast<Map<String, dynamic>>();
  final audit =
      jsonDecode(
            File('docs/programmes/hyrox_base/AUDIT.json').readAsStringSync(),
          )
          as Map;
  late InMemoryExerciseKnowledgeRepository repository;
  late _FixtureAuthority authority;
  late Map<String, SessionExerciseVersionPin> pins;
  late CanonicalSessionSourceCompiler compiler;
  setUp(() {
    repository = InMemoryExerciseKnowledgeRepository();
    authority = _FixtureAuthority();
    pins = {};
    var index = 0;
    for (final raw in audit['identities'] as List) {
      final label = raw['authored_label'] as String;
      final d = ExerciseDefinition(
        id: ExerciseId.parse('EX-${900950 + index++}'),
        canonicalName: 'Synthetic $label fixture',
        modality: ExerciseModality.strength,
        lifecycleStatus: ExerciseLifecycleStatus.published,
        version: '7',
        publishedAt: DateTime.utc(2026, 10, 24),
      );
      repository.upsertDefinition(d);
      pins[label] = SessionExerciseVersionPin(
        d.id.value,
        d.version,
        personalisationDigest(d.toJson()),
      );
    }
    compiler = CanonicalSessionSourceCompiler(
      lookup: repository,
      publicationAuthority: authority,
      pins: pins,
    );
  });
  Map<String, dynamic> source(int week, String mode) =>
      sources.singleWhere((s) => s['week'] == week && s['mode'] == mode);

  test(
    'strict physical squat scope retains RIR after numeric load binding',
    () {
      final physical = StrengthExercisePrescription.fromJson({
        'sets': 3,
        'reps': 8,
        'five_rm_basis_points': 8000,
        'rir': '3',
        'rest_seconds_range': [150, 180],
      });
      final loaded = physical.copyWith(
        load: const StrengthLoadPrescription(
          type: StrengthLoadType.fixedKg,
          kg: 80,
        ),
      );
      expect(
        StrengthPrescriptionFormatter.summaryLine(loaded),
        contains('3 RIR'),
      );
      expect(loaded.restSecondsRange!.toJson(), [150, 180]);
    },
  );

  test(
    'all 48 canonical model lowerings preserve source, grouped meaning and export round trips',
    () async {
      const codec = SessionExecutionPlanCodec();
      var groups = 0, timed = 0;
      for (final s in sources) {
        final compiled = await compiler.compile(
          personalisationCanonicalJson(s),
        );
        final plan = compiled.execution;
        expect(plan.authoredSource, s);
        final restored = codec.decodePlan(
          jsonDecode(jsonEncode(codec.encodePlan(plan)))
              as Map<String, dynamic>,
        );
        expect(codec.encodePlan(restored), codec.encodePlan(plan));
        for (final b in restored.blocks) {
          if (b.linkedExercises.any((e) => e.hasExecutionGroup)) groups++;
          if (b.workoutFormat == WorkoutFormat.emom) {
            timed++;
            expect(
              b.timerConfiguration!.stations.length,
              s['mode'] == 'gym_b' ? 2 : 3,
            );
            expect(
              b.timerConfiguration!.stations.where((st) => st.isRest).length,
              s['mode'] == 'gym_c' ? 1 : 0,
            );
          }
        }
        final reopened = await compiler.reopen(compiled.exportSource());
        expect(reopened.exportSource(), compiled.exportSource());
        expect(reopened.document, s);
      }
      expect(groups, 24);
      expect(timed, 16);
    },
  );

  test(
    'missing versions, mismatched exact pin or unverified events refuse without fallback',
    () async {
      final s = personalisationCanonicalJson(source(1, 'gym_a'));
      pins.remove('back_squat');
      await expectLater(compiler.compile(s), throwsFormatException);
      final other = pins['rowing']!;
      pins['back_squat'] = SessionExerciseVersionPin(
        other.id,
        '999',
        other.digest,
      );
      await expectLater(compiler.compile(s), throwsFormatException);
      authority.available = false;
      await expectLater(compiler.compile(s), throwsFormatException);
    },
  );

  test(
    'RIR/rest windows, carries, holds and per-side paired work remain typed',
    () async {
      final first = (await compiler.compile(
        personalisationCanonicalJson(source(1, 'gym_a')),
      )).execution;
      final firstSquat = first.blocks
          .expand((b) => b.linkedExercises)
          .singleWhere((e) => e.displayName == 'back_squat')
          .prescription!;
      final loaded = firstSquat.copyWith(
        load: const StrengthLoadPrescription(
          type: StrengthLoadType.fixedKg,
          kg: 80,
        ),
      );
      expect(
        StrengthPrescriptionFormatter.summaryLine(loaded),
        contains('3 RIR'),
      );
      final physical = StrengthExercisePrescription.fromJson({
        'sets': 3,
        'reps': 8,
        'five_rm_basis_points': 8000,
        'rir': '3',
        'rest_seconds_range': [150, 180],
      });
      expect(
        StrengthPrescriptionFormatter.summaryLine(
          physical.copyWith(
            load: const StrengthLoadPrescription(
              type: StrengthLoadType.fixedKg,
              kg: 80,
            ),
          ),
        ),
        contains('3 RIR'),
      );
      final a = (await compiler.compile(
        personalisationCanonicalJson(source(2, 'gym_a')),
      )).execution;
      final squat = a.blocks
          .expand((b) => b.linkedExercises)
          .singleWhere((e) => e.displayName == 'back_squat')
          .prescription!;
      expect(squat.rirRange!.toJson(), [2, 3]);
      expect(squat.restSecondsRange!.toJson(), [150, 180]);
      final carry = a.blocks
          .expand((b) => b.linkedExercises)
          .singleWhere((e) => e.displayName == 'suitcase_carry')
          .prescription!;
      expect(
        StrengthPrescriptionFormatter.formatSetsReps(carry),
        '3 × 35 m / side',
      );
      final c = (await compiler.compile(
        personalisationCanonicalJson(source(1, 'gym_c')),
      )).execution;
      final row = c.blocks
          .expand((b) => b.linkedExercises)
          .singleWhere(
            (e) => e.displayName == 'split_stance_single_arm_cable_row',
          );
      expect(row.prescription!.reps.exactReps, 10);
      expect(row.prescription!.perSide, true);
      expect(row.hasExecutionGroup, true);
      final pallof = c.blocks
          .expand((b) => b.linkedExercises)
          .singleWhere((e) => e.displayName == 'pallof_press')
          .prescription!;
      final finisherCopy = c.blocks
          .singleWhere((b) => b.title == 'Gym finisher')
          .content;
      expect(finisherCopy, contains('selected race weight'));
      expect(finisherCopy, contains('race-standard target'));
      expect(finisherCopy, contains('race-division mapping unresolved'));
      expect(finisherCopy, contains('including the last round'));
      expect(pallof.holdSeconds, 2);
      expect(pallof.restSecondsRange!.toJson(), [45, 60]);
      final b = (await compiler.compile(
        personalisationCanonicalJson(source(1, 'gym_b')),
      )).execution;
      expect(
        b.blocks
            .expand((b) => b.linkedExercises)
            .singleWhere((e) => e.displayName == 'long_lever_plank')
            .prescription!
            .reps
            .durationSeconds,
        20,
      );
    },
  );

  test(
    'duration choice is explicit, source-bound, immutable and survives started/performance restore',
    () async {
      final compiled = await compiler.compile(
        personalisationCanonicalJson(source(6, 'long')),
      );
      final original = compiled.execution;
      final window = authoredDurationWindows(original).entries.single;
      expect(window.value, [3900, 4800]);
      expect(
        () => validateDurationChoices(original, {}),
        throwsFormatException,
      );
      expect(
        () => validateDurationChoices(original, {window.key: 4801}),
        throwsFormatException,
      );
      final frozen = <String, dynamic>{
        'schema_version': 1,
        'protocol_id': original.sessionId,
        'choices': {
          window.key: {
            'authored_range_seconds': window.value,
            'selected_seconds': 4800,
          },
        },
      };
      final started = applyFrozenDurationChoices(original, frozen);
      final timer = started.blocks
          .singleWhere((b) => b.blockId == window.key)
          .timerConfiguration!;
      expect(timer.durationSeconds, 4800);
      expect(timer.durationSecondsRange!.toJson(), [3900, 4800]);
      expect(
        original.blocks
            .singleWhere((b) => b.blockId == window.key)
            .timerConfiguration!
            .durationSeconds,
        isNull,
      );
      const codec = SessionExecutionPlanCodec();
      final restored = codec.decodePlan(
        jsonDecode(jsonEncode(codec.encodePlan(started)))
            as Map<String, dynamic>,
      );
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: restored,
            athleteId: 'synthetic-only',
            trainingSessionId: 1,
          );
      final snapshot = SessionPerformanceSnapshot.fromJson(
        jsonDecode(jsonEncode(controller.draft.sessionSnapshot.toJson()))
            as Map<String, dynamic>,
      );
      expect(snapshot.durationChoiceSnapshot, frozen);
      expect(
        () =>
            snapshot.durationChoiceSnapshot!['choices'][window
                    .key]['selected_seconds'] =
                3900,
        throwsUnsupportedError,
      );
      expect(snapshot.authoredSource, source(6, 'long'));
      final changed = jsonDecode(jsonEncode(frozen)) as Map<String, dynamic>;
      changed['choices'][window.key]['selected_seconds'] = 3900;
      expect(
        () => applyFrozenDurationChoices(started, changed),
        throwsFormatException,
      );
    },
  );

  test(
    'source export tampering never restores a claimed graph or approval',
    () async {
      final result = await compiler.compile(
        personalisationCanonicalJson(source(2, 'gym_c')),
      );
      final tampered =
          jsonDecode(result.exportSource()) as Map<String, dynamic>;
      tampered['graph']['blocks'][1]['title'] = 'forged';
      await expectLater(
        compiler.reopen(jsonEncode(tampered)),
        throwsFormatException,
      );
      final unsupported =
          jsonDecode(jsonEncode(source(1, 'gym_b'))) as Map<String, dynamic>;
      unsupported['blocks'][0]['kind'] = 'unapproved_new_timer';
      await expectLater(
        compiler.compile(personalisationCanonicalJson(unsupported)),
        throwsFormatException,
      );
    },
  );

  test(
    'no prescribed repetitions, load, hold or RIR becomes a recorded actual',
    () async {
      for (final mode in ['gym_a', 'gym_b', 'gym_c']) {
        final plan = (await compiler.compile(
          personalisationCanonicalJson(source(1, mode)),
        )).execution;
        final controller =
            PerformanceCaptureController.initializeFromExecutionPlan(
              plan: plan,
              athleteId: 'synthetic-only',
              trainingSessionId: 1,
            );
        for (final b in controller.draft.blockDrafts) {
          for (final e in b.exerciseResults) {
            for (final set in e.sets) {
              expect(set.reps, isNull);
              expect(set.load, isNull);
              expect(set.durationSeconds, isNull);
              expect(set.distance, isNull);
            }
          }
        }
      }
    },
  );

  testWidgets(
    'timed EMOM changes to recovery at the authored second; interval work has no final recovery',
    (tester) async {
      final b = (await compiler.compile(
        personalisationCanonicalJson(source(1, 'gym_b')),
      )).execution;
      final timer = b.blocks
          .singleWhere((x) => x.workoutFormat == WorkoutFormat.emom)
          .timerConfiguration!;
      final c = BlockTimerController(
        format: WorkoutFormat.emom,
        configuration: timer,
        onStateChanged: (_) {},
      );
      c.start();
      expect(c.state!.phase, BlockTimerPhase.work);
      await tester.pump(const Duration(seconds: 35));
      expect(c.state!.phase, BlockTimerPhase.rest);
      expect(c.state!.primarySeconds, 25);
      await tester.pump(const Duration(seconds: 25));
      expect(c.state!.currentRound, 2);
      c.dispose();
      final run = (await compiler.compile(
        personalisationCanonicalJson(source(1, 'quality')),
      )).execution;
      final intervals = run.blocks
          .singleWhere(
            (x) =>
                x.workoutFormat == WorkoutFormat.intervals &&
                x.blockType.name == 'conditioning',
          )
          .timerConfiguration!;
      final r = BlockTimerController(
        format: WorkoutFormat.intervals,
        configuration: intervals,
        onStateChanged: (_) {},
      );
      r.start();
      await tester.pump(const Duration(seconds: 1320));
      expect(r.state!.isFinished, true);
      r.dispose();
    },
  );

  testWidgets(
    'EMOM timer retains final rest minute and dedicated intervals omit last recovery',
    (tester) async {
      final plan = (await compiler.compile(
        personalisationCanonicalJson(source(8, 'gym_c')),
      )).execution;
      final finisher = plan.blocks.singleWhere(
        (b) => b.workoutFormat == WorkoutFormat.emom,
      );
      final controller = BlockTimerController(
        format: WorkoutFormat.emom,
        configuration: finisher.timerConfiguration!,
        onStateChanged: (_) {},
      );
      controller.start();
      await tester.pump(const Duration(seconds: 120));
      expect(controller.state!.currentStationLabel, 'Rest');
      expect(controller.state!.isFinished, false);
      await tester.pump(const Duration(seconds: 599));
      expect(controller.state!.isFinished, false);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.state!.isFinished, true);
      controller.dispose();
    },
  );
}
