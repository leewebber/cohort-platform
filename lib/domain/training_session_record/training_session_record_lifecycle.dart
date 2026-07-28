import 'vocabulary/training_session_record_lifecycle_status.dart';
import 'training_session_record.dart';
import 'training_session_record_transition_result.dart';

class TrainingSessionRecordLifecycle {
  const TrainingSessionRecordLifecycle._();

  static const allowedTransitions = {
    TrainingSessionRecordLifecycleStatus.recording: {
      TrainingSessionRecordLifecycleStatus.completed,
      TrainingSessionRecordLifecycleStatus.abandoned,
    },
  };

  static bool canTransition({
    required TrainingSessionRecordLifecycleStatus from,
    required TrainingSessionRecordLifecycleStatus to,
  }) {
    if (from.isTerminal) return false;
    final allowed = allowedTransitions[from];
    return allowed?.contains(to) ?? false;
  }

  static TrainingSessionRecordTransitionResult requireTransition({
    required TrainingSessionRecord record,
    required TrainingSessionRecordLifecycleStatus target,
  }) {
    if (!canTransition(from: record.lifecycleStatus, to: target)) {
      return TrainingSessionRecordTransitionResult.singleFailure(
        TrainingSessionRecordTransitionIssueCode.invalidLifecycleStatus,
        detail: '${record.lifecycleStatus.name}->${target.name}',
      );
    }
    return TrainingSessionRecordTransitionResult.success(record);
  }
}
