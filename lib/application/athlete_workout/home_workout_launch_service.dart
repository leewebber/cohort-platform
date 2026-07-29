import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/coach_brain_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import '../adaptation/adaptation_application.dart';
import 'athlete_workout_orchestrator.dart';
import 'athlete_workout_result.dart';
import 'home_workout_execution_context.dart';

typedef ProtocolDraftLoader = Future<ProtocolDraft> Function(String protocolId);

/// Prepares domain execution context before legacy M7 launch.
class HomeWorkoutLaunchService {
  const HomeWorkoutLaunchService({
    AthleteWorkoutOrchestrator? workoutOrchestrator,
    ProtocolDraftLoader? loadProtocolDraft,
  }) : _workoutOrchestrator =
           workoutOrchestrator ?? const AthleteWorkoutOrchestrator(),
       _loadProtocolDraft =
           loadProtocolDraft ?? _unsupportedProtocolDraftLoader;

  final AthleteWorkoutOrchestrator _workoutOrchestrator;
  final ProtocolDraftLoader _loadProtocolDraft;

  Future<HomeWorkoutLaunchPrepareResult> prepareForLegacyLaunch({
    required HomeWorkoutExecutionContext executionContext,
    required String athleteId,
    required Protocol protocol,
    required int trainingSessionId,
    AdaptationRequest? adaptationRequest,
  }) async {
    var context = executionContext;

    final occurrence = context.workout.occurrence;
    if (occurrence == null) {
      return HomeWorkoutLaunchPrepareResult.failure(
        detail: 'occurrence_missing',
      );
    }

    if (occurrence.executionSnapshot == null) {
      final attach = await _attachDayOfAdaptation(
        context: context,
        athleteId: athleteId,
        protocol: protocol,
        request: adaptationRequest,
      );
      if (!attach.isSuccess) {
        return HomeWorkoutLaunchPrepareResult.failure(
          detail: attach.detail ?? 'attach_failed',
        );
      }
      context = attach.context!;
    }

    final startedAt = DateTime.now();
    final startResult = _workoutOrchestrator.startTodayWorkout(
      athleteId: athleteId,
      date: context.occurrenceDate,
      occurrenceRepository: context.occurrenceRepository,
      startedAt: startedAt,
    );

    if (startResult.startStatus != AthleteWorkoutStartStatus.succeeded) {
      return HomeWorkoutLaunchPrepareResult.failure(
        detail: startResult.startDetail ?? startResult.startStatus.name,
      );
    }

    context = context.withWorkout(startResult);

    final inProgressOccurrence = startResult.occurrence;
    final snapshot = inProgressOccurrence?.executionSnapshot;
    if (inProgressOccurrence == null || snapshot == null) {
      return HomeWorkoutLaunchPrepareResult.failure(
        detail: 'snapshot_missing_after_start',
      );
    }

    final playerId =
        'home-$trainingSessionId-${inProgressOccurrence.occurrenceId}';
    final playerResult = WorkoutPlayer.openForOccurrence(
      occurrence: inProgressOccurrence,
      playerId: playerId,
    );

    if (!playerResult.isSuccess || playerResult.player == null) {
      return HomeWorkoutLaunchPrepareResult.failure(
        detail: playerResult.issues.isEmpty
            ? 'workout_player_open_failed'
            : playerResult.issues.first.code.name,
      );
    }

    return HomeWorkoutLaunchPrepareResult.success(
      context: context,
      launchContext: HomeWorkoutLaunchBundle(
        occurrence: inProgressOccurrence,
        executionSnapshot: snapshot,
        legacyProtocolId: inProgressOccurrence.sourceSessionId.trim(),
        workoutPlayer: playerResult.player!,
      ),
    );
  }

