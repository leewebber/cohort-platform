import 'package:flutter/foundation.dart';

import '../../../../data/repositories/programme_store_exception.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme_builder/models/programme_builder_constants.dart';
import '../../../programme_builder/models/programme_builder_document.dart';
import '../../../programme_builder/models/programme_builder_history.dart';
import '../../../programme_builder/models/programme_builder_operation_result.dart';
import '../../../programme_builder/models/programme_builder_path.dart';
import '../../../programme_builder/models/programme_builder_preview.dart';
import '../../../programme_builder/models/programme_publish_readiness.dart';
import '../../../programme_builder/models/programme_validation_result.dart';
import '../../../programme_builder/models/programme_version_draft_metadata.dart';
import '../../../programme_builder/services/programme_builder_preview_service.dart';
import '../../../programme_builder/services/programme_builder_protocol_name_resolver.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator.dart';
import '../../../programme_builder/services/programme_builder_service.dart';
import '../../../programme_builder/services/programme_builder_validation_service.dart';
import '../models/programme_editor_selection.dart';
import '../models/programme_editor_view_state.dart';

/// Result of an editor save attempt.
class ProgrammeEditorSaveResult {
  const ProgrammeEditorSaveResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

/// Result of an editor publish attempt.
class ProgrammeEditorPublishResult {
  const ProgrammeEditorPublishResult({
    required this.success,
    this.message,
    this.publishedVersionId,
  });

  final bool success;
  final String? message;
  final String? publishedVersionId;
}

/// Screen-level orchestration for Programme Editor.
///
/// Owns document, selection, history, validation, and save state.
/// No Supabase imports.
class ProgrammeEditorController {
  ProgrammeEditorController({
    required ProgrammeBuilderService builderService,
    required ProgrammeBuilderValidationService validationService,
    required ProgrammeBuilderPublishCoordinator publishCoordinator,
    required ProgrammeBuilderPreviewService previewService,
    required ProgrammeBuilderProtocolPickerService protocolPickerService,
    required ProgrammeBuilderProtocolNameResolver protocolNameResolver,
    required String coachId,
    required String versionId,
    ProgrammeBuilderHistory? history,
  })  : _builderService = builderService,
        _validationService = validationService,
        _publishCoordinator = publishCoordinator,
        _previewService = previewService,
        _protocolPickerService = protocolPickerService,
        _protocolNameResolver = protocolNameResolver,
        _coachId = coachId,
        _versionId = versionId,
        history = history ?? ProgrammeBuilderHistory();

  final ProgrammeBuilderService _builderService;
  final ProgrammeBuilderValidationService _validationService;
  final ProgrammeBuilderPublishCoordinator _publishCoordinator;
  final ProgrammeBuilderPreviewService _previewService;
  final ProgrammeBuilderProtocolPickerService _protocolPickerService;
  final ProgrammeBuilderProtocolNameResolver _protocolNameResolver;
  final String _coachId;
  final String _versionId;

  final ProgrammeBuilderHistory history;
  final List<VoidCallback> _listeners = [];

  ProgrammeBuilderDocument? document;
  ProgrammeValidationResult? validation;
  ProgrammePublishReadiness? publishReadiness;
  ProgrammeEditorSelection selection = const ProgrammeEditorSelection();
  ProgrammeEditorViewState viewState = ProgrammeEditorViewState.loading;
  bool isSaving = false;
  String? errorMessage;

  bool get isReadOnly =>
      viewState == ProgrammeEditorViewState.readOnly ||
      (document != null && !document!.isEditable);

  bool get canUndo => history.canUndo && !isReadOnly;

  bool get canRedo => history.canRedo && !isReadOnly;

  bool get hasUnsavedChanges => document?.hasUnsavedChanges ?? false;

  ProgrammeBuilderService get builderService => _builderService;

  String get versionId => _versionId;

  bool get canPublish =>
      !isReadOnly &&
      !isSaving &&
      (publishReadiness?.isReady ?? false);

