import 'package:flutter/material.dart';

import '../../models/protocol.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'cohort_card.dart';

class ProtocolCard extends StatelessWidget {
  const ProtocolCard({
    super.key,
    required this.protocol,
    this.onTap,
  });

  final Protocol protocol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(protocol.goal ?? protocol.protocolId, style: CohortTextStyles.eyebrow),
          const SizedBox(height: 8),
          Text(protocol.name, style: CohortTextStyles.cardTitle),
          const SizedBox(height: 8),
          Text(
            [
              if (protocol.equipment != null) protocol.equipment!,
              if (protocol.durationMin != null) '${protocol.durationMin} min',
              if (protocol.capability != null) protocol.capability!,
            ].join(' · '),
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (protocol.demand != null) protocol.demand!,
              if (protocol.recovery != null) protocol.recovery!,
            ].join(' · '),
            style: const TextStyle(
              color: CohortColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}