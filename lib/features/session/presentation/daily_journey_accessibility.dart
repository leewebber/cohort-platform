import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';

/// Production Daily Journey accessibility helpers. Not a second execution path.
abstract final class DailyJourneyAccessibility {
  static const double minTapSize = JourneyInteraction.minTapSize;
  static const double minPrimaryHeight = JourneyInteraction.minPrimaryHeight;
  static const Duration duplicateActionLock =
      JourneyInteraction.duplicateActionLock;

  static String spokenUnit(String? unit, {String fallback = 'kilograms'}) {
    final trimmed = unit?.trim().toLowerCase();
    return switch (trimmed) {
      null || '' => fallback,
      'kg' || 'kilogram' || 'kilograms' => 'kilograms',
      'lb' || 'lbs' || 'pound' || 'pounds' => 'pounds',
      'm' || 'meter' || 'metre' || 'metres' || 'meters' => 'metres',
      'km' || 'kilometre' || 'kilometer' || 'kilometres' || 'kilometers' =>
        'kilometres',
      'mi' || 'mile' || 'miles' => 'miles',
      's' || 'sec' || 'secs' || 'second' || 'seconds' => 'seconds',
      _ => unit!.trim(),
    };
  }

  static String setLoadLabel(int setNumber, String? unit) {
    return 'Set $setNumber load, ${spokenUnit(unit)}';
  }

  static String setRepsLabel(int setNumber) => 'Set $setNumber reps';

  static String setDistanceLabel(int setNumber, String? unit) {
    return 'Set $setNumber distance, ${spokenUnit(unit, fallback: 'metres')}';
  }

  static String setCompletedLabel(int setNumber) => 'Set $setNumber completed';

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  static bool shouldStackFields(BuildContext context, double maxWidth) {
    final scaled = MediaQuery.textScalerOf(context).scale(16);
    return maxWidth < 340 || scaled > 22;
  }
}

class JourneyAnnouncement extends StatelessWidget {
  const JourneyAnnouncement({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: const SizedBox(width: 1, height: 1),
    );
  }
}
