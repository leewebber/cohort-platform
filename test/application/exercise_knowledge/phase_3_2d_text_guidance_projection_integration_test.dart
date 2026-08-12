import 'dart:convert';

import 'package:cohort_platform/application/exercise_knowledge/operational_exercise_text_guidance_query_service.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3.2D text-guidance application projection', () {
    test('projects all eight founder-approved records locally', () {
      final repository = _publishedPilotRepository();
      final service = OperationalExerciseTextGuidanceQueryService(
        repository: repository,
      );
      final before = jsonEncode(repository.authoringSnapshot().toJson());

      final serialized = <String>[];
      for (final entry
          in FounderApprovedMovementKnowledgePhase32d.canonicalNames.entries) {
        final first = service.query(entry.key);
        final second = service.query(entry.key);
        expect(first, isA<OperationalExerciseTextGuidanceResolved>());
        expect(second, isA<OperationalExerciseTextGuidanceResolved>());

        final firstGuidance =
            (first as OperationalExerciseTextGuidanceResolved).guidance;
        final secondGuidance =
            (second as OperationalExerciseTextGuidanceResolved).guidance;
        expect(firstGuidance.exerciseId, entry.key);
        expect(firstGuidance.canonicalName, entry.value);
        expect(firstGuidance.movementStandards, hasLength(1));
        expect(firstGuidance.coachingContents, hasLength(1));
        expect(firstGuidance, secondGuidance);
        expect(
          firstGuidance.toCanonicalJson(),
          secondGuidance.toCanonicalJson(),
        );
        serialized.add(firstGuidance.toCanonicalJson());
      }

      expect(serialized, hasLength(8));
      expect(serialized.toSet(), hasLength(8));
      expect(jsonEncode(repository.authoringSnapshot().toJson()), before);
      expect(serialized.join(), isNot(contains('video')));
      expect(serialized.join(), isNot(contains('provider')));
      expect(serialized.join(), isNot(contains('http')));
    });

    test(
      'caller-supplied canonical authority fails closed before publication',
      () {
        final source = _sourceSnapshot();
        final missing = source.copyWith(
          definitions: source.definitions
              .where((definition) => definition.id.value != 'EX-012')
              .toList(growable: false),
        );
        expect(
          () => FounderApprovedMovementKnowledgePhase32d.draftSnapshot(missing),
          throwsStateError,
        );

        final renamed = source.copyWith(
          definitions: source.definitions
              .map((definition) {
                if (definition.id.value != 'EX-012') return definition;
                return ExerciseDefinition.fromJson({
                  ...definition.toJson(),
                  'canonical_name': 'Not the approved canonical name',
                });
              })
              .toList(growable: false),
        );
        expect(
          () => FounderApprovedMovementKnowledgePhase32d.draftSnapshot(renamed),
          throwsStateError,
        );
      },
    );
  });
}

InMemoryExerciseKnowledgeRepository _publishedPilotRepository() {
  final repository = InMemoryExerciseKnowledgeRepository(
    initial: _sourceSnapshot(),
  );
  final publication = FounderApprovedMovementKnowledgePhase32d.publish(
    repository: repository,
    actingOwner: ExerciseKnowledgePublicationService.founderOwner,
    reviewerId: KnowledgeActorId.parse('cohort.projection_test_reviewer'),
    publishedAt: DateTime.utc(2026, 8, 12, 12),
  );
  expect(publication.isAccepted, isTrue, reason: publication.issues.toString());
  return repository;
}

ExerciseCatalogueSnapshot _sourceSnapshot() {
  return ExerciseCatalogueSnapshot(
    catalogueVersion: 'projection-integration-source',
    definitions: FounderApprovedMovementKnowledgePhase32d.canonicalNames.entries
        .map(
          (entry) => ExerciseDefinition(
            id: ExerciseId.parse(entry.key),
            canonicalName: entry.value,
            modality: ExerciseModality.other,
            lifecycleStatus: ExerciseLifecycleStatus.published,
            version: '1',
            owner: ExerciseKnowledgePublicationService.founderOwner,
            publishedAt: DateTime.utc(2026, 8, 10),
          ),
        )
        .toList(growable: false),
    relationships: const [],
    comparisonProtocols: const [],
  );
}
