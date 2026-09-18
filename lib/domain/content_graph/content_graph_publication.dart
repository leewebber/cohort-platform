import 'content_graph_vocabulary.dart';

enum ContentGraphPublicationStatus {
  published,
  alreadyPublished,
  hashMismatch,
  unsupportedFormat,
  unresolvedReference,
  conflictingIdentity,
  unauthorised,
}

class ContentGraphPublicationResult {
  const ContentGraphPublicationResult({
    required this.status,
    this.manifestId,
    this.programmeVersionId,
    this.compositeIdentity,
    this.code,
  });

  final ContentGraphPublicationStatus status;
  final String? manifestId;
  final String? programmeVersionId;
  final String? compositeIdentity;
  final String? code;

  bool get isSuccess =>
      status == ContentGraphPublicationStatus.published ||
      status == ContentGraphPublicationStatus.alreadyPublished;

  factory ContentGraphPublicationResult.fromJson(Map<String, Object?> json) {
    final raw = (json['status'] ?? '').toString();
    final status = ContentGraphPublicationStatus.values.firstWhere(
      (value) => _wireName(value) == raw,
      orElse: () => ContentGraphPublicationStatus.unsupportedFormat,
    );
    return ContentGraphPublicationResult(
      status: status,
      manifestId: json['manifest_id']?.toString(),
      programmeVersionId: json['programme_version_id']?.toString(),
      compositeIdentity: json['composite_identity']?.toString(),
      code: json['code']?.toString(),
    );
  }

  static String _wireName(ContentGraphPublicationStatus status) {
    switch (status) {
      case ContentGraphPublicationStatus.alreadyPublished:
        return 'already_published';
      case ContentGraphPublicationStatus.hashMismatch:
        return 'hash_mismatch';
      case ContentGraphPublicationStatus.unsupportedFormat:
        return 'unsupported_format';
      case ContentGraphPublicationStatus.unresolvedReference:
        return 'unresolved_reference';
      case ContentGraphPublicationStatus.conflictingIdentity:
        return 'conflicting_identity';
      case ContentGraphPublicationStatus.unauthorised:
        return 'unauthorised';
      case ContentGraphPublicationStatus.published:
        return 'published';
    }
  }
}

class PersistedContentGraphManifest {
  const PersistedContentGraphManifest({
    required this.id,
    required this.programmeVersionId,
    required this.compilerVersion,
    required this.graphFormatVersion,
    required this.sourcePackageHash,
    required this.supplementalRelationshipHash,
    required this.graphStructuralHash,
    required this.compositeIdentity,
    required this.canonicalPayload,
    required this.publicationState,
    required this.unresolved,
    this.createdAt,
  });

  final String id;
  final String programmeVersionId;
  final String compilerVersion;
  final int graphFormatVersion;
  final String sourcePackageHash;
  final String supplementalRelationshipHash;
  final String graphStructuralHash;
  final String compositeIdentity;
  final Map<String, Object?> canonicalPayload;
  final ContentLifecycle publicationState;
  final List<String> unresolved;
  final DateTime? createdAt;
}
