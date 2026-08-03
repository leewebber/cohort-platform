import '../../../core/persistence/athlete_local_repository.dart';
import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../models/programme_schedule_persistence.dart';
import 'programme_schedule_projection_store.dart';

/// Restores authoritative schedule projection after relaunch.
///
/// Server projection outranks local cache. Cache is athlete+assignment scoped
/// and never invents successful server persistence.
class ProgrammeScheduleRestoreService {
  const ProgrammeScheduleRestoreService({
    required this.store,
    required this.localRepository,
  });

  final ProgrammeScheduleProjectionStore store;
  final AthleteLocalRepository localRepository;

  static const supportedSchemaVersion = 'programme.schedule.projection.v1';

  /// Ensures baseline exists on the server, then caches and returns it.
  Future<ProgrammeSchedulePersistenceResult> ensureAndRestore({
    required String athleteId,
    required String programmeAssignmentId,
  }) async {
    final server = await store.ensureBaseline(
      programmeAssignmentId: programmeAssignmentId,
    );
    if (!server.isSuccess || server.projection == null) {
      return server;
    }

    final projection = server.projection!;
    if (projection.athleteId != athleteId) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.assignmentNotOwned,
        code: 'cross_athlete_projection',
        message: 'Projection athlete does not match signed-in athlete.',
        assignmentId: programmeAssignmentId,
      );
    }
    if (projection.schemaVersion != supportedSchemaVersion) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.unsupportedSchemaVersion,
        code: 'unsupported_schema_version',
        assignmentId: programmeAssignmentId,
        projection: projection,
      );
    }

    await localRepository.saveProgrammeScheduleProjection(
      athleteId: athleteId,
      projection: projection,
    );

    return ProgrammeSchedulePersistenceResult(
      status: server.status == ProgrammeSchedulePersistenceStatus.initialised
          ? ProgrammeSchedulePersistenceStatus.initialised
          : ProgrammeSchedulePersistenceStatus.restored,
      code: server.code,
      assignmentId: projection.assignmentId,
      scheduleRevision: projection.scheduleRevision,
      projection: projection,
      source: ProgrammeSchedulePersistenceSource.server,
    );
  }

  /// Relaunch path: prefer server ensure; fall back to validated cache only
  /// when server is unavailable, without treating cache as authoritative write.
  Future<ProgrammeSchedulePersistenceResult> restoreAfterRelaunch({
    required String athleteId,
    required String programmeAssignmentId,
    bool preferServer = true,
  }) async {
    if (preferServer) {
      final server = await ensureAndRestore(
        athleteId: athleteId,
        programmeAssignmentId: programmeAssignmentId,
      );
      if (server.isSuccess ||
          server.status !=
              ProgrammeSchedulePersistenceStatus.persistenceUnavailable) {
        return server;
      }
    }

    final cached = await localRepository.readProgrammeScheduleProjection(
      athleteId: athleteId,
      assignmentId: programmeAssignmentId,
    );
    if (cached == null) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.absent,
        code: 'projection_absent',
        assignmentId: programmeAssignmentId,
      );
    }

    final validated = _validateCache(
      athleteId: athleteId,
      assignmentId: programmeAssignmentId,
      cached: cached,
    );
    if (validated != null) return validated;

    return ProgrammeSchedulePersistenceResult(
      status: ProgrammeSchedulePersistenceStatus.restored,
      code: 'restored_from_cache_pending_reload',
      assignmentId: cached.assignmentId,
      scheduleRevision: cached.scheduleRevision,
      projection: cached,
      source: ProgrammeSchedulePersistenceSource.localCache,
    );
  }

  /// Rejects stale/corrupt/mismatched cache relative to known server truth.
  ProgrammeSchedulePersistenceResult? rejectStaleCache({
    required String athleteId,
    required String assignmentId,
    required PersistedProgrammeScheduleProjection cache,
    required PersistedProgrammeScheduleProjection server,
  }) {
    if (cache.athleteId != athleteId || cache.assignmentId != assignmentId) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.localCacheCorrupt,
        code: 'cache_scope_mismatch',
      );
    }
    if (cache.programmeVersionId != server.programmeVersionId ||
        cache.packageContentHash != server.packageContentHash) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.packageProvenanceMismatch,
        code: 'cache_provenance_mismatch',
      );
    }
    if (cache.scheduleRevision < server.scheduleRevision) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.localCacheStale,
        code: 'cache_revision_stale',
        scheduleRevision: server.scheduleRevision,
        projection: server,
        source: ProgrammeSchedulePersistenceSource.server,
      );
    }
    if (cache.scheduleRevision > server.scheduleRevision) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.authoritativeReloadRequired,
        code: 'cache_ahead_of_server',
        projection: server,
        source: ProgrammeSchedulePersistenceSource.server,
      );
    }
    return null;
  }

  ProgrammeSchedulingSnapshot snapshotForPreview({
    required PersistedProgrammeScheduleProjection projection,
    required SessionOccurrenceDate today,
    ProgrammeSchedulingAssignmentStatus assignmentStatus =
        ProgrammeSchedulingAssignmentStatus.active,
    String? cursorSessionSlotId,
    Set<String> preparedProgrammedSessionKeys = const {},
    Set<String> adaptedProgrammedSessionKeys = const {},
    Set<String> pendingAdaptationProposalKeys = const {},
    Set<String> consumedAdaptationProposalIds = const {},
  }) {
    return projection.toSchedulingSnapshot(
      today: today,
      assignmentStatus: assignmentStatus,
      cursorSessionSlotId: cursorSessionSlotId,
      preparedProgrammedSessionKeys: preparedProgrammedSessionKeys,
      adaptedProgrammedSessionKeys: adaptedProgrammedSessionKeys,
      pendingAdaptationProposalKeys: pendingAdaptationProposalKeys,
      consumedAdaptationProposalIds: consumedAdaptationProposalIds,
    );
  }

  ProgrammeSchedulePersistenceResult? _validateCache({
    required String athleteId,
    required String assignmentId,
    required PersistedProgrammeScheduleProjection cached,
  }) {
    if (cached.athleteId != athleteId || cached.assignmentId != assignmentId) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.localCacheCorrupt,
        code: 'cache_scope_mismatch',
      );
    }
    if (cached.schemaVersion != supportedSchemaVersion) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.unsupportedSchemaVersion,
        code: 'unsupported_schema_version',
      );
    }
    if (cached.occurrences.isEmpty) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.localCacheCorrupt,
        code: 'empty_projection_cache',
      );
    }
    final seen = <String>{};
    for (final occurrence in cached.occurrences) {
      if (!seen.add(occurrence.sessionSlotId)) {
        return const ProgrammeSchedulePersistenceResult(
          status: ProgrammeSchedulePersistenceStatus.localCacheCorrupt,
          code: 'duplicate_occurrence_in_cache',
        );
      }
      if (occurrence.programmeVersionId != cached.programmeVersionId ||
          occurrence.packageContentHash != cached.packageContentHash) {
        return const ProgrammeSchedulePersistenceResult(
          status: ProgrammeSchedulePersistenceStatus.packageProvenanceMismatch,
          code: 'cache_occurrence_provenance_mismatch',
        );
      }
    }
    return null;
  }
}
