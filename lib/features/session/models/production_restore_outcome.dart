/// Typed outcomes from the canonical production restore resolver.
enum ProductionRestoreOutcome {
  noDraft,
  resumable,
  legacyPartiallyRecoverable,
  completedHosted,
  staleOccurrence,
  staleProgrammeVersion,
  foreignAthlete,
  corrupt,
  unsupportedVersion,
  conflict,
  unavailable,
  transientFailure,
}

class ProductionRestoreException implements Exception {
  const ProductionRestoreException(this.outcome, this.athleteMessage);

  final ProductionRestoreOutcome outcome;
  final String athleteMessage;

  @override
  String toString() => athleteMessage;
}
