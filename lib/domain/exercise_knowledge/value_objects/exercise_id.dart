/// Canonical exercise identity for the Exercise Knowledge Authority.
///
/// Sole canonical format: `EX-*` (e.g. `EX-073`).
/// Transitional knowledge ids (`cohort.exercise.*`) are never canonical.
class ExerciseId implements Comparable<ExerciseId> {
  ExerciseId._(this.value);

  /// Canonical pattern: EX- followed by one or more digits.
  static final RegExp canonicalPattern = RegExp(r'^EX-\d+$');

  static final RegExp _transitionalKnowledgePattern = RegExp(
    r'^cohort\.exercise\.',
    caseSensitive: false,
  );

  final String value;

  /// Parses and validates a canonical exercise id.
  ///
  /// Throws [FormatException] for blank, malformed, or transitional ids.
  factory ExerciseId.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Exercise id must not be blank.');
    }
    if (_transitionalKnowledgePattern.hasMatch(trimmed)) {
      throw FormatException(
        'Transitional knowledge id is not a canonical exercise id: $trimmed',
      );
    }
    if (!canonicalPattern.hasMatch(trimmed)) {
      throw FormatException(
        'Malformed canonical exercise id (expected EX-<digits>): $trimmed',
      );
    }
    return ExerciseId._(trimmed);
  }

  /// Returns null instead of throwing when [raw] is not a valid canonical id.
  static ExerciseId? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      return ExerciseId.parse(raw);
    } on FormatException {
      return null;
    }
  }

  /// True when [raw] matches the transitional knowledge namespace.
  static bool isTransitionalKnowledgeId(String raw) {
    return _transitionalKnowledgePattern.hasMatch(raw.trim());
  }

  /// True when [raw] is a well-formed canonical `EX-*` id.
  static bool isCanonical(String raw) {
    return canonicalPattern.hasMatch(raw.trim());
  }

  String toJson() => value;

  factory ExerciseId.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException('Exercise id JSON must be a string, got $json');
    }
    return ExerciseId.parse(json);
  }

  @override
  int compareTo(ExerciseId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is ExerciseId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
