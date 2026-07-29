import 'package:flutter/material.dart';

import '../../../data/repositories/training_session_repository.dart';
import '../../../models/training_session_status.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
import '../models/workout_player_result.dart';
import '../screens/workout_overview_screen.dart';
import 'coach_brain_workout_plan_service.dart';

/// Navigates Home → Workout Overview → Player → Complete → Home.
class WorkoutPlayerLauncher {
  WorkoutPlayerLauncher({
    TrainingSessionRepository? trainingSessions,
    ProgrammeSessionProgressionCoordinator? progression,
    CoachBrainWorkoutPlanService? planService,
  }) : _trainingSessions =
           trainingSessions ?? const TrainingSessionRepository(),
       _progression =
           progression ?? ProgrammeSessionProgressionCoordinator(),
       _planService = planService ?? CoachBrainWorkoutPlanService();

  final TrainingSessionRepository _trainingSessions;
  final ProgrammeSessionProgressionCoordinator _progression;
  final CoachBrainWorkoutPlanService _planService;

  Future<WorkoutPlayerResult?> launchFromHome({
    required BuildContext context,
    required String athleteId,
    required String protocolId,
    int? existingTrainingSessionId,
    ProgrammeExecutionContext? programmeContext,
    ProgrammeProgressSummary? programmeProgress,
    String? programmeId,
    int? weekNumber,
    bool resume = false,
  }) async {
    var trainingSessionId = existingTrainingSessionId;

    if (!resume || trainingSessionId == null) {
      final session = await _trainingSessions.createSession(
        athleteId: athleteId,
        protocolId: protocolId,
        status: TrainingSessionStatus.inProgress,
        programmeId: programmeId,
        weekNumber: weekNumber,
      );
      trainingSessionId = session.id;

      await _progression.markSessionStartedIfProgrammeBacked(
        athleteId: athleteId,
        programmeContext: programmeContext,
        trainingSessionId: trainingSessionId,
      );
    }

    if (!context.mounted) return null;

    return Navigator.of(context).push<WorkoutPlayerResult>(
      MaterialPageRoute(
        builder: (_) => WorkoutOverviewScreen(
          athleteId: athleteId,
          trainingSessionId: trainingSessionId,
          programmeContext: programmeContext,
          planService: _planService,
        ),
      ),
    );
  }

  /// Test / preview entry with a pre-resolved Coach Brain plan.
  Future<WorkoutPlayerResult?> launchWithPlan({
    required BuildContext context,
    required String athleteId,
    required CoachBrainWorkoutPlan plan,
    int? trainingSessionId,
    ProgrammeExecutionContext? programmeContext,
  }) {
    return Navigator.of(context).push<WorkoutPlayerResult>(
      MaterialPageRoute(
        builder: (_) => WorkoutOverviewScreen(
          athleteId: athleteId,
          trainingSessionId: trainingSessionId,
          programmeContext: programmeContext,
          preloadedPlan: plan,
        ),
      ),
    );
  }
}
