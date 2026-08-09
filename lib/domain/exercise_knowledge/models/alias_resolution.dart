import '../value_objects/exercise_id.dart';

/// Alias resolution outcome. Aliases are never canonical identity.
sealed class AliasResolutionResult {
  const AliasResolutionResult();
}

/// Exactly one canonical `EX-*` match.
class AliasResolved extends AliasResolutionResult {
  const AliasResolved(this.canonicalId);

  final ExerciseId canonicalId;
}

/// Multiple canonical matches — fail closed for authoring/validation.
class AliasAmbiguous extends AliasResolutionResult {
  const AliasAmbiguous(this.canonicalIds);

  /// Deterministically ordered candidate ids.
  final List<ExerciseId> canonicalIds;
}

/// No match for the search/authoring alias.
class AliasNotFound extends AliasResolutionResult {
  const AliasNotFound();
}
