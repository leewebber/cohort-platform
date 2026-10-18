import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/programme_studio/authoring/plan_package_v1_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'synthetic_strength_lineages_test.dart'
    show createB, DeferredLineageCompiler;

List<Map> slots(SyntheticCompositionController c) => [
  for (final w in c.programme.tree!['weeks'])
    for (final d in w['days'])
      for (final s in d['slots']) s as Map,
];
Map<String, String> choices(SyntheticCompositionController c) => {
  for (final s in slots(c)) s['slot_key'] as String: s['session_key'] as String,
};
Future<void> setup(
  SyntheticCompositionController c, {
  int dayA = 1,
  int dayB = 4,
}) async {
  final p = await c.prepareFourWeekSchedule(
    c.session.revisions.first,
    c.secondSession.revisions.first,
    dayA,
    dayB,
  );
  expect(p, isNotNull, reason: c.errors.join('\n'));
  expect(await c.usePreparedVersion(p!), true);
}

void main() {
  Future<SyntheticCompositionController> open({
    DeferredLineageCompiler? compiler,
  }) async {
    final c = SyntheticCompositionController(compiler: compiler);
    await c.ready;
    addTearDown(c.dispose);
    await createB(c);
    return c;
  }

  test(
    'four weeks preserve contracts once, all eight exact prescriptions and independent later versions through both products',
    () async {
      final c = await open();
      final original = c.programme.tree!;
      final a1 = c.session.revisions.first.source,
          b1 = c.secondSession.revisions.first.source;
      await setup(c);
      expect(slots(c).length, 8);
      expect(choices(c).keys.toSet().length, 8);
      for (final w in c.programme.tree!['weeks']) {
        expect(
          [
            for (final d in w['days'])
              if ((d['slots'] as List).isNotEmpty) d['day_order'],
          ],
          [1, 4],
        );
      }
      for (final field in [
        'phases',
        'adaptation_permissions',
        'protected_invariants',
        'assessments',
        'performance_evidence_requirements',
        'comparison_identities',
      ]) {
        expect(c.programme.tree![field], original[field], reason: field);
      }
      final initial = choices(c);
      c.session.createDraft();
      c.session.editExercise(0, 'reps', '6');
      expect(await c.session.freeze(), true);
      c.secondSession.createDraft();
      c.secondSession.editExercise(0, 'reps', '9');
      expect(await c.secondSession.freeze(), true);
      expect(choices(c), initial); // Saving never selects.
      final a2 = (await c.prepareUseVersion(
        'W3D1S1',
        c.session.revisions.last,
      ))!;
      expect(choices(c), initial); // Preparing consent never selects/admit.
      expect(await c.usePreparedVersion(a2), true);
      final b2 = (await c.prepareUseVersion(
        'W4D4S1',
        c.secondSession.revisions.last,
      ))!;
      expect(await c.usePreparedVersion(b2), true);
      final updated = choices(c);
      expect(updated['W3D1S1'], 'SYN-D2-STRENGTH-R2');
      expect(updated['W4D4S1'], 'SYN-D2-STRENGTH-B-R2');
      for (final k in initial.keys.where(
        (k) => k != 'W3D1S1' && k != 'W4D4S1',
      )) {
        expect(updated[k], initial[k]);
      }
      expect(c.session.revisions.first.source, a1);
      expect(c.secondSession.revisions.first.source, b1);
      expect(await c.validate(), true, reason: c.errors.join('\n'));
      expect(c.current!.slotBindings.length, 8);
      final packet = (await c.exportHandoff())!;
      final files = CanonicalSourceBundle.fromReview(c.current!).files;
      expect(files['sessions/session-a-v1.founder.yaml'], a1);
      expect(files['sessions/session-b-v1.founder.yaml'], b1);
      expect(files['review.json'], packet);
      final compiled = const PlanPackageCompiler().compile(
        files['programme.plan-package.yaml']!,
      );
      expect(compiled.isValid, true);
      expect(compiled.contentHashSha256, c.current!.packageHash);
      final bindings = c.current!.slotBindings;
      expect(await c.reopen(packet), true);
      expect(c.reconstructed!.slotBindings, bindings);
      expect(c.reconstructedExport(), packet);
      // Invalid active draft/reservations survive four-week editable reconstruction.
      c.secondSession.createDraft();
      c.secondSession.cancelDraft();
      c.secondSession.createDraft();
      c.secondSession.editExercise(0, 'reps', 'bad reps');
      final saved = (await c.saveEditableWorkspace())!;
      expect(jsonDecode(saved)['version'], 2);
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(restored.dispose);
      expect(restored.workspaceContents, saved);
      expect(choices(restored), updated);
      expect(restored.current, null);
      expect(restored.secondSession.source, contains('bad reps'));
      expect(restored.secondSession.activeIdentity.revisionNumber, 4);
      restored.secondSession.editExercise(0, 'reps', '10');
      expect(await restored.secondSession.freeze(), true);
      expect(choices(restored), updated);
      expect(await restored.validate(), true);
      expect(restored.current!.slotBindings.length, 8);
    },
  );
  test(
    'internally generated keys remain unique when A moves and B uses original day',
    () async {
      final c = await open();
      await setup(c, dayA: 5, dayB: 1);
      expect(slots(c).length, 8);
      expect(choices(c).length, 8);
      expect(
        c.programme.tree!['weeks'][0]['days'][4]['slots'][0]['slot_key'],
        'W1D1S1',
      );
      expect(await c.validate(), true, reason: c.errors.join('\n'));
    },
  );
  for (final days in [(0, 4), (1, 8), (4, 4)]) {
    test('invalid setup days $days are atomic with no admission', () async {
      final c = await open();
      final before = c.workspaceContents;
      expect(
        await c.prepareFourWeekSchedule(
          c.session.revisions.first,
          c.secondSession.revisions.first,
          days.$1,
          days.$2,
        ),
        null,
      );
      expect(c.workspaceContents, before);
    });
  }
  test(
    'cancelled preparation and repeated setup preserve current selections and receipt',
    () async {
      final c = await open();
      final before = c.workspaceContents;
      expect(
        await c.prepareFourWeekSchedule(
          c.session.revisions.first,
          c.secondSession.revisions.first,
          1,
          4,
        ),
        isNotNull,
      );
      expect(c.workspaceContents, before);
      await setup(c);
      final existing = c.workspaceContents;
      expect(
        await c.prepareFourWeekSchedule(
          c.session.revisions.first,
          c.secondSession.revisions.first,
          2,
          5,
        ),
        null,
      );
      expect(c.workspaceContents, existing);
    },
  );
  test(
    'referenced removal and foreign-lineage selection refuse without source or receipt mutation',
    () async {
      final c = await open();
      await setup(c);
      expect(await c.validate(), true);
      final before = c.workspaceContents,
          receipt = c.current,
          revision = c.programme.revision;
      c.programme.removeSlot(0, 0, 0);
      expect(c.programme.issues.single.message, contains('locked assessment'));
      expect(c.workspaceContents, before);
      expect(c.programme.revision, revision);
      expect(c.current, same(receipt));
      expect(
        await c.prepareUseVersion('W1D1S1', c.secondSession.revisions.first),
        null,
      );
      expect(c.workspaceContents, before);
      expect(c.errors.join(), contains('locked comparison'));
      expect(
        await c.selectRevision(
          0,
          0,
          0,
          c.secondSession.revisions.first.identity,
        ),
        false,
      );
      expect(c.workspaceContents, before);
      // Removing an unreferenced occurrence is supported and survives file reopen.
      c.programme.removeSlot(3, 3, 0);
      expect(slots(c).length, 7);
      final saved = (await c.saveEditableWorkspace())!;
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(restored.dispose);
      expect(slots(restored).length, 7);
    },
  );
  test(
    'supported move preserves identity and reopens as authoritative schedule',
    () async {
      final c = await open();
      await setup(c);
      c.programme.setDayType(2, 5, 'training');
      c.programme.moveSlot(2, 0, 0, 2, 5, 0);
      c.programme.setDayType(2, 0, 'rest');
      final saved = (await c.saveEditableWorkspace())!;
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(restored.dispose);
      expect(
        restored.programme.tree!['weeks'][2]['days'][5]['slots'][0]['slot_key'],
        'W3D1S1',
      );
      expect(await restored.validate(), true);
    },
  );
  test(
    'v1 safe migration retains source and invalid drafts; future and disguised expanded v1 reject',
    () async {
      final c = await open();
      final old = jsonDecode((await c.saveEditableWorkspace())!) as Map;
      old['version'] = 1;
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(
            jsonEncode(old),
          );
      addTearDown(restored.dispose);
      expect(restored.programme.draftSource, c.programme.draftSource);
      expect(jsonDecode(restored.workspaceContents)['version'], 2);
      await setup(c);
      for (final version in [1, 3, 99]) {
        final bad = jsonDecode((await c.saveEditableWorkspace())!) as Map;
        bad['version'] = version;
        final before = c.workspaceContents;
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(bad)),
          throwsFormatException,
        );
        expect(c.workspaceContents, before);
      }
    },
  );
  for (final field in [
    'phase_key',
    'day_key',
    'assessment',
    'extra_day_field',
    'duration',
  ]) {
    test(
      'unsupported source $field cannot be silently editable or lose fields',
      () async {
        final c = await open();
        await setup(c);
        final saved = jsonDecode((await c.saveEditableWorkspace())!) as Map;
        final tree = c.programme.tree!;
        switch (field) {
          case 'phase_key':
            tree['weeks'][1]['phase_key'] = 'foreign';
          case 'day_key':
            tree['weeks'][1]['days'][2]['day_key'] = 'custom';
          case 'assessment':
            tree['assessments'][0]['slot_ref'] = 'W2D1S1';
          case 'extra_day_field':
            tree['weeks'][1]['days'][2]['unsupported'] = 'retained';
          case 'duration':
            tree['programme']['duration_weeks'] = 5;
        }
        saved['programme_source'] = const PlanPackageV1YamlWriter().writeDraft(
          tree,
        );
        final before = c.workspaceContents;
        await expectLater(
          c.prepareEditableWorkspace(jsonEncode(saved)),
          throwsFormatException,
        );
        expect(c.workspaceContents, before);
      },
    );
  }
  for (final change in ['edit', 'reset', 'dispose']) {
    test(
      'schedule preparation ignores $change while verifying sources',
      () async {
        final compiler = DeferredLineageCompiler();
        final c = await open(compiler: compiler);
        compiler.pauseLineage = c.secondSession.lineage.id;
        final pending = c.prepareFourWeekSchedule(
          c.session.revisions.first,
          c.secondSession.revisions.first,
          1,
          4,
        );
        while (compiler.gate == null) {
          await Future<void>.delayed(Duration.zero);
        }
        if (change == 'edit') {
          c.programme.editProgramme('name', 'Synthetic changed');
        }
        if (change == 'reset') await c.reset();
        if (change == 'dispose') c.dispose();
        final source = c.programme.draftSource;
        compiler.gate!.complete();
        expect(await pending, null);
        expect(c.programme.draftSource, source);
        expect(c.admitted.length, 1);
      },
    );
    test('schedule confirmation expires after $change', () async {
      final c = await open();
      final p = (await c.prepareFourWeekSchedule(
        c.session.revisions.first,
        c.secondSession.revisions.first,
        1,
        4,
      ))!;
      if (change == 'edit') {
        c.programme.editProgramme('name', 'Synthetic changed');
      }
      if (change == 'reset') await c.reset();
      if (change == 'dispose') c.dispose();
      expect(await c.usePreparedVersion(p), false);
      expect(c.admitted.length, 1);
    });
  }
}
