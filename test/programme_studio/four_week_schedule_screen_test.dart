import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'programme_first_screen_test.dart' show mount, tap;
import 'synthetic_strength_lineages_test.dart' show createB;

int count(SyntheticCompositionController c) => [
  for (final w in c.programme.tree!['weeks'])
    for (final d in w['days'])
      for (final s in d['slots']) s,
].length;
void main() {
  testWidgets(
    'setup explains missing second session and does not expand or admit it',
    (t) async {
      final c = await mount(t);
      final before = c.workspaceContents;
      await tap(t, find.byKey(const Key('setup-four-weeks')));
      expect(
        find.textContaining('First create and save synthetic Session B.'),
        findsOneWidget,
      );
      expect(find.text('Create second session'), findsOneWidget);
      expect(c.workspaceContents, before);
    },
  );
  testWidgets(
    'explicit weekdays and setup consent create eight, cancellation and stale dialog do not',
    (t) async {
      final c = await mount(t);
      await createB(c);
      await t.pumpAndSettle();
      final before = c.workspaceContents;
      await tap(t, find.byKey(const Key('setup-four-weeks')));
      expect(find.text('Session A day each week'), findsOneWidget);
      expect(find.text('Session B day each week'), findsOneWidget);
      expect(find.text('Session B exact version'), findsOneWidget);
      await tap(t, find.text('Cancel'));
      expect(c.workspaceContents, before);
      await tap(t, find.byKey(const Key('setup-four-weeks')));
      c.programme.editProgramme('description', 'Synthetic edit during consent');
      final changed = c.workspaceContents;
      await tap(t, find.text('Create eight-workout schedule'));
      expect(c.workspaceContents, changed);
      expect(count(c), 1);
      await tap(t, find.byKey(const Key('setup-four-weeks')));
      await tap(t, find.text('Create eight-workout schedule'));
      expect(count(c), 8);
      expect(c.admitted.length, 2);
      expect(find.text('4 weeks · 8 scheduled workouts'), findsOneWidget);
      expect(find.byKey(const Key('setup-four-weeks')), findsNothing);
      expect(t.takeException(), null);
    },
  );
}
