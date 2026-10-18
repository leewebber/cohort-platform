import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_session_revision_catalogue.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'synthetic_strength_lineages_test.dart'
    show DeferredLineageCompiler, createB, enterRoot;

String selection(SyntheticCompositionController c) =>
    c.programme.tree!['weeks'][0]['days'][0]['slots'][0]['session_key']
        as String;
Future<D2LocalRevision> changed(SyntheticCompositionController c) async {
  c.session.createDraft();
  c.session.editExercise(0, 'reps', '6');
  expect(await c.session.freeze(), true);
  return c.session.revisions.last;
}

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
    'prepared consent mutates neither side; commit is observed atomically and keeps old bytes',
    () async {
      final c = await open();
      final old = c.admitted.single.source;
      final r = await changed(c);
      final before = c.programme.draftSource;
      final prepared = (await c.prepareUseVersion('W1D1S1', r))!;
      expect(c.admitted.length, 1);
      expect(c.programme.draftSource, before);
      final observed = <(int, String)>[];
      void observe() => observed.add((c.admitted.length, selection(c)));
      c.addListener(observe);
      c.programme.addListener(observe);
      expect(await c.usePreparedVersion(prepared), true);
      expect(
        observed
            .where((s) => s.$1 == 2)
            .every((s) => s.$2 == 'SYN-D2-STRENGTH-R2'),
        true,
      );
      expect(selection(c), 'SYN-D2-STRENGTH-R2');
      expect(c.admitted.length, 2);
      expect(c.session.revisions.first.source, old);
      expect(await c.usePreparedVersion(prepared), false);
      final repeat = (await c.prepareUseVersion('W1D1S1', r))!;
      expect(await c.usePreparedVersion(repeat), true);
      expect(c.admitted.length, 2);
    },
  );
  test(
    'invalid target, invalid prospective programme and foreign owner leave admission and selection untouched',
    () async {
      final c = await open();
      final r = await changed(c);
      final before = c.programme.draftSource;
      expect(await c.prepareUseVersion('missing', r), null);
      expect(c.admitted.length, 1);
      expect(c.programme.draftSource, before);
      c.programme.editProgramme('name', '');
      final invalid = c.programme.draftSource;
      expect(await c.prepareUseVersion('W1D1S1', r), null);
      expect(c.admitted.length, 1);
      expect(c.programme.draftSource, invalid);
      final foreign = ProtocolAuthoringController();
      await foreign.ready;
      addTearDown(foreign.dispose);
      foreign.createDraft();
      foreign.editExercise(0, 'reps', '6');
      expect(await foreign.freeze(), true);
      expect(await c.prepareUseVersion('W1D1S1', foreign.revisions.last), null);
      expect(c.admitted.length, 1);
      expect(c.programme.draftSource, invalid);
    },
  );
  for (final edit in [
    'programme',
    'prescription',
    'other owner',
    'move',
    'reset',
  ]) {
    test('confirmation expires after $edit changes relevant state', () async {
      final c = await open();
      final r = await changed(c);
      final p = (await c.prepareUseVersion('W1D1S1', r))!;
      switch (edit) {
        case 'programme':
          c.programme.editProgramme('name', 'Changed');
        case 'prescription':
          c.session.createDraft();
          c.session.editExercise(0, 'reps', '7');
        case 'other owner':
          c.createSecondSession();
        case 'move':
          c.programme.setDayType(0, 1, 'training');
          c.programme.moveSlot(0, 0, 0, 0, 1, 0);
        case 'reset':
          await c.reset();
      }
      final source = c.programme.draftSource;
      final admitted = c.admitted;
      expect(c.isCurrentVersionUse(p), false);
      expect(await c.usePreparedVersion(p), false);
      expect(c.programme.draftSource, source);
      expect(c.admitted, admitted);
    });
  }
  test(
    'B descendant includes its genuine unadmitted root in one atomic commit and round trip',
    () async {
      final c = await open();
      final a = c.session.revisions.single.source;
      await createB(c);
      c.secondSession.createDraft();
      c.secondSession.editExercise(0, 'reps', '9');
      expect(await c.secondSession.freeze(), true);
      c.programme.addSlot(0, 0, 'W1D1S2', 'SYN-D2-STRENGTH-R1');
      final p = (await c.prepareUseVersion(
        'W1D1S2',
        c.secondSession.revisions.last,
      ))!;
      expect(c.admitted.length, 1);
      expect(p.includedVersions.length, 3);
      expect(await c.usePreparedVersion(p), true);
      expect(c.admitted.length, 3);
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][1]['session_key'],
        'SYN-D2-STRENGTH-B-R2',
      );
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(c.session.revisions.single.source, a);
      final packet = (await c.exportHandoff())!;
      expect(await c.reopen(packet), true);
      expect(c.reconstructedExport(), packet);
    },
  );
  for (final change in ['other owner', 'reset', 'dispose']) {
    test(
      'pending preparation ignores $change without partial admission',
      () async {
        final compiler = DeferredLineageCompiler();
        final c = await open(compiler: compiler);
        final r = await changed(c);
        final original = selection(c);
        compiler.pauseLineage = SyntheticStrengthLineage.a.id;
        final pending = c.prepareUseVersion('W1D1S1', r);
        await Future<void>.delayed(Duration.zero);
        if (change == 'other owner') {
          c.createSecondSession();
          enterRoot(c.secondSession);
        } else if (change == 'reset') {
          await c.reset();
        } else {
          c.dispose();
        }
        compiler.gate!.complete();
        expect(await pending, null);
        expect(c.admitted.length, 1);
        expect(selection(c), original);
      },
    );
  }
  test(
    'atomic second-slot choice preserves first-slot selection and both-owner bytes through ordering',
    () async {
      final c = await open();
      await createB(c);
      c.programme.addSlot(0, 0, 'W1D1S2', 'SYN-D2-STRENGTH-R1');
      final a = c.session.revisions.single.source;
      final b = c.secondSession.revisions.single;
      final p = (await c.prepareUseVersion('W1D1S2', b))!;
      expect(await c.usePreparedVersion(p), true);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(
        c.programme.tree!['weeks'][0]['days'][0]['slots'][1]['session_key'],
        'SYN-D2-STRENGTH-B-R1',
      );
      c.programme.moveSlot(0, 0, 1, 0, 0, 0);
      expect(await c.validate(), true);
      expect(
        c.current!.slotBindings.first['session_lineage_id'],
        SyntheticStrengthLineage.b.id,
      );
      expect(
        c.current!.slotBindings.last['session_lineage_id'],
        SyntheticStrengthLineage.a.id,
      );
      expect(c.session.revisions.single.source, a);
      expect(c.secondSession.revisions.single.source, b.source);
    },
  );
  for (final queued in [false, true]) {
    for (final action in ['reset', 'dispose']) {
      test(
        'atomic completion refuses $action from notification (queued=$queued)',
        () async {
          final c = await open();
          final r = await changed(c);
          final p = (await c.prepareUseVersion('W1D1S1', r))!;
          var once = false;
          Future<void>? reset;
          c.addListener(() {
            if (!once &&
                c.admitted.length == 2 &&
                selection(c) == 'SYN-D2-STRENGTH-R2') {
              once = true;
              void replace() {
                if (action == 'reset') {
                  reset = c.reset();
                } else {
                  c.dispose();
                }
              }

              if (queued) {
                scheduleMicrotask(replace);
              } else {
                replace();
              }
            }
          });
          expect(await c.usePreparedVersion(p), false);
          await reset;
          if (action == 'reset') {
            expect(c.admitted.length, 1);
            expect(selection(c), 'SYN-D2-STRENGTH-R1');
          }
        },
      );
    }
  }
  test(
    'atomic completion preserves callback-started newer pending review',
    () async {
      final compiler = DeferredLineageCompiler();
      final c = await open(compiler: compiler);
      final r = await changed(c);
      final p = (await c.prepareUseVersion('W1D1S1', r))!;
      var once = false;
      Future<bool>? newer;
      c.addListener(() {
        if (!once && c.admitted.length == 2) {
          once = true;
          compiler.pauseLineage = SyntheticStrengthLineage.a.id;
          newer = c.validate();
        }
      });
      expect(await c.usePreparedVersion(p), true);
      expect(c.busy, true);
      expect(c.current, null);
      compiler.gate!.complete();
      expect(await newer, true);
      expect(c.current, isNotNull);
    },
  );
  test(
    'late preparation failure cannot replace a newer successful joint review',
    () async {
      final compiler = DeferredLineageCompiler();
      final c = await open(compiler: compiler);
      final r = await changed(c);
      compiler.pauseLineage = SyntheticStrengthLineage.a.id;
      compiler.fail = true;
      final pending = c.prepareUseVersion('W1D1S1', r);
      await Future<void>.delayed(Duration.zero);
      expect(await c.validate(), true);
      final receipt = c.current;
      compiler.gate!.complete();
      expect(await pending, null);
      expect(c.current, same(receipt));
      expect(c.errors, isEmpty);
      expect(c.admitted.length, 1);
    },
  );
}
