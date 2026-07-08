import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/circuit_session_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';

class SessionPlayerScreen extends StatefulWidget {
  const SessionPlayerScreen({
    super.key,
    this.sessionTitle = 'Bodyweight Grinder',
  });

  final String sessionTitle;

  @override
  State<SessionPlayerScreen> createState() => _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends State<SessionPlayerScreen> {
  bool _isTimerRunning = false;

  static const _bodyweightGrinderSteps = [
    SessionStep(
      stepNumber: 1,
      title: 'Air Squat',
      prescription: '12 reps • Controlled tempo',
      coachCue:
          'Sit back and down. Keep chest tall and knees tracking over toes.',
    ),
    SessionStep(
      stepNumber: 2,
      title: 'Push Up',
      prescription: '10 reps • Full range',
      coachCue: 'Maintain a straight line from head to heel.',
    ),
    SessionStep(
      stepNumber: 3,
      title: 'Walking Lunge',
      prescription: '10 reps each leg',
      coachCue: 'Long stride. Back knee kisses the floor.',
    ),
    SessionStep(
      stepNumber: 4,
      title: 'Plank Hold',
      prescription: '30 seconds • Brace hard',
      coachCue: 'Ribs down, glutes tight, breathe steadily.',
    ),
    SessionStep(
      stepNumber: 5,
      title: 'Burpee',
      prescription: '8 reps • Steady pace',
      coachCue: 'Chest to floor, explode up, land soft.',
    ),
  ];

  static const _guidedSteps = [
    SessionStep(
      stepNumber: 1,
      title: 'Air Squat',
      prescription: '3 sets × 12 reps • Controlled tempo',
      coachCue:
          'Sit back and down. Keep chest tall and knees tracking over toes.',
    ),
    SessionStep(
      stepNumber: 2,
      title: 'Push Up',
      prescription: '3 sets × 10 reps • Full range',
      coachCue: 'Maintain a straight line from head to heel.',
    ),
    SessionStep(
      stepNumber: 3,
      title: 'Walking Lunge',
      prescription: '3 sets × 10 reps each leg',
      coachCue: 'Long stride. Back knee kisses the floor.',
    ),
    SessionStep(
      stepNumber: 4,
      title: 'Plank Hold',
      prescription: '3 sets × 30 seconds',
      coachCue: 'Ribs down, glutes tight, breathe steadily.',
    ),
    SessionStep(
      stepNumber: 5,
      title: 'Burpee',
      prescription: '3 sets × 8 reps',
      coachCue: 'Chest to floor, explode up, land soft.',
    ),
  ];

  List<SessionStep> get _steps {
    final mode = executionModeForSession(widget.sessionTitle);
    return mode == SessionExecutionMode.circuit
        ? _bodyweightGrinderSteps
        : _guidedSteps;
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
    final mode = executionModeForSession(widget.sessionTitle);
    final steps = _steps;
    final currentStep = steps.first;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                widget.sessionTitle,
                style: CohortTextStyles.h1,
              ),

              const SizedBox(height: CohortSpacing.xl),

              if (mode == SessionExecutionMode.guidedSteps) ...[
                SessionProgressBar(
                  currentStep: currentStep.stepNumber,
                  totalSteps: steps.length,
                ),
                const SizedBox(height: CohortSpacing.xl),
                SessionStepCard(
                  stepNumber: currentStep.stepNumber,
                  title: currentStep.title,
                  prescription: currentStep.prescription,
                  coachCue: currentStep.coachCue,
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
        ),
      ),
    );
  }
}
