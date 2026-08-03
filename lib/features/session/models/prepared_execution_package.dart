import '../../adaptation/models/accepted_adaptation_decision.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../workout_player/models/workout_session_brief.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import 'session_execution_plan.dart';

/// Athlete-facing prepared execution for today.
///
/// Retains an immutable [programmedSessionKey] linking to the coach-authored
/// programmed session. Accepted adaptations are derived decisions — they do
/// not mutate the programmed source.
class PreparedExecutionPackage {
  const PreparedExecutionPackage({
    required this.programmedSessionKey,
    required this.plan,
    required this.brief,
    required this.preparedAt,
    this.planId,
    this.planVersion,
    this.assignmentId,
    this.programmeVersionId,
    this.packageContentHash,
    this.dayKey,
    this.slotOrder,
    this.protocolId,
    this.acceptedAdaptation,
    this.coachBrainPlan,
  });

  final ProgrammedSessionKey programmedSessionKey;
  final SessionExecutionPlan plan;
  final WorkoutSessionBrief brief;
  final DateTime preparedAt;
  final String? planId;
  final String? planVersion;

  /// Plan Library assignment id, or materialised `programme_assignments.id`.
  final String? assignmentId;

  /// Exact programme version id for authored Plan Package preparation.
  final String? programmeVersionId;

  /// Materialised package content hash provenance.
  final String? packageContentHash;
  final String? dayKey;
  final int? slotOrder;
  final String? protocolId;
  final AcceptedAdaptationDecision? acceptedAdaptation;
  final CoachBrainWorkoutPlan? coachBrainPlan;

  bool get hasAcceptedAdaptation => acceptedAdaptation != null;

  bool get isProgrammeBacked =>
      programmeVersionId != null &&
      programmeVersionId!.trim().isNotEmpty &&
      packageContentHash != null &&
      packageContentHash!.trim().isNotEmpty;

  /// Attaches an accepted decision and optionally replaces the active executable
  /// plan. Programmed identity and package provenance are preserved.
  PreparedExecutionPackage withAcceptedAdaptation(
    AcceptedAdaptationDecision decision, {
    SessionExecutionPlan? executablePlan,
    WorkoutSessionBrief? executableBrief,
  }) {
    return PreparedExecutionPackage(
      programmedSessionKey: programmedSessionKey,
      plan: executablePlan ?? plan,
      brief: executableBrief ?? brief,
      preparedAt: preparedAt,
      planId: planId,
      planVersion: planVersion,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      packageContentHash: packageContentHash,
      dayKey: dayKey,
      slotOrder: slotOrder,
      protocolId: protocolId,
      acceptedAdaptation: decision,
      coachBrainPlan: coachBrainPlan,
    );
  }

  PreparedExecutionPackage withoutAdaptation() {
    return PreparedExecutionPackage(
      programmedSessionKey: programmedSessionKey,
      plan: plan,
      brief: brief,
      preparedAt: preparedAt,
      planId: planId,
      planVersion: planVersion,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      packageContentHash: packageContentHash,
      dayKey: dayKey,
      slotOrder: slotOrder,
      protocolId: protocolId,
      coachBrainPlan: coachBrainPlan,
    );
  }

  /// Sprint 1.6D: restore authored executable plan and clear active acceptance.
  ///
  /// Programmed identity and Plan Package provenance are preserved. Does not
  /// invent a plan — callers must supply the reconstructed authored plan.
  PreparedExecutionPackage withRevertedToOriginal({
    required SessionExecutionPlan originalPlan,
    WorkoutSessionBrief? originalBrief,
  }) {
    if (!hasAcceptedAdaptation) {
      throw StateError(
        'Cannot revert: prepared package has no accepted adaptation.',
      );
    }
    if (!originalPlan.hasExecutableBlocks) {
      throw ArgumentError.value(
        originalPlan,
        'originalPlan',
        'Reconstructed authored plan must contain executable blocks.',
      );
    }
    return PreparedExecutionPackage(
      programmedSessionKey: programmedSessionKey,
      plan: originalPlan,
      brief: originalBrief ?? brief,
      preparedAt: preparedAt,
      planId: planId,
      planVersion: planVersion,
      assignmentId: assignmentId,
      programmeVersionId: programmeVersionId,
      packageContentHash: packageContentHash,
      dayKey: dayKey,
      slotOrder: slotOrder,
      protocolId: protocolId,
      acceptedAdaptation: null,
      coachBrainPlan: coachBrainPlan,
    );
  }
}

/// Domain guard: previous performance must never become a load prescription.
class LoadSelectionPolicy {
  const LoadSelectionPolicy();

  /// Always null — Cohort never computes a next / forced load.
  double? suggestedNextLoadKg({
    double? previousLoadKg,
    double? programmedLoadKg,
  }) => null;

  bool get allowsAutomaticProgression => false;
  bool get allowsForcedLoadFromPrevious => false;
}
