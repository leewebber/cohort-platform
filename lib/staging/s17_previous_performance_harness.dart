import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/features/workout_player/services/previous_performance_resolver.dart';

import 's17_staging_journey_matrix.dart';

/// Journey C — previous-performance reference-only verification.
///
/// Uses athlete-entered completed snapshots only. Does not rewrite prescriptions
/// or invoke progression.
class S17PreviousPerformanceHarness {
  const S17PreviousPerformanceHarness({
    this.resolver = const PreviousPerformanceResolver(),
  });

  final PreviousPerformanceResolver resolver;

  S17JourneyResult run({
    required String exerciseId,
    required List<PreviousPerformanceSnapshot> athleteEnteredRecords,
    required String? authoredPrescriptionFingerprintBefore,
    required String? authoredPrescriptionFingerprintAfter,
    required bool progressionRewritten,
  }) {
    final matching = resolver.resolveLatest(
      exerciseId: exerciseId,
      records: athleteEnteredRecords
          .where((r) => r.exerciseId == exerciseId)
          .toList(growable: false),
    );
    final unlikeExerciseId = 'unlike-$exerciseId';
    final unlike = resolver.resolveLatest(
      exerciseId: unlikeExerciseId,
      records: athleteEnteredRecords,
    );

    final matchingSurfaced = matching != null && matching.hasDisplayableContent;
    final unlikeAbsent = unlike == null;
    final prescriptionUnchanged =
        authoredPrescriptionFingerprintBefore != null &&
        authoredPrescriptionFingerprintBefore ==
            authoredPrescriptionFingerprintAfter;
    final noProgression = !progressionRewritten;

    if (matchingSurfaced &&
        unlikeAbsent &&
        prescriptionUnchanged &&
        noProgression) {
      return S17JourneyResult.pass;
    }
    return S17JourneyResult.fail;
  }

  String detail({
    required S17JourneyResult result,
    required bool matchingSurfaced,
    required bool unlikeAbsent,
    required bool prescriptionUnchanged,
    required bool noProgression,
  }) {
    return 'matching=$matchingSurfaced unlike_absent=$unlikeAbsent '
        'prescription_unchanged=$prescriptionUnchanged '
        'no_progression=$noProgression result=${result.label}';
  }
}
