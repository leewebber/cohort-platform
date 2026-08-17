import '../../performance/models/active_performance_draft.dart';
import '../../performance/services/performance_validation_service.dart';

class SessionFinishEligibility {
  const SessionFinishEligibility({
    required this.canFinish,
    required this.reason,
  });

  final bool canFinish;
  final String reason;
}

class SessionFinishEligibilityEvaluator {
  const SessionFinishEligibilityEvaluator({
    this._validationService = const PerformanceValidationService(),
  });

  final PerformanceValidationService _validationService;

  SessionFinishEligibility evaluate({
    required int incompleteBlockCount,
    required ActivePerformanceDraft performanceDraft,
  }) {
    if (incompleteBlockCount > 0) {
      return SessionFinishEligibility(
        canFinish: false,
        reason:
            'Complete $incompleteBlockCount remaining '
            'block${incompleteBlockCount == 1 ? '' : 's'}',
      );
    }

    final validation = _validationService.validateForCompletion(
      performanceDraft,
    );
    if (!validation.isValid) {
      final firstError = validation.fieldErrors.values.isEmpty
          ? null
          : validation.fieldErrors.values.first;
      return SessionFinishEligibility(
        canFinish: false,
        reason: firstError ?? 'Complete all required performance entries',
      );
    }

    return const SessionFinishEligibility(
      canFinish: true,
      reason: 'Ready to finish',
    );
  }
}
