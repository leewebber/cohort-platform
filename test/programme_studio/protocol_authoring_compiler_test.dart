import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/exercise_knowledge/in_memory/in_memory_transitional_exercise_id_bridge.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_identity_mapping.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_source_guard.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_fixture_identity_adapter.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_review_bridge.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import '../../tool/founder_programme_import/repository_transitional_identity_adapter.dart';

const r1 = SessionRevisionIdentity(
  protocolId: d2RootProtocolId,
  sessionLineageId: d2LineageId,
  revisionNumber: 1,
);
void main() {
  const writer = FounderStrengthYamlWriter();
  test(
    'actual mapper, typed conversion, legacy and execution preserve supported dose and absence',
    () async {
      final compiler = SyntheticStrengthSessionCompiler();
      final result = await compiler.compileExact(d2R1Source(), r1);
      expect(result.source, d2R1Source());
      expect(result.sourceDigest, d2SourceDigest(result.source));
      final links = result.protocol.blocks.single.linkedExercises;
      expect(links.map((l) => l.exerciseId), ['EX-9001', 'EX-9002']);
      expect(links.first.prescription!.toJson(), {
        'sets': 2,
        'reps': {'type': 'exact', 'exact_reps': 5},
        'load': {'type': 'fixedKg', 'kg': 12.5},
        'rest_seconds': 60,
        'tempo': '3-1-1',
        'coach_cue': 'Synthetic cue only.',
      });
      expect(links.last.prescription!.load, isNull);
      expect(links.last.prescription!.restSeconds, isNull);
      expect(
        result.execution.blocks.single.linkedExercises.first.prescription!
            .toJson(),
        links.first.prescription!.toJson(),
      );
      expect(compiler.store.mutationAttempts, 0);
      expect(
        () => compiler.store.deleteDraftVersion('anything'),
        throwsStateError,
      );
      expect(compiler.store.mutationAttempts, 1);
      expect(() => result.protocol.blocks.clear(), throwsUnsupportedError);
      expect(
        () => result.protocol.blocks.single.linkedExercises.clear(),
        throwsUnsupportedError,
      );
      expect(() => result.bindings.clear(), throwsUnsupportedError);
    },
  );
  test(
    'semantic round trip excludes formatting and exact-rep/RPE aliases',
    () async {
      final t = d2FounderTree();
      final p =
          FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
              as Map;
      p['reps'] = {'type': 'exact', 'exact_reps': 5};
      p.remove('load');
      p['target_rpe'] = 7;
      final source = writer.write(t);
      final normalized = writer.write(
        const FounderStrengthSourceGuard().canonicalTree(
          source,
          importKey: d2ImportKey(1),
        ),
      );
      final compiler = SyntheticStrengthSessionCompiler();
      expect(
        (await compiler.compileExact(source, r1)).semanticJson,
        (await compiler.compileExact(normalized, r1)).semanticJson,
      );
    },
  );
  for (final label in [
    'invalid',
    'unmapped',
    'missing',
    'unpublished',
    'retired',
    'ambiguous',
    'conflict',
    'duplicate-record',
  ]) {
    test('exact identity refuses $label', () async {
      final t = d2FounderTree(),
          defs = d2ExerciseDefinitions(),
          mappings = d2IdentityMappings();
      final e = FounderStrengthSourceGuard.exerciseRows(t).first;
      switch (label) {
        case 'invalid':
          e['transitional_exercise_id'] = 'EX-9001';
        case 'unmapped':
          e['transitional_exercise_id'] = 'cohort.exercise.unmapped';
        case 'missing':
          defs.removeAt(0);
        case 'unpublished':
          defs[0] = ExerciseDefinition.fromJson({
            ...defs[0].toJson(),
            'lifecycle_status': 'draft',
          });
        case 'retired':
          mappings[0] = ExerciseIdentityMapping.fromJson({
            ...mappings[0].toJson(),
            'lifecycle_status': 'retired',
          });
        case 'ambiguous':
          defs.add(defs.first);
        case 'conflict':
          mappings.add(
            ExerciseIdentityMapping.fromJson({
              ...mappings.first.toJson(),
              'id': 'conflicting',
              'canonical_id': 'EX-9002',
            }),
          );
        case 'duplicate-record':
          mappings.add(
            ExerciseIdentityMapping.fromJson({
              ...mappings.first.toJson(),
              'canonical_id': 'EX-9002',
            }),
          );
      }
      await expectLater(
        SyntheticStrengthSessionCompiler(
          definitions: defs,
          mappings: mappings,
        ).compileExact(writer.write(t), r1),
        throwsFormatException,
      );
    });
  }
  test(
    'same labels do not resolve identity and duplicate resolved links fail',
    () async {
      final t = d2FounderTree(),
          rows = FounderStrengthSourceGuard.exerciseRows(d2FounderTree());
      for (final r in FounderStrengthSourceGuard.exerciseRows(t)) {
        r['exercise_name'] = 'Same name';
      }
      final c = SyntheticStrengthSessionCompiler();
      expect(
        (await c.compileExact(
          writer.write(t),
          r1,
        )).protocol.blocks.single.linkedExercises.map((l) => l.exerciseId),
        ['EX-9001', 'EX-9002'],
      );
      FounderStrengthSourceGuard.exerciseRows(
            t,
          ).last['transitional_exercise_id'] =
          rows.first['transitional_exercise_id'];
      await expectLater(
        c.compileExact(writer.write(t), r1),
        throwsFormatException,
      );
    },
  );
  test(
    'local adapter conforms to unchanged tool adapter for every bridge outcome',
    () {
      final mappings = d2IdentityMappings();
      final retired = ExerciseIdentityMapping.fromJson({
        ...mappings.first.toJson(),
        'lifecycle_status': 'retired',
      });
      final conflict = ExerciseIdentityMapping.fromJson({
        ...mappings.first.toJson(),
        'id': 'conflict',
        'canonical_id': 'EX-9002',
      });
      for (final initial in [
        mappings,
        [retired],
        [mappings.first, conflict],
        <ExerciseIdentityMapping>[],
      ]) {
        final bridge = InMemoryTransitionalExerciseIdBridge(initial: initial);
        for (final id in [
          'cohort.exercise.d2_fixture_a',
          'cohort.exercise.missing',
          'bad',
        ]) {
          final expected = RepositoryTransitionalIdentityAdapter(
                bridge,
              ).resolve(id),
              actual = SyntheticFixtureIdentityAdapter(bridge).resolve(id);
          expect(actual.kind, expected.kind);
          expect(actual.canonicalId, expected.canonicalId);
          expect(actual.canonicalCandidates, expected.canonicalCandidates);
        }
      }
    },
  );
  test(
    'derived reader transport rejects missing rows and altered exercise body',
    () async {
      final s = await SyntheticStrengthSessionCompiler().compileExact(
        d2R1Source(),
        r1,
      );
      const b = SyntheticStrengthReviewBridge();
      final text = b.readerText([s]);
      b.verifyReaderText(text, [s]);
      expect(
        () => b.verifyReaderText(text.replaceFirst('EX-9001', 'EX-9002'), [s]),
        throwsFormatException,
      );
      expect(
        () => b.verifyReaderText(
          text.replaceFirst(
            'INSERT INTO public.session_block_exercises',
            'INSERT INTO public.unknown',
          ),
          [s],
        ),
        throwsFormatException,
      );
      final review = b.project(s, [s]);
      expect(review.session.sourceDigest, s.sourceDigest);
      expect(
        review
            .catalog
            .developerFixtures
            .single
            .weeks
            .single
            .days
            .first
            .sessions
            .single
            .protocolId,
        r1.protocolId,
      );
      expect(jsonDecode(s.semanticJson)['bindings'], {
        'cohort.exercise.d2_fixture_a': 'EX-9001@1',
        'cohort.exercise.d2_fixture_b': 'EX-9002@1',
      });
    },
  );
}
