import 'dart:convert';

import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reviewer = KnowledgeActorId.parse('cohort.founder_review');
  final publishedAt = DateTime.utc(2026, 8, 12, 12);

  group('Phase 3.2D founder-approved pilot', () {
    test('contains exactly eight text-only canonical aggregates', () {
      expect(FounderApprovedMovementKnowledgePhase32d.canonicalNames, const {
        'EX-012': 'Push Up',
        'EX-021': 'Plank',
        'EX-025': 'Walking Lunge',
        'EX-049': 'Row Erg',
        'EX-050': 'Ski Erg',
        'EX-052': 'Wall Ball',
        'EX-057': 'Kettlebell Swing',
        'EX-130': 'Burpee Broad Jump',
      });
      expect(
        FounderApprovedMovementKnowledgePhase32d.movementStandards,
        hasLength(8),
      );
      expect(
        FounderApprovedMovementKnowledgePhase32d.coachingContents,
        hasLength(8),
      );
      expect(
        FounderApprovedMovementKnowledgePhase32d.movementStandards
            .map((record) => record.exerciseId)
            .toSet(),
        FounderApprovedMovementKnowledgePhase32d.exerciseIds,
      );
      expect(
        FounderApprovedMovementKnowledgePhase32d.coachingContents
            .map((record) => record.exerciseId)
            .toSet(),
        FounderApprovedMovementKnowledgePhase32d.exerciseIds,
      );
    });

    test('fails closed on missing or renamed canonical identities', () {
      final source = _sourceSnapshot();
      final missing = source.copyWith(
        definitions: source.definitions
            .where((definition) => definition.id.value != 'EX-012')
            .toList(),
      );
      expect(
        () => FounderApprovedMovementKnowledgePhase32d.draftSnapshot(missing),
        throwsStateError,
      );

      final renamed = source.copyWith(
        definitions: source.definitions.map((definition) {
          if (definition.id.value != 'EX-012') return definition;
          return ExerciseDefinition.fromJson({
            ...definition.toJson(),
            'canonical_name': 'Renamed Push Up',
          });
        }).toList(),
      );
      expect(
        () => FounderApprovedMovementKnowledgePhase32d.draftSnapshot(renamed),
        throwsStateError,
      );
    });

    test('all records satisfy movement-content validation', () {
      final draft = FounderApprovedMovementKnowledgePhase32d.draftSnapshot(
        _sourceSnapshot(),
      );
      final published = _publish(draft);
      expect(published.isAccepted, isTrue, reason: published.issues.toString());

      final snapshot = published.snapshot!;
      final issues = const ExerciseMovementContentValidator().validate(
        definitions: snapshot.definitions,
        movementStandards: snapshot.movementStandards,
        coachingContents: snapshot.coachingContents,
        videoReferences: snapshot.videoReferences,
      );
      expect(issues, isEmpty);
    });

    test('mandatory variant and wording amendments are present', () {
      final plank = _standard('EX-021');
      expect(plank.applicabilityKey, 'forearm_plank');
      final plankText = _encoded(plank);
      expect(plankText, contains('both forearms'));
      expect(plankText, contains('approximately beneath the shoulders'));
      expect(plankText, contains('feet'));
      expect(plankText, contains('approximately straight alignment'));
      expect(plankText, isNot(contains('high plank')));
      expect(plankText, isNot(contains('straight-arm')));
      expect(
        plank.invalidRepetitionCriteria,
        everyElement(
          anyOf(
            contains('support'),
            contains('alignment'),
            contains('contact'),
          ),
        ),
      );

      final lungeText = [
        _encoded(_standard('EX-025')),
        _encoded(_coaching('EX-025')),
      ].join(' ');
      expect(lungeText, isNot(contains('middle toe')));
      expect(lungeText, isNot(contains('directly over')));
      expect(
        lungeText,
        contains(
          'stable, controlled relationship between the hip, knee and foot',
        ),
      );

      final ski = _standard('EX-050');
      final skiText = _encoded(ski);
      expect(ski.executionSequence.first, contains('arms and trunk'));
      expect(skiText, contains('trunk forwards'));
      expect(skiText, contains('knees flex'));
      expect(skiText, contains('Finish the pull with the arms'));
      expect(skiText, contains('returns upwards'));
      expect(skiText, isNot(contains('hip and knee extension')));
      expect(skiText, isNot(contains('hips and knees extend')));

      final swing = _standard('EX-057');
      expect(swing.applicabilityKey, 'russian_kettlebell_swing_chest_height');
      final swingText = [
        swing.title,
        swing.applicabilityKey,
        swing.startPosition,
        ...swing.executionSequence,
        ...swing.completionCriteria,
        ...swing.invalidRepetitionCriteria,
        ...swing.safetyNotes,
      ].join(' ');
      expect(swingText, contains('approximately chest height'));
      expect(swingText, contains('hip-driven swing'));
      expect(swingText, contains('intentionally completed overhead'));
      expect(swingText, isNot(contains('American')));
      expect(swingText, isNot(contains('competition')));

      final burpeeJump = _standard('EX-130');
      final boundary = _encoded(burpeeJump);
      expect(boundary, contains('chest or front torso contacts the floor'));
      expect(boundary, contains('return to standing movement'));
      expect(boundary, contains('take-off uses both feet'));
      expect(boundary, contains('landing uses both feet'));
      expect(boundary, contains('controlled before continuation'));
      expect(boundary, isNot(contains('jump distance')));
    });

    test('standards keep preferences in coaching and avoid judging rules', () {
      final rowStandard = _encoded(_standard('EX-049'));
      final rowCoaching = _encoded(_coaching('EX-049'));
      expect(rowStandard, isNot(contains('Legs, body, arms')));
      expect(rowCoaching, contains('Legs, body, arms'));

      final wallStandard = _encoded(_standard('EX-052'));
      expect(wallStandard, isNot(contains('target height')));
      expect(wallStandard, isNot(contains('full squat')));

      final allContent = _allContentText();
      expect(allContent.toLowerCase(), isNot(contains('hyrox')));
      expect(allContent.toLowerCase(), isNot(contains('no-rep')));
      expect(allContent.toLowerCase(), isNot(contains('race judging')));
    });

    test('legacy treatment excludes programme-specific and unresolved cues', () {
      final allContent = _allContentText();
      for (final excluded in const [
        'Run relaxed, breathe calmly, keep the effort conversational.',
        'Run comfortably hard, controlled breathing, hold the pace without sprinting.',
        'Fast but relaxed, smooth acceleration, never strain.',
        'Shorten stride, scan terrain, keep effort not pace as the target.',
        'Walk tall, breathe through the nose if possible, keep it easy.',
        'Easy load, tall posture, smooth walking pace.',
        'Move smoothly, step or jump back, keep breathing controlled, find a repeatable rhythm.',
        'Load hips, jump explosively, land softly and reset.',
      ]) {
        expect(allContent, isNot(contains(excluded)), reason: excluded);
      }

      expect(
        _coaching('EX-012').coachingCues,
        contains(
          'Body straight, elbows controlled, chest to floor, lock out fully.',
        ),
      );
      expect(
        _coaching('EX-052').coachingCues,
        contains(
          'Squat under control, stand and throw smoothly, receive the ball securely.',
        ),
      );
      expect(
        _coaching('EX-052').coachingCues,
        isNot(
          contains(
            'Full squat, stand hard, throw smoothly, catch into next rep.',
          ),
        ),
      );
    });

    test('founder boundary publishes all eight as operational text-only', () {
      final repository = InMemoryExerciseKnowledgeRepository(
        initial: _sourceSnapshot(),
      );
      final result = FounderApprovedMovementKnowledgePhase32d.publish(
        repository: repository,
        actingOwner: ExerciseKnowledgePublicationService.founderOwner,
        reviewerId: reviewer,
        publishedAt: publishedAt,
      );
      expect(result.isAccepted, isTrue, reason: result.issues.toString());
      expect(repository.operationalSnapshot().videoReferences, isEmpty);

      for (final id in FounderApprovedMovementKnowledgePhase32d.exerciseIds) {
        final knowledge = repository.operationalMovementKnowledge(id);
        expect(knowledge.movementStandards, hasLength(1), reason: id.value);
        expect(knowledge.coachingContents, hasLength(1), reason: id.value);
        expect(knowledge.playableVideos, isEmpty, reason: id.value);
        expect(knowledge.hasTextGuidance, isTrue, reason: id.value);
      }
    });

    test('publication requires founder authority', () {
      final repository = InMemoryExerciseKnowledgeRepository(
        initial: _sourceSnapshot(),
      );
      final denied = FounderApprovedMovementKnowledgePhase32d.publish(
        repository: repository,
        actingOwner: 'coach',
        reviewerId: reviewer,
        publishedAt: publishedAt,
      );
      expect(denied.isAccepted, isFalse);
      expect(
        denied.issues.any(
          (issue) => issue.code == 'founder_authority_required',
        ),
        isTrue,
      );
      expect(repository.operationalSnapshot().movementStandards, isEmpty);
    });

    test('published content cannot mutate without a new version', () {
      final repository = InMemoryExerciseKnowledgeRepository(
        initial: _sourceSnapshot(),
      );
      final first = FounderApprovedMovementKnowledgePhase32d.publish(
        repository: repository,
        actingOwner: ExerciseKnowledgePublicationService.founderOwner,
        reviewerId: reviewer,
        publishedAt: publishedAt,
      );
      expect(first.isAccepted, isTrue, reason: first.issues.toString());

      final current = repository.authoringSnapshot();
      final draft = FounderApprovedMovementKnowledgePhase32d.draftSnapshot(
        current,
      );
      final changed = MovementStandard.fromJson({
        ...draft.movementStandards.first.toJson(),
        'title': 'Changed without a version bump',
      });
      final attempted = const ExerciseKnowledgePublicationService()
          .publishCatalogue(
            repository: repository,
            draftSnapshot: draft.copyWith(
              movementStandards: [changed, ...draft.movementStandards.skip(1)],
            ),
            actingOwner: ExerciseKnowledgePublicationService.founderOwner,
            reviewerId: reviewer,
            publishedAt: publishedAt.add(const Duration(hours: 1)),
          );
      expect(attempted.isAccepted, isFalse);
      expect(
        attempted.issues.any(
          (issue) => issue.code == 'silent_published_content_mutation',
        ),
        isTrue,
      );
    });

    test('serialization and round trips are deterministic', () {
      final first = FounderApprovedMovementKnowledgePhase32d.draftSnapshot(
        _sourceSnapshot(),
      );
      final reversed = ExerciseCatalogueSnapshot(
        catalogueVersion: 'reversed-input',
        definitions: _pilotDefinitions().reversed.toList(),
        relationships: const [],
        comparisonProtocols: const [],
      );
      final second = FounderApprovedMovementKnowledgePhase32d.draftSnapshot(
        reversed,
      );
      final firstJson = first.toJson()
        ..['catalogue_version'] = 'stable'
        ..remove('label');
      final secondJson = second.toJson()
        ..['catalogue_version'] = 'stable'
        ..remove('label');
      expect(jsonEncode(firstJson), jsonEncode(secondJson));

      final decoded = ExerciseCatalogueSnapshot.fromJson(first.toJson());
      expect(jsonEncode(decoded.toJson()), jsonEncode(first.toJson()));
    });

    test('authority fields and production media cannot enter the pilot', () {
      final snapshot = FounderApprovedMovementKnowledgePhase32d.draftSnapshot(
        _sourceSnapshot(),
      );
      expect(snapshot.videoReferences, isEmpty);
      final encoded = jsonEncode(snapshot.toJson());
      expect(encoded, isNot(contains('http://')));
      expect(encoded, isNot(contains('https://')));

      for (final field in const [
        'sets',
        'reps',
        'load',
        'duration_target',
        'athlete_actuals',
        'adaptation_acceptance',
        'automatic_exercise_selection',
        'comparison_grants',
      ]) {
        expect(
          () => MovementStandard.fromJson({
            ...FounderApprovedMovementKnowledgePhase32d.movementStandards.first
                .toJson(),
            field: 'forbidden',
          }),
          throwsFormatException,
          reason: field,
        );
      }
    });
  });
}

