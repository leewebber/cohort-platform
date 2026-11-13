import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_service.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/presentation/strength_workout_instructions.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'instruction copy removes explicit metadata without splitting prose',
    () {
      expect(
        StrengthWorkoutInstructions.lines(
          'Walk for 5 minutes; slow down as needed.\n'
          'Protocol ID: protocol-private\n'
          'source_occurrence_id: W01-A-internal\n'
          'Review status: pending\n'
          'Rest until your breathing settles.',
        ),
        [
          'Walk for 5 minutes; slow down as needed.',
          'Rest until your breathing settles.',
        ],
      );
    },
  );

  testWidgets('standard authored strength keeps the order and recording targets', (
    tester,
  ) async {
    final graph =
        (jsonDecode(
                      File(
                        'docs/programmes/hybrid_10k/m31_thursday_trial/protocol-graphs.json',
                      ).readAsStringSync(),
                    )
                    as List<dynamic>)
                .single
            as Map<String, dynamic>;
    final source = (graph['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final blocks = [
      for (final block in source)
        SessionExecutionBlock.fromSessionBlock(
          SessionBlock.fromRow(
            block,
            linkedExercises: [
              for (final link
                  in (block['exercises'] as List<dynamic>)
                      .cast<Map<String, dynamic>>())
                SessionBlockExerciseLink.fromRow(link),
            ],
          ),
          exercisesById: const {},
        ),
    ];
    final plan = SessionExecutionPlan(
      sessionId: graph['protocol_id'] as String,
      sessionTitle: 'Thursday strength',
      blocks: blocks,
    );
    final controller = SessionExecutionController(
      plan: plan,
      sessionKey: 'strength-readability',
    )..startSession();
    final performance =
        PerformanceCaptureController.initializeFromExecutionPlan(
          plan: plan,
          athleteId: 'fixture-athlete',
          trainingSessionId: 9,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: ActiveSessionScreen(
          controller: controller,
          performanceController: performance,
          athleteId: 'fixture-athlete',
          trainingSessionId: 9,
          saveCoordinator: PerformanceRecordSaveCoordinator(
            store: InMemoryPerformanceRecordStore(),
          ),
          previousStrengthService: PreviousStrengthPerformanceService(
            store: const EmptyPreviousStrengthPerformanceStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const steps = [
      '1. 5 minutes walking/marching',
      '2. 10 bodyweight squats',
      '3. 8 unloaded hinges',
      '4. 8 scapular pull-ups OR shoulder-blade movements',
      '5. 8 arm circles each direction',
      '6. First loaded lower-body pattern: 2–4 progressively loaded warm-up sets',
      '7. Each new upper-body pattern: 1–2 light sets as needed; no failure',
    ];
    for (final step in steps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.textContaining('Retained proposed preparation'), findsNothing);

    Future<void> tap(String label) async {
      final target = find.text(label);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('Workout guidance');
    expect(
      find.text('Preparation and warm-up sets are separate from working sets.'),
      findsOneWidget,
    );
    expect(find.textContaining('D8 review'), findsNothing);
    expect(
      find.text('Use this week’s exact sets, rests and repetitions in reserve.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('selected consolidation, lower-body control and taper'),
      findsNothing,
    );
    await tap('Next >');

    final authoredExercises = (source[1]['exercises'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final exerciseLabels = [
      for (final exercise in authoredExercises)
        exercise['display_label_override'] as String,
    ];
    expect(
      performance.draft.blockDrafts[1].exerciseResults.map(
        (exercise) => exercise.exerciseSnapshot.displayName,
      ),
      exerciseLabels,
    );
    expect(find.text('2 × 5–6'), findsOneWidget);
    expect(find.text('Load: Athlete selected'), findsWidgets);
    expect(find.text('2–3 RIR'), findsWidgets);
    expect(find.text('Rest 120–180 s'), findsOneWidget);
    expect(find.textContaining('D8 review pending'), findsNothing);

    await tap('Setup, tempo & cues');
    expect(
      find.text(
        'Tempo Lower under control for about 2 seconds, with no forced pause. Lift purposefully.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'controlled hinge, stop before spinal position changes',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Membership and dose explicitly selected'),
      findsNothing,
    );

    final firstLoad = find
        .widgetWithText(TextField, 'Total barbell load')
        .first;
    await tester.ensureVisible(firstLoad);
    await tester.enterText(firstLoad, '42.5');
    await tester.pumpAndSettle();
    final draft = performance.draft.blockDrafts[1];
    expect(draft.exerciseResults.first.sets.first.load, 42.5);
    expect(draft.exerciseResults.first.sets.first.loadUnit, 'kg');
    expect(
      blocks[1].linkedExercises.first.prescription!.authoredDetails,
      authoredExercises.first['prescription']['authored_details'],
    );
    expect(blocks.first.content, source.first['content']);
  });
}
