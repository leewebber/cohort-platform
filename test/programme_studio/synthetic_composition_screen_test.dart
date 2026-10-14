import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme_studio/authoring/programme_authoring_screen.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_screen.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';

Future<SyntheticCompositionController> mount(
  WidgetTester tester, {
  Size size = const Size(1300, 1000),
  double scale = 1,
  SyntheticCompositionController? suppliedController,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final c = suppliedController ?? SyntheticCompositionController();
  await c.ready;
  addTearDown(c.dispose);
  await tester.pumpWidget(
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
  await tester.pumpAndSettle();
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

class ConsumptionRaceController extends SyntheticCompositionController {
  bool queueEdit = false, queueSecondOwner = false;
  @override
  Future<String?> exportHandoff() async {
    final bytes = await super.exportHandoff();
    if (queueEdit) {
      scheduleMicrotask(() {
        if (queueSecondOwner) {
          secondSession.createDraft();
          secondSession.editExercise(0, 'reps', '10');
        } else {
          programme.editProgramme('name', 'Synthetic consumption edit');
        }
      });
      await Future<void>.value();
    }
    return bytes;
  }
}

void main() {
  testWidgets(
    'B creation reuses empty form; same-title R1 admission and confirmed second-slot selection',
    (t) async {
      final c = await mount(t);
      await tap(t, find.byKey(const Key('create-lineage-b')));
      expect(c.secondSession.isCreatingRoot, true);
      expect(
        (t.widget<TextFormField>(field('exercise-0-sets'))).initialValue,
        '',
      );
      for (final entry in {
        'session-title': 'Synthetic strength session',
        'block-title': 'Straight sets',
        'exercise-0-sets': '3',
        'exercise-0-reps': '8',
      }.entries) {
        await t.ensureVisible(field(entry.key));
        await t.enterText(field(entry.key), entry.value);
      }
      final picker = find.byWidgetPredicate(
        (w) =>
            w is DropdownButton<String> &&
            w.key.toString().contains('exercise-0-picker'),
      );
      await tap(t, picker);
      await tap(t, find.text('EX-9002 · Synthetic fixture B').last);
      await tap(t, find.text('Confirm'));
      await tap(t, find.text('Validate and refresh review'));
      await tap(t, find.text('Freeze local revision'));
      final b = c.secondSession.revisions.single;
      expect(c.admitted.length, 1);
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][0]['session_key'],
        d2SessionKey(1),
      );
      await tap(t, find.byKey(const Key('composition-tab-2')));
      expect(
        find.byKey(Key('admission-status-${revisionKey(b.identity)}')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          Key('admission-status-${revisionKey(c.session.activeIdentity)}'),
        ),
        findsOneWidget,
      );
      await tap(t, find.byKey(Key('admit-${revisionKey(b.identity)}')));
      await tap(t, find.text('Confirm'));
      expect(c.admitted.length, 2);
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][0]['session_key'],
        d2SessionKey(1),
      );
      await tap(t, find.byKey(const Key('composition-tab-1')));
      await tap(t, find.byKey(const Key('add-slot')));
      await t.enterText(find.byKey(const Key('new-slot-key')), 'W1D1S2');
      await tap(t, find.text('Add slot'));
      final slotPicker = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.key.toString().contains('W1D1S2-'),
      );
      await tap(t, slotPicker);
      await tap(
        t,
        find.textContaining(SyntheticStrengthLineage.b.sessionKey(1)).last,
      );
      expect(
        find.text('Select exact revision for this required slot?'),
        findsOneWidget,
      );
      await tap(t, find.text('Cancel'));
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][1]['session_key'],
        d2SessionKey(1),
      );
      await tap(t, slotPicker);
      await tap(
        t,
        find.textContaining(SyntheticStrengthLineage.b.sessionKey(1)).last,
      );
      await tap(t, find.text('Confirm'));
      await tap(t, find.byKey(const Key('joint-validate')));
      expect(c.current!.slotBindings.length, 2);
      await tap(t, find.byKey(const Key('composition-tab-3')));
      await tap(t, find.byKey(const Key('joint-studio')));
      expect(find.text('Current joint Studio'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(find.textContaining('8 reps'), findsWidgets);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'copy refuses a queued edit in unselected B after export completion',
    (t) async {
      final c = ConsumptionRaceController();
      await mount(t, suppliedController: c);
      c.createSecondSession();
      c.secondSession.editSession('title', 'Synthetic strength session');
      c.secondSession.editBlock('title', 'Straight sets');
      c.secondSession.replaceExercise(0, 'cohort.exercise.d2_fixture_b');
      c.secondSession.editExercise(0, 'sets', '3');
      c.secondSession.editExercise(0, 'reps', '8');
      expect(await c.secondSession.freeze(), true);
      expect(await c.admit(c.secondSession.revisions.single), true);
      expect(await c.validate(), true);
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('complete-export')));
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
      await tap(t, find.byKey(const Key('copy-handoff')));
      expect(writes, 0);
      expect(c.current, null);
      expect(find.text('Export invalidated'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('copy consumes the exact freshly validated handoff', (t) async {
    final c = await mount(t);
    await c.validate();
    await t.pumpAndSettle();
    final expected = (await c.exportHandoff())!;
    await tap(t, find.byKey(const Key('complete-export')));
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tap(t, find.byKey(const Key('copy-handoff')));
    expect(copied, [expected]);
    expect(
      find.text('Complete local handoff — canonical sources'),
      findsNothing,
    );
    expect(c.current, isNotNull);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'copy refuses a source edit queued between export and UI consumption',
    (t) async {
      final c = ConsumptionRaceController();
      await mount(t, suppliedController: c);
      await c.validate();
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('complete-export')));
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
      await tap(t, find.byKey(const Key('copy-handoff')));
      expect(c.current, null);
      expect(writes, 0);
      expect(find.text('Export invalidated'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'reused session form: invalid draft, freeze, admit without select, confirmed exact slot choice',
    (t) async {
      final c = await mount(t);
      expect(find.text('Select for programme'), findsNothing);
      await tap(t, find.text('Create local draft revision'));
      final title = field('session-title');
      await t.ensureVisible(title);
      await t.enterText(title, '');
      await tap(t, find.text('Validate and refresh review'));
      expect(find.textContaining('session.title'), findsOneWidget);
      expect(c.current, null);
      await t.ensureVisible(title);
      await t.enterText(title, 'Synthetic strength session');
      final reps = field('exercise-0-reps');
      await t.ensureVisible(reps);
      await t.enterText(reps, '6');
      await tap(t, find.text('Validate and refresh review'));
      await tap(t, find.text('Freeze local revision'));
      expect(c.admitted.length, 1);
      expect(c.programme.tree!['sessions'].length, 1);
      await tap(t, find.byKey(const Key('composition-tab-2')));
      expect(
        find.byKey(
          Key('admission-status-${revisionKey(c.session.activeIdentity)}'),
        ),
        findsOneWidget,
      );
      await tap(
        t,
        find.byKey(Key('admit-${revisionKey(c.session.activeIdentity)}')),
      );
      await tap(t, find.text('Cancel'));
      expect(c.admitted.length, 1);
      await tap(
        t,
        find.byKey(Key('admit-${revisionKey(c.session.activeIdentity)}')),
      );
      await tap(t, find.text('Confirm'));
      expect(c.admitted.length, 2);
      expect(find.text('W1D1S1 → SYN-D2-STRENGTH-R1'), findsOneWidget);
      await tap(t, find.byKey(const Key('composition-tab-1')));
      final chooser = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Exact fixture session revision',
      );
      await tap(t, chooser);
      await tap(t, find.textContaining('revision 2').last);
      expect(find.textContaining('Source SHA-256:'), findsOneWidget);
      await tap(t, find.text('Cancel'));
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][0]['session_key'],
        d2SessionKey(1),
      );
      await tap(t, chooser);
      await tap(t, find.textContaining('revision 2').last);
      await tap(t, find.text('Confirm'));
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][0]['session_key'],
        d2SessionKey(2),
      );
      await tap(t, find.byKey(const Key('joint-validate')));
      expect(c.current, isNotNull);
      await tap(t, find.byKey(const Key('composition-tab-3')));
      await tap(t, find.byKey(const Key('joint-studio')));
      expect(find.text('Current joint Studio'), findsOneWidget);
      expect(find.textContaining('6 reps'), findsWidgets);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'reused add-slot chooses admitted references and programme edits clear joint review',
    (t) async {
      final c = await mount(t);
      await c.validate();
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('composition-tab-1')));
      await tap(t, find.byKey(const Key('add-slot')));
      expect(t.takeException(), isNull);
      await t.enterText(find.byKey(const Key('new-slot-key')), 'W1D1S2');
      await tap(t, find.text('Add slot'));
      expect(c.current, null);
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][1]['session_key'],
        d2SessionKey(1),
      );
      final name = field('programme-name');
      await t.scrollUntilVisible(
        name,
        -400,
        scrollable: find
            .descendant(
              of: find.byType(ProgrammeAuthoringScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.enterText(name, '');
      await tap(t, find.byKey(const Key('joint-validate')));
      expect(c.current, null);
      await t.pumpAndSettle();
      expect(find.textContaining('programme.name'), findsWidgets);
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('complete-export')))
            .onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'complete export invalidates open dialog; handoff reopen is separate read-only and reset restores seed',
    (t) async {
      final c = await mount(t);
      expect(await c.validate(), true);
      await t.pumpAndSettle();
      final packet = (await c.exportHandoff())!;
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('complete-export')));
      expect(
        find.text('Complete local handoff — canonical sources'),
        findsOneWidget,
      );
      c.programme.editProgramme('name', 'Synthetic intervening edit');
      await t.pumpAndSettle();
      expect(find.text('Export invalidated'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('copy-handoff'))).onPressed,
        isNull,
      );
      await tap(t, find.text('Close'));
      final live = c.programme.draftSource;
      await tap(t, find.byKey(const Key('complete-reopen')));
      await t.enterText(find.byKey(const Key('handoff-input')), packet);
      await tap(t, find.text('Reconstruct review'));
      expect(c.reconstructed, isNotNull);
      expect(c.programme.draftSource, live);
      expect(
        find.text('Reconstructed review — read-only, separate sources'),
        findsOneWidget,
      );
      expect(c.reconstructedExport(), packet);
      await tap(t, find.byKey(const Key('workspace-reset')));
      await tap(t, find.text('Confirm'));
      expect(c.admitted.single.source, d2R1Source());
      expect(c.reconstructed, null);
      expect(
        c.programme.tree!['programme']['name'],
        'Synthetic D2 revision selection',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'malformed handoff shows session-source error and retains rejected bytes',
    (t) async {
      final c = await mount(t);
      final yaml = c.programme.draftSource;
      await tap(t, find.byKey(const Key('complete-reopen')));
      await t.enterText(find.byKey(const Key('handoff-input')), yaml);
      await tap(t, find.text('Reconstruct review'));
      expect(c.reconstructed, null);
      expect(c.rejectedHandoff, yaml);
      expect(
        find.textContaining('Programme YAML alone has no session sources'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large-text composition and export stay usable without overflow',
    (t) async {
      final c = await mount(t, size: const Size(390, 844), scale: 2);
      expect(t.takeException(), isNull);
      await c.validate();
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('composition-tab-1')));
      expect(t.takeException(), isNull);
      await tap(t, find.byKey(const Key('composition-tab-2')));
      expect(t.takeException(), isNull);
      await tap(t, find.byKey(const Key('composition-tab-3')));
      expect(t.takeException(), isNull);
      await tap(t, find.byKey(const Key('complete-export')));
      expect(t.takeException(), isNull);
      await tap(t, find.text('Close'));
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'already opened actual Studio loses current status after source edits',
    (t) async {
      final c = await mount(t);
      await c.validate();
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('composition-tab-3')));
      await tap(t, find.byKey(const Key('joint-studio')));
      c.programme.editProgramme('name', 'Synthetic later source');
      await t.pumpAndSettle();
      expect(find.text('Review invalidated'), findsOneWidget);
      expect(find.text('Current joint Studio'), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