ExerciseKnowledgePublicationResult _publish(ExerciseCatalogueSnapshot draft) {
  return const ExerciseKnowledgePublicationService().publishCatalogue(
    repository: InMemoryExerciseKnowledgeRepository(),
    draftSnapshot: draft,
    actingOwner: ExerciseKnowledgePublicationService.founderOwner,
    reviewerId: KnowledgeActorId.parse('cohort.founder_review'),
    publishedAt: DateTime.utc(2026, 8, 12, 12),
  );
}

MovementStandard _standard(String exerciseId) =>
    FounderApprovedMovementKnowledgePhase32d.movementStandards.singleWhere(
      (record) => record.exerciseId.value == exerciseId,
    );

CoachingContent _coaching(String exerciseId) =>
    FounderApprovedMovementKnowledgePhase32d.coachingContents.singleWhere(
      (record) => record.exerciseId.value == exerciseId,
    );

String _encoded(ExerciseKnowledgeContentRecord record) =>
    jsonEncode(record.toJson());

String _allContentText() => jsonEncode({
  'standards': FounderApprovedMovementKnowledgePhase32d.movementStandards
      .map((record) => record.toJson())
      .toList(),
  'coaching': FounderApprovedMovementKnowledgePhase32d.coachingContents
      .map((record) => record.toJson())
      .toList(),
});

ExerciseCatalogueSnapshot _sourceSnapshot() {
  return ExerciseCatalogueSnapshot(
    catalogueVersion: 'authoritative-catalogue',
    definitions: _pilotDefinitions(),
    relationships: const [],
    comparisonProtocols: const [],
  );
}

List<ExerciseDefinition> _pilotDefinitions() {
  return FounderApprovedMovementKnowledgePhase32d.canonicalNames.entries
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
      .toList(growable: false);
}
