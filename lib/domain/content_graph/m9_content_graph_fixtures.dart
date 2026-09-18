import 'content_graph_manifest.dart';
import 'content_graph_models.dart';
import 'content_graph_service.dart';
import 'content_graph_vocabulary.dart';
import 'in_memory_content_graph_store.dart';

/// Fixture-only Apollo-shaped graph. Never contacts Field Manual.
class M9ContentGraphFixtures {
  static const firstParty = ContentActor(
    publisherId: 'publisher.cohort-global',
    role: ContentAuthRole.firstPartyPublisher,
  );
  static const external = ContentActor(
    publisherId: 'publisher.acme-coach',
    role: ContentAuthRole.externalPublisher,
  );
  static const reader = ContentActor(
    publisherId: 'publisher.cohort-global',
    role: ContentAuthRole.reader,
  );

  static const programmeId = 'programme.apollo-12-week';
  static const v1Id = 'programme-version.apollo.v1';
  static const v2DraftId = 'programme-version.apollo.v2-draft';
  static const athleteAssignmentId = 'assignment.lee-fixture';
  static const sessionV1Id = 'session.apollo-strength-a.r1';
  static const sessionV2Id = 'session.apollo-strength-a.r2';
  static const exerciseSquat = 'EX-136';
  static const exercisePull = 'EX-095';
  static const exerciseReplacement = 'EX-137';
  static final fixtureSourcePackageHash = ContentGraphBinding.sha256Hex(
    'm9-fixture-plan-package-v1:APOLLO-BUILD-12-WEEK@2',
  );

  static ContentGraphService seed({
    InMemoryContentGraphStore? store,
  }) {
    final graph = store ?? InMemoryContentGraphStore();
    graph.putPublisher(
      const ContentPublisher(
        id: 'publisher.cohort-global',
        displayName: 'Cohort',
        namespace: 'cohort_global',
        firstParty: true,
      ),
    );
    graph.putPublisher(
      const ContentPublisher(
        id: 'publisher.acme-coach',
        displayName: 'Acme Coach',
        namespace: 'coach.acme',
        firstParty: false,
      ),
    );
    graph.putExercise(
      const ContentExercise(id: exerciseSquat, displayName: 'Back Squat'),
    );
    graph.putExercise(
      const ContentExercise(
        id: exercisePull,
        displayName: 'Weighted Pull-Up',
        aliases: ['pull-up weighted'],
      ),
    );
    graph.putExercise(
      const ContentExercise(
        id: exerciseReplacement,
        displayName: 'Neutral-Grip Pull-Up',
      ),
    );
    graph.putExercise(
      const ContentExercise(
        id: 'LEGACY-NAME-ONLY',
        displayName: 'Unknown legacy movement',
        unresolvedLegacy: true,
      ),
    );
    graph.putSessionTemplate(
      const SessionTemplate(
        id: 'session-template.apollo-strength-a',
        displayName: 'Apollo Strength A',
        ownerId: 'publisher.cohort-global',
      ),
    );
    graph.putSessionTemplateVersion(
      const SessionTemplateVersion(
        id: sessionV1Id,
        templateId: 'session-template.apollo-strength-a',
        revisionNumber: 1,
        lifecycle: ContentLifecycle.draft,
        ownerId: 'publisher.cohort-global',
        label: 'r1',
        sourceHash: 'session-src-r1',
      ),
    );
    graph.putBlock(
      const AuthoredBlock(
        id: 'block.strength-a.main',
        sessionTemplateVersionId: sessionV1Id,
        position: 1,
        title: 'Main strength',
        exerciseIds: [exerciseSquat, exercisePull],
        prescriptionByExercise: {
          exerciseSquat: '4x6 @ 70kg',
          exercisePull: '4x8 @ 5kg',
        },
      ),
    );
    graph.putSessionTemplateVersion(
      const SessionTemplateVersion(
        id: sessionV1Id,
        templateId: 'session-template.apollo-strength-a',
        revisionNumber: 1,
        lifecycle: ContentLifecycle.published,
        ownerId: 'publisher.cohort-global',
        label: 'r1',
        sourceHash: 'session-src-r1',
      ),
    );
    graph.putProgramme(
      const ProgrammeIdentity(
        id: programmeId,
        code: 'APOLLO-BUILD-12-WEEK',
        displayName: 'Apollo 12 Week',
        ownerId: 'publisher.cohort-global',
      ),
    );
    graph.putProgrammeVersion(
      ProgrammeVersion(
        id: v1Id,
        programmeId: programmeId,
        versionNumber: 1,
        lifecycle: ContentLifecycle.draft,
        ownerId: 'publisher.cohort-global',
        label: 'v1',
        sourcePackageRef: 'plan-package-v1:APOLLO-BUILD-12-WEEK@2',
        sourcePackageHash: fixtureSourcePackageHash,
      ),
    );
    graph.putPlacement(
      const ProgrammePlacement(
        id: 'placement.w1.day_1.s1',
        programmeVersionId: v1Id,
        sessionTemplateVersionId: sessionV1Id,
        weekNumber: 1,
        dayKey: 'day_1',
        slotOrder: 1,
        progressionParameters: {'load_progress': 'linear'},
      ),
    );

    final service = ContentGraphService(store: graph);
    service.rebindSupplementalFromGraph(v1Id);
    service.publish(
      actor: firstParty,
      programmeVersionId: v1Id,
      setCatalogueDefault: true,
    );
    service.enrol(
      assignmentId: athleteAssignmentId,
      athleteId: 'athlete.fixture-existing',
      programmeId: programmeId,
    );
    graph.putOccurrence(
      const DerivedOccurrence(
        id: 'occurrence.w1.day_1',
        assignmentId: athleteAssignmentId,
        placementId: 'placement.w1.day_1.s1',
        programmeVersionId: v1Id,
      ),
    );
    return service;
  }

  static void forkSessionTemplateRevision(InMemoryContentGraphStore store) {
    store.putSessionTemplateVersion(
      const SessionTemplateVersion(
        id: sessionV2Id,
        templateId: 'session-template.apollo-strength-a',
        revisionNumber: 2,
        lifecycle: ContentLifecycle.draft,
        ownerId: 'publisher.cohort-global',
        label: 'r2',
        sourceHash: 'session-src-r2',
      ),
    );
    store.putBlock(
      const AuthoredBlock(
        id: 'block.strength-a.main.r2',
        sessionTemplateVersionId: sessionV2Id,
        position: 1,
        title: 'Main strength',
        exerciseIds: [exerciseSquat, exerciseReplacement],
        prescriptionByExercise: {
          exerciseSquat: '4x6 @ 72.5kg',
          exerciseReplacement: '4x8 @ bodyweight',
        },
      ),
    );
    store.putSessionTemplateVersion(
      const SessionTemplateVersion(
        id: sessionV2Id,
        templateId: 'session-template.apollo-strength-a',
        revisionNumber: 2,
        lifecycle: ContentLifecycle.published,
        ownerId: 'publisher.cohort-global',
        label: 'r2',
        sourceHash: 'session-src-r2',
      ),
    );
  }
}
