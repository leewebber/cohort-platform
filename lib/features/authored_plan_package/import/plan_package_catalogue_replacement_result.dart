/// Typed outcomes from the atomic Cohort Global catalogue replacement RPC.
enum PlanPackageCatalogueReplacementStatus {
  replaced,
  alreadyReplaced,
  wrongLineage,
  invalidReplacement,
  conflictingEligibleVersion,
  unauthorized,
  lifecycleInvariantFailure,
  invalidRequest,
}

class PlanPackageCatalogueReplacementResult {
  const PlanPackageCatalogueReplacementResult({
    required this.status,
    required this.code,
    this.retiringVersionId,
    this.replacementVersionId,
    this.eligibleVersionCount,
  });

  final PlanPackageCatalogueReplacementStatus status;
  final String code;
  final String? retiringVersionId;
  final String? replacementVersionId;
  final int? eligibleVersionCount;

  bool get isSuccess =>
      status == PlanPackageCatalogueReplacementStatus.replaced ||
      status == PlanPackageCatalogueReplacementStatus.alreadyReplaced;

  factory PlanPackageCatalogueReplacementResult.fromRpcMap(
    Map<String, dynamic> map,
  ) {
    final rpcStatus = map['status']?.toString();
    final code = map['code']?.toString() ?? 'unknown';

    final status = switch ((rpcStatus, code)) {
      ('replaced', _) => PlanPackageCatalogueReplacementStatus.replaced,
      ('already_replaced', _) =>
        PlanPackageCatalogueReplacementStatus.alreadyReplaced,
      (_, 'wrong_lineage') =>
        PlanPackageCatalogueReplacementStatus.wrongLineage,
      (_, 'invalid_replacement') ||
      (_, 'invalid_replacement_structure') ||
      (
        _,
        'replacement_not_found',
      ) => PlanPackageCatalogueReplacementStatus.invalidReplacement,
      ('conflict', 'conflicting_eligible_version') =>
        PlanPackageCatalogueReplacementStatus.conflictingEligibleVersion,
      ('authorization_failure', _) =>
        PlanPackageCatalogueReplacementStatus.unauthorized,
      ('lifecycle_invariant_failure', _) =>
        PlanPackageCatalogueReplacementStatus.lifecycleInvariantFailure,
      _ => PlanPackageCatalogueReplacementStatus.invalidRequest,
    };

    return PlanPackageCatalogueReplacementResult(
      status: status,
      code: code,
      retiringVersionId: map['retiring_version_id']?.toString(),
      replacementVersionId: map['replacement_version_id']?.toString(),
      eligibleVersionCount: _nullableInt(map['eligible_version_count']),
    );
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
