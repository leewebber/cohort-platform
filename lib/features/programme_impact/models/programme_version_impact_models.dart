import '../../../models/programme_vocabulary.dart';
import '../../../models/session_revision_vocabulary.dart';
import '../../session_revision/models/content_usage_vocabulary.dart';

/// One session slot pinned on an exact Programme Version.
class ProgrammeVersionSessionReference {
  const ProgrammeVersionSessionReference({
    required this.programmeVersionId,
    required this.slotId,
    required this.protocolId,
    required this.sessionLineageId,
    required this.sessionRevisionNumber,
    required this.sessionName,
    required this.sessionLifecycleStatus,
    required this.weekNumber,
    required this.dayKey,
    required this.dayOrder,
    required this.slotOrder,
    this.slotLabel,
    this.occurrenceCount = 1,
  });

  final String programmeVersionId;
  final String slotId;
  final String protocolId;
  final String sessionLineageId;
  final int sessionRevisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus sessionLifecycleStatus;
  final int weekNumber;
  final String dayKey;
  final int dayOrder;
  final int slotOrder;
  final String? slotLabel;
  final int occurrenceCount;
}

/// Exercise dependency aggregated across Session Revisions in one Programme Version.
class ProgrammeVersionExerciseReference {
  const ProgrammeVersionExerciseReference({
    required this.exerciseId,
    required this.exerciseName,
    required this.sessionRevisionIds,
    required this.sessionCount,
    required this.blockLinkCount,
    this.isLegacyReference = false,
  });

  final String exerciseId;
  final String exerciseName;
  final List<String> sessionRevisionIds;
  final int sessionCount;
  final int blockLinkCount;
  final bool isLegacyReference;
}

/// Active or historical assignment impact for one Programme Version.
class ProgrammeVersionAssignmentImpact {
  const ProgrammeVersionAssignmentImpact({
    required this.assignmentId,
    required this.assignmentStatus,
    required this.assignedAt,
    required this.isActive,
    this.startedAt,
    this.completedAt,
    this.progressSummary,
  });

  final String assignmentId;
  final ProgrammeAssignmentStatus assignmentStatus;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool isActive;
  final String? progressSummary;
}

/// Historical performance attributable to one exact Programme Version.
class ProgrammeVersionHistoricalImpact {
  const ProgrammeVersionHistoricalImpact({
    required this.terminalRecordCount,
    required this.completedSessionCount,
    required this.skippedSessionCount,
    required this.athleteCount,
    required this.sessionRevisionCount,
    required this.exerciseResultCount,
    required this.isAuthoritative,
    this.earliestPerformedAt,
    this.latestPerformedAt,
    this.limitationNote,
  });

  final int terminalRecordCount;
  final int completedSessionCount;
  final int skippedSessionCount;
  final int athleteCount;
  final int sessionRevisionCount;
  final int exerciseResultCount;
  final DateTime? earliestPerformedAt;
  final DateTime? latestPerformedAt;
  final bool isAuthoritative;
  final String? limitationNote;

  bool get hasUsage => terminalRecordCount > 0;
}

/// Lineage context for one queried Programme Version.
class ProgrammeVersionLineageContext {
  const ProgrammeVersionLineageContext({
    required this.programmeLineageId,
    required this.currentVersionNumber,
    required this.latestPublishedVersionId,
    required this.latestPublishedVersionNumber,
    required this.newerVersionIds,
    required this.hasNewerVersion,
    required this.queriedVersionLifecycleStatus,
  });

  final String programmeLineageId;
  final int currentVersionNumber;
  final String? latestPublishedVersionId;
  final int? latestPublishedVersionNumber;
  final List<String> newerVersionIds;
  final bool hasNewerVersion;
  final ProgrammeLifecycleStatus queriedVersionLifecycleStatus;
}

/// Read-only impact summary for one exact Programme Version (M10.1).
class ProgrammeVersionImpactSummary {
  const ProgrammeVersionImpactSummary({
    required this.programmeVersionId,
    required this.programmeLineageId,
    required this.programmeName,
    required this.versionNumber,
    required this.lifecycleStatus,
    required this.sessionReferences,
    required this.distinctSessionRevisionCount,
    required this.distinctSessionLineageCount,
    required this.totalSessionSlotCount,
    required this.exerciseReferences,
    required this.distinctExerciseCount,
    required this.activeAssignments,
    required this.activeAssignmentCount,
    required this.historicalImpact,
    required this.lineageContext,
    required this.classifications,
    required this.hasAuthoredContent,
    required this.hasActiveOperationalImpact,
    required this.hasHistoricalImpact,
    required this.isUnused,
    required this.warnings,
    required this.summaryMessages,
  });

  final String programmeVersionId;
  final String programmeLineageId;
  final String programmeName;
  final int versionNumber;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final List<ProgrammeVersionSessionReference> sessionReferences;
  final int distinctSessionRevisionCount;
  final int distinctSessionLineageCount;
  final int totalSessionSlotCount;
  final List<ProgrammeVersionExerciseReference> exerciseReferences;
  final int distinctExerciseCount;
  final List<ProgrammeVersionAssignmentImpact> activeAssignments;
  final int activeAssignmentCount;
  final ProgrammeVersionHistoricalImpact historicalImpact;
  final ProgrammeVersionLineageContext lineageContext;
  final List<ContentUsageClassification> classifications;
  final bool hasAuthoredContent;
  final bool hasActiveOperationalImpact;
  final bool hasHistoricalImpact;
  final bool isUnused;
  final List<String> warnings;
  final List<String> summaryMessages;
}

enum ProgrammeVersionImpactLookupStatus {
  success,
  versionNotFound,
  lookupFailed,
}

class ProgrammeVersionImpactLookupResult {
  const ProgrammeVersionImpactLookupResult._({
    required this.status,
    this.summary,
    this.message,
  });

  const ProgrammeVersionImpactLookupResult.success(
    ProgrammeVersionImpactSummary summary,
  ) : this._(status: ProgrammeVersionImpactLookupStatus.success, summary: summary);

  const ProgrammeVersionImpactLookupResult.versionNotFound()
      : this._(status: ProgrammeVersionImpactLookupStatus.versionNotFound);

  const ProgrammeVersionImpactLookupResult.lookupFailed(String message)
      : this._(
          status: ProgrammeVersionImpactLookupStatus.lookupFailed,
          message: message,
        );

  final ProgrammeVersionImpactLookupStatus status;
  final ProgrammeVersionImpactSummary? summary;
  final String? message;

  bool get isSuccess => status == ProgrammeVersionImpactLookupStatus.success;
}
