import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_screen.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'programme_first_controller_test.dart' show changed, selection;
import 'synthetic_composition_screen_test.dart' show ConsumptionRaceController;
import 'synthetic_strength_lineages_test.dart' show createB;

Future<SyntheticCompositionController> mount(
  WidgetTester t, {
  Size size = const Size(1300, 1000),
  double scale = 1,
  SyntheticCompositionController? supplied,
}) async {
  await t.binding.setSurfaceSize(size);
  addTearDown(() => t.binding.setSurfaceSize(null));
  final c = supplied ?? SyntheticCompositionController();
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
      home: SyntheticCompositionScreen(controller: c),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

Future<void> tap(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pumpAndSettle();
}

Finder field(String id) => find.byWidgetPredicate(
  (w) => w is TextFormField && w.key.toString().contains(id),
);
void main() {
  testWidgets(
    'author edits, saves without selecting, cancels, deliberately uses and reviews exact dose, exports and reopens read-only',
    (t) async {
      final c = await mount(t);
      expect(find.text('Edit session'), findsOneWidget);
      expect(find.text('Using Version 1 here'), findsOneWidget);
      await tap(t, find.text('Edit session'));
      await t.ensureVisible(field('exercise-0-reps'));
      await t.enterText(field('exercise-0-reps'), '');
      await tap(t, find.text('Save new version'));
      expect(
        find.text('Enter a positive whole number of reps.'),
        findsOneWidget,
      );
      expect(c.session.revisions.length, 1);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      await t.enterText(field('exercise-0-reps'), '6');
      await tap(t, find.text('Save new version'));
      expect(c.session.revisions.length, 2);
      expect(c.admitted.length, 1);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(
        find.textContaining('excluded from complete review export'),
        findsOneWidget,
      );
      final r = c.session.revisions.last;
      final use = find.byKey(Key('use-version-${revisionKey(r.identity)}'));
      await tap(t, use);
      expect(find.text('Use Version 2 here?'), findsOneWidget);
      expect(find.text('Week 1 · Day 1 · Workout 1'), findsWidgets);
      await tap(t, find.text('Keep current version'));
      expect(c.admitted.length, 1);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      await tap(t, find.text('Choose version'));
      await tap(t, use);
      await tap(t, find.text('Use version here'));
      expect(c.admitted.length, 2);
      expect(selection(c), 'SYN-D2-STRENGTH-R2');
      expect(find.text('Using Version 2 here'), findsOneWidget);
      await tap(t, find.text('Review programme').first);
      expect(find.textContaining('6 reps'), findsWidgets);
      await t.pageBack();
      await t.pumpAndSettle();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tap(t, find.text('Export complete review'));
      expect(find.textContaining('including unused versions'), findsOneWidget);
      expect(
        find.textContaining(
          'Included: Synthetic strength session · Session A · Version 1',
        ),
        findsOneWidget,
      );
      await tap(t, find.text('Copy review export'));
      expect(copied, isNotNull);
      expect(jsonDecode(copied!)['sessions'].length, 2);
      final live = c.programme.draftSource, owner = c.session;
      await tap(t, find.text('Open exported review'));
      await t.enterText(
        find.widgetWithText(TextField, 'Paste review export'),
        copied!,
      );
      await tap(t, find.text('Open read-only review'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('Read-only exported review'), findsWidgets);
      expect(find.textContaining('6 reps'), findsWidgets);
      expect(c.programme.draftSource, live);
      expect(c.session, same(owner));
      expect(c.reconstructedExport(), copied);
      await tap(t, find.text('Included versions (2)'));
      expect(
        find.text('Available in programme, not currently used'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'same-title sessions and private/available/used states stay distinct',
    (t) async {
      final c = await mount(t);
      await createB(c);
      final b = c.secondSession.revisions.single;
      await t.pumpAndSettle();
      await tap(t, find.text('Sessions'));
      expect(find.textContaining('Session A · Version 1'), findsOneWidget);
      expect(find.textContaining('Session B · Version 1'), findsOneWidget);
      expect(find.textContaining('Saved here, not added'), findsOneWidget);
      await tap(t, find.text('Add to programme without changing workouts'));
      await tap(t, find.text('Add to programme'));
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(
        find.textContaining('Available in programme, not currently used'),
        findsOneWidget,
      );
      expect(c.admitted.any((s) => sameRevision(s.identity, b.identity)), true);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'open confirmation disables after cross-owner change and cancel leaves both sides unchanged',
    (t) async {
      final c = await mount(t);
      final r = await changed(c);
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version'));
      await tap(t, find.byKey(Key('use-version-${revisionKey(r.identity)}')));
      c.createSecondSession();
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use version here'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('workspace changed. Close'), findsOneWidget);
      await tap(t, find.text('Keep current version'));
      expect(c.admitted.length, 1);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'add workout generates a unique key, cancellation is inert, metadata and existing template survive',
    (t) async {
      final c = await mount(t);
      await tap(t, find.text('Programme details and schedule'));
      await tap(t, find.byKey(const Key('add-slot')));
      expect(find.byKey(const Key('new-slot-key')), findsNothing);
      await tap(t, find.text('Cancel'));
      expect(c.programme.tree!['weeks'][0]['days'][0]['slots'].length, 1);
      await tap(t, find.byKey(const Key('add-slot')));
      await tap(t, find.widgetWithText(FilledButton, 'Add workout'));
      final slots = c.programme.tree!['weeks'][0]['days'][0]['slots'] as List;
      expect(slots.length, 2);
      expect(slots[1]['slot_key'], 'W1D1S2');
      expect(
        slots[1]['completion_expectation'],
        slots[0]['completion_expectation'],
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'stale export copy cannot consume bytes after an unselected owner edit',
    (t) async {
      final c = ConsumptionRaceController();
      await mount(t, supplied: c);
      await createB(c);
      await c.admit(c.secondSession.revisions.single);
      await t.pumpAndSettle();
      await tap(t, find.text('Export complete review'));
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') writes++;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      c.queueEdit = true;
      c.queueSecondOwner = true;
      await tap(t, find.text('Copy review export'));
      expect(writes, 0);
      expect(c.current, null);
      expect(find.text('Review export changed'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'clipboard completion after reset cannot close the stale dialog or announce success',
    (t) async {
      final c = await mount(t);
      final completion = Completer<void>();
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              writes++;
              await completion.future;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tap(t, find.text('Export complete review'));
      await tap(t, find.text('Copy review export'));
      expect(writes, 1);
      await c.reset();
      await t.pumpAndSettle();
      completion.complete();
      await t.pumpAndSettle();
      expect(find.text('Review export changed'), findsOneWidget);
      expect(find.textContaining('Review export copied.'), findsNothing);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large text remains usable with errors, temporary notice and Advanced',
    (t) async {
      await mount(t, size: const Size(390, 844), scale: 2);
      await tap(t, find.text('Edit session'));
      await t.ensureVisible(field('exercise-0-reps'));
      await t.enterText(field('exercise-0-reps'), '');
      await tap(t, find.text('Save new version'));
      expect(
        find.text('Enter a positive whole number of reps.'),
        findsOneWidget,
      );
      await tap(t, find.text('Discard changes'));
      expect(find.text('Using Version 1 here'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid exported input is retained and never replaces live authoring',
    (t) async {
      final c = await mount(t);
      final source = c.programme.draftSource, owner = c.session;
      await tap(t, find.text('Open exported review'));
      await t.enterText(
        find.widgetWithText(TextField, 'Paste review export'),
        'incomplete review',
      );
      await tap(t, find.text('Open read-only review'));
      expect(
        find.textContaining('This review export is incomplete or unsupported.'),
        findsOneWidget,
      );
      expect(c.rejectedHandoff, 'incomplete review');
      expect(c.programme.draftSource, source);
      expect(c.session, same(owner));
      expect(c.reconstructed, null);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'save refuses no-op and discard leaves immutable programme version alone',
    (t) async {
      final c = await mount(t);
      final source = c.programme.draftSource;
      await tap(t, find.text('Edit session'));
      await tap(t, find.text('Save new version'));
      expect(
        find.text(
          'No workout changes to save. Make a change or discard this draft.',
        ),
        findsOneWidget,
      );
      expect(c.session.revisions.length, 1);
      await tap(t, find.text('Discard changes'));
      expect(c.programme.draftSource, source);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'schedule add and move confirmations reject changed programme snapshots',
    (t) async {
      final c = await mount(t);
      c.programme.addSlot(0, 0, 'W1D1S2', 'SYN-D2-STRENGTH-R1');
      await t.pumpAndSettle();
      await tap(t, find.text('Programme details and schedule'));
      await tap(t, find.byKey(const Key('add-slot')));
      c.programme.editProgramme('name', 'Changed during add');
      await t.pumpAndSettle();
      final beforeAdd = c.programme.draftSource;
      await tap(t, find.widgetWithText(FilledButton, 'Add workout'));
      expect(c.programme.draftSource, beforeAdd);
      await tap(t, find.text('Move / reorder').first);
      c.programme.editProgramme('name', 'Changed during move');
      await t.pumpAndSettle();
      final beforeMove = c.programme.draftSource;
      await tap(t, find.text('Confirm move'));
      expect(c.programme.draftSource, beforeMove);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('exercise consent expires when the other owner changes', (
    t,
  ) async {
    final c = await mount(t);
    await tap(t, find.text('Edit session'));
    final picker = find.byWidgetPredicate(
      (w) =>
          w is DropdownButton<String> &&
          w.key.toString().contains('exercise-0-picker'),
    );
    await tap(t, picker);
    await tap(t, find.text('Synthetic fixture B').last);
    expect(find.text('Use this exercise?'), findsOneWidget);
    c.secondSession.createRootDraft();
    await t.pumpAndSettle();
    await tap(t, find.text('Confirm'));
    expect(
      c
          .session
          .tree!['weeks'][0]['days'][0]['sessions'][0]['blocks'][0]['exercises'][0]['transitional_exercise_id'],
      'cohort.exercise.d2_fixture_a',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('reset consent does not discard a changed workspace', (t) async {
    final c = await mount(t);
    await changed(c);
    await t.pumpAndSettle();
    await tap(t, find.text('Reset example'));
    c.programme.editProgramme('name', 'Keep these changes');
    await t.pumpAndSettle();
    await tap(t, find.text('Discard workspace'));
    expect(c.session.revisions.length, 2);
    expect(c.programme.tree!['programme']['name'], 'Keep these changes');
    expect(t.takeException(), isNull);
  });
}
