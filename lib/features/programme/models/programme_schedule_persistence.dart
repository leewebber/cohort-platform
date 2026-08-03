import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';

/// Typed outcomes for Sprint 1.7C durable schedule projection persistence.
enum ProgrammeSchedulePersistenceStatus {
  initialised,
  alreadyExists,
  restored,
  absent,
  assignmentNotFound,
  assignmentNotOwned,
  assignmentIneligible,
  packageProvenanceMismatch,
  malformedBaseline,
  duplicateOccurrenceIdentity,
  scheduleRevisionConflict,
  localCacheStale,
  localCacheCorrupt,
  authoritativeReloadRequired,
  persistenceUnavailable,
  unsupportedSchemaVersion,
  authorizationFailure,
  validationFailure,
  conflict,
  failed,
}

/// Authoritative persisted projection DTO returned by ensure/load RPCs.
class PersistedProgrammeScheduleProjection {
  const PersistedProgrammeScheduleProjection({
    required this.assignmentId,
    required this.athleteId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.timezone,
    required this.startedAt,
    required this.scheduleRevision,
    required this.schemaVersion,
    required this.occurrences,
    this.schedulingHorizonEnd,
    this.createdAt,
    this.updatedAt,
  });

  final String assignmentId;
  final String athleteId;
  final String programmeVersionId;
  final String packageContentHash;
  final String timezone;
  final SessionOccurrenceDate startedAt;
  final int scheduleRevision;
  final String schemaVersion;
  final List<PersistedProgrammeScheduleOccurrence> occurrences;

