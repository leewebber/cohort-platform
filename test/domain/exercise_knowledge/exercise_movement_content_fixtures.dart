import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';

import 'exercise_knowledge_fixtures.dart';

/// Synthetic contract fixtures only. Wording, providers, and URLs are not
/// production content.
class ExerciseMovementContentFixtures {
  ExerciseMovementContentFixtures._();

  static final author = KnowledgeActorId.parse('fixture.author');
  static final reviewer = KnowledgeActorId.parse('fixture.reviewer');
  static final authoredAt = DateTime.utc(2026, 1, 1);
  static final publishedAt = DateTime.utc(2026, 1, 2);
  static const provenance = KnowledgeProvenance(
    sourceType: 'synthetic_contract_fixture',
    sourceReference: 'phase_3_2b_tests',
  );

  static final movementStandard = MovementStandard(
    id: KnowledgeReferenceId.parse('standard.hyrox.wall_ball_target'),
    exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
    version: '1',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: author,
    reviewerId: reviewer,
    language: 'en',
    title: 'Synthetic observable movement standard',
    applicabilityKey: 'fixture_variant',
    startPosition: 'Synthetic observable start position.',
    executionSequence: const [
      'Synthetic observable execution step one.',
      'Synthetic observable execution step two.',
    ],
    completionCriteria: const ['Synthetic observable completion criterion.'],
    invalidRepetitionCriteria: const [
      'Synthetic observable invalid-repetition criterion.',
    ],
    safetyNotes: const ['Synthetic non-clinical safety boundary.'],
    provenance: provenance,
    authoredAt: authoredAt,
    reviewedAt: publishedAt,
    publishedAt: publishedAt,
  );

  static final coachingContent = CoachingContent(
    id: KnowledgeReferenceId.parse('coaching.fixture.wall_ball'),
    exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
    version: '1',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: author,
    reviewerId: reviewer,
    language: 'en',
    audience: 'fixture_audience',
    setupGuidance: const ['Synthetic reusable setup guidance.'],
    executionInstructions: const ['Synthetic reusable execution instruction.'],
    coachingCues: const ['Synthetic reusable coaching cue.'],
    faultCorrections: const [
      CoachingFaultCorrection(
        fault: 'Synthetic observable fault.',
        correction: 'Synthetic reusable correction.',
      ),
    ],
    breathingGuidance: const ['Synthetic reusable breathing guidance.'],
    safetyNotes: const ['Synthetic non-clinical coaching safety note.'],
    regressionProgressionExplanation:
        'Synthetic explanatory text only; it grants no relationship authority.',
    provenance: provenance,
    authoredAt: authoredAt,
    reviewedAt: publishedAt,
    publishedAt: publishedAt,
  );

  static final videoReference = VideoReference(
    id: KnowledgeReferenceId.parse('video.fixture.wall_ball'),
    exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
    version: '1',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: author,
    reviewerId: reviewer,
    purpose: 'synthetic_demonstration',
    providerKey: VideoProviderKey.parse('fixture_provider'),
    providerAssetId: 'synthetic-asset',
    canonicalUri: 'https://media.invalid/synthetic-fixture',
    language: 'en',
    durationSeconds: 30,
    availability: VideoAvailabilityState.available,
    lastVerifiedAt: publishedAt,
    captionsState: AccessibilityAvailabilityState.notProvided,
    transcriptState: AccessibilityAvailabilityState.notProvided,
    audioDescriptionState: AccessibilityAvailabilityState.notProvided,
    provenance: provenance,
    rightsBasis: 'synthetic_fixture_only',
    ownerOrLicensor: 'synthetic_fixture_owner',
    attributionRequirements: 'Synthetic fixture attribution.',
    authoredAt: authoredAt,
    reviewedAt: publishedAt,
    publishedAt: publishedAt,
  );

  static final unavailableVideo = VideoReference(
    id: KnowledgeReferenceId.parse('video.fixture.unavailable'),
    exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
    version: '1',
    lifecycleStatus: ExerciseLifecycleStatus.published,
    authorId: author,
    reviewerId: reviewer,
    purpose: 'synthetic_unavailable_demonstration',
    providerKey: VideoProviderKey.parse('fixture_provider'),
    language: 'en',
    availability: VideoAvailabilityState.unavailable,
    captionsState: AccessibilityAvailabilityState.unavailable,
    transcriptState: AccessibilityAvailabilityState.unavailable,
    audioDescriptionState: AccessibilityAvailabilityState.unavailable,
    provenance: provenance,
    authoredAt: authoredAt,
    reviewedAt: publishedAt,
    publishedAt: publishedAt,
  );

  static final draftVideo = VideoReference(
    id: KnowledgeReferenceId.parse('video.fixture.draft'),
    exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
    version: '1',
    lifecycleStatus: ExerciseLifecycleStatus.draft,
    authorId: author,
    purpose: '',
    language: '',
    availability: VideoAvailabilityState.unavailable,
    captionsState: AccessibilityAvailabilityState.notProvided,
    transcriptState: AccessibilityAvailabilityState.notProvided,
    audioDescriptionState: AccessibilityAvailabilityState.notProvided,
    provenance: provenance,
    authoredAt: authoredAt,
  );

  static ExerciseDefinition definitionWithPublishedContentRefs() {
    final source = ExerciseKnowledgeFixtures.hyroxWallBalls;
    return ExerciseDefinition(
      id: source.id,
      canonicalName: source.canonicalName,
      aliases: source.aliases,
      modality: source.modality,
      familyId: source.familyId,
      movementPatterns: source.movementPatterns,
      laterality: source.laterality,
      technicalComplexity: source.technicalComplexity,
      impactLevel: source.impactLevel,
      validPrescriptionDimensions: source.validPrescriptionDimensions,
      validCompletedPerformanceDimensions:
          source.validCompletedPerformanceDimensions,
      equipment: source.equipment,
      environments: source.environments,
      movementStandardRefs: source.movementStandardRefs,
      coachingContentRefs: [CoachingContentRef(id: coachingContent.id)],
      mediaRefs: [
        MediaReference(id: videoReference.id, kind: MediaReferenceKind.video),
      ],
      sportStandardRefs: source.sportStandardRefs,
      lifecycleStatus: source.lifecycleStatus,
      version: source.version,
      publishedAt: source.publishedAt,
    );
  }

  static ExerciseCatalogueSnapshot publishedTextOnlySnapshot() {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: 'fixture-text-only-1',
      definitions: [
        ...ExerciseKnowledgeFixtures.allDefinitions.where(
          (definition) =>
              definition.id != ExerciseKnowledgeFixtures.hyroxWallBalls.id,
        ),
        ExerciseKnowledgeFixtures.hyroxWallBalls,
      ],
      relationships: ExerciseKnowledgeFixtures.validRelationships,
      comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
      movementStandards: [movementStandard],
    );
  }

  static ExerciseCatalogueSnapshot publishedVideoSnapshot({
    List<VideoReference>? videoReferences,
  }) {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: 'fixture-video-1',
      definitions: [
        ...ExerciseKnowledgeFixtures.allDefinitions.where(
          (definition) =>
              definition.id != ExerciseKnowledgeFixtures.hyroxWallBalls.id,
        ),
        definitionWithPublishedContentRefs(),
      ],
      relationships: ExerciseKnowledgeFixtures.validRelationships,
      comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
      movementStandards: [movementStandard],
      coachingContents: [coachingContent],
      videoReferences: videoReferences ?? [videoReference],
    );
  }
}
