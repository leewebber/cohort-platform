import '../contracts/coach_decision_request.dart';
import '../contracts/coach_decision_result.dart';
import '../vocabulary/coach_decision_type.dart';
import 'coach_decision_handler.dart';

/// Framework placeholder — no coaching behaviour.
class StubSessionAdaptationCoachDecisionHandler extends CoachDecisionHandler {
  const StubSessionAdaptationCoachDecisionHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.sessionAdaptation;

  @override
  String get handlerName => 'stub_session_adaptation';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'session_adaptation_not_implemented',
    );
  }
}

class StubExerciseSubstitutionCoachDecisionHandler
    extends CoachDecisionHandler {
  const StubExerciseSubstitutionCoachDecisionHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.exerciseSubstitution;

  @override
  String get handlerName => 'stub_exercise_substitution';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'exercise_substitution_not_implemented',
    );
  }
}

class StubPrescriptionScalingCoachDecisionHandler extends CoachDecisionHandler {
  const StubPrescriptionScalingCoachDecisionHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.prescriptionScaling;

  @override
  String get handlerName => 'stub_prescription_scaling';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'prescription_scaling_not_implemented',
    );
  }
}

class StubReschedulingCoachDecisionHandler extends CoachDecisionHandler {
  const StubReschedulingCoachDecisionHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.rescheduling;

  @override
  String get handlerName => 'stub_rescheduling';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'rescheduling_not_implemented',
    );
  }
}

class StubExtraTrainingCoachDecisionHandler extends CoachDecisionHandler {
  const StubExtraTrainingCoachDecisionHandler();

  @override
  CoachDecisionType get decisionType => CoachDecisionType.extraTraining;

  @override
  String get handlerName => 'stub_extra_training';

  @override
  CoachDecisionResult handle(CoachDecisionRequest request) {
    return CoachDecisionResult.stubPlaceholder(
      decisionType: decisionType,
      requestId: request.requestId,
      handlerName: handlerName,
      placeholderCode: 'extra_training_not_implemented',
    );
  }
}

/// All framework stub handlers for composition and tests.
const List<CoachDecisionHandler> kStubCoachDecisionHandlers = [
  StubSessionAdaptationCoachDecisionHandler(),
  StubExerciseSubstitutionCoachDecisionHandler(),
  StubPrescriptionScalingCoachDecisionHandler(),
  StubReschedulingCoachDecisionHandler(),
  StubExtraTrainingCoachDecisionHandler(),
];
