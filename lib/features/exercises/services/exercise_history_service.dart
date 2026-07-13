import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/training_session_set_repository.dart';
import '../../../models/exercise_history.dart';
import '../../../models/exercise_history_raw_row.dart';
import '../../../models/strength_set_performance.dart';

/// Builds notebook-style exercise history from persisted set rows.
class ExerciseHistoryService {
  ExerciseHistoryService({
    TrainingSessionSetRepository? setRepository,
    ProtocolRepository? protocolRepository,
  })  : setRepository = setRepository ?? const TrainingSessionSetRepository(),
        protocolRepository = protocolRepository ?? ProtocolRepository();

  final TrainingSessionSetRepository setRepository;
  final ProtocolRepository protocolRepository;

  static const defaultSessionLimit = 20;

  Future<ExerciseHistory> buildHistory({
    required String athleteId,
    required String exerciseId,
    int sessionLimit = defaultSessionLimit,
  }) async {
    final rows = await setRepository.getCompletedExerciseHistory(
      athleteId: athleteId,
      exerciseId: exerciseId,
      sessionLimit: sessionLimit,
    );

    if (rows.isEmpty) {
      return ExerciseHistory(
        exerciseId: exerciseId,
        sessions: const [],
      );
    }

    final protocolIds = rows
        .map((row) => row.protocolId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final protocolNames = await protocolRepository.getProtocolNamesByIds(
      protocolIds,
    );

    final groupedRows = <int, List<ExerciseHistoryRawRow>>{};
    final sessionCompletedAt = <int, DateTime?>{};
    final sessionProtocolId = <int, String>{};
    final sessionEndedEarly = <int, bool>{};
    final sessionCompletionReason = <int, String?>{};

    for (final row in rows) {
      groupedRows.putIfAbsent(row.trainingSessionId, () => []).add(row);
      sessionCompletedAt[row.trainingSessionId] = row.sessionCompletedAt;
      sessionProtocolId[row.trainingSessionId] = row.protocolId;
      sessionEndedEarly[row.trainingSessionId] = row.endedEarly;
      sessionCompletionReason[row.trainingSessionId] = row.completionReason;
    }

    final sessions = groupedRows.entries.map((entry) {
      final trainingSessionId = entry.key;
      final sets = entry.value.map((row) => row.performance).toList()
        ..sort(_compareSets);

      final protocolId = sessionProtocolId[trainingSessionId] ?? '';
      final protocolLabel = protocolNames[protocolId] ?? protocolId;

      return ExerciseHistorySession(
        trainingSessionId: trainingSessionId,
        performedAt: sessionCompletedAt[trainingSessionId],
        protocolLabel: protocolLabel.isEmpty ? 'Session' : protocolLabel,
        setLines: sets.map(_setLineFromPerformance).toList(growable: false),
        summaryLine: _summaryLineForSets(sets),
        athleteNote: _athleteNoteFromSets(sets),
        endedEarly: sessionEndedEarly[trainingSessionId] ?? false,
        completionReason: sessionCompletionReason[trainingSessionId],
      );
    }).toList()
      ..sort((left, right) {
        final leftDate = left.performedAt;
        final rightDate = right.performedAt;

        if (leftDate == null && rightDate == null) {
          return right.trainingSessionId.compareTo(left.trainingSessionId);
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }

        return rightDate.compareTo(leftDate);
      });

    return ExerciseHistory(
      exerciseId: exerciseId,
      sessions: sessions,
    );
  }

  ExerciseHistorySetLine _setLineFromPerformance(
    StrengthSetPerformance performance,
  ) {
    final loadLabel = _formatLoad(
      performance.loadValue,
      performance.loadUnit,
    );
    final reps = _nullableString(performance.actualReps) ??
        _nullableString(performance.targetReps);

    final performanceCore = _formatPerformanceCore(
      loadLabel: loadLabel,
      reps: reps,
      rpe: performance.rpe,
    );

    final displayLine = performance.isExtraSet
        ? 'EXTRA SET ${performance.setNumber} — $performanceCore'
        : performanceCore;

    return ExerciseHistorySetLine(
      setNumber: performance.setNumber,
      isExtraSet: performance.isExtraSet,
      displayLine: displayLine,
    );
  }

  String _formatPerformanceCore({
    required String? loadLabel,
    required String? reps,
    required int? rpe,
  }) {
    final parts = <String>[];

    if (loadLabel != null && reps != null) {
      parts.add('$loadLabel × $reps');
    } else if (loadLabel != null) {
      parts.add(loadLabel);
    } else if (reps != null) {
      parts.add('$reps reps');
    } else {
      parts.add('—');
    }

    if (rpe != null) {
      parts.add('RPE $rpe');
    }

    return parts.join(' · ');
  }

  String _summaryLineForSets(List<StrengthSetPerformance> sets) {
    final prescribedCount =
        sets.where((set) => set.completed && !set.isExtraSet).length;
    final extraCount = sets.where((set) => set.completed && set.isExtraSet).length;

    final parts = <String>[];
    if (prescribedCount > 0) {
      parts.add(
        '$prescribedCount prescribed set${prescribedCount == 1 ? '' : 's'}',
      );
    }
    if (extraCount > 0) {
      parts.add('$extraCount extra set${extraCount == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) {
      return 'Sets logged';
    }

    return parts.join(' · ');
  }

  String? _athleteNoteFromSets(List<StrengthSetPerformance> sets) {
    final rowsWithNotes = sets
        .where((set) => set.athleteNote?.trim().isNotEmpty == true)
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

  int _compareSets(
    StrengthSetPerformance left,
    StrengthSetPerformance right,
  ) {
    final extraCompare =
        (left.isExtraSet ? 1 : 0).compareTo(right.isExtraSet ? 1 : 0);
    if (extraCompare != 0) {
      return extraCompare;
    }

    return left.setNumber.compareTo(right.setNumber);
  }

  String? _formatLoad(double? value, String? unit) {
    if (value == null) {
      return null;
    }

    final normalizedUnit = unit?.trim().toLowerCase();
    final formattedValue = _trimTrailingZero(value);

    if (normalizedUnit == null || normalizedUnit.isEmpty) {
      return formattedValue;
    }

    if (normalizedUnit == 'kg' || normalizedUnit == 'lb') {
      return '$formattedValue $normalizedUnit';
    }

    return '$formattedValue $normalizedUnit';
  }

  String _trimTrailingZero(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
