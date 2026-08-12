import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_knowledge_fixtures.dart';
import 'exercise_movement_content_fixtures.dart';

void main() {
  const validator = ExerciseMovementContentValidator();
  const loader = ExerciseCatalogueSnapshotLoader();

  group('movement-content serialization', () {
    test('every contract round-trips deterministically', () {
      final records = <ExerciseKnowledgeContentRecord>[
        ExerciseMovementContentFixtures.movementStandard,
        ExerciseMovementContentFixtures.coachingContent,
        ExerciseMovementContentFixtures.videoReference,
      ];
      for (final record in records) {
        final decoded = switch (record) {
          MovementStandard value => MovementStandard.fromJson(value.toJson()),
          CoachingContent value => CoachingContent.fromJson(value.toJson()),
          VideoReference value => VideoReference.fromJson(value.toJson()),
          _ => throw StateError('Unsupported fixture type.'),
        };
        expect(decoded.toJson(), record.toJson());
        expect(jsonEncode(decoded.toJson()), jsonEncode(record.toJson()));
      }
    });

    test('aggregate order is stable regardless of insertion order', () {
      final standard = ExerciseMovementContentFixtures.movementStandard;
      final later = MovementStandard.fromJson({
        ...standard.toJson(),
        'id': 'standard.fixture.z',
      });
      final first = ExerciseCatalogueSnapshot(
        catalogueVersion: 'ordering',
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        relationships: const [],
        comparisonProtocols: const [],
        movementStandards: [later, standard],
      );
      final second = ExerciseCatalogueSnapshot(
        catalogueVersion: 'ordering',
        definitions: ExerciseKnowledgeFixtures.allDefinitions.reversed.toList(),
        relationships: const [],
        comparisonProtocols: const [],
        movementStandards: [standard, later],
      );
      expect(jsonEncode(first.toJson()), jsonEncode(second.toJson()));
    });

    test('unsupported content schema versions fail closed', () {
      final json = {
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'schema_version': 99,
      };
      expect(() => MovementStandard.fromJson(json), throwsFormatException);
    });

    test('video accessibility states must be explicit', () {
      final json = Map<String, Object?>.from(
        ExerciseMovementContentFixtures.videoReference.toJson(),
      )..remove('captions_state');
      expect(() => VideoReference.fromJson(json), throwsFormatException);
    });
  });

  group('canonical identity and aggregate references', () {
    test('valid published text and video aggregate loads', () {
      final result = loader.load(
        ExerciseMovementContentFixtures.publishedVideoSnapshot().toJson(),
      );
      expect(result.isValid, isTrue, reason: result.issues.toString());
    });

    test(
      'aliases and transitional ids are rejected as canonical attachments',
      () {
        final json = ExerciseMovementContentFixtures.movementStandard.toJson();
        expect(
          () => MovementStandard.fromJson({
            ...json,
            'exercise_id': 'cohort.exercise.fixture',
          }),
          throwsFormatException,
        );
        expect(
          () => MovementStandard.fromJson({
            ...json,
            'exercise_id': 'fixture movement',
          }),
          throwsFormatException,
        );
      },
    );

    test(
      'unknown canonical exercise attachments fail aggregate validation',
      () {
        final unknown = MovementStandard.fromJson({
          ...ExerciseMovementContentFixtures.movementStandard.toJson(),
          'exercise_id': 'EX-9999',
        });
        final issues = validator.validate(
          definitions: ExerciseKnowledgeFixtures.allDefinitions,
          movementStandards: [unknown],
          coachingContents: const [],
          videoReferences: const [],
        );
        expect(
          issues.any((issue) => issue.code == 'content_unknown_exercise'),
          isTrue,
        );
      },
    );

    test('unresolved published definition references fail closed', () {
      final snapshot = ExerciseMovementContentFixtures.publishedVideoSnapshot()
          .copyWith(coachingContents: const []);
      final result = loader.load(snapshot.toJson());
      expect(result.isValid, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.code == 'unresolved_published_coaching_content_ref',
        ),
        isTrue,
      );
    });

    test('duplicate id/version and conflicting published versions fail', () {
      final standard = ExerciseMovementContentFixtures.movementStandard;
      final versionTwo = MovementStandard.fromJson({
        ...standard.toJson(),
        'version': '2',
      });
      final duplicateIssues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [standard, standard],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(
        duplicateIssues.any(
          (issue) => issue.code == 'duplicate_content_version',
        ),
        isTrue,
      );
      final versionIssues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [standard, versionTwo],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(
        versionIssues.any(
          (issue) => issue.code == 'conflicting_current_published_versions',
        ),
        isTrue,
      );
    });
  });

  group('lifecycle, replacement, and publication', () {
    test('published nested collections are immutable', () {
      expect(
        () => ExerciseMovementContentFixtures.movementStandard.executionSequence
            .add('mutation'),
        throwsUnsupportedError,
      );
      expect(
        () => ExerciseMovementContentFixtures.coachingContent.coachingCues.add(
          'mutation',
        ),
        throwsUnsupportedError,
      );
    });

    test('draft is authoring-only and retired content is historical', () {
      final draft = ExerciseMovementContentFixtures.draftVideo;
      final retired = VideoReference.fromJson({
        ...ExerciseMovementContentFixtures.unavailableVideo.toJson(),
        'id': 'video.fixture.retired',
        'lifecycle_status': 'retired',
      });
      final repo = InMemoryExerciseKnowledgeRepository(
        initial: ExerciseMovementContentFixtures.publishedVideoSnapshot(
          videoReferences: [
            ExerciseMovementContentFixtures.videoReference,
            draft,
            retired,
          ],
        ),
      );
      expect(
        repo
            .videoReferencesForExercise(
              draft.exerciseId,
              visibility: ExerciseKnowledgeVisibility.operational,
            )
            .contains(draft),
        isFalse,
      );
      expect(
        repo
            .videoReferencesForExercise(
              retired.exerciseId,
              visibility: ExerciseKnowledgeVisibility.historical,
            )
            .any((item) => item.id == retired.id),
        isTrue,
      );
    });

    test('valid explicit replacement is accepted', () {
      final old = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'id': 'standard.fixture.old',
        'lifecycle_status': 'retired',
        'replacement_id':
            ExerciseMovementContentFixtures.movementStandard.id.value,
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [
          old,
          ExerciseMovementContentFixtures.movementStandard,
        ],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(issues, isEmpty);
    });

    test('replacement cycles fail closed', () {
      MovementStandard replacement(String id, String target) =>
          MovementStandard.fromJson({
            ...ExerciseMovementContentFixtures.movementStandard.toJson(),
            'id': id,
            'lifecycle_status': 'retired',
            'replacement_id': target,
          });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [
          replacement('standard.fixture.a', 'standard.fixture.b'),
          replacement('standard.fixture.b', 'standard.fixture.a'),
        ],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(issues.any((issue) => issue.code == 'replacement_cycle'), isTrue);
    });

    test('excessive replacement depth fails closed', () {
      final standards = <MovementStandard>[];
      for (var i = 0; i < 10; i++) {
        standards.add(
          MovementStandard.fromJson({
            ...ExerciseMovementContentFixtures.movementStandard.toJson(),
            'id': 'standard.fixture.depth.$i',
            'lifecycle_status': 'retired',
            if (i < 9) 'replacement_id': 'standard.fixture.depth.${i + 1}',
          }),
        );
      }
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: standards,
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(
        issues.any((issue) => issue.code == 'replacement_depth_exceeded'),
        isTrue,
      );
    });

    test('cross-kind and cross-exercise replacements fail closed', () {
      final crossKind = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'id': 'standard.fixture.cross_kind',
        'lifecycle_status': 'retired',
        'replacement_id':
            ExerciseMovementContentFixtures.coachingContent.id.value,
      });
      final crossExerciseTarget = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'id': 'standard.fixture.other_exercise',
        'exercise_id': ExerciseKnowledgeFixtures.backSquat.id.value,
      });
      final crossExercise = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'id': 'standard.fixture.cross_exercise',
        'lifecycle_status': 'retired',
        'replacement_id': crossExerciseTarget.id.value,
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [
          crossKind,
          crossExercise,
          crossExerciseTarget,
          ExerciseMovementContentFixtures.movementStandard,
        ],
        coachingContents: [ExerciseMovementContentFixtures.coachingContent],
        videoReferences: const [],
      );
      expect(
        issues
            .where((issue) => issue.code == 'replacement_scope_mismatch')
            .length,
        greaterThanOrEqualTo(2),
      );
    });

    test('missing replacements fail closed', () {
      final missing = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'id': 'standard.fixture.missing_replacement',
        'lifecycle_status': 'retired',
        'replacement_id': 'standard.fixture.not_present',
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [
          missing,
          ExerciseMovementContentFixtures.movementStandard,
        ],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(
        issues.any((issue) => issue.code == 'replacement_missing'),
        isTrue,
      );
    });

    test('publication requires founder authority and an explicit reviewer', () {
      const publication = ExerciseKnowledgePublicationService();
      final draft = _draftSnapshot();
      final denied = publication.publishCatalogue(
        repository: InMemoryExerciseKnowledgeRepository(),
        draftSnapshot: draft,
        actingOwner: 'coach',
        reviewerId: ExerciseMovementContentFixtures.reviewer,
        publishedAt: ExerciseMovementContentFixtures.publishedAt,
      );
      expect(denied.isAccepted, isFalse);
      expect(
        denied.issues.any(
          (issue) => issue.code == 'founder_authority_required',
        ),
        isTrue,
      );

      final missingReviewer = publication.publishCatalogue(
        repository: InMemoryExerciseKnowledgeRepository(),
        draftSnapshot: draft,
        actingOwner: 'founder',
        publishedAt: ExerciseMovementContentFixtures.publishedAt,
      );
      expect(missingReviewer.isAccepted, isFalse);
      expect(
        missingReviewer.issues.any(
          (issue) => issue.code == 'content_reviewer_required',
        ),
        isTrue,
      );
    });

    test('founder publication makes complete draft content operational', () {
      const publication = ExerciseKnowledgePublicationService();
      final repo = InMemoryExerciseKnowledgeRepository();
      final result = publication.publishCatalogue(
        repository: repo,
        draftSnapshot: _draftSnapshot(),
        actingOwner: 'founder',
        reviewerId: ExerciseMovementContentFixtures.reviewer,
        publishedAt: ExerciseMovementContentFixtures.publishedAt,
      );
      expect(result.isAccepted, isTrue, reason: result.issues.toString());
      expect(
        repo
            .operationalMovementKnowledge(
              ExerciseKnowledgeFixtures.hyroxWallBalls.id,
            )
            .hasTextGuidance,
        isTrue,
      );
    });

    test('published content cannot mutate without a version change', () {
      const publication = ExerciseKnowledgePublicationService();
      final repo = InMemoryExerciseKnowledgeRepository(
        initial: ExerciseMovementContentFixtures.publishedVideoSnapshot(),
      );
      final changed = MovementStandard.fromJson(
        {
          ...ExerciseMovementContentFixtures.movementStandard.toJson(),
          'title': 'Changed without version bump',
          'lifecycle_status': 'draft',
          'reviewer': null,
          'reviewed_at': null,
          'published_at': null,
        }..removeWhere((_, value) => value == null),
      );
      final draft = _draftSnapshot().copyWith(movementStandards: [changed]);
      final result = publication.publishCatalogue(
        repository: repo,
        draftSnapshot: draft,
        actingOwner: 'founder',
        reviewerId: ExerciseMovementContentFixtures.reviewer,
        publishedAt: ExerciseMovementContentFixtures.publishedAt,
      );
      expect(result.isAccepted, isFalse);
      expect(
        result.issues.any(
          (issue) => issue.code == 'silent_published_content_mutation',
        ),
        isTrue,
      );
    });
  });

  group('published content completeness and media fallback', () {
    test('published standards require variant-scoped observable criteria', () {
      final incomplete = MovementStandard.fromJson({
        ...ExerciseMovementContentFixtures.movementStandard.toJson(),
        'applicability_key': '',
        'execution_sequence': <String>[],
        'completion_criteria': <String>[],
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [incomplete],
        coachingContents: const [],
        videoReferences: const [],
      );
      expect(
        issues.any(
          (issue) => issue.code == 'incomplete_published_movement_standard',
        ),
        isTrue,
      );
    });

    test('published coaching requires provenance, safety, and corrections', () {
      final incomplete = CoachingContent.fromJson({
        ...ExerciseMovementContentFixtures.coachingContent.toJson(),
        'safety_notes': <String>[],
        'fault_corrections': <Object?>[],
        'provenance': {'source_type': '', 'source_reference': ''},
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: const [],
        coachingContents: [incomplete],
        videoReferences: const [],
      );
      expect(
        issues.any(
          (issue) => issue.code == 'incomplete_published_coaching_content',
        ),
        isTrue,
      );
      expect(
        issues.any(
          (issue) => issue.code == 'published_content_missing_provenance',
        ),
        isTrue,
      );
    });

    test('published available video requires HTTPS governance metadata', () {
      final invalid = VideoReference.fromJson({
        ...ExerciseMovementContentFixtures.videoReference.toJson(),
        'canonical_uri': 'http://media.invalid/fixture',
        'rights_basis': '',
      });
      final issues = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: const [],
        coachingContents: const [],
        videoReferences: [invalid],
      );
      expect(issues.any((issue) => issue.code == 'invalid_video_uri'), isTrue);
      expect(
        issues.any(
          (issue) => issue.code == 'available_video_missing_rights_metadata',
        ),
        isTrue,
      );
    });

    test('malformed and unsupported media URIs fail publication', () {
      for (final uri in [
        'not a uri',
        'ftp://media.invalid/fixture',
        '/relative',
      ]) {
        final invalid = VideoReference.fromJson({
          ...ExerciseMovementContentFixtures.videoReference.toJson(),
          'canonical_uri': uri,
        });
        final issues = validator.validate(
          definitions: ExerciseKnowledgeFixtures.allDefinitions,
          movementStandards: const [],
          coachingContents: const [],
          videoReferences: [invalid],
        );
        expect(
          issues.any((issue) => issue.code == 'invalid_video_uri'),
          isTrue,
          reason: uri,
        );
      }
    });

    test('draft video may omit delivery metadata but is not operational', () {
      final result = validator.validate(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        movementStandards: [ExerciseMovementContentFixtures.movementStandard],
        coachingContents: const [],
        videoReferences: [ExerciseMovementContentFixtures.draftVideo],
      );
      expect(result, isEmpty);
      final repo = InMemoryExerciseKnowledgeRepository(
        initial: ExerciseCatalogueSnapshot(
          catalogueVersion: 'draft',
          definitions: ExerciseKnowledgeFixtures.allDefinitions,
          relationships: const [],
          comparisonProtocols: const [],
          movementStandards: [ExerciseMovementContentFixtures.movementStandard],
          videoReferences: [ExerciseMovementContentFixtures.draftVideo],
        ),
      );
      expect(
        repo
            .videoReferencesForExercise(
              ExerciseMovementContentFixtures.draftVideo.exerciseId,
            )
            .isEmpty,
        isTrue,
      );
    });

    test('unavailable video resolves to text-only guidance', () {
      final unavailable = ExerciseMovementContentFixtures.unavailableVideo;
      final definition =
          ExerciseMovementContentFixtures.definitionWithPublishedContentRefs();
      final unavailableDefinition = ExerciseDefinition.fromJson({
        ...definition.toJson(),
        'media_refs': [
          {'id': unavailable.id.value, 'kind': 'video'},
        ],
      });
      final snapshot = ExerciseCatalogueSnapshot(
        catalogueVersion: 'unavailable',
        definitions: [
          ...ExerciseKnowledgeFixtures.allDefinitions.where(
            (item) => item.id != unavailableDefinition.id,
          ),
          unavailableDefinition,
        ],
        relationships: ExerciseKnowledgeFixtures.validRelationships,
        comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
        movementStandards: [ExerciseMovementContentFixtures.movementStandard],
        coachingContents: [ExerciseMovementContentFixtures.coachingContent],
        videoReferences: [unavailable],
      );
      final loaded = loader.load(snapshot.toJson());
      expect(loaded.isValid, isTrue, reason: loaded.issues.toString());
      final knowledge = InMemoryExerciseKnowledgeRepository(
        initial: snapshot,
      ).operationalMovementKnowledge(unavailable.exerciseId);
      expect(knowledge.hasTextGuidance, isTrue);
      expect(knowledge.playableVideos, isEmpty);
    });
  });

  group('authority firewall', () {
    test('programme prescription concepts cannot enter content contracts', () {
      for (final field in const [
        'sets',
        'reps',
        'load',
        'weight_target',
        'distance_target',
        'duration_target',
        'pace_target',
        'tempo_prescription',
        'rest_prescription',
        'session_placement',
        'scheduling',
      ]) {
        expect(
          () => MovementStandard.fromJson({
            ...ExerciseMovementContentFixtures.movementStandard.toJson(),
            field: 'forbidden',
          }),
          throwsFormatException,
          reason: field,
        );
      }
    });

    test(
      'actuals, acceptance, comparison, and invariant mutation are rejected',
      () {
        for (final field in const [
          'athlete_actuals',
          'completion_status',
          'adaptation_acceptance',
          'automatic_exercise_selection',
          'comparison_grants',
          'comparable_history_identity',
          'programme_invariant_mutation',
        ]) {
          expect(
            () => CoachingContent.fromJson({
              ...ExerciseMovementContentFixtures.coachingContent.toJson(),
              field: true,
            }),
            throwsFormatException,
            reason: field,
          );
        }
        expect(
          ExerciseMovementContentFixtures.coachingContent.grantsComparability,
          isFalse,
        );
        expect(
          ExerciseMovementContentFixtures
              .coachingContent
              .grantsSubstitutionAuthority,
          isFalse,
        );
        expect(
          ExerciseMovementContentFixtures
              .coachingContent
              .grantsExerciseSelection,
          isFalse,
        );
      },
    );

    test('no application or UI consumer imports new content contracts', () {
      const contractImports = [
        'models/movement_standard.dart',
        'models/coaching_content.dart',
        'models/video_reference.dart',
      ];
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File ||
            !entity.path.endsWith('.dart') ||
            entity.path.contains('/domain/exercise_knowledge/')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (contractImports.any(source.contains)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty);
    });
  });
}

