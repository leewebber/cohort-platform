import 'vocabulary/workout_execution_record_lifecycle_status.dart';
import 'workout_execution_record.dart';
import 'workout_execution_record_transition_result.dart';

class WorkoutExecutionRecordLifecycle {
  const WorkoutExecutionRecordLifecycle._();

  static const allowedTransitions = {
    WorkoutExecutionRecordLifecycleStatus.recording: {
      WorkoutExecutionRecordLifecycleStatus.completed,
      WorkoutExecutionRecordLifecycleStatus.abandoned,
    },
  };

  static bool canTransition({
    required WorkoutExecutionRecordLifecycleStatus from,
    required WorkoutExecutionRecordLifecycleStatus to,
  }) {
    if (from.isTerminal) return false;
    final allowed = allowedTransitions[from];
    return allowed?.contains(to) ?? false;
  }

  static WorkoutExecutionRecordTransitionResult requireTransition({
    required WorkoutExecutionRecord record,
    required WorkoutExecutionRecordLifecycleStatus target,
  }) {
    if (!canTransition(from: record.lifecycleStatus, to: target)) {
      return WorkoutExecutionRecordTransitionResult.singleFailure(
        WorkoutExecutionRecordTransitionIssueCode.invalidLifecycleStatus,
        detail: '${record.lifecycleStatus.name}->${target.name}',
      );
    }
    return WorkoutExecutionRecordTransitionResult.success(record);
  }
}
