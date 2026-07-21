import '../../core/services/supabase_service.dart';
import '../../features/performance/models/training_session_record_status.dart';
import '../../features/session_revision/models/session_revision_usage_models.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_vocabulary.dart';
import 'session_revision_relationship_store.dart';

class SessionRevisionRelationshipSupabaseStore
    extends SessionRevisionRelationshipStore {
  const SessionRevisionRelationshipSupabaseStore();

  static const _slotsTable = 'programme_version_session_slots';
  static const _daysTable = 'programme_version_days';
  static const _weeksTable = 'programme_version_weeks';
  static const _versionsTable = 'programme_versions';
  static const _lineagesTable = 'programme_lineages';
  static const _assignmentsTable = 'programme_assignments';
  static const _recordsTable = 'training_session_records';

  @override
  Future<List<SessionRevisionProgrammeReference>> listProgrammeSlotReferences(
    String protocolId,
  ) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) return const [];

    final slotRows = await SupabaseService.client
        .from(_slotsTable)
        .select('id, day_id, session_order, display_title, protocol_id')
        .eq('protocol_id', normalizedProtocolId);

    if (slotRows.isEmpty) return const [];

    final slots = List<Map<String, dynamic>>.from(slotRows as List);
    final dayIds = slots
        .map((row) => row['day_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (dayIds.isEmpty) return const [];

    final dayRows = await SupabaseService.client
        .from(_daysTable)
        .select('id, week_id, day_key, day_order')
        .inFilter('id', dayIds);

    final days = {
      for (final row in List<Map<String, dynamic>>.from(dayRows as List))
        row['id']?.toString(): row,
    };

    final weekIds = days.values
        .map((row) => row['week_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (weekIds.isEmpty) return const [];

    final weekRows = await SupabaseService.client
        .from(_weeksTable)
        .select('id, version_id, week_number')
        .inFilter('id', weekIds);

    final weeks = {
      for (final row in List<Map<String, dynamic>>.from(weekRows as List))
        row['id']?.toString(): row,
    };

    final versionIds = weeks.values
        .map((row) => row['version_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (versionIds.isEmpty) return const [];

    final versionRows = await SupabaseService.client
        .from(_versionsTable)
        .select('id, lineage_id, version_number, name, lifecycle_status')
        .inFilter('id', versionIds);

    final versions = {
      for (final row in List<Map<String, dynamic>>.from(versionRows as List))
        row['id']?.toString(): row,
    };

    final lineageIds = versions.values
        .map((row) => row['lineage_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final lineageRows = lineageIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from(_lineagesTable)
                .select('id, code')
                .inFilter('id', lineageIds) as List,
          );

    final lineages = {
      for (final row in lineageRows) row['id']?.toString(): row,
    };

    final references = <SessionRevisionProgrammeReference>[];

    for (final slot in slots) {
      final day = days[slot['day_id']?.toString()];
      if (day == null) continue;

      final week = weeks[day['week_id']?.toString()];
      if (week == null) continue;

      final version = versions[week['version_id']?.toString()];
      if (version == null) continue;

      final lineage = lineages[version['lineage_id']?.toString()];
      if (lineage == null) continue;

      references.add(
        SessionRevisionProgrammeReference(
          programmeLineageId: lineage['id']?.toString() ?? '',
          programmeLineageCode: lineage['code']?.toString() ?? '',
          programmeVersionId: version['id']?.toString() ?? '',
          programmeVersionNumber: version['version_number'] is int
              ? version['version_number'] as int
              : int.tryParse(version['version_number']?.toString() ?? '') ?? 1,
          programmeName: version['name']?.toString() ?? '',
          programmeLifecycleStatus: ProgrammeLifecycleStatusDb.fromDb(
            version['lifecycle_status']?.toString(),
          ),
          slotId: slot['id']?.toString() ?? '',
          weekNumber: week['week_number'] is int
              ? week['week_number'] as int
              : int.tryParse(week['week_number']?.toString() ?? '') ?? 1,
          dayKey: day['day_key']?.toString() ?? '',
          dayOrder: day['day_order'] is int
              ? day['day_order'] as int
              : int.tryParse(day['day_order']?.toString() ?? '') ?? 1,
          slotOrder: slot['session_order'] is int
              ? slot['session_order'] as int
              : int.tryParse(slot['session_order']?.toString() ?? '') ?? 1,
          slotLabel: _nullableTrimmedString(slot['display_title']),
        ),
      );
    }

    references.sort(_compareProgrammeReferences);
    return references;
  }

  @override
  Future<List<SessionRevisionAssignmentReference>>
      listActiveAssignmentReferences(
    String protocolId,
  ) async {
    final programmeReferences = await listProgrammeSlotReferences(protocolId);
    final versionIds = programmeReferences
        .map((reference) => reference.programmeVersionId)
        .toSet();

    if (versionIds.isEmpty) return const [];

    final assignmentRows = await SupabaseService.client
        .from(_assignmentsTable)
        .select()
        .inFilter('programme_version_id', versionIds.toList())
        .eq('status', ProgrammeAssignmentStatus.active.dbValue);

    final assignments = List<Map<String, dynamic>>.from(
      assignmentRows as List,
    ).map(ProgrammeAssignment.fromMap);

    return buildActiveAssignmentReferences(
      assignments: assignments,
      referencingVersionIds: versionIds,
    );
  }

  @override
  Future<SessionRevisionHistoricalUsage> getHistoricalUsage(
    String protocolId,
  ) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) {
      return const SessionRevisionHistoricalUsage(recordCount: 0);
    }

    final rows = await SupabaseService.client
        .from(_recordsTable)
        .select('started_at, completed_at, status')
        .eq('source_protocol_id', normalizedProtocolId)
        .neq('status', TrainingSessionRecordStatus.inProgress.dbValue);

    final terminalRecords = <({DateTime performedAt})>[];
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final status = TrainingSessionRecordStatusDb.fromDb(
        row['status']?.toString(),
      );
      if (!status.isTerminal) continue;

      final performedAt = _parseDateTime(row['completed_at']) ??
          _parseDateTime(row['started_at']);
      if (performedAt == null) continue;

      terminalRecords.add((performedAt: performedAt));
    }

    return buildHistoricalUsage(terminalRecords: terminalRecords);
  }

  static int _compareProgrammeReferences(
    SessionRevisionProgrammeReference a,
    SessionRevisionProgrammeReference b,
  ) {
    final lineageCompare =
        a.programmeLineageCode.compareTo(b.programmeLineageCode);
    if (lineageCompare != 0) return lineageCompare;

    final versionCompare =
        a.programmeVersionNumber.compareTo(b.programmeVersionNumber);
    if (versionCompare != 0) return versionCompare;

    final weekCompare = a.weekNumber.compareTo(b.weekNumber);
    if (weekCompare != 0) return weekCompare;

    final dayCompare = a.dayOrder.compareTo(b.dayOrder);
    if (dayCompare != 0) return dayCompare;

    return a.slotOrder.compareTo(b.slotOrder);
  }

  static String? _nullableTrimmedString(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
