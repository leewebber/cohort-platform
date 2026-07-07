import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocols/protocol_library_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openProtocolLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProtocolLibraryScreen(),
      ),
    );
  }

  void _openExerciseLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Cohort Field Manual'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                "What's today's focus?",
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Train with purpose. Choose the right session for your goal, equipment and recovery state.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xl),

              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SectionTitle("Today's Recommendation"),
                    SizedBox(height: CohortSpacing.lg),
                    Text(
                      'Generate the right session for today.',
                      style: CohortTextStyles.h2,
                    ),
                    SizedBox(height: CohortSpacing.sm),
                    Text(
                      'Soon you’ll be able to select your goal, equipment, time and recovery state.',
                      style: CohortTextStyles.small,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CohortSpacing.lg),

              CohortButton(
                label: "Generate Today's Protocol",
                onPressed: () {},
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Knowledge'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openProtocolLibrary(context),
                child: const _HomeActionRow(
                  title: 'Protocol Library',
                  subtitle: 'Browse and search the full Cohort protocol library.',
                  status: 'OPEN',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openExerciseLibrary(context),
                child: const _HomeActionRow(
                  title: 'Exercise Library',
                  subtitle: 'Browse movements, cues and coaching knowledge.',
                  status: 'OPEN',
                ),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Planning'),
              const SizedBox(height: CohortSpacing.md),

              const CohortCard(
                child: _HomeActionRow(
                  title: 'Weekly Blueprint',
                  subtitle: 'Build a balanced week from the Cohort training structure.',
                  status: 'SOON',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              const CohortCard(
                child: _HomeActionRow(
                  title: 'Training Log',
                  subtitle: 'Record completed sessions and track progress.',
                  status: 'SOON',
                ),
              ),

              const SizedBox(height: CohortSpacing.xxl),

              const Center(
                child: Text(
                  'Build physical capability.',
                  style: CohortTextStyles.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.lg),
        Text(status, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}