import '../../session/models/strength_set_entry.dart';
import '../../session/services/strength_load_parser.dart';
import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import 'personal_bests.dart';
import 'progression_comparison.dart';
import 'strength_progression.dart';

/// Shared athlete-facing projection for every progression surface.
class ProgressionSurfaceProjection {
  const ProgressionSurfaceProjection({
    required this.comparison,
    this.personalBests = const [],
  });

  final ProgressionComparison comparison;
  final List<PersonalBest> personalBests;

  String get verdictLabel => comparison.outcome.label;

  String get explanation => comparison.summary;

  String get conciseHighlight => comparison.conciseHighlight;

  String? get personalBestStatus {
    if (personalBests.isEmpty) return null;
    return personalBests
        .map((best) => '${best.kind.label}: ${best.detail}')
        .join(' · ');
  }

  bool get hasPersonalBest => personalBests.isNotEmpty;
}

/// Maps logged session-player sets onto [StrengthProgressionFacts].
///
/// Does not emit verdicts. Thresholds and outcome vocabulary stay in
/// [StrengthProgressionComparison].
abstract final class StrengthProgressionEvidence {
  static StrengthProgressionFacts fromLoggedSets({
    required String exerciseId,
    required List<StrengthSetEntry> completedSets,
    int? prescribedSetCount,
  }) {
    final sets = <TrainingSetResult>[];
    var loadKind = StrengthActualLoadKind.external;
    for (final entry in completedSets.where((set) => set.completed)) {
      final parsed = StrengthLoadParser.parse(entry.load);
      if (parsed.unit == 'bw') {
        loadKind = StrengthActualLoadKind.bodyweight;
      }
      sets.add(
        TrainingSetResult(
          setResultId: entry.localId,
          exerciseResultId: exerciseId,
          setNumber: entry.setNumber,
          position: entry.setNumber,
          load: parsed.unit == 'bw' ? null : parsed.value,
          loadUnit: parsed.unit == 'bw' ? null : (parsed.unit ?? 'kg'),
          reps: _parseReps(entry.actualReps),
          rpe: entry.rpe,
          completed: true,
        ),
      );
    }
    return StrengthProgressionFacts(
      exerciseId: exerciseId.trim().isEmpty ? 'logged-exercise' : exerciseId,
      loadKind: loadKind,
      sets: sets,
      prescribedSetCount: prescribedSetCount,
    );
  }

  static StrengthProgressionFacts? fromPrevious({
    required String exerciseId,
    required List<({String? loadLabel, String? reps, double? rpe})> sets,
  }) {
    if (sets.isEmpty) return null;
    final parsedSets = <TrainingSetResult>[];
    var loadKind = StrengthActualLoadKind.external;
    var index = 1;
    for (final set in sets) {
      final parsed = StrengthLoadParser.parse(set.loadLabel);
      if (parsed.unit == 'bw') {
        loadKind = StrengthActualLoadKind.bodyweight;
      }
      parsedSets.add(
        TrainingSetResult(
          setResultId: 'prev-$index',
          exerciseResultId: exerciseId,
          setNumber: index,
          position: index,
          load: parsed.unit == 'bw' ? null : parsed.value,
          loadUnit: parsed.unit == 'bw' ? null : (parsed.unit ?? 'kg'),
          reps: _parseReps(set.reps),
          rpe: set.rpe?.round(),
          completed: true,
        ),
      );
      index += 1;
    }
    return StrengthProgressionFacts(
      exerciseId: exerciseId.trim().isEmpty ? 'logged-exercise' : exerciseId,
      loadKind: loadKind,
      sets: parsedSets,
      prescribedSetCount: parsedSets.length,
    );
  }

  static int? _parseReps(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return int.tryParse(RegExp(r'\d+').stringMatch(trimmed) ?? '');
  }
}
