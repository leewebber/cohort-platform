import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';

class PausedCompiler extends SyntheticStrengthSessionCompiler {
  int calls = 0;
  int? pauseCall;
  Completer<void>? entered, gate;
  Future<void> pauseAfter(int count) {
    pauseCall = calls + count;
    entered = Completer<void>();
    gate = Completer<void>();
    return entered!.future;
  }

  void release() => gate!.complete();
  @override
  Future<D2CompiledSession> compileExact(
    String source,
    SessionRevisionIdentity identity,
  ) async {
    calls++;
    if (calls == pauseCall) {
      entered!.complete();
      await gate!.future;
    }
    return super.compileExact(source, identity);
  }
}

Future<ProtocolAuthoringController> controller({
  SyntheticStrengthSessionCompiler? compiler,
}) async {
  final c = ProtocolAuthoringController(compiler: compiler);
  await c.ready;
  expect(c.initialized, true);
  addTearDown(c.dispose);
  return c;
}

void main() {
  for (final queued in [false, true]) {
    for (final action in [
      if (!queued) 'validate',
      'exportFounder',
      'exportPackage',
      'freeze',
    ]) {
      test(
        '$action refuses an edit at validation completion (queued=$queued)',
        () async {
          final c = await controller();
          c.createDraft();
          c.editExercise(0, 'reps', '6');
          var edited = false;
          c.addListener(() {
            if (!edited && c.current != null) {
              edited = true;
              void edit() => c.editExercise(0, 'reps', '7');
              if (queued) {
                scheduleMicrotask(edit);
              } else {
                edit();
              }
            }
          });
          final result = await switch (action) {
            'validate' => c.validate(),
            'exportFounder' => c.exportFounder(),
            'exportPackage' => c.exportPackage(),
            _ => c.freeze(),
          };
          expect(edited, true);
          expect(result, action.startsWith('export') ? isNull : false);
          expect(c.current, isNull);
          expect(c.revisions.length, 1);
          expect(c.selectedRevision, 1);
          expect(c.isEditing, true);
        },
      );
    }
  }
  test(
    'create/edit/freeze never changes R1 bytes or selected programme; selection is separate',
    () async {
      final c = await controller();
      final original = c.source, package = c.selectedProgrammeSource;
      expect(await c.validate(), true);
      final rootDigest = c.revisions.single.digest;
      c.createDraft();
      expect(c.activeIdentity.revisionNumber, 2);
      expect(c.current, isNull);
      c.editExercise(0, 'reps', '6');
      expect(await c.validate(), true);
      expect(c.current!.session.protocol.name, 'Synthetic strength session');
      expect(await c.freeze(), true);
      expect(c.isEditing, false);
      expect(c.current, isNull);
      expect(c.selectedRevision, 1);
      expect(c.selectedProgrammeSource, package);
      expect(c.revisions.first.source, original);
      expect(c.revisions.first.digest, rootDigest);
      expect(await c.selectProgrammeRevision(2), true);
      expect(c.selectedRevision, 2);
      final review = c
          .current!
          .catalog
          .developerFixtures
          .single
          .weeks
          .single
          .days
          .first
          .sessions
          .single;
      expect(review.revisionNumber, 2);
      expect(review.blocks.single.movements.first.reps, '6');
      expect(
        c
            .revisions
            .first
            .compiled
            .protocol
            .blocks
            .single
            .linkedExercises
            .first
            .prescription!
            .reps
            .exactReps,
        5,
      );
      final before =
          jsonDecode(
                const PlanPackageCompiler().compile(package).canonicalJson!,
              )
              as Map;
      final after =
          jsonDecode(
                const PlanPackageCompiler()
                    .compile(c.selectedProgrammeSource)
                    .canonicalJson!,
              )
              as Map;
      for (final key in [
        'programme',
        'phases',
        'adaptation_permissions',
        'protected_invariants',
        'assessments',
        'performance_evidence_requirements',
        'comparison_identities',
      ]) {
        expect(after[key], before[key], reason: key);
      }
      final oldSlot =
          ((before['weeks'].single['days'].first)['slots'] as List).single
              as Map;
      final newSlot =
          ((after['weeks'].single['days'].first)['slots'] as List).single
              as Map;
      final expected = {...oldSlot, 'session_key': d2SessionKey(2)};
      expect(newSlot, expected);
      c.createDraft();
      expect(c.activeIdentity.revisionNumber, 3);
      c.editSession('title', 'R3 candidate');
      expect(
        c.revisions.last.compiled.protocol.name,
        'Synthetic strength session',
      );
    },
  );
  test(
    'no-op and formatting-only drafts cannot freeze; abandoned numbers are not reused',
    () async {
      final c = await controller();
      c.createDraft();
      final draft = c.source;
      expect(c.reopen('# formatting only\n$draft'), true);
      expect(await c.freeze(), false);
      expect(c.errors.join(), contains('no_semantic_change'));
      expect(c.current, isNull);
      expect(c.revisions.length, 1);
      c.cancelDraft();
      c.createDraft();
      expect(c.activeIdentity.revisionNumber, 3);
      c.editBlock('title', 'New block');
      expect(await c.freeze(), true);
      expect(c.revisions.map((r) => r.identity.revisionNumber), [1, 3]);
    },
  );
  test(
    'invalid input and unsupported reopen retain source and clear all success',
    () async {
      final c = await controller();
      c.createDraft();
      c.editSession('title', 'New title');
      expect(await c.validate(), true);
      c.editSession('title', '');
      expect(c.current, isNull);
      expect(await c.exportFounder(), isNull);
      expect(c.errors.join(), contains('session.title'));
      c.resetDraft();
      expect(c.current, isNull);
      c.editExercise(0, 'reps', '6');
      expect(await c.validate(), true);
      final bad = '${c.source}\nunsupported_contract: {keep: true}\n';
      expect(c.reopen(bad), false);
      expect(c.source, bad);
      expect(c.tree, isNull);
      expect(c.current, isNull);
      expect(await c.exportPackage(), isNull);
      c.resetDraft();
      expect(c.source, contains('reps: 5'));
      expect(c.current, isNull);
      final wrong = c.source.replaceFirst(d2ImportKey(2), d2ImportKey(1));
      expect(c.reopen(wrong), false);
      expect(c.source, wrong);
    },
  );
  test(
    'wrapper edits and unpublished/foreign revisions cannot silently replace bindings',
    () async {
      final c = await controller();
      c.createDraft();
      final changed = c.source.replaceFirst(
        'Synthetic week',
        'Different wrapper',
      );
      expect(c.reopen(changed), false);
      expect(c.errors.join(), contains('wrapper_locked'));
      c.resetDraft();
      c.editSession('title', 'Valid edit');
      expect(await c.freeze(), true);
      final source = c.revisions.last.source;
      c.openRevision(1);
      expect(c.source, d2R1Source());
      expect(c.reopen(source), false);
      expect(c.revisions.last.source, source);
      expect(await c.selectProgrammeRevision(999), false);
      expect(c.selectedRevision, 1);
      expect(c.current, isNull);
    },
  );
  test(
    'export/reopen/export is identical and body/package identity remain separate',
    () async {
      final c = await controller();
      final package = c.selectedProgrammeSource, hash = c.selectedProgrammeHash;
      c.createDraft();
      c.editExercise(0, 'notes', 'Unicode cue 😀\nsecond line');
      final exported = await c.exportFounder();
      expect(exported, isNotNull);
      final sourceDigest = c.current!.session.sourceDigest,
          candidatePackageHash = c.current!.packageHash;
      expect(c.selectedProgrammeSource, package);
      expect(c.selectedProgrammeHash, hash);
      expect(c.reopen(exported!), true);
      expect(c.current, isNull);
      expect(await c.exportFounder(), exported);
      expect(c.current!.session.sourceDigest, sourceDigest);
      expect(c.current!.packageHash, candidatePackageHash);
      c.editExercise(0, 'notes', 'A different cue');
      expect(await c.validate(), true);
      expect(c.current!.session.sourceDigest, isNot(sourceDigest));
      expect(c.current!.packageHash, candidatePackageHash);
      expect(c.selectedProgrammeHash, hash);
    },
  );
  test(
    'add/remove/reorder keeps authored dose; incomplete and duplicate rows fail',
    () async {
      final c = await controller();
      c.createDraft();
      c.moveExercise(0, 1);
      expect(await c.validate(), true);
      expect(
        c.current!.session.protocol.blocks.single.linkedExercises.map(
          (l) => l.exerciseId,
        ),
        ['EX-9002', 'EX-9001'],
      );
      c.removeExercise(1);
      c.addExercise();
      expect(await c.validate(), false);
      c.replaceExercise(1, 'cohort.exercise.d2_fixture_a');
      c.editExercise(1, 'sets', '3');
      c.editExercise(1, 'reps', '7');
      expect(await c.validate(), true, reason: c.errors.join());
      c.replaceExercise(1, 'cohort.exercise.d2_fixture_b');
      expect(await c.validate(), false);
      expect(c.errors.join(), contains('duplicate exercise'));
      c.resetDraft();
      c.setLoadMode(0, 'bodyweight');
      expect(await c.validate(), true);
      expect(
        c
            .current!
            .session
            .protocol
            .blocks
            .single
            .linkedExercises
            .first
            .prescription!
            .load,
        isNotNull,
      );
      c.setLoadMode(0, 'unspecified');
      expect(await c.validate(), true);
      expect(
        c
            .current!
            .session
            .protocol
            .blocks
            .single
            .linkedExercises
            .first
            .prescription!
            .load,
        isNull,
      );
      c.setLoadMode(0, 'rpe');
      c.editLoadValue(0, '11');
      expect(await c.validate(), false);
      expect(c.errors.join(), contains('1–10'));
      c.editLoadValue(0, '7');
      expect(await c.validate(), true);
    },
  );
  test(
    'late validation/export cannot resurrect success after editing',
    () async {
      final compiler = PausedCompiler();
      final d = await controller(compiler: compiler);
      d.createDraft();
      final entered = compiler.pauseAfter(1);
      final pending = d.exportFounder();
      await entered;
      d.editSession('title', '');
      expect(d.current, isNull);
      compiler.release();
      expect(await pending, isNull);
      expect(d.current, isNull);
      expect(await d.validate(), false);
    },
  );
  test(
    'editing during final freeze verification cannot add an obsolete snapshot',
    () async {
      final compiler = PausedCompiler();
      final c = await controller(compiler: compiler);
      c.createDraft();
      c.editExercise(0, 'reps', '6');
      final entered = compiler.pauseAfter(2);
      final pending = c.freeze();
      await entered;
      c.editExercise(0, 'reps', '7');
      compiler.release();
      expect(await pending, false);
      expect(c.revisions.length, 1);
      expect(c.current, isNull);
      expect(await c.freeze(), true);
      expect(
        c
            .revisions
            .last
            .compiled
            .protocol
            .blocks
            .single
            .linkedExercises
            .first
            .prescription!
            .reps
            .exactReps,
        7,
      );
    },
  );
  test(
    'selection and overlapping validation races are generation bound',
    () async {
      final compiler = PausedCompiler();
      final c = await controller(compiler: compiler);
      c.createDraft();
      c.editExercise(0, 'reps', '6');
      expect(await c.freeze(), true);
      final entered = compiler.pauseAfter(1);
      final selection = c.selectProgrammeRevision(2);
      await entered;
      c.openRevision(1);
      compiler.release();
      expect(await selection, false);
      expect(c.selectedRevision, 1);
      expect(c.current, isNull);
      c.createDraft();
      final second = compiler.pauseAfter(1);
      final old = c.validate();
      await second;
      c.editExercise(0, 'reps', '8');
      expect(await c.validate(), true);
      final current = c.current;
      compiler.release();
      expect(await old, false);
      expect(c.current, same(current));
    },
  );
}
