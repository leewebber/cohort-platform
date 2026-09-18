import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';

import 'content_graph_manifest.dart';
import 'content_graph_models.dart';
import 'content_graph_service.dart';
import 'content_graph_vocabulary.dart';
import 'in_memory_content_graph_store.dart';

/// Local, read-only Apollo v1 compatibility bridge.
///
/// Plan Package schema v1 has no canonical exercise IDs. Exercise-level
/// edges are taken from committed Apollo week SQL, not guessed from names.
class ApolloLocalGraphBinder {
  static const expectedPlanPackageHash =
      '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83';
  static const programmeCode = 'APOLLO-BUILD-12-WEEK';
  static const expectedCanonicalExerciseCount = 58;

  static const distinctPullUpIds = {
    'EX-095': 'Weighted Pull-Up',
    'EX-137': 'Neutral-Grip Pull-Up',
    'EX-149': 'Strict Pull-Up',
  };

  static const distinctRunningIds = {
    'EX-129': 'Running',
  };

  ApolloBoundGraph bind({
    required String planPackageYaml,
    required Map<String, String> weekSqlByPath,
  }) {
    const compiler = PlanPackageCompiler();
    final compiled = compiler.compile(planPackageYaml);
    if (!compiled.isValid || compiled.manifest == null) {
      throw ContentGraphException(
        ContentGraphFailureCode.validationFailed,
        compiled.issues.map((issue) => issue.toString()).join(','),
      );
    }
    final packageHash = compiled.contentHashSha256!;
    if (packageHash != expectedPlanPackageHash) {
      throw const ContentGraphException(
        ContentGraphFailureCode.sourceHashMismatch,
        'Apollo Plan Package v1 hash changed; binder must not rewrite it.',
      );
    }

    final sql = ApolloSqlRelationshipParser().parse(weekSqlByPath);
    final store = InMemoryContentGraphStore();
    store.putPublisher(
      const ContentPublisher(
        id: 'publisher.cohort-global',
        displayName: 'Cohort',
        namespace: 'cohort_global',
        firstParty: true,
      ),
    );
    for (final exercise in sql.catalogue.values) {
      store.putExercise(exercise);
    }
    store.putProgramme(
      const ProgrammeIdentity(
        id: 'programme.apollo-12-week',
        code: programmeCode,
        displayName: 'Apollo 12 Week',
        ownerId: 'publisher.cohort-global',
      ),
    );

    final protocolIds = {
      for (final session in compiled.manifest!.sessions) session.protocolId,
    };
    for (final protocolId in protocolIds) {
      store.putSessionTemplate(
        SessionTemplate(
          id: 'session-template.$protocolId',
          displayName: protocolId,
          ownerId: 'publisher.cohort-global',
        ),
      );
      store.putSessionTemplateVersion(
        SessionTemplateVersion(
          id: protocolId,
          templateId: 'session-template.$protocolId',
          revisionNumber: 1,
          lifecycle: ContentLifecycle.draft,
          ownerId: 'publisher.cohort-global',
          sourceHash: protocolId,
        ),
      );
      final blocks = sql.blocksBySession[protocolId] ?? const [];
      var position = 1;
      for (final blockId in blocks) {
        final exerciseIds = sql.exercisesByBlock[blockId] ?? const [];
        if (exerciseIds.isEmpty) continue;
        store.putBlock(
          AuthoredBlock(
            id: blockId,
            sessionTemplateVersionId: protocolId,
            position: position++,
            title: blockId,
            exerciseIds: exerciseIds,
          ),
        );
      }
      store.putSessionTemplateVersion(
        SessionTemplateVersion(
          id: protocolId,
          templateId: 'session-template.$protocolId',
          revisionNumber: 1,
          lifecycle: ContentLifecycle.published,
          ownerId: 'publisher.cohort-global',
          sourceHash: protocolId,
        ),
      );
    }

    store.putProgrammeVersion(
      const ProgrammeVersion(
        id: 'programme-version.apollo.v1',
        programmeId: 'programme.apollo-12-week',
        versionNumber: 2,
        lifecycle: ContentLifecycle.draft,
        ownerId: 'publisher.cohort-global',
        label: 'v1-bridge',
        sourcePackageRef: 'plan-package-v1:APOLLO-BUILD-12-WEEK@2',
        sourcePackageHash: expectedPlanPackageHash,
        sourcePackageSchemaVersion: ContentGraphBinding.planPackageSchemaV1,
      ),
    );

    for (final week in compiled.manifest!.weeks) {
      for (final day in week.days) {
        for (final item in day.slots) {
          final session = compiled.manifest!.sessions.singleWhere(
            (candidate) => candidate.sessionKey == item.sessionKey,
          );
          store.putPlacement(
            ProgrammePlacement(
              id: 'placement.${item.slotKey}',
              programmeVersionId: 'programme-version.apollo.v1',
              sessionTemplateVersionId: session.protocolId,
              weekNumber: week.weekNumber,
              dayKey: day.dayKey,
              slotOrder: item.sessionOrder,
            ),
          );
        }
      }
    }

    store.putSupplementalSource(
      'programme-version.apollo.v1',
      sql.source,
    );
    store.putProgrammeVersion(
      store.programmeVersion('programme-version.apollo.v1')!.copyWith(
        supplementalRelationshipHash: sql.source.sha256,
      ),
    );

    final service = ContentGraphService(store: store);
    final published = service.publish(
      actor: const ContentActor(
        publisherId: 'publisher.cohort-global',
        role: ContentAuthRole.firstPartyPublisher,
      ),
      programmeVersionId: 'programme-version.apollo.v1',
    );
    final compiledGraph = service.compileDraft(published.id);
    return ApolloBoundGraph(
      packageHash: packageHash,
      supplemental: sql.source,
      manifest: compiledGraph.manifest,
      store: store,
      service: service,
      catalogueNames: {
        for (final exercise in sql.catalogue.values)
          exercise.id: exercise.displayName,
      },
      unresolved: sql.source.unresolved,
    );
  }
}

