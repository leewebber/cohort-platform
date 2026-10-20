import 'dart:async';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/apollo_pilot/apollo_pilot.dart';
import 'package:cohort_platform/features/programme_studio/apollo_pilot/apollo_pilot_pin.dart';
import 'package:cohort_platform/features/programme_studio/apollo_pilot/apollo_pilot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const key2 = '${ApolloPilotSource.strengthBlock}/2/EX-079';
void main() {
  late ApolloPilotSource source;
  setUpAll(
    () => source = ApolloPilotSource.read({
      for (final p in ApolloPilotPin.files.keys) p: File(p).readAsStringSync(),
    }),
  );
  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text);
    if (f.evaluate().isEmpty) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 12000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        f,
        150,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'full local review edit freeze confirm export and editable reopen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ApolloPilotController(source);
      final files = <String>[];
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: ApolloPilotScreen(
            controller: c,
            saveFile: files.add,
            openFile: () async => opened,
          ),
        ),
      );
      expect(find.text(ApolloPilotSource.target), findsOneWidget);
      expect(
        find.text('Locally selected: LOCAL-APOLLO-W4-SAT-R1'),
        findsOneWidget,
      );
      final edit = find.byKey(const ValueKey('$key2/sets'));
      await tester.scrollUntilVisible(
        edit,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(edit), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4');
      await tap(tester, 'Apply edit');
      await tap(tester, 'Save new local revision');
      expect(c.revisions.length, 2);
      expect(c.selected.number, 1);
      await tap(tester, 'Use R2…');
      expect(find.text('Use this version…'), findsOneWidget);
      expect(
        find.textContaining('Current: LOCAL-APOLLO-W4-SAT-R1'),
        findsOneWidget,
      );
      expect(find.textContaining('Proposed: 4 sets'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(c.selected.number, 1);
      await tap(tester, 'Use R2…');
      await tap(tester, 'Confirm local selection');
      expect(c.selected.number, 2);
      await tap(tester, 'Save editable pilot');
      opened = files.last;
      await tap(tester, 'Export R2 source');
      final (_, compiled) = ApolloPilotSource.recompileCanonical(files.last);
      expect(compiled.digest, c.selected.digest);
      final editable = opened;
      opened = files.last;
      await tap(tester, 'Recompile pilot source');
      expect(
        find.textContaining('Source recompiled: LOCAL-APOLLO-W4-SAT-R2'),
        findsOneWidget,
      );
      opened = editable;
      await tap(tester, 'Open editable pilot');
      expect(
        find.textContaining('Validated 2 local revisions'),
        findsOneWidget,
      );
      await tap(tester, 'Replace local workspace');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 12000));
      await tester.pumpAndSettle();
      expect(
        find.text('Locally selected: LOCAL-APOLLO-W4-SAT-R2'),
        findsOneWidget,
      );
      await tap(tester, 'Save editable pilot');
      expect(files.last, opened);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'stale selection modal refuses with visible error and no selection',
    (tester) async {
      final c = ApolloPilotController(source);
      c.edit(key2, 'sets', '4');
      c.freeze();
      await tester.pumpWidget(
        MaterialApp(home: ApolloPilotScreen(controller: c)),
      );
      await tap(tester, 'Use R2…');
      c.edit(key2, 'rir', '2');
      await tap(tester, 'Confirm local selection');
      expect(c.selected.number, 1);
      expect(find.textContaining('Workspace changed.'), findsOneWidget);
    },
  );
  testWidgets(
    'file picker cancellation malformed file and replacement cancellation preserve state',
    (tester) async {
      final c = ApolloPilotController(source);
      final before = c.saveWorkspace();
      String? file;
      await tester.pumpWidget(
        MaterialApp(
          home: ApolloPilotScreen(controller: c, openFile: () async => file),
        ),
      );
      await tap(tester, 'Open editable pilot');
      expect(c.saveWorkspace(), before);
      file = '{}';
      await tap(tester, 'Open editable pilot');
      expect(c.saveWorkspace(), before);
      expect(find.byKey(const ValueKey('pilot-error')), findsOneWidget);
      file = before;
      await tap(tester, 'Open editable pilot');
      await tap(tester, 'Cancel');
      expect(c.saveWorkspace(), before);
    },
  );
  testWidgets(
    'change then revert while preparing file invalidates atomic replacement',
    (tester) async {
      final c = ApolloPilotController(source);
      final pending = Completer<String?>();
      final saved = c.saveWorkspace();
      await tester.pumpWidget(
        MaterialApp(
          home: ApolloPilotScreen(
            controller: c,
            openFile: () => pending.future,
          ),
        ),
      );
      await tester.tap(find.text('Open editable pilot'));
      await tester.pump();
      c.edit(key2, 'sets', '4');
      c.edit(key2, 'sets', '2');
      pending.complete(saved);
      await tester.pumpAndSettle();
      await tap(tester, 'Replace local workspace');
      expect(find.textContaining('Workspace changed.'), findsOneWidget);
      expect(c.saveWorkspace(), saved);
    },
  );
  testWidgets(
    'edit preparation and open confirmation both reject later changes',
    (tester) async {
      final c = ApolloPilotController(source);
      final saved = c.saveWorkspace();
      await tester.pumpWidget(
        MaterialApp(
          home: ApolloPilotScreen(controller: c, openFile: () async => saved),
        ),
      );
      final edit = find.byKey(const ValueKey('$key2/reps'));
      await tester.scrollUntilVisible(
        edit,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(edit), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5-7');
      c.edit(key2, 'sets', '4');
      await tap(tester, 'Apply edit');
      expect(find.textContaining('Workspace changed.'), findsOneWidget);
      expect(c.draft[key2]!.containsKey('reps'), isFalse);
      await tap(tester, 'Cancel');
      await tap(tester, 'Open editable pilot');
      c.edit(key2, 'rir', '2');
      final before = c.saveWorkspace();
      await tap(tester, 'Replace local workspace');
      expect(find.textContaining('Workspace changed.'), findsOneWidget);
      expect(c.saveWorkspace(), before);
    },
  );
  testWidgets(
    'complete read-only warmup and distance stay readable at narrow size',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ApolloPilotScreen(controller: ApolloPilotController(source)),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Duration: 5 min'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Duration: 5 min'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Distance: 30 m'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Distance: 30 m'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
