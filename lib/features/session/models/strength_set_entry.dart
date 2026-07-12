/// Local in-memory set row for [StrengthSessionView] execution logging.
class StrengthSetEntry {
  const StrengthSetEntry({
    required this.localId,
    required this.setNumber,
    this.targetReps,
    this.actualReps,
    this.load,
    this.rpe,
    this.completed = false,
    this.isExtraSet = false,
  });

  final String localId;
  final int setNumber;
  final String? targetReps;
  final String? actualReps;
  final String? load;
  final int? rpe;
  final bool completed;
  final bool isExtraSet;

  bool get hasStartedData {
    final loadValue = load?.trim();
    final repsValue = actualReps?.trim();

    return (loadValue != null && loadValue.isNotEmpty) ||
        (repsValue != null && repsValue.isNotEmpty);
  }

  StrengthSetEntry copyWith({
    String? localId,
    int? setNumber,
    String? targetReps,
    String? actualReps,
    String? load,
    int? rpe,
    bool? completed,
    bool? isExtraSet,
    bool clearRpe = false,
  }) {
    return StrengthSetEntry(
      localId: localId ?? this.localId,
      setNumber: setNumber ?? this.setNumber,
      targetReps: targetReps ?? this.targetReps,
      actualReps: actualReps ?? this.actualReps,
      load: load ?? this.load,
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      completed: completed ?? this.completed,
      isExtraSet: isExtraSet ?? this.isExtraSet,
    );
  }

  static int parsePrescribedSetCount(String? sets) {
    final value = int.tryParse(sets?.trim() ?? '');
    if (value != null && value > 0) {
      return value;
    }

    return 1;
  }

  static List<StrengthSetEntry> prescribedSetsForStep({
    required int stepNumber,
    String? prescribedSets,
    String? targetReps,
    String? defaultLoad,
  }) {
    final count = parsePrescribedSetCount(prescribedSets);
    final normalizedTarget = _nullableString(targetReps);
    final normalizedLoad = _nullableString(defaultLoad);

    return [
      for (var index = 0; index < count; index++)
        StrengthSetEntry(
          localId: 'set-$stepNumber-${index + 1}',
          setNumber: index + 1,
          targetReps: normalizedTarget,
          load: normalizedLoad,
        ),
    ];
  }

  static String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
