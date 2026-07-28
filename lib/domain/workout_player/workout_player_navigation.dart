import '../adaptation/application/adapted_session_execution_snapshot.dart';
import 'value_objects/workout_player_position.dart';

/// One navigable exercise slot in workout order.
class WorkoutPlayerNavigableStep {
  const WorkoutPlayerNavigableStep({
    required this.sourceBlockLocalId,
    required this.exerciseLinkLocalId,
    required this.stepIndex,
  });

  final String sourceBlockLocalId;
  final String exerciseLinkLocalId;
  final int stepIndex;

  WorkoutPlayerPosition toPosition() {
    return WorkoutPlayerPosition(
      sourceBlockLocalId: sourceBlockLocalId,
      exerciseLinkLocalId: exerciseLinkLocalId,
      stepIndex: stepIndex,
    );
  }
}

/// Read-only navigation over an execution snapshot (prescription source of truth).
class WorkoutPlayerNavigation {
  const WorkoutPlayerNavigation._();

  static List<WorkoutPlayerNavigableStep> navigableSteps(
    AdaptedSessionExecutionSnapshot snapshot,
  ) {
    final blocks = [...snapshot.retainedBlocks]
      ..sort((a, b) => a.sourcePosition.compareTo(b.sourcePosition));

    final steps = <WorkoutPlayerNavigableStep>[];
    for (final block in blocks) {
      for (final exercise in block.exercises) {
        steps.add(
          WorkoutPlayerNavigableStep(
            sourceBlockLocalId: block.sourceBlockLocalId,
            exerciseLinkLocalId: exercise.exerciseLinkLocalId,
            stepIndex: steps.length,
          ),
        );
      }
    }
    return List.unmodifiable(steps);
  }

  static WorkoutPlayerPosition? positionAtStepIndex({
    required AdaptedSessionExecutionSnapshot snapshot,
    required int stepIndex,
  }) {
    final steps = navigableSteps(snapshot);
    if (stepIndex < 0 || stepIndex >= steps.length) return null;
    return steps[stepIndex].toPosition();
  }

  static WorkoutPlayerPosition? firstPosition(
    AdaptedSessionExecutionSnapshot snapshot,
  ) {
    return positionAtStepIndex(snapshot: snapshot, stepIndex: 0);
  }

  static int? indexOfBlock({
    required AdaptedSessionExecutionSnapshot snapshot,
    required String sourceBlockLocalId,
  }) {
    final steps = navigableSteps(snapshot);
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].sourceBlockLocalId == sourceBlockLocalId) return i;
    }
    return null;
  }

  static int? nextBlockFirstStepIndex({
    required AdaptedSessionExecutionSnapshot snapshot,
    required WorkoutPlayerPosition current,
  }) {
    final steps = navigableSteps(snapshot);
    for (var i = current.stepIndex + 1; i < steps.length; i++) {
      if (steps[i].sourceBlockLocalId != current.sourceBlockLocalId) {
        return i;
      }
    }
    return null;
  }

  static int remainingStepsAfter({
    required AdaptedSessionExecutionSnapshot snapshot,
    required WorkoutPlayerPosition current,
  }) {
    final total = navigableSteps(snapshot).length;
    if (total == 0) return 0;
    return (total - 1 - current.stepIndex).clamp(0, total);
  }

  static bool isAtLastStep({
    required AdaptedSessionExecutionSnapshot snapshot,
    required WorkoutPlayerPosition current,
  }) {
    final steps = navigableSteps(snapshot);
    if (steps.isEmpty) return true;
    return current.stepIndex >= steps.length - 1;
  }
}
