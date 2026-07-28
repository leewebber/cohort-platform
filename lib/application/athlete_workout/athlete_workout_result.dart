import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/training_session_record/training_session_record_domain.dart'
    as domain_record;

enum AthleteWorkoutResolutionStatus {
  invalidRequest,
  noWorkoutScheduled,
  multipleWorkoutsScheduled,
  workoutPlanned,
  workoutAdapted,
  workoutInProgress,
  workoutCompleted,
  workoutSkipped,
  workoutCancelled,
}

enum AthleteWorkoutAdaptationStatus {
  none,
  succeeded,
  unavailable,
  invalidWorkoutState,
  sourceSessionMismatch,
  coachBrainFailed,
  attachmentFailed,
}

enum AthleteWorkoutStartStatus {
  none,
  succeeded,
  invalidRequest,
  noWorkoutScheduled,
  multipleWorkoutsScheduled,
  unavailable,
  transitionFailed,
}

enum AthleteWorkoutCompletionStatus {
  none,
  succeeded,
  invalidRequest,
  noWorkoutScheduled,
  multipleWorkoutsScheduled,
  unavailable,
  transitionFailed,
}

/// Application result for "today's workout" — immutable, UI-friendly.
class AthleteWorkoutResult {
  const AthleteWorkoutResult({
    required this.status,
    required this.athleteId,
    required this.date,
    this.occurrence,
    this.matchingOccurrences = const [],
    this.lifecycleState,
    this.executionSnapshot,
    this.adaptationAvailable = false,
    this.canStartWorkout = false,
    this.adaptationStatus = AthleteWorkoutAdaptationStatus.none,
    this.adaptationDetail,
    this.startStatus = AthleteWorkoutStartStatus.none,
    this.startDetail,
    this.canCompleteWorkout = false,
    this.completionStatus = AthleteWorkoutCompletionStatus.none,
    this.completionDetail,
    this.trainingSessionRecord,
  });

  final AthleteWorkoutResolutionStatus status;
  final String athleteId;
  final SessionOccurrenceDate date;
  final SessionOccurrence? occurrence;
  final List<SessionOccurrence> matchingOccurrences;
  final SessionOccurrenceLifecycleState? lifecycleState;
  final AdaptedSessionExecutionSnapshot? executionSnapshot;
  final bool adaptationAvailable;
  final bool canStartWorkout;
  final AthleteWorkoutAdaptationStatus adaptationStatus;
  final String? adaptationDetail;
  final AthleteWorkoutStartStatus startStatus;
  final String? startDetail;
  final bool canCompleteWorkout;
  final AthleteWorkoutCompletionStatus completionStatus;
  final String? completionDetail;
  final domain_record.TrainingSessionRecord? trainingSessionRecord;

  bool get hasWorkout => occurrence != null;

  bool get adaptationSucceeded =>
      adaptationStatus == AthleteWorkoutAdaptationStatus.succeeded;

  bool get startSucceeded => startStatus == AthleteWorkoutStartStatus.succeeded;

  bool get completionSucceeded =>
      completionStatus == AthleteWorkoutCompletionStatus.succeeded;

  /// Primary handle for Coach Brain and future commands (skip, adapt, start).
  String? get occurrenceId => occurrence?.occurrenceId;

  AthleteWorkoutResult withAdaptationOutcome({
    required AthleteWorkoutAdaptationStatus adaptationStatus,
    String? adaptationDetail,
    SessionOccurrence? occurrence,
    SessionOccurrenceLifecycleState? lifecycleState,
    AdaptedSessionExecutionSnapshot? executionSnapshot,
    AthleteWorkoutResolutionStatus? status,
    bool? adaptationAvailable,
    bool? canStartWorkout,
  }) {
    return AthleteWorkoutResult(
      status: status ?? this.status,
      athleteId: athleteId,
      date: date,
      occurrence: occurrence ?? this.occurrence,
      matchingOccurrences: matchingOccurrences,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      executionSnapshot: executionSnapshot ?? this.executionSnapshot,
      adaptationAvailable: adaptationAvailable ?? this.adaptationAvailable,
      canStartWorkout: canStartWorkout ?? this.canStartWorkout,
      adaptationStatus: adaptationStatus,
      adaptationDetail: adaptationDetail,
      startStatus: startStatus,
      startDetail: startDetail,
      canCompleteWorkout: canCompleteWorkout,
      completionStatus: completionStatus,
      completionDetail: completionDetail,
      trainingSessionRecord: trainingSessionRecord,
    );
  }

