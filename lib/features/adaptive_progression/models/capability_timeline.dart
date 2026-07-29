/// Direction of a capability change on the athlete timeline.
enum CapabilityChangeDirection { up, down, steady }

/// Lightweight capability timeline entry (no graphs).
class CapabilityTimelineEvent {
  const CapabilityTimelineEvent({
    required this.eventId,
    required this.recordedAt,
    required this.capabilityId,
    required this.label,
    required this.direction,
    this.fromLevel,
    this.toLevel,
    this.sourceCompletionId,
  });

  final String eventId;
  final DateTime recordedAt;
  final String capabilityId;

  /// Athlete-facing label (e.g. "Threshold Capacity").
  final String label;
  final CapabilityChangeDirection direction;
  final double? fromLevel;
  final double? toLevel;
  final String? sourceCompletionId;

  String get directionSymbol => switch (direction) {
    CapabilityChangeDirection.up => '↑',
    CapabilityChangeDirection.down => '↓',
    CapabilityChangeDirection.steady => '→',
  };

  String get summaryLine => '$label $directionSymbol';
}

/// In-memory capability timeline (memory only).
class CapabilityTimelineStore {
  CapabilityTimelineStore._();

  static final List<CapabilityTimelineEvent> _items = [];

  static List<CapabilityTimelineEvent> get all =>
      List.unmodifiable(_items);

  static List<CapabilityTimelineEvent> recent({int limit = 8}) {
    final sorted = [..._items]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (sorted.length <= limit) return sorted;
    return sorted.take(limit).toList(growable: false);
  }

  static void add(CapabilityTimelineEvent event) => _items.add(event);

  static void addAll(Iterable<CapabilityTimelineEvent> events) =>
      _items.addAll(events);

  static void clear() => _items.clear();
}

/// Maps ontology capability ids → calm athlete language.
class CapabilityLabelCatalog {
  const CapabilityLabelCatalog._();

  static const Map<String, String> _labels = {
    'cohort.capability.relative_strength': 'Relative Strength',
    'cohort.capability.aerobic_capacity': 'Aerobic Capacity',
    'cohort.capability.work_capacity': 'Work Capacity',
    'cohort.capability.movement_competency': 'Movement Quality',
    'cohort.capability.pushing_strength': 'Upper Body Strength',
    'cohort.capability.pulling_strength': 'Pulling Strength',
    'cohort.capability.strength_endurance': 'Strength Endurance',
    'cohort.capability.grip_strength': 'Grip Strength',
    'cohort.capability.threshold': 'Threshold Capacity',
    'cohort.capability.running_economy': 'Running Economy',
    'cohort.capability.pacing': 'Pacing',
    'cohort.capability.loaded_carry_capacity': 'Carry Capacity',
    'cohort.capability.resilience': 'Resilience',
    'cohort.capability.burpee_efficiency': 'Burpee Efficiency',
  };

  static String labelFor(String capabilityId) {
    final mapped = _labels[capabilityId];
    if (mapped != null) return mapped;
    final leaf = capabilityId.contains('.')
        ? capabilityId.split('.').last
        : capabilityId;
    return leaf
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }
}
