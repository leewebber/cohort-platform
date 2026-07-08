import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/today_session_card.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocols/protocol_library_screen.dart';
import '../session/session_player_screen.dart';

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

  void _openSessionPlayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SessionPlayerScreen(),
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
              const SectionTitle('Cohort'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Today',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Know the plan. Execute with confidence.',
                style: CohortTextStyles.body,
              ),

              const SizedBox(height: CohortSpacing.xl),

              TodaySessionCard(
                title: 'Bodyweight Grinder',
                subtitle: 'Capacity • Full Body',
                weekLabel: 'Cohort Foundation • Week 1 • Monday',
                duration: '30 minutes',
                status: 'Planned Session',
                onPressed: () => _openSessionPlayer(context),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Need to Adapt?'),
              const SizedBox(height: CohortSpacing.md),

              const CohortCard(
                child: _AdaptationRow(
                  title: 'Travelling',
                  subtitle: 'Preserve the training intent with limited equipment.',
                  icon: Icons.flight_takeoff,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              const CohortCard(
                child: _AdaptationRow(
                  title: 'Limited Equipment',
                  subtitle: 'Find the closest available version of today’s session.',
                  icon: Icons.fitness_center,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              const CohortCard(
                child: _AdaptationRow(
                  title: 'Poor Recovery',
                  subtitle: 'Reduce load or volume while protecting progress.',
                  icon: Icons.bedtime,
                ),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Knowledge'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openProtocolLibrary(context),
                child: const _HomeActionRow(
                  title: 'Protocol Library',
                  subtitle: 'Browse structured training sessions.',
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

class _AdaptationRow extends StatelessWidget {
  const _AdaptationRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: CohortSpacing.lg),
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
      ],
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