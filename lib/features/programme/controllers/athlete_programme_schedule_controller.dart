import 'package:flutter/foundation.dart';

import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../models/programme_schedule_apply.dart';
import '../models/programme_schedule_persistence.dart';
import '../services/programme_schedule_apply_service.dart';
import '../services/programme_schedule_restore_service.dart';

/// Minimal athlete Move/Swap scheduling surface controller (Sprint 1.7D).
///
/// Owns restore → preview → exact-preview confirm. Does not expose Push/Skip/Undo.
class AthleteProgrammeScheduleController extends ChangeNotifier {
  AthleteProgrammeScheduleController({
    required this.athleteId,
    required this.assignmentId,
    required this._restoreService,
    required this._applyService,
  });

  final String athleteId;
  final String assignmentId;
  final ProgrammeScheduleRestoreService _restoreService;
  final ProgrammeScheduleApplyService _applyService;

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

  bool get isLoading => _loading;
  bool get isConfirming => _confirming;
  String? get errorMessage => _errorMessage;
  ProgrammeSchedulingSnapshot? get snapshot => _snapshot;
  ProgrammeSchedulingPreview? get preview => _preview;
  ProgrammeSchedulingPreviewCode? get previewCode => _previewCode;
  String? get previewDetail => _previewDetail;
  ProgrammeScheduleApplyResult? get lastApplyResult => _lastApplyResult;
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

    _snapshot = _snapshotFromPersisted(result.projection!);
    _loading = false;
    notifyListeners();
  }

  void cancelPreview() {
    _clearPreview();
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
      _snapshot = _snapshotFromPersisted(result.projection!);
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
    }
  }

  void _clearPreview() {
    _preview = null;
    _previewCode = null;
    _previewDetail = null;
    _pendingCommand = null;
    _idempotencyKey = null;
  }

  ProgrammeSchedulingSnapshot _snapshotFromPersisted(
    PersistedProgrammeScheduleProjection projection,
  ) {
    final today = SessionOccurrenceDate.fromDateTime(DateTime.now());
    return projection.toSchedulingSnapshot(
      today: today,
      assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
    );
  }
}
