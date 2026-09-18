import 'dart:convert';

import 'content_graph_manifest.dart';
import 'content_graph_models.dart';
import 'content_graph_publication.dart';
import 'content_graph_service.dart';
import 'content_graph_vocabulary.dart';

/// Persistence port for derived graph manifests. Never mutates authored content.
abstract class ContentGraphManifestRepository {
  Future<ContentGraphPublicationResult> publish({
    required Map<String, Object?> payload,
    required bool authorised,
  });

  Future<PersistedContentGraphManifest?> loadByProgrammeVersion(
    String programmeVersionId,
  );
}

class InMemoryContentGraphManifestRepository
    implements ContentGraphManifestRepository {
  final _byVersion = <String, PersistedContentGraphManifest>{};
  final _byComposite = <String, PersistedContentGraphManifest>{};

  @override
  Future<ContentGraphPublicationResult> publish({
    required Map<String, Object?> payload,
    required bool authorised,
  }) async {
    if (!authorised) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.unauthorised,
        code: 'unauthorised',
      );
    }
    final compiler = payload['compiler_version']?.toString();
    final format = payload['graph_format_version'];
    final source = payload['source_package_hash']?.toString() ?? '';
    final supplemental =
        payload['supplemental_relationship_hash']?.toString() ?? '';
    final graph = payload['graph_structural_hash']?.toString() ?? '';
    final composite = payload['composite_identity']?.toString() ?? '';
    final versionId = payload['programme_version_id']?.toString();
    final hex = RegExp(r'^[0-9a-f]{64}$');
    if (compiler != ContentGraphBinding.compilerVersion || format != 1) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.unsupportedFormat,
        code: 'unsupported_compiler_or_format',
      );
    }
    if (versionId == null ||
        !hex.hasMatch(source) ||
        !hex.hasMatch(supplemental) ||
        !hex.hasMatch(graph) ||
        !hex.hasMatch(composite)) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.hashMismatch,
        code: 'malformed_hash',
      );
    }
    final expected = ContentGraphBinding.compositeDigest(
      sourcePackageHash: source,
      supplementalRelationshipHash: supplemental,
    );
    if (expected != composite) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.hashMismatch,
        code: 'composite_mismatch',
      );
    }
    final existing = _byVersion[versionId];
    if (existing != null) {
      if (existing.compositeIdentity == composite &&
          existing.graphStructuralHash == graph) {
        return ContentGraphPublicationResult(
          status: ContentGraphPublicationStatus.alreadyPublished,
          manifestId: existing.id,
          programmeVersionId: versionId,
          compositeIdentity: composite,
        );
      }
      return ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.conflictingIdentity,
        code: 'version_already_has_manifest',
        manifestId: existing.id,
      );
    }
    final same = _byComposite[composite];
    if (same != null) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.conflictingIdentity,
        code: 'composite_already_bound',
      );
    }
    final unresolved = [
      for (final item in (payload['unresolved'] as List? ?? const []))
        item.toString(),
    ];
    if (payload['require_full_resolution'] == true && unresolved.isNotEmpty) {
      return const ContentGraphPublicationResult(
        status: ContentGraphPublicationStatus.unresolvedReference,
        code: 'full_resolution_required',
      );
    }
    final id = 'manifest.$versionId';
    final persisted = PersistedContentGraphManifest(
      id: id,
      programmeVersionId: versionId,
      compilerVersion: compiler!,
      graphFormatVersion: 1,
      sourcePackageHash: source,
      supplementalRelationshipHash: supplemental,
      graphStructuralHash: graph,
      compositeIdentity: composite,
      canonicalPayload: Map<String, Object?>.from(
        (payload['canonical_payload'] as Map?) ?? const {},
      ),
      publicationState: ContentLifecycle.published,
      unresolved: unresolved,
      createdAt: DateTime.utc(2026, 9, 18),
    );
    _byVersion[versionId] = persisted;
    _byComposite[composite] = persisted;
    return ContentGraphPublicationResult(
      status: ContentGraphPublicationStatus.published,
      manifestId: id,
      programmeVersionId: versionId,
      compositeIdentity: composite,
    );
  }

  @override
  Future<PersistedContentGraphManifest?> loadByProgrammeVersion(
    String programmeVersionId,
  ) async {
    return _byVersion[programmeVersionId];
  }
}

class ContentGraphPersistenceService {
  ContentGraphPersistenceService({
    required this.graph,
    required this.repository,
  });

  final ContentGraphService graph;
  final ContentGraphManifestRepository repository;

  Map<String, Object?> publishPayload(String programmeVersionId) {
    final compiled = graph.compileDraft(programmeVersionId);
    final version = graph.store.programmeVersion(programmeVersionId);
    if (version == null) {
      throw const ContentGraphException(
        ContentGraphFailureCode.notFound,
        'Programme version not found.',
      );
    }
    return {
      'programme_version_id': programmeVersionId,
      'compiler_version': compiled.manifest.compilerVersion,
      'graph_format_version': compiled.manifest.graphFormatVersion,
      'source_package_hash': compiled.manifest.sourceCanonicalContentSha256,
      'supplemental_relationship_hash':
          compiled.manifest.supplementalRelationshipSha256,
      'graph_structural_hash': compiled.manifest.graphCanonicalSha256,
      'composite_identity': compiled.manifest.compositeContentIdentity,
      'canonical_payload': jsonDecode(compiled.canonicalJson),
      'unresolved': compiled.manifest.unresolved,
      'require_full_resolution': false,
    };
  }

  Future<ContentGraphPublicationResult> persistPublished({
    required String programmeVersionId,
    bool authorised = true,
    Map<String, Object?>? overridePayload,
  }) {
    return repository.publish(
      payload: overridePayload ?? publishPayload(programmeVersionId),
      authorised: authorised,
    );
  }
}
