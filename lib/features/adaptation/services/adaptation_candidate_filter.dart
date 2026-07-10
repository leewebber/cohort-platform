import '../../../models/adaptation_reason.dart';
import '../../../models/adaptation_request.dart';
import '../../../models/protocol.dart';
import 'constraint_evaluator.dart';

/// Result of evaluating whether a candidate protocol fits adaptation constraints.
class AdaptationCandidateFilterResult {
  const AdaptationCandidateFilterResult({
    required this.isSuitable,
    this.rejectionReason,
  });

  final bool isSuitable;
  final String? rejectionReason;

  @override
  String toString() {
    return 'AdaptationCandidateFilterResult('
        'isSuitable: $isSuitable, '
        'rejectionReason: $rejectionReason'
        ')';
  }
}

/// Filters candidate protocols by adaptation constraints.
///
/// Separates constraint suitability from intrinsic session similarity scored by
/// [ProtocolSimilarityService].
class AdaptationCandidateFilter {
  const AdaptationCandidateFilter();

  static const _constraintEvaluator = ConstraintEvaluator();

  AdaptationCandidateFilterResult evaluate({
    required Protocol currentProtocol,
    required Protocol candidateProtocol,
    required AdaptationRequest request,
    bool keepsCurrentProtocol = false,
  }) {
    if (keepsCurrentProtocol &&
        candidateProtocol.protocolId == currentProtocol.protocolId) {
      return const AdaptationCandidateFilterResult(isSuitable: true);
    }

    switch (request.reason) {
      case AdaptationReason.equipment:
        return _fromEvaluation(
          _constraintEvaluator.equipmentSatisfied(
            candidateProtocol,
            request.availableEquipment,
          ),
        );
      case AdaptationReason.environment:
        return _fromEvaluation(
          _constraintEvaluator.environmentSatisfied(
            candidateProtocol,
            request.environment,
          ),
        );
      case AdaptationReason.time:
        return _fromEvaluation(
          _constraintEvaluator.timeSatisfied(
            candidateProtocol,
            request.availableMinutes,
          ),
        );
      case AdaptationReason.recovery:
        return _fromEvaluation(
          _constraintEvaluator.recoverySatisfied(
            candidateProtocol,
            request.recoveryState,
          ),
        );
    }
  }

  AdaptationCandidateFilterResult _fromEvaluation(
    ConstraintEvaluation evaluation,
  ) {
    return AdaptationCandidateFilterResult(
      isSuitable: evaluation.satisfied,
      rejectionReason: evaluation.reason,
    );
  }
}
