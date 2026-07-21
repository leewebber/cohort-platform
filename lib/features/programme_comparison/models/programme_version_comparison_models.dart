import '../../../models/programme_vocabulary.dart';
import '../../../models/session_revision_vocabulary.dart';

enum ProgrammeVersionComparisonStatus {
  success,
  sourceNotFound,
  targetNotFound,
  incompatibleLineage,
  lookupFailed,
  partial,
}

enum ProgrammeChangeType {
  added,
  removed,
  modified,
  moved,
  replaced,
  unchanged,
}

enum ProgrammeChangeSeverity {
  informational,
  low,
  moderate,
  high,
}

enum ProgrammeComparisonClassification {
  metadataChanged,
  structureChanged,
  sessionsAdded,
  sessionsRemoved,
  sessionsMoved,
  sessionRevisionsUpdated,
  exercisesAdded,
  exercisesRemoved,
  identical,
  partialComparison,
}

enum ProgrammeSlotMatchingBasis {
  stableSlotId,
  structuralPosition,
  sessionLineageContext,
  unmatched,
}

class ProgrammeVersionComparisonIdentity {
  const ProgrammeVersionComparisonIdentity({
    required this.programmeLineageId,
    required this.programmeName,
    required this.sourceVersionId,
    required this.sourceVersionNumber,
    required this.sourceLifecycleStatus,
    required this.targetVersionId,
    required this.targetVersionNumber,
    required this.targetLifecycleStatus,
  });

  final String programmeLineageId;
  final String programmeName;
  final String sourceVersionId;
  final int sourceVersionNumber;
  final ProgrammeLifecycleStatus sourceLifecycleStatus;
  final String targetVersionId;
  final int targetVersionNumber;
  final ProgrammeLifecycleStatus targetLifecycleStatus;
}

class ProgrammeMetadataChange {
  const ProgrammeMetadataChange({
    required this.field,
    required this.sourceValue,
    required this.targetValue,
    required this.changeType,
  });

  final String field;
  final String? sourceValue;
  final String? targetValue;
  final ProgrammeChangeType changeType;
}

class ProgrammeWeekReference {
  const ProgrammeWeekReference({
    required this.weekId,
    required this.weekIndex,
    this.title,
  });

  final String weekId;
  final int weekIndex;
  final String? title;
}

class ProgrammeDayReference {
  const ProgrammeDayReference({
    required this.dayId,
    required this.weekIndex,
    required this.dayIndex,
    required this.dayKey,
    this.title,
  });

  final String dayId;
  final int weekIndex;
  final int dayIndex;
  final String dayKey;
  final String? title;
}

class ProgrammeSlotSnapshot {
  const ProgrammeSlotSnapshot({
    required this.slotId,
    required this.weekId,
    required this.dayId,
    required this.weekIndex,
    required this.dayIndex,
    required this.slotIndex,
    required this.dayKey,
    required this.protocolId,
    required this.sessionLineageId,
    required this.sessionRevisionNumber,
    required this.sessionName,
    required this.sessionLifecycleStatus,
    this.slotLabel,
    this.timeOfDay,
    this.isOptional = false,
    this.completionExpectation,
    this.coachNote,
    this.athleteNote,
  });

  final String slotId;
  final String weekId;
  final String dayId;
  final int weekIndex;
  final int dayIndex;
  final int slotIndex;
  final String dayKey;
  final String protocolId;
  final String sessionLineageId;
  final int sessionRevisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus sessionLifecycleStatus;
  final String? slotLabel;
  final String? timeOfDay;
  final bool isOptional;
  final String? completionExpectation;
  final String? coachNote;
  final String? athleteNote;
}

class ProgrammeSlotChange {
  const ProgrammeSlotChange({
    required this.changeType,
    required this.matchingBasis,
    this.sourceSlot,
    this.targetSlot,
    this.changedFields = const [],
    this.sourcePosition,
    this.targetPosition,
  });

  final ProgrammeChangeType changeType;
  final ProgrammeSlotMatchingBasis matchingBasis;
  final ProgrammeSlotSnapshot? sourceSlot;
  final ProgrammeSlotSnapshot? targetSlot;
  final List<String> changedFields;
  final String? sourcePosition;
  final String? targetPosition;
}

