import '../../features/session_revision/models/session_revision_usage_models.dart';
import '../../models/session_lineage.dart';
import '../../models/session_revision_vocabulary.dart';

/// Persistence boundary for Session Lineages and revision metadata.
abstract class SessionLineageStore {
  const SessionLineageStore();

  Future<SessionLineage> insertLineage({
    required String displayName,
    String? id,
  });

  Future<SessionLineage?> getLineageById(String lineageId);

  Future<int> getMaxRevisionNumber(String lineageId);

  Future<SessionRevisionLifecycleStatus?> getRevisionLifecycleStatus(
    String protocolId,
  );

  Future<String?> getLineageIdForRevision(String protocolId);

  Future<SessionRevisionIdentity?> getRevisionIdentity(String protocolId);

  Future<void> updateRevisionLifecycle({
    required String protocolId,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  });

  Future<void> assignRevisionLineage({
    required String protocolId,
    required String sessionLineageId,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
  });
}

class SessionLineageStoreException implements Exception {
  const SessionLineageStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
