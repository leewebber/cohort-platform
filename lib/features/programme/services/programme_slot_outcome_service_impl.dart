import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../errors/programme_progression_exception.dart';
import '../models/resolved_today_session.dart';
import 'programme_slot_outcome_service.dart';

/// Persists programme slot outcomes with full cursor context.
class ProgrammeSlotOutcomeServiceImpl implements ProgrammeSlotOutcomeService {
  const ProgrammeSlotOutcomeServiceImpl({
    required ProgrammeSlotOutcomeStore slotOutcomeStore,
  }) : _slotOutcomeStore = slotOutcomeStore;

  final ProgrammeSlotOutcomeStore _slotOutcomeStore;

  @override
  Future<ProgrammeSlotOutcome> upsertFromResolution({
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    DateTime? resolvedAt,
  }) async {
    _validateResolutionContext(resolution);

    final assignmentId = resolution.assignmentId!;
    final sessionSlotId = resolution.slotId!;
    final existing = await _slotOutcomeStore.getForSlot(
      assignmentId: assignmentId,
      sessionSlotId: sessionSlotId,
    );

    final outcome = ProgrammeSlotOutcome(
      id: existing?.id ?? '',
      assignmentId: assignmentId,
      sessionSlotId: sessionSlotId,
      weekNumber: resolution.weekNumber!,
      dayKey: resolution.dayKey!,
      sessionOrder: resolution.slotOrder!,
      outcomeStatus: outcomeStatus,
      trainingSessionId: trainingSessionId ?? existing?.trainingSessionId,
      replacementProtocolId: replacementProtocolId ?? existing?.replacementProtocolId,
      resolutionNote: resolutionNote ?? existing?.resolutionNote,
      resolvedAt: resolvedAt ??
          (outcomeStatus.isTerminal ? DateTime.now().toUtc() : existing?.resolvedAt),
    );

    return _slotOutcomeStore.upsert(outcome);
  }

  void _validateResolutionContext(ResolvedTodaySession resolution) {
    if (resolution.assignmentId == null ||
        resolution.slotId == null ||
        resolution.weekNumber == null ||
        resolution.dayKey == null ||
        resolution.slotOrder == null) {
      throw ProgrammeProgressionException(
        ProgrammeProgressionErrorCode.missingSlotContext,
        'ResolvedTodaySession is missing required slot cursor context',
      );
    }
  }
}
