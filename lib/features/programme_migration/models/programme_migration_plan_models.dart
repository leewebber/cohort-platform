import '../../../models/programme_vocabulary.dart';
import '../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../programme_impact/models/programme_version_impact_models.dart';

enum ProgrammeMigrationPlannerStatus {
  success,
  partial,
  sourceNotFound,
  targetNotFound,
  incompatibleLineage,
  comparisonUnavailable,
  impactUnavailable,
  assignmentUnavailable,
  lookupFailed,
}

enum MigrationClassification {
  alreadyCompleted,
  safeImmediate,
  safeAfterCurrentSession,
  safeAfterCurrentWeek,
  manualReview,
  cannotDetermine,
  unsupported,
}

class ProgrammeMigrationPosition {
  const ProgrammeMigrationPosition({
    required this.weekIndex,
    required this.dayKey,
    required this.dayIndex,
    required this.slotIndex,
    this.slotId,
    this.protocolId,
    this.sessionName,
  });

  final int weekIndex;
  final String dayKey;
  final int dayIndex;
  final int slotIndex;
  final String? slotId;
  final String? protocolId;
  final String? sessionName;

  String get displayLabel =>
      'Week $weekIndex · $dayKey · Slot $slotIndex';
}

class ProgrammeMigrationIdentity {
  const ProgrammeMigrationIdentity({
    required this.programmeLineageId,
    required this.programmeName,
    required this.sourceProgrammeVersionId,
    required this.sourceVersionNumber,
    required this.targetProgrammeVersionId,
    required this.targetVersionNumber,
    required this.comparisonSummary,
    required this.sourceImpactSummary,
  });

  final String programmeLineageId;
  final String programmeName;
  final String sourceProgrammeVersionId;
  final int sourceVersionNumber;
  final String targetProgrammeVersionId;
  final int targetVersionNumber;
  final ProgrammeVersionComparisonSummary comparisonSummary;
  final ProgrammeVersionImpactSummary sourceImpactSummary;
}

class AssignmentMigrationPlan {
  const AssignmentMigrationPlan({
    required this.assignmentId,
    required this.assignmentStatus,
    required this.currentWeek,
    required this.currentDayKey,
    required this.currentSessionOrder,
    required this.completionPercent,
    required this.currentProgrammePosition,
    required this.completedRequiredSlotCount,
    required this.totalRequiredSlotCount,
    required this.hasStarted,
    required this.migrationClassification,
    required this.recommendation,
    required this.reasoning,
    required this.warnings,
  });

  final String assignmentId;
  final ProgrammeAssignmentStatus assignmentStatus;
  final int currentWeek;
  final String currentDayKey;
  final int currentSessionOrder;
  final int? completionPercent;
  final ProgrammeMigrationPosition? currentProgrammePosition;
  final int completedRequiredSlotCount;
  final int totalRequiredSlotCount;
  final bool hasStarted;
  final MigrationClassification migrationClassification;
  final String recommendation;
  final String reasoning;
  final List<String> warnings;
}

class MigrationSummary {
  const MigrationSummary({
    required this.totalAssignments,
    required this.safeImmediate,
    required this.safeAfterCurrentWeek,
    required this.safeAfterCurrentSession,
    required this.manualReview,
    required this.completed,
    required this.cancelled,
    required this.unknown,
  });

  final int totalAssignments;
  final int safeImmediate;
  final int safeAfterCurrentWeek;
  final int safeAfterCurrentSession;
  final int manualReview;
  final int completed;
  final int cancelled;
  final int unknown;
}

class ProgrammeMigrationPlan {
  const ProgrammeMigrationPlan({
    required this.identity,
    required this.assignmentPlans,
    required this.summary,
    required this.warnings,
    required this.limitationNotes,
    required this.isPartial,
  });

