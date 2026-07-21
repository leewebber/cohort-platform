import 'package:cohort_platform/data/repositories/session_revision_relationship_store.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/repositories/performance_record_store.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'in_memory_programme_stores.dart';

/// In-memory relationship store for unit tests.
class InMemorySessionRevisionRelationshipStore
    extends SessionRevisionRelationshipStore {
  InMemorySessionRevisionRelationshipStore({
    required this.programmeTables,
    List<TrainingSessionRecord>? performanceRecords,
  }) : performanceRecords = performanceRecords ?? <TrainingSessionRecord>[];

  final InMemoryProgrammeTables programmeTables;
  final List<TrainingSessionRecord> performanceRecords;

  @override
  Future<List<SessionRevisionProgrammeReference>> listProgrammeSlotReferences(
    String protocolId,
  ) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) return const [];

    final references = <SessionRevisionProgrammeReference>[];

    for (final slot in programmeTables.slots) {
      if (slot.protocolId != normalizedProtocolId) continue;

      final day = _dayById(slot.dayId);
      if (day == null) continue;

      final week = _weekById(day.weekId);
      if (week == null) continue;

      final version = _versionById(week.versionId);
      if (version == null) continue;

      final lineage = _lineageById(version.lineageId);
      if (lineage == null) continue;

      references.add(
        _toProgrammeReference(
          slot: slot,
          day: day,
          week: week,
          version: version,
          lineage: lineage,
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

    return buildActiveAssignmentReferences(
      assignments: programmeTables.assignments,
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

    final terminalRecords = performanceRecords
        .where(
          (record) =>
              record.sourceProtocolId == normalizedProtocolId &&
              isTerminalRecordStatus(record.status),
        )
        .map(
          (record) => (
            performedAt: record.completedAt ?? record.startedAt,
          ),
        );

    return buildHistoricalUsage(terminalRecords: terminalRecords);
  }

  ProgrammeVersionDay? _dayById(String dayId) {
    for (final day in programmeTables.days) {
      if (day.id == dayId) return day;
    }
    return null;
  }

  ProgrammeVersionWeek? _weekById(String weekId) {
    for (final week in programmeTables.weeks) {
      if (week.id == weekId) return week;
    }
    return null;
  }

  ProgrammeVersion? _versionById(String versionId) {
    for (final version in programmeTables.versions) {
      if (version.id == versionId) return version;
    }
    return null;
  }

  ProgrammeLineage? _lineageById(String lineageId) {
    for (final lineage in programmeTables.lineages) {
      if (lineage.id == lineageId) return lineage;
    }
    return null;
  }

  static SessionRevisionProgrammeReference _toProgrammeReference({
    required ProgrammeVersionSessionSlot slot,
    required ProgrammeVersionDay day,
    required ProgrammeVersionWeek week,
    required ProgrammeVersion version,
    required ProgrammeLineage lineage,
  }) {
    return SessionRevisionProgrammeReference(
      programmeLineageId: lineage.id,
      programmeLineageCode: lineage.code,
      programmeVersionId: version.id,
      programmeVersionNumber: version.versionNumber,
      programmeName: version.name,
      programmeLifecycleStatus: version.lifecycleStatus,
      slotId: slot.id,
      weekNumber: week.weekNumber,
      dayKey: day.dayKey,
      dayOrder: day.dayOrder,
      slotOrder: slot.sessionOrder,
      slotLabel: slot.displayTitle,
    );
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
}
