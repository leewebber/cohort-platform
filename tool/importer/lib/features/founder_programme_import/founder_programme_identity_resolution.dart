enum FounderProgrammeTransitionalResolutionKind {
  resolved,
  invalid,
  unmapped,
  conflict,
  retired,
}

class FounderProgrammeTransitionalResolution {
  FounderProgrammeTransitionalResolution({
    required this.kind,
    this.canonicalId,
    List<String> canonicalCandidates = const [],
  }) : canonicalCandidates = List.unmodifiable(
         canonicalCandidates.toList()..sort(),
       );

  final FounderProgrammeTransitionalResolutionKind kind;
  final String? canonicalId;
  final List<String> canonicalCandidates;
}

/// Pure-Dart importer port adapted to the repository-owned identity bridge.
abstract interface class FounderProgrammeTransitionalIdentityResolver {
  FounderProgrammeTransitionalResolution resolve(String rawReference);
}

class FounderProgrammeExerciseLocation
    implements Comparable<FounderProgrammeExerciseLocation> {
  const FounderProgrammeExerciseLocation({
    required this.importKey,
    required this.weekNumber,
    required this.dayNumber,
    required this.sessionOrder,
    required this.blockOrder,
    required this.exerciseOrder,
  });

  final String importKey;
  final int weekNumber;
  final int dayNumber;
  final int sessionOrder;
  final int blockOrder;
  final int exerciseOrder;

  String get path =>
      'programme[$importKey].week[$weekNumber].day[$dayNumber].'
      'session[$sessionOrder].block[$blockOrder].exercise[$exerciseOrder]';

  @override
  int compareTo(FounderProgrammeExerciseLocation other) {
    for (final comparison in [
      weekNumber.compareTo(other.weekNumber),
      dayNumber.compareTo(other.dayNumber),
      sessionOrder.compareTo(other.sessionOrder),
      blockOrder.compareTo(other.blockOrder),
      exerciseOrder.compareTo(other.exerciseOrder),
    ]) {
      if (comparison != 0) return comparison;
    }
    return importKey.compareTo(other.importKey);
  }

  @override
  bool operator ==(Object other) =>
      other is FounderProgrammeExerciseLocation &&
      importKey == other.importKey &&
      weekNumber == other.weekNumber &&
      dayNumber == other.dayNumber &&
      sessionOrder == other.sessionOrder &&
      blockOrder == other.blockOrder &&
      exerciseOrder == other.exerciseOrder;

  @override
  int get hashCode => Object.hash(
    importKey,
    weekNumber,
    dayNumber,
    sessionOrder,
    blockOrder,
    exerciseOrder,
  );
}

class FounderProgrammeIdentityIssue
    implements Comparable<FounderProgrammeIdentityIssue> {
  FounderProgrammeIdentityIssue({
    required this.location,
    required this.rawReference,
    required this.code,
    required this.message,
    List<String> canonicalCandidates = const [],
  }) : canonicalCandidates = List.unmodifiable(
         canonicalCandidates.toList()..sort(),
       );

  final FounderProgrammeExerciseLocation location;
  final String rawReference;
  final String code;
  final String message;
  final List<String> canonicalCandidates;

  String get formattedMessage {
    final reference = rawReference.isEmpty
        ? ''
        : ' Reference: "$rawReference".';
    final candidates = canonicalCandidates.isEmpty
        ? ''
        : ' Candidates: ${canonicalCandidates.join(', ')}.';
    return '${location.path} $message$reference$candidates';
  }

  Map<String, Object?> toJson() => {
    'programme_import_key': location.importKey,
    'week_number': location.weekNumber,
    'day_number': location.dayNumber,
    'session_order': location.sessionOrder,
    'block_order': location.blockOrder,
    'exercise_order': location.exerciseOrder,
    'raw_reference': rawReference,
    'code': code,
    'message': message,
    'canonical_candidates': canonicalCandidates,
  };

  @override
  int compareTo(FounderProgrammeIdentityIssue other) {
    final byLocation = location.compareTo(other.location);
    if (byLocation != 0) return byLocation;
    final byCode = code.compareTo(other.code);
    if (byCode != 0) return byCode;
    return rawReference.compareTo(other.rawReference);
  }
}

class FounderProgrammeResolvedIdentityPlan {
  FounderProgrammeResolvedIdentityPlan({
    required Map<FounderProgrammeExerciseLocation, String> canonicalIds,
    required List<FounderProgrammeIdentityIssue> issues,
  }) : canonicalIds = Map.unmodifiable(canonicalIds),
       issues = List.unmodifiable(issues.toList()..sort());

  final Map<FounderProgrammeExerciseLocation, String> canonicalIds;
  final List<FounderProgrammeIdentityIssue> issues;

  bool get isResolved => issues.isEmpty;

  String canonicalIdAt(FounderProgrammeExerciseLocation location) {
    final id = canonicalIds[location];
    if (id == null) {
      throw StateError('No resolved canonical id for ${location.path}.');
    }
    return id;
  }
}
