import '../models/planning_recommendation.dart';
import 'models/planning_context.dart';
import 'models/planning_stage_models.dart';

class PlanningContextValidationResult {
  const PlanningContextValidationResult({
    required this.isValid,
    this.messages = const [],
  });

  final bool isValid;
  final List<String> messages;
}

class PlanningContextValidator {
  const PlanningContextValidator();

  PlanningContextValidationResult validate(PlanningContext context) {
    final messages = <String>[];

    final ontology = context.input.knowledgeOntologyVersion;

    if (context.recommendation != null &&
        context.recommendation!.ontologyVersion != ontology) {
      messages.add('recommendation ontology mismatch');
    }
    if (context.sessionBlueprint != null &&
        context.sessionBlueprint!.ontologyVersion != ontology) {
      messages.add('blueprint ontology mismatch');
    }
    if (context.exercisePolicyResult != null &&
        context.exercisePolicyResult!.ontologyVersion != ontology) {
      messages.add('policy ontology mismatch');
    }

    if (context.sessionExecutionPlan != null &&
        context.prescriptionResult == null) {
      messages.add('execution plan requires prescription result');
    }

    if (context.recommendation != null && context.sessionBlueprint != null) {
      final recArch =
          context.recommendation!.recommendedSessionArchetype?.archetypeId;
      if (recArch != null &&
          recArch != context.sessionBlueprint!.sessionArchetype.archetypeId) {
        messages.add('blueprint archetype diverged from recommendation');
      }
    }

    if (context.exercisePolicyResult != null && context.sessionBlueprint != null) {
      if (context.exercisePolicyResult!.primaryTrainingIntentId !=
          context.sessionBlueprint!.primaryTrainingIntentId) {
        messages.add('policy intent diverged from blueprint');
      }
      if (context.exercisePolicyResult!.sessionArchetypeId !=
          context.sessionBlueprint!.sessionArchetype.archetypeId) {
        messages.add('policy archetype diverged from blueprint');
      }
    }

    if (context.prescriptionResult != null && context.sessionBlueprint != null) {
      if (context.prescriptionResult!.primaryTrainingIntentId !=
          context.sessionBlueprint!.primaryTrainingIntentId) {
        messages.add('prescription intent diverged from blueprint');
      }
    }

    _checkStageChain(context, messages);

    return PlanningContextValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }

  void _checkStageChain(PlanningContext context, List<String> messages) {
    final succeeded = context.stages
        .where((s) => s.isSuccess)
        .map((s) => s.stageId)
        .toSet();

    if (context.sessionBlueprint != null &&
        !succeeded.contains(PlanningStageId.planningEngine)) {
      messages.add('blueprint present without successful planning stage');
    }
    if (context.exercisePolicyResult != null &&
        !succeeded.contains(PlanningStageId.sessionBlueprint)) {
      messages.add('policy present without successful blueprint stage');
    }
    if (context.prescriptionResult != null &&
        !succeeded.contains(PlanningStageId.exercisePolicy)) {
      messages.add('prescription present without successful policy stage');
    }
    if (context.sessionExecutionPlan != null &&
        !succeeded.contains(PlanningStageId.prescription)) {
      messages.add('execution plan present without successful prescription stage');
    }
  }
}
