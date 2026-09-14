import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../services/performance_chronology.dart';
import 'eligible_performance_evidence.dart';
import 'strength_progression.dart';

enum PersonalBestKind {
  heaviestLoad,
  repsAtLoad,
  loadAtReps,
  sessionVolume,
  lowestRpeForMatchedWork;

  String get label => switch (this) {
    PersonalBestKind.heaviestLoad => 'Heaviest load',
    PersonalBestKind.repsAtLoad => 'Rep best at load',
    PersonalBestKind.loadAtReps => 'Load best at reps',
    PersonalBestKind.sessionVolume => 'Volume best',
    PersonalBestKind.lowestRpeForMatchedWork => 'Lowest RPE for matched work',
  };
}

class PersonalBest {
  const PersonalBest({
    required this.kind,
    required this.exerciseId,
    required this.displayName,
    required this.performedAt,
    required this.recordId,
    required this.detail,
  });

  final PersonalBestKind kind;
  final String exerciseId;
  final String displayName;
  final DateTime performedAt;
  final String recordId;
  final String detail;
}

abstract final class PersonalBestEvaluator {
  static List<PersonalBest> forExercise({
    required String athleteId,
    required String exerciseId,
    required List<TrainingSessionRecord> history,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return const [];
    final eligible = history
        .where(
          (record) =>
              record.athleteId == athleteId &&
              EligiblePerformanceEvidence.isEligibleRecord(record),
        )
        .toList()
      ..sort(PerformanceChronology.compareNewestFirst);

    TrainingSetResult? heaviest;
    DateTime? heaviestAt;
    String? heaviestRecord;
    String displayName = '';
    TrainingSetResult? mostRepsAtHeaviest;
    double? bestVolume;
    DateTime? volumeAt;
    String? volumeRecord;

    for (final record in eligible) {
      for (final block in record.blockResults) {
        for (final exercise in block.exerciseResults) {
          if (exercise.sourceExerciseId != id) continue;
          if (exercise.exerciseSnapshot.loadKind !=
              StrengthActualLoadKind.external) {
            continue;
          }
          displayName = exercise.exerciseSnapshot.displayName;
          final facts = StrengthProgressionFacts.fromExercise(exercise);
          for (final set in facts.sets) {
            final load = set.load;
            if (load == null || load <= 0) continue;
            if (heaviest == null || load > (heaviest.load ?? 0)) {
              heaviest = set;
              heaviestAt = record.performanceChronologyAt;
              heaviestRecord = record.recordId;
              mostRepsAtHeaviest = set;
            } else if (load == heaviest.load &&
                (set.reps ?? 0) > (mostRepsAtHeaviest?.reps ?? 0)) {
              mostRepsAtHeaviest = set;
              heaviestAt = record.performanceChronologyAt;
              heaviestRecord = record.recordId;
            }
          }
          final volume = facts.volume;
          if (volume != null && (bestVolume == null || volume > bestVolume)) {
            bestVolume = volume;
            volumeAt = record.performanceChronologyAt;
            volumeRecord = record.recordId;
          }
        }
      }
    }

    if (heaviest == null || heaviestAt == null || heaviestRecord == null) {
      return const [];
    }

    final out = <PersonalBest>[
      PersonalBest(
        kind: PersonalBestKind.heaviestLoad,
        exerciseId: id,
        displayName: displayName,
        performedAt: heaviestAt,
        recordId: heaviestRecord,
        detail:
            '${heaviest.load!.toStringAsFixed(heaviest.load! == heaviest.load!.roundToDouble() ? 0 : 1)} kg',
      ),
    ];
    if (mostRepsAtHeaviest != null &&
        mostRepsAtHeaviest.reps != null &&
        mostRepsAtHeaviest.reps! > (heaviest.reps ?? 0)) {
      out.add(
        PersonalBest(
          kind: PersonalBestKind.repsAtLoad,
          exerciseId: id,
          displayName: displayName,
          performedAt: heaviestAt,
          recordId: heaviestRecord,
          detail: '${mostRepsAtHeaviest.reps} reps at ${heaviest.load} kg',
        ),
      );
    }
    final impliedVolume =
        (heaviest.load ?? 0) * (heaviest.reps ?? 0) * 1.0;
    if (bestVolume != null &&
        volumeAt != null &&
        volumeRecord != null &&
        bestVolume > impliedVolume * 1.25) {
      out.add(
        PersonalBest(
          kind: PersonalBestKind.sessionVolume,
          exerciseId: id,
          displayName: displayName,
          performedAt: volumeAt,
          recordId: volumeRecord,
          detail: '${bestVolume.round()} kg volume',
        ),
      );
    }
    return List.unmodifiable(out);
  }
}
