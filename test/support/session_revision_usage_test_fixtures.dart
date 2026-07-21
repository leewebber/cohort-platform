import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'in_memory_programme_stores.dart';
import 'in_memory_session_lineage_store.dart';

class SessionRevisionUsageTestFixtures {
  static ProgrammeLineage seedLineage(
    InMemoryProgrammeTables tables, {
    String id = 'lineage-1',
    String code = 'PROG-TEST',
  }) {
    final lineage = ProgrammeLineage(id: id, code: code);
    tables.lineages.add(lineage);
    return lineage;
  }

  static ProgrammeVersion seedVersion(
    InMemoryProgrammeTables tables, {
    required ProgrammeLineage lineage,
    String id = 'version-1',
    int versionNumber = 1,
    ProgrammeLifecycleStatus lifecycleStatus =
        ProgrammeLifecycleStatus.published,
    String name = 'Test Programme',
  }) {
    final version = ProgrammeVersion(
      id: id,
      lineageId: lineage.id,
      versionNumber: versionNumber,
      lifecycleStatus: lifecycleStatus,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      name: name,
    );
    tables.versions.add(version);
    return version;
  }

  static ProgrammeVersionWeek seedWeek(
    InMemoryProgrammeTables tables, {
    required ProgrammeVersion version,
    String id = 'week-1',
    int weekNumber = 1,
  }) {
    final week = ProgrammeVersionWeek(
      id: id,
      versionId: version.id,
      weekNumber: weekNumber,
    );
    tables.weeks.add(week);
    return week;
  }

  static ProgrammeVersionDay seedDay(
    InMemoryProgrammeTables tables, {
    required ProgrammeVersionWeek week,
    String id = 'day-1',
    String dayKey = 'day_1',
    int dayOrder = 1,
  }) {
    final day = ProgrammeVersionDay(
      id: id,
      weekId: week.id,
      dayKey: dayKey,
      dayOrder: dayOrder,
    );
    tables.days.add(day);
    return day;
  }

  static ProgrammeVersionSessionSlot seedSlot(
    InMemoryProgrammeTables tables, {
    required ProgrammeVersionDay day,
    required String protocolId,
    String id = 'slot-1',
    int sessionOrder = 1,
    String? displayTitle,
  }) {
    final slot = ProgrammeVersionSessionSlot(
      id: id,
      dayId: day.id,
      sessionOrder: sessionOrder,
      protocolId: protocolId,
      displayTitle: displayTitle,
    );
    tables.slots.add(slot);
    return slot;
  }

  static void seedRevisionMetadata(
    InMemorySessionLineageStore lineageStore, {
    required String protocolId,
    required String sessionLineageId,
    int revisionNumber = 1,
    SessionRevisionLifecycleStatus lifecycleStatus =
        SessionRevisionLifecycleStatus.published,
  }) {
    lineageStore.seedRevision(
      protocolId: protocolId,
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      lifecycleStatus: lifecycleStatus,
    );
  }

  static ProgrammeAssignment seedAssignment(
    InMemoryProgrammeTables tables, {
    required String athleteId,
    required ProgrammeVersion version,
    required ProgrammeLineage lineage,
    String id = 'assignment-1',
    ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
    DateTime? startedAt,
  }) {
    final assignment = ProgrammeAssignment(
      id: id,
      athleteId: athleteId,
      programmeVersionId: version.id,
      lineageCode: lineage.code,
      status: status,
      startedAt: startedAt ?? DateTime.utc(2026, 1, 1),
    );
    tables.assignments.add(assignment);
    return assignment;
  }

  static TrainingSessionRecord seedTerminalRecord({
    required String recordId,
    required String athleteId,
    required String sourceProtocolId,
    required DateTime performedAt,
    TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
  }) {
    return TrainingSessionRecord(
      recordId: recordId,
      athleteId: athleteId,
      sourceProtocolId: sourceProtocolId,
      status: status,
      sessionSnapshot: SessionPerformanceSnapshot(
        sourceProtocolId: sourceProtocolId,
        sessionTitle: 'Snapshot',
      ),
      startedAt: performedAt,
      completedAt: performedAt,
    );
  }
}
