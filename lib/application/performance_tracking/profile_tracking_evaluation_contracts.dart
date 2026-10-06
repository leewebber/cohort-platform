part of 'profile_tracking_evaluator.dart';

/// Inputs must come from the trusted C2 adapter/bridge. A typed object itself
/// cannot prove authentication, existence, coherence or publication authority.
final class TrackingEvaluationInput {
  const TrackingEvaluationInput({
    required this.id,
    required this.query,
    required this.result,
  });
  final String id;
  final HistoryTrackingQuery query;
  final HistoryTrackingResult result;
}

final class TrackingProfileRequest {
  const TrackingProfileRequest({
    required this.profile,
    this.selection,
    this.programmeBinding,
    this.automaticSelection = false,
  });
  final TrackingReference profile;
  final TrackingReference? selection;
  final TrackingReference? programmeBinding;
  final bool automaticSelection;
}

final class TrackingComparisonRequest {
  const TrackingComparisonRequest({
    required this.id,
    required this.metric,
    required this.policy,
    required this.leftInputId,
    required this.rightInputId,
  });
  final String id;
  final TrackingReference metric;
  final TrackingReference policy;
  final String leftInputId;
  final String rightInputId;
}

/// Closed admission policy, separate from C1 method/artifact encoding. These
/// rules never calculate a delta, choose operands, convert units or rank values.
abstract final class TrackingComparabilityPolicy {
  static const content = <String, Object?>{
    'evaluation_policy_schema': 1,
    'id': 'same_metric_context_v1',
    'version': 1,
    'rules': [
      'same_athlete',
      'same_exact_metric_and_method',
      'available_tracking_eligible_operands',
      'same_canonical_unit_and_field_scope',
      'present_equal_comparison_family_and_required_context',
      'distinct_physical_observations',
      'preserve_all_mismatch_and_unavailable_reasons',
      'no_arithmetic_ordering_or_prescription',
    ],
  };
  static TrackingReference get reference => TrackingReference(
    id: 'same_metric_context_v1',
    version: 1,
    digest: _hash(content),
  );
}

/// Deeply immutable, ephemeral projection. Sorted unordered collections and
/// canonical object keys are deterministic; profile member and operand order
/// remain meaningful. This hash is not a result ledger or permission credential.
final class ProfileTrackingEvaluation {
  ProfileTrackingEvaluation._(Map<String, Object?> content)
    : content = _freeze(content) as Map<String, Object?>;
  final Map<String, Object?> content;
  bool get isFailure => content['state'] == 'failure';
  String? get failureCode => isFailure ? content['reason'] as String : null;
  String get canonicalJson => _json(content);
  String get digest => _hash(content);
  bool get grantsPrescriptionEligibility => false;
  bool get canReconstructHistoricalInputs => false;
}
