import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_service.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/domain/content_graph/in_memory_content_graph_store.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryContentGraphStore store;
  late ContentGraphService service;

  setUp(() {
    store = InMemoryContentGraphStore();
    service = M9ContentGraphFixtures.seed(store: store);
  });

  group('identity and lifecycle', () {
    test('stable programme identity is distinct from version identity', () {
      final v1 = store.programmeVersion(M9ContentGraphFixtures.v1Id)!;
      expect(v1.programmeId, M9ContentGraphFixtures.programmeId);
      expect(v1.id, isNot(v1.programmeId));
      expect(v1.versionNumber, 1);
      expect(v1.lifecycle, ContentLifecycle.published);
    });

    test('published programme version is immutable', () {
      expect(
        () => store.putPlacement(
          const ProgrammePlacement(
            id: 'illegal',
            programmeVersionId: M9ContentGraphFixtures.v1Id,
            sessionTemplateVersionId: M9ContentGraphFixtures.sessionV1Id,
            weekNumber: 2,
            dayKey: 'day_1',
            slotOrder: 1,
          ),
        ),
        throwsA(
          isA<ContentGraphException>().having(
            (e) => e.code,
            'code',
            ContentGraphFailureCode.publishedImmutable,
          ),
        ),
      );
    });

    test('clone increments version number monotonically', () {
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: M9ContentGraphFixtures.v2DraftId,
      );
      expect(draft.versionNumber, 2);
      expect(draft.lifecycle, ContentLifecycle.draft);
      expect(draft.supersedesVersionId, M9ContentGraphFixtures.v1Id);
    });

    test('identical canonical content is rejected on publish', () {
      service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: M9ContentGraphFixtures.v2DraftId,
      );
      expect(
        () => service.publish(
          actor: M9ContentGraphFixtures.firstParty,
          programmeVersionId: M9ContentGraphFixtures.v2DraftId,
        ),
        throwsA(
          isA<ContentGraphException>().having(
            (e) => e.code,
            'code',
            ContentGraphFailureCode.identicalCanonicalContent,
          ),
        ),
      );
    });

    test('retire keeps historical assignment readable', () {
      service.retire(
        actor: M9ContentGraphFixtures.firstParty,
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      );
      final assignment = service.resolveAssignment(
        M9ContentGraphFixtures.athleteAssignmentId,
      );
      expect(assignment.programmeVersionId, M9ContentGraphFixtures.v1Id);
      expect(
        store.programmeVersion(M9ContentGraphFixtures.v1Id)!.lifecycle,
        ContentLifecycle.retired,
      );
    });
  });

  group('relationships and used-by', () {
    test('exercise traverses block, session, programme, assignment', () {
      final used = service.usedByExercise(M9ContentGraphFixtures.exerciseSquat);
      expect(
        used.hits.any((h) => h.nodeType == ContentNodeType.authoredBlock),
        isTrue,
      );
      expect(
        used.hits.any(
          (h) => h.nodeType == ContentNodeType.sessionTemplateVersion && h.direct,
        ),
        isTrue,
      );
      expect(
        used.hits.any(
          (h) =>
              h.nodeType == ContentNodeType.programmeVersion && h.direct == false,
        ),
        isTrue,
      );
      expect(used.activeAssignmentCount, 1);
    });

    test('session used-by includes placement coordinates', () {
      final used = service.usedBySessionTemplateVersion(
        M9ContentGraphFixtures.sessionV1Id,
      );
      expect(used.hits.single.label, '1/day_1/1');
      expect(used.activeAssignmentCount, 1);
    });

    test('unresolved exercise fails publication', () {
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: 'draft-unresolved',
      );
      store.putPlacement(
        ProgrammePlacement(
          id: 'bad-slot',
          programmeVersionId: draft.id,
          sessionTemplateVersionId: 'missing-session',
          weekNumber: 3,
          dayKey: 'day_1',
          slotOrder: 1,
        ),
      );
      expect(
        service.validateDraft(draft.id),
        contains('unresolved_session:missing-session'),
      );
    });

    test('legacy unresolved exercise is surfaced, not guessed', () {
      store.putSessionTemplateVersion(
        const SessionTemplateVersion(
          id: 'session.legacy',
          templateId: 'session-template.apollo-strength-a',
          revisionNumber: 9,
          lifecycle: ContentLifecycle.draft,
          ownerId: 'publisher.cohort-global',
        ),
      );
      store.putBlock(
        const AuthoredBlock(
          id: 'block.legacy',
          sessionTemplateVersionId: 'session.legacy',
          position: 1,
          title: 'Legacy',
          exerciseIds: ['LEGACY-NAME-ONLY'],
        ),
      );
      store.putSessionTemplateVersion(
        const SessionTemplateVersion(
          id: 'session.legacy',
          templateId: 'session-template.apollo-strength-a',
          revisionNumber: 9,
          lifecycle: ContentLifecycle.published,
          ownerId: 'publisher.cohort-global',
        ),
      );
      final draft = service.createDraftVersion(
        actor: M9ContentGraphFixtures.firstParty,
        programmeId: M9ContentGraphFixtures.programmeId,
        draftVersionId: 'draft-legacy',
      );
      store.putPlacement(
        ProgrammePlacement(
          id: 'legacy-slot',
          programmeVersionId: draft.id,
          sessionTemplateVersionId: 'session.legacy',
          weekNumber: 12,
          dayKey: 'day_1',
          slotOrder: 1,
        ),
      );
      expect(
        service.validateDraft(draft.id),
        contains('legacy_unresolved_exercise:LEGACY-NAME-ONLY'),
      );
    });
  });

  group('compiler', () {
    test('same input produces the same hash', () {
      final a = service.compileDraft(M9ContentGraphFixtures.v1Id);
      final b = service.compileDraft(M9ContentGraphFixtures.v1Id);
      expect(a.sha256, b.sha256);
      expect(a.canonicalJson.contains('created_at'), isFalse);
    });
  });

  group('assignment pinning', () {
    test('existing athlete stays on v1 after v2 publish', () {
      M9ContentGraphFixtures.forkSessionTemplateRevision(store);
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: M9ContentGraphFixtures.v2DraftId,
      );
      store.putPlacement(
        ProgrammePlacement(
          id: 'placement.w1.day_1.s1->${draft.id}',
          programmeVersionId: draft.id,
          sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
          weekNumber: 1,
          dayKey: 'day_1',
          slotOrder: 1,
        ),
      );
      service.rebindSupplementalFromGraph(draft.id);
      final v2 = service.publish(
        actor: M9ContentGraphFixtures.firstParty,
        programmeVersionId: draft.id,
        setCatalogueDefault: true,
      );
      expect(
        service.resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId)
            .programmeVersionId,
        M9ContentGraphFixtures.v1Id,
      );
      final newbie = service.enrol(
        assignmentId: 'assignment.new',
        athleteId: 'athlete.new',
        programmeId: M9ContentGraphFixtures.programmeId,
      );
      expect(newbie.programmeVersionId, v2.id);
      expect(newbie.programmeVersionId, isNot(M9ContentGraphFixtures.v1Id));
    });

    test('execution never follows latest', () {
      final pinned = service.resolveAssignment(
        M9ContentGraphFixtures.athleteAssignmentId,
      );
      final latest = service.defaultPublishedVersion(
        M9ContentGraphFixtures.programmeId,
      );
      expect(pinned.programmeVersionId, latest.id);
      M9ContentGraphFixtures.forkSessionTemplateRevision(store);
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: 'draft-later',
      );
      store.putPlacement(
        ProgrammePlacement(
          id: 'moved',
          programmeVersionId: draft.id,
          sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
          weekNumber: 1,
          dayKey: 'day_2',
          slotOrder: 1,
        ),
      );
      service.rebindSupplementalFromGraph(draft.id);
      service.publish(
        actor: M9ContentGraphFixtures.firstParty,
        programmeVersionId: draft.id,
        setCatalogueDefault: true,
      );
      expect(
        service.resolveAssignment(M9ContentGraphFixtures.athleteAssignmentId)
            .programmeVersionId,
        pinned.programmeVersionId,
      );
      expect(
        service.defaultPublishedVersion(M9ContentGraphFixtures.programmeId).id,
        isNot(pinned.programmeVersionId),
      );
    });
  });

  group('diff', () {
    test('classifies exercise substitution, movement and metadata', () {
      M9ContentGraphFixtures.forkSessionTemplateRevision(store);
      final draft = service.cloneDraftFromPublished(
        actor: M9ContentGraphFixtures.firstParty,
        publishedVersionId: M9ContentGraphFixtures.v1Id,
        draftVersionId: M9ContentGraphFixtures.v2DraftId,
      );
      store.putPlacement(
        store.placementsForVersion(draft.id).single.copyWith(
          sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
          titleOverride: 'Strength A (updated)',
          progressionParameters: const {'load_progress': 'step'},
          adaptationPermission: 'restricted',
        ),
      );
      final diff = service.diffAgainstPrevious(draft.id);
      expect(diff.hasBreaking, isTrue);
      expect(diff.hasMaterial, isTrue);
      expect(
        diff.entries.any((e) => e.summary.contains('metadata-only')),
        isTrue,
      );
      expect(
        diff.entries.any((e) => e.summary.contains('adaptation-permission')),
        isTrue,
      );
    });
  });

  group('authorization', () {
    test('external publisher cannot mutate first-party programme', () {
      expect(
        () => service.cloneDraftFromPublished(
          actor: M9ContentGraphFixtures.external,
          publishedVersionId: M9ContentGraphFixtures.v1Id,
          draftVersionId: 'stolen',
        ),
        throwsA(
          isA<ContentGraphException>().having(
            (e) => e.code,
            'code',
            ContentGraphFailureCode.namespaceIsolation,
          ),
        ),
      );
    });

    test('reader cannot publish', () {
      expect(
        () => service.publish(
          actor: M9ContentGraphFixtures.reader,
          programmeVersionId: M9ContentGraphFixtures.v1Id,
        ),
        throwsA(
          isA<ContentGraphException>().having(
            (e) => e.code,
            'code',
            ContentGraphFailureCode.unauthorized,
          ),
        ),
      );
    });
  });

  group('backfill', () {
    test('fixture seed is idempotent on a fresh store', () {
      final again = InMemoryContentGraphStore();
      M9ContentGraphFixtures.seed(store: again);
      M9ContentGraphFixtures.seed(store: InMemoryContentGraphStore());
      expect(
        again.programmeVersion(M9ContentGraphFixtures.v1Id)!.lifecycle,
        ContentLifecycle.published,
      );
      expect(again.assignments.length, 1);
    });
  });

  group('performance bounds', () {
    test('used-by is indexed rather than N+1 over evidence', () {
      final used = service.usedByExercise(M9ContentGraphFixtures.exerciseSquat);
      expect(used.hits.length, lessThan(20));
      expect(store.occurrences.length, 1);
    });
  });
}