class ProgrammeWeekChange {
  const ProgrammeWeekChange({
    required this.changeType,
    required this.matchingBasis,
    this.sourceWeek,
    this.targetWeek,
    this.changedFields = const [],
  });

  final ProgrammeChangeType changeType;
  final String matchingBasis;
  final ProgrammeWeekReference? sourceWeek;
  final ProgrammeWeekReference? targetWeek;
  final List<String> changedFields;
}

class ProgrammeDayChange {
  const ProgrammeDayChange({
    required this.changeType,
    required this.matchingBasis,
    this.sourceDay,
    this.targetDay,
    this.changedFields = const [],
  });

  final ProgrammeChangeType changeType;
  final String matchingBasis;
  final ProgrammeDayReference? sourceDay;
  final ProgrammeDayReference? targetDay;
  final List<String> changedFields;
}

class SessionRevisionChange {
  const SessionRevisionChange({
    required this.sessionLineageId,
    required this.changeType,
    this.sourceProtocolId,
    this.sourceRevisionNumber,
    this.targetProtocolId,
    this.targetRevisionNumber,
    this.sourceSessionName,
    this.targetSessionName,
    this.sourceSlotReferences = const [],
    this.targetSlotReferences = const [],
  });

  final String sessionLineageId;
  final String? sourceProtocolId;
  final int? sourceRevisionNumber;
  final String? targetProtocolId;
  final int? targetRevisionNumber;
  final String? sourceSessionName;
  final String? targetSessionName;
  final ProgrammeChangeType changeType;
  final List<String> sourceSlotReferences;
  final List<String> targetSlotReferences;
}

class ExerciseSetChange {
  const ExerciseSetChange({
    required this.addedExercises,
    required this.removedExercises,
    required this.retainedExercises,
    required this.sourceExerciseCount,
    required this.targetExerciseCount,
    required this.netExerciseCountChange,
  });

  final List<String> addedExercises;
  final List<String> removedExercises;
  final List<String> retainedExercises;
  final int sourceExerciseCount;
  final int targetExerciseCount;
  final int netExerciseCountChange;
}

class ExerciseReferenceChange {
  const ExerciseReferenceChange({
    required this.exerciseId,
    required this.exerciseName,
    required this.changeType,
    required this.sourceSessionRevisionIds,
    required this.targetSessionRevisionIds,
    required this.sourceBlockLinkCount,
    required this.targetBlockLinkCount,
  });

  final String exerciseId;
  final String exerciseName;
  final ProgrammeChangeType changeType;
  final List<String> sourceSessionRevisionIds;
  final List<String> targetSessionRevisionIds;
  final int sourceBlockLinkCount;
  final int targetBlockLinkCount;
}

class ProgrammeStructureMetrics {
  const ProgrammeStructureMetrics({
    required this.sourceWeekCount,
    required this.targetWeekCount,
    required this.weekCountDelta,
    required this.sourceTrainingDayCount,
    required this.targetTrainingDayCount,
    required this.trainingDayCountDelta,
    required this.sourceSlotCount,
    required this.targetSlotCount,
    required this.slotCountDelta,
    required this.sourceDistinctSessionRevisionCount,
    required this.targetDistinctSessionRevisionCount,
    required this.sessionRevisionCountDelta,
    required this.sourceDistinctExerciseCount,
    required this.targetDistinctExerciseCount,
    required this.exerciseCountDelta,
  });

  final int sourceWeekCount;
  final int targetWeekCount;
  final int weekCountDelta;
  final int sourceTrainingDayCount;
  final int targetTrainingDayCount;
  final int trainingDayCountDelta;
  final int sourceSlotCount;
  final int targetSlotCount;
  final int slotCountDelta;
  final int sourceDistinctSessionRevisionCount;
  final int targetDistinctSessionRevisionCount;
  final int sessionRevisionCountDelta;
  final int sourceDistinctExerciseCount;
  final int targetDistinctExerciseCount;
  final int exerciseCountDelta;
}

