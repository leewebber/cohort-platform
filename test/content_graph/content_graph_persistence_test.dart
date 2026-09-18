import 'package:cohort_platform/domain/content_graph/apollo_local_graph_binder.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_manifest.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_persistence.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_publication.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_reconstruction.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/domain/content_graph/in_memory_content_graph_store.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:cohort_platform/features/programme/services/athlete_runtime_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists immutable manifest with typed outcomes', () async {
    final seeded = M9ContentGraphFixtures.seed();
    final repo = InMemoryContentGraphManifestRepository();
    final persistence = ContentGraphPersistenceService(
      graph: seeded,
      repository: repo,
    );
    final first = await persistence.persistPublished(
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    expect(first.status, ContentGraphPublicationStatus.published);
    final retry = await persistence.persistPublished(
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    expect(retry.status, ContentGraphPublicationStatus.alreadyPublished);
    final mismatch = await persistence.persistPublished(
      programmeVersionId: M9ContentGraphFixtures.v1Id,
      overridePayload: {
        ...persistence.publishPayload(M9ContentGraphFixtures.v1Id),
        'composite_identity': '0' * 64,
      },
    );
    expect(mismatch.status, ContentGraphPublicationStatus.hashMismatch);
    final unsupported = await persistence.persistPublished(
      programmeVersionId: M9ContentGraphFixtures.v1Id,
      overridePayload: {
        ...persistence.publishPayload(M9ContentGraphFixtures.v1Id),
        'compiler_version': 'nope',
      },
    );
    expect(
      unsupported.status,
      ContentGraphPublicationStatus.unsupportedFormat,
    );
    final unauth = await persistence.persistPublished(
      programmeVersionId: M9ContentGraphFixtures.v1Id,
      authorised: false,
    );
    expect(unauth.status, ContentGraphPublicationStatus.unauthorised);
  });

  test('pinning is independent of later default and graph hash', () {
    final memory = InMemoryContentGraphStore();
    final service = M9ContentGraphFixtures.seed(store: memory);
    final originalPin = service
        .resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId)
        .programmeVersionId;
    expect(originalPin, M9ContentGraphFixtures.v1Id);
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id).sha256;
    M9ContentGraphFixtures.forkSessionTemplateRevision(memory);
    final draft = service.cloneDraftFromPublished(
      actor: M9ContentGraphFixtures.firstParty,
      publishedVersionId: M9ContentGraphFixtures.v1Id,
      draftVersionId: M9ContentGraphFixtures.v2DraftId,
    );
    service.store.putPlacement(
      memory.placementsForVersion(draft.id).single.copyWith(
            sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
          ),
    );
    service.rebindSupplementalFromGraph(draft.id);
    service.publish(
      actor: M9ContentGraphFixtures.firstParty,
      programmeVersionId: draft.id,
      setCatalogueDefault: true,
    );
    service.retire(
      actor: M9ContentGraphFixtures.firstParty,
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    expect(
      service
          .resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId)
          .programmeVersionId,
      M9ContentGraphFixtures.v1Id,
    );
    final enrolled = service.enrol(
      assignmentId: 'assignment.generic-b',
      athleteId: 'athlete.generic-b',
      programmeId: M9ContentGraphFixtures.programmeId,
    );
    expect(enrolled.programmeVersionId, isNot(M9ContentGraphFixtures.v1Id));
    final after = service.compileDraft(M9ContentGraphFixtures.v1Id).sha256;
    expect(after, before);
  });

  test('used-by is canonical-id and diff classes stay stable', () {
    final service = M9ContentGraphFixtures.seed();
    final used = service.usedByExercise(M9ContentGraphFixtures.exerciseSquat);
    expect(
      used.hits.any((h) => h.nodeType == ContentNodeType.authoredBlock),
      isTrue,
    );
    final draft = service.cloneDraftFromPublished(
      actor: M9ContentGraphFixtures.firstParty,
      publishedVersionId: M9ContentGraphFixtures.v1Id,
      draftVersionId: 'draft-diff',
    );
    service.store.putPlacement(
      service.store.placementsForVersion(draft.id).single.copyWith(
            titleOverride: 'Renamed only',
          ),
    );
    final metadata = service.diffAgainstPrevious(draft.id);
    expect(metadata.entries, isNotEmpty);
    expect(
      metadata.entries.every(
        (e) => e.classification == ContentDiffClass.metadataPresentation,
      ),
      isTrue,
    );
  });

  test('reconstruction classifies without guessing and is idempotent', () {
    final reconstruction = ContentGraphReconstructionService();
    const source = 'canonical-source-v1';
    final exercises = const [
      ContentExercise(id: 'EX-136', displayName: 'Back Squat'),
      ContentExercise(id: 'EX-129', displayName: 'Running'),
      ContentExercise(
        id: 'LEGACY-NAME-ONLY',
        displayName: 'Unknown',
        unresolvedLegacy: true,
      ),
    ];
    final dry = reconstruction.run(
      jobKey: 'local-apollo',
      sourceCanonical: source,
      exercises: exercises,
      supplementalExerciseIds: const ['EX-129'],
      authoredExerciseIds: const ['EX-136'],
    );
    expect(dry.dryRun, isTrue);
    expect(dry.resolvableCount, 1);
    expect(dry.supplementalCount, 1);
    expect(dry.unresolvedCount, 1);
    expect(dry.rowsWritten, 0);
    final first = reconstruction.run(
      jobKey: 'local-apollo',
      sourceCanonical: source,
      exercises: exercises,
      supplementalExerciseIds: const ['EX-129'],
      authoredExerciseIds: const ['EX-136'],
      dryRun: false,
      apply: true,
    );
    expect(first.rowsWritten, 3);
    final second = reconstruction.run(
      jobKey: 'local-apollo',
      sourceCanonical: source,
      exercises: exercises,
      supplementalExerciseIds: const ['EX-129'],
      authoredExerciseIds: const ['EX-136'],
      dryRun: false,
      apply: true,
    );
    expect(second.rowsWritten, 0);
    final changed = reconstruction.run(
      jobKey: 'local-apollo',
      sourceCanonical: 'changed-source',
      exercises: exercises,
      supplementalExerciseIds: const ['EX-129'],
      authoredExerciseIds: const ['EX-136'],
      dryRun: false,
      apply: true,
    );
    expect(changed.rejectedCode, 'source_changed_during_resume');
  });

  test('Apollo binder still yields 58 EX-* and frozen package hash', () {
    expect(
      ApolloLocalGraphBinder.expectedPlanPackageHash,
      '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
    );
    expect(ApolloLocalGraphBinder.expectedCanonicalExerciseCount, 58);
  });

  test('missing content-graph capability fails closed', () {
    expect(AthleteRuntimeCapabilities.unavailable.contentGraphRead, isFalse);
    expect(AthleteRuntimeCapabilities.unavailable.contentGraphPublish, isFalse);
    expect(AthleteRuntimeCapabilities.unavailable.contentGraphImpact, isFalse);
    expect(AthleteRuntimeCapabilities.unavailable.schemaVersion, 0);
    const schemaOnly = AthleteRuntimeCapabilities(
      schemaVersion: 2,
      contentGraphRead: true,
    );
    expect(schemaOnly.contentGraphPublish, isFalse);
    expect(schemaOnly.contentGraphImpact, isFalse);
    expect(schemaOnly.contentGraphRead, isTrue);
  });

  test('display names are not relationship keys', () {
    expect(
      ContentGraphBinding.compositeDigest(
        sourcePackageHash: 'a' * 64,
        supplementalRelationshipHash: 'b' * 64,
      ),
      isNot(contains('Back Squat')),
    );
  });
}
