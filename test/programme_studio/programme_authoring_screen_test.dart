import 'package:cohort_platform/features/programme_studio/presentation/programme_studio_app.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'metadata edit invalidates actual review; exact export, failure and reset work',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ProgrammeAuthoringController(
        fixture: programmeAuthoringFixtures.first,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: cohortTheme,
          home: ProgrammeAuthoringScreen(controller: c),
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      expect(c.isCurrent, isTrue, reason: c.issues.toString());
      final name = find.byKey(const ValueKey('programme-name-0'));
      await tester.scrollUntilVisible(
        name,
        -250,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.enterText(name, 'Synthetic changed name');
      await tester.pump();
      expect(c.currentReview, isNull);
      expect(find.text('Review awaits the current source'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('export-yaml')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      final exact = c.verifiedExport();
      await tester.tap(find.byKey(const Key('export-yaml')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('export-text')))
            .data,
        exact,
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.byKey(const Key('copy-yaml')));
      await tester.pumpAndSettle();
      expect(copied, exact);
      await tester.scrollUntilVisible(
        name,
        -250,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.enterText(name, '');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      expect(c.isCurrent, isFalse);
      expect(find.text('Resolve before review or export'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('reset-source')),
        -250,
        scrollable: find.byType(Scrollable).at(1),
      );
      await tester.tap(find.byKey(const Key('reset-source')));
      await tester.pumpAndSettle();
      expect(c.currentReview, isNull);
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      expect(c.meaningChanged, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopen malformed source displays actionable failure instead of old review',
    (tester) async {
      final c = ProgrammeAuthoringController(
        fixture: programmeAuthoringFixtures.first,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: cohortTheme,
          home: ProgrammeAuthoringScreen(controller: c),
        ),
      );
      c.validateAndReview();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Author'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reopen-source')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reopen-input')),
        'programme: [',
      );
      await tester.tap(find.text('Open source'));
      await tester.pumpAndSettle();
      expect(c.currentReview, isNull);
      expect(find.text('Resolve before review or export'), findsOneWidget);
      expect(c.issues.first.code, 'malformed_yaml');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'required slot dialogs confirm references and preserve stable keys',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ProgrammeAuthoringController(
        fixture: programmeAuthoringFixtures.first,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: cohortTheme,
          home: ProgrammeAuthoringScreen(controller: c),
        ),
      );
      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          250,
          scrollable: find.byType(Scrollable).at(1),
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      List<dynamic> slots() => c.tree!['weeks'][0]['days'][0]['slots'] as List;
      Future<void> selectRevision(int epoch) async {
        final picker = find.byKey(
          ValueKey('session-$epoch-W1D1S1-SYN-SESSION-R1'),
        );
        await reveal(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Synthetic session revision 2 · revision 2').last,
        );
        await tester.pumpAndSettle();
      }

      final original = c.draftSource;
      await selectRevision(0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.draftSource, original);
      await selectRevision(1);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(slots().first['session_key'], 'SYN-SESSION-R2');
      await reveal(find.text('Move / reorder').first);
      await tester.tap(find.text('Move / reorder').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('position-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Slot 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm move'));
      await tester.pumpAndSettle();
      expect(slots().map((s) => s['slot_key']), ['W1D1S2', 'W1D1S1']);
      await reveal(find.text('Remove').first);
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(slots().length, 2);
      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(slots().single['slot_key'], 'W1D1S1');
      await reveal(find.byKey(const Key('add-slot')));
      await tester.tap(find.byKey(const Key('add-slot')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-slot-key')),
        'SYN-ADDED',
      );
      await tester.tap(find.text('Add slot'));
      await tester.pumpAndSettle();
      expect(slots().last['slot_key'], 'SYN-ADDED');
      expect(c.validateAndReview(), isTrue, reason: c.issues.toString());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '390 width and 200 percent text remain scrollable and reviewable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: cohortTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ProgrammeAuthoringScreen(),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      expect(find.byType(ProgrammeStudioScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Author'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('programme-name-0')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('programme-name-0')),
        '',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('validate-review')));
      await tester.tap(find.byKey(const Key('validate-review')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Invalid draft — export and review unavailable'),
        findsOneWidget,
      );
    },
  );
}
