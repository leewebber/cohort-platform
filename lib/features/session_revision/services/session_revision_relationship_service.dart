import '../../../data/repositories/session_lineage_store.dart';
import '../../../data/repositories/session_lineage_supabase_store.dart';
import '../../../data/repositories/session_revision_relationship_store.dart';
import '../../../data/repositories/session_revision_relationship_supabase_store.dart';
import '../models/content_usage_vocabulary.dart';
import '../models/session_revision_usage_models.dart';

/// Read-only service for Session Revision usage relationships (M9.2).
///
/// Answers which programme versions, active assignments, and historical records
/// reference one exact Session Revision identified by [protocolId].
class SessionRevisionRelationshipService {
  SessionRevisionRelationshipService({
    SessionRevisionRelationshipStore? relationshipStore,
    SessionLineageStore? lineageStore,
  })  : _relationshipStore =
            relationshipStore ?? const SessionRevisionRelationshipSupabaseStore(),
        _lineageStore = lineageStore ?? const SessionLineageSupabaseStore();

  final SessionRevisionRelationshipStore _relationshipStore;
  final SessionLineageStore _lineageStore;

  Future<SessionRevisionUsageSummary> getUsageForRevision(
    String protocolId,
  ) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) {
      throw SessionRevisionRelationshipStoreException(
        'protocolId is required.',
      );
    }

    final identity =
        await _lineageStore.getRevisionIdentity(normalizedProtocolId);
    if (identity == null) {
      throw SessionRevisionRelationshipStoreException(
        'Session revision $normalizedProtocolId was not found.',
      );
    }

    final programmeReferences =
        await getProgrammeReferences(normalizedProtocolId);
    final activeAssignmentReferences =
        await getActiveAssignmentReferences(normalizedProtocolId);
    final historicalUsage = await getHistoricalUsage(normalizedProtocolId);

    final hasDirectAuthoredUsage = programmeReferences.isNotEmpty;
    final hasActiveOperationalUsage = activeAssignmentReferences.isNotEmpty;
    final hasHistoricalUsage = historicalUsage.hasUsage;

    return SessionRevisionUsageSummary(
      protocolId: identity.protocolId,
      sessionLineageId: identity.sessionLineageId,
      revisionNumber: identity.revisionNumber,
      programmeReferences: programmeReferences,
      activeAssignmentReferences: activeAssignmentReferences,
      historicalUsage: historicalUsage,
      classifications: buildUsageClassifications(
        hasDirectAuthoredUsage: hasDirectAuthoredUsage,
        hasActiveOperationalUsage: hasActiveOperationalUsage,
        hasHistoricalUsage: hasHistoricalUsage,
      ),
      programmeReferenceCount: countDistinctProgrammeVersions(programmeReferences),
      slotReferenceCount: programmeReferences.length,
    );
  }

  Future<List<SessionRevisionProgrammeReference>> getProgrammeReferences(
    String protocolId,
  ) {
    return _relationshipStore.listProgrammeSlotReferences(protocolId.trim());
  }

  Future<List<SessionRevisionAssignmentReference>>
      getActiveAssignmentReferences(
    String protocolId,
  ) {
    return _relationshipStore.listActiveAssignmentReferences(
      protocolId.trim(),
    );
  }

  Future<SessionRevisionHistoricalUsage> getHistoricalUsage(
    String protocolId,
  ) {
    return _relationshipStore.getHistoricalUsage(protocolId.trim());
  }
}
