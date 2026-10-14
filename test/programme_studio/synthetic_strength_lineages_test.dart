import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_identity_mapping.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_programme_revision_catalogue.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';

class DeferredLineageCompiler extends SyntheticStrengthSessionCompiler {
  DeferredLineageCompiler() : super(allowSecondLineage: true);
  String? pauseLineage;
  bool fail = false;
  int pauseAfter = 0;
  Completer<void>? gate;
  @override
  Future<D2CompiledSession> compileExact(
    String source,
    SessionRevisionIdentity identity,
  ) async {
    if (pauseLineage == identity.sessionLineageId) {
      if (pauseAfter > 0) {
        pauseAfter--;
        return super.compileExact(source, identity);
      }
      pauseLineage = null;
      gate = Completer<void>();
      await gate!.future;
      if (fail) throw const FormatException('deferred foreign-owner failure');
    }
    return super.compileExact(source, identity);
  }
}

void enterRoot(ProtocolAuthoringController owner) {
  owner.editSession('title', 'Synthetic strength session');
  owner.editBlock('title', 'Straight sets');
  owner.replaceExercise(0, 'cohort.exercise.d2_fixture_b');
  owner.editExercise(0, 'sets', '3');
  owner.editExercise(0, 'reps', '8');
}

String selectedKey(SyntheticCompositionController c, int slot) =>
    ((c.programme.tree!['weeks'] as List).single['days'] as List)
            .first['slots'][slot]['session_key']
        as String;
Future<void> createB(SyntheticCompositionController c) async {
  c.createSecondSession();
  enterRoot(c.secondSession);
  expect(
    await c.secondSession.freeze(),
    true,
    reason: c.secondSession.errors.join("\n"),
  );
}

Future<void> twoSlots(SyntheticCompositionController c) async {
  await createB(c);
  expect(await c.admit(c.secondSession.revisions.single), true);
  c.programme.addSlot(0, 0, 'W1D1S2', d2SessionKey(1));
  expect(
    await c.selectRevision(0, 0, 1, SyntheticStrengthLineage.b.identity(1)),
    true,
  );
}

