import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_catalogue_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_action.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_sort_mode.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_tab.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_catalogue_view_state.dart';
import 'package:cohort_platform/features/coach_studio/programmes/utils/programme_catalogue_list_processor.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_publishing_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_seed_template.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import '../support/in_memory_programme_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const coachId = 'dev-coach';

  late InMemoryProgrammeTables tables;
  late ProgrammeCatalogueController controller;

  ProgrammeCatalogEntry entry({
    required String id,
    required String name,
    required String lineageCode,
    required ProgrammeLifecycleStatus lifecycle,
    DateTime? updatedAt,
    String? primaryGoal,
    bool approvedForGlobal = false,
    int versionNumber = 1,
  }) {
    return ProgrammeCatalogEntry(
      versionId: id,
      lineageCode: lineageCode,
      versionNumber: versionNumber,
      name: name,
      lifecycleStatus: lifecycle,
      libraryScope: ProgrammeLibraryScope.coachPrivate,
      ownerType: ProgrammeOwnerType.coach,
      ownerId: coachId,
      primaryGoal: primaryGoal,
      approvedForGlobal: approvedForGlobal,
      updatedAt: updatedAt,
    );
  }

  void seedVersion({
    required String id,
    required String lineageCode,
    required ProgrammeLifecycleStatus lifecycle,
    DateTime? updatedAt,
    String? primaryGoal,
    bool approvedForGlobal = false,
    int versionNumber = 1,
  }) {
    final lineageId = 'lineage-$lineageCode';
    if (!tables.lineages.any((lineage) => lineage.id == lineageId)) {
      tables.lineages.add(
        ProgrammeLineage(id: lineageId, code: lineageCode),
      );
    }

    tables.versions.add(
      ProgrammeVersion(
        id: id,
        lineageId: lineageId,
        versionNumber: versionNumber,
        lifecycleStatus: lifecycle,
        libraryScope: ProgrammeLibraryScope.coachPrivate,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        name: 'Programme $lineageCode',
        primaryGoal: primaryGoal,
        approvedForGlobal: approvedForGlobal,
        updatedAt: updatedAt,
        publishedAt: lifecycle == ProgrammeLifecycleStatus.published
            ? updatedAt
            : null,
        archivedAt: lifecycle == ProgrammeLifecycleStatus.archived
            ? updatedAt
            : null,
      ),
    );
  }

  void seedTreeForVersion(String versionId) {
    final week = ProgrammeVersionWeek(
      id: 'week-$versionId',
      versionId: versionId,
      weekNumber: 1,
    );
    final day = ProgrammeVersionDay(
      id: 'day-$versionId',
      weekId: week.id,
      dayKey: 'day_1',
      dayOrder: 1,
    );
    final slot = ProgrammeVersionSessionSlot(
      id: 'slot-$versionId',
      dayId: day.id,
      sessionOrder: 1,
      protocolId: 'BW-001',
    );

    tables.weeks.add(week);
    tables.days.add(day);
    tables.slots.add(slot);
  }

  setUp(() {
    tables = InMemoryProgrammeTables();
    final versionStore = InMemoryProgrammeVersionStore(tables);
    final assignmentStore = InMemoryProgrammeAssignmentStore(tables);
    final validationService = ProgrammeBuilderValidationServiceImpl(
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );
    final builderService = ProgrammeBuilderServiceImpl(
      versionStore: versionStore,
      assignmentStore: assignmentStore,
      validationService: validationService,
    );

    controller = ProgrammeCatalogueController(
      builderService: builderService,
      catalogService: ProgrammeCatalogServiceImpl(
        versionStore: versionStore,
        coachId: coachId,
      ),
      publishCoordinator: ProgrammeBuilderPublishCoordinatorImpl(
        builderService: builderService,
        publishingService: ProgrammePublishingServiceImpl(
          versionStore: versionStore,
        ),
        validationService: validationService,
      ),
      publishingService: ProgrammePublishingServiceImpl(
        versionStore: versionStore,
      ),
      validationService: validationService,
      coachId: coachId,
    );
  });

  test('drafts load', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'COHORT-DRAFT-1',
      lifecycle: ProgrammeLifecycleStatus.draft,
      updatedAt: DateTime.utc(2026, 7, 10),
    );

    await controller.loadTab(ProgrammeCatalogueTab.drafts);

    expect(controller.viewState, ProgrammeCatalogueViewState.ready);
    expect(controller.loadedEntries, hasLength(1));
  });

  test('published load', () async {
    seedVersion(
      id: 'pub-1',
      lineageCode: 'COHORT-PUB-1',
      lifecycle: ProgrammeLifecycleStatus.published,
      updatedAt: DateTime.utc(2026, 7, 11),
    );

    await controller.loadTab(ProgrammeCatalogueTab.published);

    expect(controller.loadedEntries.single.lifecycleStatus,
        ProgrammeLifecycleStatus.published);
  });

  test('global load', () async {
    seedVersion(
      id: 'global-1',
      lineageCode: 'COHORT-GLOBAL-1',
      lifecycle: ProgrammeLifecycleStatus.published,
      updatedAt: DateTime.utc(2026, 7, 12),
      approvedForGlobal: true,
    );

    await controller.loadTab(ProgrammeCatalogueTab.cohortGlobal);

    expect(controller.loadedEntries.single.approvedForGlobal, isTrue);
  });

  test('archived load', () async {
    seedVersion(
      id: 'arch-1',
      lineageCode: 'COHORT-ARCH-1',
      lifecycle: ProgrammeLifecycleStatus.archived,
      updatedAt: DateTime.utc(2026, 7, 13),
    );

    await controller.loadTab(ProgrammeCatalogueTab.archived);

    expect(controller.loadedEntries.single.lifecycleStatus,
        ProgrammeLifecycleStatus.archived);
  });

  test('search by name', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'ALPHA',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );
    seedVersion(
      id: 'draft-2',
      lineageCode: 'BETA',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );
    tables.versions[0] = tables.versions[0].copyWith(name: 'Alpha Programme');
    tables.versions[1] = tables.versions[1].copyWith(name: 'Beta Programme');

    await controller.loadTab(ProgrammeCatalogueTab.drafts);
    controller.setSearchTerm('alpha');

    expect(controller.displayedEntries, hasLength(1));
    expect(controller.displayedEntries.single.name, contains('Alpha'));
  });

  test('search by lineage code', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'COHORT-ALPHA',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );
    seedVersion(
      id: 'draft-2',
      lineageCode: 'COHORT-BETA',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );

    await controller.loadTab(ProgrammeCatalogueTab.drafts);
    controller.setSearchTerm('beta');

    expect(controller.displayedEntries.single.lineageCode, 'COHORT-BETA');
  });

  test('scope filter', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'PRIVATE-1',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );
    tables.versions[0] = tables.versions[0].copyWith(
      libraryScope: ProgrammeLibraryScope.coachPrivate,
    );

    await controller.loadTab(ProgrammeCatalogueTab.drafts);
    controller.setScopeFilter(ProgrammeLibraryScope.cohortGlobal);

    expect(controller.displayedEntries, isEmpty);
  });

  test('primary goal filter', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'GOAL-1',
      lifecycle: ProgrammeLifecycleStatus.draft,
      primaryGoal: 'Strength',
    );
    seedVersion(
      id: 'draft-2',
      lineageCode: 'GOAL-2',
      lifecycle: ProgrammeLifecycleStatus.draft,
      primaryGoal: 'Running',
    );

    await controller.loadTab(ProgrammeCatalogueTab.drafts);
    controller.setPrimaryGoalFilter('Strength');

    expect(controller.displayedEntries, hasLength(1));
    expect(controller.displayedEntries.single.primaryGoal, 'Strength');
  });

  test('last-edited default sort', () async {
    final processor = const ProgrammeCatalogueListProcessor();
    final sorted = processor.apply(
      entries: [
        entry(
          id: '1',
          name: 'Old',
          lineageCode: 'A',
          lifecycle: ProgrammeLifecycleStatus.draft,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        entry(
          id: '2',
          name: 'New',
          lineageCode: 'B',
          lifecycle: ProgrammeLifecycleStatus.draft,
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      ],
      sortMode: ProgrammeCatalogueSortMode.lastEdited,
    );

    expect(sorted.first.name, 'New');
  });

  test('name sort', () async {
    final processor = const ProgrammeCatalogueListProcessor();
    final sorted = processor.apply(
      entries: [
        entry(
          id: '1',
          name: 'Zulu',
          lineageCode: 'A',
          lifecycle: ProgrammeLifecycleStatus.draft,
        ),
        entry(
          id: '2',
          name: 'Alpha',
          lineageCode: 'B',
          lifecycle: ProgrammeLifecycleStatus.draft,
        ),
      ],
      sortMode: ProgrammeCatalogueSortMode.nameAZ,
    );

    expect(sorted.first.name, 'Alpha');
  });

  test('null updatedAt sorts last', () async {
    final processor = const ProgrammeCatalogueListProcessor();
    final sorted = processor.apply(
      entries: [
        entry(
          id: '1',
          name: 'No date',
          lineageCode: 'A',
          lifecycle: ProgrammeLifecycleStatus.draft,
        ),
        entry(
          id: '2',
          name: 'Dated',
          lineageCode: 'B',
          lifecycle: ProgrammeLifecycleStatus.draft,
          updatedAt: DateTime.utc(2026, 7, 1),
        ),
      ],
      sortMode: ProgrammeCatalogueSortMode.lastEdited,
    );

    expect(sorted.first.name, 'Dated');
    expect(sorted.last.name, 'No date');
  });

  test('action disabled while running', () async {
    controller.actionInProgressVersionId = 'draft-1';
    final result = await controller.archiveVersion('draft-1');
    expect(result.success, isFalse);
  });

  test('errors surface', () async {
    tables.denyReads = true;
    await controller.loadTab(ProgrammeCatalogueTab.drafts);
    expect(controller.viewState, ProgrammeCatalogueViewState.permissionDenied);
    expect(controller.errorMessage, isNotNull);
  });

  test('create programme returns version id', () async {
    final result = await controller.createProgramme(
      metadata: const ProgrammeVersionDraftMetadata(
        lineageCode: 'COHORT-NEW-001',
        versionNumber: 1,
        name: 'New Programme',
      ),
      seedTemplate: ProgrammeSeedTemplate.strength,
    );

    expect(result.success, isTrue);
    expect(result.versionId, isNotNull);
  });

  test('clone version', () async {
    seedVersion(
      id: 'pub-1',
      lineageCode: 'COHORT-CLONE',
      lifecycle: ProgrammeLifecycleStatus.published,
      versionNumber: 1,
    );
    seedTreeForVersion('pub-1');

    final result = await controller.cloneVersion('pub-1');

    expect(result.success, isTrue);
    expect(result.navigateToEditor, isTrue);
  });

  test('duplicate programme', () async {
    seedVersion(
      id: 'pub-1',
      lineageCode: 'COHORT-DUP-SRC',
      lifecycle: ProgrammeLifecycleStatus.published,
    );
    seedTreeForVersion('pub-1');

    final result = await controller.duplicateProgramme(
      sourceVersionId: 'pub-1',
      newLineageCode: 'COHORT-DUP-TARGET',
      newProgrammeName: 'Duplicate Target',
    );

    expect(result.success, isTrue);
    expect(result.navigateToEditor, isTrue);
  });

  test('archive', () async {
    seedVersion(
      id: 'pub-1',
      lineageCode: 'COHORT-ARCHIVE',
      lifecycle: ProgrammeLifecycleStatus.published,
    );

    final result = await controller.archiveVersion('pub-1');

    expect(result.success, isTrue);
    expect(controller.activeTab, ProgrammeCatalogueTab.archived);
  });

  test('delete draft', () async {
    seedVersion(
      id: 'draft-1',
      lineageCode: 'COHORT-DELETE',
      lifecycle: ProgrammeLifecycleStatus.draft,
    );

    final result = await controller.deleteDraft('draft-1');

    expect(result.success, isTrue);
    expect(tables.versions.where((version) => version.id == 'draft-1'), isEmpty);
  });
}
