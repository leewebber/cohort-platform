import '../contracts/adaptation_constraint.dart';
import '../vocabulary/impact_level.dart';
import '../vocabulary/movement_pattern.dart';
import '../vocabulary/training_environment.dart';

/// Immutable athlete / situational constraints for read-only adaptation evaluation.
///
/// Not bound to UI widgets or Supabase rows. Unknown [AdaptationConstraintKind.unknown]
/// entries in [extensions] are ignored safely during evaluation.
class AdaptationConstraintContext {
  const AdaptationConstraintContext({
    this.availableDurationMin,
    this.availableEquipment = const {},
    this.trainingEnvironment,
    this.recoveryStateLabel,
    this.restrictedMovementPatterns = const {},
    this.restrictedBodyRegions = const {},
    this.excludedExerciseIds = const {},
    this.maxPermittedImpact,
    this.extensions = const {},
  });

  factory AdaptationConstraintContext.empty() {
    return const AdaptationConstraintContext();
  }

  final int? availableDurationMin;
  final Set<String> availableEquipment;
  final TrainingEnvironment? trainingEnvironment;
  final String? recoveryStateLabel;
  final Set<MovementPattern> restrictedMovementPatterns;
  final Set<String> restrictedBodyRegions;
  final Set<String> excludedExerciseIds;
  final ImpactLevel? maxPermittedImpact;

  /// Optional future constraints without rewriting the evaluator core.
  final Set<AdaptationConstraint> extensions;

  bool get hasTimeConstraint => availableDurationMin != null;
  bool get hasEquipmentConstraint => availableEquipment.isNotEmpty;
  bool get hasEnvironmentConstraint => trainingEnvironment != null;
  bool get hasMovementRestrictions =>
      restrictedMovementPatterns.isNotEmpty ||
      restrictedBodyRegions.isNotEmpty ||
      excludedExerciseIds.isNotEmpty;
  bool get hasImpactConstraint => maxPermittedImpact != null;
  bool get isEmpty =>
      !hasTimeConstraint &&
      !hasEquipmentConstraint &&
      !hasEnvironmentConstraint &&
      !hasMovementRestrictions &&
      !hasImpactConstraint &&
      (recoveryStateLabel == null || recoveryStateLabel!.trim().isEmpty) &&
      extensions.isEmpty;

  /// Rejects non-positive durations. Returns the same instance when valid.
  AdaptationConstraintContext validated() {
    final minutes = availableDurationMin;
    if (minutes != null && minutes <= 0) {
      throw ArgumentError.value(
        minutes,
        'availableDurationMin',
        'Must be a positive whole number of minutes when set.',
      );
    }
    return this;
  }

  AdaptationConstraintContext copyWith({
    int? availableDurationMin,
    Set<String>? availableEquipment,
    TrainingEnvironment? trainingEnvironment,
    String? recoveryStateLabel,
    Set<MovementPattern>? restrictedMovementPatterns,
    Set<String>? restrictedBodyRegions,
    Set<String>? excludedExerciseIds,
    ImpactLevel? maxPermittedImpact,
    Set<AdaptationConstraint>? extensions,
    bool clearAvailableDuration = false,
    bool clearTrainingEnvironment = false,
    bool clearMaxImpact = false,
  }) {
    return AdaptationConstraintContext(
      availableDurationMin: clearAvailableDuration
          ? null
          : (availableDurationMin ?? this.availableDurationMin),
      availableEquipment: availableEquipment ?? this.availableEquipment,
      trainingEnvironment: clearTrainingEnvironment
          ? null
          : (trainingEnvironment ?? this.trainingEnvironment),
      recoveryStateLabel: recoveryStateLabel ?? this.recoveryStateLabel,
      restrictedMovementPatterns:
          restrictedMovementPatterns ?? this.restrictedMovementPatterns,
      restrictedBodyRegions:
          restrictedBodyRegions ?? this.restrictedBodyRegions,
      excludedExerciseIds: excludedExerciseIds ?? this.excludedExerciseIds,
      maxPermittedImpact: clearMaxImpact
          ? null
          : (maxPermittedImpact ?? this.maxPermittedImpact),
      extensions: extensions ?? this.extensions,
    );
  }
}
