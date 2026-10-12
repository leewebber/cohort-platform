import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_screen.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';

Future<ProtocolAuthoringController> mount(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
  double scale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = ProtocolAuthoringController();
  await controller.ready;
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: cohortTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ProtocolAuthoringScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export refuses an edit triggered by validation completion', (
    tester,
  ) async {
    final c = await mount(tester);
    await tap(tester, 'Create local draft revision');
    c.editExercise(0, 'reps', '6');
    expect(await c.validate(), true);
    await tester.pumpAndSettle();
    var edited = false;
    c.addListener(() {
      if (!edited && c.current != null) {
        edited = true;
        c.editExercise(0, 'reps', '7');
      }
    });
    await tap(tester, 'Export Founder YAML');
    expect(edited, true);
    expect(c.current, isNull);
    expect(find.text('Founder YAML — exact validated bytes'), findsNothing);
    expect(c.revisions.length, 1);
    expect(c.selectedRevision, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'actual editor invalidation, missing title, export/reopen, freeze and explicit selection',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'Validate and refresh review');
      expect(c.current, isNotNull);
      await tap(tester, 'Create local draft revision');
      expect(c.current, isNull);
      final title = find.byKey(const ValueKey('1-session-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, '');
      await tap(tester, 'Validate and refresh review');
      expect(c.current, isNull);
      expect(find.textContaining('session.title'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Export Founder YAML'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Synthetic edited session');
      await tap(tester, 'Validate and refresh review');
      expect(c.current, isNotNull);
      await tap(tester, 'Export Founder YAML');
      expect(find.text('Founder YAML — exact validated bytes'), findsOneWidget);
      await tap(tester, 'Close');
      await tap(tester, 'Reopen Founder YAML');
      await tap(tester, 'Reopen source');
      expect(c.current, isNull);
      expect(await c.validate(), true);
      await tester.pumpAndSettle();
      await tap(tester, 'Freeze local revision');
      expect(c.selectedRevision, 1);
      expect(c.revisions.length, 2);
      expect(c.isEditing, false);
      await tap(tester, 'Select for programme');
      await tap(tester, 'Cancel');
      expect(c.selectedRevision, 1);
      await tap(tester, 'Select for programme');
      await tap(tester, 'Confirm');
      expect(c.selectedRevision, 2);
      expect(c.current, isNotNull);
      expect(c.revisions.first.source, d2R1Source());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'existing Studio review reads kg, bodyweight, RPE and tempo from typed data',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'Validate and refresh review');
      await tap(tester, 'Open Studio review');
      expect(find.textContaining('12.5 kg'), findsWidgets);
      expect(find.text('Tempo 3-1-1'), findsOneWidget);
      expect(find.textContaining('Rest 1 min'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      c.createDraft();
      c.setLoadMode(0, 'rpe');
      c.editLoadValue(0, '7');
      c.setLoadMode(1, 'bodyweight');
      expect(await c.validate(), true);
      await tester.pumpAndSettle();
      await tap(tester, 'Open Studio review');
      expect(find.text('RPE 7'), findsOneWidget);
      expect(find.textContaining('Bodyweight'), findsWidgets);
      c.editExercise(0, 'reps', '6');
      await tester.pumpAndSettle();
      expect(find.text('Review invalidated'), findsOneWidget);
      expect(find.text('RPE 7'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'open export clears its successful bytes when source is invalidated',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'Create local draft revision');
      c.editExercise(0, 'reps', '6');
      expect(await c.validate(), true);
      await tester.pumpAndSettle();
      await tap(tester, 'Export Founder YAML');
      c.editSession('title', '');
      await tester.pumpAndSettle();
      expect(find.text('Export invalidated'), findsOneWidget);
      expect(find.text('Founder YAML — exact validated bytes'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Copy validated bytes'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow and large-text editor survives errors, reset and removal confirmation',
    (tester) async {
      final c = await mount(tester, size: const Size(390, 844), scale: 2);
      await tap(tester, 'Create local draft revision');
      expect(tester.takeException(), isNull);
      final title = find.byKey(const ValueKey('1-session-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, '');
      await tap(tester, 'Validate and refresh review');
      expect(c.current, isNull);
      await tap(tester, 'Reset to source revision');
      expect(c.source, contains('Synthetic strength session'));
      await tap(tester, 'Remove exercise');
      await tap(tester, 'Cancel');
      expect(c.tree, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
