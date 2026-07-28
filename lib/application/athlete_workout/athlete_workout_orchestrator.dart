import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/training_session_record/training_session_record_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

import 'athlete_workout_capabilities.dart';
import 'athlete_workout_result.dart';

/// Coordinates daily workout resolution for the athlete experience (no domain rules).
class AthleteWorkoutOrchestrator {
  const AthleteWorkoutOrchestrator({
    AthleteDailySessionResolver? dailySessionResolver,
    this.coachBrainRouter,
  }) : _dailySessionResolver =
            dailySessionResolver ?? const AthleteDailySessionResolver();

  final AthleteDailySessionResolver _dailySessionResolver;
  final CoachDecisionRouter? coachBrainRouter;

  AthleteWorkoutResult resolveToday({
    required String athleteId,
    required SessionOccurrenceDate date,
    required AthleteSessionOccurrenceIndex occurrenceIndex,
  }) {
    final resolution = _dailySessionResolver.resolve(
      athleteId: athleteId,
      date: date,
      index: occurrenceIndex,
    );

    return _resultFromResolution(resolution);
  }

  /// End-to-end: resolve → Coach Brain → attach snapshot → updated workout result.
  AthleteWorkoutResult adaptTodayWorkout({
    required String athleteId,
    required SessionOccurrenceDate date,
    required AthleteSessionOccurrenceIndex occurrenceIndex,
    required SessionAdaptationCoachDecisionContext adaptationContext,
    required DateTime recordedAt,
    CoachDecisionRouter? coachBrainRouter,
    String? requestId,
  }) {
    final current = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    if (!current.hasWorkout) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.unavailable,
        adaptationDetail: current.status.name,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.multipleWorkoutsScheduled) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.invalidWorkoutState,
        adaptationDetail: 'multiple_workouts_scheduled',
      );
    }

    if (!current.adaptationAvailable) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.unavailable,
        adaptationDetail: current.lifecycleState?.name,
      );
    }

    final occurrence = current.occurrence!;
    if (adaptationContext.plannedSession.protocolId.trim() !=
        occurrence.sourceSessionId.trim()) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.sourceSessionMismatch,
        adaptationDetail: occurrence.sourceSessionId,
      );
    }

    final router =
        coachBrainRouter ?? this.coachBrainRouter ?? CoachBrainDependencies.defaults().router;
    final resolvedRequestId =
        requestId ?? 'adapt-${occurrence.occurrenceId}-$recordedAt';

    final coachResult = router.route(
      CoachDecisionRequest(
        decisionType: CoachDecisionType.sessionAdaptation,
        requestId: resolvedRequestId,
        athleteId: athleteId.trim(),
        context: adaptationContext,
      ),
    );

    if (!coachResult.isCompleted || coachResult.executionSnapshot == null) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.coachBrainFailed,
        adaptationDetail: coachResult.sessionAdaptationFailureCode?.name ??
            coachResult.status.name,
      );
    }

    final attachResult = occurrence.attachAdaptation(
      executionSnapshot: coachResult.executionSnapshot!,
      recordedAt: recordedAt,
    );

    if (!attachResult.isSuccess || attachResult.occurrence == null) {
      return current.withAdaptationOutcome(
        adaptationStatus: AthleteWorkoutAdaptationStatus.attachmentFailed,
        adaptationDetail: attachResult.issues.isEmpty
            ? null
            : attachResult.issues.first.code.name,
      );
    }

    final updatedOccurrence = attachResult.occurrence!;
    occurrenceIndex.upsert(athleteId: athleteId, occurrence: updatedOccurrence);

    final refreshed = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    return refreshed.withAdaptationOutcome(
      adaptationStatus: AthleteWorkoutAdaptationStatus.succeeded,
    );
  }

  /// End-to-end: resolve → startInProgress → index upsert → refreshed result.
  AthleteWorkoutResult startTodayWorkout({
    required String athleteId,
    required SessionOccurrenceDate date,
    required AthleteSessionOccurrenceIndex occurrenceIndex,
    required DateTime startedAt,
  }) {
    final current = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    if (current.status == AthleteWorkoutResolutionStatus.invalidRequest) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.invalidRequest,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.noWorkoutScheduled) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.noWorkoutScheduled,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.multipleWorkoutsScheduled) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.multipleWorkoutsScheduled,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.workoutInProgress) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.unavailable,
        startDetail: 'already_in_progress',
      );
    }

    if (!current.canStartWorkout) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.unavailable,
        startDetail: current.lifecycleState?.name,
      );
    }

    final occurrence = current.occurrence!;
    final transition = occurrence.startInProgress(recordedAt: startedAt);

    if (!transition.isSuccess || transition.occurrence == null) {
      return current.withStartOutcome(
        startStatus: AthleteWorkoutStartStatus.transitionFailed,
        startDetail: transition.issues.isEmpty
            ? null
            : transition.issues.first.code.name,
      );
    }

    occurrenceIndex.upsert(
      athleteId: athleteId,
      occurrence: transition.occurrence!,
    );

    final refreshed = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    return refreshed.withStartOutcome(
      startStatus: AthleteWorkoutStartStatus.succeeded,
    );
  }

  /// End-to-end: resolve → finish player → record → complete occurrence → index upsert.
  AthleteWorkoutResult completeTodayWorkout({
    required String athleteId,
    required SessionOccurrenceDate date,
    required AthleteSessionOccurrenceIndex occurrenceIndex,
    required WorkoutPlayer workoutPlayer,
    required List<TrainingExerciseExecutionEntry> exerciseOutcomes,
    required DateTime finishedAt,
    String? recordId,
  }) {
    final current = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    if (current.status == AthleteWorkoutResolutionStatus.invalidRequest) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.invalidRequest,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.noWorkoutScheduled) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.noWorkoutScheduled,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.multipleWorkoutsScheduled) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.multipleWorkoutsScheduled,
      );
    }

    if (current.status == AthleteWorkoutResolutionStatus.workoutCompleted) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.unavailable,
        completionDetail: 'already_completed',
      );
    }

    if (current.status != AthleteWorkoutResolutionStatus.workoutInProgress) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.unavailable,
        completionDetail: current.lifecycleState?.name,
      );
    }

    if (!current.canCompleteWorkout) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.unavailable,
        completionDetail: current.lifecycleState?.name,
      );
    }

    final occurrence = current.occurrence!;
    if (workoutPlayer.occurrenceId.trim() != occurrence.occurrenceId.trim()) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.invalidRequest,
        completionDetail: 'player_occurrence_mismatch',
      );
    }

    if (workoutPlayer.executionStatus != WorkoutPlayerExecutionStatus.active) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.unavailable,
        completionDetail: workoutPlayer.executionStatus.name,
      );
    }

    final snapshot = occurrence.executionSnapshot;
    if (snapshot != null &&
        !identical(workoutPlayer.executionSnapshot, snapshot)) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.invalidRequest,
        completionDetail: 'player_snapshot_mismatch',
      );
    }

    final playerFinish = workoutPlayer.finishWorkout(recordedAt: finishedAt);
    if (!playerFinish.isSuccess || playerFinish.player == null) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.transitionFailed,
        completionDetail: playerFinish.issues.isEmpty
            ? null
            : playerFinish.issues.first.code.name,
      );
    }

    final resolvedRecordId = recordId ??
        'record-${occurrence.occurrenceId}-${finishedAt.millisecondsSinceEpoch}';

    final recordResult = TrainingSessionRecord.finalizeFromWorkoutPlayer(
      player: playerFinish.player!,
      recordId: resolvedRecordId,
      exerciseOutcomes: exerciseOutcomes,
    );

    if (!recordResult.isSuccess || recordResult.record == null) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.transitionFailed,
        completionDetail: recordResult.issues.isEmpty
            ? null
            : recordResult.issues.first.code.name,
      );
    }

    final completeResult = occurrence.complete(completedAt: finishedAt);
    if (!completeResult.isSuccess || completeResult.occurrence == null) {
      return current.withCompletionOutcome(
        completionStatus: AthleteWorkoutCompletionStatus.transitionFailed,
        completionDetail: completeResult.issues.isEmpty
            ? null
            : completeResult.issues.first.code.name,
      );
    }

    occurrenceIndex.upsert(
      athleteId: athleteId,
      occurrence: completeResult.occurrence!,
    );

    final refreshed = resolveToday(
      athleteId: athleteId,
      date: date,
      occurrenceIndex: occurrenceIndex,
    );

    return refreshed.withCompletionOutcome(
      completionStatus: AthleteWorkoutCompletionStatus.succeeded,
      trainingSessionRecord: recordResult.record,
    );
  }

  AthleteWorkoutResult _resultFromResolution(
    AthleteDailySessionResolutionResult resolution,
  ) {
    final status = _mapStatus(resolution.outcome);
    final occurrence = resolution.occurrence;

    if (occurrence == null) {
      return AthleteWorkoutResult(
        status: status,
        athleteId: resolution.athleteId,
        date: resolution.date,
        matchingOccurrences: resolution.matchingOccurrences,
      );
    }

    return AthleteWorkoutResult(
      status: status,
      athleteId: resolution.athleteId,
      date: resolution.date,
      occurrence: occurrence,
      matchingOccurrences: resolution.matchingOccurrences,
      lifecycleState: occurrence.lifecycleState,
      executionSnapshot: occurrence.executionSnapshot,
      adaptationAvailable: AthleteWorkoutCapabilities.adaptationAvailable(occurrence),
      canStartWorkout: AthleteWorkoutCapabilities.canStartWorkout(occurrence),
      canCompleteWorkout: AthleteWorkoutCapabilities.canCompleteWorkout(occurrence),
    );
  }

  AthleteWorkoutResolutionStatus _mapStatus(
    AthleteDailySessionResolutionOutcome outcome,
  ) {
    return switch (outcome) {
      AthleteDailySessionResolutionOutcome.invalidLookup =>
        AthleteWorkoutResolutionStatus.invalidRequest,
      AthleteDailySessionResolutionOutcome.noSessionScheduled =>
        AthleteWorkoutResolutionStatus.noWorkoutScheduled,
      AthleteDailySessionResolutionOutcome.multipleSessionsScheduled =>
        AthleteWorkoutResolutionStatus.multipleWorkoutsScheduled,
      AthleteDailySessionResolutionOutcome.sessionPlanned =>
        AthleteWorkoutResolutionStatus.workoutPlanned,
      AthleteDailySessionResolutionOutcome.sessionAdapted =>
        AthleteWorkoutResolutionStatus.workoutAdapted,
      AthleteDailySessionResolutionOutcome.sessionInProgress =>
        AthleteWorkoutResolutionStatus.workoutInProgress,
      AthleteDailySessionResolutionOutcome.sessionCompleted =>
        AthleteWorkoutResolutionStatus.workoutCompleted,
      AthleteDailySessionResolutionOutcome.sessionSkipped =>
        AthleteWorkoutResolutionStatus.workoutSkipped,
      AthleteDailySessionResolutionOutcome.sessionCancelled =>
        AthleteWorkoutResolutionStatus.workoutCancelled,
    };
  }
}
