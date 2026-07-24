import 'package:founder_importer/models/programme_vocabulary.dart';
import 'package:founder_importer/features/session_revision/models/content_usage_vocabulary.dart';

/// Identity metadata for one Session Revision instance.
class SessionRevisionIdentity {
  const SessionRevisionIdentity({
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
  });

  final String protocolId;
  final String sessionLineageId;
  final int revisionNumber;
}

/// One programme slot that references an exact Session Revision.
class SessionRevisionProgrammeReference {
  const SessionRevisionProgrammeReference({
    required this.programmeLineageId,
    required this.programmeLineageCode,
    required this.programmeVersionId,
    required this.programmeVersionNumber,
    required this.programmeName,
    required this.programmeLifecycleStatus,
    required this.slotId,
    required this.weekNumber,
    required this.dayKey,
    required this.dayOrder,
    required this.slotOrder,
    this.slotLabel,
  });

  final String programmeLineageId;
  final String programmeLineageCode;
  final String programmeVersionId;
  final int programmeVersionNumber;
  final String programmeName;
  final ProgrammeLifecycleStatus programmeLifecycleStatus;
  final String slotId;
  final int weekNumber;
  final String dayKey;
  final int dayOrder;
  final int slotOrder;
  final String? slotLabel;
}

/// One active assignment that transitively depends on a Session Revision.
class SessionRevisionAssignmentReference {
  const SessionRevisionAssignmentReference({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.assignmentStatus,
    required this.athleteId,
    required this.assignedAt,
    required this.isActive,
  });

  final String assignmentId;
  final String programmeVersionId;
  final ProgrammeAssignmentStatus assignmentStatus;
  final String athleteId;
  final DateTime assignedAt;
  final bool isActive;
}

/// Aggregated historical usage from terminal training records.
class SessionRevisionHistoricalUsage {
  const SessionRevisionHistoricalUsage({
    required this.recordCount,
    this.earliestPerformedAt,
    this.latestPerformedAt,
  });

  final int recordCount;
  final DateTime? earliestPerformedAt;
  final DateTime? latestPerformedAt;

  bool get hasUsage => recordCount > 0;
}

/// Read-only usage summary for one exact Session Revision.
class SessionRevisionUsageSummary {
  const SessionRevisionUsageSummary({
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.programmeReferences,
    required this.activeAssignmentReferences,
    required this.historicalUsage,
    required this.classifications,
    required this.programmeReferenceCount,
    required this.slotReferenceCount,
  });

  final String protocolId;
  final String sessionLineageId;
  final int revisionNumber;
  final List<SessionRevisionProgrammeReference> programmeReferences;
  final List<SessionRevisionAssignmentReference> activeAssignmentReferences;
  final SessionRevisionHistoricalUsage historicalUsage;
  final List<ContentUsageClassification> classifications;

  /// Distinct programme versions referencing this revision.
  final int programmeReferenceCount;

  /// Total slot rows referencing this revision (may exceed programme count).
  final int slotReferenceCount;

  bool get hasDirectAuthoredUsage =>
      classifications.contains(ContentUsageClassification.directAuthored);

  bool get hasActiveOperationalUsage =>
      classifications.contains(ContentUsageClassification.activeOperational);

  bool get hasHistoricalUsage =>
      classifications.contains(ContentUsageClassification.historicalPerformance);

  bool get isUnused => classifications.isEmpty;
}
