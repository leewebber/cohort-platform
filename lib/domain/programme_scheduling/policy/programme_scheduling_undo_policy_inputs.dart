/// Contract inputs for undo eligibility (modelled in 1.7B; not applied).
///
/// Durable operation log / snapshot restoration remain Sprint 1.7F work.
class ProgrammeSchedulingUndoPolicyInputs {
  const ProgrammeSchedulingUndoPolicyInputs({
    required this.operationCompletedAtAthleteLocal,
    required this.priorScheduleRevision,
    required this.priorSnapshotIdentity,
    this.ttlAthleteLocalHours =
        ProgrammeSchedulingUndoPolicyInputs.defaultTtlAthleteLocalHours,
  });

  static const defaultTtlAthleteLocalHours = 72;

  final DateTime operationCompletedAtAthleteLocal;
  final int priorScheduleRevision;

  /// Opaque identity of the prior durable schedule snapshot.
  final String priorSnapshotIdentity;

  final int ttlAthleteLocalHours;

  Map<String, Object?> toCanonicalMap() => {
    'operationCompletedAtAthleteLocal':
        operationCompletedAtAthleteLocal.toIso8601String(),
    'priorScheduleRevision': priorScheduleRevision,
    'priorSnapshotIdentity': priorSnapshotIdentity,
    'ttlAthleteLocalHours': ttlAthleteLocalHours,
  };
}
