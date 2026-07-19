import '../../../models/exercise.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';

/// Builds canonical [SessionExecutionPlan] projections for preview and athlete flows.
class SessionExecutionPlanBuilder {
  const SessionExecutionPlanBuilder();

  SessionExecutionPlan build({
    required String sessionId,
    required String sessionTitle,
    required List<SessionBlock> blocks,
    List<Exercise> exercises = const [],
    String? programmeContextLabel,
    int? durationMin,
    String? coachNotes,
  }) {
    final exerciseById = {
      for (final exercise in exercises) exercise.exerciseId: exercise,
    };

    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    return SessionExecutionPlan(
      sessionId: sessionId,
      sessionTitle:
          sessionTitle.trim().isEmpty ? 'Session' : sessionTitle.trim(),
      blocks: ordered
          .map(
            (block) => SessionExecutionBlock.fromSessionBlock(
              block,
              exercisesById: exerciseById,
            ),
          )
          .toList(growable: false),
      durationMin: durationMin,
      coachNotes: coachNotes,
      programmeContextLabel: programmeContextLabel,
    );
  }
}
