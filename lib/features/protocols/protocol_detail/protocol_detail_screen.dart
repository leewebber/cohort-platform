import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/attribute_grid.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/protocol_step_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/repositories/protocol_step_repository.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_step.dart';
import '../widgets/protocol_header.dart';

class ProtocolDetailScreen extends StatelessWidget {
  const ProtocolDetailScreen({
    super.key,
    required this.protocol,
  });

  final Protocol protocol;

  static const ProtocolStepRepository _stepRepository =
      ProtocolStepRepository();

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

              ProtocolHeader(protocol: protocol),

              const SizedBox(height: CohortSpacing.xl),

              if (protocol.description != null &&
                  protocol.description!.trim().isNotEmpty)
                _SectionCard(
                  title: 'Purpose',
                  child: Text(
                    protocol.description!,
                    style: CohortTextStyles.body,
                  ),
                ),

              _ProtocolStepsSection(
                protocol: protocol,
                stepRepository: _stepRepository,
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Attributes'),

              const SizedBox(height: CohortSpacing.md),

              AttributeGrid(
                attributes: {
                  'Training Quality': protocol.trainingQuality,
                  'Session Type': protocol.sessionType,
                  'Primary Focus': protocol.capability,
                  'Training Demand': protocol.demand,
                  'Recovery Requirement': protocol.recovery,
                  'Environment': protocol.environment,
                  'Suitable For': protocol.suitableFor,
                },
              ),

              if (protocol.coachingNotes != null &&
                  protocol.coachingNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.xl),
                _SectionCard(
                  title: 'Coach Notes',
                  child: Text(
                    protocol.coachingNotes!,
                    style: CohortTextStyles.body,
                  ),
                ),
              ],

              const SizedBox(height: CohortSpacing.xxl),

              CohortButton(
                label: 'Start Session',
                onPressed: () {},
              ),

              const SizedBox(height: CohortSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolStepsSection extends StatelessWidget {
  const _ProtocolStepsSection({
    required this.protocol,
    required this.stepRepository,
  });

  final Protocol protocol;
  final ProtocolStepRepository stepRepository;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProtocolStep>>(
      future: stepRepository.getProtocolSteps(protocol.protocolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionCard(
            title: 'Session',
            child: Text(
              'Loading session...',
              style: CohortTextStyles.body,
            ),
          );
        }

        final steps = snapshot.data ?? [];

        if (steps.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Session'),
                const SizedBox(height: CohortSpacing.md),
                ...steps.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProtocolStepCard(step: step),
                  ),
                ),
              ],
            ),
          );
        }

        if (protocol.mainSession != null &&
            protocol.mainSession!.trim().isNotEmpty) {
          return _SectionCard(
            title: 'Session',
            child: Text(
              protocol.mainSession!,
              style: CohortTextStyles.body,
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: CohortSpacing.md),
          CohortCard(
            child: child,
          ),
        ],
      ),
    );
  }
}