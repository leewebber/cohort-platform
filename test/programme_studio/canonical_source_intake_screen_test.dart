import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_screen.dart';
import 'programme_first_screen_test.dart' show tap, field;

void main() {
  Future<SyntheticCompositionController> mount(
    WidgetTester t, {
    required Future<Uint8List?> Function() choose,
    void Function(String)? save,
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
          chooseSources: choose,
          downloadWorkspace: save ?? (_) {},
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  Future<Uint8List> archive() async {
    final c = SyntheticCompositionController();
    await c.ready;
    try {
      expect(await c.validate(), true);
      return Uint8List.fromList(
        CanonicalSourceBundle.fromReview(c.current!).archiveBytes,
      );
    } finally {
      c.dispose();
    }
  }

  testWidgets(
    'source intake is distinct, cancellable, then creates owned snapshots and editable v3 file',
    (t) async {
      final bytes = await archive();
      String? saved;
      final c = await mount(
        t,
        choose: () async => bytes,
        save: (s) => saved = s,
      );
      expect(find.text('Open canonical sources'), findsOneWidget);
      expect(find.text('Open editable workspace'), findsOneWidget);
      expect(find.text('Open exported review'), findsOneWidget);
      expect(await c.validate(), true);
      await t.pumpAndSettle();
      final before = c.workspaceContents,
          owner = c.session,
          receipt = c.current;
      await tap(t, find.text('Open canonical sources'));
      expect(find.text('Replace with canonical sources?'), findsOneWidget);
      expect(find.textContaining('no inferred parent'), findsOneWidget);
      expect(c.workspaceContents, before);
      expect(c.session, same(owner));
      expect(c.current, same(receipt));
      await tap(t, find.text('Keep current workspace'));
      expect(c.workspaceContents, before);
      expect(c.current, same(receipt));
      await tap(t, find.text('Open canonical sources'));
      await tap(t, find.text('Replace with source workspace'));
      expect(c.hasImportedSnapshots, true);
      expect(c.current, null);
      expect(c.session, isNot(same(owner)));
      expect(find.textContaining('Source-import basis retained'), findsOneWidget);
      await tap(t, find.text('Edit session'));
      await t.ensureVisible(field('exercise-0-reps'));
      await t.enterText(field('exercise-0-reps'), '6');
      await tap(t, find.text('Save new version'));
      await tap(t, find.text('Keep current version'));
      expect(c.session.revisions.length, 2);
      expect(c.admitted.length, 1);
      await tap(t, find.text('Save editable workspace'));
      expect(saved, contains('"version": 3'));
      expect(t.takeException(), null);
    },
  );
  testWidgets(
    'picker cancellation and malformed source errors preserve live workspace and explain correct format',
    (t) async {
      Uint8List? selected;
      final c = await mount(t, choose: () async => selected);
      final before = c.workspaceContents;
      await tap(t, find.text('Open canonical sources'));
      expect(c.workspaceContents, before);
      selected = Uint8List.fromList('not a tar'.codeUnits);
      await tap(t, find.text('Open canonical sources'));
      expect(find.textContaining('Canonical sources refused:'), findsOneWidget);
      expect(
        find.textContaining('complete supported uncompressed Studio TAR'),
        findsOneWidget,
      );
      expect(c.workspaceContents, before);
      expect(t.takeException(), null);
    },
  );
  testWidgets(
    'stale source confirmation disables replacement and keeps current work',
    (t) async {
      final bytes = await archive();
      final c = await mount(t, choose: () async => bytes);
      await tap(t, find.text('Open canonical sources'));
      c.programme.editProgramme('name', 'Synthetic current edit');
      await t.pumpAndSettle();
      final after = c.workspaceContents;
      expect(find.textContaining('Current workspace changed.'), findsOneWidget);
      final action = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Replace with source workspace'),
      );
      expect(action.onPressed, null);
      await tap(t, find.text('Keep current workspace'));
      expect(c.workspaceContents, after);
    },
  );
  testWidgets(
    'source file chosen after a live edit is never prepared or installed',
    (t) async {
      final pending = Completer<Uint8List?>();
      final bytes = await archive();
      final c = await mount(t, choose: () => pending.future);
      await tap(t, find.text('Open canonical sources'));
      c.programme.editProgramme('description', 'Synthetic picker edit');
      final after = c.workspaceContents;
      pending.complete(bytes);
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          'Workspace changed while choosing canonical sources.',
        ),
        findsOneWidget,
      );
      expect(find.text('Replace with canonical sources?'), findsNothing);
      expect(c.workspaceContents, after);
    },
  );
  testWidgets(
    'narrow large text can explain source history and cancel without overflow',
    (t) async {
      final bytes = await archive();
      final c = await mount(
        t,
        choose: () async => bytes,
        size: const Size(390, 844),
        scale: 2,
      );
      final before = c.workspaceContents;
      await tap(t, find.text('Open canonical sources'));
      await tap(t, find.text('Keep current workspace'));
      expect(c.workspaceContents, before);
      expect(t.takeException(), null);
    },
  );
}
