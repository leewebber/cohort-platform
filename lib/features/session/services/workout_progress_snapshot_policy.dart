import '../../../core/persistence/models/execution_result_models.dart';
import '../models/production_restore_outcome.dart';

enum WorkoutProgressSnapshotBootAction {
  none,
  clearSafely,
  showCannotRestore,
}

/// [WorkoutProgressSnapshot] is legacy discovery only. It never proves resume.
class WorkoutProgressSnapshotPolicy {
  const WorkoutProgressSnapshotPolicy();

  /// True when snapshot rows cannot be mapped onto programme block actuals.
  bool hasUnmappableEnteredResults(WorkoutProgressSnapshot snapshot) {
    return snapshot.enteredResults.isNotEmpty;
  }

  WorkoutProgressSnapshotBootAction bootAction({
    required WorkoutProgressSnapshot? snapshot,
    required String currentAthleteId,
    ProductionRestoreOutcome? durableOutcome,
  }) {
    if (snapshot == null) {
      return WorkoutProgressSnapshotBootAction.none;
    }
    if (snapshot.athleteId.isEmpty ||
        snapshot.athleteId != currentAthleteId) {
      return WorkoutProgressSnapshotBootAction.clearSafely;
    }
    if (durableOutcome == ProductionRestoreOutcome.completedHosted ||
        durableOutcome == ProductionRestoreOutcome.foreignAthlete ||
        durableOutcome == ProductionRestoreOutcome.corrupt) {
      return WorkoutProgressSnapshotBootAction.clearSafely;
    }
    if (hasUnmappableEnteredResults(snapshot) &&
        durableOutcome != ProductionRestoreOutcome.resumable &&
        durableOutcome !=
            ProductionRestoreOutcome.legacyPartiallyRecoverable) {
      return WorkoutProgressSnapshotBootAction.showCannotRestore;
    }
    return WorkoutProgressSnapshotBootAction.clearSafely;
  }
}