  /// Inclusive last permitted athlete-local date; null = explicitly unbounded.
  final SessionOccurrenceDate? schedulingHorizonEnd;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PersistedProgrammeScheduleProjection.fromMap(
    Map<String, dynamic> map,
  ) {
    final occRaw = map['occurrences'];
    final occurrences = <PersistedProgrammeScheduleOccurrence>[];
    if (occRaw is List) {
      for (final item in occRaw) {
        if (item is Map<String, dynamic>) {
          occurrences.add(PersistedProgrammeScheduleOccurrence.fromMap(item));
        } else if (item is Map) {
          occurrences.add(
            PersistedProgrammeScheduleOccurrence.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }
    return PersistedProgrammeScheduleProjection(
      assignmentId: _req(map['assignment_id']),
      athleteId: _req(map['athlete_id']),
      programmeVersionId: _req(map['programme_version_id']),
      packageContentHash: _req(map['package_content_hash']),
      timezone: _req(map['timezone']),
      startedAt: _reqDate(map['started_at']),
      scheduleRevision: _reqInt(map['schedule_revision']),
      schemaVersion: map['schema_version']?.toString() ??
          'programme.schedule.projection.v1',
      occurrences: List.unmodifiable(occurrences),
      schedulingHorizonEnd: _nullableDate(map['scheduling_horizon_end']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, Object?> toPersistenceMap() => {
    'assignment_id': assignmentId,
    'athlete_id': athleteId,
    'programme_version_id': programmeVersionId,
    'package_content_hash': packageContentHash,
    'timezone': timezone,
    'started_at': startedAt.toString(),
    'schedule_revision': scheduleRevision,
    'schema_version': schemaVersion,
    'scheduling_horizon_end': schedulingHorizonEnd?.toString(),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'occurrences': occurrences.map((o) => o.toPersistenceMap()).toList(),
  };

  ProgrammeScheduleProjection toDomainProjection() {
    return ProgrammeScheduleProjection(
      scheduleRevision: scheduleRevision,
      occurrences: occurrences
          .map(
            (o) => o.toDomainOccurrence(
              assignmentId: assignmentId,
            ),
          )
          .toList(),
    );
  }

  /// Reconstructs a compute-only preview snapshot from durable projection.
  ///
  /// Prepared/adapted/pending flags remain owned elsewhere and default empty
  /// unless the caller supplies them — this method does not mutate those owners.
  ProgrammeSchedulingSnapshot toSchedulingSnapshot({
    required SessionOccurrenceDate today,
    ProgrammeSchedulingAssignmentStatus assignmentStatus =
        ProgrammeSchedulingAssignmentStatus.active,
    SessionOccurrenceDate? schedulingHorizonEnd,
    Set<String> preparedProgrammedSessionKeys = const {},
    Set<String> adaptedProgrammedSessionKeys = const {},
    Set<String> pendingAdaptationProposalKeys = const {},
    Set<String> consumedAdaptationProposalIds = const {},
    String? cursorSessionSlotId,
  }) {
    return ProgrammeSchedulingSnapshot(
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      packageContentHash: packageContentHash,
      timezone: timezone,
      startedAt: startedAt,
      today: today,
      assignmentStatus: assignmentStatus,
      projection: toDomainProjection(),
      schedulingHorizonEnd: schedulingHorizonEnd ?? this.schedulingHorizonEnd,
      preparedProgrammedSessionKeys: preparedProgrammedSessionKeys,
      adaptedProgrammedSessionKeys: adaptedProgrammedSessionKeys,
      pendingAdaptationProposalKeys: pendingAdaptationProposalKeys,
      consumedAdaptationProposalIds: consumedAdaptationProposalIds,
      cursorSessionSlotId: cursorSessionSlotId,
    );
  }
}

class PersistedProgrammeScheduleOccurrence {
  const PersistedProgrammeScheduleOccurrence({
    required this.sessionSlotId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.protocolId,
    required this.programmedSessionKey,
    required this.scheduledDate,
    required this.disposition,
  });

  final String sessionSlotId;
  final String programmeVersionId;
  final String packageContentHash;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String protocolId;
  final String programmedSessionKey;
  final SessionOccurrenceDate scheduledDate;
  final ProgrammeScheduleDisposition disposition;

  factory PersistedProgrammeScheduleOccurrence.fromMap(
    Map<String, dynamic> map,
  ) {
    return PersistedProgrammeScheduleOccurrence(
      sessionSlotId: _req(map['session_slot_id']),
      programmeVersionId: _req(map['programme_version_id']),
      packageContentHash: _req(map['package_content_hash']),
      weekNumber: _reqInt(map['week_number']),
      dayKey: _req(map['day_key']),
      sessionOrder: _reqInt(map['session_order']),
      protocolId: _req(map['protocol_id']),
      programmedSessionKey: _req(map['programmed_session_key']),
      scheduledDate: _reqDate(map['scheduled_date']),
      disposition: _disposition(map['disposition']),
    );
  }

  Map<String, Object?> toPersistenceMap() => {
    'session_slot_id': sessionSlotId,
    'programme_version_id': programmeVersionId,
    'package_content_hash': packageContentHash,
    'week_number': weekNumber,
    'day_key': dayKey,
    'session_order': sessionOrder,
    'protocol_id': protocolId,
    'programmed_session_key': programmedSessionKey,
    'scheduled_date': scheduledDate.toString(),
    'disposition': disposition.name,
  };

  ScheduledProgrammeOccurrence toDomainOccurrence({
    required String assignmentId,
  }) {
    return ScheduledProgrammeOccurrence(
      identity: ScheduledOccurrenceIdentity(
        assignmentId: assignmentId,
        programmeVersionId: programmeVersionId,
        packageContentHash: packageContentHash,
        sessionSlotId: sessionSlotId,
        weekNumber: weekNumber,
        dayKey: dayKey,
        sessionOrder: sessionOrder,
        protocolId: protocolId,
        programmedSessionKey: programmedSessionKey,
      ),
      scheduledDate: scheduledDate,
      disposition: disposition,
    );
  }
}

class ProgrammeSchedulePersistenceResult {
  const ProgrammeSchedulePersistenceResult({
    required this.status,
    this.code,
    this.message,
    this.assignmentId,
    this.scheduleRevision,
    this.projection,
    this.source = ProgrammeSchedulePersistenceSource.server,
  });

  final ProgrammeSchedulePersistenceStatus status;
  final String? code;
  final String? message;
  final String? assignmentId;
  final int? scheduleRevision;
  final PersistedProgrammeScheduleProjection? projection;
  final ProgrammeSchedulePersistenceSource source;

  bool get isSuccess =>
      status == ProgrammeSchedulePersistenceStatus.initialised ||
      status == ProgrammeSchedulePersistenceStatus.alreadyExists ||
      status == ProgrammeSchedulePersistenceStatus.restored;

  factory ProgrammeSchedulePersistenceResult.fromEnsureRpcMap(
    Map<String, dynamic> map,
  ) {
    final statusRaw = map['status']?.toString() ?? 'failed';
    final code = map['code']?.toString();
    final status = _statusFromEnsure(statusRaw, code);
    PersistedProgrammeScheduleProjection? projection;
    final projRaw = map['projection'];
    if (projRaw is Map<String, dynamic>) {
      projection = PersistedProgrammeScheduleProjection.fromMap(projRaw);
    } else if (projRaw is Map) {
      projection = PersistedProgrammeScheduleProjection.fromMap(
        Map<String, dynamic>.from(projRaw),
      );
    }
    return ProgrammeSchedulePersistenceResult(
      status: status,
      code: code,
      message: map['message']?.toString(),
      assignmentId: map['assignment_id']?.toString(),
      scheduleRevision: _nullableInt(map['schedule_revision']),
      projection: projection,
      source: ProgrammeSchedulePersistenceSource.server,
    );
  }
}

enum ProgrammeSchedulePersistenceSource { server, localCache }

ProgrammeSchedulePersistenceStatus _statusFromEnsure(
  String statusRaw,
  String? code,
) {
  switch (statusRaw) {
    case 'initialised':
      return ProgrammeSchedulePersistenceStatus.initialised;
    case 'already_exists':
      return ProgrammeSchedulePersistenceStatus.alreadyExists;
    case 'authorization_failure':
      if (code == 'assignment_not_found') {
        return ProgrammeSchedulePersistenceStatus.assignmentNotFound;
      }
      return ProgrammeSchedulePersistenceStatus.authorizationFailure;
    case 'validation_failure':
      switch (code) {
        case 'assignment_not_materialised':
        case 'assignment_ineligible':
          return ProgrammeSchedulePersistenceStatus.assignmentIneligible;
        case 'package_provenance_mismatch':
          return ProgrammeSchedulePersistenceStatus.packageProvenanceMismatch;
        case 'empty_programme_structure':
          return ProgrammeSchedulePersistenceStatus.malformedBaseline;
        default:
          return ProgrammeSchedulePersistenceStatus.validationFailure;
      }
    case 'conflict':
      if (code == 'duplicate_occurrence_identity') {
        return ProgrammeSchedulePersistenceStatus.duplicateOccurrenceIdentity;
      }
      if (code == 'projection_provenance_conflict') {
        return ProgrammeSchedulePersistenceStatus.packageProvenanceMismatch;
      }
      return ProgrammeSchedulePersistenceStatus.conflict;
    default:
      return ProgrammeSchedulePersistenceStatus.failed;
  }
}

String _req(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    throw const FormatException('Missing required projection field');
  }
  return text;
}

int _reqInt(Object? value) {
  if (value is int) return value;
  return int.parse(value.toString());
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

SessionOccurrenceDate _reqDate(Object? value) {
  final text = value?.toString() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (match == null) {
    throw FormatException('Invalid date: $value');
  }
  return SessionOccurrenceDate(
    year: int.parse(match.group(1)!),
    month: int.parse(match.group(2)!),
    day: int.parse(match.group(3)!),
  );
}

SessionOccurrenceDate? _nullableDate(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return _reqDate(text);
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

ProgrammeScheduleDisposition _disposition(Object? value) {
  switch (value?.toString()) {
    case 'skipped':
      return ProgrammeScheduleDisposition.skipped;
    case 'completed':
      return ProgrammeScheduleDisposition.completed;
    default:
      return ProgrammeScheduleDisposition.scheduled;
  }
}
