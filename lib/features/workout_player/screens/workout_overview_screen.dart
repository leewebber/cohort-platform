import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../models/training_session_completion_context.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../adaptation/services/prepared_execution_reverter.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
import '../controllers/workout_player_controller.dart';
import '../models/workout_player_result.dart';
import '../models/workout_session_brief.dart';
import '../services/coach_brain_workout_plan_service.dart';
import '../widgets/workout_player_widgets.dart';
import 'workout_player_screen.dart';

/// Mission briefing before the athlete starts.
class WorkoutOverviewScreen extends StatefulWidget {
  const WorkoutOverviewScreen({
    super.key,
    required this.athleteId,
    this.trainingSessionId,
    this.programmeContext,
    this.planService,
    this.preloadedPlan,
    this.preloadedBrief,
    this.orchestrationId,
    this.onFinished,
  });

  final String athleteId;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final CoachBrainWorkoutPlanService? planService;
  final CoachBrainWorkoutPlan? preloadedPlan;
  final WorkoutSessionBrief? preloadedBrief;
  final String? orchestrationId;
  final ValueChanged<WorkoutPlayerResult>? onFinished;

  @override
  State<WorkoutOverviewScreen> createState() => _WorkoutOverviewScreenState();
}

class _WorkoutOverviewScreenState extends State<WorkoutOverviewScreen> {
  late Future<CoachBrainWorkoutPlan> _planFuture;
  late final CoachBrainWorkoutPlanService _planService =
      widget.planService ?? CoachBrainWorkoutPlanService();

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
  }

  Future<CoachBrainWorkoutPlan> _loadPlan() {
    final preloaded = widget.preloadedPlan;
    if (preloaded != null) return Future.value(preloaded);
    return _planService.resolveTodayPlan(athleteId: widget.athleteId);
  }

  void _retry() {
    setState(() {
      _planFuture = _loadPlan();
    });
  }

  Future<void> _revertToProgrammed() async {
    final restored = await PreparedExecutionReverter().revertToProgrammed();
    if (!mounted) return;
    if (restored == null) return;
    setState(() {
      _planFuture = Future.value(restored.planBundle);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restored the original programmed session.'),
      ),
    );
  }

  Future<void> _start(CoachBrainWorkoutPlan resolved) async {
    final controller = WorkoutPlayerController(
      plan: resolved.plan,
      brief: resolved.brief,
      orchestrationId:
          widget.orchestrationId ?? resolved.planningContext.orchestrationId,
    );
    controller.startSession();

    final result = await Navigator.of(context).push<WorkoutPlayerResult>(
      MaterialPageRoute(
        builder: (_) => WorkoutPlayerScreen(
          controller: controller,
          athleteId: widget.athleteId,
          trainingSessionId: widget.trainingSessionId,
          programmeContext: widget.programmeContext,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      widget.onFinished?.call(result);
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        title: const Text('TODAY', style: CohortTextStyles.eyebrow),
        centerTitle: false,
      ),
      body: FutureBuilder<CoachBrainWorkoutPlan>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: CohortColors.phosphor),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorBody(
              message: snapshot.error?.toString() ??
                  'Could not prepare today\'s session.',
              onRetry: _retry,
            );
          }

          final resolved = snapshot.data!;
          final brief = resolved.brief;
          final adaptation =
              AthleteProfileSession.programme?.acceptedAdaptation;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      CohortSpacing.xl,
                      CohortSpacing.md,
                      CohortSpacing.xl,
                      CohortSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(brief.sessionName, style: CohortTextStyles.h1),
                        const SizedBox(height: CohortSpacing.lg),
                        if (brief.objective != null)
                          WorkoutMetaRow(
                            label: 'Objective',
                            value: brief.objective!,
                          ),
                        WorkoutMetaRow(
                          label: 'Estimated duration',
                          value: brief.durationLabel,
                        ),
                        if (brief.primaryFocus != null)
                          WorkoutMetaRow(
                            label: 'Primary focus',
                            value: brief.primaryFocus!,
                          ),
                        if (brief.trainingIntent != null)
                          WorkoutMetaRow(
                            label: 'Training intent',
                            value: brief.trainingIntent!,
                          ),
                        if (brief.sessionDifficulty != null)
                          WorkoutMetaRow(
                            label: 'Session difficulty',
                            value: brief.sessionDifficulty!,
                          ),
                        if (brief.sessionNotes != null)
                          WorkoutMetaRow(
                            label: 'Session notes',
                            value: brief.sessionNotes!,
                          ),
                        if (brief.coachNotes != null)
                          WorkoutMetaRow(
                            label: 'Coach notes',
                            value: brief.coachNotes!,
                          ),
                        if (adaptation != null) ...[
                          const SizedBox(height: CohortSpacing.xl),
                          Text(
                            'ACCEPTED ADAPTATION',
                            style: CohortTextStyles.sectionLabel,
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            'Reason: ${adaptation.reasonCode}',
                            style: CohortTextStyles.body,
                          ),
                          if (adaptation.changeSummary.isNotEmpty) ...[
                            const SizedBox(height: CohortSpacing.sm),
                            ...adaptation.changeSummary.map(
                              (line) => Text(
                                '• $line',
                                style: CohortTextStyles.body,
                              ),
                            ),
                          ],
                          TextButton(
                            onPressed: _revertToProgrammed,
                            child: Text(
                              'Use original programmed session',
                              style: CohortTextStyles.body.copyWith(
                                color: CohortColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CohortSpacing.xl,
                    CohortSpacing.md,
                    CohortSpacing.xl,
                    CohortSpacing.xl,
                  ),
                  child: CohortButton(
                    label: 'START SESSION',
                    showTrailingArrow: true,
                    onPressed: () => _start(resolved),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unable to load session', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          Text(message, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Completes training session bookkeeping after player finish.
class WorkoutCompletionService {
  WorkoutCompletionService({
    TrainingSessionRepository? trainingSessions,
    ProgrammeSessionProgressionCoordinator? progression,
  }) : _trainingSessions = trainingSessions ?? const TrainingSessionRepository(),
       _progression =
           progression ?? ProgrammeSessionProgressionCoordinator();

  final TrainingSessionRepository _trainingSessions;
  final ProgrammeSessionProgressionCoordinator _progression;

  Future<void> complete({
    required String athleteId,
    required int? trainingSessionId,
    required ProgrammeExecutionContext? programmeContext,
    required WorkoutPlayerResult result,
  }) async {
    final sessionId = trainingSessionId;
    if (sessionId == null) return;

    await _trainingSessions.completeSession(
      sessionId,
      completion: TrainingSessionCompletionContext(
        endedEarly: !result.completed,
        sessionNote: result.notes,
        completedExerciseCount: result.exercisesCompleted,
        totalExerciseCount: result.totalExercises,
      ),
    );

    await _progression.handleSessionCompleted(
      athleteId: athleteId,
      programmeContext: programmeContext,
      trainingSessionId: sessionId,
      endedEarly: !result.completed,
      resolutionNote: result.notes,
    );
  }
}
