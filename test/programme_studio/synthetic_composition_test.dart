import 'dart:async';
import 'dart:convert';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_review_bridge.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_programme_revision_catalogue.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_controller.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_session_revision_catalogue.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';

String slotKey(SyntheticCompositionController c, [int slot = 0]) =>
    ((c.programme.tree!['weeks'] as List).single['days'] as List)
            .first['slots'][slot]['session_key']
        as String;
Future<D2LocalRevision> changed(SyntheticCompositionController c) async {
  c.session.createDraft();
  c.session.editExercise(0, 'reps', '6');
  expect(await c.session.freeze(), true);
  return c.session.revisions.last;
}

class PausedCompiler extends SyntheticStrengthSessionCompiler {
  bool pauseNext = false, fail = false;
  Completer<void>? gate;
  @override
  Future<D2CompiledSession> compileExact(
    String source,
    SessionRevisionIdentity identity,
  ) async {
    if (pauseNext) {
      pauseNext = false;
      gate = Completer<void>();
      await gate!.future;
      if (fail) throw const FormatException('deferred failure');
    }
    return super.compileExact(source, identity);
  }
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
    'fixed profile rejects a different exercise version on initialization',
    () async {
      final defs = d2ExerciseDefinitions().map((d) {
        final json = d.toJson();
        json['version'] = '2';
        return ExerciseDefinition.fromJson(json);
      }).toList();
      final c = SyntheticCompositionController(
        compiler: SyntheticStrengthSessionCompiler(definitions: defs),
      );
      addTearDown(c.dispose);
      await c.ready;
      expect(c.initialized, false);
      expect(c.errors.join(), contains('fixture_profile'));
      expect(c.admitted, isEmpty);
    },
  );
  test(
    'seed uses exact R1, complete locked contracts and current-source review',
    () async {
      final c = await open();
      expect(slotKey(c), d2SessionKey(1));
      expect(c.admitted.single.source, d2R1Source());
      expect(c.current, null);
      expect(await c.validate(), true);
      final r = c.current!;
      expect(r.sessions.single.source, d2R1Source());
      expect(
        r.slotBindings.single['source_digest'],
        c.admitted.single.sourceDigest,
      );
      final tree = c.programme.tree!;
      for (final key in [
        'adaptation_permissions',
        'protected_invariants',
        'assessments',
        'performance_evidence_requirements',
        'comparison_identities',
      ]) {
        expect(tree[key], isNotEmpty);
      }
      expect(c.compiler.store.mutationAttempts, 0);
    },
  );
  test(
    'freeze, append-only admission and exact selection are separate; preserve edits and R1',
    () async {
      final c = await open();
      final r1 = c.admitted.single;
      c.programme.editProgramme('name', 'Synthetic renamed');
      final r2 = await changed(c);
      expect(c.admitted.length, 1);
      expect(slotKey(c), d2SessionKey(1));
      expect(await c.admit(r2), true);
      expect(c.admitted.length, 2);
      expect(slotKey(c), d2SessionKey(1));
      expect(c.current, null);
      expect(c.programme.tree!['programme']['name'], 'Synthetic renamed');
      expect(await c.admit(r2), true);
      expect(c.admitted.length, 2);
      expect(await c.select(0, 0, 0, 2), true);
      expect(slotKey(c), d2SessionKey(2));
      expect(await c.validate(), true);
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
      expect(c.admitted.first.source, r1.source);
      expect(c.admitted.first.sourceDigest, r1.sourceDigest);
      expect(c.current!.sessions.map((s) => s.protocol.name).toSet().length, 1);
    },
  );
  test(
    'every slot is reviewed after add/order/move and exact required-slot selection',
    () async {
      final c = await open();
      final r2 = await changed(c);
      await c.admit(r2);
      c.programme.addSlot(0, 0, 'W1D1S2', d2SessionKey(1));
      await c.select(0, 0, 1, 2);
      c.programme.setDayType(0, 1, 'training');
      c.programme.moveSlot(0, 0, 1, 0, 1, 0);
      c.programme.editWeek(0, 'title', 'Synthetic edited week');
      c.programme.editDay(0, 1, 'coach_note', 'Synthetic day note');
      expect(await c.validate(), true);
      expect(c.current!.slotBindings.length, 2);
      expect(c.current!.slotBindings.map((b) => b['revision_number']), [1, 2]);
      expect(
        c
            .current!
            .catalog
            .developerFixtures
            .single
            .weeks
            .single
            .days
            .last
            .sessions
            .single
            .blocks
            .single
            .movements
            .first
            .reps,
        '6',
      );
    },
  );
  test(
    'failed selection/admission preserves references; foreign identical frozen entry refused',
    () async {
      final c = await open();
      expect(await c.validate(), true);
      expect(await c.select(0, 0, 0, 2), false);
      expect(slotKey(c), d2SessionKey(1));
      expect(c.current, null);
      final other = ProtocolAuthoringController();
      await other.ready;
      addTearDown(other.dispose);
      expect(await c.admit(other.revisions.single), false);
      expect(c.admitted.length, 1);
      expect(slotKey(c), d2SessionKey(1));
      expect(await c.select(0, 0, 99, 1), false);
      expect(slotKey(c), d2SessionKey(1));
    },
  );
  test(
    'draft and no-op freeze block joint exports; cancellation preserves exact snapshots',
    () async {
      final c = await open();
      expect(await c.validate(), true);
      final original = c.admitted.single.source;
      c.session.createDraft();
      expect(c.current, null);
      expect(await c.exportHandoff(), null);
      expect(await c.session.freeze(), false);
      expect(c.admitted.length, 1);
      c.session.editSession('title', '');
      expect(await c.session.validate(), false);
      c.session.cancelDraft();
      expect(c.current, null);
      expect(c.admitted.single.source, original);
      expect(await c.validate(), true);
    },
  );
  test(
    'invalid programme/locked contract references refuse successful joint review',
    () async {
      final c = await open();
      await c.validate();
      c.programme.editProgramme('name', '');
      expect(await c.validate(), false);
      expect(c.current, null);
      expect(c.errors.join(), contains('programme.name'));
      c.programme.editProgramme('name', 'Synthetic');
      c.programme.removeSlot(0, 0, 0);
      expect(await c.validate(), false);
      expect(c.current, null);
      await c.reset();
      expect(slotKey(c), d2SessionKey(1));
      expect(await c.validate(), true);
    },
  );
  test(
    'all declared sources exported; deterministic separate readonly reopen preserves live workspace',
    () async {
      final c = await open();
      await c.admit(await changed(c));
      final packet = await c.exportHandoff();
      expect(packet, isNotNull);
      final json = jsonDecode(packet!) as Map;
      expect(json['sessions'].length, 2);
      expect(c.current!.slotBindings.single['revision_number'], 1);
      final live = c.programme.draftSource,
          owner = c.session,
          entries = c.admitted;
      expect(await c.reopen(packet), true);
      expect(c.current, null);
      expect(c.reconstructedExport(), packet);
      expect(c.programme.draftSource, live);
      expect(identical(c.session, owner), true);
      expect(c.admitted, entries);
      expect(c.reconstructed!.slotBindings.single['revision_number'], 1);
      expect(
        (const PlanPackageCompiler().compile(
          c.reconstructed!.programmeSource,
        )).canonicalJson,
        c.reconstructed!.canonicalJson,
      );
    },
  );
  test(
    'source and package hash have distinct authority and immutable exposed collections',
    () async {
      final c = await open();
      await c.validate();
      final before = c.current!;
      final other = await changed(c);
      final bodyOnly = reviewComposition(before.programmeSource, [
        c.admitted.single,
      ]);
      expect(bodyOnly.packageHash, before.packageHash);
      expect(other.digest, isNot(before.sessions.single.sourceDigest));
      // Package compiler sees no body inputs and retains the same hash for fixed refs.
      expect(
        const PlanPackageCompiler()
            .compile(before.programmeSource)
            .contentHashSha256,
        before.packageHash,
      );
      expect(() => before.sessions.clear(), throwsUnsupportedError);
      expect(() => before.slotBindings.single.clear(), throwsUnsupportedError);
      expect(
        () => before.sessions.single.bindings.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => before.catalog.developerFixtures.clear(),
        throwsUnsupportedError,
      );
      expect(before.catalog.developerFixtures, isNotEmpty);
      await c.admit(other);
      await c.select(0, 0, 0, 2);
      await c.validate();
      expect(c.current!.packageHash, isNot(before.packageHash));
      final exactPackage = c.current!.programmeSource;
      final differentBody = await c.compiler.compileExact(
        other.source.replaceFirst('reps: 6', 'reps: 7'),
        other.identity,
      );
      expect(differentBody.sourceDigest, isNot(other.digest));
      final alternativeReview = reviewComposition(exactPackage, [
        c.admitted.first,
        differentBody,
      ]);
      expect(alternativeReview.packageHash, c.current!.packageHash);
      final immutable = SyntheticProgrammeRevisionCatalogue(
        c.session.revisions.first,
      );
      immutable.appendVerified(other.compiled);
      expect(() => immutable.checkAppend(differentBody), throwsFormatException);
      final digests = c.admitted.map((s) => s.sourceDigest).toList();
      c.programme.editProgramme('name', 'Synthetic other metadata');
      await c.validate();
      expect(c.admitted.map((s) => s.sourceDigest), digests);
    },
  );
  for (final type in [
    'missing',
    'extra',
    'duplicate',
    'digest',
    'bytes',
    'bindings',
    'fingerprint',
    'tuple',
    'title',
    'version',
    'slot',
    'package_hash',
    'unknown',
    'wrapper',
  ]) {
    test(
      'handoff fails closed on $type tampering without live replacement',
      () async {
        final c = await open();
        await c.admit(await changed(c));
        final bytes = (await c.exportHandoff())!;
        final payload = jsonDecode(bytes) as Map<String, dynamic>;
        final rows = payload['sessions'] as List;
        switch (type) {
          case 'missing':
            rows.removeLast();
            break;
          case 'extra':
            rows.add(jsonDecode(jsonEncode(rows.last)));
            (rows.last as Map)['session_key'] = 'foreign';
            break;
          case 'duplicate':
            rows.add(jsonDecode(jsonEncode(rows.first)));
            break;
          case 'digest':
            rows.first['source_digest'] = 'bad';
            break;
          case 'bytes':
            rows.last['founder_yaml'] += '\n# changed';
            break;
          case 'bindings':
            rows.last['exercise_bindings']['cohort.exercise.d2_fixture_a'] =
                'EX-9002@1';
            break;
          case 'fingerprint':
            payload['fixture_profile']['fingerprint'] = 'bad';
            break;
          case 'tuple':
            rows.last['identity']['protocol_id'] = 'foreign';
            break;
          case 'title':
            payload['programme_yaml'] = (payload['programme_yaml'] as String)
                .replaceAll('Synthetic strength session', 'Wrong title');
            break;
          case 'version':
            payload['version'] = 2;
            break;
          case 'slot':
            payload['slot_bindings'][0]['source_digest'] = 'bad';
            break;
          case 'package_hash':
            payload['package_hash'] = 'bad';
            break;
          case 'unknown':
            payload['unrecognised'] = true;
            break;
          case 'wrapper':
            rows.last['founder_yaml'] = (rows.last['founder_yaml'] as String)
                .replaceAll('Local fixture only.', 'Changed wrapper');
            rows.last['source_digest'] = d2SourceDigest(
              rows.last['founder_yaml'] as String,
            );
            break;
        }
        final live = c.programme.draftSource, owned = c.admitted;
        expect(await c.reopen(jsonEncode(payload)), false);
        expect(c.current, null);
        expect(c.reconstructed, null);
        expect(c.rejectedHandoff, isNotNull);
        expect(c.programme.draftSource, live);
        expect(c.admitted, owned);
      },
    );
  }
  test(
    'duplicate escaped JSON keys and bare programme YAML cannot reconstruct review',
    () async {
      final c = await open();
      final packet = (await c.exportHandoff())!;
      expect(
        await c.reopen(
          packet.replaceFirst(
            '"version": 1',
            '"version": 1, "\\u0076ersion": 1',
          ),
        ),
        false,
      );
      expect(c.errors.join(), contains('duplicate'));
      expect(await c.reopen(c.programme.draftSource), false);
      expect(c.errors.join(), contains('session sources'));
    },
  );
  for (final kind in ['validate', 'export', 'admit', 'select', 'reopen']) {
    test('$kind ignores edit while source verification is pending', () async {
      final compiler = PausedCompiler(), c = await open(compiler: compiler);
      final r2 = await changed(c);
      await c.admit(r2);
      final packet = (await c.exportHandoff())!;
      compiler.pauseNext = true;
      final operation = switch (kind) {
        'validate' => c.validate(),
        'export' => c.exportHandoff(),
        'admit' => c.admit(r2),
        'select' => c.select(0, 0, 0, 2),
        _ => c.reopen(packet),
      };
      await Future<void>.delayed(Duration.zero);
      expect(compiler.gate, isNotNull);
      c.programme.editProgramme('name', 'Synthetic newer edit');
      compiler.gate!.complete();
      final result = await operation;
      expect(result, kind == 'export' ? null : false);
      expect(c.current, null);
      expect(c.reconstructed, null);
      expect(slotKey(c), d2SessionKey(1));
    });
  }
  test(
    'new admission does not partially commit when session edit invalidates async check',
    () async {
      final compiler = PausedCompiler(),
          c = await open(compiler: compiler),
          r2 = await changed(c);
      compiler.pauseNext = true;
      final work = c.admit(r2);
      await Future<void>.delayed(Duration.zero);
      c.session.createDraft();
      compiler.gate!.complete();
      expect(await work, false);
      expect(c.admitted.length, 1);
      expect(c.programme.tree!['sessions'].length, 1);
      expect(slotKey(c), d2SessionKey(1));
    },
  );
  test('old async failure cannot replace newer successful receipt', () async {
    final compiler = PausedCompiler(), c = await open(compiler: compiler);
    compiler.pauseNext = true;
    final old = c.validate();
    await Future<void>.delayed(Duration.zero);
    expect(await c.validate(), true);
    final receipt = c.current;
    compiler.fail = true;
    compiler.gate!.complete();
    expect(await old, false);
    expect(identical(c.current, receipt), true);
    expect(c.errors, isEmpty);
  });
  for (final queued in [false, true]) {
    test(
      'validation/export refuses ${queued ? 'queued' : 'synchronous'} success listener edits',
      () async {
        final c = await open();
        var changed = false;
        c.addListener(() {
          if (!changed && c.current != null) {
            changed = true;
            if (queued) {
              scheduleMicrotask(
                () => c.programme.editProgramme(
                  'name',
                  'Synthetic notification edit',
                ),
              );
            } else {
              c.programme.editProgramme('name', 'Synthetic notification edit');
            }
          }
        });
        expect(await c.exportHandoff(), null);
        expect(c.current, null);
      },
    );
  }
  test(
    'disposal invalidates pending verification without publishing a receipt',
    () async {
      final compiler = PausedCompiler();
      final c = SyntheticCompositionController(compiler: compiler);
      await c.ready;
      compiler.pauseNext = true;
      final work = c.validate();
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      compiler.gate!.complete();
      expect(await work, false);
      expect(c.current, null);
    },
  );
  test(
    'later selection wins over an older pending explicit selection',
    () async {
      final compiler = PausedCompiler(), c = await open(compiler: compiler);
      await c.admit(await changed(c));
      compiler.pauseNext = true;
      final older = c.select(0, 0, 0, 2);
      await Future<void>.delayed(Duration.zero);
      expect(await c.select(0, 0, 0, 1), true);
      compiler.gate!.complete();
      expect(await older, false);
      expect(slotKey(c), d2SessionKey(1));
      expect(c.current, null);
    },
  );
  test(
    'busy notification edit prevents admission before any mutation',
    () async {
      final c = await open();
      final own = await changed(c);
      var edited = false;
      c.addListener(() {
        if (c.busy && !edited) {
          edited = true;
          c.programme.editProgramme('name', 'Synthetic notification edit');
        }
      });
      expect(await c.admit(own), false);
      expect(c.admitted.length, 1);
      expect(c.programme.tree!['sessions'].length, 1);
      expect(slotKey(c), d2SessionKey(1));
    },
  );
  test(
    'reset ignores pending operation and restores seed without earlier draft/reservations',
    () async {
      final compiler = PausedCompiler(), c = await open(compiler: compiler);
      await c.admit(await changed(c));
      compiler.pauseNext = true;
      final work = c.validate();
      await Future<void>.delayed(Duration.zero);
      await c.reset();
      compiler.gate!.complete();
      expect(await work, false);
      expect(c.admitted.length, 1);
      expect(slotKey(c), d2SessionKey(1));
      expect(c.current, null);
    },
  );
}
