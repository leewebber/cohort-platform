import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../services/performance_chronology.dart';
import 'eligible_performance_evidence.dart';
import 'strength_progression.dart';

enum PersonalBestKind {
  heaviestLoad,
  repsAtLoad,
  sessionVolume;

  String get label => switch (this) {
    PersonalBestKind.heaviestLoad => 'Heaviest completed load',
    PersonalBestKind.repsAtLoad => 'Most completed reps at a specified load',
    PersonalBestKind.sessionVolume => 'Highest valid comparable session volume',
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

/// Observational personal-best detection from completed actuals only.
///
/// Types:
/// - Heaviest completed load
/// - Most completed reps at a specified load, only when a prior completed
///   set exists at that same load (never inferred from a first visit to a load)
/// - Highest valid comparable session volume, only when the increase is not
///   merely additional prescribed or extra completed sets
///
/// Prioritization when one session creates multiple technically valid bests:
/// 1. Heaviest completed load
/// 2. Most completed reps at a specified load, omitting a reps-at-load that
///    is the same heaviest-load set already announced
/// 3. Session volume, omitted when explained by the load/rep bests or by
///    extra prescribed sets
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
    if (eligible.isEmpty) return const [];

    final sessions = <_ExerciseSession>[];
    for (final record in eligible) {
      final session = _sessionFor(record, id);
      if (session != null) sessions.add(session);
    }
    if (sessions.isEmpty) return const [];

    return List.unmodifiable(_prioritized(sessions, exerciseId: id));
  }

  /// Bests established by [current], using [history] plus [current] as evidence.
  static List<PersonalBest> announcedForCurrent({
    required String athleteId,
    required String exerciseId,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> history,
  }) {
    final merged = <TrainingSessionRecord>[
      for (final record in history)
        if (record.recordId != current.recordId) record,
      current,
    ];
    return [
      for (final best in forExercise(
        athleteId: athleteId,
        exerciseId: exerciseId,
        history: merged,
      ))
        if (best.recordId == current.recordId) best,
    ];
  }

  static _ExerciseSession? _sessionFor(
    TrainingSessionRecord record,
    String exerciseId,
  ) {
    for (final block in record.blockResults) {
      for (final exercise in block.exerciseResults) {
        if (exercise.sourceExerciseId != exerciseId) continue;
        if (exercise.exerciseSnapshot.loadKind !=
            StrengthActualLoadKind.external) {
          continue;
        }
        final facts = StrengthProgressionFacts.fromExercise(exercise);
        if (facts.sets.isEmpty) continue;
        return _ExerciseSession(
          recordId: record.recordId,
          displayName: exercise.exerciseSnapshot.displayName,
          performedAt: record.performanceChronologyAt,
          facts: facts,
        );
      }
    }
    return null;
  }

  static List<PersonalBest> _prioritized(
    List<_ExerciseSession> sessions, {
    required String exerciseId,
  }) {
    _ExerciseSession? heaviestSession;
    TrainingSetResult? heaviestSet;
    for (final session in sessions) {
      for (final set in session.facts.sets) {
        final load = set.load;
        if (load == null || load <= 0) continue;
        if (heaviestSet == null || load > (heaviestSet.load ?? 0)) {
          heaviestSet = set;
          heaviestSession = session;
        }
      }
    }
    if (heaviestSession == null || heaviestSet == null) return const [];
    final holder = heaviestSession;
    final topSet = heaviestSet;

    final out = <PersonalBest>[];
    final priorHeaviest = sessions
        .where((session) => session.recordId != holder.recordId)
        .expand((session) => session.facts.sets)
        .map((set) => set.load ?? 0)
        .fold<double>(0, (max, load) => load > max ? load : max);
    if (sessions.length >= 2 && (topSet.load ?? 0) > priorHeaviest) {
      out.add(
        PersonalBest(
          kind: PersonalBestKind.heaviestLoad,
          exerciseId: exerciseId,
          displayName: holder.displayName,
          performedAt: holder.performedAt,
          recordId: holder.recordId,
          detail: '${_load(topSet.load)} kg',
        ),
      );
    }

    final repsAtLoad = _repsAtLoadBest(sessions: sessions);
    if (repsAtLoad != null) {
      out.add(
        PersonalBest(
          kind: PersonalBestKind.repsAtLoad,
          exerciseId: exerciseId,
          displayName: repsAtLoad.session.displayName,
          performedAt: repsAtLoad.session.performedAt,
          recordId: repsAtLoad.session.recordId,
          detail:
              '${repsAtLoad.set.reps} reps at ${_load(repsAtLoad.set.load)} kg',
        ),
      );
    }

    final volumeBest = _volumeBest(
      sessions: sessions,
      heaviestSession: holder,
      heaviestSet: topSet,
    );
    if (volumeBest != null) {
      out.add(
        PersonalBest(
          kind: PersonalBestKind.sessionVolume,
          exerciseId: exerciseId,
          displayName: volumeBest.displayName,
          performedAt: volumeBest.performedAt,
          recordId: volumeBest.recordId,
          detail: '${volumeBest.facts.volume!.round()} kg volume',
        ),
      );
    }
    return out;
  }

