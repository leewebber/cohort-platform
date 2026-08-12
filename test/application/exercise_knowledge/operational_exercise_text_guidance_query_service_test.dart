import 'dart:convert';

import 'package:cohort_platform/application/exercise_knowledge/operational_exercise_text_guidance.dart';
import 'package:cohort_platform/application/exercise_knowledge/operational_exercise_text_guidance_query_service.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/exercise_knowledge/exercise_knowledge_fixtures.dart';
import '../../domain/exercise_knowledge/exercise_movement_content_fixtures.dart';

void main() {
  group('OperationalExerciseTextGuidanceQueryService', () {
    test('projects published MovementStandard text only', () {
      final result = _query(
        movementStandards: [ExerciseMovementContentFixtures.movementStandard],
      );

      final guidance = _resolved(result);
      expect(guidance.movementStandards, hasLength(1));
      expect(guidance.coachingContents, isEmpty);
      expect(
        guidance.movementStandards.single.executionSequence,
        ExerciseMovementContentFixtures.movementStandard.executionSequence,
      );
    });

    test('projects published CoachingContent text only', () {
      final result = _query(
        coachingContents: [ExerciseMovementContentFixtures.coachingContent],
      );

      final guidance = _resolved(result);
      expect(guidance.movementStandards, isEmpty);
      expect(guidance.coachingContents, hasLength(1));
      expect(
        guidance.coachingContents.single.coachingCues,
        ExerciseMovementContentFixtures.coachingContent.coachingCues,
      );
    });

    test(
      'projects combined text deterministically by content id and version',
      () {
        final firstStandard = ExerciseMovementContentFixtures.movementStandard;
        final secondStandard = MovementStandard.fromJson({
          ...firstStandard.toJson(),
          'id': 'standard.aaa.fixture',
          'version': '2',
        });
        final repository = _repository(
          movementStandards: [firstStandard, secondStandard],
          coachingContents: [ExerciseMovementContentFixtures.coachingContent],
        );
        final service = OperationalExerciseTextGuidanceQueryService(
          repository: repository,
        );

        final first = _resolved(service.query(_exerciseId.value));
        final second = _resolved(service.query(_exerciseId.value));

        expect(first.movementStandards.map((item) => item.contentId), [
          'standard.aaa.fixture',
          firstStandard.id.value,
        ]);
        expect(first, second);
        expect(first.toCanonicalJson(), second.toCanonicalJson());
      },
    );

    test('output and all nested collections are immutable', () {
      final guidance = _resolved(
        _query(
          movementStandards: [ExerciseMovementContentFixtures.movementStandard],
          coachingContents: [ExerciseMovementContentFixtures.coachingContent],
        ),
      );

      expect(
        () => guidance.movementStandards.add(guidance.movementStandards.single),
        throwsUnsupportedError,
      );
      expect(
        () => guidance.movementStandards.single.executionSequence.add(
          'not allowed',
        ),
        throwsUnsupportedError,
      );
      expect(
        () => guidance.coachingContents.single.faultCorrections.add(
          guidance.coachingContents.single.faultCorrections.single,
        ),
        throwsUnsupportedError,
      );
    });

    test('VideoReference is never exposed by the projection', () {
      final result = _query(
        movementStandards: [ExerciseMovementContentFixtures.movementStandard],
        videoReferences: [ExerciseMovementContentFixtures.videoReference],
      );

      final encoded = _resolved(result).toCanonicalJson();
      expect(encoded, isNot(contains('video')));
      expect(encoded, isNot(contains('provider')));
      expect(encoded, isNot(contains('https://')));
    });

    test('draft text is excluded and yields typed unavailable result', () {
      final draft = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'lifecycle_status': 'draft',
        'reviewer': null,
        'reviewed_at': null,
        'published_at': null,
      });
      final result = _query(movementStandards: [draft]);

      expect(
        _rejected(result).code,
        OperationalExerciseTextGuidanceFailureCode
            .operationalTextGuidanceUnavailable,
      );
    });

    test('malformed published text fails as an invariant violation', () {
      final malformed = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'start_position': '',
      });
      final result = _query(movementStandards: [malformed]);

      expect(
        _rejected(result).code,
        OperationalExerciseTextGuidanceFailureCode
            .contentProjectionInvariantViolation,
      );
    });

    test('preserves caller-supplied canonical identity without inference', () {
      final guidance = _resolved(
        _query(
          movementStandards: [ExerciseMovementContentFixtures.movementStandard],
        ),
      );

      expect(guidance.exerciseId, _exerciseId.value);
      expect(guidance.canonicalName, _definition.canonicalName);
    });

    test('rejects malformed, transitional, alias, and name inputs', () {
      final service = OperationalExerciseTextGuidanceQueryService(
        repository: _repository(),
      );
      for (final raw in const [
        '',
        'EX-not-digits',
        'cohort.exercise.wall_ball',
        'Wall Ball',
      ]) {
        expect(
          _rejected(service.query(raw)).code,
          OperationalExerciseTextGuidanceFailureCode.invalidCanonicalExerciseId,
          reason: raw,
        );
      }
    });

    test('rejects a missing, draft, or retired canonical definition', () {
      final missing = OperationalExerciseTextGuidanceQueryService(
        repository: InMemoryExerciseKnowledgeRepository(),
      ).query(_exerciseId.value);
      expect(
        _rejected(missing).code,
        OperationalExerciseTextGuidanceFailureCode
            .missingPublishedExerciseDefinition,
      );

      for (final lifecycle in const [
        ExerciseLifecycleStatus.draft,
        ExerciseLifecycleStatus.retired,
      ]) {
        final definition = ExerciseDefinition.fromJson({
          ..._definition.toJson(),
          'lifecycle_status': lifecycle.wireValue,
        });
        final result = OperationalExerciseTextGuidanceQueryService(
          repository: InMemoryExerciseKnowledgeRepository(
            initial: ExerciseCatalogueSnapshot(
              catalogueVersion: 'test',
              definitions: [definition],
              relationships: const [],
              comparisonProtocols: const [],
            ),
          ),
        ).query(_exerciseId.value);
        expect(
          _rejected(result).code,
          OperationalExerciseTextGuidanceFailureCode
              .missingPublishedExerciseDefinition,
        );
      }
    });

    test('fails closed on repository identity mismatch', () {
      final repository = _MismatchedKnowledgeRepository(
        initial: ExerciseCatalogueSnapshot(
          catalogueVersion: 'test',
          definitions: [_definition],
          relationships: const [],
          comparisonProtocols: const [],
        ),
      );

      final result = OperationalExerciseTextGuidanceQueryService(
        repository: repository,
      ).query(_exerciseId.value);

      expect(
        _rejected(result).code,
        OperationalExerciseTextGuidanceFailureCode
            .contentProjectionInvariantViolation,
      );
    });

    test('does not mutate source aggregates or acquire other authorities', () {
      final repository = _repository(
        movementStandards: [ExerciseMovementContentFixtures.movementStandard],
        coachingContents: [ExerciseMovementContentFixtures.coachingContent],
      );
      final before = jsonEncode(repository.authoringSnapshot().toJson());

      final result = OperationalExerciseTextGuidanceQueryService(
        repository: repository,
      ).query(_exerciseId.value);
      final encoded = _resolved(result).toCanonicalJson();

      expect(jsonEncode(repository.authoringSnapshot().toJson()), before);
      for (final forbidden in const [
        'sets',
        'reps',
        'load',
        'athlete_actuals',
        'completion_evidence',
        'adaptation',
        'comparison',
        'substitution',
        'plan_package',
      ]) {
        expect(encoded, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

final _definition =
    ExerciseMovementContentFixtures.definitionWithPublishedContentRefs();
final _exerciseId = ExerciseKnowledgeFixtures.hyroxWallBalls.id;

OperationalExerciseTextGuidanceQueryResult _query({
  List<MovementStandard> movementStandards = const [],
  List<CoachingContent> coachingContents = const [],
  List<VideoReference> videoReferences = const [],
}) {
  return OperationalExerciseTextGuidanceQueryService(
    repository: _repository(
      movementStandards: movementStandards,
      coachingContents: coachingContents,
      videoReferences: videoReferences,
    ),
  ).query(_exerciseId.value);
}

InMemoryExerciseKnowledgeRepository _repository({
  List<MovementStandard> movementStandards = const [],
  List<CoachingContent> coachingContents = const [],
  List<VideoReference> videoReferences = const [],
}) {
  return InMemoryExerciseKnowledgeRepository(
    initial: ExerciseCatalogueSnapshot(
      catalogueVersion: 'projection-unit-test',
      definitions: [_definition],
      relationships: const [],
      comparisonProtocols: const [],
      movementStandards: movementStandards,
      coachingContents: coachingContents,
      videoReferences: videoReferences,
    ),
  );
}

OperationalExerciseTextGuidance _resolved(
  OperationalExerciseTextGuidanceQueryResult result,
) {
  expect(result, isA<OperationalExerciseTextGuidanceResolved>());
  return (result as OperationalExerciseTextGuidanceResolved).guidance;
}

OperationalExerciseTextGuidanceRejected _rejected(
  OperationalExerciseTextGuidanceQueryResult result,
) {
  expect(result, isA<OperationalExerciseTextGuidanceRejected>());
  return result as OperationalExerciseTextGuidanceRejected;
}

class _MismatchedKnowledgeRepository
    extends InMemoryExerciseKnowledgeRepository {
  _MismatchedKnowledgeRepository({required super.initial});

  @override
  ExerciseMovementKnowledge operationalMovementKnowledge(ExerciseId id) {
    return ExerciseMovementKnowledge(
      exerciseId: ExerciseId.parse('EX-999'),
      movementStandards: const [],
      coachingContents: const [],
      playableVideos: const [],
    );
  }
}
