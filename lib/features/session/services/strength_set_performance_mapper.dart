import '../../../models/session_step.dart';
import '../../../models/strength_set_performance.dart';
import '../models/strength_set_entry.dart';
import 'strength_load_parser.dart';

/// Builds [StrengthSetPerformance] rows from in-session set state.
class StrengthSetPerformanceMapper {
  const StrengthSetPerformanceMapper();

  StrengthSetPerformance? fromEntry({
    required int trainingSessionId,
    required SessionStep step,
    required StrengthSetEntry entry,
    String? athleteNote,
  }) {
    final protocolStepId = step.protocolStepId;
    final exerciseId = step.exerciseId?.trim();

    if (protocolStepId == null || exerciseId == null || exerciseId.isEmpty) {
      return null;
    }

    final targetLoad = StrengthLoadParser.parse(step.prescribedLoad);
    final actualLoad = StrengthLoadParser.parse(entry.load);

    return StrengthSetPerformance(
      id: 0,
      trainingSessionId: trainingSessionId,
      protocolStepId: protocolStepId,
      exerciseId: exerciseId,
      setNumber: entry.setNumber,
      targetReps: entry.targetReps ?? step.prescribedReps,
      targetLoadValue: targetLoad.value,
      targetLoadUnit: targetLoad.unit,
      actualReps: entry.actualReps,
      loadValue: actualLoad.value,
      loadUnit: actualLoad.unit ?? targetLoad.unit,
      rpe: entry.rpe,
      completed: entry.completed,
      isExtraSet: entry.isExtraSet,
      athleteNote: _nullableString(athleteNote),
    );
  }

  static String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
