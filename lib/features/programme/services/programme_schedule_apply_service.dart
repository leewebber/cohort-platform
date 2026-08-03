import 'dart:math';

import '../../../core/persistence/athlete_local_repository.dart';
import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../../adaptation/models/accepted_adaptation_decision.dart';
import '../models/programme_schedule_apply.dart';
import 'athlete_programme_session_prepare_service.dart';
import 'programme_schedule_apply_store.dart';
import 'programme_schedule_restore_service.dart';

/// Application boundary for confirmed Move/Swap exact-preview apply.
///
/// Does not expose generic projection writers. Push/Skip remain unapplied
/// (server returns typed unsupported; no client apply constructors for them).
class ProgrammeScheduleApplyService {
  ProgrammeScheduleApplyService({
    required ProgrammeScheduleApplyStore applyStore,
    required ProgrammeScheduleRestoreService restoreService,
    required AthleteLocalRepository localRepository,
    AthleteProgrammeSessionPrepareService? prepareService,
  }) : _applyStore = applyStore,
       _restoreService = restoreService,
       _local = localRepository,
       _prepareService = prepareService;

  final ProgrammeScheduleApplyStore _applyStore;
  final ProgrammeScheduleRestoreService _restoreService;
  final AthleteLocalRepository _local;
  final AthleteProgrammeSessionPrepareService? _prepareService;

  /// Stable client idempotency key for one confirmation attempt (retry-safe).
  static String newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Builds a Move command from a ready preview (revision + fingerprint bound).
  ProgrammeScheduleMoveCommand? moveCommandFromPreview({
    required ProgrammeSchedulingSnapshot snapshot,
    required ProgrammeSchedulingMoveRequest request,
    required ProgrammeSchedulingPreview preview,
    String? idempotencyKey,
  }) {
    if (preview.operationType != ProgrammeSchedulingOperationType.move) {
      return null;
    }
    return ProgrammeScheduleMoveCommand(
      assignmentId: snapshot.assignmentId,
      programmeVersionId: snapshot.programmeVersionId,
      packageContentHash: snapshot.packageContentHash,
      expectedScheduleRevision: snapshot.projection.scheduleRevision,
      previewFingerprint: preview.fingerprint,
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
      sessionSlotId: request.sessionSlotId,
      targetDate: request.targetDate,
    );
  }

  ProgrammeScheduleSwapCommand? swapCommandFromPreview({
    required ProgrammeSchedulingSnapshot snapshot,
    required ProgrammeSchedulingSwapRequest request,
    required ProgrammeSchedulingPreview preview,
    String? idempotencyKey,
  }) {
    if (preview.operationType != ProgrammeSchedulingOperationType.swap) {
      return null;
    }
    return ProgrammeScheduleSwapCommand(
      assignmentId: snapshot.assignmentId,
      programmeVersionId: snapshot.programmeVersionId,
      packageContentHash: snapshot.packageContentHash,
      expectedScheduleRevision: snapshot.projection.scheduleRevision,
      previewFingerprint: preview.fingerprint,
      idempotencyKey: idempotencyKey ?? newIdempotencyKey(),
      sessionSlotIdA: request.sessionSlotIdA,
      sessionSlotIdB: request.sessionSlotIdB,
    );
  }

  /// Confirms the exact preview. Retries must reuse [command.idempotencyKey].
  Future<ProgrammeScheduleApplyResult> confirmApply({
    required String athleteId,
    required ProgrammeScheduleApplyCommand command,
  }) async {
    if (command is! ProgrammeScheduleMoveCommand &&
        command is! ProgrammeScheduleSwapCommand) {
      return const ProgrammeScheduleApplyResult(
        status: ProgrammeScheduleApplyStatus.unsupportedOperation,
        code: 'unsupported_operation',
      );
    }

    final result = await _applyStore.apply(command);
    if (!result.isSuccess || result.projection == null) {
      if (result.requiresReload) {
        await _restoreService.ensureAndRestore(
          athleteId: athleteId,
          programmeAssignmentId: command.assignmentId,
        );
      }
      return result;
    }

    final projection = result.projection!;
    if (projection.athleteId != athleteId) {
      return const ProgrammeScheduleApplyResult(
        status: ProgrammeScheduleApplyStatus.assignmentNotOwned,
        code: 'cross_athlete_projection',
      );
    }

    // Persist-before-cache: store authoritative server result first.
    await _local.saveProgrammeScheduleProjection(
      athleteId: athleteId,
      projection: projection,
    );

    // Local prepared / pending clear for affected keys (local-only model).
    // Consumed adaptation proposal IDs are intentionally not touched.
    final keys = result.clearedProgrammedSessionKeys;
    if (keys.isNotEmpty) {
      await _prepareService?.clearPreparedForProgrammedSessionKeys(
        athleteId: athleteId,
        programmedSessionKeys: keys,
      );
      final pending = AdaptationRecommendationBuffer.pending;
      if (pending != null && keys.contains(pending.programmedSessionKey)) {
        AdaptationRecommendationBuffer.dismiss();
      }
    }

    return result;
  }

  /// Convenience: preview then return ready result without applying.
  ProgrammeSchedulingPreviewResult previewMove({
    required ProgrammeSchedulingSnapshot snapshot,
    required String sessionSlotId,
    required SessionOccurrenceDate targetDate,
  }) {
    const engine = ProgrammeSchedulingPreviewEngine();
    return engine.preview(
      snapshot: snapshot,
      request: ProgrammeSchedulingMoveRequest(
        sessionSlotId: sessionSlotId,
        targetDate: targetDate,
      ),
    );
  }

  ProgrammeSchedulingPreviewResult previewSwap({
    required ProgrammeSchedulingSnapshot snapshot,
    required String sessionSlotIdA,
    required String sessionSlotIdB,
  }) {
    const engine = ProgrammeSchedulingPreviewEngine();
    return engine.preview(
      snapshot: snapshot,
      request: ProgrammeSchedulingSwapRequest(
        sessionSlotIdA: sessionSlotIdA,
        sessionSlotIdB: sessionSlotIdB,
      ),
    );
  }
}
