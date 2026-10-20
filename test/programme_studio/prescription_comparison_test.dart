import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/prescription_comparison.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_source_guard.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'four_week_schedule_test.dart' show setup, choices;
import 'programme_first_controller_test.dart' show changed;
import 'synthetic_strength_lineages_test.dart'
    show createB, DeferredLineageCompiler;

Future<D2CompiledSession> compile(
  Map<String, dynamic> tree, {
  int number = 1,
  String prefix = '',
}) {
  tree['programme']['import_key'] = d2ImportKey(number);
  return SyntheticStrengthSessionCompiler().compileExact(
    '$prefix${const FounderStrengthYamlWriter().write(tree)}',
    SyntheticStrengthLineage.a.identity(number),
  );
}

Future<PrescriptionComparison> compareEdit(
  void Function(Map<String, dynamic>) edit,
) async {
  final tree = d2FounderTree();
  final before = await compile(d2FounderTree());
  edit(tree);
  return PrescriptionComparison.compare(before, await compile(tree, number: 2));
}

Map<String, dynamic> firstDose(Map<String, dynamic> t) =>
    FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
        as Map<String, dynamic>;

void main() {
  test('identical selected source gives explicit no-change state', () async {
    final source = await compile(d2FounderTree());
    final c = PrescriptionComparison.compare(source, source);
    expect(c.supported, true);
    expect(c.changes, isEmpty);
    expect(c.summary, 'No prescription or session metadata change');
  });
  test(
    'comments, equivalent exact-rep encoding, numeric kg and whitespace are not prescription changes',
    () async {
      final tree = d2FounderTree();
      final a = await compile(d2FounderTree());
      firstDose(tree)['reps'] = {'type': 'exact', 'exact_reps': 5};
      firstDose(tree)['load'] = {'unit': 'kg', 'value': 12.50};
      FounderStrengthSourceGuard.session(tree)['title'] =
          '  Synthetic strength session  ';
      final b = await compile(tree, number: 2, prefix: '# Different comment\n');
      expect(a.sourceDigest, isNot(b.sourceDigest));
      expect(PrescriptionComparison.compare(a, b).changes, isEmpty);
    },
  );
  for (final entry in {
    'sets': 4,
    'reps': 7,
    'rest_seconds': 90,
    'tempo': '2-0-2',
    'notes': 'Different synthetic cue',
  }.entries) {
    test(
      'reports exact before/after ${entry.key} without derivation',
      () async {
        final c = await compareEdit(
          (t) => firstDose(t)[entry.key] = entry.value,
        );
        expect(c.prescriptionChanged, true);
        expect(c.changes.length, 1);
        expect(c.changes.single.before, isNot(c.changes.single.after));
        expect(c.changes.single.subject, contains('Exercise 1'));
      },
    );
  }
  final loads = <String, Map<String, dynamic>?>{
    'Unspecified': null,
    'Bodyweight': {'unit': 'bodyweight'},
    '12.5 kg': {'unit': 'kg', 'value': 12.5},
    'RPE 8': {'unit': 'rpe', 'value': 8},
  };
  for (final from in loads.entries) {
    for (final to in loads.entries.where((v) => v.key != from.key)) {
      test('preserves load mode ${from.key} to ${to.key}', () async {
        final t = d2FounderTree(), u = d2FounderTree();
        for (final pair in [(t, from.value), (u, to.value)]) {
          final dose = firstDose(pair.$1);
          dose.remove('load');
          if (pair.$2 != null) dose['load'] = pair.$2;
        }
        final c = PrescriptionComparison.compare(
          await compile(t),
          await compile(u, number: 2),
        );
        expect(c.changes.single.field, 'Load');
        expect(c.changes.single.before, from.key);
        expect(c.changes.single.after, to.key);
      });
    }
  }
  test(
    'RPE alias is existing mapped meaning, not a different load mode',
    () async {
      final t = d2FounderTree(), u = d2FounderTree();
      firstDose(t)['load'] = {'unit': 'rpe', 'value': 8};
      firstDose(u).remove('load');
      firstDose(u)['target_rpe'] = 8;
      expect(
        PrescriptionComparison.compare(
          await compile(t),
          await compile(u, number: 2),
        ).changes,
        isEmpty,
      );
    },
  );
  test('explicit rest tempo cues differ from unspecified values', () async {
    final c = await compareEdit((t) {
      for (final key in ['rest_seconds', 'tempo', 'notes']) {
        firstDose(t).remove(key);
      }
    });
    expect(c.changes.map((c) => c.field), ['Rest', 'Tempo', 'Cues']);
    expect(c.changes.every((c) => c.after == 'Unspecified'), true);
  });
  test(
    'session and block metadata only are explicitly separate from prescription change',
    () async {
      final c = await compareEdit((t) {
        final s = FounderStrengthSourceGuard.session(t),
            b = FounderStrengthSourceGuard.block(t);
        s['title'] = 'Another synthetic title';
        s.remove('coach_notes');
        s.remove('estimated_duration_minutes');
        b['title'] = 'Another synthetic block';
        b['coach_notes'] = 'Another block note';
        FounderStrengthSourceGuard.exerciseRows(t).first['exercise_name'] =
            'Another label';
      });
      expect(c.summary, 'Metadata only — no prescription change');
      expect(c.changes.length, 6);
      expect(c.prescriptionChanged, false);
      expect(c.changes.where((c) => c.after == 'Unspecified').length, 2);
    },
  );
  test(
    'reorder follows identities with identical labels, preserving each dose',
    () async {
      final t = d2FounderTree();
      for (final e in FounderStrengthSourceGuard.exerciseRows(t)) {
        e['exercise_name'] = 'Same title';
      }
      final a = await compile(t);
      final b = FounderStrengthSourceGuard.block(t);
      b['exercises'] = (b['exercises'] as List).reversed.toList();
      final rows = FounderStrengthSourceGuard.exerciseRows(t);
      for (var i = 0; i < rows.length; i++) {
        rows[i]['order'] = i + 1;
      }
      final c = PrescriptionComparison.compare(a, await compile(t, number: 2));
      expect(c.changes.map((c) => c.field), ['Order', 'Order']);
      expect(c.changes.map((c) => c.subject).toSet().length, 2);
      expect(c.changes.first.before, '1');
      expect(c.changes.first.after, '2');
    },
  );
  test(
    'add and remove are identity changes even with identical titles',
    () async {
      final t = d2FounderTree(), u = d2FounderTree();
      final a = FounderStrengthSourceGuard.exerciseRows(t).first;
      final b = FounderStrengthSourceGuard.exerciseRows(u).last;
      a['exercise_name'] = b['exercise_name'] = 'Same title';
      b['order'] = 1;
      FounderStrengthSourceGuard.block(t)['exercises'] = [a];
      FounderStrengthSourceGuard.block(u)['exercises'] = [b];
      final c = PrescriptionComparison.compare(
        await compile(t),
        await compile(u, number: 2),
      );
      expect(c.changes.map((c) => c.field), [
        'Exercise removed',
        'Exercise added',
      ]);
      expect(c.changes.first.subject, contains('Exercise 1'));
      expect(c.changes.last.subject, contains('Exercise 1'));
      expect(c.changes.last.after, contains('Load: Unspecified'));
    },
  );
  test(
    'an explicit cue saying Unspecified remains distinct from absence',
    () async {
      final c = await compareEdit((t) => firstDose(t)['notes'] = 'Unspecified');
      expect(c.changes.single.after, '“Unspecified”');
      expect(c.changes.single.before, '“Synthetic cue only.”');
    },
  );
  test(
    'missing sources and different identity profiles are unavailable, never no-change',
    () async {
      final a = await compile(d2FounderTree());
      expect(PrescriptionComparison.compare(null, a).supported, false);
      final definitions = d2ExerciseDefinitions();
      final different = SyntheticStrengthSessionCompiler(
        definitions: definitions.reversed.toList(),
      );
      // Profile fingerprints include the exact configured snapshot order.
      final b = await different.compileExact(a.source, a.identity);
      final c = PrescriptionComparison.compare(a, b);
      expect(c.supported, false);
      expect(c.summary, contains('Comparison unavailable'));
      expect(c.changes, isEmpty);
    },
  );
  test(
    'four-week comparison and exact target survive editable and both export products',
    () async {
      final c = SyntheticCompositionController();
      await c.ready;
      addTearDown(c.dispose);
      await createB(c);
      await setup(c, dayA: 2, dayB: 5);
      final r = await changed(c), original = choices(c), admitted = c.admitted;
      final p = (await c.prepareUseVersion('W4D2S1', r))!;
      expect(p.targetLabel, 'Week 4 · Day 2 · Workout 1');
      expect(p.currentVersion!.identity.revisionNumber, 1);
      expect(p.comparison!.changes.single.field, 'Exact reps');
      expect(p.comparison!.changes.single.before, '5');
      expect(p.comparison!.changes.single.after, '6');
      expect(p.unchangedOccurrences, [
        'Week 1 · Day 2 · Workout 1',
        'Week 2 · Day 2 · Workout 1',
        'Week 3 · Day 2 · Workout 1',
      ]);
      expect(choices(c), original);
      expect(c.admitted, admitted); // Cancellation/preparation changes nothing.
      expect(await c.usePreparedVersion(p), true);
      final expected = {...original, 'W4D2S1': 'SYN-D2-STRENGTH-R2'};
      expect(choices(c), expected);
      final saved = (await c.saveEditableWorkspace())!;
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(saved);
      addTearDown(restored.dispose);
      expect(choices(restored), expected);
      final reverse = (await restored.prepareUseVersion(
        'W4D2S1',
        restored.session.revisions.first,
      ))!;
      expect(reverse.comparison!.changes.single.before, '6');
      expect(reverse.comparison!.changes.single.after, '5');
      final packet = (await restored.exportHandoff())!;
      final bundle = CanonicalSourceBundle.fromReview(restored.current!);
      expect(bundle.files['review.json'], packet);
      expect(await restored.reopen(packet), true);
      expect(restored.reconstructedExport(), packet);
      final imported = await restored.prepareCanonicalSources(
        bundle.archiveBytes,
      );
      expect(imported, isNotNull);
      imported!.dispose();
      expect(choices(restored), expected);
    },
  );
  for (final change in ['edit', 'move', 'replace', 'new preparation']) {
    test(
      'current-source verification race expires comparison after $change',
      () async {
        final compiler = DeferredLineageCompiler();
        final c = SyntheticCompositionController(compiler: compiler);
        await c.ready;
        addTearDown(c.dispose);
        final r = await changed(c);
        final saved = (await c.saveEditableWorkspace())!;
        compiler.pauseLineage = SyntheticStrengthLineage.a.id;
        final pending = c.prepareUseVersion('W1D1S1', r);
        await Future<void>.delayed(Duration.zero);
        switch (change) {
          case 'edit':
            c.programme.editProgramme('name', 'Changed while preparing');
          case 'move':
            c.programme.setDayType(0, 1, 'training');
            c.programme.moveSlot(0, 0, 0, 0, 1, 0);
          case 'replace':
            final replacement = (await c.prepareEditableWorkspace(saved))!;
            expect(await c.replaceEditableWorkspace(replacement), true);
          case 'new preparation':
            expect(await c.prepareUseVersion('W1D1S1', r), isNotNull);
        }
        compiler.gate!.complete();
        expect(await pending, null);
        expect(c.admitted.length, 1);
      },
    );
  }
  test(
    'failed current-source verification preserves catalogue selection and current review receipt',
    () async {
      final compiler = DeferredLineageCompiler();
      final c = SyntheticCompositionController(compiler: compiler);
      await c.ready;
      addTearDown(c.dispose);
      final r = await changed(c);
      expect(await c.validate(), true);
      final source = c.programme.draftSource,
          available = c.admitted,
          receipt = c.current;
      compiler.pauseLineage = SyntheticStrengthLineage.a.id;
      compiler.fail = true;
      final pending = c.prepareUseVersion('W1D1S1', r);
      await Future<void>.delayed(Duration.zero);
      compiler.gate!.complete();
      expect(await pending, null);
      expect(c.programme.draftSource, source);
      expect(c.admitted, available);
      expect(c.current, same(receipt));
    },
  );
  for (final queued in [false, true]) {
    test(
      'edit after comparison preparation notification cannot expose stale consent queued=$queued',
      () async {
        final c = SyntheticCompositionController();
        await c.ready;
        addTearDown(c.dispose);
        final r = await changed(c);
        var once = false;
        c.addListener(() {
          if (!c.busy && !once) {
            once = true;
            void edit() => c.programme.editProgramme('name', 'Newer state');
            if (queued) {
              scheduleMicrotask(edit);
            } else {
              edit();
            }
          }
        });
        expect(await c.prepareUseVersion('W1D1S1', r), null);
        expect(c.admitted.length, 1);
      },
    );
  }
  test(
    'edit at atomic confirmation notification refuses before any admission',
    () async {
      final c = SyntheticCompositionController();
      await c.ready;
      addTearDown(c.dispose);
      final r = await changed(c);
      final p = (await c.prepareUseVersion('W1D1S1', r))!;
      var once = false;
      c.addListener(() {
        if (c.busy && !once) {
          once = true;
          c.programme.editProgramme('name', 'Changed at confirmation');
        }
      });
      expect(await c.usePreparedVersion(p), false);
      expect(c.admitted.length, 1);
      expect(choices(c)['W1D1S1'], 'SYN-D2-STRENGTH-R1');
    },
  );
}
