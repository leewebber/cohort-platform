import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_editor_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/models/programme_editor_view_state.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/services/programme_publishing_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_history.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_path.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_preview.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_seed_template.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_preview_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_name_resolver.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_protocol_picker_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_publish_coordinator_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_service_impl.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_validation_service_impl.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';

void main() {
  const coachId = 'dev-coach';
  const versionId = 'draft-1';

  late InMemoryProgrammeTables tables;
  late ProgrammeBuilderServiceImpl builderService;
  late ProgrammeBuilderValidationService validationService;
  late FakeProtocolPickerService pickerService;
  late FakeProtocolNameResolver nameResolver;
  late FakePreviewService previewService;
  late ProgrammeEditorController controller;

  ProgrammeBuilderDocument sampleDocument({
    String protocolId = 'BW-001',
    ProgrammeLifecycleStatus lifecycle = ProgrammeLifecycleStatus.draft,
  }) {
    return ProgrammeBuilderDocument.clean(
      metadata: ProgrammeVersionDraftMetadata(
        versionId: versionId,
        lineageId: 'lineage-1',
        lineageCode: 'COHORT-TEST',
        versionNumber: 1,
        lifecycleStatus: lifecycle,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        name: 'Foundation Test',
      ),
      template: ProgrammeTemplateDraft(
        weeks: [
          ProgrammeWeekDraft(
            localId: 'week-1',
            weekNumber: 1,
            days: [
              ProgrammeDayDraft(
                localId: 'day-1',
                dayKey: 'day_1',
                dayOrder: 1,
                slots: [
                  ProgrammeSessionSlotDraft(
                    localId: 'slot-1',
                    sessionOrder: 1,
                    protocolId: protocolId,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      lastSavedAt: DateTime.utc(2026, 7, 16),
    );
  }

  void seedPersistedDraft() {
    tables.lineages.add(const ProgrammeLineage(id: 'lineage-1', code: 'COHORT-TEST'));
    tables.versions.add(
      ProgrammeVersion(
        id: versionId,
        lineageId: 'lineage-1',
        versionNumber: 1,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        libraryScope: ProgrammeLibraryScope.coachPrivate,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        name: 'Foundation Test',
        updatedAt: DateTime.utc(2026, 7, 16),
      ),
    );
    tables.weeks.add(
      ProgrammeVersionWeek(
        id: 'week-db-1',
        versionId: versionId,
        weekNumber: 1,
      ),
    );
    tables.days.add(
      ProgrammeVersionDay(
        id: 'day-db-1',
        weekId: 'week-db-1',
        dayKey: 'day_1',
        dayOrder: 1,
      ),
    );
    tables.slots.add(
      ProgrammeVersionSessionSlot(
        id: 'slot-db-1',
        dayId: 'day-db-1',
        sessionOrder: 1,
        protocolId: 'BW-001',
      ),
    );
  }

  ProgrammeEditorController createController({
    ProgrammeBuilderService? serviceOverride,
    bool failSave = false,
  }) {
    final service = serviceOverride ??
        (failSave
            ? FailingSaveBuilderService(builderService)
            : builderService);

    return ProgrammeEditorController(
      builderService: service,
      validationService: validationService,
      publishCoordinator: ProgrammeBuilderPublishCoordinatorImpl(
        builderService: builderService,
        publishingService: ProgrammePublishingServiceImpl(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        validationService: validationService,
      ),
      previewService: previewService,
      protocolPickerService: pickerService,
      protocolNameResolver: nameResolver,
      coachId: coachId,
      versionId: versionId,
    );
  }

  setUp(() {
    tables = InMemoryProgrammeTables();
    seedPersistedDraft();

    validationService = ProgrammeBuilderValidationServiceImpl(
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );
    builderService = ProgrammeBuilderServiceImpl(
      versionStore: InMemoryProgrammeVersionStore(tables),
      assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      validationService: validationService,
    );
    pickerService = FakeProtocolPickerService();
    nameResolver = FakeProtocolNameResolver();
    previewService = FakePreviewService();

    controller = createController();
  });

  test('load persisted draft is clean', () async {
    await controller.load();

    expect(controller.viewState, ProgrammeEditorViewState.ready);
    expect(controller.document?.isDirty, isFalse);
    expect(controller.document?.hasUnsavedChanges, isFalse);
  });

  test('metadata edit marks dirty', () async {
    await controller.load();
    await controller.updateMetadata(
      controller.document!.metadata.copyWith(name: 'Updated'),
    );

    expect(controller.document?.metadata.name, 'Updated');
    expect(controller.hasUnsavedChanges, isTrue);
  });

  test('save success clears dirty state', () async {
    await controller.load();
    await controller.updateMetadata(
      controller.document!.metadata.copyWith(name: 'Saved Name'),
    );

    final result = await controller.save();

    expect(result.success, isTrue);
    expect(controller.hasUnsavedChanges, isFalse);
    expect(controller.document?.lastSavedAt, isNotNull);
  });

  test('save failure preserves dirty document', () async {
    final failingController = createController(failSave: true);
    await failingController.load();
    await failingController.updateMetadata(
      failingController.document!.metadata.copyWith(name: 'Dirty Name'),
    );

    final result = await failingController.save();

    expect(result.success, isFalse);
    expect(failingController.hasUnsavedChanges, isTrue);
    expect(failingController.document?.metadata.name, 'Dirty Name');
  });

  test('add week keeps contiguous numbering', () async {
    await controller.load();
    await controller.addWeek();

    final weekNumbers =
        controller.document!.template.allWeeks.map((w) => w.weekNumber);
    expect(weekNumbers, [1, 2]);
  });

  test('rest conversion clears slots through service edit', () async {
    await controller.load();
    final dayId =
        controller.document!.template.allWeeks.single.days.single.localId;
    await controller.setDayType(
      dayLocalId: dayId,
      dayType: ProgrammeDayType.rest,
    );

    final day = controller.document!.template.allWeeks.single.days.single;
    expect(day.dayType, ProgrammeDayType.rest);
    expect(day.slots, isEmpty);
  });

  test('protocol assign replace and clear', () async {
    await controller.load();
    final slotId = controller
        .document!.template.allWeeks.single.days.single.slots.single.localId;
    await controller.assignProtocol(
      slotLocalId: slotId,
      protocolId: 'BW-002',
    );
    expect(
      controller.document!.template.allWeeks.single.days.single.slots.single
          .protocolId,
      'BW-002',
    );

    await controller.clearProtocol(slotId);
    expect(
      controller.document!.template.allWeeks.single.days.single.slots.single
          .protocolId,
      '',
    );
  });

  test('validation path selection updates selection', () async {
    await controller.load();
    final weekId = controller.document!.template.allWeeks.single.localId;
    final dayId =
        controller.document!.template.allWeeks.single.days.single.localId;
    final slotId = controller.document!.template.allWeeks.single.days.single
        .slots.single.localId;

    controller.selectPath(
      ProgrammeBuilderSlotPath(
        weekLocalId: weekId,
        dayLocalId: dayId,
        slotLocalId: slotId,
      ),
    );

    expect(controller.selection.slotLocalId, slotId);
    expect(controller.selection.dayLocalId, dayId);
    expect(controller.selection.weekLocalId, weekId);
  });

  test('undo and redo restore document', () async {
    await controller.load();
    final originalName = controller.document!.metadata.name;

    await controller.updateMetadata(
      controller.document!.metadata.copyWith(name: 'Changed'),
    );
    controller.undo();

    expect(controller.document?.metadata.name, originalName);

    controller.redo();
    expect(controller.document?.metadata.name, 'Changed');
  });

  test('history is bounded to max depth', () async {
    final boundedHistory = ProgrammeBuilderHistory(maxDepth: 2);
    final boundedController = ProgrammeEditorController(
      builderService: builderService,
      validationService: validationService,
      publishCoordinator: ProgrammeBuilderPublishCoordinatorImpl(
        builderService: builderService,
        publishingService: ProgrammePublishingServiceImpl(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        validationService: validationService,
      ),
      previewService: previewService,
      protocolPickerService: pickerService,
      protocolNameResolver: nameResolver,
      coachId: coachId,
      versionId: versionId,
      history: boundedHistory,
    );

    await boundedController.load();
    for (var i = 0; i < 4; i++) {
      await boundedController.updateMetadata(
        boundedController.document!.metadata.copyWith(name: 'Name $i'),
      );
    }

    expect(boundedController.history.undoDepth, lessThanOrEqualTo(2));
  });

  test('published document loads read-only', () async {
    tables.versions[0] = tables.versions[0].copyWith(
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      publishedAt: DateTime.utc(2026, 7, 16),
    );

    await controller.load();

    expect(controller.viewState, ProgrammeEditorViewState.readOnly);
    expect(controller.isReadOnly, isTrue);
  });

  test('round-trip save and reload preserves slot protocol', () async {
    await controller.load();
    await controller.assignProtocol(
      slotLocalId: controller.document!.template.allWeeks.single.days.single
          .slots
          .single
          .localId,
      protocolId: 'BW-009',
    );
    await controller.save();

    final reloaded = createController();
    await reloaded.load();

    final slot = reloaded.document!.template.allWeeks.single.days.single.slots
        .single;
    expect(slot.protocolId, 'BW-009');
  });

  test('preview uses preview service', () async {
    await controller.load();
    final preview = await controller.buildPreview();

    expect(preview, isNotNull);
    expect(preview!.programmeName, 'Foundation Test');
  });
}

class FakeProtocolPickerService implements ProgrammeBuilderProtocolPickerService {
  @override
  Future<ProgrammeBuilderProtocolOption?> getById(String protocolId) async {
    return ProgrammeBuilderProtocolOption(
      protocolId: protocolId,
      name: 'Protocol $protocolId',
    );
  }

  @override
  Future<List<ProgrammeBuilderProtocolOption>> listSelectableProtocols({
    String? searchTerm,
    int limit = 50,
  }) async {
    final options = [
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-001',
        name: 'Bodyweight Grinder',
        sessionType: 'strength',
        durationMin: 45,
      ),
      const ProgrammeBuilderProtocolOption(
        protocolId: 'BW-002',
        name: 'Mobility Flow',
        sessionType: 'mobility',
        durationMin: 30,
      ),
    ];

    final term = searchTerm?.trim().toLowerCase();
    if (term == null || term.isEmpty) return options;

    return options
        .where(
          (option) =>
              option.name.toLowerCase().contains(term) ||
              option.protocolId.toLowerCase().contains(term),
        )
        .toList();
  }
}

class FakeProtocolNameResolver implements ProgrammeBuilderProtocolNameResolver {
  @override
  Future<Map<String, String>> resolveNames(Set<String> protocolIds) async {
    return {
      for (final id in protocolIds) id: 'Protocol $id',
    };
  }
}

class FakePreviewService implements ProgrammeBuilderPreviewService {
  @override
  Future<ProgrammeBuilderPreview> buildPreview(
    ProgrammeBuilderDocument document, {
    Map<String, String> protocolNamesById = const {},
  }) async {
    return ProgrammeBuilderPreview(
      programmeName: document.metadata.name,
      lineageCode: document.metadata.lineageCode,
      versionNumber: document.metadata.versionNumber,
      weeks: const [],
    );
  }
}

class FailingSaveBuilderService implements ProgrammeBuilderService {
  FailingSaveBuilderService(this._delegate);

  final ProgrammeBuilderService _delegate;

  @override
  Future<ProgrammeBuilderEditResult> addDay(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) =>
      _delegate.addDay(document, weekLocalId: weekLocalId);

  @override
  Future<ProgrammeBuilderEditResult> addSlot(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) =>
      _delegate.addSlot(document, dayLocalId: dayLocalId);

  @override
  Future<ProgrammeBuilderEditResult> addWeek(ProgrammeBuilderDocument document) =>
      _delegate.addWeek(document);

  @override
  Future<ProgrammeBuilderEditResult> assignProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  }) =>
      _delegate.assignProtocol(
        document,
        slotLocalId: slotLocalId,
        protocolId: protocolId,
        displayTitle: displayTitle,
      );

  @override
  Future<ProgrammeBuilderEditResult> clearProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) =>
      _delegate.clearProtocol(document, slotLocalId: slotLocalId);

  @override
  Future<ProgrammeBuilderOperationResult> createDraftProgramme({
    required String coachId,
    required ProgrammeVersionDraftMetadata seedMetadata,
    seedTemplate = ProgrammeSeedTemplate.empty,
  }) =>
      _delegate.createDraftProgramme(
        coachId: coachId,
        seedMetadata: seedMetadata,
        seedTemplate: seedTemplate,
      );

  @override
  Future<ProgrammeBuilderOperationResult> deleteDraft({
    required String versionId,
    required String coachId,
  }) =>
      _delegate.deleteDraft(versionId: versionId, coachId: coachId);

  @override
  Future<ProgrammeBuilderEditResult> duplicateWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) =>
      _delegate.duplicateWeek(document, weekLocalId: weekLocalId);

  @override
  Future<ProgrammeBuilderOperationResult> duplicateProgramme({
    required String sourceVersionId,
    required String coachId,
    required String newLineageCode,
    required String newProgrammeName,
  }) =>
      _delegate.duplicateProgramme(
        sourceVersionId: sourceVersionId,
        coachId: coachId,
        newLineageCode: newLineageCode,
        newProgrammeName: newProgrammeName,
      );

  @override
  Future<ProgrammeBuilderDocument> loadDocument({required String versionId}) =>
      _delegate.loadDocument(versionId: versionId);

  @override
  Future<List<ProgrammeCatalogEntry>> listCoachDrafts({required String coachId}) =>
      _delegate.listCoachDrafts(coachId: coachId);

  @override
  Future<ProgrammeBuilderEditResult> removeDay(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) =>
      _delegate.removeDay(document, dayLocalId: dayLocalId);

  @override
  Future<ProgrammeBuilderEditResult> removeSlot(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) =>
      _delegate.removeSlot(document, slotLocalId: slotLocalId);

  @override
  Future<ProgrammeBuilderEditResult> removeWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) =>
      _delegate.removeWeek(document, weekLocalId: weekLocalId);

  @override
  ProgrammeBuilderEditResult? redo(ProgrammeBuilderDocument document) =>
      _delegate.redo(document);

  @override
  Future<ProgrammeBuilderOperationResult> saveDocument(
    ProgrammeBuilderDocument document,
  ) async {
    return ProgrammeBuilderOperationResult(
      status: ProgrammeBuilderOperationStatus.storeFailed,
      document: document,
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> setDayType(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    required ProgrammeDayType dayType,
  }) =>
      _delegate.setDayType(
        document,
        dayLocalId: dayLocalId,
        dayType: dayType,
      );

  @override
  ProgrammeBuilderEditResult? undo(ProgrammeBuilderDocument document) =>
      _delegate.undo(document);

  @override
  Future<ProgrammeBuilderEditResult> updateDayMetadata(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    String? title,
    ProgrammeIntent? intent,
    bool clearTitle = false,
    bool clearIntent = false,
  }) =>
      _delegate.updateDayMetadata(
        document,
        dayLocalId: dayLocalId,
        title: title,
        intent: intent,
        clearTitle: clearTitle,
        clearIntent: clearIntent,
      );

  @override
  Future<ProgrammeBuilderEditResult> updateMetadata(
    ProgrammeBuilderDocument document,
    ProgrammeVersionDraftMetadata metadata,
  ) =>
      _delegate.updateMetadata(document, metadata);

  @override
  Future<ProgrammeBuilderEditResult> updateSlotMetadata(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    String? displayTitle,
    ProgrammeSessionTimeOfDay? timeOfDay,
    bool? isOptional,
    ProgrammeSessionCompletionExpectation? completionExpectation,
    String? coachNote,
    String? athleteNote,
    bool clearDisplayTitle = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) =>
      _delegate.updateSlotMetadata(
        document,
        slotLocalId: slotLocalId,
        displayTitle: displayTitle,
        timeOfDay: timeOfDay,
        isOptional: isOptional,
        completionExpectation: completionExpectation,
        coachNote: coachNote,
        athleteNote: athleteNote,
        clearDisplayTitle: clearDisplayTitle,
        clearCoachNote: clearCoachNote,
        clearAthleteNote: clearAthleteNote,
      );
}
