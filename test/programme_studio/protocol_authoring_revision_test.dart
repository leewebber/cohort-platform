import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_source_guard.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_session_revision_catalogue.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';

void main() {
  const r1 = SessionRevisionIdentity(
    protocolId: d2RootProtocolId,
    sessionLineageId: d2LineageId,
    revisionNumber: 1,
  );
  test(
    'frozen tuple cannot be replaced, reservations are monotonic, stale seal is refused',
    () async {
      final compiler = SyntheticStrengthSessionCompiler();
      final original = await compiler.compileExact(d2R1Source(), r1);
      final catalogue = SyntheticSessionRevisionCatalogue(original);
      final second = catalogue.reserve(1);
      final tree = d2FounderTree();
      (tree['programme'] as Map)['import_key'] = d2ImportKey(2);
      (FounderStrengthSourceGuard.exerciseRows(tree).first['prescription']
              as Map)['reps'] =
          6;
      final source = const FounderStrengthYamlWriter().write(tree);
      final compiled = await compiler.compileExact(source, second);
      await expectLater(
        catalogue.freeze(compiled, compiler, isCurrent: () => false),
        throwsStateError,
      );
      expect(catalogue.revisions.length, 1);
      final frozen = await catalogue.freeze(compiled, compiler);
      await expectLater(catalogue.freeze(compiled, compiler), throwsStateError);
      expect(frozen.source, source);
      expect(catalogue.at(1).source, d2R1Source());
      expect(() => catalogue.revisions.clear(), throwsUnsupportedError);
      expect(
        () => frozen.compiled.protocol.blocks.single.linkedExercises.clear(),
        throwsUnsupportedError,
      );
      final third = catalogue.reserve(2);
      catalogue.abandon(third);
      expect(catalogue.reserve(2).revisionNumber, 4);
    },
  );
  test(
    'unknown tuple and mismatched source import key fail before a snapshot exists',
    () async {
      final compiler = SyntheticStrengthSessionCompiler();
      for (final tuple in [
        const SessionRevisionIdentity(
          protocolId: 'wrong',
          sessionLineageId: d2LineageId,
          revisionNumber: 1,
        ),
        const SessionRevisionIdentity(
          protocolId: d2RootProtocolId,
          sessionLineageId: 'wrong',
          revisionNumber: 1,
        ),
        const SessionRevisionIdentity(
          protocolId: d2RootProtocolId,
          sessionLineageId: d2LineageId,
          revisionNumber: 0,
        ),
        const SessionRevisionIdentity(
          protocolId: '$d2RootProtocolId-rev-2',
          sessionLineageId: d2LineageId,
          revisionNumber: 2,
        ),
      ]) {
        await expectLater(
          compiler.compileExact(d2R1Source(), tuple),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'caller fixture list mutation cannot alter retained compiler authority',
    () async {
      final definitions = d2ExerciseDefinitions(),
          mappings = d2IdentityMappings();
      final compiler = SyntheticStrengthSessionCompiler(
        definitions: definitions,
        mappings: mappings,
      );
      definitions.clear();
      mappings.clear();
      expect(
        (await compiler.compileExact(d2R1Source(), r1)).bindings.length,
        2,
      );
    },
  );
}
