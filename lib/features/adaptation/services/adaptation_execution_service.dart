import '../../../data/repositories/programme_adaptation_event_store.dart';
import '../../../data/repositories/programme_adaptation_event_supabase_store.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../models/adaptation_scoring_reason.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../../performance/models/training_session_record.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progression_result.dart';
import '../../programme/models/programme_template.dart';
import '../models/adaptation_execution_result.dart';
import '../models/programme_adaptation_event.dart';
import 'adaptation_service.dart';
import 'post_completion_adaptation_evaluator.dart';

/// Executes deterministic post-completion adaptations on future programme slots.
class AdaptationExecutionService {
  AdaptationExecutionService({
    ProgrammeAdaptationEventStore? adaptationEventStore,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    ProtocolRepository? protocolRepository,
    PostCompletionAdaptationEvaluator? evaluator,
    ProgrammeFutureSlotFinder? futureSlotFinder,
    AdaptationService? adaptationService,
  })  : _adaptationEventStore =
            adaptationEventStore ?? const ProgrammeAdaptationEventSupabaseStore(),
        _assignmentStore =
            assignmentStore ?? const ProgrammeAssignmentSupabaseStore(),
        _slotOutcomeStore =
            slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
        _versionStore = versionStore ?? const ProgrammeVersionSupabaseStore(),
        _protocolRepository = protocolRepository ?? ProtocolRepository(),
        _evaluator = evaluator ?? const PostCompletionAdaptationEvaluator(),
        _futureSlotFinder = futureSlotFinder ?? const ProgrammeFutureSlotFinder(),
        _adaptationService = AdaptationService(
          protocolRepository ?? ProtocolRepository(),
        );

  final ProgrammeAdaptationEventStore _adaptationEventStore;
  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeVersionStore _versionStore;
  final ProtocolRepository _protocolRepository;
  final PostCompletionAdaptationEvaluator _evaluator;
  final ProgrammeFutureSlotFinder _futureSlotFinder;
  final AdaptationService _adaptationService;