class ApolloBoundGraph {
  const ApolloBoundGraph({
    required this.packageHash,
    required this.supplemental,
    required this.manifest,
    required this.store,
    required this.service,
    required this.catalogueNames,
    required this.unresolved,
  });

  final String packageHash;
  final SupplementalRelationshipSource supplemental;
  final ContentGraphManifest manifest;
  final InMemoryContentGraphStore store;
  final ContentGraphService service;
  final Map<String, String> catalogueNames;
  final List<String> unresolved;
}

class ApolloSqlRelationshipParser {
  SupplementalParseResult parse(Map<String, String> weekSqlByPath) {
    final paths = weekSqlByPath.keys.toList()..sort();
    final catalogue = <String, ContentExercise>{};
    final blockToSession = <String, String>{};
    final exercisesByBlock = <String, List<String>>{};
    final unresolved = <String>{};
    final uuid = r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
    final blockSession = RegExp(
      "\\('($uuid)','(APOLLO-W\\d+-[A-Z]+-R1)'",
    );
    final exerciseRow = RegExp(
      "('(?:$uuid)'|'(?:$uuid)'::uuid),'(EX-\\d+)'",
    );
    final catalogueRow = RegExp(
      "\\('(EX-\\d+)','([^']+)'",
    );
    final tmpRef = RegExp(r"TMP-[A-Z0-9-]+");

    for (final path in paths) {
      final sql = weekSqlByPath[path]!;
      for (final match in tmpRef.allMatches(sql)) {
        unresolved.add('legacy_tmp:${match.group(0)}');
      }
      for (final match in RegExp(r'EX-\d+').allMatches(sql)) {
        final id = match.group(0)!;
        catalogue.putIfAbsent(
          id,
          () => ContentExercise(id: id, displayName: id),
        );
      }
      for (final match in catalogueRow.allMatches(sql)) {
        final id = match.group(1)!;
        final name = match.group(2)!;
        catalogue.putIfAbsent(
          id,
          () => ContentExercise(id: id, displayName: name),
        );
      }
      for (final match in blockSession.allMatches(sql)) {
        blockToSession[match.group(1)!] = match.group(2)!;
      }
      for (final match in exerciseRow.allMatches(sql)) {
        final rawBlock = match.group(1)!;
        final blockId = rawBlock
            .replaceAll("'", '')
            .replaceAll('::uuid', '');
        final exerciseId = match.group(2)!;
        exercisesByBlock.putIfAbsent(blockId, () => <String>[]);
        if (!exercisesByBlock[blockId]!.contains(exerciseId)) {
          exercisesByBlock[blockId]!.add(exerciseId);
        }
        catalogue.putIfAbsent(
          exerciseId,
          () => ContentExercise(id: exerciseId, displayName: exerciseId),
        );
      }
    }

    final blocksBySession = <String, List<String>>{};
    for (final entry in blockToSession.entries) {
      blocksBySession.putIfAbsent(entry.value, () => <String>[]);
      blocksBySession[entry.value]!.add(entry.key);
    }
    for (final sessionBlocks in blocksBySession.values) {
      sessionBlocks.sort();
    }

    for (final entry in blockToSession.entries) {
      if (!exercisesByBlock.containsKey(entry.key)) {
        unresolved.add('name_only_block:${entry.key}:${entry.value}');
      }
    }

    final edgeRows = <Map<String, String>>[];
    for (final entry in exercisesByBlock.entries) {
      final sessionId = blockToSession[entry.key];
      for (final exerciseId in entry.value) {
        edgeRows.add({
          'block_id': entry.key,
          'exercise_id': exerciseId,
          'session_id': sessionId ?? '',
        });
      }
    }
    edgeRows.sort((a, b) {
      final exercise = a['exercise_id']!.compareTo(b['exercise_id']!);
      if (exercise != 0) return exercise;
      final block = a['block_id']!.compareTo(b['block_id']!);
      if (block != 0) return block;
      return a['session_id']!.compareTo(b['session_id']!);
    });
    final ids = catalogue.keys.toList()..sort();
    final unresolvedSorted = unresolved.toList()..sort();
    final tree = <String, Object?>{
      'edges': edgeRows,
      'exercise_ids': ids,
      'files': paths,
      'schema_version': ContentGraphBinding.apolloSqlSupplementalSchema,
      'unresolved': unresolvedSorted,
    };
    final keys = tree.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: tree[k]});
    final source = SupplementalRelationshipSource(
      schemaVersion: ContentGraphBinding.apolloSqlSupplementalSchema,
      canonicalJson: canonical,
      sha256: ContentGraphBinding.sha256Hex(canonical),
      exerciseIds: ids.toSet(),
      unresolved: unresolvedSorted,
    );
    return SupplementalParseResult(
      source: source,
      catalogue: catalogue,
      blocksBySession: blocksBySession,
      exercisesByBlock: exercisesByBlock,
    );
  }
}

class SupplementalParseResult {
  const SupplementalParseResult({
    required this.source,
    required this.catalogue,
    required this.blocksBySession,
    required this.exercisesByBlock,
  });

  final SupplementalRelationshipSource source;
  final Map<String, ContentExercise> catalogue;
  final Map<String, List<String>> blocksBySession;
  final Map<String, List<String>> exercisesByBlock;
}
