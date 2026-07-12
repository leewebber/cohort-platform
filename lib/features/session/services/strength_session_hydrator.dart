import '../../../models/session_step.dart';
import '../../../models/strength_set_performance.dart';
import '../models/strength_set_entry.dart';

/// Result of merging persisted set rows into local exercise state.
class StrengthSessionHydrationResult {
  const StrengthSessionHydrationResult({
    required this.sets,
    required this.isExerciseComplete,
    this.athleteNote,
  });

  final List<StrengthSetEntry> sets;
  final String? athleteNote;
  final bool isExerciseComplete;
}

/// Rebuilds in-memory strength set rows from `training_session_sets`.
class StrengthSessionHydrator {
  const StrengthSessionHydrator();

  StrengthSessionHydrationResult hydrateExercise({
    required SessionStep step,
    required List<StrengthSetEntry> baseSets,
    required List<StrengthSetPerformance> persisted,
    required Set<String> preserveSetLocalIds,
  }) {
    final protocolStepId = step.protocolStepId;
    if (protocolStepId == null) {
      return StrengthSessionHydrationResult(
        sets: List<StrengthSetEntry>.from(baseSets),
        isExerciseComplete: false,
      );
    }

    final stepRows = persisted
        .where((row) => row.protocolStepId == protocolStepId)
        .toList();

    if (stepRows.isEmpty) {
      return StrengthSessionHydrationResult(
        sets: List<StrengthSetEntry>.from(baseSets),
        isExerciseComplete: false,
      );
    }

    final sets = List<StrengthSetEntry>.from(baseSets);

    for (var index = 0; index < sets.length; index++) {
      final entry = sets[index];
      if (entry.isExtraSet || preserveSetLocalIds.contains(entry.localId)) {
        continue;
      }

      final row = _matchingPrescribedRow(stepRows, entry.setNumber);
      if (row != null) {
        sets[index] = _entryFromPerformance(
          baseEntry: entry,
          performance: row,
        );
      }
    }

    final extraRows = stepRows.where((row) => row.isExtraSet).toList()
      ..sort((left, right) => left.setNumber.compareTo(right.setNumber));

    for (final row in extraRows) {
      final alreadyRestored = sets.any(
        (set) => set.isExtraSet && set.setNumber == row.setNumber,
      );
      if (alreadyRestored) {
        final existingIndex = sets.indexWhere(
          (set) => set.isExtraSet && set.setNumber == row.setNumber,
        );
        final existing = sets[existingIndex];
        if (!preserveSetLocalIds.contains(existing.localId)) {
          sets[existingIndex] = _extraEntryFromPerformance(
            stepNumber: step.stepNumber,
            performance: row,
            localId: existing.localId,
          );
        }
        continue;
      }

      final localId = 'extra-${step.stepNumber}-restored-${row.id}';
      if (preserveSetLocalIds.contains(localId)) {
        continue;
      }

      sets.add(
        _extraEntryFromPerformance(
          stepNumber: step.stepNumber,
          performance: row,
          localId: localId,
        ),
      );
    }

    sets.sort((left, right) {
      final extraCompare =
          (left.isExtraSet ? 1 : 0).compareTo(right.isExtraSet ? 1 : 0);
      if (extraCompare != 0) {
        return extraCompare;
      }

      return left.setNumber.compareTo(right.setNumber);
    });

    final athleteNote = _athleteNoteFromRows(stepRows);

    return StrengthSessionHydrationResult(
      sets: sets,
      athleteNote: athleteNote,
      isExerciseComplete: _isExerciseComplete(sets),
    );
  }

  StrengthSetPerformance? _matchingPrescribedRow(
    List<StrengthSetPerformance> rows,
    int setNumber,
  ) {
    for (final row in rows) {
      if (!row.isExtraSet && row.setNumber == setNumber) {
        return row;
      }
    }

    return null;
  }

  StrengthSetEntry _entryFromPerformance({
    required StrengthSetEntry baseEntry,
    required StrengthSetPerformance performance,
  }) {
    return baseEntry.copyWith(
      actualReps: performance.actualReps ?? baseEntry.actualReps,
      load: formatLoadLabel(
            performance.loadValue,
            performance.loadUnit,
          ) ??
          baseEntry.load,
      rpe: performance.rpe,
      completed: performance.completed,
      clearRpe: performance.rpe == null,
    );
  }

  StrengthSetEntry _extraEntryFromPerformance({
    required int stepNumber,
    required StrengthSetPerformance performance,
    required String localId,
  }) {
    return StrengthSetEntry(
      localId: localId,
      setNumber: performance.setNumber,
      targetReps: performance.targetReps,
      actualReps: performance.actualReps,
      load: formatLoadLabel(performance.loadValue, performance.loadUnit),
      rpe: performance.rpe,
      completed: performance.completed,
      isExtraSet: true,
    );
  }

  String? _athleteNoteFromRows(List<StrengthSetPerformance> rows) {
    final rowsWithNotes = rows
        .where((row) => row.athleteNote?.trim().isNotEmpty == true)
        .toList();

    if (rowsWithNotes.isEmpty) {
      return null;
    }

    rowsWithNotes.sort((left, right) {
      final completedCompare =
          (left.completed ? 1 : 0).compareTo(right.completed ? 1 : 0);
      if (completedCompare != 0) {
        return completedCompare;
      }

      return left.setNumber.compareTo(right.setNumber);
    });

    return rowsWithNotes.last.athleteNote?.trim();
  }

  static bool _isExerciseComplete(List<StrengthSetEntry> sets) {
    final prescribedSets = sets.where((set) => !set.isExtraSet).toList();
    if (prescribedSets.isEmpty || prescribedSets.any((set) => !set.completed)) {
      return false;
    }

    for (final extraSet in sets.where((set) => set.isExtraSet)) {
      if (extraSet.hasStartedData && !extraSet.completed) {
        return false;
      }
    }

    return true;
  }

  static String? formatLoadLabel(double? value, String? unit) {
    if (value == null) {
      return null;
    }

    final normalizedUnit = unit?.trim().toLowerCase();
    final formattedValue = _trimTrailingZero(value);

    if (normalizedUnit == null || normalizedUnit.isEmpty) {
      return formattedValue;
    }

    if (normalizedUnit == 'kg' || normalizedUnit == 'lb') {
      return '$formattedValue$normalizedUnit';
    }

    return '$formattedValue $normalizedUnit';
  }

  static String _trimTrailingZero(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
