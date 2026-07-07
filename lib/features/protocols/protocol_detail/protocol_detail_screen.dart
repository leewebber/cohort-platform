import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/attribute_grid.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/protocol.dart';
import '../widgets/protocol_header.dart';

class ProtocolDetailScreen extends StatelessWidget {
  const ProtocolDetailScreen({
    super.key,
    required this.protocol,
  });

  final Protocol protocol;

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

              if (protocol.mainSession != null &&
                  protocol.mainSession!.trim().isNotEmpty)
                _SectionCard(
                  title: 'Session',
                  child: Text(
                    protocol.mainSession!,
                    style: CohortTextStyles.body,
                  ),
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