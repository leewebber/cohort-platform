import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/data/repositories/session_lineage_store.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import 'package:cohort_platform/models/session_lineage.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';

class InMemorySessionLineageStore extends SessionLineageStore {
  InMemorySessionLineageStore();

  final lineages = <SessionLineage>[];
  final revisionMetadata = <String, _RevisionMetadata>{};

  @override
  Future<SessionLineage> insertLineage({
    required String displayName,
    String? id,
  }) async {
    final lineage = SessionLineage(
      id: id ?? DatabaseUuid.newV4(),
      displayName: displayName.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    lineages.add(lineage);
    return lineage;
  }

  @override
  Future<SessionLineage?> getLineageById(String lineageId) async {
    for (final lineage in lineages) {
      if (lineage.id == lineageId) return lineage;
    }
    return null;
  }

  @override
  Future<int> getMaxRevisionNumber(String lineageId) async {
    var max = 0;
    for (final entry in revisionMetadata.entries) {
      if (entry.value.sessionLineageId == lineageId &&
          entry.value.revisionNumber > max) {
        max = entry.value.revisionNumber;
      }
    }
    return max;
  }

  @override
  Future<SessionRevisionLifecycleStatus?> getRevisionLifecycleStatus(
    String protocolId,
  ) async {
    return revisionMetadata[protocolId]?.lifecycleStatus;
  }

  @override
  Future<String?> getLineageIdForRevision(String protocolId) async {
    return revisionMetadata[protocolId]?.sessionLineageId;
  }

  @override
  Future<SessionRevisionIdentity?> getRevisionIdentity(String protocolId) async {
    final metadata = revisionMetadata[protocolId];
    if (metadata == null) return null;

    return SessionRevisionIdentity(
      protocolId: protocolId,
      sessionLineageId: metadata.sessionLineageId,
      revisionNumber: metadata.revisionNumber,
    );
  }

  @override
  Future<void> updateRevisionLifecycle({
    required String protocolId,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) async {
    final existing = revisionMetadata[protocolId];
    if (existing == null) return;
    revisionMetadata[protocolId] = existing.copyWith(
      lifecycleStatus: lifecycleStatus,
      publishedAt: publishedAt ?? existing.publishedAt,
      archivedAt: archivedAt ?? existing.archivedAt,
    );
  }

  @override
  Future<void> assignRevisionLineage({
    required String protocolId,
    required String sessionLineageId,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
  }) async {
    revisionMetadata[protocolId] = _RevisionMetadata(
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      lifecycleStatus: lifecycleStatus,
      publishedAt: publishedAt,
    );
  }

  void seedRevision({
    required String protocolId,
    required String sessionLineageId,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    revisionMetadata[protocolId] = _RevisionMetadata(
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      lifecycleStatus: lifecycleStatus,
      publishedAt: publishedAt,
      archivedAt: archivedAt,
    );
  }
}

class _RevisionMetadata {
  const _RevisionMetadata({
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.lifecycleStatus,
    this.publishedAt,
    this.archivedAt,
  });

  final String sessionLineageId;
  final int revisionNumber;
  final SessionRevisionLifecycleStatus lifecycleStatus;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  _RevisionMetadata copyWith({
    SessionRevisionLifecycleStatus? lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    return _RevisionMetadata(
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
