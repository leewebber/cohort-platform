import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../models/programme_schedule_apply.dart';
import '../models/programme_schedule_persistence.dart';
import '../services/programme_schedule_apply_service.dart';
import '../services/programme_schedule_operations_store.dart';
import '../services/programme_schedule_restore_service.dart';

/// Athlete assignment calendar controller (Sprint 1.7F).
///
/// Owns restore → preview → exact-preview confirm for Move/Swap/Push/Skip/Undo.
class AthleteProgrammeScheduleController extends ChangeNotifier {
  AthleteProgrammeScheduleController({
    required this.athleteId,
    required this.assignmentId,
    required this._restoreService,
    required this._applyService,
    this._assignmentStore,
    this._operationsStore,
  });

  final String athleteId;
  final String assignmentId;
  final ProgrammeScheduleRestoreService _restoreService;
  final ProgrammeScheduleApplyService _applyService;
  final ProgrammeAssignmentStore? _assignmentStore;
  final ProgrammeScheduleOperationsStore? _operationsStore;

  bool _loading = true;
  bool _confirming = false;
  String? _errorMessage;
  ProgrammeSchedulingSnapshot? _snapshot;
  ProgrammeSchedulingPreview? _preview;
  ProgrammeSchedulingPreviewCode? _previewCode;
  String? _previewDetail;
  ProgrammeScheduleApplyCommand? _pendingCommand;
  String? _idempotencyKey;
  ProgrammeScheduleApplyResult? _lastApplyResult;
  ProgrammeSchedulingUndoableOperation? _undoableOperation;

  bool get isLoading => _loading;
  bool get isConfirming => _confirming;
  String? get errorMessage => _errorMessage;
  ProgrammeSchedulingSnapshot? get snapshot => _snapshot;
  ProgrammeSchedulingPreview? get preview => _preview;
  ProgrammeSchedulingPreviewCode? get previewCode => _previewCode;
  String? get previewDetail => _previewDetail;
  ProgrammeScheduleApplyResult? get lastApplyResult => _lastApplyResult;
  ProgrammeSchedulingUndoableOperation? get undoableOperation =>
      _undoableOperation;
  bool get hasConfirmablePreview =>
      _preview != null && _pendingCommand != null && !_confirming;

  List<ScheduledProgrammeOccurrence> get uncompletedOccurrences {
    final snap = _snapshot;
    if (snap == null) return const [];
    return snap.projection.occurrences
        .where((o) => o.isUncompleted)
        .toList(growable: false);
  }

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _clearPreview();
    notifyListeners();

    final result = await _restoreService.ensureAndRestore(
      athleteId: athleteId,
      programmeAssignmentId: assignmentId,
    );
    if (!result.isSuccess || result.projection == null) {
      _errorMessage =
          result.message ?? 'Schedule could not be loaded. Try again.';
      _loading = false;
      notifyListeners();
      return;
    }

