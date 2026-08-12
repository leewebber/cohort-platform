import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'knowledge_content_common.dart';
import 'knowledge_reference.dart';

/// Observable, reusable movement criteria for one canonical exercise variant.
///
/// Does not contain programme dosage, athlete actuals, selection, comparison,
/// scheduling, or adaptation decisions.
class MovementStandard implements ExerciseKnowledgeContentRecord {
  MovementStandard({
    required this.id,
    required this.exerciseId,
    required this.version,
    required this.lifecycleStatus,
    required this.authorId,
    required this.language,
    required this.title,
    required this.applicabilityKey,
    required this.startPosition,
    required List<String> executionSequence,
    required List<String> completionCriteria,
    required this.provenance,
    required this.authoredAt,
    this.reviewerId,
    List<String> invalidRepetitionCriteria = const [],
    List<KnowledgeReferenceId> safetyBoundaryRefs = const [],
    List<String> safetyNotes = const [],
    this.reviewedAt,
    this.publishedAt,
    this.replacementId,
  }) : executionSequence = List.unmodifiable(executionSequence),
       completionCriteria = List.unmodifiable(completionCriteria),
       invalidRepetitionCriteria = List.unmodifiable(invalidRepetitionCriteria),
       safetyBoundaryRefs = List.unmodifiable(safetyBoundaryRefs),
       safetyNotes = List.unmodifiable(safetyNotes);

  @override
  final KnowledgeReferenceId id;
  @override
  final ExerciseId exerciseId;
  @override
  final String version;
  @override
  final ExerciseLifecycleStatus lifecycleStatus;
  @override
  final KnowledgeActorId authorId;
  @override
  final KnowledgeActorId? reviewerId;
  final String language;
  final String title;
  final String applicabilityKey;
  final String startPosition;
  final List<String> executionSequence;
  final List<String> completionCriteria;
  final List<String> invalidRepetitionCriteria;
  final List<KnowledgeReferenceId> safetyBoundaryRefs;
  final List<String> safetyNotes;
  @override
  final KnowledgeProvenance provenance;
  @override
  final DateTime authoredAt;
  @override
  final DateTime? reviewedAt;
  @override
  final DateTime? publishedAt;
  @override
  final KnowledgeReferenceId? replacementId;

  @override
  ExerciseKnowledgeContentKind get contentKind =>
      ExerciseKnowledgeContentKind.movementStandard;

  MovementStandard publish({
    required KnowledgeActorId reviewerId,
    required DateTime publishedAt,
  }) => MovementStandard(
    id: id,
    exerciseId: exerciseId,
    version: version,
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: authorId,
    reviewerId: reviewerId,
    language: language,
    title: title,
    applicabilityKey: applicabilityKey,
    startPosition: startPosition,
    executionSequence: executionSequence,
    completionCriteria: completionCriteria,
    invalidRepetitionCriteria: invalidRepetitionCriteria,
    safetyBoundaryRefs: safetyBoundaryRefs,
    safetyNotes: safetyNotes,
    provenance: provenance,
    authoredAt: authoredAt,
    reviewedAt: reviewedAt ?? publishedAt,
    publishedAt: this.publishedAt ?? publishedAt,
    replacementId: replacementId,
  );

  @override
  Map<String, Object?> toJson() => {
    ...KnowledgeContentCodec.commonJson(
      id: id,
      exerciseId: exerciseId,
      version: version,
      lifecycleStatus: lifecycleStatus,
      authorId: authorId,
      reviewerId: reviewerId,
      provenance: provenance,
      authoredAt: authoredAt,
      reviewedAt: reviewedAt,
      publishedAt: publishedAt,
      replacementId: replacementId,
    ),
    'language': language,
    'title': title,
    'applicability_key': applicabilityKey,
    'start_position': startPosition,
    'execution_sequence': executionSequence,
    'completion_criteria': completionCriteria,
    'invalid_repetition_criteria': invalidRepetitionCriteria,
    'safety_boundary_refs': safetyBoundaryRefs
        .map((ref) => ref.value)
        .toList(growable: false),
    'safety_notes': safetyNotes,
  };

  factory MovementStandard.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, _keys, 'movement_standard');
    KnowledgeContentCodec.requireSchemaVersion(json, 'movement_standard');
    return MovementStandard(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      exerciseId: ExerciseId.parse(json['exercise_id']?.toString() ?? ''),
      version: json['version']?.toString() ?? '',
      lifecycleStatus: KnowledgeContentCodec.lifecycle(
        json['lifecycle_status'],
        'movement_standard.lifecycle_status',
      ),
      authorId: KnowledgeContentCodec.actor(
        json['author'],
        'movement_standard.author',
      ),
      reviewerId: KnowledgeContentCodec.optionalActor(
        json['reviewer'],
        'movement_standard.reviewer',
      ),
      language: json['language']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      applicabilityKey: json['applicability_key']?.toString() ?? '',
      startPosition: json['start_position']?.toString() ?? '',
      executionSequence: KnowledgeContentCodec.strings(
        json['execution_sequence'],
        'movement_standard.execution_sequence',
      ),
      completionCriteria: KnowledgeContentCodec.strings(
        json['completion_criteria'],
        'movement_standard.completion_criteria',
      ),
      invalidRepetitionCriteria: KnowledgeContentCodec.strings(
        json['invalid_repetition_criteria'],
        'movement_standard.invalid_repetition_criteria',
      ),
      safetyBoundaryRefs: KnowledgeContentCodec.referenceIds(
        json['safety_boundary_refs'],
        'movement_standard.safety_boundary_refs',
      ),
      safetyNotes: KnowledgeContentCodec.strings(
        json['safety_notes'],
        'movement_standard.safety_notes',
      ),
      provenance: KnowledgeContentCodec.provenance(
        json['provenance'],
        'movement_standard.provenance',
      ),
      authoredAt: KnowledgeContentCodec.requireDate(
        json['authored_at'],
        'movement_standard.authored_at',
      ),
      reviewedAt: KnowledgeContentCodec.optionalDate(
        json['reviewed_at'],
        'movement_standard.reviewed_at',
      ),
      publishedAt: KnowledgeContentCodec.optionalDate(
        json['published_at'],
        'movement_standard.published_at',
      ),
      replacementId: json['replacement_id'] == null
          ? null
          : KnowledgeReferenceId.parse(json['replacement_id'].toString()),
    );
  }

  static const _keys = {
    'schema_version',
    'id',
    'exercise_id',
    'version',
    'lifecycle_status',
    'author',
    'reviewer',
    'language',
    'title',
    'applicability_key',
    'start_position',
    'execution_sequence',
    'completion_criteria',
    'invalid_repetition_criteria',
    'safety_boundary_refs',
    'safety_notes',
    'provenance',
    'authored_at',
    'reviewed_at',
    'published_at',
    'replacement_id',
  };
}
