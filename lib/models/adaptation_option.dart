import 'package:flutter/material.dart';

import 'adaptation_reason.dart';

class AdaptationOption {
  const AdaptationOption({
    required this.reason,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final AdaptationReason reason;
  final String title;
  final String subtitle;
  final IconData icon;

  static const List<AdaptationOption> options = [
    AdaptationOption(
      reason: AdaptationReason.recovery,
      title: 'Recovery',
      subtitle: 'How you feel today affects the session route.',
      icon: Icons.bedtime_outlined,
    ),
    AdaptationOption(
      reason: AdaptationReason.environment,
      title: 'Environment',
      subtitle: 'Where you can train today.',
      icon: Icons.place_outlined,
    ),
    AdaptationOption(
      reason: AdaptationReason.equipment,
      title: 'Equipment',
      subtitle: 'What you have available right now.',
      icon: Icons.fitness_center,
    ),
    AdaptationOption(
      reason: AdaptationReason.time,
      title: 'Time',
      subtitle: 'How long you can train today.',
      icon: Icons.timer_outlined,
    ),
  ];
}
