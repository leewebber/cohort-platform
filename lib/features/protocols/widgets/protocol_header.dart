import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/metadata_row.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/protocol.dart';

class ProtocolHeader extends StatelessWidget {
  const ProtocolHeader({
    super.key,
    required this.protocol,
  });

  final Protocol protocol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(protocol.goal ?? 'Protocol'),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          protocol.name,
          style: CohortTextStyles.h1,
        ),
        const SizedBox(height: CohortSpacing.lg),
        MetadataRow(
          icon: Icons.timer_outlined,
          text: protocol.durationMin == null
              ? null
              : '${protocol.durationMin} minutes',
        ),
        MetadataRow(
          icon: Icons.fitness_center_outlined,
          text: protocol.capability,
        ),
        MetadataRow(
          icon: Icons.place_outlined,
          text: protocol.equipment,
        ),
      ],
    );
  }
}