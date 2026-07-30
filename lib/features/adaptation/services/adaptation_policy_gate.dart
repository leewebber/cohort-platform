import '../../../models/adaptation_reason.dart';
import 'post_completion_adaptation_evaluator.dart';

/// Allowed / prohibited adaptation scope (coach-authored policy boundary).
enum AdaptationChangeKind {
  reduceVolume,
  removeOptionalAccessories,
  compressForTime,
  substituteApprovedEquipment,
  substituteApprovedExercise,
  convertApprovedModality,
  // Prohibited:
  rewritePlan,
  rewriteLaterSessions,
  changePeriodisation,
  forceDeload,
  moveWeek,
  changeAssessments,
  inventUnrelatedTraining,
  mutateProgrammedSession,
}

class AdaptationPolicyGate {
  const AdaptationPolicyGate();

  static const allowed = {
    AdaptationChangeKind.reduceVolume,
    AdaptationChangeKind.removeOptionalAccessories,
    AdaptationChangeKind.compressForTime,
    AdaptationChangeKind.substituteApprovedEquipment,
    AdaptationChangeKind.substituteApprovedExercise,
    AdaptationChangeKind.convertApprovedModality,
  };

  static const prohibited = {
    AdaptationChangeKind.rewritePlan,
    AdaptationChangeKind.rewriteLaterSessions,
    AdaptationChangeKind.changePeriodisation,
    AdaptationChangeKind.forceDeload,
    AdaptationChangeKind.moveWeek,
    AdaptationChangeKind.changeAssessments,
    AdaptationChangeKind.inventUnrelatedTraining,
    AdaptationChangeKind.mutateProgrammedSession,
  };

  bool isAllowed(AdaptationChangeKind kind) => allowed.contains(kind);

  /// Returns rejected kinds (empty when all permitted).
  List<AdaptationChangeKind> rejectUnsupported(
    Iterable<AdaptationChangeKind> proposed,
  ) {
    return proposed.where((k) => !isAllowed(k)).toList(growable: false);
  }

  void assertAllowed(Iterable<AdaptationChangeKind> proposed) {
    final bad = rejectUnsupported(proposed);
    if (bad.isNotEmpty) {
      throw AdaptationPolicyException(
        'Unsupported adaptation changes: ${bad.map((e) => e.name).join(', ')}',
        rejected: bad,
      );
    }
  }

  /// Day-of athlete Adapt request categories → proposed change kinds.
  static List<AdaptationChangeKind> kindsForDayOf(AdaptationReason reason) {
    return switch (reason) {
      AdaptationReason.time => const [
        AdaptationChangeKind.compressForTime,
        AdaptationChangeKind.reduceVolume,
        AdaptationChangeKind.removeOptionalAccessories,
      ],
      AdaptationReason.equipment => const [
        AdaptationChangeKind.substituteApprovedEquipment,
        AdaptationChangeKind.substituteApprovedExercise,
      ],
      AdaptationReason.environment => const [
        AdaptationChangeKind.convertApprovedModality,
        AdaptationChangeKind.substituteApprovedEquipment,
      ],
      // Recovery may reduce volume for today — never force a deload week.
      AdaptationReason.recovery => const [
        AdaptationChangeKind.reduceVolume,
        AdaptationChangeKind.removeOptionalAccessories,
      ],
    };
  }

  /// Post-completion evaluators mutate future slots — prohibited by default.
  static List<AdaptationChangeKind> kindsForPostCompletion(
    AdaptationEvaluationType type,
  ) {
    return switch (type) {
      AdaptationEvaluationType.loadProgression => const [
        AdaptationChangeKind.rewriteLaterSessions,
      ],
      AdaptationEvaluationType.protocolSubstitution => const [
        AdaptationChangeKind.rewriteLaterSessions,
        AdaptationChangeKind.forceDeload,
      ],
    };
  }
}

class AdaptationPolicyException implements Exception {
  AdaptationPolicyException(this.message, {this.rejected = const []});

  final String message;
  final List<AdaptationChangeKind> rejected;

  @override
  String toString() => 'AdaptationPolicyException: $message';
}