  final ProgrammeMigrationIdentity identity;
  final List<AssignmentMigrationPlan> assignmentPlans;
  final MigrationSummary summary;
  final List<String> warnings;
  final List<String> limitationNotes;
  final bool isPartial;
}

class ProgrammeMigrationPlannerLookupResult {
  const ProgrammeMigrationPlannerLookupResult._({
    required this.status,
    this.plan,
    this.message,
  });

  const ProgrammeMigrationPlannerLookupResult.success(ProgrammeMigrationPlan plan)
      : this._(status: ProgrammeMigrationPlannerStatus.success, plan: plan);

  const ProgrammeMigrationPlannerLookupResult.partial(ProgrammeMigrationPlan plan)
      : this._(status: ProgrammeMigrationPlannerStatus.partial, plan: plan);

  const ProgrammeMigrationPlannerLookupResult.sourceNotFound()
      : this._(status: ProgrammeMigrationPlannerStatus.sourceNotFound);

  const ProgrammeMigrationPlannerLookupResult.targetNotFound()
      : this._(status: ProgrammeMigrationPlannerStatus.targetNotFound);

  const ProgrammeMigrationPlannerLookupResult.incompatibleLineage()
      : this._(status: ProgrammeMigrationPlannerStatus.incompatibleLineage);

  const ProgrammeMigrationPlannerLookupResult.comparisonUnavailable(String message)
      : this._(
          status: ProgrammeMigrationPlannerStatus.comparisonUnavailable,
          message: message,
        );

  const ProgrammeMigrationPlannerLookupResult.impactUnavailable(String message)
      : this._(
          status: ProgrammeMigrationPlannerStatus.impactUnavailable,
          message: message,
        );

  const ProgrammeMigrationPlannerLookupResult.assignmentUnavailable(String message)
      : this._(
          status: ProgrammeMigrationPlannerStatus.assignmentUnavailable,
          message: message,
        );

  const ProgrammeMigrationPlannerLookupResult.lookupFailed(String message)
      : this._(
          status: ProgrammeMigrationPlannerStatus.lookupFailed,
          message: message,
        );

  final ProgrammeMigrationPlannerStatus status;
  final ProgrammeMigrationPlan? plan;
  final String? message;

  bool get isSuccess =>
      status == ProgrammeMigrationPlannerStatus.success ||
      status == ProgrammeMigrationPlannerStatus.partial;
}

/// Derived change scope for one assignment cursor against a comparison summary.
class ProgrammeMigrationChangeScope {
  const ProgrammeMigrationChangeScope({
    required this.isIdentical,
    required this.affectsCurrentSession,
    required this.currentSessionRemoved,
    required this.currentSessionRevisionOnly,
    required this.affectsCurrentWeek,
    required this.affectsPastOrCurrentPosition,
    required this.affectsFutureOnly,
    required this.affectsFutureWeeksOnly,
    required this.hasStructuralChanges,
  });

  final bool isIdentical;
  final bool affectsCurrentSession;
  final bool currentSessionRemoved;
  final bool currentSessionRevisionOnly;
  final bool affectsCurrentWeek;
  final bool affectsPastOrCurrentPosition;
  final bool affectsFutureOnly;
  final bool affectsFutureWeeksOnly;
  final bool hasStructuralChanges;
}

/// Authoritative progress facts for one assignment on the source version.
class AssignmentProgressSnapshot {
  const AssignmentProgressSnapshot({
    required this.assignmentId,
    required this.isAuthoritative,
    required this.hasStarted,
    required this.completedRequiredSlotCount,
    required this.totalRequiredSlotCount,
    required this.completionPercent,
    required this.currentPosition,
    this.limitationNote,
  });

  final String assignmentId;
  final bool isAuthoritative;
  final bool hasStarted;
  final int completedRequiredSlotCount;
  final int totalRequiredSlotCount;
  final int? completionPercent;
  final ProgrammeMigrationPosition? currentPosition;
  final String? limitationNote;
}
