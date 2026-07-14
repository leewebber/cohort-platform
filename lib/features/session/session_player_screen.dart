import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/circuit_session_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../data/repositories/protocol_step_repository.dart';
import '../../data/repositories/training_session_repository.dart';
import '../../models/exercise.dart';
import '../../models/interval_session_plan.dart';
import '../../models/protocol.dart';
import '../../models/protocol_step.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';
import '../../models/training_session_completion_context.dart';
import 'models/interval_session_finish_summary.dart';
import 'models/strength_session_finish_summary.dart';
import 'services/interval_session_plan_builder.dart';
import 'services/interval_session_leave_coordinator.dart';
import 'services/session_execution_router.dart';
import 'services/session_wins_builder.dart';
import 'services/strength_session_leave_coordinator.dart';
import 'session_review_screen.dart';
import 'widgets/interval_session_view.dart';
import 'widgets/strength_session_view.dart';

class SessionPlayerScreen extends StatefulWidget {
  const SessionPlayerScreen({
    super.key,
    required this.protocolId,
    this.displayTitle,
    this.trainingSessionId,
  });

  final String protocolId;
  final String? displayTitle;
  final int? trainingSessionId;

  String get sessionLabel => displayTitle ?? protocolId;

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerContent {
  const _SessionPlayerContent({
    required this.mode,
    required this.steps,
    this.athleteId,
    this.intervalPlan,
    this.intervalPlanError,
  });

  final SessionExecutionMode mode;
  final List<SessionStep> steps;
  final String? athleteId;
  final IntervalSessionPlan? intervalPlan;
  final String? intervalPlanError;
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  final _protocolRepository = ProtocolRepository();
  final _stepRepository = const ProtocolStepRepository();
  final _exerciseRepository = ExerciseRepository();
  final _trainingSessionRepository = const TrainingSessionRepository();
  static const _executionRouter = SessionExecutionRouter();
  static const _sessionWinsBuilder = SessionWinsBuilder();
  static const _intervalPlanBuilder = IntervalSessionPlanBuilder();

  bool _isTimerRunning = false;
  late final Future<_SessionPlayerContent> _contentFuture;
  StrengthSessionLeaveCoordinator? _strengthLeaveCoordinator;
  IntervalSessionLeaveCoordinator? _intervalLeaveCoordinator;
  SessionExecutionMode? _resolvedMode;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadSessionContent();
  }

  Future<_SessionPlayerContent> _loadSessionContent() async {
    final protocol = await _protocolRepository.getProtocolById(widget.protocolId);
    final protocolSteps =
        await _stepRepository.getProtocolSteps(widget.protocolId);
    final steps = await _sessionStepsFromProtocolSteps(protocolSteps);
    final athleteId = await _resolveAthleteId();
    final resolvedProtocol = protocol ??
        Protocol(
          protocolId: widget.protocolId,
          name: widget.sessionLabel,
        );
    final mode = _executionRouter.determineExecutionMode(resolvedProtocol);

    IntervalSessionPlan? intervalPlan;
    String? intervalPlanError;
    if (mode == SessionExecutionMode.intervals) {
      try {
        intervalPlan = _intervalPlanBuilder.build(
          protocol: resolvedProtocol,
          steps: protocolSteps,
        );
      } on StateError catch (error) {
        intervalPlanError = error.message;
      }
    }

    return _SessionPlayerContent(
      mode: mode,
      steps: steps,
      athleteId: athleteId,
      intervalPlan: intervalPlan,
      intervalPlanError: intervalPlanError,
    );
  }

  Future<String?> _resolveAthleteId() async {
    final sessionId = widget.trainingSessionId;
    if (sessionId == null) {
      return null;
    }

    final session = await _trainingSessionRepository.getSessionById(sessionId);
    final athleteId = session?.athleteId.trim();
    if (athleteId == null || athleteId.isEmpty) {
      return null;
    }

    return athleteId;
  }

