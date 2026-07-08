import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/circuit_session_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/protocol_step_repository.dart';
import '../../models/exercise.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';

class SessionPlayerScreen extends StatefulWidget {
  const SessionPlayerScreen({
    super.key,
    required this.protocolId,
    this.displayTitle,
  });

  final String protocolId;
  final String? displayTitle;

  String get sessionLabel => displayTitle ?? protocolId;

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  final _stepRepository = const ProtocolStepRepository();
  final _exerciseRepository = ExerciseRepository();

  bool _isTimerRunning = false;
  late final Future<List<SessionStep>> _stepsFuture;

  @override
  void initState() {
    super.initState();
    _stepsFuture = _loadSessionSteps();
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

  void _finishSession() {
    setState(() => _isTimerRunning = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mode = executionModeForSession(widget.sessionLabel);

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<SessionStep>>(
          future: _stepsFuture,
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

            final steps = snapshot.data ?? [];

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
                  else if (mode == SessionExecutionMode.guidedSteps) ...[
                    SessionProgressBar(
                      currentStep: steps.first.stepNumber,
                      totalSteps: steps.length,
                    ),
                    const SizedBox(height: CohortSpacing.xl),
                    SessionStepCard(
                      step: steps.first,
                      onComplete: () {},
                    ),
                  ] else
                    CircuitSessionCard(
                      steps: steps,
                      isTimerRunning: _isTimerRunning,
                      onStartTimer: _startTimer,
                      onFinishSession: _finishSession,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
