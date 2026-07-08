import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';

class SessionPlayerScreen extends StatelessWidget {
  const SessionPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

              const Text(
                'Bodyweight Grinder',
                style: CohortTextStyles.h1,
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SessionProgressBar(
                currentStep: 1,
                totalSteps: 5,
              ),

              const SizedBox(height: CohortSpacing.xl),

              SessionStepCard(
                stepNumber: 1,
                title: 'Air Squat',
                prescription: '3 sets × 12 reps • Controlled tempo',
                coachCue:
                    'Sit back and down. Keep chest tall and knees tracking over toes.',
                onComplete: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
