import 's17_staging_journey_matrix.dart';

class S17CompletionAttempt {
  const S17CompletionAttempt({
    required this.assignmentId,
    required this.versionId,
    required this.programmedSessionKey,
    required this.packageContentHash,
    required this.athleteEntered,
    required this.succeeded,
    required this.advancedToSessionOrder,
    this.duplicateOfPrior = false,
    this.createdDuplicateHistory = false,
    this.rewrotePrescription = false,
  });

  final String assignmentId;
  final String versionId;
  final String programmedSessionKey;
  final String packageContentHash;
  final bool athleteEntered;
  final bool succeeded;
  final int? advancedToSessionOrder;
  final bool duplicateOfPrior;
  final bool createdDuplicateHistory;
  final bool rewrotePrescription;
}

class S17CompletionHarnessResult {
  const S17CompletionHarnessResult({
    required this.result,
    required this.detail,
  });

  final S17JourneyResult result;
  final String detail;
}

/// Journey K — completion, advancement, duplicate protection.
class S17CompletionHarness {
  const S17CompletionHarness();

  S17CompletionHarnessResult evaluate({
    required String expectedAssignmentId,
    required String expectedVersionId,
    required String expectedSessionKey,
    required String expectedPackageHash,
    required S17CompletionAttempt primary,
    required S17CompletionAttempt duplicate,
    required int expectedNextSessionOrder,
  }) {
    final bound =
        primary.assignmentId == expectedAssignmentId &&
        primary.versionId == expectedVersionId &&
        primary.programmedSessionKey == expectedSessionKey &&
        primary.packageContentHash == expectedPackageHash;
    final entered = primary.athleteEntered;
    final advanced =
        primary.succeeded &&
        primary.advancedToSessionOrder == expectedNextSessionOrder;
    final noRewrite = !primary.rewrotePrescription;
    final duplicateOk =
        duplicate.duplicateOfPrior &&
        !duplicate.createdDuplicateHistory &&
        duplicate.advancedToSessionOrder == primary.advancedToSessionOrder &&
        !duplicate.rewrotePrescription;

    if (bound && entered && advanced && noRewrite && duplicateOk) {
      return const S17CompletionHarnessResult(
        result: S17JourneyResult.pass,
        detail:
            'Completion bound; advancement respected schedule; duplicate idempotent',
      );
    }
    return S17CompletionHarnessResult(
      result: S17JourneyResult.fail,
      detail:
          'bound=$bound entered=$entered advanced=$advanced '
          'no_rewrite=$noRewrite duplicate_ok=$duplicateOk',
    );
  }
}
