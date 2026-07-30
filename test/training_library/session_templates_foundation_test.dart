import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/training_library/models/session_template_taxonomy.dart';
import 'package:cohort_platform/features/training_library/models/training_library_item_summary.dart';
import 'package:cohort_platform/features/training_library/models/training_library_tab.dart';
import 'package:cohort_platform/features/training_library/screens/training_library_screen.dart';
import 'package:cohort_platform/features/training_library/services/cohort_session_template_catalogue.dart';
import 'package:cohort_platform/features/training_library/services/cohort_session_template_seed_service.dart';
import 'package:cohort_platform/features/training_library/services/session_library_authoring_coordinator.dart';
import 'package:cohort_platform/features/training_library/services/training_library_service.dart';
import 'package:cohort_platform/features/training_library/widgets/session_templates_tab.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_classification.dart';
import 'package:cohort_platform/models/training_content_edit_policy.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

void main() {
  const policy = TrainingContentEditPolicy();
  const taxonomy = SessionTemplateTaxonomy();

  group('CohortSessionTemplateCatalogue', () {
    test('has stable seed IDs and valid classification', () {
      final all = CohortSessionTemplateCatalogue.all();
      expect(all, hasLength(10));
      expect(all.map((t) => t.protocolId).toSet(), hasLength(10));

      for (final draft in all) {
        expect(
          CohortSessionTemplateCatalogue.isCanonicalSeedId(draft.protocolId),
          isTrue,
        );
        expect(draft.contentKind, TrainingContentKind.sessionTemplate);
        expect(draft.authoringScope, TrainingAuthoringScope.cohortGlobal);
        expect(
          draft.endorsementStatus,
          TrainingEndorsementStatus.cohortEndorsed,
        );
        expect(draft.published, isTrue);
        expect(draft.ownerId, isNull);
        expect(draft.name.trim(), isNotEmpty);
        expect(draft.purpose?.trim(), isNotEmpty);
        expect(draft.steps, isNotEmpty);
        expect(TrainingContentClassification.isSessionTemplate(draft), isTrue);
        expect(
          TrainingContentClassification.isCanonicalSessionTemplate(draft),
          isTrue,
        );
        expect(policy.canEditInPlace(draft, coachId: 'coach-1'), isFalse);
        expect(policy.canUseAsTemplateSource(draft), isTrue);
        expect(policy.isCanonicalTemplateSource(draft), isTrue);
        expect(policy.requiresCoachOwnedCopy(draft), isTrue);
      }
    });
  });

  group('CohortSessionTemplateSeedService', () {
    test('idempotent seeding inserts once and skips on repeat', () async {
      final store = InMemoryCohortSessionTemplateSeedStore();
      final service = CohortSessionTemplateSeedService(store: store);

      final first = await service.seedCanonicalTemplates();
      expect(first.insertedIds, hasLength(10));
      expect(first.skippedExistingIds, isEmpty);
      expect(store.rows, hasLength(10));

      final second = await service.seedCanonicalTemplates();
      expect(second.insertedIds, isEmpty);
      expect(second.skippedExistingIds, hasLength(10));
      expect(store.rows, hasLength(10));
    });

    test('refuses coach-owned colliding id without overwrite', () async {
      final store = InMemoryCohortSessionTemplateSeedStore();
      store.rows['TMP-001'] = ProtocolDraft(
        protocolId: 'TMP-001',
        name: 'Coach Session',
        steps: const [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.coachPrivate,
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        ownerId: 'coach-1',
        published: true,
      );

      final service = CohortSessionTemplateSeedService(store: store);
      expect(
        () => service.seedCanonicalTemplates(),
        throwsA(isA<CohortSessionTemplateSeedConflictException>()),
      );
      expect(store.rows['TMP-001']!.contentKind, TrainingContentKind.session);
      expect(store.rows['TMP-001']!.ownerId, 'coach-1');
    });

    test('refuses impostor template missing endorsement', () async {
      final store = InMemoryCohortSessionTemplateSeedStore();
      store.rows['TMP-002'] = ProtocolDraft(
        protocolId: 'TMP-002',
        name: 'Impostor',
        steps: const [],
        contentKind: TrainingContentKind.sessionTemplate,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        published: true,
      );

      final service = CohortSessionTemplateSeedService(store: store);
      expect(
        () => service.seedCanonicalTemplates(),
        throwsA(isA<CohortSessionTemplateSeedConflictException>()),
      );
    });

    test('completes empty steps and refuses partial step sets', () async {
      final store = InMemoryCohortSessionTemplateSeedStore();
      final canonical = CohortSessionTemplateCatalogue.upperBodyStrength;
      store.rows['TMP-002'] = canonical.copyWith(steps: const []);

      final service = CohortSessionTemplateSeedService(store: store);
      final completed = await service.seedCanonicalTemplates();
      expect(completed.completedStepIds, contains('TMP-002'));
      expect(store.rows['TMP-002']!.steps.length, canonical.steps.length);

      store.rows['TMP-003'] = CohortSessionTemplateCatalogue.lowerBodyStrength
          .copyWith(steps: canonical.steps.take(1).toList());
      expect(
        () => service.seedCanonicalTemplates(),
        throwsA(isA<CohortSessionTemplateSeedConflictException>()),
      );
    });
  });

  group('SessionTemplateTaxonomy filters', () {
    test('filters catalogue by modality and equipment', () {
      final service = TrainingLibraryService();
      final strength = service.catalogueFixtureSummaries(
        modality: SessionTemplateModalityFilter.strength,
      );
      final hyrox = service.catalogueFixtureSummaries(
        modality: SessionTemplateModalityFilter.hyrox,
      );
      final bodyweight = service.catalogueFixtureSummaries(
        equipment: SessionTemplateEquipmentFilter.bodyweight,
      );

      expect(strength, isNotEmpty);
      expect(
        strength.every(
          (s) => s.modalityFilter == SessionTemplateModalityFilter.strength,
        ),
        isTrue,
      );
      expect(hyrox.map((s) => s.contentId), contains('TMP-006'));
      expect(bodyweight.map((s) => s.contentId), contains('TMP-008'));
      expect(bodyweight.map((s) => s.contentId), contains('TMP-009'));
    });

    test('derives bodyweight equipment bucket honestly', () {
      expect(
        taxonomy.equipmentBucketFor(requiredEquipment: 'Bodyweight'),
        SessionTemplateEquipmentFilter.bodyweight,
      );
      expect(
        taxonomy.equipmentBucketFor(requiredEquipment: 'Dumbbell, Minimal Kit'),
        SessionTemplateEquipmentFilter.minimalKit,
      );
      expect(
        taxonomy.equipmentBucketFor(requiredEquipment: 'Barbell, Full Gym'),
        SessionTemplateEquipmentFilter.fullGym,
      );
      expect(taxonomy.equipmentBucketFor(requiredEquipment: null), isNull);
      expect(taxonomy.equipmentBucketFor(requiredEquipment: ''), isNull);
    });

    test('does not classify Hybrid as HYROX without explicit signals', () {
      expect(
        taxonomy.modalityFor(
          sessionType: 'Hybrid',
          suitableFor: 'General Fitness',
          primaryIntent: SessionIntent.mixedModalConditioning,
        ),
        SessionTemplateModalityFilter.conditioning,
      );
      expect(
        taxonomy.modalityFor(
          sessionType: 'Hybrid',
          suitableFor: 'HYROX, Intermediate',
          primaryIntent: SessionIntent.hyroxSpecificConditioning,
        ),
        SessionTemplateModalityFilter.hyrox,
      );
      expect(
        taxonomy.modalityFor(sessionType: 'Mystery', suitableFor: null),
        isNull,
      );
    });
  });

  group('Use Template derivative lifecycle', () {
    test('creates coach-owned session with provenance and new ID', () async {
      final template = CohortSessionTemplateCatalogue.fullBodyStrength;
      final protocolService = FakeProtocolBuilderService()
        ..drafts[template.protocolId] = template;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final draft = await coordinator.prepareDraftFromTemplate(
        templateContentId: template.protocolId,
      );

      expect(draft.protocolId, isNot(template.protocolId));
      expect(SessionCloneService.isLocalCloneDraftId(draft.protocolId), isTrue);
      expect(draft.contentKind, TrainingContentKind.session);
      expect(draft.authoringScope, TrainingAuthoringScope.coachPrivate);
      expect(draft.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(draft.ownerId, 'coach-1');
      expect(draft.sourceContentId, template.protocolId);
      expect(draft.sourceContentKind, TrainingContentKind.sessionTemplate);
      expect(TrainingContentClassification.isCohortProtocol(draft), isFalse);
      expect(TrainingContentClassification.isSessionTemplate(draft), isFalse);

      // Canonical template unchanged in store.
      expect(
        protocolService.drafts[template.protocolId]!.contentKind,
        TrainingContentKind.sessionTemplate,
      );
      expect(protocolService.drafts[template.protocolId]!.name, template.name);
    });

    test('preview loads template without creating derivative', () async {
      final template = CohortSessionTemplateCatalogue.mobilityRecovery;
      final protocolService = FakeProtocolBuilderService()
        ..drafts[template.protocolId] = template;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final preview = await coordinator.loadTemplateForPreview(
        template.protocolId,
      );

      expect(preview.protocolId, template.protocolId);
      expect(preview.contentKind, TrainingContentKind.sessionTemplate);
      expect(protocolService.librarySaveCallCount, 0);
      expect(protocolService.saveCallCount, 0);
    });

    test('preview and prepare reject non-canonical template sources', () async {
      final impostor = CohortSessionTemplateCatalogue.fullBodyStrength.copyWith(
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        ownerId: 'coach-x',
        authoringScope: TrainingAuthoringScope.coachPrivate,
      );
      final coachSession = ProtocolDraft(
        protocolId: 'SES-PRIV',
        name: 'Private',
        steps: const [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.coachPrivate,
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        ownerId: 'coach-1',
        published: true,
      );
      final protocolService = FakeProtocolBuilderService()
        ..drafts[impostor.protocolId] = impostor
        ..drafts[coachSession.protocolId] = coachSession;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      expect(
        () => coordinator.loadTemplateForPreview(impostor.protocolId),
        throwsA(isA<ProtocolBuilderException>()),
      );
      expect(
        () => coordinator.loadTemplateForPreview(coachSession.protocolId),
        throwsA(isA<ProtocolBuilderException>()),
      );
      expect(
        () => coordinator.prepareDraftFromTemplate(
          templateContentId: impostor.protocolId,
        ),
        throwsA(isA<ProtocolBuilderException>()),
      );
    });

    test(
      'in-place template save claiming session_template is rejected',
      () async {
        final template = CohortSessionTemplateCatalogue.upperBodyStrength;
        final protocolService = FakeProtocolBuilderService()
          ..drafts[template.protocolId] = template;

        expect(
          () => protocolService.saveCoachLibrarySession(
            template.copyWith(name: 'Mutated Template'),
          ),
          throwsA(isA<ProtocolBuilderException>()),
        );
        expect(
          protocolService.drafts[template.protocolId]!.name,
          'Upper-Body Strength',
        );
      },
    );

    test('ordinary coach mutation of template is rejected below UI', () async {
      final template = CohortSessionTemplateCatalogue.upperBodyStrength;
      final protocolService = FakeProtocolBuilderService()
        ..drafts[template.protocolId] = template;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final result = await coordinator.updateSession(
        draft: template.copyWith(
          contentKind: TrainingContentKind.session,
          authoringScope: TrainingAuthoringScope.coachPrivate,
          ownerId: 'coach-1',
          name: 'Hijacked',
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(protocolService.librarySaveCallCount, 0);
      expect(
        protocolService.drafts[template.protocolId]!.name,
        'Upper-Body Strength',
      );
    });

    test('save of template-derived session lands in My Sessions', () async {
      final template = CohortSessionTemplateCatalogue.bodyweightSession;
      final protocolService = FakeProtocolBuilderService()
        ..drafts[template.protocolId] = template;
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('coach-1'),
      );

      final draft = await coordinator.prepareDraftFromTemplate(
        templateContentId: template.protocolId,
      );
      final result = await coordinator.createSession(draft: draft);

      expect(result.isSuccess, isTrue);
      expect(result.contentId, testDurableSessionId);
      final saved = protocolService.libraryDrafts[testDurableSessionId]!;
      expect(saved.contentKind, TrainingContentKind.session);
      expect(saved.sourceContentId, template.protocolId);
      expect(saved.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(
        protocolService.drafts[template.protocolId]!.contentKind,
        TrainingContentKind.sessionTemplate,
      );
    });

    test('clone service rejects attaching template identity', () {
      final template = CohortSessionTemplateCatalogue.simpleBenchmark;
      expect(
        () => const SessionCloneService().cloneTemplateToSession(
          source: template,
          newContentId: template.protocolId,
          ownerId: 'coach-1',
          destination: CohortProtocolCopyDestination.sessionLibrary,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Training Library Templates destination', () {
    setUp(() {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-1',
          displayName: 'Coach',
          isCoach: true,
          isAthlete: false,
        ),
      );
    });

    tearDown(CurrentUserSession.clear);

    testWidgets('shows Templates tab distinct from Protocols and My Sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingLibraryScreen(
            cohortTab: const Text('Cohort tab content'),
            sessionTab: const Text('Session tab content'),
            templatesTab: const Text('Templates tab content'),
          ),
        ),
      );

      expect(find.text('Cohort Protocols'), findsOneWidget);
      expect(find.text('My Sessions'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(TrainingLibraryTab.values, hasLength(3));
    });

    testWidgets('templates tab renders catalogue cards and actions', (
      tester,
    ) async {
      final summaries = TrainingLibraryService().catalogueFixtureSummaries();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionTemplatesTab(
              listTemplates:
                  ({
                    String? searchTerm,
                    SessionTemplateModalityFilter modality =
                        SessionTemplateModalityFilter.all,
                    SessionTemplateEquipmentFilter equipment =
                        SessionTemplateEquipmentFilter.all,
                  }) async {
                    return summaries
                        .where(
                          (item) =>
                              searchTerm == null ||
                              searchTerm.isEmpty ||
                              item.title.toLowerCase().contains(
                                searchTerm.toLowerCase(),
                              ),
                        )
                        .toList();
                  },
              coordinator: SessionLibraryAuthoringCoordinator(
                protocolBuilderService: FakeProtocolBuilderService()
                  ..drafts.addEntries(
                    CohortSessionTemplateCatalogue.all().map(
                      (d) => MapEntry(d.protocolId, d),
                    ),
                  ),
                idGenerator: FixedSessionIdGenerator(testDurableSessionId),
                coachIdentity: const FixedCoachIdentity('coach-1'),
              ),
              coachIdentity: const FixedCoachIdentity('coach-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full-Body Strength'), findsOneWidget);
      expect(find.text('Preview template'), findsWidgets);
      expect(find.text('Use template'), findsWidgets);
      expect(
        find.textContaining('creates your own editable session'),
        findsWidgets,
      );
    });

    testWidgets('empty catalogue state is shown when loader returns none', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionTemplatesTab(
              listTemplates:
                  ({
                    String? searchTerm,
                    SessionTemplateModalityFilter modality =
                        SessionTemplateModalityFilter.all,
                    SessionTemplateEquipmentFilter equipment =
                        SessionTemplateEquipmentFilter.all,
                  }) async => const <TrainingLibraryItemSummary>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No templates available yet'), findsOneWidget);
    });
  });

  group('canonical template summary classification', () {
    test('service maps repository protocols as cohort templates', () async {
      final repository = _FakeCanonicalTemplateRepository(
        templates: [
          Protocol(
            protocolId: 'TMP-001',
            name: 'Full-Body Strength',
            sessionType: 'Strength',
            durationMin: 55,
            description: 'Balanced strength session',
            requiredEquipment: 'Barbell, Full Gym',
            technicalComplexity: 'Intermediate',
          ),
        ],
      );
      final service = TrainingLibraryService(protocolRepository: repository);

      final summaries = await service.loadCanonicalTemplateSummaries();

      expect(summaries, hasLength(1));
      expect(summaries.first.isCanonicalTemplate, isTrue);
      expect(
        summaries.first.endorsementStatus,
        TrainingEndorsementStatus.cohortEndorsed,
      );
      expect(
        summaries.first.authoringScope,
        TrainingAuthoringScope.cohortGlobal,
      );
      expect(summaries.first.purpose, 'Balanced strength session');
    });
  });
}

class _FakeCanonicalTemplateRepository extends ProtocolRepository {
  _FakeCanonicalTemplateRepository({required this.templates});

  final List<Protocol> templates;

  @override
  Future<List<Protocol>> listCanonicalSessionTemplates({
    int limit = 100,
  }) async {
    return templates.take(limit).toList();
  }
}
