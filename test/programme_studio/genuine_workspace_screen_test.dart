import 'dart:async';
import 'dart:convert';

import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'package:cohort_platform/features/programme_studio/genuine_authoring/genuine_workspace_screen.dart';
import 'package:cohort_platform/features/programme_studio/composition/programme_first_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'genuine_workspace_test.dart' show selectedWorkspace;

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  GenuineWorkspace c, {
  void Function(String)? download,
  Future<String?> Function()? choose,
  void Function(GenuineWorkspace)? replace,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: ProgrammeFirstScreen.sourcePolicy(
        workspace: GenuineWorkspaceScreen(
          controller: c,
          downloadWorkspace: download ?? (_) {},
          chooseWorkspace: choose ?? () async => null,
          replace: replace ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'coach edits unresolved strength, saves intent, previews and reopens actual backup',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      String? saved;
      GenuineWorkspace? replacement;
      await mount(
        tester,
        c,
        download: (s) => saved = s,
        choose: () async => saved,
        replace: (value) => replacement = value,
      );
      expect(find.text('Programme builder'), findsOneWidget);
      expect(find.text('Create later draft'), findsNothing);
      expect(find.text('Review exact prescriptions'), findsNothing);
      await tapVisible(tester, find.text('Open session').first);
      await tapVisible(tester, find.text('Edit session'));
      await tester.ensureVisible(field('Sets').first);
      await tester.enterText(field('Sets').first, '4');
      await tester.pump();
      await tapVisible(tester, find.text('Save changes'));
      expect(
        find.textContaining('Changes kept in this workspace.'),
        findsOneWidget,
      );
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
      expect(find.text('Save changes'), findsNothing);
      await tapVisible(tester, find.text('Preview as athlete'));
      final text = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('athlete-prescription')).last,
          )
          .data!;
      expect(text, contains('4 ×'));
      expect(find.textContaining('Unpublished changes'), findsWidgets);
      await tapVisible(tester, find.text('Close preview'));
      await tester.tap(find.text('Download backup'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(c.unsaved, isFalse);
      await tester.tap(find.text('Open backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Open backup'));
      await tester.pumpAndSettle();
      expect(replacement, isNotNull);
      addTearDown(() => replacement?.dispose());
      expect(replacement!.save(), saved);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'copy-to-day preserves pending strength and editing copy never changes original',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      await mount(tester, c);
      await tapVisible(tester, find.text('Open session').first);
      await tapVisible(tester, find.text('Edit session'));
      await tester.ensureVisible(field('Sets').first);
      await tester.enterText(field('Sets').first, '4');
      await tapVisible(tester, find.text('Save changes'));
      await tapVisible(tester, find.text('Copy to day'));
      await tapVisible(tester, find.text('Saturday').last);
      await tapVisible(tester, find.text('Confirm'));
      await tapVisible(tester, find.text('Back to programme'));
      final copy = c.occurrences.singleWhere(
        (s) => s['week'] == 1 && s['day'] == 6,
      );
      final buttons = find.text('Open session');
      await tapVisible(tester, buttons.at(5));
      expect(
        c.ownerOf(c.selected(copy['slot_key'] as String)).lineage,
        isNot(c.ownerOf(c.selected('LW10K-W01-D01')).lineage),
      );
      await tapVisible(tester, find.text('Edit session'));
      await tester.ensureVisible(field('Sets').first);
      await tester.enterText(field('Sets').first, '5');
      await tapVisible(tester, find.text('Save changes'));
      expect(
        c
            .ownerOf(c.selected('LW10K-W01-D01'))
            .draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        4,
      );
      expect(
        c
            .ownerOf(c.selected(copy['slot_key'] as String))
            .draft!['blocks'][1]['exercises'][0]['prescription']['sets'],
        5,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'W4 run uses plain target, saves selected occurrence and invalidates an open preview',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      await mount(tester, c);
      await tapVisible(tester, find.text('Week 4'));
      await tapVisible(tester, find.text('Open session').at(1));
      await tapVisible(tester, find.text('Edit session'));
      expect(
        find.text(
          '4 × 5 min — threshold pace, 90 sec easy between.\nPersonalised pace and heart rate use the athlete’s separately confirmed training inputs. No athlete data is entered here.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(field('Session title'));
      await tester.enterText(field('Session title'), 'Threshold review');
      await tapVisible(tester, find.text('Save changes'));
      expect(c.selected('LW10K-W04-D02').title, 'Threshold review');
      expect(
        find.textContaining('Changes saved in this workspace.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Preview as athlete'));
      final readable = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('athlete-prescription')).last,
          )
          .data!;
      expect(readable, contains('42:30'));
      expect(readable, contains('Personalised threshold pace'));
      expect(readable, isNot(contains('M2.3')));
      expect(readable, isNot(contains('alpha_quality_pace_v1')));
      c.programme.editProgramme('name', 'Changed while previewing');
      await tester.pump();
      expect(
        find.text('The session changed. Close and reopen the preview.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid sets stay editable; Cancel restores previously kept intent',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      await mount(tester, c);
      await tapVisible(tester, find.text('Open session').first);
      await tapVisible(tester, find.text('Edit session'));
      await tester.ensureVisible(field('Sets').first);
      await tester.enterText(field('Sets').first, '4');
      await tapVisible(tester, find.text('Save changes'));
      final before = c.owners.values.first.draft!;
      final beforeText = jsonEncode(before);
      await tapVisible(tester, find.text('Edit session'));
      await tester.ensureVisible(field('Sets').first);
      await tester.enterText(field('Sets').first, 'invalid');
      await tapVisible(tester, find.text('Save changes'));
      expect(find.textContaining('Please correct:'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      await tapVisible(tester, find.text('Cancel'));
      expect(jsonEncode(c.owners.values.first.draft), beforeText);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale asynchronous backup selection cannot replace newer changes',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final saved = c.save();
      final pending = Completer<String?>();
      GenuineWorkspace? replaced;
      await mount(
        tester,
        c,
        choose: () => pending.future,
        replace: (value) => replaced = value,
      );
      await tester.tap(find.text('Open backup'));
      await tester.pump();
      c.programme.editProgramme('name', 'Newer changes');
      pending.complete(saved);
      await tester.pumpAndSettle();
      expect(replaced, isNull);
      expect(
        find.text('Open this backup and replace the workspace?'),
        findsNothing,
      );
      expect(c.programme.tree!['programme']['name'], 'Newer changes');
    },
  );
  testWidgets(
    'shared-occurrence edit splits ownership and Cancel restores selection without leaving a pending copy',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final r = c.selected('LW10K-W01-D02');
      c.place(0, 5, r);
      await mount(tester, c);
      await tapVisible(tester, find.text('Open session').at(1));
      await tapVisible(tester, find.text('Edit session'));
      expect(
        c.selected('LW10K-W01-D02').identity.sessionLineageId,
        isNot(r.identity.sessionLineageId),
      );
      await tapVisible(tester, find.text('Cancel'));
      expect(c.selected('LW10K-W01-D02').source, r.source);
      expect(c.hasDrafts, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'older selected occurrence never edits another occurrence pending newer source',
    (tester) async {
      final c = selectedWorkspace();
      addTearDown(c.dispose);
      final r = c.selected('LW10K-W01-D02');
      c.place(0, 5, r);
      final saturday =
          c.occurrences.singleWhere((s) => s['day'] == 6)['slot_key'] as String;
      c.begin(r);
      final owner = c.ownerOf(r);
      c.edit(owner, (g) => g['blocks'][0]['content'] = 'Newer source notes');
      expect(c.freeze(owner), isTrue);
      c.useRevision(owner.latest, [saturday], c.generation);
      c.begin(owner.latest);
      c.edit(owner, (g) => g['blocks'][0]['content'] = 'Pending newer intent');
      final pending = jsonEncode(owner.draft);
      await mount(tester, c);
      await tapVisible(tester, find.text('Open session').at(1));
      await tapVisible(tester, find.text('Edit session'));
      final edited = c.ownerOf(c.selected('LW10K-W01-D02'));
      expect(edited.lineage, isNot(owner.lineage));
      expect(
        edited.draft!['blocks'][0]['content'],
        jsonDecode(r.source)['blocks'][0]['content'],
      );
      await tapVisible(tester, find.text('Cancel'));
      expect(c.selected('LW10K-W01-D02').source, r.source);
      expect(jsonEncode(owner.draft), pending);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale copy confirmation cannot act on changed schedule', (
    tester,
  ) async {
    final c = selectedWorkspace();
    addTearDown(c.dispose);
    await mount(tester, c);
    await tapVisible(tester, find.text('Copy to day').first);
    await tapVisible(tester, find.text('Saturday').last);
    c.programme.editProgramme('name', 'Changed while confirming');
    await tester.pump();
    await tapVisible(tester, find.text('Confirm'));
    expect(c.occurrences, hasLength(60));
    expect(find.textContaining('The programme changed'), findsOneWidget);
  });

  testWidgets('narrow schedule and compact strength controls remain laid out', (
    tester,
  ) async {
    final c = selectedWorkspace();
    addTearDown(c.dispose);
    await mount(tester, c);
    await tester.binding.setSurfaceSize(const Size(390, 850));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Open session').first);
    await tapVisible(tester, find.text('Edit session'));
    await tester.ensureVisible(field('Sets').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Cancel newly added session leaves existing day untouched', (
    tester,
  ) async {
    final c = selectedWorkspace();
    addTearDown(c.dispose);
    final before = c.occurrences;
    await mount(tester, c);
    await tapVisible(tester, find.text('Add session').first);
    await tapVisible(tester, find.text('Strength session'));
    expect(c.occurrences, hasLength(61));
    await tapVisible(tester, find.text('Cancel'));
    expect(c.occurrences, before);
    expect(c.hasDrafts, isFalse);
    expect(tester.takeException(), isNull);
  });
}