  ProgrammeEditorSelection get selectionState => selection;

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  Future<void> load() async {
    viewState = ProgrammeEditorViewState.loading;
    errorMessage = null;
    _notify();

    try {
      final loaded = await _builderService.loadDocument(versionId: _versionId);
      document = loaded;
      history.clear();
      validation = _validationService.validate(loaded);
      publishReadiness = null;
      selection = _defaultSelection(loaded);
      viewState = loaded.isEditable
          ? ProgrammeEditorViewState.ready
          : ProgrammeEditorViewState.readOnly;
      errorMessage = null;
    } on ProgrammeStoreException catch (error) {
      document = null;
      errorMessage = error.message;
      viewState = ProgrammeEditorViewState.error;
    } catch (error) {
      document = null;
      errorMessage = 'Could not load programme.';
      viewState = ProgrammeEditorViewState.error;
    }

    _notify();
  }

  ProgrammeEditorSelection _defaultSelection(ProgrammeBuilderDocument doc) {
    final weeks = doc.template.allWeeks;
    if (weeks.isEmpty) return const ProgrammeEditorSelection();

    final week = weeks.first;
    final day = week.days.isEmpty ? null : week.days.first;
    final slot = day == null || day.slots.isEmpty ? null : day.slots.first;

    return ProgrammeEditorSelection(
      weekLocalId: week.localId,
      dayLocalId: day?.localId,
      slotLocalId: slot?.localId,
    );
  }

  Future<ProgrammeEditorSaveResult> save() async {
    final current = document;
    if (current == null || isSaving || isReadOnly) {
      return const ProgrammeEditorSaveResult(success: false);
    }

    isSaving = true;
    viewState = ProgrammeEditorViewState.saving;
    _notify();

    final result = await _builderService.saveDocument(current);

    isSaving = false;

    if (result.isSuccess && result.document != null) {
      document = result.document;
      validation = _validationService.validate(result.document!);
      publishReadiness = null;
      viewState = result.document!.isEditable
          ? ProgrammeEditorViewState.ready
          : ProgrammeEditorViewState.readOnly;
      _notify();
      return const ProgrammeEditorSaveResult(success: true);
    }

    viewState = current.isEditable
        ? ProgrammeEditorViewState.ready
        : ProgrammeEditorViewState.readOnly;
    errorMessage = 'Save failed. Your local changes are preserved.';
    _notify();
    return ProgrammeEditorSaveResult(
      success: false,
      message: errorMessage,
    );
  }

  Future<void> validate() async {
    final current = document;
    if (current == null) return;

    validation = _validationService.validate(current);
    publishReadiness = _publishCoordinator.validateReadiness(
      current,
      knownProtocolIds: _knownProtocolIds(current),
    );
    _notify();
  }

  Future<ProgrammeEditorPublishResult> publish() async {
    final current = document;
    if (current == null || isReadOnly || isSaving) {
      return const ProgrammeEditorPublishResult(success: false);
    }

    await validate();
    if (!(publishReadiness?.isReady ?? false)) {
      return ProgrammeEditorPublishResult(
        success: false,
        message: 'Resolve validation errors before publishing.',
      );
    }

    isSaving = true;
    viewState = ProgrammeEditorViewState.saving;
    _notify();

    final result = await _publishCoordinator.publish(
      document: current,
      coachId: _coachId,
      knownProtocolIds: _knownProtocolIds(current),
    );

    isSaving = false;

    if (result.status == ProgrammeBuilderOperationStatus.published &&
        result.document != null) {
      document = result.document;
      history.clear();
      validation = _validationService.validate(result.document!);
      publishReadiness = null;
      viewState = ProgrammeEditorViewState.readOnly;
      _notify();
      return ProgrammeEditorPublishResult(
        success: true,
        publishedVersionId: result.publishedVersionId,
      );
    }

    viewState = current.isEditable
        ? ProgrammeEditorViewState.ready
        : ProgrammeEditorViewState.readOnly;
    errorMessage = _publishErrorMessage(result);
    _notify();
    return ProgrammeEditorPublishResult(
      success: false,
      message: errorMessage,
    );
  }

