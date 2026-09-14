import '../models/performance_snapshot.dart';
import '../models/previous_strength_performance.dart';
import '../models/session_result_entry_mode.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'performance_chronology.dart';

/// Candidate prior session used only for strength history selection.
class PreviousStrengthCandidate {
  const PreviousStrengthCandidate({
    required this.recordId,
    required this.athleteId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.performedOn,
    this.entryMode = SessionResultEntryMode.live,
    required this.exercises,
  });

  final String recordId;
  final String athleteId;
  final TrainingSessionRecordStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? performedOn;
  final SessionResultEntryMode entryMode;
  final List<PreviousStrengthCandidateExercise> exercises;

  TrainingSessionRecord get chronologyRecord => TrainingSessionRecord(
    recordId: recordId,
    athleteId: athleteId,
    status: status,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: '',
      sessionTitle: '',
      blocks: [],
    ),
    startedAt: startedAt,
    completedAt: completedAt,
    performedOn: performedOn,
    entryMode: entryMode,
  );
}

class PreviousStrengthCandidateExercise {
  const PreviousStrengthCandidateExercise({
    required this.exerciseId,
    required this.sets,
  });

  final String exerciseId;
  final List<PreviousStrengthSetEvidence> sets;
}

/// Picks the latest valid prior strength result per canonical exercise ID.
abstract final class PreviousStrengthPerformanceSelector {
  static const eligibleStatuses = {
    TrainingSessionRecordStatus.completed,
    TrainingSessionRecordStatus.partiallyCompleted,
  };

  static Map<String, PreviousStrengthExerciseEvidence> selectLatest({
    required String athleteId,
    required Iterable<String> exerciseIds,
    required List<PreviousStrengthCandidate> candidates,
    String? excludeRecordId,
    DateTime? currentChronologyAt,
  }) {
    final wanted = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (wanted.isEmpty) return const {};

    final eligible = candidates.where((candidate) {
      if (candidate.athleteId != athleteId) return false;
      if (!eligibleStatuses.contains(candidate.status)) return false;
      if (excludeRecordId != null &&
          excludeRecordId.isNotEmpty &&
          candidate.recordId == excludeRecordId) {
        return false;
      }
      if (currentChronologyAt != null &&
          !candidate.chronologyRecord.performanceChronologyAt.isBefore(
            currentChronologyAt,
          )) {
        return false;
      }
      return true;
    }).toList()..sort(
      (a, b) => PerformanceChronology.compareNewestFirst(
        a.chronologyRecord,
        b.chronologyRecord,
      ),
    );

    final out = <String, PreviousStrengthExerciseEvidence>{};
    for (final exerciseId in wanted) {
      for (final candidate in eligible) {
        final match = _latestSets(candidate, exerciseId);
        if (match.isEmpty) continue;
        out[exerciseId] = PreviousStrengthExerciseEvidence(
          exerciseId: exerciseId,
          recordId: candidate.recordId,
          performedAt: candidate.chronologyRecord.performanceChronologyAt,
          sets: match,
        );
        break;
      }
    }
    return out;
  }

  static List<PreviousStrengthSetEvidence> _latestSets(
    PreviousStrengthCandidate candidate,
    String exerciseId,
  ) {
    final usable = <PreviousStrengthSetEvidence>[];
    for (final exercise in candidate.exercises) {
      if (exercise.exerciseId != exerciseId) continue;
      for (final set in exercise.sets) {
        if (!set.hasActuals) continue;
        usable.add(set);
      }
    }
    usable.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return List.unmodifiable(usable);
  }
}
