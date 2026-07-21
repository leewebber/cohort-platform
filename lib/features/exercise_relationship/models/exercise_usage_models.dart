import '../../session_revision/models/content_usage_vocabulary.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/session_revision_vocabulary.dart';

/// Where an Exercise-to-Session link was discovered.
enum ExerciseRelationshipSource {
  sessionBlockLink,
  legacyProtocolStep,
}

/// One block-level link from an exact Session Revision to an Exercise.
class ExerciseRevisionReference {
  const ExerciseRevisionReference({
    required this.protocolId,
    required this.sessionLineageId,
    required this.sessionRevisionNumber,
    required this.sessionName,
    required this.sessionLifecycleStatus,
    required this.blockId,
    required this.blockTitle,
    required this.blockOrder,
    required this.relationshipSource,
    this.exerciseLinkId,
    this.displayLabelOverride,
  });

  final String protocolId;
  final String sessionLineageId;
  final int sessionRevisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus sessionLifecycleStatus;
  final String blockId;
  final String blockTitle;
  final int blockOrder;
  final ExerciseRelationshipSource relationshipSource;
  final String? exerciseLinkId;
  final String? displayLabelOverride;
}

/// Session Lineages containing revisions that link to the Exercise.
class ExerciseSessionLineageReference {
  const ExerciseSessionLineageReference({
    required this.sessionLineageId,
    required this.sessionDisplayName,
    required this.revisionCount,
    required this.revisionNumbers,
  });

  final String sessionLineageId;
  final String sessionDisplayName;
  final int revisionCount;
  final List<int> revisionNumbers;
}

/// Programme Version dependency through an exact Session Revision using the Exercise.
class ExerciseProgrammeReference {
  const ExerciseProgrammeReference({
    required this.programmeLineageId,
    required this.programmeLineageCode,
    required this.programmeVersionId,
    required this.programmeVersionNumber,
    required this.programmeName,
    required this.programmeLifecycleStatus,
    required this.protocolId,
    required this.sessionRevisionNumber,
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
  final String protocolId;
  final int sessionRevisionNumber;
  final String slotId;
  final int weekNumber;
  final String dayKey;
  final int dayOrder;
  final int slotOrder;
  final String? slotLabel;
}

/// Active assignment dependency through a Programme Version containing the Exercise.
class ExerciseAssignmentReference {
  const ExerciseAssignmentReference({
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

/// Historical performance usage from terminal M8 records.
class ExerciseHistoricalUsage {
  const ExerciseHistoricalUsage({
    required this.recordCount,
    required this.performanceOccurrenceCount,
    required this.isAuthoritative,
    this.earliestPerformedAt,
    this.latestPerformedAt,
    this.sessionRevisionCount = 0,
    this.limitationNote,
  });

  final int recordCount;
  final int performanceOccurrenceCount;
  final DateTime? earliestPerformedAt;
  final DateTime? latestPerformedAt;
  final int sessionRevisionCount;
  final bool isAuthoritative;
  final String? limitationNote;

  bool get hasUsage => recordCount > 0 || performanceOccurrenceCount > 0;
}

/// Read-only usage summary for one exact Exercise.
class ExerciseUsageSummary {
  const ExerciseUsageSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.directSessionReferences,
    required this.sessionLineageReferences,
    required this.programmeReferences,
    required this.activeAssignmentReferences,
    required this.historicalUsage,
    required this.classifications,
    required this.directSessionRevisionCount,
    required this.directBlockReferenceCount,
    required this.sessionLineageCount,
    required this.programmeVersionCount,
    required this.activeAssignmentCount,
    required this.historicalRecordCount,
  });

  final String exerciseId;
  final String exerciseName;
  final List<ExerciseRevisionReference> directSessionReferences;
  final List<ExerciseSessionLineageReference> sessionLineageReferences;
  final List<ExerciseProgrammeReference> programmeReferences;
  final List<ExerciseAssignmentReference> activeAssignmentReferences;
  final ExerciseHistoricalUsage historicalUsage;
  final List<ContentUsageClassification> classifications;
  final int directSessionRevisionCount;
  final int directBlockReferenceCount;
  final int sessionLineageCount;
  final int programmeVersionCount;
  final int activeAssignmentCount;
  final int historicalRecordCount;

  bool get hasDirectAuthoredUsage =>
      classifications.contains(ContentUsageClassification.directAuthored);

  bool get hasActiveOperationalUsage =>
      classifications.contains(ContentUsageClassification.activeOperational);

  bool get hasHistoricalUsage =>
      classifications.contains(ContentUsageClassification.historicalPerformance);

  bool get isUnused => classifications.isEmpty;
}

enum ExerciseUsageLookupStatus {
  success,
  exerciseNotFound,
  lookupFailed,
}

class ExerciseUsageLookupResult {
  const ExerciseUsageLookupResult._({
    required this.status,
    this.summary,
    this.message,
  });

  const ExerciseUsageLookupResult.success(ExerciseUsageSummary summary)
      : this._(status: ExerciseUsageLookupStatus.success, summary: summary);

  const ExerciseUsageLookupResult.exerciseNotFound()
      : this._(status: ExerciseUsageLookupStatus.exerciseNotFound);

  const ExerciseUsageLookupResult.lookupFailed(String message)
      : this._(
          status: ExerciseUsageLookupStatus.lookupFailed,
          message: message,
        );

  final ExerciseUsageLookupStatus status;
  final ExerciseUsageSummary? summary;
  final String? message;

  bool get isSuccess => status == ExerciseUsageLookupStatus.success;
}
