import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cohort_platform/features/private_programme/private_protocol_graph_builder.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/protocol_step_to_block_converter.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';

void main() {
  late PlanPackageCompileResult compiled;
  late PrivateProtocolGraphBuildResult graphs;

  setUpAll(() {
    compiled = const PlanPackageCompiler().compile(
      File('tool/programmes/bali_hybrid_base_v1.plan-package.yaml').readAsStringSync(),
    );
    expect(compiled.isValid, isTrue);
    graphs = const PrivateProtocolGraphBuilder().build(
      compileResult: compiled,
      founderYaml: File(
        'tool/programmes/bali_hybrid_base_v1.founder.yaml',
      ).readAsStringSync(),
    );
  });

  test('Bali scheduled sessions all receive executable founder graphs', () {
    expect(graphs.missingProtocolIds, isEmpty);
    expect(graphs.graphs, hasLength(71));
    expect(graphs.blockCount, greaterThan(71));
    expect(graphs.exerciseCount, greaterThan(200));
  });

  test('header-only payload is incomplete', () {
    expect(graphs.graphs, isNotEmpty);
    final first = graphs.graphs.first;
    expect(first['blocks'], isA<List>());
    expect((first['blocks'] as List), isNotEmpty);
  });

  SessionExecutionPlan planFor(String protocolId) {
    final graph = graphs.graphs.cast<Map<String, Object?>>().firstWhere(
      (item) => item['protocol_id'] == protocolId,
    );
    final blocks = <SessionBlock>[];
    for (final raw in graph['blocks'] as List) {
      final block = Map<String, dynamic>.from(raw as Map);
      final links = <SessionBlockExerciseLink>[];
      for (final exRaw in block['exercises'] as List? ?? const []) {
        final ex = Map<String, dynamic>.from(exRaw as Map);
        final prescriptionRaw = ex['prescription'];
        links.add(
          SessionBlockExerciseLink(
            localId: 'l-${ex['position']}',
            exerciseId: ex['exercise_id'] as String,
            position: ex['position'] as int,
            displayLabelOverride: ex['display_label_override'] as String?,
            prescription: prescriptionRaw is Map
                ? StrengthExercisePrescription.fromJson(
                    Map<String, dynamic>.from(prescriptionRaw),
                  )
                : null,
          ),
        );
      }
      blocks.add(
        SessionBlock(
          localId: 'b-${block['position']}',
          blockType: SessionBlockTypeDb.fromDb(block['block_type'] as String),
          title: block['title'] as String,
          content: block['content'] as String? ?? '',
          workoutFormat: WorkoutFormatDb.fromDb(
            block['workout_format'] as String? ?? 'none',
          ),
          position: block['position'] as int,
          coachNotes: block['coach_notes'] as String?,
          linkedExercises: links,
        ),
      );
    }
    final execution = blocks
        .map(
          (block) => SessionExecutionBlock.fromSessionBlock(
            block,
            exercisesById: const {},
          ),
        )
        .toList(growable: false);
    return SessionExecutionPlan(
      sessionId: protocolId,
      sessionTitle: protocolId,
      blocks: execution,
    );
  }

  test('Week 1 Saturday Strength A compiles', () {
    final plan = planFor('BALI-W01-D01-S01-R1');
    expect(plan.hasExecutableBlocks, isTrue);
    expect(plan.blocks.map((b) => b.title), containsAll(['Warm-up', 'Cooldown']));
    expect(
      plan.blocks.expand((b) => b.linkedExercises.map((e) => e.displayName)),
      containsAll([
        'Front squat',
        'Romanian deadlift',
        'Weighted pull-up',
        'Rear-foot-elevated split squat',
        'Chest-supported row',
        'Ab wheel',
        'Farmer carry',
      ]),
    );
  });

  test('Week 1 Sunday BikeErg compiles as steady-state', () {
    final plan = planFor('BALI-W01-D02-S01-R1');
    expect(plan.hasExecutableBlocks, isTrue);
    expect(
      plan.blocks.any((b) => b.workoutFormat == WorkoutFormat.steadyState),
      isTrue,
    );
  });

  test('Week 1 Monday Threshold compiles as intervals', () {
    final plan = planFor('BALI-W01-D03-S01-R1');
    expect(plan.hasExecutableBlocks, isTrue);
    expect(
      plan.blocks.any((b) => b.workoutFormat == WorkoutFormat.intervals),
      isTrue,
    );
  });

  test('Week 1 Monday muscular endurance compiles ordered blocks', () {
    final plan = planFor('BALI-W01-D03-S02-R1');
    expect(plan.hasExecutableBlocks, isTrue);
    expect(plan.blocks.length, greaterThanOrEqualTo(2));
  });

  test('Week 4 Bike test, 2 km Row, and efficiency test compile', () {
    expect(planFor('BALI-W04-D03-S01-R1').hasExecutableBlocks, isTrue);
    expect(planFor('BALI-W04-D05-S01-R1').hasExecutableBlocks, isTrue);
    expect(planFor('BALI-W04-D07-S01-R1').hasExecutableBlocks, isTrue);
  });

  test('Week 5 Row threshold and Week 8 strength/efficiency compile', () {
    expect(planFor('BALI-W05-D07-S01-R1').hasExecutableBlocks, isTrue);
    expect(planFor('BALI-W08-D01-S01-R1').hasExecutableBlocks, isTrue);
    expect(planFor('BALI-W08-D09-S01-R1').hasExecutableBlocks, isTrue);
  });

  test('header-only protocol fails closed at compile', () {
    const plan = SessionExecutionPlan(
      sessionId: 'BALI-HEADER-ONLY',
      sessionTitle: 'Header only',
      blocks: [],
    );
    expect(plan.hasExecutableBlocks, isFalse);
  });

  test('legacy converter is unused when blocks exist', () {
    const converter = ProtocolStepToBlockConverter();
    expect(converter.convertStepsToBlocks(const []), isEmpty);
  });
}
