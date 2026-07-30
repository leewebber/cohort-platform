import '../adaptation/services/adaptation_policy_gate.dart';

/// Schema constants for Authored Plan Package YAML (package schema v1).
///
/// This is distinct from [ProgrammeVersion] persistence and from the legacy
/// generative [PlanDefinition] pathway. See
/// `docs/architecture/Authored_Plan_Package_v1.md`.
class PlanPackageSchema {
  PlanPackageSchema._();

  /// Only this package schema version is accepted by the Sprint 1.1 compiler.
  static const int supportedPackageSchemaVersion = 1;

  /// Stable identifier pattern for package-local keys and comparison IDs.
  static final RegExp identityPattern = RegExp(r'^[A-Za-z][A-Za-z0-9._:-]*$');

  /// Programme lineage codes (e.g. `PROG-FIXTURE-01`).
  static final RegExp lineageCodePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9._:-]*$',
  );

  /// Day ordinal keys matching Programme Engine (`day_1`, `day_2`, …).
  static final RegExp dayKeyPattern = RegExp(r'^day_[1-9][0-9]*$');

  /// Field names forbidden anywhere in authored programme truth because they
  /// represent athlete execution / previous-performance evidence.
  static const forbiddenAuthoredTruthKeys = {
    'previous_performance',
    'previous_load',
    'last_load',
    'last_time',
    'execution_result',
    'athlete_result',
    'completed_load',
    'recorded_result',
    'performance_snapshot',
    'generated_workout',
    'coach_brain',
  };

  /// Adaptation kinds that may appear in authored permissions.
  ///
  /// Reuses [AdaptationPolicyGate.allowed] — never invents new coaching rules.
  static Set<AdaptationChangeKind> get permittedAdaptationKinds =>
      AdaptationPolicyGate.allowed;

  static String adaptationKindYamlValue(AdaptationChangeKind kind) {
    return switch (kind) {
      AdaptationChangeKind.reduceVolume => 'reduce_volume',
      AdaptationChangeKind.removeOptionalAccessories =>
        'remove_optional_accessories',
      AdaptationChangeKind.compressForTime => 'compress_for_time',
      AdaptationChangeKind.substituteApprovedEquipment =>
        'substitute_approved_equipment',
      AdaptationChangeKind.substituteApprovedExercise =>
        'substitute_approved_exercise',
      AdaptationChangeKind.convertApprovedModality =>
        'convert_approved_modality',
      _ => kind.name,
    };
  }

  static AdaptationChangeKind? adaptationKindFromYaml(String raw) {
    final normalised = raw.trim();
    for (final kind in AdaptationChangeKind.values) {
      if (adaptationKindYamlValue(kind) == normalised ||
          kind.name == normalised) {
        return kind;
      }
    }
    return null;
  }
}
