import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'programme_first_screen_test.dart' show mount, tap;
import 'programme_first_controller_test.dart' show changed, selection;
import 'synthetic_strength_lineages_test.dart'
    show createB, DeferredLineageCompiler;
import 'four_week_schedule_test.dart' show setup, choices;

void main() {
  testWidgets(
    'confirmation shows semantic fields, exact occurrence and optional evidence; cancellation is inert',
    (t) async {
      final c = await mount(t);
      await createB(c);
      await setup(c);
      c.session.createDraft();
      c.session.editExercise(0, 'reps', '6');
      c.session.editExercise(0, 'rest_seconds', '');
      c.session.editExercise(0, 'tempo', '2-0-2');
      c.session.editExercise(0, 'notes', 'Different synthetic cue');
      expect(await c.session.freeze(), true);
      final original = choices(c), admitted = c.admitted;
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version').first);
      await tap(
        t,
        find.byKey(
          Key('use-version-${revisionKey(c.session.revisions.last.identity)}'),
        ),
      );
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Week 1 · Day 1 · Workout 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Session A · Version 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            'Synthetic strength session · Session A · Version 2',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Prescription changes'), findsOneWidget);
      expect(find.text('Before: 5'), findsOneWidget);
      expect(find.text('After: 6'), findsOneWidget);
      expect(find.text('After: Unspecified'), findsOneWidget);
      expect(find.text('After: “2-0-2”'), findsOneWidget);
      expect(find.text('After: “Different synthetic cue”'), findsOneWidget);
      expect(find.textContaining('Shared occurrences retain'), findsOneWidget);
      expect(
        find.textContaining('Keep their current version: Week 2'),
        findsOneWidget,
      );
      expect(find.textContaining('Source SHA-256:'), findsNothing);
      await tap(t, find.text('Advanced source identities'));
      expect(find.textContaining('Source SHA-256:'), findsNWidgets(2));
      await tap(t, find.text('Keep current version'));
      expect(choices(c), original);
      expect(c.admitted, admitted);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('metadata-only title and notes changes stay descriptive', (
    t,
  ) async {
    final c = await mount(t);
    c.session.createDraft();
    c.session.editSession('title', 'Renamed synthetic session');
    c.session.editBlock('coach_notes', 'Changed block note');
    expect(await c.session.freeze(), true);
    await t.pumpAndSettle();
    await tap(t, find.text('Choose version'));
    await tap(
      t,
      find.byKey(
        Key('use-version-${revisionKey(c.session.revisions.last.identity)}'),
      ),
    );
    expect(find.text('Metadata only — no prescription change'), findsOneWidget);
    expect(find.text('Before: “Synthetic strength session”'), findsOneWidget);
    expect(find.text('After: “Renamed synthetic session”'), findsOneWidget);
    expect(find.text('After: “Changed block note”'), findsOneWidget);
    await tap(t, find.text('Use version here'));
    expect(selection(c), 'SYN-D2-STRENGTH-R2');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'same-title lineages compare exact exercise identity, never title',
    (t) async {
      final c = await mount(t);
      await createB(c);
      c.programme.addSlot(0, 0, 'W1D1S2', 'SYN-D2-STRENGTH-R1');
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version').last);
      await tap(
        t,
        find.byKey(
          Key(
            'use-version-${revisionKey(c.secondSession.revisions.single.identity)}',
          ),
        ),
      );
      expect(find.text('Prescription changes'), findsOneWidget);
      expect(
        find.textContaining('Exercise 1 · Exercise removed'),
        findsOneWidget,
      );
      expect(find.textContaining('Exercise 1 · Sets'), findsOneWidget);
      expect(find.textContaining('Session A · Version 1'), findsWidgets);
      expect(find.textContaining('Session B · Version 1'), findsWidgets);
      await tap(t, find.text('Keep current version'));
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(c.admitted.length, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('selecting the same exact version explains no change', (t) async {
    final c = await mount(t);
    await tap(t, find.text('Choose version'));
    await tap(
      t,
      find.byKey(
        Key('use-version-${revisionKey(c.session.revisions.single.identity)}'),
      ),
    );
    expect(
      find.text('No prescription or session metadata change'),
      findsOneWidget,
    );
    await tap(t, find.text('Use version here'));
    expect(c.admitted.length, 1);
    expect(selection(c), 'SYN-D2-STRENGTH-R1');
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'moved occurrence invalidates displayed comparison and disables confirmation',
    (t) async {
      final c = await mount(t);
      final r = await changed(c);
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version'));
      await tap(t, find.byKey(Key('use-version-${revisionKey(r.identity)}')));
      c.programme.setDayType(0, 1, 'training');
      c.programme.moveSlot(0, 0, 0, 0, 1, 0);
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
      expect(find.text('After: 6'), findsNothing);
      await tap(t, find.text('Keep current version'));
      expect(c.admitted.length, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'verification failure shows unavailable comparison without admission or selection',
    (t) async {
      final compiler = DeferredLineageCompiler();
      final supplied = SyntheticCompositionController(compiler: compiler);
      final c = await mount(t, supplied: supplied);
      final r = await changed(c);
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version'));
      compiler.fail = true;
      compiler.pauseLineage = SyntheticStrengthLineage.a.id;
      await tap(t, find.byKey(Key('use-version-${revisionKey(r.identity)}')));
      compiler.gate!.complete();
      await t.pumpAndSettle();
      expect(find.textContaining('Comparison unavailable.'), findsOneWidget);
      expect(find.text('Use version here'), findsNothing);
      expect(c.admitted.length, 1);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large-text confirmation remains scrollable and cancellable',
    (t) async {
      final c = await mount(t, size: const Size(390, 844), scale: 2);
      final r = await changed(c);
      await t.pumpAndSettle();
      await tap(t, find.text('Choose version'));
      await tap(t, find.byKey(Key('use-version-${revisionKey(r.identity)}')));
      expect(find.text('After: 6'), findsOneWidget);
      await tap(t, find.text('Keep current version'));
      expect(c.admitted.length, 1);
      expect(t.takeException(), isNull);
    },
  );
}
