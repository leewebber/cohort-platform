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
import '../../models/protocol.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';
import 'services/session_execution_router.dart';
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
  });

  final SessionExecutionMode mode;
  final List<SessionStep> steps;
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  final _protocolRepository = ProtocolRepository();
  final _stepRepository = const ProtocolStepRepository();
  final _exerciseRepository = ExerciseRepository();
  final _trainingSessionRepository = const TrainingSessionRepository();
  static const _executionRouter = SessionExecutionRouter();

  bool _isTimerRunning = false;
  late final Future<_SessionPlayerContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadSessionContent();
  }

  Future<_SessionPlayerContent> _loadSessionContent() async {
    final protocol = await _protocolRepository.getProtocolById(widget.protocolId);
    final steps = await _loadSessionSteps();
    final mode = _executionRouter.determineExecutionMode(
      protocol ??
          Protocol(
            protocolId: widget.protocolId,
            name: widget.sessionLabel,
          ),
    );

    return _SessionPlayerContent(mode: mode, steps: steps);
  }

  Future<List<SessionStep>> _loadSessionSteps() async {
    final protocolSteps =
        await _stepRepository.getProtocolSteps(widget.protocolId);

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
          onFinishSession: _finishSession,
        );
      case SessionExecutionMode.intervals:
        // TODO(Execution): Replace with IntervalSessionView.
        return _legacyGuidedPlayer(steps);
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

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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

                  if (steps.isEmpty)
                    const Text(
                      'No session steps available.',
                      style: CohortTextStyles.body,
                    )
                  else
                    _buildExecutionView(mode: mode, steps: steps),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