ExerciseCatalogueSnapshot _draftSnapshot() {
  final definition =
      ExerciseMovementContentFixtures.definitionWithPublishedContentRefs();
  final draftDefinition = ExerciseDefinition.fromJson(
    {...definition.toJson(), 'lifecycle_status': 'draft', 'published_at': null}
      ..removeWhere((_, value) => value == null),
  );
  return ExerciseCatalogueSnapshot(
    catalogueVersion: 'draft-content-1',
    definitions: [
      ...ExerciseKnowledgeFixtures.allDefinitions.where(
        (item) => item.id != draftDefinition.id,
      ),
      draftDefinition,
    ],
    relationships: ExerciseKnowledgeFixtures.validRelationships,
    comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
    movementStandards: [
      _asDraft(ExerciseMovementContentFixtures.movementStandard),
    ],
    coachingContents: [
      _asDraft(ExerciseMovementContentFixtures.coachingContent),
    ],
    videoReferences: [_asDraft(ExerciseMovementContentFixtures.videoReference)],
  );
}

T _asDraft<T extends ExerciseKnowledgeContentRecord>(T record) {
  final json = Map<String, Object?>.from(record.toJson())
    ..['lifecycle_status'] = 'draft'
    ..remove('reviewer')
    ..remove('reviewed_at')
    ..remove('published_at');
  return switch (record) {
    MovementStandard _ => MovementStandard.fromJson(json) as T,
    CoachingContent _ => CoachingContent.fromJson(json) as T,
    VideoReference _ => VideoReference.fromJson(json) as T,
    _ => throw StateError('Unsupported fixture type.'),
  };
}
