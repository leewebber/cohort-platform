import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/models/previous_strength_performance.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'dart:ui' show Tristate;

import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/features/workout_player/services/previous_performance_resolver.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PreviousPerformanceStore.clear);

  testWidgets('collapsed cards show name and canonical volume once', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    expect(find.text('Weighted Pull-Up'), findsOneWidget);
    expect(find.text('4 × 5–6'), findsOneWidget);
    expect(find.text('Incline Barbell Bench Press'), findsOneWidget);
    expect(find.text('4 × 6–8'), findsOneWidget);
    expect(find.text('Romanian Deadlift'), findsOneWidget);
    expect(find.text('3 × 8–10'), findsOneWidget);
    expect(find.text('Farmer Carry'), findsOneWidget);
    expect(find.text('3 × 40 m'), findsOneWidget);
  });

  testWidgets('first incomplete strength exercise starts expanded', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    expect(find.text('Previous performance'), findsOneWidget);
    expect(find.text('Add set'), findsOneWidget);
    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Set 1 reps'), findsOneWidget);
  });

  testWidgets('later exercises begin collapsed without capture chrome', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    expect(find.text('Load per hand (kg)'), findsNothing);
    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.text('Previous performance'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Exercise info for Incline Barbell Bench Press'),
      findsNothing,
    );
  });

  testWidgets('tapping expands and collapses the selected exercise', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    await _tapExercise(tester, 'Incline Barbell Bench Press');
    expect(find.text('Previous performance'), findsOneWidget);
    expect(find.text('Add set'), findsOneWidget);

    await _tapExercise(tester, 'Incline Barbell Bench Press');
    expect(find.text('Previous performance'), findsNothing);
    expect(find.text('Add set'), findsNothing);
  });

  testWidgets('opening another exercise collapses the previous one', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    await _tapExercise(tester, 'Romanian Deadlift');

    expect(find.text('Add set'), findsOneWidget);
    expect(find.text('Set 1 reps'), findsWidgets);
    expect(find.text('Load per hand (kg)'), findsNothing);
    expect(
      find.bySemanticsLabel('Exercise info for Weighted Pull-Up'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Exercise info for Romanian Deadlift'),
      findsOneWidget,
    );
  });

  testWidgets('current exercise can collapse to show the session overview', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    await _tapExercise(tester, 'Weighted Pull-Up');

    expect(find.text('Add set'), findsNothing);
    expect(find.text('Previous performance'), findsNothing);
    expect(find.text('Weighted Pull-Up'), findsOneWidget);
    expect(find.text('Incline Barbell Bench Press'), findsOneWidget);
  });

  testWidgets('weight and reps survive collapse and re-expansion', (
    tester,
  ) async {
    final harness = _Harness(_initialDraft());
    await _pumpHarness(tester, harness);

    await tester.enterText(
      find.widgetWithText(TextField, 'Set 1 reps').first,
      '7',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Load (kg)').first,
      '12.5',
    );
    await tester.pump();

    await _tapExercise(tester, 'Incline Barbell Bench Press');
    await _tapExercise(tester, 'Weighted Pull-Up');

    expect(find.widgetWithText(TextField, 'Set 1 reps'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('12.5'), findsOneWidget);
  });

  testWidgets('valid set edits still notify the capture callbacks', (
    tester,
  ) async {
    final harness = _Harness(_initialDraft());
    await _pumpHarness(tester, harness);

    await tester.enterText(
      find.widgetWithText(TextField, 'Set 1 reps').first,
      '6',
    );
    await tester.pump();

    expect(harness.updateCalls, greaterThan(0));
  });

  testWidgets(
    'invalid editable drafts survive toggling without marking complete',
    (tester) async {
      final harness = _Harness(_initialDraft());
      await _pumpHarness(tester, harness);

      await tester.enterText(
        find.widgetWithText(TextField, 'Set 1 reps').first,
        '8',
      );
      await tester.pump();
      await _tapExercise(tester, 'Incline Barbell Bench Press');
      await _tapExercise(tester, 'Weighted Pull-Up');

      expect(find.text('8'), findsOneWidget);
      expect(find.text('Completed · 4 sets'), findsNothing);
      expect(harness.draft.exerciseResults.first.sets.first.completed, isFalse);
    },
  );

  testWidgets('hosted Week 1 evidence shows ghosts without writing today', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      draft: _initialDraft(),
      history: PreviousStrengthHistoryState.ready({
        'EX-095': PreviousStrengthExerciseEvidence(
          exerciseId: 'EX-095',
          recordId: 'week-1',
          performedAt: DateTime.utc(2026, 9, 7),
          sets: const [
            PreviousStrengthSetEvidence(
              setNumber: 1,
              reps: 5,
              load: 10,
              loadUnit: 'kg',
            ),
          ],
        ),
      }),
    );

    expect(find.text('Previous performance'), findsOneWidget);
    expect(find.textContaining('Last: 10 kg'), findsOneWidget);
    expect(find.text('First recorded performance'), findsNothing);
  });

  testWidgets('loading and error remain distinct from first recorded', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      draft: _initialDraft(),
      history: const PreviousStrengthHistoryState.loading(),
    );
    expect(find.text('Loading previous performance…'), findsOneWidget);
    expect(find.text('First recorded performance'), findsNothing);

    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlockResultEditor(
              blockDraft: _initialDraft(),
              linkedExercises: _apolloUpper().linkedExercises,
              previousStrengthHistory:
                  const PreviousStrengthHistoryState.failed(),
              onRetryPreviousStrength: () => retried += 1,
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
    expect(find.text('Couldn’t load previous performance'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('ready history with no match is first recorded performance', (
    tester,
  ) async {
    await _pumpEditor(
      tester,
      draft: _initialDraft(),
      history: const PreviousStrengthHistoryState.ready({}),
    );
    expect(find.text('First recorded performance'), findsOneWidget);
  });

  testWidgets('previous performance appears only when expanded', (
    tester,
  ) async {
    PreviousPerformanceStore.replaceAll([
      PreviousPerformanceSnapshot(
        exerciseId: 'EX-095',
        sessionType: PreviousPerformanceSessionType.strength,
        performedAt: DateTime.utc(2026, 8, 1),
        repSummary: '6, 6, 5, 5',
        loadSummary: '10 kg',
      ),
      PreviousPerformanceSnapshot(
        exerciseId: 'EX-136',
        sessionType: PreviousPerformanceSessionType.strength,
        performedAt: DateTime.utc(2026, 8, 1),
        repSummary: '8, 8, 7, 7',
        loadSummary: '70 kg',
      ),
    ]);

    await _pumpEditor(tester, draft: _initialDraft());

    expect(find.textContaining('6, 6, 5, 5'), findsOneWidget);
    expect(find.textContaining('70 kg'), findsNothing);

    await _tapExercise(tester, 'Incline Barbell Bench Press');
    expect(find.textContaining('70 kg'), findsOneWidget);
    expect(find.textContaining('6, 6, 5, 5'), findsNothing);
  });

  testWidgets('expanding does not duplicate previous-performance resolves', (
    tester,
  ) async {
    final resolver = _CountingResolver();
    await _pumpEditor(tester, draft: _initialDraft(), resolver: resolver);
    final afterFirst = resolver.resolveCount;

    await _tapExercise(tester, 'Weighted Pull-Up');
    await _tapExercise(tester, 'Weighted Pull-Up');
    await _tapExercise(tester, 'Incline Barbell Bench Press');
    await _tapExercise(tester, 'Incline Barbell Bench Press');
    await _tapExercise(tester, 'Incline Barbell Bench Press');

    expect(afterFirst, 1);
    expect(resolver.resolveCount, 2);
  });

  testWidgets('completed exercise shows a compact completed state', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _resumeDraft(completeFirst: true));

    expect(find.text('Completed · 4 sets'), findsOneWidget);
    expect(find.text('Add set'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Exercise info for Incline Barbell Bench Press'),
      findsOneWidget,
    );
  });

  testWidgets('partial exercise remains incomplete on the collapsed card', (
    tester,
  ) async {
    final draft = _applySet(
      _initialDraft(),
      'EX-095',
      (set) => set.setNumber == 1
          ? set.copyWith(reps: 7, load: 10, completed: true)
          : set,
    );
    await _pumpEditor(tester, draft: draft);

    expect(find.text('Completed · 4 sets'), findsNothing);
    expect(find.text('Previous performance'), findsOneWidget);
  });

  testWidgets('resume expands the earliest incomplete exercise', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _resumeDraft(completeFirst: true));

    expect(
      find.bySemanticsLabel('Exercise info for Incline Barbell Bench Press'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Exercise info for Weighted Pull-Up'),
      findsNothing,
    );
  });

  testWidgets('fully completed strength list opens collapsed', (tester) async {
    await _pumpEditor(tester, draft: _resumeDraft(completeAll: true));

    expect(find.text('Previous performance'), findsNothing);
    expect(find.text('Add set'), findsNothing);
    expect(find.text('Completed · 4 sets'), findsNWidgets(2));
    expect(find.text('Completed · 3 sets'), findsNWidgets(3));
  });

  testWidgets('clearing a completed set removes the completed badge', (
    tester,
  ) async {
    final harness = _Harness(_resumeDraft(completeFirst: true));
    await _pumpHarness(tester, harness);

    expect(find.text('Completed · 4 sets'), findsOneWidget);

    await _tapExercise(tester, 'Weighted Pull-Up');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await _tapExercise(tester, 'Weighted Pull-Up');

    expect(find.text('Completed · 4 sets'), findsNothing);
  });

  testWidgets('accordion toggling does not write persistence callbacks', (
    tester,
  ) async {
    final harness = _Harness(_initialDraft());
    await _pumpHarness(tester, harness);

    await _tapExercise(tester, 'Incline Barbell Bench Press');
    await _tapExercise(tester, 'Romanian Deadlift');
    await _tapExercise(tester, 'Romanian Deadlift');

    expect(harness.updateCalls, 0);
    expect(harness.addSetCalls, 0);
    expect(harness.resultCalls, 0);
  });

  testWidgets('set order is preserved across expand and collapse', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.decoration?.labelText)
          .whereType<String>()
          .where((label) => label.startsWith('Set'))
          .toList(),
      ['Set 1 reps', 'Set 2 reps', 'Set 3 reps', 'Set 4 reps'],
    );
  });

  testWidgets('long names wrap on a narrow Dynamic Type screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 1400),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: BlockResultEditor(
                blockDraft: _initialDraft(),
                linkedExercises: _apolloUpper().linkedExercises,
                onResultChanged: (_) {},
                onAddSet: (_) {},
                onUpdateSet: (_, _, _) {},
                onDuplicateSet: (_, _) {},
                onRemoveSet: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Overhead Cable Triceps Extension'), findsOneWidget);
  });

  testWidgets('keyboard inset keeps the expanded header in a scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Builder(
              builder: (context) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: BlockResultEditor(
                    blockDraft: _initialDraft(),
                    linkedExercises: _apolloUpper().linkedExercises,
                    onResultChanged: (_) {},
                    onAddSet: (_) {},
                    onUpdateSet: (_, _, _) {},
                    onDuplicateSet: (_, _) {},
                    onRemoveSet: (_, _) {},
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapExercise(tester, 'Farmer Carry');

    expect(find.text('Farmer Carry'), findsOneWidget);
    expect(find.text('Load per hand (kg)'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VoiceOver semantics expose name, volume, and expanded state', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft());

    final expanded = tester.getSemantics(
      find.bySemanticsLabel('Weighted Pull-Up. 4 × 5–6'),
    );
    expect(expanded.flagsCollection.isButton, isTrue);
    expect(expanded.flagsCollection.isExpanded, Tristate.isTrue);

    final collapsed = tester.getSemantics(
      find.bySemanticsLabel('Incline Barbell Bench Press. 4 × 6–8'),
    );
    expect(collapsed.flagsCollection.isButton, isTrue);
    expect(collapsed.flagsCollection.isExpanded, Tristate.isFalse);
  });

  testWidgets('paired strength work keeps group structure and order', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _initialDraft(paired: true));

    expect(find.text('Upper pair · 3 rounds'), findsOneWidget);
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
      labels.indexOf('Weighted Pull-Up') <
          labels.indexOf('Incline Barbell Bench Press'),
      isTrue,
    );
  });

  testWidgets('iPhone-width Apollo W1 overview matches founder scan cases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PreviousPerformanceStore.replaceAll([
      PreviousPerformanceSnapshot(
        exerciseId: 'EX-095',
        sessionType: PreviousPerformanceSessionType.strength,
        performedAt: DateTime.utc(2026, 8, 3),
        repSummary: '6, 6, 5, 5',
        loadSummary: '+10 kg',
      ),
    ]);

    await _pumpEditor(tester, draft: _initialDraft());

    expect(find.text('Weighted Pull-Up'), findsOneWidget);
    expect(find.text('4 × 5–6'), findsOneWidget);
    expect(find.text('Previous performance'), findsOneWidget);
    expect(find.textContaining('+10 kg'), findsOneWidget);
    expect(find.text('Incline Barbell Bench Press'), findsOneWidget);
    expect(find.text('4 × 6–8'), findsOneWidget);

    await _tapExercise(tester, 'Weighted Pull-Up');
    expect(find.text('Previous performance'), findsNothing);

    await _tapExercise(tester, 'Weighted Pull-Up');
    expect(find.textContaining('+10 kg'), findsOneWidget);
  });
}