void main() {
  Future<SyntheticCompositionController> open({
    SyntheticStrengthSessionCompiler? compiler,
  }) async {
    final c = SyntheticCompositionController(compiler: compiler);
    await c.ready;
    expect(c.initialized, true);
    addTearDown(c.dispose);
    return c;
  }

  test(
    'live owners cannot be replaced with a foreign identical catalogue',
    () async {
      final c = await open();
      await twoSlots(c);
      final foreign = ProtocolAuthoringController(
        lineage: SyntheticStrengthLineage.b,
      );
      await foreign.ready;
      addTearDown(foreign.dispose);
      foreign.createRootDraft();
      enterRoot(foreign);
      expect(await foreign.freeze(), true);
      final owner = c.secondSession;
      expect(
        () => (c as dynamic).secondSession = foreign,
        throwsNoSuchMethodError,
      );
      expect(c.secondSession, same(owner));
      expect(await c.admit(foreign.revisions.single), false);
    },
  );
  test(
    'B initial root requires input; failure and cancellation allocate no source or selection',
    () async {
      final c = await open();
      final a = c.admitted.single.source;
      await c.validate();
      c.createSecondSession();
      final draft = c.secondSession.tree!;
      final session =
          (draft['weeks'] as List).single['days'].single['sessions'].single
              as Map;
      expect(session['title'], '');
      expect(session['blocks'].single['exercises'].single['prescription'], {
        'sets': '',
        'reps': '',
      });
      expect(c.current, null);
      expect(await c.exportHandoff(), null);
      expect(await c.secondSession.freeze(), false);
      expect(c.secondSession.revisions, isEmpty);
      c.secondSession.cancelDraft();
      expect(c.secondSession.canCreateRoot, true);
      expect(c.admitted.single.source, a);
      expect(selectedKey(c, 0), d2SessionKey(1));
      await createB(c);
      expect(c.secondSession.activeIdentity.revisionNumber, 1);
      expect(c.admitted.length, 1);
      expect(c.secondSession.canCreateRoot, false);
    },
  );
  test(
    'same title and R1/R2 across owners remain distinct through slots and complete reopen',
    () async {
      final c = await open();
      await twoSlots(c);
      final a1 = c.session.revisions.first,
          b1 = c.secondSession.revisions.first;
      c.session.createDraft();
      c.session.editExercise(0, 'reps', '6');
      expect(await c.session.freeze(), true);
      c.secondSession.createDraft();
      c.secondSession.editExercise(0, 'reps', '9');
      expect(
        await c.secondSession.freeze(),
        true,
        reason: c.secondSession.errors.join("\n"),
      );
      final a2 = c.session.revisions.last, b2 = c.secondSession.revisions.last;
      expect(a2.identity.revisionNumber, 2);
      expect(b2.identity.revisionNumber, 2);
      expect(a2.compiled.protocol.name, b2.compiled.protocol.name);
      expect(a2.source, isNot(b2.source));
      expect(await c.admit(a2), true);
      expect(await c.admit(b2), true);
      expect(selectedKey(c, 0), d2SessionKey(1));
      expect(selectedKey(c, 1), SyntheticStrengthLineage.b.sessionKey(1));
      expect(await c.selectRevision(0, 0, 0, a2.identity), true);
      expect(c.session.revisions.first.source, a1.source);
      expect(c.secondSession.revisions.first.source, b1.source);
      final packet = (await c.exportHandoff())!;
      final data = jsonDecode(packet) as Map;
      expect(data['version'], 2);
      expect(data['sessions'].length, 4);
      expect(c.current!.slotBindings.map((s) => s['session_lineage_id']), [
        SyntheticStrengthLineage.a.id,
        SyntheticStrengthLineage.b.id,
      ]);
      expect(
        c
            .current!
            .catalog
            .developerFixtures
            .single
            .weeks
            .single
            .days
            .first
            .sessions
            .last
            .blocks
            .single
            .movements
            .single
            .reps,
        '8',
      );
      final live = c.programme.draftSource,
          owners = c.owners,
          versions = c.owners.map((o) => o.revisions).toList();
      expect(await c.reopen(packet), true);
      expect(c.reconstructedExport(), packet);
      expect(c.programme.draftSource, live);
      expect(c.owners, owners);
      expect(c.owners.map((o) => o.revisions).toList(), versions);
      expect(
        c.reconstructed!.sessions.map((s) => s.sourceDigest).toSet().length,
        4,
      );
      expect(c.compiler.store.mutationAttempts, 0);
    },
  );
  test(
    'B reservations/no-op evolve independently; A bytes and references remain fixed',
    () async {
      final c = await open();
      await twoSlots(c);
      final a = c.session.revisions.single.source;
      c.secondSession.createDraft();
      expect(await c.secondSession.freeze(), false);
      c.secondSession.cancelDraft();
      c.secondSession.createDraft();
      expect(c.secondSession.activeIdentity.revisionNumber, 3);
      c.secondSession.editExercise(0, 'sets', '4');
      expect(
        await c.secondSession.freeze(),
        true,
        reason: c.secondSession.errors.join("\n"),
      );
      expect(await c.admit(c.secondSession.revisions.last), true);
      expect(selectedKey(c, 1), SyntheticStrengthLineage.b.sessionKey(1));
      expect(c.session.revisions.single.source, a);
      expect(
        await c.selectRevision(
          0,
          0,
          1,
          c.secondSession.revisions.last.identity,
        ),
        true,
      );
      expect(selectedKey(c, 0), d2SessionKey(1));
    },
  );
  test(
    'all-slot correctness after B selection, movement and independent ordering',
    () async {
      final c = await open();
      await twoSlots(c);
      c.programme.setDayType(0, 1, 'training');
      c.programme.moveSlot(0, 0, 1, 0, 1, 0);
      expect(await c.validate(), true, reason: c.errors.join("\n"));
      expect(c.current!.slotBindings.length, 2);
      expect(c.current!.slotBindings.last['slot_key'], 'W1D1S2');
      expect(
        c.current!.slotBindings.last['source_digest'],
        c.secondSession.revisions.single.digest,
      );
      c.programme.moveSlot(0, 1, 0, 0, 0, 0);
      expect(await c.validate(), false);
      expect(c.errors.join(), contains("Training days must reference"));
      c.programme.setDayType(0, 1, "rest");
      expect(await c.validate(), true, reason: c.errors.join("\n"));
      expect(
        c.current!.slotBindings.first['session_lineage_id'],
        SyntheticStrengthLineage.b.id,
      );
      expect(
        c.current!.slotBindings.last['session_lineage_id'],
        SyntheticStrengthLineage.a.id,
      );
    },
  );
  test(
    'foreign identical B root, wrong owner and conflicting source fail atomically',
    () async {
      final c = await open();
      await twoSlots(c);
      final foreign = ProtocolAuthoringController(
        lineage: SyntheticStrengthLineage.b,
      );
      await foreign.ready;
      addTearDown(foreign.dispose);
      foreign.createRootDraft();
      enterRoot(foreign);
      expect(await foreign.freeze(), true);
      final source = c.programme.draftSource, entries = c.admitted;
      expect(await c.admit(foreign.revisions.single), false);
      expect(c.admitted, entries);
      expect(c.programme.draftSource, source);
      c.secondSession.openIdentity(SyntheticStrengthLineage.a.identity(1));
      expect(c.secondSession.errors.join(), contains('foreign'));
      final conflicting = await c.compiler.compileExact(
        c.secondSession.revisions.single.source.replaceFirst(
          'reps: 8',
          'reps: 10',
        ),
        SyntheticStrengthLineage.b.identity(1),
      );
      final catalogue = SyntheticProgrammeRevisionCatalogue(
        c.session.revisions.single,
      );
      catalogue.appendVerified(c.secondSession.revisions.single.compiled);
      expect(
        () => catalogue.appendVerified(conflicting),
        throwsFormatException,
      );
      expect(await c.admit(c.secondSession.revisions.single), true);
      expect(c.admitted.length, 2);
    },
  );
  for (final altered in ['version', 'definition', 'mapping']) {
    test(
      'actual compiler fingerprint rejects altered $altered even if resolved IDs agree',
      () async {
        final defs = d2ExerciseDefinitions(), maps = d2IdentityMappings();
        if (altered == 'mapping') {
          maps[0] = ExerciseIdentityMapping.fromJson({
            ...maps[0].toJson(),
            'provenance': 'foreign profile',
          });
        } else {
          defs[0] = ExerciseDefinition.fromJson({
            ...defs[0].toJson(),
            if (altered == 'version')
              'version': '2'
            else
              'canonical_name': 'Foreign name',
          });
        }
        final c = SyntheticCompositionController(
          compiler: SyntheticStrengthSessionCompiler(
            definitions: defs,
            mappings: maps,
            allowSecondLineage: true,
          ),
        );
        addTearDown(c.dispose);
        await c.ready;
        expect(c.initialized, false);
        expect(c.admitted, isEmpty);
        expect(c.errors, isNotEmpty);
      },
    );
  }
  test(
    'old single-lineage v1 transport remains byte-identical to the published baseline',
    () async {
      final c = await open();
      final packet = (await c.exportHandoff())!;
      expect(
        packet,
        File(
          'docs/checkpoints/programme_studio_strength_lineages/ORIGINAL_V1_HANDOFF.json',
        ).readAsStringSync(),
      );
      expect(await c.reopen(packet), true);
      expect(c.reconstructedExport(), packet);
      await twoSlots(c);
      final multi = (await c.exportHandoff())!;
      final reordered = jsonDecode(multi) as Map<String, dynamic>;
      reordered['sessions'] = (reordered['sessions'] as List).reversed.toList();
      expect(await c.reopen(jsonEncode(reordered)), true);
      expect(c.reconstructedExport(), multi);
    },
  );
  for (final tamper in [
    'missing-root',
    'duplicate',
    'foreign',
    'identity',
    'source',
    'bindings',
    'profile',
    'version',
    'wrapper',
    'slot',
    'extra',
  ]) {
    test(
      'v2 rejects $tamper without changing live owners or sources',
      () async {
        final c = await open();
        await twoSlots(c);
        final bytes = (await c.exportHandoff())!;
        final data = jsonDecode(bytes) as Map<String, dynamic>;
        final rows = data['sessions'] as List;
        final row =
            rows.singleWhere(
                  (r) =>
                      r['identity']['session_lineage_id'] ==
                      SyntheticStrengthLineage.b.id,
                )
                as Map;
        switch (tamper) {
          case 'missing-root':
            rows.remove(row);
          case 'duplicate':
            rows.add(row);
          case 'foreign':
            row['identity']['session_lineage_id'] = 'FOREIGN';
          case 'identity':
            row['identity']['protocol_id'] = d2RootProtocolId;
          case 'source':
            row['founder_yaml'] = row['founder_yaml'].replaceFirst(
              'reps: 8',
              'reps: 99',
            );
          case 'bindings':
            row['exercise_bindings']['cohort.exercise.d2_fixture_b'] =
                'EX-9002@2';
          case 'profile':
            data['fixture_profile']['fingerprint'] = 'forged';
          case 'version':
            data['version'] = 1;
          case 'wrapper':
            row['founder_yaml'] = row['founder_yaml'].replaceFirst(
              'Fixed synthetic wrapper notes.',
              'Forged wrapper.',
            );
            row['source_digest'] = d2SourceDigest(row['founder_yaml']);
          case 'slot':
            data['slot_bindings'].last['protocol_id'] = d2RootProtocolId;
          case 'extra':
            row['approved'] = true;
        }
        final live = c.programme.draftSource,
            owners = c.owners,
            sources = c.admitted;
        expect(await c.reopen(jsonEncode(data)), false);
        expect(c.current, null);
        expect(c.reconstructed, null);
        expect(c.programme.draftSource, live);
        expect(c.owners, owners);
        expect(c.admitted, sources);
      },
    );
  }
  for (final operation in [
    'review',
    'selection',
    'admission',
    'reopen',
    'export',
  ]) {
    test(
      '$operation ignores cross-owner edits during pending source compilation',
      () async {
        final compiler = DeferredLineageCompiler();
        final c = await open(compiler: compiler);
        // Use the actually owned compiler so deferral participates in the workspace.
        final owned = c.compiler as DeferredLineageCompiler;
        await twoSlots(c);
        final packet = (await c.exportHandoff())!;
        owned.pauseLineage =
            operation == 'selection' || operation == 'admission'
            ? SyntheticStrengthLineage.b.id
            : SyntheticStrengthLineage.a.id;
        final Future<Object?> pending = switch (operation) {
          'selection' => c.selectRevision(
            0,
            0,
            1,
            SyntheticStrengthLineage.b.identity(1),
          ),
          'admission' => c.admit(c.secondSession.revisions.single),
          'reopen' => c.reopen(packet),
          'export' => c.exportHandoff(),
          _ => c.validate(),
        };
        await Future<void>.delayed(Duration.zero);
        final editedOwner = operation == 'selection' || operation == 'admission'
            ? c.session
            : c.secondSession;
        editedOwner.createDraft();
        editedOwner.editExercise(0, 'reps', '10');
        owned.gate!.complete();
        final result = await pending;
        expect(result, operation == 'export' ? null : false);
        expect(c.current, null);
        expect(c.reconstructed, null);
        expect(selectedKey(c, 1), SyntheticStrengthLineage.b.sessionKey(1));
        expect(compiler.store.mutationAttempts, 0);
      },
    );
  }
  for (final stage in [0, 1]) {
    for (final action in ['cancel', 'reset', 'dispose']) {
      test(
        'initial B freeze stays atomic during $action at compile $stage',
        () async {
          final compiler = DeferredLineageCompiler();
          final c = await open(compiler: compiler);
          final owned = c.compiler as DeferredLineageCompiler;
          c.createSecondSession();
          enterRoot(c.secondSession);
          final old = c.secondSession;
          owned.pauseLineage = SyntheticStrengthLineage.b.id;
          owned.pauseAfter = stage;
          final pending = old.freeze();
          await Future<void>.delayed(Duration.zero);
          if (action == 'cancel') {
            old.cancelDraft();
          } else if (action == 'reset') {
            await c.reset();
          } else {
            c.dispose();
          }
          owned.gate!.complete();
          expect(await pending, false);
          expect(old.revisions, isEmpty);
          if (action != 'dispose') {
            expect(c.admitted.length, 1);
            expect(selectedKey(c, 0), d2SessionKey(1));
          }
          expect(compiler.store.mutationAttempts, 0);
        },
      );
    }
  }
  test(
    'unselected B edits invalidate export consumption and open review receipts',
    () async {
      final c = await open();
      await createB(c);
      await c.admit(c.secondSession.revisions.single);
      final packet = (await c.exportHandoff())!, receipt = c.current!;
      c.secondSession.createDraft();
      expect(c.canConsumeExport(packet), false);
      expect(c.isCurrentReceipt(receipt), false);
      c.secondSession.cancelDraft();
      expect(await c.validate(), true, reason: c.errors.join("\n"));
      expect(
        c.current!.slotBindings.single['session_lineage_id'],
        SyntheticStrengthLineage.a.id,
      );
    },
  );
  test('late B failure cannot replace a newer successful receipt', () async {
    final compiler = DeferredLineageCompiler();
    final c = await open(compiler: compiler);
    final owned = c.compiler as DeferredLineageCompiler;
    await twoSlots(c);
    owned.pauseLineage = SyntheticStrengthLineage.b.id;
    owned.fail = true;
    final pending = c.validate();
    await Future<void>.delayed(Duration.zero);
    expect(await c.validate(), true, reason: c.errors.join("\n"));
    final receipt = c.current;
    owned.gate!.complete();
    expect(await pending, false);
    expect(c.current, receipt);
    expect(c.errors, isEmpty);
    expect(compiler.store.mutationAttempts, 0);
  });
}