  AthleteWorkoutResult withStartOutcome({
    required AthleteWorkoutStartStatus startStatus,
    String? startDetail,
    SessionOccurrence? occurrence,
    SessionOccurrenceLifecycleState? lifecycleState,
    AdaptedSessionExecutionSnapshot? executionSnapshot,
    AthleteWorkoutResolutionStatus? status,
    bool? adaptationAvailable,
    bool? canStartWorkout,
    bool? canCompleteWorkout,
  }) {
    return AthleteWorkoutResult(
      status: status ?? this.status,
      athleteId: athleteId,
      date: date,
      occurrence: occurrence ?? this.occurrence,
      matchingOccurrences: matchingOccurrences,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      executionSnapshot: executionSnapshot ?? this.executionSnapshot,
      adaptationAvailable: adaptationAvailable ?? this.adaptationAvailable,
      canStartWorkout: canStartWorkout ?? this.canStartWorkout,
      adaptationStatus: adaptationStatus,
      adaptationDetail: adaptationDetail,
      startStatus: startStatus,
      startDetail: startDetail,
      canCompleteWorkout: canCompleteWorkout ?? this.canCompleteWorkout,
      completionStatus: completionStatus,
      completionDetail: completionDetail,
      trainingSessionRecord: trainingSessionRecord,
    );
  }

  AthleteWorkoutResult withCompletionOutcome({
    required AthleteWorkoutCompletionStatus completionStatus,
    String? completionDetail,
    domain_record.TrainingSessionRecord? trainingSessionRecord,
    SessionOccurrence? occurrence,
    SessionOccurrenceLifecycleState? lifecycleState,
    AdaptedSessionExecutionSnapshot? executionSnapshot,
    AthleteWorkoutResolutionStatus? status,
    bool? adaptationAvailable,
    bool? canStartWorkout,
    bool? canCompleteWorkout,
  }) {
    return AthleteWorkoutResult(
      status: status ?? this.status,
      athleteId: athleteId,
      date: date,
      occurrence: occurrence ?? this.occurrence,
      matchingOccurrences: matchingOccurrences,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      executionSnapshot: executionSnapshot ?? this.executionSnapshot,
      adaptationAvailable: adaptationAvailable ?? this.adaptationAvailable,
      canStartWorkout: canStartWorkout ?? this.canStartWorkout,
      adaptationStatus: adaptationStatus,
      adaptationDetail: adaptationDetail,
      startStatus: startStatus,
      startDetail: startDetail,
      canCompleteWorkout: canCompleteWorkout ?? this.canCompleteWorkout,
      completionStatus: completionStatus,
      completionDetail: completionDetail,
      trainingSessionRecord:
          trainingSessionRecord ?? this.trainingSessionRecord,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AthleteWorkoutResult &&
        other.status == status &&
        other.athleteId == athleteId &&
        other.date == date &&
        other.occurrence == occurrence &&
        other.adaptationAvailable == adaptationAvailable &&
        other.canStartWorkout == canStartWorkout &&
        other.canCompleteWorkout == canCompleteWorkout &&
        other.adaptationStatus == adaptationStatus &&
        other.adaptationDetail == adaptationDetail &&
        other.startStatus == startStatus &&
        other.startDetail == startDetail &&
        other.completionStatus == completionStatus &&
        other.completionDetail == completionDetail &&
        other.trainingSessionRecord == trainingSessionRecord &&
        _listEquals(other.matchingOccurrences, matchingOccurrences);
  }

  @override
  int get hashCode => Object.hash(
        status,
        athleteId,
        date,
        occurrence,
        adaptationAvailable,
        canStartWorkout,
        canCompleteWorkout,
        adaptationStatus,
        adaptationDetail,
        startStatus,
        startDetail,
        completionStatus,
        completionDetail,
        trainingSessionRecord,
        Object.hashAll(matchingOccurrences),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
