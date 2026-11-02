import 'dart:convert';

import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace_screen.dart';
import 'package:cohort_platform/features/programme_studio/composition/programme_first_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'genuine_workspace_test.dart' show selectedWorkspace;

void main() {
  testWidgets(
    'ordinary strength controls save actual native draft bytes and explicit open replacement',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      String? saved;
      GenuineWorkspace? replacement;
      await tester.pumpWidget(
        MaterialApp(
          home: ProgrammeFirstScreen.sourcePolicy(
            workspace: GenuineWorkspaceScreen(
              controller: c,
              downloadWorkspace: (text) => saved = text,
              chooseWorkspace: () async => saved,
              replace: (candidate) => replacement = candidate,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sessions'));
      await tester.pump();
      await tester.ensureVisible(find.text('Create later draft'));
      await tester.tap(find.text('Create later draft'));
      await tester.pump();
      final exercise = find.text('Bilateral incline DB press');
      await tester.ensureVisible(exercise);
      await tester.tap(exercise);
      await tester.pumpAndSettle();
      final sets = find
          .byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Sets',
          )
          .first;
      await tester.ensureVisible(sets);
      await tester.enterText(sets, '4');
      await tester.pump();
      expect(
        c
            .owners
            .values
            .first
            .draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        4,
      );
      expect(
        jsonDecode(
          c.owners.values.first.latest.source,
        )['blocks'][1]['exercises'][0]['prescription']['sets'],
        3,
      );
      await tester.tap(find.text('Save editable draft'));
      await tester.pump();
      expect(saved, isNotNull);
      expect(c.unsaved, isFalse);
      await tester.tap(find.text('Open editable draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace workspace'));
      await tester.pumpAndSettle();
      expect(replacement, isNotNull);
      addTearDown(() => replacement?.dispose());
      expect(replacement!.save(), saved);
      expect(tester.takeException(), isNull);
    },
  );
}
