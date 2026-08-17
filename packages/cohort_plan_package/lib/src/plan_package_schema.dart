import 'adaptation_policy_gate.dart';

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

  /// Canonical persisted UUID shape accepted for Session Lineage authority.
  ///
  /// This is deliberately narrower than [identityPattern]: package-local keys
  /// retain their existing letter-leading rule, while `session_lineage_id`
  /// may also carry the exact lowercase UUID stored by `session_lineages.id`.
  static final RegExp canonicalSessionLineageUuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static final RegExp _uuidLikePattern = RegExp(r'^\{?[0-9A-Fa-f-]+\}?$');

  /// Whether [value] is an existing symbolic Session Lineage identity or an
  /// exact canonical lowercase persisted UUID.
  ///
  /// UUID-like values are fail-closed: uppercase, compact, braced, partial,
  /// or otherwise malformed UUID representations are not treated as legacy
  /// symbolic identities.
  static bool isValidSessionLineageIdentity(String value) {
    if (canonicalSessionLineageUuidPattern.hasMatch(value)) return true;

    final looksUuidLike =
        _uuidLikePattern.hasMatch(value) &&
        (value.length >= 24 || value.contains('{') || value.contains('}')) &&
        (value.contains('-') || value.length == 32);
    if (looksUuidLike) return false;

    return identityPattern.hasMatch(value);
  }

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