  /// Reps-at-load requires a prior completed set at the same load. The heaviest
  /// set is not also announced as a reps-at-load best.
  static ({_ExerciseSession session, TrainingSetResult set})? _repsAtLoadBest({
    required List<_ExerciseSession> sessions,
  }) {
    final byLoad = <double, List<({_ExerciseSession session, TrainingSetResult set})>>{};
    for (final session in sessions) {
      for (final set in session.facts.sets) {
        final load = set.load;
        if (load == null || load <= 0 || set.reps == null) continue;
        byLoad.putIfAbsent(load, () => []).add((session: session, set: set));
      }
    }

    ({_ExerciseSession session, TrainingSetResult set})? best;
    for (final entries in byLoad.values) {
      final distinctRecords = {for (final entry in entries) entry.session.recordId};
      if (distinctRecords.length < 2) continue;
      entries.sort((a, b) => (b.set.reps ?? 0).compareTo(a.set.reps ?? 0));
      final candidate = entries.first;
      final priorBestReps = entries
          .where((entry) => entry.session.recordId != candidate.session.recordId)
          .map((entry) => entry.set.reps ?? 0)
          .fold<int>(0, (max, reps) => reps > max ? reps : max);
      if ((candidate.set.reps ?? 0) <= priorBestReps) continue;
      if (best == null || (candidate.set.reps ?? 0) > (best.set.reps ?? 0)) {
        best = candidate;
      }
    }
    return best;
  }

  static _ExerciseSession? _volumeBest({
    required List<_ExerciseSession> sessions,
    required _ExerciseSession heaviestSession,
    required TrainingSetResult heaviestSet,
  }) {
    _ExerciseSession? best;
    for (final session in sessions) {
      final volume = session.facts.volume;
      if (volume == null) continue;
      if (_volumeFromExtraSets(session, sessions)) continue;
      if (best == null || volume > (best.facts.volume ?? 0)) {
        best = session;
      }
    }
    if (best == null) return null;
    final implied = (heaviestSet.load ?? 0) * (heaviestSet.reps ?? 0);
    if (best.recordId == heaviestSession.recordId &&
        (best.facts.volume ?? 0) <= implied * 1.25) {
      return null;
    }
    return best;
  }

  static bool _volumeFromExtraSets(
    _ExerciseSession candidate,
    List<_ExerciseSession> sessions,
  ) {
    final minSets = sessions
        .map((session) => session.facts.completedSetCount ?? 0)
        .where((count) => count > 0)
        .fold<int?>(null, (min, count) => min == null || count < min ? count : min);
    if (minSets == null) return false;
    final currentSets = candidate.facts.completedSetCount ?? 0;
    if (currentSets <= minSets) return false;
    final prescribedGrew = sessions.any((session) {
      final a = candidate.facts.prescribedSetCount;
      final b = session.facts.prescribedSetCount;
      if (a == null || b == null) return currentSets > (session.facts.completedSetCount ?? 0);
      return a > b;
    });
    return prescribedGrew || currentSets > minSets;
  }

  static String _load(double? value) {
    if (value == null) return '0';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _ExerciseSession {
  const _ExerciseSession({
    required this.recordId,
    required this.displayName,
    required this.performedAt,
    required this.facts,
  });

  final String recordId;
  final String displayName;
  final DateTime performedAt;
  final StrengthProgressionFacts facts;
}
