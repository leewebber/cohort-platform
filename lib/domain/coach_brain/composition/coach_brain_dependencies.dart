import '../handlers/coach_decision_handler.dart';
import '../handlers/stub_coach_decision_handlers.dart';
import '../routing/coach_decision_handler_registry.dart';
import '../routing/coach_decision_router.dart';
import '../session_adaptation/session_adaptation_coach_decision_handler.dart';
import '../session_adaptation/session_adaptation_pipeline.dart';

/// Composition root for Coach Brain — wire handlers without changing router API.
class CoachBrainDependencies {
  CoachBrainDependencies._({required this.registry, required this.router});

  final CoachDecisionHandlerRegistry registry;
  final CoachDecisionRouter router;

  factory CoachBrainDependencies({
    Iterable<CoachDecisionHandler>? handlers,
    bool requireAllDecisionTypes = true,
  }) {
    final resolvedHandlers = handlers ?? kDefaultCoachDecisionHandlers();
    final registry = CoachDecisionHandlerRegistry(
      handlers: resolvedHandlers,
      requireAllDecisionTypes: requireAllDecisionTypes,
    );
    return CoachBrainDependencies._(
      registry: registry,
      router: CoachDecisionRouter(registry: registry),
    );
  }

  /// Production wiring: real session adaptation + stub handlers for other types.
  factory CoachBrainDependencies.defaults({
    SessionAdaptationPipeline? sessionAdaptationPipeline,
  }) {
    return CoachBrainDependencies(
      handlers: kDefaultCoachDecisionHandlers(
        sessionAdaptationPipeline: sessionAdaptationPipeline,
      ),
    );
  }

  /// All stub handlers (framework / placeholder tests).
  factory CoachBrainDependencies.stub() {
    return CoachBrainDependencies(handlers: kStubCoachDecisionHandlers);
  }
}

List<CoachDecisionHandler> kDefaultCoachDecisionHandlers({
  SessionAdaptationPipeline? sessionAdaptationPipeline,
}) {
  return [
    SessionAdaptationCoachDecisionHandler(
      pipeline: sessionAdaptationPipeline ?? const SessionAdaptationPipeline(),
    ),
    const StubExerciseSubstitutionCoachDecisionHandler(),
    const StubPrescriptionScalingCoachDecisionHandler(),
    const StubReschedulingCoachDecisionHandler(),
    const StubExtraTrainingCoachDecisionHandler(),
  ];
}
