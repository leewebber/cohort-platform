import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/widgets/athlete/athlete_block_card.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const warmUpPrelude = SessionBlockExerciseLink(
  localId: 'prelude',
  exerciseId: 'bike',
  position: 1,
  prescription: StrengthExercisePrescription(
    sets: 1,
    reps: StrengthRepPrescription(
      type: StrengthRepType.duration,
      text: '5 minutes',
    ),
  ),
);
const warmUpCircuit = SessionBlockExerciseLink(
  localId: 'circuit',
  exerciseId: 'band-pull-apart',
  position: 2,
  executionGroupKey: 'warm-up-circuit',
  executionGroupLabel: 'Warm-Up Circuit',
  executionGroupRounds: 2,
  prescription: StrengthExercisePrescription(
    sets: 2,
    reps: StrengthRepPrescription(type: StrengthRepType.exact, exactReps: 20),
  ),
);
const carryPrescription = StrengthExercisePrescription(
  sets: 4,
  reps: StrengthRepPrescription(
    type: StrengthRepType.distance,
    text: '40 metres',
  ),
  restSeconds: 75,
  performanceCapture: ExercisePerformanceCapture(
    loadUnit: 'kg',
    loadLabel: 'Load per hand',
    distanceUnit: 'm',
    durationOptional: true,
  ),
);

