import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/domain/content_graph/apollo_local_graph_binder.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_manifest.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_persistence.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_service.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/domain/content_graph/in_memory_content_graph_store.dart';

const contentGraphPublisherId = '00000000-0000-4000-8000-00000000c001';
const contentGraphPublisherNodeId = 'publisher.cohort-global';
const apolloProgrammeVersionId = '2ba018bd-7dc2-4dfd-8d8e-e35823158920';
const spartanV3ProgrammeVersionId = '32986922-47d1-46b0-b391-a7931d73033e';

const expectedApolloSource =
    '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83';
const expectedApolloSupplemental =
    '5bb78fc24df9af9f03b0bddde238b004f64c54c60cef0872640b0d209e4951d0';
const expectedApolloGraph =
    '2b17ad30ab69a247948677078a1e37e5e7e077bf437cff527cb69937d5fb89e8';
const expectedApolloComposite =
    '481956c3277f4666ae80766c65e114b69aaf982758917e3de05ca5f8b9157b12';
const expectedApolloNodes = 300;
const expectedApolloEdges = 738;

const expectedSpartanSource =
    'b4bfaab4f6cd25417d52b6f0b2604d9f98b3e10b074c3d58896acde3db05473e';
const expectedSpartanSupplemental =
    '052735532570816fabdd1824730edc4afdc414bc3f2eac8f28db2f23fffd6247';
const expectedSpartanGraph =
    '8ddb918e3e642c85bc150dff0741f4a581a21927375d2365102d945e77ae5715';
const expectedSpartanComposite =
    '8c5989bd8ba360294cb619e721213a94fe19302387f7bf8008c203bfb5538d17';
const expectedSpartanNodes = 83;
const expectedSpartanEdges = 97;

const apolloPlanPackagePath =
    'tool/programmes/apollo_build_12_week_v1.plan-package.yaml';
const spartanPlanPackagePath =
    'tool/programmes/spartan_physique_block1_week1.plan-package.yaml';
const spartanRelationshipsPath =
    'content/content_graph/v1/sources/spartan_physique_v3.relationships.json';
const artifactRoot = 'content/content_graph/v1';

const forbiddenOperationalKeys = {
  'assignment_id',
  'assignment_ids',
  'athlete_id',
  'athlete_ids',
  'active_count',
  'paused_count',
  'completed_count',
  'catalogue_default',
  'generated_at',
  'created_at',
  'updated_at',
  'local_path',
  'workdir',
  'connection_string',
  'password',
  'jwt',
  'service_role',
};

class PublicationCandidate {
  const PublicationCandidate({
    required this.label,
    required this.programmeVersionId,
    required this.classification,
    required this.requireFullResolution,
    required this.manifest,
    required this.publication,
    required this.unresolved,
  });

  final String label;
  final String programmeVersionId;
  final String classification;
  final bool requireFullResolution;
  final ContentGraphManifest manifest;
  final Map<String, Object?> publication;
  final List<String> unresolved;

  String get manifestJson => encodeCanonical(publication['canonical_payload']);

  String get publicationJson => encodeCanonical(publication);

  int get nodeCount => manifest.nodeCount;
  int get edgeCount => manifest.edgeCount;
}

class PublicationArtifactBuilder {
  const PublicationArtifactBuilder();

  PublicationCandidate buildApollo() {
    final yaml = File(apolloPlanPackagePath).readAsStringSync();
    final weekSql = _apolloWeekSql();
    final bound = ApolloLocalGraphBinder().bind(
      planPackageYaml: yaml,
      weekSqlByPath: weekSql,
    );
    final persistence = ContentGraphPersistenceService(
      graph: bound.service,
      repository: InMemoryContentGraphManifestRepository(),
    );
    final payload = persistence.publishPayload('programme-version.apollo.v1');
    payload['programme_version_id'] = apolloProgrammeVersionId;
    payload['publisher_id'] = contentGraphPublisherId;
    payload['require_full_resolution'] = false;
    _stripNoncanonical(payload);
    return PublicationCandidate(
      label: 'apollo',
      programmeVersionId: apolloProgrammeVersionId,
      classification: '2',
      requireFullResolution: false,
      manifest: bound.manifest,
      publication: payload,
      unresolved: bound.unresolved,
    );
  }