  Future<AdaptationExecutionResult> executeAfterSessionCompletion({
    required String athleteId,
    required TrainingSessionRecord record,
    required ProgrammeExecutionContext programmeContext,
    required int trainingSessionId,
    required bool endedEarly,
    ProgrammeProgressionResult? progressionResult,
  }) async {
    if (!programmeContext.isProgrammeBacked) {
      return AdaptationExecutionResult.skipped('Session is not programme-backed');
    }

    final assignmentId = programmeContext.assignmentId;
    final existing = await _adaptationEventStore.getByTriggerSession(
      assignmentId: assignmentId,
      triggerTrainingSessionId: trainingSessionId,
    );
    if (existing != null) {
      return AdaptationExecutionResult.fromEvent(existing);
    }

    final assignment = await _assignmentStore.getById(assignmentId);
    if (assignment == null || !assignment.isActive) {
      return AdaptationExecutionResult.skipped('No active assignment');
    }

    final tree = await _versionStore.loadTemplateTree(
      assignment.programmeVersionId,
    );
    if (tree == null) {
      return AdaptationExecutionResult.skipped('Programme template unavailable');
    }

    final outcomes = await _slotOutcomeStore.listForAssignment(assignmentId);
    final completedSlotId = programmeContext.sessionSlotId;
    final completedWeek = programmeContext.weekNumber;
    final completedDay = programmeContext.dayKey;
    final completedOrder = programmeContext.sessionOrder;
    final plannedProtocolId = programmeContext.plannedProtocolId;

    final futureSlots = _futureSlotFinder.listFutureSlots(
      tree: tree,
      afterWeekNumber: completedWeek,
      afterDayKey: completedDay,
      afterSessionOrder: completedOrder,
      outcomes: outcomes,
      matchingProtocolId: plannedProtocolId,
    );

    final nextMatchingFutureSlot =
        futureSlots.isEmpty ? null : futureSlots.first;

    final strengthSummary = _evaluator.summarizeStrengthPerformance(record);

    final priorCompletedSameProtocol = _countPriorCompletedSameProtocol(
      tree: tree,
      outcomes: outcomes,
      plannedProtocolId: plannedProtocolId,
      excludeSlotId: completedSlotId,
    );

    final evaluation = _evaluator.evaluate(
      record: record,
      plannedProtocolId: plannedProtocolId,
      completedSlotId: completedSlotId,
      assignmentOutcomes: outcomes,
      nextMatchingFutureSlot: nextMatchingFutureSlot,
      strengthSummary: strengthSummary,
      endedEarly: endedEarly,
      priorCompletedSameProtocolCount: priorCompletedSameProtocol,
    );

    if (evaluation == null) {
      return AdaptationExecutionResult.skipped('No adaptation rules matched');
    }

    String? replacementProtocolId;
    final payload = <String, dynamic>{
      'plannedProtocolId': plannedProtocolId,
      'targetWeekNumber': evaluation.targetSlot.weekNumber,
      'targetDayKey': evaluation.targetSlot.dayKey,
      'targetSlotTitle': evaluation.targetSlot.slotTitle,
    };

    if (evaluation.type == AdaptationEvaluationType.protocolSubstitution) {
      final currentProtocol =
          await _protocolRepository.getProtocolById(plannedProtocolId);
      if (currentProtocol == null) {
        return AdaptationExecutionResult.skipped('Planned protocol not found');
      }

      final recommendations = await _adaptationService.getRecommendations(
        currentProtocol: currentProtocol,
        reason: AdaptationScoringReason.poorRecovery,
      );

      if (recommendations.isEmpty) {
        return AdaptationExecutionResult.skipped(
          'No suitable recovery protocol found',
        );
      }

      replacementProtocolId = recommendations.first.protocol.protocolId;
      payload['replacementProtocolId'] = replacementProtocolId;
    } else {
      payload.addAll({
        'exerciseId': evaluation.exerciseId,
        'exerciseName': evaluation.exerciseName,
        'previousLoadKg': evaluation.previousLoadKg,
        'newLoadKg': evaluation.newLoadKg,
        'deltaKg': PostCompletionAdaptationEvaluator.loadProgressionDeltaKg,
      });
    }

    final existingTargetOutcome = await _slotOutcomeStore.getForSlot(
      assignmentId: assignmentId,
      sessionSlotId: evaluation.targetSlot.slotId,
    );

    final adaptedOutcome = ProgrammeSlotOutcome(
      id: existingTargetOutcome?.id ?? '',
      assignmentId: assignmentId,
      sessionSlotId: evaluation.targetSlot.slotId,
      weekNumber: evaluation.targetSlot.weekNumber,
      dayKey: evaluation.targetSlot.dayKey,
      sessionOrder: evaluation.targetSlot.sessionOrder,
      outcomeStatus: ProgrammeSlotOutcomeStatus.scheduled,
      replacementProtocolId:
          replacementProtocolId ?? existingTargetOutcome?.replacementProtocolId,
      resolutionNote: evaluation.explanation,
      trainingSessionId: existingTargetOutcome?.trainingSessionId,
      resolvedAt: existingTargetOutcome?.resolvedAt,
    );

    await _slotOutcomeStore.upsert(adaptedOutcome);

    final event = await _adaptationEventStore.insert(
      ProgrammeAdaptationEvent(
        id: '',
        assignmentId: assignmentId,
        athleteId: athleteId,
        triggerTrainingSessionId: trainingSessionId,
        adaptationType: evaluation.type == AdaptationEvaluationType.loadProgression
            ? ProgrammeAdaptationType.loadProgression
            : ProgrammeAdaptationType.protocolSubstitution,
        explanation: evaluation.explanation,
        athleteSummary: evaluation.athleteSummary,
        affectedSlotIds: [evaluation.targetSlot.slotId],
        payload: payload,
        triggerSlotId: evaluation.triggerSlotId,
      ),
    );

    return AdaptationExecutionResult.fromEvent(event);
  }

  int _countPriorCompletedSameProtocol({
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
    required String plannedProtocolId,
    required String excludeSlotId,
  }) {
    final slotProtocolById = <String, String>{};
    for (final weekNode in tree.weekNodes) {
      for (final dayNode in weekNode.sortedDays) {
        for (final slot in dayNode.sortedSlots) {
          slotProtocolById[slot.id] = slot.protocolId;
        }
      }
    }

    return outcomes.where((outcome) {
      if (outcome.sessionSlotId == excludeSlotId) return false;
      if (outcome.outcomeStatus != ProgrammeSlotOutcomeStatus.completed) {
        return false;
      }
      return slotProtocolById[outcome.sessionSlotId] == plannedProtocolId;
    }).length;
  }
}
