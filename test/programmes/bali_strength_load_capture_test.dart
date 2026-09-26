import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/private_programme/private_protocol_graph_builder.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PlanPackageCompileResult compiled;
  late PrivateProtocolGraphBuildResult graphs;

  setUpAll(() {
    compiled = const PlanPackageCompiler().compile(
      File('tool/programmes/bali_hybrid_base_v1.plan-package.yaml').readAsStringSync(),
    );
    expect(compiled.isValid, isTrue);
    expect(
      compiled.contentHashSha256,
      'f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b',
    );
    graphs = const PrivateProtocolGraphBuilder().build(
      compileResult: compiled,
      founderYaml: File(
        'tool/programmes/bali_hybrid_base_v1.founder.yaml',
      ).readAsStringSync(),
    );
  });

  Map<String, dynamic> exerciseOf(String protocolId, String exerciseId) {
    final graph = graphs.graphs.cast<Map<String, Object?>>().firstWhere(
      (item) => item['protocol_id'] == protocolId,
    );
    for (final raw in graph['blocks'] as List) {
      final block = Map<String, dynamic>.from(raw as Map);
      for (final exRaw in block['exercises'] as List? ?? const []) {
        final ex = Map<String, dynamic>.from(exRaw as Map);
        if (ex['exercise_id'] == exerciseId) return ex;
      }
    }
    fail('missing $exerciseId in $protocolId');
  }

  StrengthExercisePrescription rx(String protocolId, String exerciseId) {
    return StrengthExercisePrescription.fromJson(
      Map<String, dynamic>.from(exerciseOf(protocolId, exerciseId)['prescription'] as Map),
    );
  }

  StrengthActualLoadKind kindFor(
    String protocolId,
    String exerciseId, {
    SessionBlockType blockType = SessionBlockType.strength,
  }) {
    return StrengthActualLoadKind.fromPrescription(
      blockType: blockType,
      prescription: rx(protocolId, exerciseId),
    );
  }

  test('Plan Package hash still does not cover protocol bodies', () {
    expect(compiled.manifest!.sessions, hasLength(71));
    expect(graphs.graphs, hasLength(71));
  });

  test('W1 Front squat / RDL / pull-up / RFESS / row require load + RPE', () {
    for (final id in [
      'front-squat',
      'romanian-deadlift',
      'weighted-pull-up',
      'rear-foot-elevated-split-squat',
      'chest-supported-row',
    ]) {
      final prescription = rx('BALI-W01-D01-S01-R1', id);
      expect(prescription.performanceCapture?.loadUnit, 'kg');
      expect(prescription.performanceCapture?.rpe, isTrue);
      expect(
        kindFor('BALI-W01-D01-S01-R1', id),
        StrengthActualLoadKind.external,
      );
    }
    expect(rx('BALI-W01-D01-S01-R1', 'front-squat').restSeconds, 180);
    expect(rx('BALI-W01-D01-S01-R1', 'weighted-pull-up').performanceCapture?.loadLabel, 'External load');
    expect(rx('BALI-W01-D01-S01-R1', 'rear-foot-elevated-split-squat').reps.text, '8/leg');
  });

  test('W1 Ab wheel is reps-only; farmer carry is load + 40 m', () {
    expect(
      kindFor('BALI-W01-D01-S01-R1', 'ab-wheel'),
      StrengthActualLoadKind.bodyweight,
    );
    expect(rx('BALI-W01-D01-S01-R1', 'ab-wheel').performanceCapture, isNull);
    final carry = rx('BALI-W01-D01-S01-R1', 'farmer-carry');
    expect(carry.performanceCapture?.loadUnit, 'kg');
    expect(carry.performanceCapture?.distanceUnit, 'm');
    expect(carry.prescribedDistanceText, '40 m');
    expect(kindFor('BALI-W01-D01-S01-R1', 'farmer-carry'), StrengthActualLoadKind.external);
  });

  test('Warm-up movements do not request load', () {
    expect(
      kindFor(
        'BALI-W01-D01-S01-R1',
        'bodyweight-squat',
        blockType: SessionBlockType.warmUp,
      ),
      StrengthActualLoadKind.none,
    );
    expect(rx('BALI-W01-D01-S01-R1', 'bodyweight-squat').performanceCapture, isNull);
  });

  test('Sunday press, Thursday chin-up, and Week 8 tests accept load', () {
    expect(kindFor('BALI-W01-D02-S02-R1', 'strict-press'), StrengthActualLoadKind.external);
    expect(rx('BALI-W01-D02-S02-R1', 'incline-db-press').performanceCapture?.loadUnit, 'kg');
    expect(
      rx('BALI-W01-D06-S01-R1', 'weighted-chin-up').performanceCapture?.loadLabel,
      'External load',
    );
    expect(kindFor('BALI-W08-D07-S01-R1', 'front-squat-3rm'), StrengthActualLoadKind.external);
    expect(
      rx('BALI-W08-D07-S01-R1', 'weighted-pull-up-1rm').performanceCapture?.loadLabel,
      'External load',
    );
  });

  test('hosted failure shape (freeText load, no capture) hid kg', () {
    const broken = StrengthExercisePrescription(
      sets: 4,
      reps: StrengthRepPrescription(type: StrengthRepType.exact, exactReps: 5),
      load: StrengthLoadPrescription(type: StrengthLoadType.freeText, text: 'RPE 7'),
    );
    expect(
      StrengthActualLoadKind.fromPrescription(
        blockType: SessionBlockType.strength,
        prescription: broken,
      ),
      StrengthActualLoadKind.external,
    );
  });

  testWidgets('Strength A working-set widgets render kg, reps, and RPE', (
    tester,
  ) async {
    final prescription = rx('BALI-W01-D01-S01-R1', 'front-squat');
    final block = SessionExecutionBlock.fromSessionBlock(
      SessionBlock(
        localId: 'main',
        blockType: SessionBlockType.strength,
        title: 'Main strength',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 2,
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'fs',
            exerciseId: 'front-squat',
            position: 1,
            displayLabelOverride: 'Front squat',
            prescription: prescription,
          ),
        ],
      ),
      exercisesById: const {},
    );
    final draft = const PerformanceSnapshotBuilder()
        .buildInitialBlockDrafts(
          SessionExecutionPlan(
            sessionId: 'BALI-W01-D01-S01-R1',
            sessionTitle: 'Strength A',
            blocks: [block],
          ),
        )
        .single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockResultEditor(
              blockDraft: draft,
              linkedExercises: block.linkedExercises,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, _, _) {},
              onDuplicateSet: (_, _) {},
              onRemoveSet: (_, _) {},
              onOpenExercise: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.textContaining('load'), findsWidgets);
    expect(find.text('RPE'), findsWidgets);
    expect(find.text('Bodyweight'), findsNothing);
  });

  testWidgets('Ab wheel does not render a kg field', (tester) async {
    final prescription = rx('BALI-W01-D01-S01-R1', 'ab-wheel');
    final block = SessionExecutionBlock.fromSessionBlock(
      SessionBlock(
        localId: 'main',
        blockType: SessionBlockType.strength,
        title: 'Main strength',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 2,
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'ab',
            exerciseId: 'ab-wheel',
            position: 6,
            displayLabelOverride: 'Ab wheel',
            prescription: prescription,
          ),
        ],
      ),
      exercisesById: const {},
    );
    final draft = const PerformanceSnapshotBuilder()
        .buildInitialBlockDrafts(
          SessionExecutionPlan(
            sessionId: 'BALI-W01-D01-S01-R1',
            sessionTitle: 'Strength A',
            blocks: [block],
          ),
        )
        .single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockResultEditor(
              blockDraft: draft,
              linkedExercises: block.linkedExercises,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, _, _) {},
              onDuplicateSet: (_, _) {},
              onRemoveSet: (_, _) {},
              onOpenExercise: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.text('Bodyweight'), findsWidgets);
    expect(find.text('RPE'), findsNothing);
  });
}
