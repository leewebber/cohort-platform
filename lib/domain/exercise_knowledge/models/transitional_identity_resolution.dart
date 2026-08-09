import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import 'exercise_identity_mapping.dart';

/// Structured outcome of transitional → canonical identity resolution.
sealed class TransitionalIdentityResolution {
  const TransitionalIdentityResolution();

  /// Canonical id when resolution succeeded operationally or historically.
  ExerciseId? get canonicalIdOrNull;
}

/// One published (or historical) mapping resolved to a single `EX-*`.
class TransitionalIdentityResolved extends TransitionalIdentityResolution {
  const TransitionalIdentityResolved({
    required this.transitionalId,
    required this.canonicalId,
    required this.mapping,
  });

  final TransitionalExerciseId transitionalId;
  final ExerciseId canonicalId;
  final ExerciseIdentityMapping mapping;

  @override
  ExerciseId? get canonicalIdOrNull => canonicalId;
}

/// No published/historical mapping exists for a well-formed transitional id.
class TransitionalIdentityUnmapped extends TransitionalIdentityResolution {
  const TransitionalIdentityUnmapped(this.transitionalId);

  final TransitionalExerciseId transitionalId;

  @override
  ExerciseId? get canonicalIdOrNull => null;
}

/// Input is not a valid transitional `cohort.exercise.*` id.
class TransitionalIdentityInvalid extends TransitionalIdentityResolution {
  const TransitionalIdentityInvalid(this.raw, {this.message});

  final String raw;
  final String? message;

  @override
  ExerciseId? get canonicalIdOrNull => null;
}

/// Conflicting active mappings or ambiguous authored targets.
class TransitionalIdentityConflict extends TransitionalIdentityResolution {
  const TransitionalIdentityConflict({
    required this.transitionalId,
    required this.canonicalCandidates,
    this.message,
  });

  final TransitionalExerciseId transitionalId;
  final List<ExerciseId> canonicalCandidates;
  final String? message;

  @override
  ExerciseId? get canonicalIdOrNull => null;
}