    _snapshot = await _snapshotFromPersisted(result.projection!);
    await _refreshUndoable();
    _loading = false;
    notifyListeners();
  }

  void cancelPreview() {
    _clearPreview();
    notifyListeners();
  }

  Future<void> previewUndo() async {
    final snap = _snapshot;
    final operation = _undoableOperation;
    if (snap == null || operation == null) return;
    _clearPreview();
    final result = _applyService.previewUndo(
      snapshot: snap,
      operation: operation,
    );
    if (!result.isReady || result.preview == null) {
      _previewCode = result.code;
      _previewDetail = result.detail;
      _errorMessage = result.detail ?? result.code.name;
      notifyListeners();
      return;
    }
    final preview = result.preview!;
    _preview = preview;
    _previewCode = result.code;
    _previewDetail = null;
    _idempotencyKey ??= ProgrammeScheduleApplyService.newIdempotencyKey();
    _pendingCommand = _applyService.undoCommandFromPreview(
      snapshot: snap,
      operation: operation,
      preview: preview,
      idempotencyKey: _idempotencyKey,
    );
    notifyListeners();
  }

  Future<void> previewMove({
    required String sessionSlotId,
    required SessionOccurrenceDate targetDate,
  }) async {
    final snap = _snapshot;
    if (snap == null) return;
    _clearPreview();
    final result = _applyService.previewMove(
      snapshot: snap,
      sessionSlotId: sessionSlotId,
      targetDate: targetDate,
    );
    _bindPreviewResult(
      result,
      request: ProgrammeSchedulingMoveRequest(
        sessionSlotId: sessionSlotId,
        targetDate: targetDate,
      ),
    );
    notifyListeners();
  }

  Future<void> previewSwap({
    required String sessionSlotIdA,
    required String sessionSlotIdB,
  }) async {
    final snap = _snapshot;
    if (snap == null) return;
    _clearPreview();
    final result = _applyService.previewSwap(
      snapshot: snap,
      sessionSlotIdA: sessionSlotIdA,
      sessionSlotIdB: sessionSlotIdB,
    );
    _bindPreviewResult(
      result,
      request: ProgrammeSchedulingSwapRequest(
        sessionSlotIdA: sessionSlotIdA,
        sessionSlotIdB: sessionSlotIdB,
      ),
    );
    notifyListeners();
  }

  Future<void> previewPush({
    required String fromSessionSlotId,
    required int dayDelta,
  }) async {
    final snap = _snapshot;
    if (snap == null) return;
    _clearPreview();
    final result = _applyService.previewPush(
      snapshot: snap,
      fromSessionSlotId: fromSessionSlotId,
      dayDelta: dayDelta,
    );
    _bindPreviewResult(
      result,
      request: ProgrammeSchedulingPushRequest(
        fromSessionSlotId: fromSessionSlotId,
        dayDelta: dayDelta,
      ),
    );
    notifyListeners();
  }

  Future<void> previewSkip({required String sessionSlotId}) async {
    final snap = _snapshot;
    if (snap == null) return;
    _clearPreview();
    final result = _applyService.previewSkip(
      snapshot: snap,
      sessionSlotId: sessionSlotId,
    );
    _bindPreviewResult(
      result,
      request: ProgrammeSchedulingSkipRequest(sessionSlotId: sessionSlotId),
    );
    notifyListeners();
  }

  Future<ProgrammeScheduleApplyResult?> confirmPreview() async {
    final command = _pendingCommand;
    final preview = _preview;
    if (command == null || preview == null || _confirming) return null;
    if (command.previewFingerprint != preview.fingerprint) {
      _errorMessage = 'Preview changed. Reload and preview again.';
      notifyListeners();
      return null;
    }

    _confirming = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _applyService.confirmApply(
      athleteId: athleteId,
      command: command,
    );
    _lastApplyResult = result;

    if (result.isSuccess && result.projection != null) {
      _snapshot = await _snapshotFromPersisted(
        result.projection!,
        cursorAfter: result.cursorAfter,
      );
      await _refreshUndoable();
      _clearPreview();
    } else if (result.requiresReload) {
      await load();
      _errorMessage =
          result.message ??
          'Schedule changed. Preview again before confirming.';
      _confirming = false;
      notifyListeners();
      return result;
    } else {
      _errorMessage = result.message ?? result.code ?? 'Schedule change failed.';
    }

    _confirming = false;
    notifyListeners();
    return result;
  }

  void _bindPreviewResult(
    ProgrammeSchedulingPreviewResult result, {
    required ProgrammeSchedulingRequest request,
  }) {
    final snap = _snapshot;
    if (!result.isReady || result.preview == null || snap == null) {
      _previewCode = result.code;
      _previewDetail = result.detail;
      _errorMessage = result.detail ?? result.code.name;
      return;
    }
    final preview = result.preview!;
    _preview = preview;
    _previewCode = result.code;
    _previewDetail = null;
    _idempotencyKey ??= ProgrammeScheduleApplyService.newIdempotencyKey();
    if (request is ProgrammeSchedulingMoveRequest) {
      _pendingCommand = _applyService.moveCommandFromPreview(
        snapshot: snap,
        request: request,
        preview: preview,
        idempotencyKey: _idempotencyKey,
      );
    } else if (request is ProgrammeSchedulingSwapRequest) {
      _pendingCommand = _applyService.swapCommandFromPreview(
        snapshot: snap,
        request: request,
        preview: preview,
        idempotencyKey: _idempotencyKey,
      );
    } else if (request is ProgrammeSchedulingPushRequest) {
      _pendingCommand = _applyService.pushCommandFromPreview(
        snapshot: snap,
        request: request,
        preview: preview,
        idempotencyKey: _idempotencyKey,
      );
    } else if (request is ProgrammeSchedulingSkipRequest) {
      _pendingCommand = _applyService.skipCommandFromPreview(
        snapshot: snap,
        request: request,
        preview: preview,
        idempotencyKey: _idempotencyKey,
      );
    }
  }

  void _clearPreview() {
    _preview = null;
    _previewCode = null;
    _previewDetail = null;
    _pendingCommand = null;
    _idempotencyKey = null;
  }

  Future<void> _refreshUndoable() async {
    final store = _operationsStore;
    if (store == null) {
      _undoableOperation = null;
      return;
    }
    final candidate = await store.latestUndoableOperation(
      assignmentId: assignmentId,
    );
    final snap = _snapshot;
    if (candidate == null || snap == null) {
      _undoableOperation = null;
      return;
    }
    final now = DateTime.now().toUtc();
    if (!candidate.isStructurallyEligible ||
        candidate.isExpiredAt(now) ||
        candidate.resultRevision != snap.projection.scheduleRevision) {
      _undoableOperation = null;
      return;
    }
    _undoableOperation = candidate;
  }

  Future<ProgrammeSchedulingSnapshot> _snapshotFromPersisted(
    PersistedProgrammeScheduleProjection projection, {
    Map<String, dynamic>? cursorAfter,
  }) async {
    final today = SessionOccurrenceDate.fromDateTime(DateTime.now());
    final cursorSlotId = await _resolveCursorSessionSlotId(
      projection,
      cursorAfter: cursorAfter,
    );
    return projection.toSchedulingSnapshot(
      today: today,
      assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
      cursorSessionSlotId: cursorSlotId,
      schedulingHorizonEnd: projection.schedulingHorizonEnd,
    );
  }

  /// Resolves cursor slot from apply result or durable assignment coordinates.
  Future<String?> _resolveCursorSessionSlotId(
    PersistedProgrammeScheduleProjection projection, {
    Map<String, dynamic>? cursorAfter,
  }) async {
    final afterSlot = cursorAfter?['sessionSlotId']?.toString().trim();
    if (afterSlot != null && afterSlot.isNotEmpty) {
      return afterSlot;
    }
    final afterWeek = _asInt(cursorAfter?['weekNumber']);
    final afterDay = cursorAfter?['dayKey']?.toString();
    final afterOrder = _asInt(cursorAfter?['sessionOrder']);
    if (afterWeek != null && afterDay != null && afterOrder != null) {
      return _slotMatchingCursor(
        projection,
        week: afterWeek,
        dayKey: afterDay,
        sessionOrder: afterOrder,
      );
    }

    final store = _assignmentStore;
    if (store == null) return null;
    final assignment = await store.getById(assignmentId);
    if (assignment == null || assignment.athleteId != athleteId) return null;
    return _slotMatchingCursor(
      projection,
      week: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
      sessionOrder: assignment.currentSessionOrder,
    );
  }

  String? _slotMatchingCursor(
    PersistedProgrammeScheduleProjection projection, {
    required int week,
    required String dayKey,
    required int sessionOrder,
  }) {
    for (final occurrence in projection.occurrences) {
      if (occurrence.weekNumber == week &&
          occurrence.dayKey == dayKey &&
          occurrence.sessionOrder == sessionOrder) {
        return occurrence.sessionSlotId;
      }
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