void main() {
  test('projection retains ordered execution grouping metadata', () {
    final block = SessionExecutionBlock.fromSessionBlock(
      SessionBlock(
        localId: 'warm-up',
        blockType: SessionBlockType.warmUp,
        title: 'Warm Up',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: const [warmUpPrelude, warmUpCircuit],
      ),
      exercisesById: const {},
    );

    expect(block.linkedExercises.map((item) => item.exerciseId), [
      'bike',
      'band-pull-apart',
    ]);
    expect(block.linkedExercises.first.hasExecutionGroup, isFalse);
    expect(block.linkedExercises.last.executionGroupLabel, 'Warm-Up Circuit');
    expect(block.linkedExercises.last.executionGroupRounds, 2);
  });

  test('Apollo warm-up movements retain ordered canonical identities', () {
    final block = _apolloWarmUpBlock();

    expect(block.linkedExercises.map((exercise) => exercise.exerciseId), [
      'EX-150',
      'EX-151',
      'EX-152',
      'EX-153',
      'EX-154',
    ]);
    expect(block.linkedExercises.map((exercise) => exercise.athleteLabel), [
      'Thoracic extension over foam roller',
      'Open-book rotation',
      'Serratus wall slide + reach',
      'Wall Y/lower-trap raise',
      'Single-arm cable/band row with reach',
    ]);
    expect(block.linkedExercises[3].prescription?.coachCue, 'Very light.');
    expect(
      block.linkedExercises.every((exercise) => exercise.exercise != null),
      isTrue,
    );
  });

  test('missing or malformed optional warm-up metadata remains safe', () {
    final link = SessionBlockExerciseLink.fromRow(const {
      'id': 'warm-up-link',
      'exercise_id': 'EX-150',
      'position': 1,
      'prescription': '[not an object]',
    });

    expect(link.displayLabelOverride, isNull);
    expect(link.prescription, isNull);

    final block = SessionExecutionBlock.fromSessionBlock(
      SessionBlock(
        localId: 'safe-warm-up',
        blockType: SessionBlockType.warmUp,
        title: 'Warm Up',
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [link],
      ),
      exercisesById: const {
        'EX-150': Exercise(
          exerciseId: 'EX-150',
          name: 'Thoracic Extension Over Foam Roller',
          published: true,
        ),
      },
    );

    expect(
      block.linkedExercises.single.athleteLabel,
      'Thoracic Extension Over Foam Roller',
    );
  });

  test('initial drafts seed authored blank rows without target actuals', () {
    final warmUp = _warmUpBlock();
    final carry = _carryBlock();
    final drafts = const PerformanceSnapshotBuilder().buildInitialBlockDrafts(
      SessionExecutionPlan(
        sessionId: 'spartan',
        sessionTitle: 'Spartan',
        blocks: [warmUp, carry],
      ),
    );

    expect(drafts[0].exerciseResults[0].sets, hasLength(1));
    expect(drafts[0].exerciseResults[1].sets, hasLength(2));
    expect(drafts[1].exerciseResults.single.sets, hasLength(4));

    for (final row in drafts[1].exerciseResults.single.sets) {
      expect(row.load, isNull);
      expect(row.distance, isNull);
      expect(row.durationSeconds, isNull);
      expect(row.completed, isFalse);
      expect(row.loadUnit, 'kg');
      expect(row.distanceUnit, 'm');
    }
  });

  test('warm-up cannot complete until every movement row is acknowledged', () {
    final block = _warmUpBlock();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: SessionExecutionPlan(
        sessionId: 'spartan',
        sessionTitle: 'Spartan',
        blocks: [block],
      ),
      athleteId: 'athlete',
      trainingSessionId: 1,
    )..markBlockComplete(block.blockId);

    expect(controller.validateForCompletion().isValid, isFalse);
    for (final exercise
        in controller.draft.blockDrafts.single.exerciseResults) {
      for (final row in exercise.sets) {
        controller.updateSet(
          block.blockId,
          exercise.sourceExerciseId,
          row.setResultId,
          (current) => current.copyWith(completed: true),
        );
      }
    }
    expect(controller.validateForCompletion().isValid, isTrue);
  });

  test('all four carry rows require load and distance actuals', () {
    final block = _carryBlock();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: SessionExecutionPlan(
        sessionId: 'spartan',
        sessionTitle: 'Spartan',
        blocks: [block],
      ),
      athleteId: 'athlete',
      trainingSessionId: 1,
    );
    for (final row
        in controller.draft.blockDrafts.single.exerciseResults.single.sets) {
      controller.updateSet(
        block.blockId,
        'farmer-carry',
        row.setResultId,
        (current) => current.copyWith(load: 24, distance: 40, completed: true),
      );
    }
    controller.markBlockComplete(block.blockId);

    expect(
      controller
          .draft
          .blockDrafts
          .single
          .exerciseResults
          .single
          .sets
          .first
          .reps,
      isNull,
    );
    expect(controller.validateForCompletion().isValid, isTrue);
  });

  test('incomplete carry rows fail closed after block completion', () {
    final block = _carryBlock();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: SessionExecutionPlan(
        sessionId: 'spartan',
        sessionTitle: 'Spartan',
        blocks: [block],
      ),
      athleteId: 'athlete',
      trainingSessionId: 1,
    );
    final row =
        controller.draft.blockDrafts.single.exerciseResults.single.sets.first;
    controller
      ..updateSet(
        block.blockId,
        'farmer-carry',
        row.setResultId,
        (current) => current.copyWith(load: 24, distance: 40, completed: true),
      )
      ..markBlockComplete(block.blockId);

    final result = controller.validateForCompletion();
    expect(result.isValid, isFalse);
    expect(
      result.fieldErrors.values,
      contains(
        'Complete every prescribed carry set with load per hand and distance.',
      ),
    );
  });

  testWidgets('carry editor exposes actual-only metadata fields', (
    tester,
  ) async {
    final block = _carryBlock();
    final draft = const PerformanceSnapshotBuilder()
        .buildInitialBlockDrafts(
          SessionExecutionPlan(
            sessionId: 'spartan',
            sessionTitle: 'Spartan',
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
            ),
          ),
        ),
      ),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('4 × 40 metres · Rest 1 min 15 sec'), findsOneWidget);
    expect(find.text('Last time'), findsOneWidget);
    expect(find.text('No previous performance'), findsOneWidget);
    expect(find.text('Load per hand (kg)'), findsNWidgets(4));
    expect(find.text('Completed distance (m)'), findsNWidgets(4));
    expect(find.text('Duration (optional)'), findsNWidgets(4));
    expect(find.text('Completed'), findsNWidgets(4));
  });

  testWidgets('warm-up card separates prelude, group, and exercise info', (
    tester,
  ) async {
    final block = _warmUpBlock(
      circuitExercise: const Exercise(
        exerciseId: 'band-pull-apart',
        name: 'Band Pull Apart',
        published: true,
        purpose: 'Shoulder preparation.',
        execution: 'Pull the band apart under control.',
        coachingCues: 'Keep the ribs down.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteBlockCard(
            block: block,
            isExpanded: true,
            isActive: true,
            isComplete: false,
            onToggleExpanded: () {},
            onMarkComplete: () {},
            onReopen: () {},
            onLaunchTimer: null,
            onOpenExercise: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Prelude'), findsOneWidget);
    expect(find.text('Warm-Up Circuit · 2 rounds'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);

    await tester.tap(
      find.bySemanticsLabel('Exercise info for Band Pull Apart'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Shoulder preparation.'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Pull the band apart under control.'), findsOneWidget);
    expect(find.text('Cues'), findsOneWidget);
    expect(find.text('Keep the ribs down.'), findsOneWidget);
  });

  testWidgets(
    'Apollo warm-up renders each movement, dosage, cue, and info action',
    (tester) async {
      SessionExecutionExerciseSummary? opened;
      final block = _apolloWarmUpBlock();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteBlockCard(
              block: block,
              isExpanded: true,
              isActive: true,
              isComplete: false,
              onToggleExpanded: () {},
              onMarkComplete: () {},
              onReopen: () {},
              onLaunchTimer: null,
              onOpenExercise: (exercise) => opened = exercise,
            ),
          ),
        ),
      );

      expect(find.text('Apollo Shoulder Balance Warm-Up'), findsOneWidget);
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('Thoracic extension over foam roller'), findsOneWidget);
      expect(find.text('Open-book rotation'), findsOneWidget);
      expect(find.text('Serratus wall slide + reach'), findsOneWidget);
      expect(find.text('Wall Y/lower-trap raise'), findsOneWidget);
      expect(find.text('Single-arm cable/band row with reach'), findsOneWidget);
      expect(find.text('1 × 5 slow reps at 2-3 positions'), findsOneWidget);
      expect(find.text('1 × 6/side'), findsOneWidget);
      expect(find.text('2 × 8'), findsOneWidget);
      expect(find.text('2 × 8–10'), findsOneWidget);
      expect(find.text('2 × 10/side'), findsOneWidget);
      expect(find.text('Very light.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Exercise info for Thoracic extension over foam roller',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Open-book rotation'));
      expect(opened?.exerciseId, 'EX-151');
      expect(opened?.exercise?.exerciseId, 'EX-151');
    },
  );
}

