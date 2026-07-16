import 'package:flutter/foundation.dart';

import '../../../../data/repositories/programme_store_exception.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme/models/programme_catalog_entry.dart';
import '../../../programme/services/programme_catalog_service.dart';
import '../../../programme/services/programme_publishing_service.dart';
import '../../../programme_builder/diagnostics/programme_create_diagnostics.dart';
import '../../../programme_builder/models/programme_builder_operation_result.dart';
import '../../../programme_builder/models/programme_seed_template.dart';
import '../../../programme_builder/models/programme_version_draft_metadata.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator.dart';
import '../../../programme_builder/services/programme_builder_service.dart';
import '../../../programme_builder/services/programme_builder_validation_service.dart';
import '../models/programme_catalogue_action.dart';
import '../models/programme_catalogue_sort_mode.dart';
import '../models/programme_catalogue_tab.dart';
import '../models/programme_catalogue_view_state.dart';
import '../utils/programme_catalogue_list_processor.dart';

/// Screen-level orchestration for Programme Catalogue.
///
/// Services only — no Supabase imports.
class ProgrammeCatalogueController {
  ProgrammeCatalogueController({
    required ProgrammeBuilderService builderService,
    required ProgrammeCatalogService catalogService,
    required ProgrammeBuilderPublishCoordinator publishCoordinator,
    required ProgrammePublishingService publishingService,
    required ProgrammeBuilderValidationService validationService,
    required String coachId,
    ProgrammeCatalogueListProcessor listProcessor =
        const ProgrammeCatalogueListProcessor(),
  })  : _builderService = builderService,
        _catalogService = catalogService,
        _publishCoordinator = publishCoordinator,
        _publishingService = publishingService,
        _validationService = validationService,
        _coachId = coachId,
        _listProcessor = listProcessor;

  final ProgrammeBuilderService _builderService;
  final ProgrammeCatalogService _catalogService;
  final ProgrammeBuilderPublishCoordinator _publishCoordinator;
  final ProgrammePublishingService _publishingService;
  final ProgrammeBuilderValidationService _validationService;
  final String _coachId;
  final ProgrammeCatalogueListProcessor _listProcessor;

  final List<VoidCallback> _listeners = [];

  ProgrammeCatalogueTab activeTab = ProgrammeCatalogueTab.drafts;
  ProgrammeCatalogueViewState viewState = ProgrammeCatalogueViewState.loading;
  List<ProgrammeCatalogEntry> loadedEntries = [];
  String searchTerm = '';
  ProgrammeLibraryScope? libraryScopeFilter;
  String? primaryGoalFilter;
  ProgrammeCatalogueSortMode sortMode = ProgrammeCatalogueSortMode.lastEdited;
  String? actionInProgressVersionId;
  String? errorMessage;
  DateTime? lastRefreshedAt;

  final Map<ProgrammeCatalogueTab, List<ProgrammeCatalogEntry>> _tabCache = {};

  List<ProgrammeCatalogEntry> get displayedEntries {
    var entries = loadedEntries;

    if (libraryScopeFilter != null) {
      entries = entries
          .where((entry) => entry.libraryScope == libraryScopeFilter)
          .toList();
    }

    return _listProcessor.apply(
      entries: entries,
      searchTerm: searchTerm,
      primaryGoal: primaryGoalFilter,
      sortMode: sortMode,
    );
  }

  List<String> get availablePrimaryGoals {
    final goals = loadedEntries
        .map((entry) => entry.primaryGoal?.trim())
        .whereType<String>()
        .where((goal) => goal.isNotEmpty)
        .toSet()
        .toList();
    goals.sort();
    return goals;
  }

  bool get isActionInProgress => actionInProgressVersionId != null;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  Future<void> loadTab(ProgrammeCatalogueTab tab) async {
    activeTab = tab;
    viewState = ProgrammeCatalogueViewState.loading;
    errorMessage = null;
    _notify();

    try {
      final entries = await _fetchEntriesForTab(tab);
      _tabCache[tab] = entries;
      loadedEntries = entries;
      lastRefreshedAt = DateTime.now();
      viewState =
          entries.isEmpty ? ProgrammeCatalogueViewState.empty : ProgrammeCatalogueViewState.ready;
      errorMessage = null;
    } on ProgrammeStoreException catch (error) {
      loadedEntries = [];
      errorMessage = error.message;
      viewState = error.isAccessDenied
          ? ProgrammeCatalogueViewState.permissionDenied
          : ProgrammeCatalogueViewState.error;
    } catch (error) {
      loadedEntries = [];
      errorMessage = error.toString();
      viewState = ProgrammeCatalogueViewState.error;
    }

    _notify();
  }

