import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/programme_studio/workspace_json.dart';
import 'synthetic_strength_lineages_test.dart'
    show createB, DeferredLineageCompiler;
import 'programme_first_controller_test.dart' show changed;

void main() {
  Future<SyntheticCompositionController> open({
    DeferredLineageCompiler? compiler,
  }) async {
    final c = SyntheticCompositionController(compiler: compiler);
    await c.ready;
    addTearDown(c.dispose);
    return c;
  }

  test(
    'seed serialization is deterministic; reviews excluded; restored state starts unreviewed',
    () async {
      final c = await open();
      final text = (await c.saveEditableWorkspace())!;
      expect(c.workspaceSaveRequested, false);
      expect(c.workspaceHasChanges, true);
      c.markWorkspaceDownloadRequested(text);
      expect(c.workspaceHasChanges, false);
      expect(await c.validate(), true);
      expect(c.workspaceHasChanges, false);
      final r = await SyntheticCompositionController.restoreEditableWorkspace(
        text,
      );
      addTearDown(r.dispose);
      expect(r.workspaceContents, text);
      expect(r.current, null);
      expect(r.reconstructed, null);
      expect(r.session.current, null);
      expect(r.programme.currentReview, null);
      expect(r.workspaceHasChanges, false);
      r.programme.editProgramme('name', 'Saved local draft');
      expect(r.workspaceHasChanges, true);
      expect(await r.saveEditableWorkspace(), isNotNull);
    },
  );
  test(
    'both owners, private versions, availability/slots, abandoned numbers and invalid draft survive',
    () async {
      final c = await open();
      final aRoot = c.session.revisions.first.source;
      c.session.createDraft();
      c.session.cancelDraft(); // A2 abandoned.
      final a3 = await changed(c);
      await createB(c);
      final bRoot = c.secondSession.revisions.first.source;
      c.secondSession.createDraft();
      c.secondSession.cancelDraft(); // B2 abandoned.
      c.secondSession.createDraft();
      c.secondSession.editExercise(0, 'reps', '9');
      expect(await c.secondSession.freeze(), true);
      expect(
        await c.admit(c.secondSession.revisions.first),
        true,
      ); // B1 available, unused.
      c.programme.addSlot(0, 0, 'W1D1S2', 'SYN-D2-STRENGTH-R1');
      final use = (await c.prepareUseVersion(
        'W1D1S2',
        c.secondSession.revisions.last,
      ))!;
      expect(await c.usePreparedVersion(use), true);
      c.session.openRevision(a3.identity.revisionNumber);
      c.session.createDraft();
      c.session.editExercise(0, 'reps', 'not a number');
      final identity = c.session.activeIdentity;
      final text = (await c.saveEditableWorkspace())!;
      final r = await SyntheticCompositionController.restoreEditableWorkspace(
        text,
      );
      addTearDown(r.dispose);
      expect(r.workspaceContents, text);
      expect(r.session.revisions.map((r) => r.identity.revisionNumber), [1, 3]);
      expect(
        r.admitted.any(
          (s) =>
              s.identity.sessionLineageId == a3.identity.sessionLineageId &&
              s.identity.revisionNumber == 3,
        ),
        false,
      );
      expect(r.session.revisions.first.source, aRoot);
      expect(r.secondSession.revisions.first.source, bRoot);
      expect(r.session.activeIdentity.protocolId, identity.protocolId);
      expect(r.session.source, contains('not a number'));
      expect(await r.session.freeze(), false);
      expect(r.session.revisions.length, 2);
      expect(
        await r.exportHandoff(),
        null,
      ); // Unvalidated active draft blocks review export.
      r.session.cancelDraft();
      r.session.createDraft();
      expect(
        r.session.activeIdentity.revisionNumber,
        5,
      ); // A4 reservation not reused.
      r.session.editExercise(0, 'reps', '7');
      expect(await r.session.freeze(), true);
      expect(r.session.revisions.first.source, aRoot);
      expect(r.secondSession.revisions.first.source, bRoot);
      expect(
        r.programme.tree!['weeks'][0]['days'][0]['slots'][1]['session_key'],
        'SYN-D2-STRENGTH-B-R3',
      );
      expect(await r.exportHandoff(), isNotNull);
      expect(r.session.revisions.last.identity.revisionNumber, 5);
    },
  );
  test(
    'initial B invalid root and programme invalid scalar draft preserve input without freezing',
    () async {
      final c = await open();
      c.createSecondSession();
      c.secondSession.editSession('title', 'B draft');
      c.secondSession.editExercise(0, 'reps', '');
      c.programme.editProgramme('sessions_per_week', 'many');
      final text = (await c.saveEditableWorkspace())!;
      final r = await SyntheticCompositionController.restoreEditableWorkspace(
        text,
      );
      addTearDown(r.dispose);
      expect(r.secondSession.isCreatingRoot, true);
      expect(r.secondSession.revisions, isEmpty);
      expect(r.programme.tree!['programme']['sessions_per_week'], 'many');
      expect(await r.secondSession.freeze(), false);
      expect(r.secondSession.revisions, isEmpty);
      r.secondSession.cancelDraft();
      expect(r.secondSession.canCreateRoot, true);
      expect(r.programme.validateAndReview(), false);
    },
  );
  test(
    'invalid programme placement/reference semantics remain unvalidated form state',
    () async {
      final c = await open();
      c.programme.setDayType(0, 0, 'rest');
      final text = (await c.saveEditableWorkspace())!;
      final r = await SyntheticCompositionController.restoreEditableWorkspace(
        text,
      );
      addTearDown(r.dispose);
      expect(r.programme.tree!['weeks'][0]['days'][0]['day_type'], 'rest');
      expect(await r.validate(), false);
      r.programme.setDayType(0, 0, 'training');
      expect(await r.validate(), true);
    },
  );
  test('rejected raw session input remains opaque and unvalidated', () async {
    final c = await open();
    c.session.createDraft();
    expect(c.session.reopen('not supported YAML'), false);
    final text = (await c.saveEditableWorkspace())!;
    final r = await SyntheticCompositionController.restoreEditableWorkspace(
      text,
    );
    addTearDown(r.dispose);
    expect(r.session.source, 'not supported YAML');
    expect(r.session.tree, null);
    expect(await r.session.freeze(), false);
    r.session.cancelDraft();
    expect(r.session.revisions.length, 1);
  });
  test(
    'prepared candidate cancellation and failed open leave live bytes, owners and receipts unchanged',
    () async {
      final c = await open();
      await c.validate();
      final receipt = c.current, owners = c.owners;
      final text = c.workspaceContents;
      final p = (await c.prepareEditableWorkspace(text))!;
      expect(c.current, same(receipt));
      p.dispose();
      expect(c.workspaceContents, text);
      expect(c.owners, owners);
      expect(await c.replaceEditableWorkspace(p), false);
      await expectLater(
        c.prepareEditableWorkspace('{"kind":"bad"}'),
        throwsFormatException,
      );
      expect(c.current, same(receipt));
      expect(c.workspaceContents, text);
      expect(c.owners, owners);
    },
  );
  for (final change in ['other owner', 'programme', 'reset', 'dispose']) {
    test('pending candidate fails closed after $change', () async {
      final engine = DeferredLineageCompiler();
      final c = await open(compiler: engine);
      final text = c.workspaceContents;
      engine.pauseLineage = c.session.lineage.id;
      final future = c.prepareEditableWorkspace(text);
      await Future<void>.delayed(Duration.zero);
      expect(engine.gate, isNotNull);
      switch (change) {
        case 'other owner':
          c.createSecondSession();
        case 'programme':
          c.programme.editProgramme('name', 'Changed while opening');
        case 'reset':
          await c.reset();
        case 'dispose':
          c.dispose();
      }
      engine.gate!.complete();
      expect(await future, null);
    });
  }
  test(
    'stale final confirmation and reset from completion cannot install/report old work',
    () async {
      final c = await open();
      final text = c.workspaceContents;
      final p = (await c.prepareEditableWorkspace(text))!;
      c.createSecondSession();
      final before = c.workspaceContents;
      expect(await c.replaceEditableWorkspace(p), false);
      p.dispose();
      expect(c.workspaceContents, before);
      c.secondSession.cancelDraft();
      final next = (await c.prepareEditableWorkspace(text))!;
      var queued = false;
      void listener() {
        if (!queued) {
          queued = true;
          Future.microtask(c.reset);
        }
      }

      c.addListener(listener);
      expect(await c.replaceEditableWorkspace(next), false);
      c.removeListener(listener);
    },
  );
  test(
    'pending save cannot consume a snapshot after other-owner edit',
    () async {
      final engine = DeferredLineageCompiler();
      final c = await open(compiler: engine);
      engine.pauseLineage = c.session.lineage.id;
      final future = c.saveEditableWorkspace();
      await Future<void>.delayed(Duration.zero);
      c.createSecondSession();
      engine.gate!.complete();
      expect(await future, null);
      expect(c.workspaceSaveRequested, false);
    },
  );

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'format version': (m) => m['version'] = 2,
    'serialized receipt': (m) => m['current'] = {'valid': true},
    'profile': (m) => (m['fixture_profile'] as Map)['fingerprint'] = 'altered',
    'duplicate owner': (m) =>
        (m['owners'] as List)[1] = (m['owners'] as List)[0],
    'unknown selection': (m) => (m['owners'][0] as Map)['selected'] = 9,
    'root source bytes': (m) =>
        (m['owners'][0]['catalogue']['frozen'][0] as Map)['source'] += '\n',
    'foreign admitted tuple': (m) =>
        m['admitted'][0]['protocol_id'] = 'foreign',
    'duplicate admitted tuple': (m) =>
        (m['admitted'] as List).add(m['admitted'][0]),
    'locked programme': (m) =>
        m['programme_source'] = (m['programme_source'] as String).replaceFirst(
          'SYN-INVARIANT',
          'FORGED-INVARIANT',
        ),
    'high-water conflict': (m) =>
        m['owners'][0]['catalogue']['highest_reserved'] = 4,
    'reservation without draft': (m) {
      m['owners'][0]['catalogue']['highest_reserved'] = 2;
      m['owners'][0]['catalogue']['reservations'] = [
        {'number': 2, 'parent': 1},
      ];
    },
  };
  for (final e in mutations.entries) {
    test(
      'untrusted input refuses ${e.key} without mutating live state',
      () async {
        final c = await open();
        final before = c.workspaceContents;
        final m = jsonDecode(before) as Map<String, dynamic>;
        e.value(m);
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(m)),
          throwsA(anything),
        );
        expect(c.workspaceContents, before);
      },
    );
  }
  test(
    'duplicate escaped keys, excessive depth/size and read-only packets are refused',
    () async {
      final c = await open();
      final text = c.workspaceContents;
      await expectLater(
        c.prepareEditableWorkspace(
          text.replaceFirst('"version": 1', '"version": 1, "vers\\u0069on": 1'),
        ),
        throwsFormatException,
      );
      await expectLater(
        c.prepareEditableWorkspace('${'[' * 33}0${']' * 33}'),
        throwsFormatException,
      );
      await expectLater(
        c.prepareEditableWorkspace('x' * (workspaceMaxBytes + 1)),
        throwsFormatException,
      );
      await expectLater(
        c.prepareEditableWorkspace((await c.exportHandoff())!),
        throwsFormatException,
      );
      expect(c.workspaceContents, text);
    },
  );
  test('same-parent no-op cannot freeze after reopening', () async {
    final c = await open();
    c.session.createDraft();
    final r = await SyntheticCompositionController.restoreEditableWorkspace(
      c.workspaceContents,
    );
    addTearDown(r.dispose);
    expect(await r.session.freeze(), false);
    expect(r.session.errors.join(), contains('no_semantic_change'));
  });
  test(
    'restored B evolves independently and actual altered compiler profile fails closed',
    () async {
      final c = await open();
      await changed(c);
      await createB(c);
      final text = c.workspaceContents;
      final r = await SyntheticCompositionController.restoreEditableWorkspace(
        text,
      );
      addTearDown(r.dispose);
      final a = r.session.revisions.map((r) => r.source).toList();
      r.secondSession.createDraft();
      r.secondSession.editExercise(0, 'reps', '10');
      expect(await r.secondSession.freeze(), true);
      expect(r.session.revisions.map((r) => r.source), a);
      final defs = d2ExerciseDefinitions();
      defs[0] = ExerciseDefinition.fromJson({
        ...defs[0].toJson(),
        'version': '2',
      });
      await expectLater(
        SyntheticCompositionController.restoreEditableWorkspace(
          text,
          compiler: SyntheticStrengthSessionCompiler(
            allowSecondLineage: true,
            definitions: defs,
          ),
        ),
        throwsA(anything),
      );
    },
  );
  test(
    'unsupported draft wrapper, foreign exercise, load mode and unknown fields are rejected',
    () async {
      final c = await open();
      c.session.createDraft();
      final text = c.workspaceContents;
      for (final kind in ['wrapper', 'exercise', 'load', 'field']) {
        final m = jsonDecode(text) as Map<String, dynamic>;
        final tree = m['owners'][0]['draft']['tree'];
        final session = tree['weeks'][0]['days'][0]['sessions'][0];
        switch (kind) {
          case 'wrapper':
            tree['programme']['code'] = 'foreign';
          case 'exercise':
            session['blocks'][0]['exercises'][0]['transitional_exercise_id'] =
                'foreign';
          case 'load':
            session['blocks'][0]['exercises'][0]['prescription']['load']['unit'] =
                'percent';
          case 'field':
            session['ignored'] = {'approved': true};
        }
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(m)),
          throwsA(anything),
        );
        expect(c.workspaceContents, text);
      }
    },
  );
  test(
    'frozen parent/reservation edges cannot point to unknown or frozen conflicting identities',
    () async {
      final c = await open();
      await changed(c);
      c.session.createDraft();
      final text = c.workspaceContents;
      for (final kind in ['parent', 'reservation', 'abandoned']) {
        final m = jsonDecode(text) as Map<String, dynamic>;
        final cat = m['owners'][0]['catalogue'];
        switch (kind) {
          case 'parent':
            cat['frozen'][1]['parent'] = 2;
          case 'reservation':
            cat['reservations'][0]['number'] = 2;
          case 'abandoned':
            cat['abandoned_ranges'] = [
              {'first': 2, 'last': 3},
            ];
        }
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(m)),
          throwsA(anything),
        );
        expect(c.workspaceContents, text);
      }
    },
  );
  test(
    'embedded YAML nesting/aliases are bounded before existing parsers',
    () async {
      final c = await open();
      for (final source in [
        'x: &anchor {y: *anchor}',
        'x: ${'[' * 33}1${']' * 33}',
        '${' ' * 65}x: 1',
      ]) {
        final m = jsonDecode(c.workspaceContents) as Map<String, dynamic>;
        m['programme_source'] = source;
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(m)),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'rejected wrapper input cannot gain freeze authority through validate or workspace reopen',
    () async {
      final c = await open();
      c.session.createDraft();
      c.session.editExercise(0, 'reps', '6');
      final rejected = c.session.source.replaceFirst(
        'Synthetic week',
        'Different wrapper',
      );
      expect(c.session.reopen(rejected), false);
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(
            c.workspaceContents,
          );
      addTearDown(restored.dispose);
      expect(await c.session.freeze(), false);
      expect(await restored.session.freeze(), false);
      expect(c.session.revisions.length, 1);
      expect(restored.session.revisions.length, 1);
    },
  );
  test('standalone availability must retain its original root', () async {
    final c = await open();
    await changed(c);
    final m = jsonDecode(c.workspaceContents) as Map<String, dynamic>;
    m['owners'][0]['selected'] = 2;
    m['owners'][0]['opened'] = 2;
    m['owners'][0]['programme_entries'] = [2];
    await expectLater(
      c.prepareEditableWorkspace(jsonEncode(m)),
      throwsFormatException,
    );
  });
}
