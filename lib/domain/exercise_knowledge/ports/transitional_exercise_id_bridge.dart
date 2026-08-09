import '../value_objects/exercise_id.dart';

/// Neutral future port for mapping transitional `cohort.exercise.*` ids to
/// canonical `EX-*` identities.
///
/// Phase 3.1C does **not** implement or wire this bridge. Transitional ids
/// remain non-authoritative and must not be treated as canonical keys.
abstract interface class TransitionalExerciseIdBridge {
  /// Returns a canonical id when an explicit curated mapping exists.
  ExerciseId? toCanonical(String transitionalKnowledgeId);
}
