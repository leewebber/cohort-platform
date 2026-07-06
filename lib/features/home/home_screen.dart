import 'package:flutter/material.dart';

import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Cohort Field Manual'),
              const SizedBox(height: 12),
              const Text(
                "What's today's mission?",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select a protocol, build your week, or generate the right session for today.',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle("Today's Focus"),
                    const SizedBox(height: 18),
                    const Text(
                      'Train with intent.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the session that matches your goal, equipment and recovery state.',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              CohortButton(
                label: "Generate Today's Protocol",
                onPressed: () {},
              ),

              const SizedBox(height: 32),

              SectionTitle('Field Manual'),
              const SizedBox(height: 14),

              CohortCard(
                onTap: () {},
                child: const _HomeActionRow(
                  title: 'Browse Library',
                  subtitle: 'Search and filter the full protocol library.',
                  status: 'OPEN',
                ),
              ),
              const SizedBox(height: 12),
              CohortCard(
                child: const _HomeActionRow(
                  title: 'Build My Week',
                  subtitle: 'Generate a balanced week from the Cohort blueprint.',
                  status: 'SOON',
                ),
              ),
              const SizedBox(height: 12),
              CohortCard(
                child: const _HomeActionRow(
                  title: 'Training Log',
                  subtitle: 'Record completed sessions and track progress.',
                  status: 'SOON',
                ),
              ),

              const Spacer(),

              const Center(
                child: Text(
                  'Train hard. Train intelligently. Stay ready.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          status,
          style: const TextStyle(
            color: Color(0xFFA3E635),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}