class _CountingResolver extends PreviousPerformanceResolver {
  int resolveCount = 0;

  @override
  PreviousPerformanceSnapshot? resolveLatest({
    required String exerciseId,
    List<PreviousPerformanceSnapshot>? records,
    List<ExerciseExecutionResult>? executionResults,
    PreviousPerformanceSessionType? requiredType,
  }) {
    resolveCount += 1;
    return super.resolveLatest(
      exerciseId: exerciseId,
      records: records,
      executionResults: executionResults,
      requiredType: requiredType,
    );
  }
}

class _Harness {
  _Harness(this.draft);

  BlockPerformanceDraft draft;
  var updateCalls = 0;
  var addSetCalls = 0;
  var resultCalls = 0;
}

Future<void> _tapExercise(WidgetTester tester, String name) async {
  final finder = find.text(name);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required BlockPerformanceDraft draft,
  PreviousPerformanceResolver? resolver,
  PreviousStrengthHistoryState? history,
}) async {
  tester.view.physicalSize = const Size(430, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlockResultEditor(
            blockDraft: draft,
            linkedExercises:
                (draft.sourceBlockId == 'paired-upper'
                        ? _pairedUpper()
                        : _apolloUpper())
                    .linkedExercises,
            previousPerformanceResolver:
                resolver ?? const PreviousPerformanceResolver(),
            previousStrengthHistory: history,
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
}

Future<void> _pumpHarness(WidgetTester tester, _Harness harness) async {
  tester.view.physicalSize = const Size(430, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: BlockResultEditor(
                blockDraft: harness.draft,
                linkedExercises: _apolloUpper().linkedExercises,
                onResultChanged: (_) => harness.resultCalls += 1,
                onAddSet: (_) => harness.addSetCalls += 1,
                onUpdateSet: (exerciseId, setResultId, update) {
                  harness.updateCalls += 1;
                  setState(() {
                    harness.draft = _applySet(
                      harness.draft,
                      exerciseId,
                      (set) =>
                          set.setResultId == setResultId ? update(set) : set,
                    );
                  });
                },
                onDuplicateSet: (_, _) {},
                onRemoveSet: (_, _) {},
                onOpenExercise: (_) {},
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BlockPerformanceDraft _initialDraft({bool paired = false}) {
  final block = paired ? _pairedUpper() : _apolloUpper();
  return const PerformanceSnapshotBuilder()
      .buildInitialBlockDrafts(
        SessionExecutionPlan(
          sessionId: 'apollo-w1-mon',
          sessionTitle: 'Apollo W1 Upper',
          blocks: [block],
        ),
      )
      .single;
}

BlockPerformanceDraft _resumeDraft({
  bool completeFirst = false,
  bool completeAll = false,
}) {
  var draft = _initialDraft();
  if (completeAll) {
    for (final exercise in draft.exerciseResults) {
      draft = _completeExercise(draft, exercise.sourceExerciseId);
    }
    return draft;
  }
  if (completeFirst) {
    return _completeExercise(draft, 'EX-095');
  }
  return draft;
}

BlockPerformanceDraft _completeExercise(
  BlockPerformanceDraft draft,
  String exerciseId,
) {
  return _applySet(
    draft,
    exerciseId,
    (set) => set.copyWith(completed: true, reps: 6, load: 10),
  );
}

BlockPerformanceDraft _applySet(
  BlockPerformanceDraft draft,
  String exerciseId,
  SetPerformanceDraft Function(SetPerformanceDraft) update,
) {
  return draft.copyWith(
    exerciseResults: [
      for (final exercise in draft.exerciseResults)
        if (exercise.sourceExerciseId != exerciseId)
          exercise
        else
          exercise.copyWith(
            sets: [for (final set in exercise.sets) update(set)],
          ),
    ],
  );
}

SessionExecutionBlock _apolloUpper() {
  return const SessionExecutionBlock(
    blockId: 'apollo-w1-upper',
    title: 'Upper Strength',
    blockType: SessionBlockType.strength,
    content: '',
    workoutFormat: WorkoutFormat.none,
    position: 1,
    linkedExercises: [
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-095',
        displayName: 'Weighted Pull-Up',
        prescription: StrengthExercisePrescription(
          sets: 4,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 5,
            maxReps: 6,
          ),
          restSeconds: 180,
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-136',
        displayName: 'Incline Barbell Bench Press',
        prescription: StrengthExercisePrescription(
          sets: 4,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 6,
            maxReps: 8,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-078',
        displayName: 'Romanian Deadlift',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 8,
            maxReps: 10,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-CARRY',
        displayName: 'Farmer Carry',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.distance,
            text: '40 m',
          ),
          prescribedDistanceText: '40 m',
          performanceCapture: ExercisePerformanceCapture(
            loadUnit: 'kg',
            loadLabel: 'Load per hand',
            distanceUnit: 'm',
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-139',
        displayName: 'Overhead Cable Triceps Extension',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 10,
            maxReps: 12,
          ),
        ),
      ),
    ],
  );
}

SessionExecutionBlock _pairedUpper() {
  return const SessionExecutionBlock(
    blockId: 'paired-upper',
    title: 'Upper Strength',
    blockType: SessionBlockType.strength,
    content: '',
    workoutFormat: WorkoutFormat.none,
    position: 1,
    linkedExercises: [
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-095',
        displayName: 'Weighted Pull-Up',
        executionGroupKey: 'upper-pair',
        executionGroupLabel: 'Upper pair',
        executionGroupRounds: 3,
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.exact,
            exactReps: 6,
          ),
          groupId: 'pair-1',
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-136',
        displayName: 'Incline Barbell Bench Press',
        executionGroupKey: 'upper-pair',
        executionGroupLabel: 'Upper pair',
        executionGroupRounds: 3,
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.exact,
            exactReps: 8,
          ),
          groupId: 'pair-1',
        ),
      ),
    ],
  );
}