SessionExecutionBlock _apolloWarmUpBlock() {
  const links = [
    SessionBlockExerciseLink(
      localId: 'apollo-warm-up-1',
      exerciseId: 'EX-150',
      position: 1,
      displayLabelOverride: 'Thoracic extension over foam roller',
      prescription: StrengthExercisePrescription(
        sets: 1,
        reps: StrengthRepPrescription(
          type: StrengthRepType.freeText,
          text: '5 slow reps at 2-3 positions',
        ),
      ),
    ),
    SessionBlockExerciseLink(
      localId: 'apollo-warm-up-2',
      exerciseId: 'EX-151',
      position: 2,
      displayLabelOverride: 'Open-book rotation',
      prescription: StrengthExercisePrescription(
        sets: 1,
        reps: StrengthRepPrescription(
          type: StrengthRepType.freeText,
          text: '6/side',
        ),
      ),
    ),
    SessionBlockExerciseLink(
      localId: 'apollo-warm-up-3',
      exerciseId: 'EX-152',
      position: 3,
      displayLabelOverride: 'Serratus wall slide + reach',
      prescription: StrengthExercisePrescription(
        sets: 2,
        reps: StrengthRepPrescription(
          type: StrengthRepType.exact,
          exactReps: 8,
        ),
      ),
    ),
    SessionBlockExerciseLink(
      localId: 'apollo-warm-up-4',
      exerciseId: 'EX-153',
      position: 4,
      displayLabelOverride: 'Wall Y/lower-trap raise',
      prescription: StrengthExercisePrescription(
        sets: 2,
        reps: StrengthRepPrescription(
          type: StrengthRepType.range,
          minReps: 8,
          maxReps: 10,
        ),
        coachCue: 'Very light.',
      ),
    ),
    SessionBlockExerciseLink(
      localId: 'apollo-warm-up-5',
      exerciseId: 'EX-154',
      position: 5,
      displayLabelOverride: 'Single-arm cable/band row with reach',
      prescription: StrengthExercisePrescription(
        sets: 2,
        reps: StrengthRepPrescription(
          type: StrengthRepType.freeText,
          text: '10/side',
        ),
      ),
    ),
  ];

  const exercises = {
    'EX-150': Exercise(
      exerciseId: 'EX-150',
      name: 'Thoracic Extension Over Foam Roller',
      published: true,
    ),
    'EX-151': Exercise(
      exerciseId: 'EX-151',
      name: 'Open-Book Thoracic Rotation',
      published: true,
    ),
    'EX-152': Exercise(
      exerciseId: 'EX-152',
      name: 'Serratus Wall Slide + Reach',
      published: true,
    ),
    'EX-153': Exercise(
      exerciseId: 'EX-153',
      name: 'Wall Y / Lower-Trap Raise',
      published: true,
    ),
    'EX-154': Exercise(
      exerciseId: 'EX-154',
      name: 'Single-Arm Cable/Band Row with Reach',
      published: true,
    ),
  };

  return SessionExecutionBlock.fromSessionBlock(
    const SessionBlock(
      localId: 'apollo-warm-up',
      blockType: SessionBlockType.warmUp,
      title: 'Apollo Shoulder Balance Warm-Up',
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: 1,
      linkedExercises: links,
    ),
    exercisesById: exercises,
  );
}

SessionExecutionBlock _warmUpBlock({Exercise? circuitExercise}) {
  final exercisesById = <String, Exercise>{
    'bike': const Exercise(
      exerciseId: 'bike',
      name: 'Easy Bike',
      published: true,
    ),
  };
  if (circuitExercise != null) {
    exercisesById['band-pull-apart'] = circuitExercise;
  }

  return SessionExecutionBlock.fromSessionBlock(
    SessionBlock(
      localId: 'warm-up',
      blockType: SessionBlockType.warmUp,
      title: 'Warm Up',
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: 1,
      linkedExercises: const [warmUpPrelude, warmUpCircuit],
    ),
    exercisesById: exercisesById,
  );
}

SessionExecutionBlock _carryBlock() {
  return const SessionExecutionBlock(
    blockId: 'carry-block',
    title: 'Carry',
    blockType: SessionBlockType.conditioning,
    content: '',
    workoutFormat: WorkoutFormat.none,
    position: 2,
    linkedExercises: [
      SessionExecutionExerciseSummary(
        exerciseId: 'farmer-carry',
        displayName: 'Farmer Carry',
        prescription: carryPrescription,
      ),
    ],
  );
}
