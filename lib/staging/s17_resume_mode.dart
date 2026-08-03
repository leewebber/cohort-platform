/// Resume-only mode for retained Athlete D (B4c / B4d).
///
/// Never creates athletes. Never invents credentials. Operates only from the
/// externally supplied private dart-define configuration.
class S17ResumeMode {
  /// Journeys left unresolved after B4b (A/B/E already passed).
  static const unresolvedAfterB4b = ['C', 'D', 'F', 'G', 'H', 'I', 'J', 'K'];

  /// Prerequisite checks (not journey mutations). A/B/E are never journey PASS
  /// in resume mode — only these PREREQ_* codes.
  static const prerequisiteCodes = [
    'PREREQ_A',
    'PREREQ_B',
    'PREREQ_E',
    'PREREQ_PREP',
    'PREREQ_BASELINE',
    'PREREQ_IDENTITY',
  ];

  /// Default execution order: prepare baseline, schedule ops, then K→C, then D.
  /// K may create the prior result C needs; final report still labels independently.
  static const defaultExecutionOrder = ['F', 'G', 'H', 'I', 'J', 'K', 'C', 'D'];

  static List<String> parseSelectedJourneys(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return List<String>.from(unresolvedAfterB4b);
    }
    final selected = raw
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
    for (final code in selected) {
      if (!unresolvedAfterB4b.contains(code)) {
        throw FormatException(
          'Resume mode refuses journey $code (allowed: ${unresolvedAfterB4b.join(',')})',
        );
      }
    }
    return selected;
  }

  /// Ordered subset for execution without repeating A/B/E mutations.
  static List<String> executionOrderFor(Iterable<String> selected) {
    final set = selected.map((e) => e.toUpperCase()).toSet();
    return defaultExecutionOrder.where(set.contains).toList(growable: false);
  }

  /// Resume must never invoke creator tooling.
  static bool mentionsCreatorInvocation(String source) {
    final lowered = source.toLowerCase();
    return lowered.contains('create_s17_athlete_d_fixture') ||
        lowered.contains('run_creator');
  }
}
