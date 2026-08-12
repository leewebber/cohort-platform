import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'knowledge_content_common.dart';
import 'knowledge_reference.dart';

class CoachingFaultCorrection {
  const CoachingFaultCorrection({
    required this.fault,
    required this.correction,
  });

  final String fault;
  final String correction;

  Map<String, Object?> toJson() => {'fault': fault, 'correction': correction};

  factory CoachingFaultCorrection.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, const {
      'fault',
      'correction',
    }, 'fault_correction');
    return CoachingFaultCorrection(
      fault: json['fault']?.toString() ?? '',
      correction: json['correction']?.toString() ?? '',
    );
  }
}

/// Reusable global coaching guidance for a canonical exercise.
///
/// Programme-specific coaching emphasis remains on programme/session
/// prescription and may override display emphasis without mutating this record.
class CoachingContent implements ExerciseKnowledgeContentRecord {
  CoachingContent({
    required this.id,
    required this.exerciseId,
    required this.version,
    required this.lifecycleStatus,
    required this.authorId,
    required this.language,
    required this.audience,
    required List<String> setupGuidance,
    required List<String> executionInstructions,
    required List<String> coachingCues,
    required List<CoachingFaultCorrection> faultCorrections,
    required List<String> breathingGuidance,
    required List<String> safetyNotes,
    required this.regressionProgressionExplanation,
    required this.provenance,
    required this.authoredAt,
    this.reviewerId,
    this.reviewedAt,
    this.publishedAt,
    this.replacementId,
  }) : setupGuidance = List.unmodifiable(setupGuidance),
       executionInstructions = List.unmodifiable(executionInstructions),
       coachingCues = List.unmodifiable(coachingCues),
       faultCorrections = List.unmodifiable(faultCorrections),
       breathingGuidance = List.unmodifiable(breathingGuidance),
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
  final String audience;
  final List<String> setupGuidance;
  final List<String> executionInstructions;
  final List<String> coachingCues;
  final List<CoachingFaultCorrection> faultCorrections;
  final List<String> breathingGuidance;
  final List<String> safetyNotes;

  /// Explanatory only. Structural progression/regression authority remains on
  /// typed [ExerciseRelationship] records.
  final String regressionProgressionExplanation;
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
      ExerciseKnowledgeContentKind.coachingContent;

  /// Coaching content never grants substitution, selection, or comparability.
  bool get grantsSubstitutionAuthority => false;
  bool get grantsExerciseSelection => false;
  bool get grantsComparability => false;

  CoachingContent publish({
    required KnowledgeActorId reviewerId,
    required DateTime publishedAt,
  }) => CoachingContent(
    id: id,
    exerciseId: exerciseId,
    version: version,
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: authorId,
    reviewerId: reviewerId,
    language: language,
    audience: audience,
    setupGuidance: setupGuidance,
    executionInstructions: executionInstructions,
    coachingCues: coachingCues,
    faultCorrections: faultCorrections,
    breathingGuidance: breathingGuidance,
    safetyNotes: safetyNotes,
    regressionProgressionExplanation: regressionProgressionExplanation,
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
    'audience': audience,
    'setup_guidance': setupGuidance,
    'execution_instructions': executionInstructions,
    'coaching_cues': coachingCues,
    'fault_corrections': faultCorrections
        .map((item) => item.toJson())
        .toList(growable: false),
    'breathing_guidance': breathingGuidance,
    'safety_notes': safetyNotes,
    'regression_progression_explanation': regressionProgressionExplanation,
  };

  factory CoachingContent.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, _keys, 'coaching_content');
    KnowledgeContentCodec.requireSchemaVersion(json, 'coaching_content');
    return CoachingContent(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      exerciseId: ExerciseId.parse(json['exercise_id']?.toString() ?? ''),
      version: json['version']?.toString() ?? '',
      lifecycleStatus: KnowledgeContentCodec.lifecycle(
        json['lifecycle_status'],
        'coaching_content.lifecycle_status',
      ),
      authorId: KnowledgeContentCodec.actor(
        json['author'],
        'coaching_content.author',
      ),
      reviewerId: KnowledgeContentCodec.optionalActor(
        json['reviewer'],
        'coaching_content.reviewer',
      ),
      language: json['language']?.toString() ?? '',
      audience: json['audience']?.toString() ?? '',
      setupGuidance: KnowledgeContentCodec.strings(
        json['setup_guidance'],
        'coaching_content.setup_guidance',
      ),
      executionInstructions: KnowledgeContentCodec.strings(
        json['execution_instructions'],
        'coaching_content.execution_instructions',
      ),
      coachingCues: KnowledgeContentCodec.strings(
        json['coaching_cues'],
        'coaching_content.coaching_cues',
      ),
      faultCorrections: KnowledgeContentCodec.maps(
        json['fault_corrections'],
        'coaching_content.fault_corrections',
      ).map(CoachingFaultCorrection.fromJson).toList(growable: false),
      breathingGuidance: KnowledgeContentCodec.strings(
        json['breathing_guidance'],
        'coaching_content.breathing_guidance',
      ),
      safetyNotes: KnowledgeContentCodec.strings(
        json['safety_notes'],
        'coaching_content.safety_notes',
      ),
      regressionProgressionExplanation:
          json['regression_progression_explanation']?.toString() ?? '',
      provenance: KnowledgeContentCodec.provenance(
        json['provenance'],
        'coaching_content.provenance',
      ),
      authoredAt: KnowledgeContentCodec.requireDate(
        json['authored_at'],
        'coaching_content.authored_at',
      ),
      reviewedAt: KnowledgeContentCodec.optionalDate(
        json['reviewed_at'],
        'coaching_content.reviewed_at',
      ),
      publishedAt: KnowledgeContentCodec.optionalDate(
        json['published_at'],
        'coaching_content.published_at',
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
    'audience',
    'setup_guidance',
    'execution_instructions',
    'coaching_cues',
    'fault_corrections',
    'breathing_guidance',
    'safety_notes',
    'regression_progression_explanation',
    'provenance',
    'authored_at',
    'reviewed_at',
    'published_at',
    'replacement_id',
  };
}