  Future<_AttachResult> _attachDayOfAdaptation({
    required HomeWorkoutExecutionContext context,
    required String athleteId,
    required Protocol protocol,
    AdaptationRequest? request,
  }) async {
    if (request == null) {
      return _attachWithEmptyConstraints(
        context: context,
        athleteId: athleteId,
        protocol: protocol,
      );
    }
    final draft = await _loadProtocolDraft(protocol.protocolId.trim());
    final plannedSession = PlannedSessionProtocolMetadataMerge.merge(
      draft: draft,
      protocol: protocol,
    );
    final constraints = AdaptationRequestConstraintMapper.fromRequest(request);
    final adaptationContext = SessionAdaptationCoachDecisionContext(
      plannedSession: plannedSession,
      constraints: constraints,
    );

    final result = _workoutOrchestrator.adaptTodayWorkout(
      athleteId: athleteId,
      date: context.occurrenceDate,
      occurrenceRepository: context.occurrenceRepository,
      adaptationContext: adaptationContext,
      recordedAt: DateTime.now(),
    );

    if (result.adaptationStatus != AthleteWorkoutAdaptationStatus.succeeded) {
      return _AttachResult(
        isSuccess: false,
        detail: result.adaptationDetail ?? result.adaptationStatus.name,
      );
    }

    return _AttachResult(
      isSuccess: true,
      context: context.withWorkout(result, lastAdaptationCommitted: true),
    );
  }

  Future<_AttachResult> _attachWithEmptyConstraints({
    required HomeWorkoutExecutionContext context,
    required String athleteId,
    required Protocol protocol,
  }) async {
    final draft = await _loadProtocolDraft(protocol.protocolId.trim());
    final plannedSession = PlannedSessionProtocolMetadataMerge.merge(
      draft: draft,
      protocol: protocol,
    );
    final adaptationContext = SessionAdaptationCoachDecisionContext(
      plannedSession: plannedSession,
      constraints: AdaptationConstraintContext.empty(),
    );

    final result = _workoutOrchestrator.adaptTodayWorkout(
      athleteId: athleteId,
      date: context.occurrenceDate,
      occurrenceRepository: context.occurrenceRepository,
      adaptationContext: adaptationContext,
      recordedAt: DateTime.now(),
    );

    if (result.adaptationStatus != AthleteWorkoutAdaptationStatus.succeeded) {
      return _AttachResult(
        isSuccess: false,
        detail: result.adaptationDetail ?? result.adaptationStatus.name,
      );
    }

    return _AttachResult(isSuccess: true, context: context.withWorkout(result));
  }

  static Future<ProtocolDraft> _unsupportedProtocolDraftLoader(
    String protocolId,
  ) {
    throw UnsupportedError(
      'Inject loadProtocolDraft for HomeWorkoutLaunchService ($protocolId)',
    );
  }

  /// Runs [AthleteWorkoutOrchestrator.adaptTodayWorkout] and updates in-memory context.
  Future<HomeWorkoutExecutionContext?> commitDayOfAdaptation({
    required HomeWorkoutExecutionContext executionContext,
    required String athleteId,
    required Protocol protocol,
    required AdaptationRequest request,
  }) async {
    final attach = await _attachDayOfAdaptation(
      context: executionContext,
      athleteId: athleteId,
      protocol: protocol,
      request: request,
    );
    return attach.context;
  }
}

class HomeWorkoutLaunchBundle {
  const HomeWorkoutLaunchBundle({
    required this.occurrence,
    required this.executionSnapshot,
    required this.legacyProtocolId,
    required this.workoutPlayer,
  });

  final SessionOccurrence occurrence;
  final AdaptedSessionExecutionSnapshot executionSnapshot;
  final String legacyProtocolId;
  final WorkoutPlayer workoutPlayer;
}

class HomeWorkoutLaunchPrepareResult {
  const HomeWorkoutLaunchPrepareResult._({
    required this.isSuccess,
    this.context,
    this.launchContext,
    this.detail,
  });

  factory HomeWorkoutLaunchPrepareResult.success({
    required HomeWorkoutExecutionContext context,
    required HomeWorkoutLaunchBundle launchContext,
  }) {
    return HomeWorkoutLaunchPrepareResult._(
      isSuccess: true,
      context: context,
      launchContext: launchContext,
    );
  }

  factory HomeWorkoutLaunchPrepareResult.failure({required String detail}) {
    return HomeWorkoutLaunchPrepareResult._(isSuccess: false, detail: detail);
  }

  final bool isSuccess;
  final HomeWorkoutExecutionContext? context;
  final HomeWorkoutLaunchBundle? launchContext;
  final String? detail;
}

class _AttachResult {
  const _AttachResult({required this.isSuccess, this.context, this.detail});

  final bool isSuccess;
  final HomeWorkoutExecutionContext? context;
  final String? detail;
}
