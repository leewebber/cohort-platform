import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'exercise_definition.dart';

/// Result of looking up a definition by canonical [ExerciseId].
///
/// Distinguishes missing, draft, published, and retired without display-name
/// fallback. Aliases are never returned as identity.
class ExerciseDefinitionLookup {
  const ExerciseDefinitionLookup._({
    required this.id,
    this.definition,
  });

  factory ExerciseDefinitionLookup.missing(ExerciseId id) =>
      ExerciseDefinitionLookup._(id: id);

  factory ExerciseDefinitionLookup.found(ExerciseDefinition definition) =>
      ExerciseDefinitionLookup._(
        id: definition.id,
        definition: definition,
      );

  final ExerciseId id;
  final ExerciseDefinition? definition;

  bool get isMissing => definition == null;

  ExerciseLifecycleStatus? get lifecycleStatus => definition?.lifecycleStatus;

  /// Published only — draft is never operational.
  bool get isOperational =>
      definition?.lifecycleStatus.isRuntimeAuthoritative ?? false;

  /// Published or retired — draft is excluded.
  bool get isHistoricallyResolvable =>
      definition?.lifecycleStatus.remainsResolvable ?? false;

  bool get isDraft =>
      definition?.lifecycleStatus == ExerciseLifecycleStatus.draft;

  bool get isRetired =>
      definition?.lifecycleStatus == ExerciseLifecycleStatus.retired;
}

/// Visibility filter for repository reads.
enum ExerciseKnowledgeVisibility {
  /// Published definitions/relationships only (operational).
  operational,

  /// Published + retired (historical resolution).
  historical,

  /// Draft + published + retired (authoring / founder tools).
  authoring,
}

extension ExerciseKnowledgeVisibilityMatch on ExerciseKnowledgeVisibility {
  bool includes(ExerciseLifecycleStatus status) {
    return switch (this) {
      ExerciseKnowledgeVisibility.operational =>
        status == ExerciseLifecycleStatus.published,
      ExerciseKnowledgeVisibility.historical => status.remainsResolvable,
      ExerciseKnowledgeVisibility.authoring => true,
    };
  }
}