  Future<void> refreshCurrentTab() => loadTab(activeTab);

  void setSearchTerm(String value) {
    searchTerm = value;
    _notify();
  }

  void setScopeFilter(ProgrammeLibraryScope? scope) {
    libraryScopeFilter = scope;
    _notify();
  }

  void setPrimaryGoalFilter(String? goal) {
    primaryGoalFilter = goal;
    _notify();
  }

  void setSortMode(ProgrammeCatalogueSortMode mode) {
    sortMode = mode;
    _notify();
  }

  Future<ProgrammeCatalogueActionResult> runAction({
    required ProgrammeCatalogueAction action,
    required ProgrammeCatalogEntry entry,
  }) async {
    switch (action) {
      case ProgrammeCatalogueAction.open:
        return openDraft(entry.versionId);
      case ProgrammeCatalogueAction.validate:
        return _validateDraft(entry.versionId);
      case ProgrammeCatalogueAction.publish:
        return _publishDraft(entry.versionId);
      case ProgrammeCatalogueAction.preview:
        return previewPublished(entry.versionId);
      case ProgrammeCatalogueAction.cloneVersion:
        return cloneVersion(entry.versionId);
      case ProgrammeCatalogueAction.duplicateProgramme:
        return ProgrammeCatalogueActionResult(
          action: action,
          success: false,
          message: 'Duplicate requires programme name and lineage code.',
        );
      case ProgrammeCatalogueAction.archive:
        return archiveVersion(entry.versionId);
      case ProgrammeCatalogueAction.deleteDraft:
        return deleteDraft(entry.versionId);
    }
  }

  Future<ProgrammeCatalogueActionResult> createProgramme({
    required ProgrammeVersionDraftMetadata metadata,
    ProgrammeSeedTemplate seedTemplate = ProgrammeSeedTemplate.empty,
  }) async {
    ProgrammeCreateDiagnostics.log('controller start');
    ProgrammeCreateDiagnostics.log('name=${metadata.name}');
    ProgrammeCreateDiagnostics.log('lineage=${metadata.lineageCode}');
    ProgrammeCreateDiagnostics.log('seedTemplate=${seedTemplate.name}');

    if (isActionInProgress) {
      return const ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.open,
        success: false,
        message: 'Another action is in progress.',
      );
    }

    actionInProgressVersionId = '__create__';
    _notify();

