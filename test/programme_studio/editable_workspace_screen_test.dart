import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_screen.dart';
import 'programme_first_screen_test.dart' show tap, field;

void main() {
  Future<SyntheticCompositionController> mount(
    WidgetTester t, {
    required void Function(String) download,
    required Future<String?> Function() choose,
    Size size = const Size(1300, 1000),
    double scale = 1,
  }) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    final c = SyntheticCompositionController();
    await c.ready;
    addTearDown(c.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SyntheticCompositionScreen(
          controller: c,
          downloadWorkspace: download,
          chooseWorkspace: choose,
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  testWidgets(
    'save invalid draft, open separately/cancel, replace, correct and continue immutable authoring',
    (t) async {
      String? saved;
      final c = await mount(
        t,
        download: (s) => saved = s,
        choose: () async => saved,
      );
      expect(find.text('Workspace file not saved yet.'), findsOneWidget);
      await tap(t, find.text('Edit session'));
      await t.enterText(field('exercise-0-reps'), 'bad reps');
      await tap(t, find.text('Save editable workspace'));
      expect(saved, isNotNull);
      expect(c.session.isEditing, true);
      expect(c.session.revisions.length, 1);
      expect(
        find.textContaining('Editable workspace download requested.'),
        findsWidgets,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      final owners = c.owners;
      final before = c.workspaceContents;
      await tap(t, find.text('Open editable workspace'));
      expect(find.text('Replace current workspace?'), findsOneWidget);
      expect(c.owners, owners);
      expect(c.workspaceContents, before);
      await tap(t, find.text('Keep current workspace'));
      expect(c.owners, owners);
      await tap(t, find.text('Open editable workspace'));
      await tap(t, find.text('Replace current workspace'));
      expect(c.owners.first, same(c.session));
      expect(c.session, isNot(same(owners.first)));
      expect(c.current, null);
      expect(find.text('Continue session changes'), findsOneWidget);
      await tap(t, find.text('Continue session changes'));
      expect(
        (t.widget<TextFormField>(field('exercise-0-reps'))).initialValue,
        'bad reps',
      );
      await t.enterText(field('exercise-0-reps'), '6');
      await tap(t, find.text('Save new version'));
      expect(c.session.revisions.length, 2);
      expect(c.admitted.length, 1);
      await tap(t, find.text('Programme'));
      await tap(t, find.text('Save editable workspace'));
      expect(saved, contains('cohort_editable_workspace'));
      expect(c.workspaceHasChanges, false);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelled picker and rejected review packet leave live state unchanged',
    (t) async {
      String? chosen;
      final c = await mount(t, download: (_) {}, choose: () async => chosen);
      final before = c.workspaceContents;
      await tap(t, find.text('Open editable workspace'));
      expect(c.workspaceContents, before);
      chosen = await c.exportHandoff();
      final receipt = c.current;
      await tap(t, find.text('Open editable workspace'));
      expect(
        find.textContaining('Current work was not replaced.'),
        findsOneWidget,
      );
      expect(c.workspaceContents, before);
      expect(c.current, same(receipt));
      expect(find.text('Advanced: workspace file error'), findsOneWidget);
    },
  );
  testWidgets('confirmation becomes invalid after current owner changes', (
    t,
  ) async {
    late String chosen;
    final c = await mount(t, download: (_) {}, choose: () async => chosen);
    chosen = c.workspaceContents;
    await tap(t, find.text('Open editable workspace'));
    c.createSecondSession();
    await t.pumpAndSettle();
    final confirm = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Replace current workspace'),
    );
    expect(confirm.onPressed, null);
    expect(find.textContaining('Current workspace changed.'), findsOneWidget);
    await tap(t, find.text('Keep current workspace'));
    expect(c.secondSession.isCreatingRoot, true);
  });
  testWidgets('file picker completion after an edit is stale', (t) async {
    final picker = Completer<String?>();
    final c = await mount(t, download: (_) {}, choose: () => picker.future);
    final seed = c.workspaceContents;
    await tap(t, find.text('Open editable workspace'));
    c.programme.editProgramme('name', 'Do not replace me');
    picker.complete(seed);
    await t.pumpAndSettle();
    expect(find.text('Replace current workspace?'), findsNothing);
    expect(c.programme.tree!['programme']['name'], 'Do not replace me');
    expect(
      find.textContaining('Workspace changed while choosing a file.'),
      findsOneWidget,
    );
  });
  testWidgets('download callback reset cannot mark old workspace saved', (
    t,
  ) async {
    late SyntheticCompositionController c;
    c = await mount(
      t,
      download: (_) {
        c.reset();
      },
      choose: () async => null,
    );
    await tap(t, find.text('Save editable workspace'));
    expect(c.workspaceSaveRequested, false);
    expect(
      find.textContaining('Editable workspace download requested.'),
      findsNothing,
    );
  });
  testWidgets('narrow large-text workspace controls remain usable', (t) async {
    String? saved;
    await mount(
      t,
      download: (s) => saved = s,
      choose: () async => saved,
      size: const Size(390, 844),
      scale: 2,
    );
    await tap(t, find.text('Save editable workspace'));
    expect(saved, isNotNull);
    await tap(t, find.text('Open editable workspace'));
    await tap(t, find.text('Keep current workspace'));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'reset clears transient file error and returns to an unsaved clean seed',
    (t) async {
      final c = await mount(
        t,
        download: (_) {},
        choose: () async => '{"kind":"not editable"}',
      );
      await tap(t, find.text('Open editable workspace'));
      expect(find.text('Advanced: workspace file error'), findsOneWidget);
      await tap(t, find.text('Reset example'));
      await tap(t, find.text('Discard workspace'));
      expect(find.text('Advanced: workspace file error'), findsNothing);
      expect(c.workspaceSaveRequested, false);
      expect(c.session.revisions.length, 1);
    },
  );
}
