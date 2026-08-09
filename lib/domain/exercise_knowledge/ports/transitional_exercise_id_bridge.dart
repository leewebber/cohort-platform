import '../models/exercise_identity_mapping.dart';
import '../models/transitional_identity_resolution.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';

/// One-way bridge: transitional `cohort.exercise.*` → canonical `EX-*`.
///
/// Does not resolve search aliases or display names. Does not manufacture
/// canonical ids. Does not grant substitution, comparability, or shared
/// performance history. No database access.
abstract interface class TransitionalExerciseIdBridge {
  /// Operational resolution: published mapping only; null when unmapped /
  /// invalid / conflicting / draft / retired.
  ExerciseId? toCanonical(String transitionalKnowledgeId);

  /// Structured resolution with explicit outcomes.
  TransitionalIdentityResolution resolve(
    String transitionalKnowledgeId, {
    bool includeHistorical = false,
  });

  /// Typed resolve using [TransitionalExerciseId].
  TransitionalIdentityResolution resolveTyped(
    TransitionalExerciseId transitionalId, {
    bool includeHistorical = false,
  });

  /// All mappings visible for authoring/audit, deterministic order.
  List<ExerciseIdentityMapping> listMappings({bool includeHistorical = true});

  /// Replace working mapping set (in-memory / test boundary).
  void replaceMappings(Iterable<ExerciseIdentityMapping> mappings);

  /// Upsert a single mapping record (authoring).
  void upsertMapping(ExerciseIdentityMapping mapping);

  /// Validate mappings against a known set of canonical exercise ids.
  List<ExerciseKnowledgeValidationIssue> validate({
    required Set<String> knownCanonicalIds,
  });
}
