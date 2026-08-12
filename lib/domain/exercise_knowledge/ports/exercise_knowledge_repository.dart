import '../models/alias_resolution.dart';
import '../models/coaching_content.dart';
import '../models/comparison_protocol.dart';
import '../models/exercise_catalogue_snapshot.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_definition_lookup.dart';
import '../models/exercise_movement_knowledge.dart';
import '../models/exercise_relationship.dart';
import '../models/movement_standard.dart';
import '../models/video_reference.dart';
import '../value_objects/exercise_id.dart';

/// Domain port for canonical Exercise Knowledge retrieval and draft storage.
///
/// Does not own programme prescription, athlete evidence, substitution
/// selection, or adaptation application. Not a second exercise authority —
/// consumers of the live catalogue / knowledge ontology are not migrated here.
///
/// Production persistence is deferred until an authorised schema sprint.
abstract interface class ExerciseKnowledgeRepository {
  /// Lookup by canonical [ExerciseId] only — never by display name.
  ExerciseDefinitionLookup getDefinition(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.historical,
  });

  /// Deterministic multi-get ordered by canonical id.
  List<ExerciseDefinitionLookup> getDefinitions(
    Iterable<ExerciseId> ids, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.historical,
  });

  /// All definitions visible under [visibility], ordered by canonical id.
  List<ExerciseDefinition> listDefinitions({
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  /// Resolve a search/authoring alias to a canonical `EX-*` id.
  ///
  /// Never returns the alias string as identity. Does not migrate
  /// `cohort.exercise.*` transitional ids (deferred bridge).
  AliasResolutionResult resolveAlias(String alias);

  /// Outgoing relationships from [id], direction preserved, no ranking.
  List<ExerciseRelationship> outgoingRelationships(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  /// Incoming relationships to [id], direction preserved, no ranking.
  List<ExerciseRelationship> incomingRelationships(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  /// Retrieve comparison protocol by stable id; optional version pin.
  ComparisonProtocol? getComparisonProtocol(
    String protocolId, {
    String? version,
  });

  List<MovementStandard> movementStandardsForExercise(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  List<CoachingContent> coachingContentsForExercise(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  List<VideoReference> videoReferencesForExercise(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  });

  /// Operational text plus playable media. Missing/unavailable media never
  /// removes otherwise valid textual guidance.
  ExerciseMovementKnowledge operationalMovementKnowledge(ExerciseId id);

  /// Full authoring snapshot (all lifecycles) with deterministic ordering.
  ExerciseCatalogueSnapshot authoringSnapshot({String? catalogueVersion});

  /// Published-only operational snapshot.
  ExerciseCatalogueSnapshot operationalSnapshot({String? catalogueVersion});

  /// Replace working catalogue contents (in-memory / test boundary).
  void replaceCatalogue(ExerciseCatalogueSnapshot snapshot);

  /// Upsert a single definition into the working set (authoring).
  void upsertDefinition(ExerciseDefinition definition);

  /// Upsert a relationship into the working set (authoring).
  void upsertRelationship(ExerciseRelationship relationship);

  /// Upsert a comparison protocol into the working set (authoring).
  void upsertComparisonProtocol(ComparisonProtocol protocol);

  void upsertMovementStandard(MovementStandard standard);

  void upsertCoachingContent(CoachingContent content);

  void upsertVideoReference(VideoReference reference);
}
