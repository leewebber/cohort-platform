import '../../../models/workout_format.dart';
import '../models/session_execution_plan.dart';

enum ProductionRecoveryTreatment {
  /// Structured blocks execute on ActiveSessionScreen.
  executableBlocks,

  /// Authored rest / passive recovery — guidance only, not a workout.
  guidanceOnly,

  /// Dedicated RecoverySessionView / TODO player is not a production path.
  unavailable,
}

class ProductionRecoverySessionPolicy {
  const ProductionRecoverySessionPolicy();

  ProductionRecoveryTreatment decide({
    required SessionExecutionPlan plan,
    required bool authoredAsRecoveryOrRest,
  }) {
    final executable = plan.blocks.where((block) {
      return block.hasAthleteVisibleContent &&
          block.workoutFormat != WorkoutFormat.other;
    }).toList();
    if (executable.isNotEmpty) {
      return ProductionRecoveryTreatment.executableBlocks;
    }
    if (authoredAsRecoveryOrRest) {
      return ProductionRecoveryTreatment.guidanceOnly;
    }
    return ProductionRecoveryTreatment.unavailable;
  }
}