  PublicationCandidate buildSpartanV3() {
    final package = const PlanPackageCompiler().compile(
      File(spartanPlanPackagePath).readAsStringSync(),
    );
    if (!package.isValid || package.contentHashSha256 != expectedSpartanSource) {
      throw StateError(
        'Spartan Plan Package v1 hash is not the qualified source.',
      );
    }
    final raw = jsonDecode(
      File(spartanRelationshipsPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    if (raw['programme_version_id'] != spartanV3ProgrammeVersionId) {
      throw StateError('Spartan relationship source version id mismatch.');
    }
    if (raw['package_content_hash'] != expectedSpartanSource) {
      throw StateError('Spartan relationship source package hash mismatch.');
    }
    final compiled = _bindHostedRelationships(
      versionId: spartanV3ProgrammeVersionId,
      lineageCode: raw['lineage_code'] as String,
      versionNumber: raw['version_number'] as int,
      packageHash: expectedSpartanSource,
      placements: _asMaps(raw['placements']),
      blocks: _asMaps(raw['blocks']),
      sbe: _asMaps(raw['sbe']),
    );
    return compiled;
  }

  List<PublicationCandidate> buildApprovedSet() => [
        buildApollo(),
        buildSpartanV3(),
      ];

  PublicationCandidate _bindHostedRelationships({
    required String versionId,
    required String lineageCode,
    required int versionNumber,
    required String packageHash,
    required List<Map<String, dynamic>> placements,
    required List<Map<String, dynamic>> blocks,
    required List<Map<String, dynamic>> sbe,
  }) {
    final store = InMemoryContentGraphStore();
    store.putPublisher(
      const ContentPublisher(
        id: contentGraphPublisherNodeId,
        displayName: 'Cohort',
        namespace: 'cohort_global',
        firstParty: true,
      ),
    );
    final programmeId = 'programme.${lineageCode.toLowerCase()}';
    store.putProgramme(
      ProgrammeIdentity(
        id: programmeId,
        code: lineageCode,
        displayName: lineageCode,
        ownerId: contentGraphPublisherNodeId,
      ),
    );
    final protocolIds = {
      for (final placement in placements) placement['protocol_id'] as String,
    };
    final exercisesByBlock = <String, List<String>>{};
    for (final row in sbe) {
      final blockId = row['block_id'] as String;
      final exerciseId = row['exercise_id'] as String;
      exercisesByBlock.putIfAbsent(blockId, () => <String>[]);
      if (!exercisesByBlock[blockId]!.contains(exerciseId)) {
        exercisesByBlock[blockId]!.add(exerciseId);
      }
      if (RegExp(r'^EX-[0-9]{3,}$').hasMatch(exerciseId)) {
        store.putExercise(
          ContentExercise(id: exerciseId, displayName: exerciseId),
        );
      }
    }
    final unresolved = <String>[];
    for (final protocolId in protocolIds.toList()..sort()) {
      store.putSessionTemplate(
        SessionTemplate(
          id: 'session-template.$protocolId',
          displayName: protocolId,
          ownerId: contentGraphPublisherNodeId,
        ),
      );
      store.putSessionTemplateVersion(
        SessionTemplateVersion(
          id: protocolId,
          templateId: 'session-template.$protocolId',
          revisionNumber: 1,
          lifecycle: ContentLifecycle.draft,
          ownerId: contentGraphPublisherNodeId,
          sourceHash: protocolId,
        ),
      );
    }
    for (final block in blocks) {
      final blockId = block['block_id'] as String;
      final sessionId = block['session_id'] as String;
      final exerciseIds = exercisesByBlock[blockId] ?? const <String>[];
      if (exerciseIds.isEmpty) {
        unresolved.add('name_only_block:$blockId:$sessionId');
        continue;
      }
      store.putBlock(
        AuthoredBlock(
          id: blockId,
          sessionTemplateVersionId: sessionId,
          position: block['position'] as int,
          title: (block['title'] as String?) ?? blockId,
          exerciseIds: exerciseIds,
        ),
      );
    }
    for (final protocolId in protocolIds) {
      store.putSessionTemplateVersion(
        SessionTemplateVersion(
          id: protocolId,
          templateId: 'session-template.$protocolId',
          revisionNumber: 1,
          lifecycle: ContentLifecycle.published,
          ownerId: contentGraphPublisherNodeId,
          sourceHash: protocolId,
        ),
      );
    }
    store.putProgrammeVersion(
      ProgrammeVersion(
        id: versionId,
        programmeId: programmeId,
        versionNumber: versionNumber,
        lifecycle: ContentLifecycle.draft,
        ownerId: contentGraphPublisherNodeId,
        label: 'v$versionNumber',
        sourcePackageRef: 'plan-package-v1:$lineageCode@$versionNumber',
        sourcePackageHash: packageHash,
        sourcePackageSchemaVersion: ContentGraphBinding.planPackageSchemaV1,
      ),
    );
    var slot = 0;
    for (final placement in placements) {
      store.putPlacement(
        ProgrammePlacement(
          id: 'placement.$versionId.$slot',
          programmeVersionId: versionId,
          sessionTemplateVersionId: placement['protocol_id'] as String,
          weekNumber: placement['week_number'] as int,
          dayKey: placement['day_key'] as String,
          slotOrder: placement['slot_order'] as int,
        ),
      );
      slot += 1;
    }
    unresolved.sort();
    final service = ContentGraphService(store: store);
    final derived = SupplementalRelationshipSource.fromUsedByEdges(
      service.deriveStructuralGraph(versionId).edges,
      unresolved: unresolved,
    );
    store.putSupplementalSource(versionId, derived);
    store.putProgrammeVersion(
      store.programmeVersion(versionId)!.copyWith(
        supplementalRelationshipHash: derived.sha256,
      ),
    );
    final published = service.publish(
      actor: const ContentActor(
        publisherId: contentGraphPublisherNodeId,
        role: ContentAuthRole.firstPartyPublisher,
      ),
      programmeVersionId: versionId,
    );
    final compiled = service.compileDraft(published.id);
    final persistence = ContentGraphPersistenceService(
      graph: service,
      repository: InMemoryContentGraphManifestRepository(),
    );
    final payload = persistence.publishPayload(versionId);
    payload['publisher_id'] = contentGraphPublisherId;
    payload['require_full_resolution'] = unresolved.isEmpty;
    _stripNoncanonical(payload);
    return PublicationCandidate(
      label: 'spartan_v3',
      programmeVersionId: versionId,
      classification: '1',
      requireFullResolution: unresolved.isEmpty,
      manifest: compiled.manifest,
      publication: payload,
      unresolved: unresolved,
    );
  }

  Map<String, String> _apolloWeekSql() {
    return {
      for (final file in Directory('supabase/migrations').listSync())
        if (file is File &&
            file.path.contains('apollo') &&
            file.path.endsWith('.sql') &&
            file.readAsStringSync().contains('EX-'))
          file.path: file.readAsStringSync(),
    };
  }

  List<Map<String, dynamic>> _asMaps(Object? raw) {
    return [
      for (final item in raw as List) Map<String, dynamic>.from(item as Map),
    ];
  }
}

void _stripNoncanonical(Map<String, Object?> payload) {
  payload.remove('created_at');
  payload.remove('generated_at');
  payload.remove('assignment_ids');
}

String encodeCanonical(Object? value) {
  return '${const JsonEncoder.withIndent('  ').convert(value)}\n';
}

String sha256Bytes(String text) => ContentGraphBinding.sha256Hex(text);

void assertMatchesQualification(PublicationCandidate candidate) {
  if (candidate.label == 'apollo') {
    _expectHash(candidate, expectedApolloSource, expectedApolloSupplemental,
        expectedApolloGraph, expectedApolloComposite,
        expectedApolloNodes, expectedApolloEdges);
    if (candidate.requireFullResolution) {
      throw StateError('Apollo must publish with require_full_resolution=false.');
    }
    return;
  }
  if (candidate.label == 'spartan_v3') {
    _expectHash(candidate, expectedSpartanSource, expectedSpartanSupplemental,
        expectedSpartanGraph, expectedSpartanComposite,
        expectedSpartanNodes, expectedSpartanEdges);
    if (!candidate.requireFullResolution) {
      throw StateError('Spartan v3 must require full resolution.');
    }
    return;
  }
  throw StateError('Unapproved candidate ${candidate.label}');
}

void _expectHash(
  PublicationCandidate candidate,
  String source,
  String supplemental,
  String graph,
  String composite,
  int nodes,
  int edges,
) {
  final publication = candidate.publication;
  if (publication['source_package_hash'] != source ||
      publication['supplemental_relationship_hash'] != supplemental ||
      publication['graph_structural_hash'] != graph ||
      publication['composite_identity'] != composite ||
      candidate.nodeCount != nodes ||
      candidate.edgeCount != edges) {
    throw StateError(
      'Regenerated ${candidate.label} identities differ from qualification.',
    );
  }
}

bool containsForbiddenOperationalField(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (forbiddenOperationalKeys.contains(key)) return true;
      if (containsForbiddenOperationalField(entry.value)) return true;
    }
  } else if (value is List) {
    for (final item in value) {
      if (containsForbiddenOperationalField(item)) return true;
    }
  } else if (value is String) {
    final lower = value.toLowerCase();
    if (lower.contains('postgresql://') ||
        lower.contains('service_role') ||
        lower.contains('eyj')) {
      return true;
    }
  }
  return false;
}
