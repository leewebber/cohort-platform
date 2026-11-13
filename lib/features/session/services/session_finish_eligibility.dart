import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../programme/models/programme_execution_context.dart';
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

    return _validate(performanceDraft, readyReason: 'Ready to finish');
  }

  bool allowsEarlyFinish({
    required ActivePerformanceDraft draft,
    required ProgrammeExecutionContext? programmeContext,
  }) =>
      programmeContext?.isProgrammeBacked == true &&
      programmeContext?.occurrenceId?.trim().isNotEmpty == true &&
      (switch (programmeContext?.packageSchemaVersion) {
        null || 1 || 2 => true,
        _ => false,
      }) &&
      _validationService.hasWorkToFinishEarly(draft);

  SessionFinishEligibility evaluateEarly({
    required PerformanceCaptureController controller,
    required ProgrammeExecutionContext? programmeContext,
  }) {
    if (!allowsEarlyFinish(
      draft: controller.draft,
      programmeContext: programmeContext,
    )) {
      return const SessionFinishEligibility(
        canFinish: false,
        reason:
            'Finish early is unavailable for this workout or its current results.',
      );
    }
    return _validate(
      controller.forEarlyFinish().draft,
      readyReason: 'Ready to finish early',
    );
  }

  SessionFinishEligibility _validate(
    ActivePerformanceDraft performanceDraft, {
    required String readyReason,
  }) {
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

    return SessionFinishEligibility(canFinish: true, reason: readyReason);
  }
}
