import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_knowledge_fixtures.dart';
import 'exercise_movement_content_fixtures.dart';

void main() {
  late InMemoryExerciseKnowledgeRepository repo;

  ExerciseCatalogueSnapshot fixtureSnapshot({
    List<ExerciseDefinition>? definitions,
    List<ExerciseRelationship>? relationships,
    String version = 'test-1',
  }) {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: version,
      definitions: definitions ?? ExerciseKnowledgeFixtures.allDefinitions,
      relationships:
          relationships ?? ExerciseKnowledgeFixtures.validRelationships,
      comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
      movementStandards: [
        ExerciseMovementContentFixtures.movementStandard,
      ],
    );
  }

  setUp(() {
    repo = InMemoryExerciseKnowledgeRepository(
      initial: fixtureSnapshot(),
    );
  });

  group('ExerciseKnowledgeRepository', () {
    test('deterministic lookup by EX-*', () {
      final a = repo.getDefinition(ExerciseId.parse('EX-9001'));
      final b = repo.getDefinition(ExerciseId.parse('EX-9001'));
      expect(a.definition?.canonicalName, 'Barbell Back Squat');
      expect(a.definition?.id, b.definition?.id);
      expect(
        repo
            .getDefinitions([
              ExerciseId.parse('EX-9002'),
              ExerciseId.parse('EX-9001'),
            ])
            .map((l) => l.id.value)
            .toList(),
        ['EX-9001', 'EX-9002'],
      );
    });

    test('malformed and transitional ids cannot be canonical keys', () {
      expect(() => ExerciseId.parse('cohort.exercise.back_squat'),
          throwsFormatException);
      expect(() => ExerciseId.parse('Back Squat'), throwsFormatException);
      expect(
        repo.resolveAlias('cohort.exercise.back_squat'),
        isA<AliasNotFound>(),
      );
    });

    test('unknown ids fail explicitly', () {
      final missing =
          repo.getDefinition(ExerciseId.parse('EX-0000'));
      expect(missing.isMissing, isTrue);
      expect(missing.isOperational, isFalse);
      expect(missing.isHistoricallyResolvable, isFalse);
    });

    test('alias resolution returns canonical EX-* ids', () {
      final result = repo.resolveAlias('back squat');
      expect(result, isA<AliasResolved>());
      expect((result as AliasResolved).canonicalId.value, 'EX-9001');
    });

    test('ambiguous aliases fail closed', () {
      final ambiguous = ExerciseDefinition(
        id: ExerciseId.parse('EX-9010'),
        canonicalName: 'Alt Back',
        aliases: const ['back squat'],
        modality: ExerciseModality.strength,
        lifecycleStatus: ExerciseLifecycleStatus.published,
        version: '1',
        publishedAt: DateTime.utc(2026, 8, 9),
      );
      repo.upsertDefinition(ambiguous);
      final result = repo.resolveAlias('back squat');
      expect(result, isA<AliasAmbiguous>());
      final ids = (result as AliasAmbiguous).canonicalIds.map((e) => e.value);
      expect(ids, containsAll(['EX-9001', 'EX-9010']));
    });

    test('draft knowledge is not operational', () {
      final draft = ExerciseDefinition(
        id: ExerciseId.parse('EX-9099'),
        canonicalName: 'Draft Movement',
        modality: ExerciseModality.mobility,
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: '1',
      );
      repo.upsertDefinition(draft);

      final operational = repo.getDefinition(
        draft.id,
        visibility: ExerciseKnowledgeVisibility.operational,
      );
      expect(operational.isMissing, isTrue);

      final authoring = repo.getDefinition(
        draft.id,
        visibility: ExerciseKnowledgeVisibility.authoring,
      );
      expect(authoring.isDraft, isTrue);
      expect(authoring.isOperational, isFalse);

      expect(
        repo
            .operationalSnapshot()
            .definitions
            .any((d) => d.id == draft.id),
        isFalse,
      );
    });

    test('published knowledge is retrievable operationally', () {
      final lookup = repo.getDefinition(
        ExerciseId.parse('EX-9001'),
        visibility: ExerciseKnowledgeVisibility.operational,
      );
      expect(lookup.isOperational, isTrue);
      expect(lookup.definition?.canonicalName, 'Barbell Back Squat');
    });

    test('retired knowledge remains historically resolvable', () {
      const publication = ExerciseKnowledgePublicationService();
      final retired = publication.retireDefinition(
        repository: repo,
        id: ExerciseId.parse('EX-9001'),
        actingOwner: 'founder',
        retiredAt: DateTime.utc(2026, 8, 9),
      );
      expect(retired.isAccepted, isTrue);

      final operational = repo.getDefinition(
        ExerciseId.parse('EX-9001'),
        visibility: ExerciseKnowledgeVisibility.operational,
      );
      expect(operational.isMissing, isTrue);

      final historical = repo.getDefinition(
        ExerciseId.parse('EX-9001'),
        visibility: ExerciseKnowledgeVisibility.historical,
      );
      expect(historical.isRetired, isTrue);
      expect(historical.isHistoricallyResolvable, isTrue);
    });

    test('relationships retain direction and type; no auto substitution', () {
      final out = repo.outgoingRelationships(ExerciseId.parse('EX-9001'));
      expect(out, isNotEmpty);
      for (final rel in out) {
        expect(rel.sourceExerciseId.value, 'EX-9001');
        expect(rel.targetExerciseId.value, isNot('EX-9001'));
      }
      final goblet = out.firstWhere(
        (r) => r.targetExerciseId.value == 'EX-9002',
      );
      expect(
        goblet.relationshipType,
        ExerciseRelationshipType.equipmentAlternative,
      );
      // Repository must not select a substitution — only return typed links.
      expect(out.length, greaterThanOrEqualTo(1));
    });

    test('comparison protocols require explicit identity/version', () {
      expect(
        repo.getComparisonProtocol('cmp.back_squat.standard')?.version,
        '1',
      );
      expect(
        repo.getComparisonProtocol('cmp.back_squat.standard', version: '9'),
        isNull,
      );
      expect(repo.getComparisonProtocol('cmp.missing'), isNull);
    });

    test('substitution relationships do not grant comparison compatibility', () {
      const helper = ComparisonProtocolCompatibility();
      final protocol = repo.getComparisonProtocol('cmp.back_squat.standard');
      final forGoblet = helper.protocolAppliesTo(
        protocol: protocol,
        exerciseId: ExerciseId.parse('EX-9002'),
      );
      expect(forGoblet.isCompatible, isFalse);

      final rel = ExerciseKnowledgeFixtures.backSquatToGoblet;
      expect(rel.claimsDirectComparability, isFalse);
      expect(rel.relationshipType.impliesComparabilityByDefault, isFalse);
    });

    test('catalogue serialization/order is deterministic', () {
      final s1 = repo.authoringSnapshot(catalogueVersion: 'v');
      final s2 = ExerciseCatalogueSnapshot.fromJson(
        Map<String, Object?>.from(s1.toJson()),
      );
      expect(s2.toJson(), s1.toJson());
      final ids = s1.definitions.map((d) => d.id.value).toList();
      final sorted = List<String>.of(ids)..sort();
      expect(ids, sorted);
    });

    test('no prescription or completion values in repository snapshot', () {
      final json = repo.operationalSnapshot().toJson();
      final encoded = json.toString();
      for (final key in const [
        'sets',
        'reps',
        'tempo',
        'completed_load',
        'athlete_result',
      ]) {
        expect(encoded.contains("'$key'"), isFalse);
      }
    });
  });

  group('ExerciseKnowledgePublicationService', () {
    test('invalid catalogues cannot publish', () {
      const publication = ExerciseKnowledgePublicationService();
      final bad = ExerciseCatalogueSnapshot(
        catalogueVersion: 'bad',
        definitions: [
          ExerciseDefinition(
            id: ExerciseId.parse('EX-9998'),
            canonicalName: '   ',
            modality: ExerciseModality.strength,
            lifecycleStatus: ExerciseLifecycleStatus.draft,
            version: '1',
          ),
        ],
        relationships: const [],
        comparisonProtocols: const [],
      );
      final result = publication.publishCatalogue(
        repository: InMemoryExerciseKnowledgeRepository(),
        draftSnapshot: bad,
        actingOwner: 'founder',
      );
      expect(result.isAccepted, isFalse);
      expect(result.issues.any((i) => i.code == 'blank_canonical_name'), isTrue);
    });

    test('founder publication authority is enforced', () {
      const publication = ExerciseKnowledgePublicationService();
      final result = publication.publishCatalogue(
        repository: InMemoryExerciseKnowledgeRepository(),
        draftSnapshot: fixtureSnapshot(),
        actingOwner: 'coach',
      );
      expect(result.isAccepted, isFalse);
      expect(
        result.issues.any((i) => i.code == 'founder_authority_required'),
        isTrue,
      );
    });

    test('successful founder publish makes definitions operational', () {
      const publication = ExerciseKnowledgePublicationService();
      final draftDefs = ExerciseKnowledgeFixtures.allDefinitions
          .map(
            (d) => ExerciseDefinition(
              id: d.id,
              canonicalName: d.canonicalName,
              aliases: d.aliases,
              modality: d.modality,
              familyId: d.familyId,
              movementPatterns: d.movementPatterns,
              laterality: d.laterality,
              technicalComplexity: d.technicalComplexity,
              impactLevel: d.impactLevel,
              validPrescriptionDimensions: d.validPrescriptionDimensions,
              validCompletedPerformanceDimensions:
                  d.validCompletedPerformanceDimensions,
              equipment: d.equipment,
              environments: d.environments,
              coachingContentRefs: d.coachingContentRefs,
              mediaRefs: d.mediaRefs,
              movementStandardRefs: const [],
              sportStandardRefs: d.sportStandardRefs,
              transitionalAliasIds: d.transitionalAliasIds,
              lifecycleStatus: ExerciseLifecycleStatus.draft,
              version: d.version,
              owner: 'founder',
            ),
          )
          .toList();
      final draftRels = ExerciseKnowledgeFixtures.validRelationships
          .map(
            (r) => ExerciseRelationship(
              id: r.id,
              sourceExerciseId: r.sourceExerciseId,
              targetExerciseId: r.targetExerciseId,
              relationshipType: r.relationshipType,
              substitutionConstraint: r.substitutionConstraint,
              comparisonProtocolId: r.comparisonProtocolId,
              preservesIntentNotes: r.preservesIntentNotes,
              explanationRefId: r.explanationRefId,
              lifecycleStatus: ExerciseLifecycleStatus.draft,
              version: r.version,
              owner: 'founder',
            ),
          )
          .toList();
      final empty = InMemoryExerciseKnowledgeRepository();
      final result = publication.publishCatalogue(
        repository: empty,
        draftSnapshot: ExerciseCatalogueSnapshot(
          catalogueVersion: 'pub-1',
          definitions: draftDefs,
          relationships: draftRels,
          comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
        ),
        actingOwner: 'founder',
        publishedAt: DateTime.utc(2026, 8, 9),
      );
      expect(result.isAccepted, isTrue);
      expect(
        empty
            .getDefinition(
              ExerciseId.parse('EX-9001'),
              visibility: ExerciseKnowledgeVisibility.operational,
            )
            .isOperational,
        isTrue,
      );
    });

    test('silent published mutation without version bump fails', () {
      const publication = ExerciseKnowledgePublicationService();
      final mutated = ExerciseKnowledgeFixtures.backSquat;
      final changed = ExerciseDefinition(
        id: mutated.id,
        canonicalName: 'Changed Name Silently',
        aliases: mutated.aliases,
        modality: mutated.modality,
        familyId: mutated.familyId,
        movementPatterns: mutated.movementPatterns,
        laterality: mutated.laterality,
        technicalComplexity: mutated.technicalComplexity,
        impactLevel: mutated.impactLevel,
        validPrescriptionDimensions: mutated.validPrescriptionDimensions,
        validCompletedPerformanceDimensions:
            mutated.validCompletedPerformanceDimensions,
        equipment: mutated.equipment,
        environments: mutated.environments,
        transitionalAliasIds: mutated.transitionalAliasIds,
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: mutated.version, // same version
        owner: 'founder',
      );
      final result = publication.publishCatalogue(
        repository: repo,
        draftSnapshot: fixtureSnapshot(definitions: [
          changed,
          ...ExerciseKnowledgeFixtures.allDefinitions
              .where((d) => d.id != changed.id),
        ]),
        actingOwner: 'founder',
      );
      expect(result.isAccepted, isFalse);
      expect(
        result.issues.any((i) => i.code == 'silent_published_mutation'),
        isTrue,
      );
    });
  });
}
