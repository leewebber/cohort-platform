import 'dart:convert';

import 'package:cohort_platform/domain/running_workout/running_workout_codec.dart';
import 'package:cohort_platform/domain/running_workout/running_workout_model.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/builder_theme.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/prescription_presentation.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/structured_prescription_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'genuine_workspace_test.dart' show selectedWorkspace;

void main() {
  test(
    'W4 groups expand into exactly the original typed sequence with different endings',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final g = jsonDecode(c.selected('LW10K-W04-D02').source);
      final run = const RunningWorkoutCodec().decodeMap(
        Map<String, dynamic>.from(
          g['blocks'][0]['timer_config']['running_workout'] as Map,
        ),
      );
      final groups = groupRunningSteps(run.steps);
      expect(groups, hasLength(4));
      expect(groups[1].repetitions, 3);
      expect(groups[1].recoveryAfterLast, isTrue);
      expect(groups[2].repetitions, 4);
      expect(groups[2].recoveryAfterLast, isFalse);
      expect(
        groups[2].steps.where((s) => s.role == RunningStepRole.recovery),
        hasLength(3),
      );
      expect(groups.expand((g) => g.steps), orderedEquals(run.steps));
      expect(
        groups
            .expand((g) => g.steps)
            .fold<int>(0, (n, s) => n + s.duration.milliseconds!),
        2550000,
      );
    },
  );
  test(
    'changed cues, targets or labels never get collapsed into a different prescription',
    () {
      RunningAtomicStep work(String id, {String notes = 'easy'}) =>
          RunningAtomicStep(
            stepId: id,
            role: RunningStepRole.work,
            duration: const RunningDuration.time(20000),
            notes: notes,
          );
      const recovery = RunningAtomicStep(
        stepId: 'r',
        role: RunningStepRole.recovery,
        duration: RunningDuration.time(40000),
      );
      final original = [
        work('a'),
        recovery,
        work('b'),
        recovery,
        work('c', notes: 'different'),
        recovery,
      ];
      final groups = groupRunningSteps(original);
      expect(groups.expand((g) => g.steps), orderedEquals(original));
      expect(groups.first.repetitions, 2);
      expect(groups.skip(1).every((g) => !g.repeated), isTrue);
    },
  );
  test(
    'all 40 running presentations preserve every typed step and final 10K distance',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      for (final o in c.owners.values) {
        final blocks = jsonDecode(o.latest.source)['blocks'] as List;
        for (final b in blocks.where((b) => b['timer_config'] != null)) {
          final run = const RunningWorkoutCodec().decodeMap(
            Map<String, dynamic>.from(
              b['timer_config']['running_workout'] as Map,
            ),
          );
          expect(
            groupRunningSteps(run.steps).expand((g) => g.steps),
            orderedEquals(run.steps),
          );
        }
      }
    },
  );
  Future<void> preview(
    WidgetTester tester,
    Map<String, dynamic> graph,
    String title,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: founderBuilderTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructuredPrescriptionPreview(source: graph, title: title),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'strength has ordered warm-up, five movement cards, typed doses and expandable cues',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final r = c.selected('LW10K-W01-D01');
      final graph = jsonDecode(r.source) as Map<String, dynamic>;
      final before = jsonEncode(graph);
      await preview(tester, graph, r.title);
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('5 minutes walking/marching'), findsOneWidget);
      expect(find.text('3 × 6–10'), findsOneWidget);
      expect(find.text('Bilateral chest-supported DB row'), findsOneWidget);
      expect(find.text('Load'), findsNWidgets(5));
      expect(find.text('RIR'), findsNWidgets(5));
      expect(find.textContaining('D8'), findsNothing);
      expect(find.textContaining('setup: unknown'), findsNothing);
      expect(find.textContaining('Unresolved exercise setup'), findsNothing);
      expect(jsonEncode(graph), before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'running is compact, retains useful effort and renders aliased notes once',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final r = c.selected('LW10K-W04-D02');
      final graph = jsonDecode(r.source) as Map<String, dynamic>;
      await preview(tester, graph, r.title);
      expect(find.text('Total 42:30'), findsOneWidget);
      expect(find.textContaining('3 × 20 sec'), findsOneWidget);
      expect(find.textContaining('4 × 5 min'), findsOneWidget);
      expect(
        find.textContaining('Recovery between repetitions only (3 recoveries)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('including the final one (3 recoveries)'),
        findsOneWidget,
      );
      expect(find.text('Personalised threshold pace'), findsOneWidget);
      expect(find.textContaining('RPE 7/10'), findsOneWidget);
      expect(
        find.textContaining('No extra mandatory walk before or after'),
        findsOneWidget,
      );
      expect(find.textContaining('Authored effort'), findsNothing);
      expect(find.textContaining('founder-selected'), findsNothing);
      expect(find.textContaining('M2.3'), findsNothing);
      expect(find.textContaining('D8'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown coaching notes and missing metadata are retained without unknown placeholders',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final graph =
          jsonDecode(c.selected('LW10K-W04-D02').source)
              as Map<String, dynamic>;
      graph['blocks'][0]['coach_notes'] = 'A distinct coaching instruction.';
      graph['blocks'][0]['timer_config']['running_workout']['notes'] =
          'Use the shaded route.';
      await preview(tester, graph, 'Custom');
      expect(find.text('A distinct coaching instruction.'), findsOneWidget);
      expect(find.text('Use the shaded route.'), findsOneWidget);
      expect(find.textContaining('unknown'), findsNothing);
    },
  );
  test(
    'fresh W1 Tue/Wed/Fri are actual one-step 25-minute selected sources',
    () {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      for (final day in ['02', '03', '05']) {
        final g = jsonDecode(c.selected('LW10K-W01-D$day').source);
        final run = const RunningWorkoutCodec().decodeMap(
          Map<String, dynamic>.from(
            g['blocks'][0]['timer_config']['running_workout'] as Map,
          ),
        );
        expect(run.steps, hasLength(1));
        expect(
          (run.steps.single as RunningAtomicStep).duration,
          const RunningDuration.time(1500000),
        );
      }
    },
  );
  testWidgets('timed per-side hold is printed once with source conventions', (
    tester,
  ) async {
    final c = selectedWorkspace();
    addTearDown(c.dispose);
    final r = c.selected('LW10K-W01-D04');
    await preview(
      tester,
      jsonDecode(r.source) as Map<String, dynamic>,
      r.title,
    );
    expect(find.text('2 × 30–45 sec/side'), findsOneWidget);
    expect(find.textContaining('/side / side'), findsNothing);
    expect(
      find.textContaining('External load per dumbbell (kg)'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