  String _publishErrorMessage(ProgrammeBuilderOperationResult result) {
    return switch (result.status) {
      ProgrammeBuilderOperationStatus.notReady =>
        'Resolve validation errors before publishing.',
      ProgrammeBuilderOperationStatus.storeFailed =>
        'Publish failed. Try saving first.',
      ProgrammeBuilderOperationStatus.notEditable =>
        'This programme cannot be published.',
      _ => 'Publish failed.',
    };
  }

  Future<ProgrammeBuilderPreview?> buildPreview() async {
    final current = document;
    if (current == null) return null;

    final names = await _protocolNameResolver.resolveNames(
      _assignedProtocolIds(current),
    );

    return _previewService.buildPreview(
      current,
      protocolNamesById: names,
    );
  }

  Future<void> addWeek() => _applyEdit(
        () => _builderService.addWeek(document!),
      );

  Future<void> duplicateWeek(String weekLocalId) => _applyEdit(
        () => _builderService.duplicateWeek(
          document!,
          weekLocalId: weekLocalId,
        ),
      );

  Future<void> removeWeek(String weekLocalId) => _applyEdit(
        () => _builderService.removeWeek(
          document!,
          weekLocalId: weekLocalId,
        ),
        onApplied: () {
          final weeks = document!.template.allWeeks;
          if (weeks.isEmpty) {
            selection = const ProgrammeEditorSelection();
            return;
          }
          if (!weeks.any((week) => week.localId == selection.weekLocalId)) {
            selection = ProgrammeEditorSelection(weekLocalId: weeks.first.localId);
          }
        },
      );

  Future<void> addDay(String weekLocalId) => _applyEdit(
        () => _builderService.addDay(
          document!,
          weekLocalId: weekLocalId,
        ),
      );

  Future<void> removeDay(String dayLocalId) => _applyEdit(
        () => _builderService.removeDay(
          document!,
          dayLocalId: dayLocalId,
        ),
        onApplied: () {
          if (selection.dayLocalId == dayLocalId) {
            selection = selection.copyWith(clearDay: true, clearSlot: true);
          }
        },
      );

  Future<void> updateDayMetadata({
    required String dayLocalId,
    String? title,
    ProgrammeIntent? intent,
    bool clearTitle = false,
    bool clearIntent = false,
  }) =>
      _applyEdit(
        () => _builderService.updateDayMetadata(
          document!,
          dayLocalId: dayLocalId,
          title: title,
          intent: intent,
          clearTitle: clearTitle,
          clearIntent: clearIntent,
        ),
      );

  Future<void> setDayType({
    required String dayLocalId,
    required ProgrammeDayType dayType,
  }) =>
      _applyEdit(
        () => _builderService.setDayType(
          document!,
          dayLocalId: dayLocalId,
          dayType: dayType,
        ),
        onApplied: () {
          if (dayType == ProgrammeDayType.rest &&
              selection.dayLocalId == dayLocalId) {
            selection = selection.copyWith(clearSlot: true);
          }
        },
      );

  Future<void> addSlot(String dayLocalId) => _applyEdit(
        () => _builderService.addSlot(
          document!,
          dayLocalId: dayLocalId,
        ),
      );

  Future<void> removeSlot(String slotLocalId) => _applyEdit(
        () => _builderService.removeSlot(
          document!,
          slotLocalId: slotLocalId,
        ),
        onApplied: () {
          if (selection.slotLocalId == slotLocalId) {
            selection = selection.copyWith(clearSlot: true);
          }
        },
      );

  Future<void> assignProtocol({
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  }) =>
      _applyEdit(
        () => _builderService.assignProtocol(
          document!,
          slotLocalId: slotLocalId,
          protocolId: protocolId,
          displayTitle: displayTitle,
        ),
      );

  Future<void> clearProtocol(String slotLocalId) => _applyEdit(
        () => _builderService.clearProtocol(
          document!,
          slotLocalId: slotLocalId,
        ),
      );