  Future<List<SessionStep>> _sessionStepsFromProtocolSteps(
    List<ProtocolStep> protocolSteps,
  ) async {
    final exerciseIds = protocolSteps
        .map((step) => step.exerciseId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final exercisesById = <String, Exercise>{};

    for (final exerciseId in exerciseIds) {
      final exercise = await _exerciseRepository.getExerciseById(exerciseId);
      if (exercise != null) {
        exercisesById[exerciseId] = exercise;
      }
    }

    return protocolSteps
        .map(
          (step) => SessionStep.fromProtocolStep(
            step,
            exercise: step.exerciseId != null
                ? exercisesById[step.exerciseId!]
                : null,
          ),
        )
        .toList();
  }

  void _startTimer() {
    setState(() => _isTimerRunning = true);
  }

  Future<void> _finishStrengthSession(
    StrengthSessionFinishSummary summary,
  ) async {
    setState(() => _isTimerRunning = false);

    final sessionId = widget.trainingSessionId;
    if (sessionId != null) {
      await _trainingSessionRepository.completeSession(
        sessionId,
        completion: TrainingSessionCompletionContext(
          sessionNote: summary.sessionNote,
          endedEarly: summary.endedEarly,
          completionReason: summary.endReasonLabel,
          completedExerciseCount: summary.completedExerciseCount,
          totalExerciseCount: summary.totalExerciseCount,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    final wins = _sessionWinsBuilder.build(summary);

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (reviewContext) => SessionReviewScreen(
          sessionTitle: summary.sessionTitle,
          wins: wins,
          sessionNote: summary.sessionNote,
          endedEarly: summary.endedEarly,
          completedExerciseCount: summary.completedExerciseCount,
          totalExerciseCount: summary.totalExerciseCount,
          endReasonLabel: summary.endReasonLabel,
          onReturnHome: () => Navigator.of(reviewContext).pop(),
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    final isStrengthSession =
        _resolvedMode == SessionExecutionMode.structuredStrength;
    final coordinator = _strengthLeaveCoordinator;

    if (isStrengthSession &&
        widget.trainingSessionId != null &&
        coordinator != null &&
        coordinator.hasRecordedProgress()) {
      await coordinator.confirmLeave(context);
      return;
    }

    final intervalCoordinator = _intervalLeaveCoordinator;
    if (_resolvedMode == SessionExecutionMode.intervals &&
        widget.trainingSessionId != null &&
        intervalCoordinator != null &&
        intervalCoordinator.hasRecordedProgress()) {
      await intervalCoordinator.confirmLeave(context);
      return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _finishIntervalSession(
    IntervalSessionFinishSummary summary,
  ) async {
    setState(() => _isTimerRunning = false);

    final sessionId = widget.trainingSessionId;
    if (sessionId != null) {
      await _trainingSessionRepository.completeSession(
        sessionId,
        completion: TrainingSessionCompletionContext(
          sessionNote: summary.sessionNote,
          endedEarly: summary.endedEarly,
          completionReason: summary.endReasonLabel,
          completedExerciseCount: summary.completedWorkCount,
          totalExerciseCount: summary.totalWorkCount,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    final wins = _sessionWinsBuilder.buildInterval(summary);

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (reviewContext) => SessionReviewScreen(
          sessionTitle: summary.sessionTitle,
          wins: wins,
          sessionNote: summary.sessionNote,
          endedEarly: summary.endedEarly,
          completedExerciseCount: summary.completedWorkCount,
          totalExerciseCount: summary.totalWorkCount,
          endReasonLabel: summary.endReasonLabel,
          onReturnHome: () => Navigator.of(reviewContext).pop(),
        ),
      ),
    );
  }

  Future<void> _finishSession() async {
    setState(() => _isTimerRunning = false);

    final sessionId = widget.trainingSessionId;
    if (sessionId != null) {
      await _trainingSessionRepository.completeSession(sessionId);
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

  Widget _buildExecutionView({
    required SessionExecutionMode mode,
    required List<SessionStep> steps,
    String? athleteId,
    IntervalSessionPlan? intervalPlan,
    String? intervalPlanError,
  }) {
    switch (mode) {
      case SessionExecutionMode.circuit:
        // TODO(Execution): Replace with CircuitSessionView.
        return CircuitSessionCard(
          steps: steps,
          isTimerRunning: _isTimerRunning,
          onStartTimer: _startTimer,
          onFinishSession: _finishSession,
        );
      case SessionExecutionMode.structuredStrength:
        return StrengthSessionView(
          sessionTitle: widget.sessionLabel,
          steps: steps,
          trainingSessionId: widget.trainingSessionId,
          athleteId: athleteId,
          onFinishSession: _finishStrengthSession,
          onLeaveCoordinatorReady: (coordinator) {
            _strengthLeaveCoordinator = coordinator;
          },
        );
      case SessionExecutionMode.intervals:
        if (intervalPlanError != null) {
          return Text(
            intervalPlanError,
            style: CohortTextStyles.body,
          );
        }

        if (intervalPlan == null) {
          return const Text(
            'Unable to compile interval session plan.',
            style: CohortTextStyles.body,
          );
        }

        return IntervalSessionView(
          sessionTitle: widget.sessionLabel,
          plan: intervalPlan,
          trainingSessionId: widget.trainingSessionId,
          athleteId: athleteId,
          protocolId: widget.protocolId,
          onFinishSession: _finishIntervalSession,
          onLeaveCoordinatorReady: (coordinator) {
            _intervalLeaveCoordinator = coordinator;
          },
        );
      case SessionExecutionMode.recoveryFlow:
        // TODO(Execution): Replace with RecoverySessionView.
        return _legacyGuidedPlayer(steps);
    }
  }

  Widget _legacyGuidedPlayer(List<SessionStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionProgressBar(
          currentStep: steps.first.stepNumber,
          totalSteps: steps.length,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionStepCard(
          step: steps.first,
          onComplete: () {},
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_SessionPlayerContent>(
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Loading session...',
                  style: CohortTextStyles.body,
                ),
              );
            }

            final content = snapshot.data;
            final steps = content?.steps ?? [];
            final mode = content?.mode ?? SessionExecutionMode.circuit;
            final athleteId = content?.athleteId;
            final intervalPlan = content?.intervalPlan;
            final intervalPlanError = content?.intervalPlanError;
            _resolvedMode = mode;

            final interceptBack = widget.trainingSessionId != null &&
                (mode == SessionExecutionMode.structuredStrength ||
                    mode == SessionExecutionMode.intervals);

            final hasIntervalPlanError = mode == SessionExecutionMode.intervals &&
                intervalPlanError != null;

            return PopScope(
              canPop: !interceptBack,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) {
                  return;
                }
                await _handleBackNavigation();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: _handleBackNavigation,
                      child: const Text('← Back'),
                    ),

                    const SizedBox(height: CohortSpacing.md),

                    const SectionTitle('Session'),

                    const SizedBox(height: CohortSpacing.md),

                    Text(
                      widget.sessionLabel,
                      style: CohortTextStyles.h1,
                    ),

                    const SizedBox(height: CohortSpacing.xl),

                    if (hasIntervalPlanError)
                      Text(
                        intervalPlanError,
                        style: CohortTextStyles.body,
                      )
                    else if (steps.isEmpty &&
                        mode != SessionExecutionMode.intervals)
                      const Text(
                        'No session steps available.',
                        style: CohortTextStyles.body,
                      )
                    else if (mode == SessionExecutionMode.intervals &&
                        intervalPlan == null)
                      const Text(
                        'Unable to compile interval session plan.',
                        style: CohortTextStyles.body,
                      )
                    else
                      _buildExecutionView(
                        mode: mode,
                        steps: steps,
                        athleteId: athleteId,
                        intervalPlan: intervalPlan,
                        intervalPlanError: intervalPlanError,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
