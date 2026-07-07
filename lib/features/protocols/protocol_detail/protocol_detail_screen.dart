import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/protocol.dart';

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

              SectionTitle(protocol.goal ?? 'Protocol'),

              const SizedBox(height: CohortSpacing.sm),

              Text(
                protocol.name,
                style: CohortTextStyles.h1,
              ),

              const SizedBox(height: CohortSpacing.sm),

              Text(
                [
                  if (protocol.durationMin != null)
                    '${protocol.durationMin} min',
                  if (protocol.capability != null)
                    protocol.capability!,
                  if (protocol.equipment != null)
                    protocol.equipment!,
                ].join(' • '),
                style: CohortTextStyles.body,
              ),

              const SizedBox(height: CohortSpacing.xl),

              if (protocol.description != null &&
                  protocol.description!.isNotEmpty)
                _SectionCard(
                  title: 'Purpose',
                  child: Text(
                    protocol.description!,
                    style: CohortTextStyles.body,
                  ),
                ),

              if (protocol.mainSession != null &&
                  protocol.mainSession!.isNotEmpty)
                _SectionCard(
                  title: 'Session',
                  child: Text(
                    protocol.mainSession!,
                    style: CohortTextStyles.body,
                  ),
                ),

              const SizedBox(height: CohortSpacing.lg),

              const SectionTitle('Session Details'),

              const SizedBox(height: CohortSpacing.lg),

              InfoTile(
                label: 'Training Quality',
                value: protocol.trainingQuality,
              ),

              InfoTile(
                label: 'Session Type',
                value: protocol.sessionType,
              ),

              InfoTile(
                label: 'Body Focus',
                value: protocol.capability,
              ),

              InfoTile(
                label: 'Demand',
                value: protocol.demand,
              ),

              InfoTile(
                label: 'Recovery Cost',
                value: protocol.recovery,
              ),

              InfoTile(
                label: 'Environment',
                value: protocol.environment,
              ),

              InfoTile(
                label: 'Suitable For',
                value: protocol.suitableFor,
              ),

              const SizedBox(height: CohortSpacing.xl),

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