import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../authoring/plan_package_v1_yaml_writer.dart';
import '../domain/programme_review_models.dart';
import '../projection/executable_protocol_sql_reader.dart';
import '../projection/programme_review_projector.dart';
import '../projection/programme_review_source.dart';
import '../projection/sql_values_parser.dart';
import 'protocol_authoring_fixtures.dart';
import 'synthetic_strength_lineage.dart';
import 'synthetic_strength_session_compiler.dart';

class D2ReviewReceipt {
  const D2ReviewReceipt({
    required this.session,
    required this.packageSource,
    required this.packageHash,
    required this.catalog,
  });
  final D2CompiledSession session;
  final String packageSource;
  final String packageHash;
  final ProgrammeReviewCatalog catalog;
}

/// VALUES text is a derived in-memory reader transport, never an apply command.
class SyntheticStrengthReviewBridge {
  const SyntheticStrengthReviewBridge();
  String packageSource(
    D2CompiledSession selected,
    Iterable<D2CompiledSession> entries,
  ) {
    final sessions = _entries(selected, entries);
    final lineage = SyntheticStrengthLineage.resolve(selected.identity);
    final tree = d2PackageTree(
      identity: selected.identity,
      title: selected.protocol.name,
    );
    final slots =
        ((tree['weeks'] as List).single['days'] as List).first['slots'] as List;
    (slots.single as Map)['session_key'] = lineage.sessionKey(
      selected.identity.revisionNumber,
    );
    (tree['comparison_identities'] as List).single['session_lineage_id'] =
        lineage.id;
    tree['sessions'] = [
      for (final s in sessions)
        {
          'session_key': SyntheticStrengthLineage.resolve(
            s.identity,
          ).sessionKey(s.identity.revisionNumber),
          'protocol_id': s.identity.protocolId,
          'session_lineage_id': s.identity.sessionLineageId,
          'revision_number': s.identity.revisionNumber,
          'title': s.protocol.name,
        },
    ];
    return const PlanPackageV1YamlWriter().writeDraft(tree);
  }

  D2ReviewReceipt project(
    D2CompiledSession selected,
    Iterable<D2CompiledSession> entries,
  ) {
    final sessions = _entries(selected, entries);
    final yaml = packageSource(selected, sessions);
    final package = const PlanPackageCompiler().compile(yaml);
    if (!package.isValid) {
      throw FormatException(package.issues.map((i) => i.message).join('\n'));
    }
    final text = readerText(sessions);
    verifyReaderText(text, sessions);
    final catalog = const ProgrammeReviewProjector().project(
      ProgrammeReviewProjectionRequest(
        bundles: [
          ProgrammeReviewSourceBundle(
            spec: const ProgrammeReviewSourceSpec(
              catalogId: 'd2-synthetic',
              classification: ProgrammeReviewClassification.fixtureTestExample,
              planPackagePath: 'synthetic/d2.plan-package.yaml',
              fixture: true,
              executableProtocolSqlPaths: ['synthetic/d2-derived-reader-text'],
            ),
            planPackageYaml: yaml,
            executableProtocolSql: [text],
            // Founder source goes through the exact identity adapter above, never
            // the projector's title-based Founder fallback.
          ),
        ],
      ),
    );
    final programme = catalog.developerFixtures.single;
    final review = programme.weeks.single.days.first.sessions.single;
    final expected = selected.protocol.blocks.single;
    if (!review.bodiesResolved ||
        review.protocolId != selected.identity.protocolId ||
        review.sessionLineageId != selected.identity.sessionLineageId ||
        review.revisionNumber != selected.identity.revisionNumber ||
        review.blocks.length != 1 ||
        review.blocks.single.movements.length !=
            expected.linkedExercises.length ||
        programme.findings.any(
          (f) => f.severity == ProgrammeReviewFindingSeverity.error,
        )) {
      throw const FormatException(
        'review_binding: exact session revision was not projected.',
      );
    }
    return D2ReviewReceipt(
      session: selected,
      packageSource: yaml,
      packageHash: package.contentHashSha256!,
      catalog: catalog,
    );
  }