class ProgrammeVersionComparisonSnapshot {
  const ProgrammeVersionComparisonSnapshot({
    required this.versionId,
    required this.lineageId,
    required this.versionNumber,
    required this.lifecycleStatus,
    required this.programmeName,
    required this.metadata,
    required this.weeks,
    required this.days,
    required this.slots,
    required this.exercises,
    required this.exerciseEnrichmentAuthoritative,
    this.exerciseEnrichmentLimitation,
    this.sessionEnrichmentAuthoritative = true,
    this.sessionEnrichmentLimitation,
  });

  final String versionId;
  final String lineageId;
  final int versionNumber;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final String programmeName;
  final Map<String, String?> metadata;
  final List<ProgrammeWeekReference> weeks;
  final List<ProgrammeDayReference> days;
  final List<ProgrammeSlotSnapshot> slots;
  final List<ExerciseReferenceChange> exercises;
  final bool exerciseEnrichmentAuthoritative;
  final String? exerciseEnrichmentLimitation;
  final bool sessionEnrichmentAuthoritative;
  final String? sessionEnrichmentLimitation;
}

class ProgrammeVersionComparisonSummary {
  const ProgrammeVersionComparisonSummary({
    required this.identity,
    required this.metadataChanges,
    required this.weekChanges,
    required this.dayChanges,
    required this.slotChanges,
    required this.sessionRevisionChanges,
    required this.exerciseChanges,
    required this.exerciseSetChange,
    required this.structureMetrics,
    required this.classifications,
    required this.isIdentical,
    required this.hasStructuralChanges,
    required this.hasSessionChanges,
    required this.hasExerciseChanges,
    required this.warnings,
    required this.limitationNotes,
    required this.summaryMessages,
    required this.isPartial,
  });

  final ProgrammeVersionComparisonIdentity identity;
  final List<ProgrammeMetadataChange> metadataChanges;
  final List<ProgrammeWeekChange> weekChanges;
  final List<ProgrammeDayChange> dayChanges;
  final List<ProgrammeSlotChange> slotChanges;
  final List<SessionRevisionChange> sessionRevisionChanges;
  final List<ExerciseReferenceChange> exerciseChanges;
  final ExerciseSetChange exerciseSetChange;
  final ProgrammeStructureMetrics structureMetrics;
  final List<ProgrammeComparisonClassification> classifications;
  final bool isIdentical;
  final bool hasStructuralChanges;
  final bool hasSessionChanges;
  final bool hasExerciseChanges;
  final List<String> warnings;
  final List<String> limitationNotes;
  final List<String> summaryMessages;
  final bool isPartial;
}

class ProgrammeVersionComparisonLookupResult {
  const ProgrammeVersionComparisonLookupResult._({
    required this.status,
    this.summary,
    this.message,
  });

  const ProgrammeVersionComparisonLookupResult.success(
    ProgrammeVersionComparisonSummary summary,
  ) : this._(status: ProgrammeVersionComparisonStatus.success, summary: summary);

  const ProgrammeVersionComparisonLookupResult.sourceNotFound()
      : this._(status: ProgrammeVersionComparisonStatus.sourceNotFound);

  const ProgrammeVersionComparisonLookupResult.targetNotFound()
      : this._(status: ProgrammeVersionComparisonStatus.targetNotFound);

  const ProgrammeVersionComparisonLookupResult.partial(
    ProgrammeVersionComparisonSummary summary,
  ) : this._(
          status: ProgrammeVersionComparisonStatus.partial,
          summary: summary,
        );

  const ProgrammeVersionComparisonLookupResult.incompatibleLineage()
      : this._(status: ProgrammeVersionComparisonStatus.incompatibleLineage);

  const ProgrammeVersionComparisonLookupResult.lookupFailed(String message)
      : this._(
          status: ProgrammeVersionComparisonStatus.lookupFailed,
          message: message,
        );

  final ProgrammeVersionComparisonStatus status;
  final ProgrammeVersionComparisonSummary? summary;
  final String? message;

  bool get isSuccess =>
      status == ProgrammeVersionComparisonStatus.success ||
      status == ProgrammeVersionComparisonStatus.partial;
}

typedef StructuralSlotKey = ({int weekIndex, String dayKey, int slotIndex});
typedef StructuralDayKey = ({int weekIndex, String dayKey});
