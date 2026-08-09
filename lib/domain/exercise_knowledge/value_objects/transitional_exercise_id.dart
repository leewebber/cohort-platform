/// Typed transitional knowledge exercise identifier (`cohort.exercise.*`).
///
/// Never canonical. Must not escape as [ExerciseId].
class TransitionalExerciseId implements Comparable<TransitionalExerciseId> {
  TransitionalExerciseId._(this.value);

  static final RegExp pattern = RegExp(
    r'^cohort\.exercise\.[a-z][a-z0-9_]*$',
    caseSensitive: false,
  );

  final String value;

  /// Parses a transitional knowledge id.
  ///
  /// Throws [FormatException] for blank, malformed, or canonical `EX-*` values.
  factory TransitionalExerciseId.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Transitional exercise id must not be blank.');
    }
    if (RegExp(r'^EX-\d+$').hasMatch(trimmed)) {
      throw FormatException(
        'Canonical EX-* id is not a transitional knowledge id: $trimmed',
      );
    }
    if (!pattern.hasMatch(trimmed)) {
      throw FormatException(
        'Malformed transitional exercise id '
        '(expected cohort.exercise.<snake_case>): $trimmed',
      );
    }
    return TransitionalExerciseId._(trimmed.toLowerCase());
  }

  static TransitionalExerciseId? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      return TransitionalExerciseId.parse(raw);
    } on FormatException {
      return null;
    }
  }

  static bool isTransitional(String raw) => pattern.hasMatch(raw.trim());

  String toJson() => value;

  factory TransitionalExerciseId.fromJson(Object? json) {
    if (json is! String) {
      throw FormatException(
        'Transitional exercise id JSON must be a string, got $json',
      );
    }
    return TransitionalExerciseId.parse(json);
  }

  @override
  int compareTo(TransitionalExerciseId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is TransitionalExerciseId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