  List<D2CompiledSession> _entries(
    D2CompiledSession selected,
    Iterable<D2CompiledSession> entries,
  ) {
    final byNumber = <String, D2CompiledSession>{};
    for (final s in [...entries, selected]) {
      final previous = byNumber[revisionKey(s.identity)];
      if (previous != null &&
          (previous.sourceDigest != s.sourceDigest ||
              previous.identity.protocolId != s.identity.protocolId)) {
        throw const FormatException(
          'revision_collision: conflicting source for revision.',
        );
      }
      byNumber[revisionKey(s.identity)] = s;
    }
    final result = byNumber.values.toList()
      ..sort((a, b) => compareRevisions(a.identity, b.identity));
    return result;
  }

  Map<String, List<List<Object?>>> _rows(Iterable<D2CompiledSession> sessions) {
    final protocols = <List<Object?>>[],
        blocks = <List<Object?>>[],
        links = <List<Object?>>[];
    final ids = <String>{};
    for (final s in sessions) {
      if (!ids.add(s.identity.protocolId) ||
          d2SourceDigest(s.source) != s.sourceDigest ||
          s.protocol.protocolId != s.identity.protocolId ||
          s.protocol.sessionLineageId != s.identity.sessionLineageId ||
          s.protocol.revisionNumber != s.identity.revisionNumber ||
          s.protocol.published) {
        throw const FormatException(
          'review_binding: conflicting tuple/source/body.',
        );
      }
      final p = s.protocol;
      protocols.add([
        p.protocolId,
        p.name,
        'Synthetic local preview only',
        'false',
        'session',
        'programme_only',
        'coach_authored',
        'd2-local',
        s.identity.sessionLineageId,
        s.identity.revisionNumber,
        'draft',
        p.durationMin,
        null,
        p.coachingNotes,
      ]);
      final block = p.blocks.single;
      final blockId = '${p.protocolId}-block-1';
      blocks.add([
        blockId,
        p.protocolId,
        'strength',
        block.title,
        block.content,
        'none',
        null,
        block.coachNotes,
        block.position,
      ]);
      for (final link in block.linkedExercises) {
        links.add([
          blockId,
          link.exerciseId,
          link.position,
          link.displayLabelOverride,
          jsonEncode(link.prescription!.toJson()),
        ]);
      }
    }
    return {
      'performance_protocols': protocols,
      'session_blocks': blocks,
      'session_block_exercises': links,
    };
  }

  String readerText(Iterable<D2CompiledSession> sessions) {
    final rows = _rows(sessions);
    return [
      for (final entry in rows.entries)
        'INSERT INTO public.${entry.key} VALUES\n${entry.value.map((r) => '(${r.map(_scalar).join(',')})').join(',\n')};',
    ].join('\n');
  }

  String _scalar(Object? value) => value == null
      ? 'NULL'
      : value is num
      ? '$value'
      : "'${value.toString().replaceAll("'", "''")}'";

  void verifyReaderText(String text, Iterable<D2CompiledSession> sessions) {
    final expected = _rows(sessions);
    for (final entry in expected.entries) {
      final actual = [
        for (final clause in const SqlInsertExtractor().valuesClauses(
          sql: text,
          table: entry.key,
        ))
          ...const SqlValuesParser().parseTupleList(clause),
      ];
      if (jsonEncode(actual) != jsonEncode(entry.value)) {
        throw FormatException(
          'review_transport: ${entry.key} rows/fields were dropped or rewritten.',
        );
      }
    }
    final parsed = const ExecutableProtocolSqlReader().read([text]);
    if (parsed.length != expected['performance_protocols']!.length) {
      throw const FormatException('review_transport: protocol count.');
    }
    for (final s in sessions) {
      final p = parsed[s.identity.protocolId];
      final b = s.protocol.blocks.single;
      if (p == null ||
          p.name != s.protocol.name ||
          p.coachingNotes != s.protocol.coachingNotes ||
          p.blocks.length != 1 ||
          p.blocks.single.title != b.title ||
          p.blocks.single.coachNotes != b.coachNotes ||
          p.blocks.single.movements.length != b.linkedExercises.length ||
          p.blocks.single.unsupportedReason != null) {
        throw const FormatException('review_transport: body mismatch.');
      }
      for (var i = 0; i < b.linkedExercises.length; i++) {
        final link = b.linkedExercises[i], m = p.blocks.single.movements[i];
        if (m.exerciseId != link.exerciseId ||
            m.position != link.position ||
            m.name != (link.displayLabelOverride ?? link.exerciseId) ||
            m.rawPrescription != jsonEncode(link.prescription!.toJson()) ||
            m.unsupportedReason != null) {
          throw const FormatException(
            'review_transport: exercise prescription mismatch.',
          );
        }
      }
    }
  }
}