    try {
      final result = await _builderService.createDraftProgramme(
        coachId: _coachId,
        seedMetadata: metadata,
        seedTemplate: seedTemplate,
      );

      ProgrammeCreateDiagnostics.logOperationResult(result);

      if (!result.isSuccess || result.document == null) {
        final actionResult = ProgrammeCatalogueActionResult(
          action: ProgrammeCatalogueAction.open,
          success: false,
          message: _operationMessage(result),
          warnings: result.warnings,
          debugDetail: ProgrammeCreateDiagnostics.debugDetailFromOperationResult(
            result,
          ),
        );
        ProgrammeCreateDiagnostics.log(
          'controller failure message=${actionResult.message}',
        );
        if (actionResult.debugDetail != null) {
          ProgrammeCreateDiagnostics.log(
            'controller debugDetail=${actionResult.debugDetail}',
          );
        }
        return actionResult;
      }

      await refreshCurrentTab();

      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.open,
        success: true,
        versionId: result.document!.metadata.versionId,
        navigateToEditor: true,
        refreshTab: true,
      );
    } on ProgrammeStoreException catch (error, stackTrace) {
      ProgrammeCreateDiagnostics.logException(
        error,
        stackTrace: stackTrace,
        stage: 'controller.createProgramme',
      );
      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.open,
        success: false,
        message: error.message,
        warnings: ProgrammeCreateDiagnostics.warningsFromStoreException(error),
        debugDetail: ProgrammeCreateDiagnostics.debugDetailFromStoreException(
          error,
        ),
      );
    } catch (error, stackTrace) {
      ProgrammeCreateDiagnostics.logException(
        error,
        stackTrace: stackTrace,
        stage: 'controller.createProgramme(unexpected)',
      );
      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.open,
        success: false,
        message: 'Programme action failed.',
        warnings: ['message=$error'],
        debugDetail: 'message=$error',
      );
    } finally {
      actionInProgressVersionId = null;
      _notify();
    }
  }

  Future<ProgrammeCatalogueActionResult> openDraft(String versionId) {
    return Future.value(
      ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.open,
        success: true,
        versionId: versionId,
        navigateToEditor: true,
      ),
    );
  }

  Future<ProgrammeCatalogueActionResult> previewPublished(String versionId) {
    return Future.value(
      ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.preview,
        success: true,
        versionId: versionId,
      ),
    );
  }

  Future<ProgrammeCatalogueActionResult> cloneVersion(String versionId) async {
    return _runVersionAction(
      action: ProgrammeCatalogueAction.cloneVersion,
      versionId: versionId,
      operation: () => _publishCoordinator.cloneVersion(
        publishedVersionId: versionId,
        coachId: _coachId,
      ),
      refreshTab: ProgrammeCatalogueTab.drafts,
    );
  }

  Future<ProgrammeCatalogueActionResult> duplicateProgramme({
    required String sourceVersionId,
    required String newLineageCode,
    required String newProgrammeName,
  }) async {
    return _runVersionAction(
      action: ProgrammeCatalogueAction.duplicateProgramme,
      versionId: sourceVersionId,
      operation: () => _builderService.duplicateProgramme(
        sourceVersionId: sourceVersionId,
        coachId: _coachId,
        newLineageCode: newLineageCode,
        newProgrammeName: newProgrammeName,
      ),
      refreshTab: ProgrammeCatalogueTab.drafts,
    );
  }

  Future<ProgrammeCatalogueActionResult> archiveVersion(String versionId) async {
    if (isActionInProgress) {
      return _busyResult(ProgrammeCatalogueAction.archive);
    }

    actionInProgressVersionId = versionId;
    _notify();

    try {
      await _publishingService.archiveVersion(versionId);
      activeTab = ProgrammeCatalogueTab.archived;
      await loadTab(ProgrammeCatalogueTab.archived);

      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.archive,
        success: true,
        versionId: versionId,
        refreshTab: true,
        message: 'Programme archived.',
      );
    } on ProgrammeStoreException catch (error) {
      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.archive,
        success: false,
        versionId: versionId,
        message: error.message,
      );
    } finally {
      actionInProgressVersionId = null;
      _notify();
    }
  }

  Future<ProgrammeCatalogueActionResult> deleteDraft(String versionId) async {
    return _runVersionAction(
      action: ProgrammeCatalogueAction.deleteDraft,
      versionId: versionId,
      operation: () => _builderService.deleteDraft(
        versionId: versionId,
        coachId: _coachId,
      ),
      refreshTab: activeTab,
    );
  }

  Future<ProgrammeCatalogueActionResult> _validateDraft(String versionId) async {
    if (isActionInProgress) {
      return _busyResult(ProgrammeCatalogueAction.validate);
    }

    actionInProgressVersionId = versionId;
    _notify();

    try {
      final document = await _builderService.loadDocument(versionId: versionId);
      final validation = _validationService.validate(document);
      final readiness = _validationService.buildPublishReadiness(
        document,
        validation: validation,
      );

      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.validate,
        success: true,
        versionId: versionId,
        message: readiness.isReady
            ? 'Ready to publish.'
            : '${readiness.blockingIssueCount} blocking issue(s) found.',
      );
    } on ProgrammeStoreException catch (error) {
      return ProgrammeCatalogueActionResult(
        action: ProgrammeCatalogueAction.validate,
        success: false,
        versionId: versionId,
        message: error.message,
      );
    } finally {
      actionInProgressVersionId = null;
      _notify();
    }
  }

  Future<ProgrammeCatalogueActionResult> _publishDraft(String versionId) async {
    return _runVersionAction(
      action: ProgrammeCatalogueAction.publish,
      versionId: versionId,
      operation: () async {
        final document = await _builderService.loadDocument(versionId: versionId);
        return _publishCoordinator.publish(
          document: document,
          coachId: _coachId,
        );
      },
      refreshTab: ProgrammeCatalogueTab.published,
      switchTabOnSuccess: ProgrammeCatalogueTab.published,
    );
  }

  Future<ProgrammeCatalogueActionResult> _runVersionAction({
    required ProgrammeCatalogueAction action,
    required String versionId,
    required Future<ProgrammeBuilderOperationResult> Function() operation,
    ProgrammeCatalogueTab? refreshTab,
    ProgrammeCatalogueTab? switchTabOnSuccess,
  }) async {
    if (isActionInProgress) {
      return _busyResult(action);
    }

    actionInProgressVersionId = versionId;
    _notify();

    try {
      final result = await operation();

      if (!result.isSuccess) {
        return ProgrammeCatalogueActionResult(
          action: action,
          success: false,
          versionId: versionId,
          message: _operationMessage(result),
        );
      }

      if (switchTabOnSuccess != null) {
        activeTab = switchTabOnSuccess;
      }

      if (refreshTab != null) {
        await loadTab(refreshTab);
      } else {
        await refreshCurrentTab();
      }

      final navigate = action == ProgrammeCatalogueAction.cloneVersion ||
          action == ProgrammeCatalogueAction.duplicateProgramme;

      return ProgrammeCatalogueActionResult(
        action: action,
        success: true,
        versionId: result.document?.metadata.versionId ?? versionId,
        navigateToEditor: navigate,
        refreshTab: true,
        message: _successMessage(action),
      );
    } on ProgrammeStoreException catch (error) {
      return ProgrammeCatalogueActionResult(
        action: action,
        success: false,
        versionId: versionId,
        message: error.message,
      );
    } finally {
      actionInProgressVersionId = null;
      _notify();
    }
  }

  Future<List<ProgrammeCatalogEntry>> _fetchEntriesForTab(
    ProgrammeCatalogueTab tab,
  ) {
    return switch (tab) {
      ProgrammeCatalogueTab.drafts =>
        _builderService.listCoachDrafts(coachId: _coachId),
      ProgrammeCatalogueTab.published => _catalogService.listCatalogue(
          query: ProgrammeCatalogueQuery(
            ownerType: ProgrammeOwnerType.coach,
            ownerId: _coachId,
            lifecycleStatus: ProgrammeLifecycleStatus.published,
          ),
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
      ProgrammeCatalogueTab.cohortGlobal => _catalogService.listCatalogue(
          query: const ProgrammeCatalogueQuery(
            includeGlobalApprovedOnly: true,
            lifecycleStatus: ProgrammeLifecycleStatus.published,
          ),
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
      ProgrammeCatalogueTab.archived => _catalogService.listCatalogue(
          query: ProgrammeCatalogueQuery(
            ownerType: ProgrammeOwnerType.coach,
            ownerId: _coachId,
            lifecycleStatus: ProgrammeLifecycleStatus.archived,
          ),
          lifecycleStatus: ProgrammeLifecycleStatus.archived,
        ),
    };
  }

  ProgrammeCatalogueActionResult _busyResult(ProgrammeCatalogueAction action) {
    return ProgrammeCatalogueActionResult(
      action: action,
      success: false,
      message: 'Another action is in progress.',
    );
  }

  String _operationMessage(ProgrammeBuilderOperationResult result) {
    if (result.status == ProgrammeBuilderOperationStatus.storeFailed &&
        result.warnings.isNotEmpty) {
      // User-facing message stays generic; warnings flow to debugDetail.
      return 'We could not save programme changes right now.';
    }

    return switch (result.status) {
      ProgrammeBuilderOperationStatus.validationFailed =>
        'Validation failed. Resolve blocking issues first.',
      ProgrammeBuilderOperationStatus.notReady =>
        'Programme is not ready to publish.',
      ProgrammeBuilderOperationStatus.notEditable =>
        'This programme cannot be edited or deleted.',
      ProgrammeBuilderOperationStatus.storeFailed =>
        'We could not save programme changes right now.',
      _ => 'Programme action failed.',
    };
  }

  String _successMessage(ProgrammeCatalogueAction action) {
    return switch (action) {
      ProgrammeCatalogueAction.publish => 'Programme published.',
      ProgrammeCatalogueAction.cloneVersion => 'Cloned to new draft version.',
      ProgrammeCatalogueAction.duplicateProgramme =>
        'Duplicated into a new programme lineage.',
      ProgrammeCatalogueAction.deleteDraft => 'Draft deleted.',
      _ => 'Done.',
    };
  }
}
