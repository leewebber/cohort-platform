import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';

/// Advances active plan day / week / phase after a completed session.
///
/// Fully deterministic from [PlanDefinition] shape + current cursor.
class PlanProgressionService {
  const PlanProgressionService();

  static const phaseFoundation = 'Foundation';
  static const phaseBuild = 'Build';
  static const phasePeak = 'Peak';

  PlanAssignment advance({
    required PlanAssignment assignment,
    required PlanDefinition plan,
  }) {
    if (!assignment.isActive) return assignment;

    final daysPerWeek = plan.recommendedDaysPerWeek.clamp(1, 7);
    var day = assignment.currentDay + 1;
    var week = assignment.currentWeek;

    if (day > daysPerWeek) {
      day = 1;
      week += 1;
    }

    final phase = _phaseForWeek(week: week, durationWeeks: plan.durationWeeks);

    return assignment.copyWith(
      currentDay: day,
      currentWeek: week,
      currentPhase: phase,
    );
  }

  /// Three equal-ish blocks across plan duration: Foundation → Build → Peak.
  String _phaseForWeek({required int week, required int durationWeeks}) {
    final total = durationWeeks.clamp(1, 52);
    final block = (total / 3).ceil().clamp(1, total);
    if (week > block * 2) return phasePeak;
    if (week > block) return phaseBuild;
    return phaseFoundation;
  }
}