  Future<void> updateSlotMetadata({
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
      _applyEdit(
        () => _builderService.updateSlotMetadata(
          document!,
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
        ),
      );

  Future<void> updateMetadata(ProgrammeVersionDraftMetadata metadata) =>
      _applyEdit(
        () => _builderService.updateMetadata(document!, metadata),
      );

  void undo() {
    final current = document;
    if (current == null || isReadOnly) return;

    final result = history.undo(current);
    if (result == null) return;

    document = result.document;
    validation = _validationService.validate(result.document);
    publishReadiness = null;
    _notify();
  }

  void redo() {
    final current = document;
    if (current == null || isReadOnly) return;

    final result = history.redo(current);
    if (result == null) return;

    document = result.document;
    validation = _validationService.validate(result.document);
    publishReadiness = null;
    _notify();
  }

  void selectWeek(String weekLocalId) {
    selection = ProgrammeEditorSelection(weekLocalId: weekLocalId);
    _notify();
  }

  void selectDay({
    required String weekLocalId,
    required String dayLocalId,
  }) {
    selection = ProgrammeEditorSelection(
      weekLocalId: weekLocalId,
      dayLocalId: dayLocalId,
    );
    _notify();
  }

  void selectSlot({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  }) {
    selection = ProgrammeEditorSelection(
      weekLocalId: weekLocalId,
      dayLocalId: dayLocalId,
      slotLocalId: slotLocalId,
    );
    _notify();
  }

  void selectPath(ProgrammeBuilderPath path) {
    switch (path) {
      case ProgrammeBuilderProgrammePath():
        return;
      case ProgrammeBuilderWeekPath(:final weekLocalId):
        selectWeek(weekLocalId);
      case ProgrammeBuilderDayPath(:final weekLocalId, :final dayLocalId):
        selectDay(weekLocalId: weekLocalId, dayLocalId: dayLocalId);
      case ProgrammeBuilderSlotPath(
          :final weekLocalId,
          :final dayLocalId,
          :final slotLocalId,
        ):
        selectSlot(
          weekLocalId: weekLocalId,
          dayLocalId: dayLocalId,
          slotLocalId: slotLocalId,
        );
    }
  }

  List<ProgrammeValidationIssue> issuesForPath(ProgrammeBuilderPath? path) {
    final issues = validation?.issues ?? const [];
    if (path == null) return issues;

    return issues.where((issue) {
      final issuePath = issue.path;
      if (issuePath == null) return false;
      return _pathsEqual(issuePath, path);
    }).toList();
  }

  bool _pathsEqual(ProgrammeBuilderPath left, ProgrammeBuilderPath right) {
    if (left is ProgrammeBuilderSlotPath && right is ProgrammeBuilderSlotPath) {
      return left.slotLocalId == right.slotLocalId;
    }
    if (left is ProgrammeBuilderDayPath && right is ProgrammeBuilderDayPath) {
      return left.dayLocalId == right.dayLocalId;
    }
    if (left is ProgrammeBuilderWeekPath && right is ProgrammeBuilderWeekPath) {
      return left.weekLocalId == right.weekLocalId;
    }
    return false;
  }

  Set<String> _assignedProtocolIds(ProgrammeBuilderDocument doc) {
    final ids = <String>{};
    for (final week in doc.template.allWeeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          if (!ProgrammeBuilderConstants.isUnassignedProtocolId(
            slot.protocolId,
          )) {
            ids.add(slot.protocolId.trim());
          }
        }
      }
    }
    return ids;
  }

  Set<String> _knownProtocolIds(ProgrammeBuilderDocument doc) {
    return _assignedProtocolIds(doc);
  }

  Future<void> _applyEdit(
    Future<ProgrammeBuilderEditResult> Function() editFn, {
    VoidCallback? onApplied,
  }) async {
    final current = document;
    if (current == null || isReadOnly) return;

    history.recordBeforeEdit(current);
    final result = await editFn();
    document = result.document;
    validation = result.validation ?? _validationService.validate(result.document);
    publishReadiness = null;
    onApplied?.call();
    _notify();
  }

  Future<List<ProgrammeBuilderProtocolOption>> listProtocols({
    String? searchTerm,
  }) {
    return _protocolPickerService.listSelectableProtocols(
      searchTerm: searchTerm,
    );
  }
}
