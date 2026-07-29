import '../session_blueprint/models/session_blueprint.dart';
import 'models/exercise_policy_models.dart';

class ExercisePolicyValidationResult {
  const ExercisePolicyValidationResult({
    required this.isValid,
    this.messages = const [],
  });

  final bool isValid;
  final List<String> messages;
}

class ExercisePolicyValidator {
  const ExercisePolicyValidator();

  ExercisePolicyValidationResult validateRequest(ExercisePolicyRequest request) {
    final messages = <String>[];
    final bp = request.blueprint;
    if (bp.blueprintId.trim().isEmpty) {
      messages.add('blueprintId required');
    }
    if (bp.status == SessionBlueprintStatus.invalidRecommendation) {
      messages.add('blueprint status invalidRecommendation');
    }
    if (bp.primaryTrainingIntentId.trim().isEmpty) {
      messages.add('primaryTrainingIntentId required');
    }
    return ExercisePolicyValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }

  ExercisePolicyValidationResult validateResult({
    required ExercisePolicyRequest request,
    required ExercisePolicyResult result,
  }) {
    final messages = <String>[];
    final bp = request.blueprint;

    if (result.primaryTrainingIntentId != bp.primaryTrainingIntentId) {
      messages.add('primary training intent must be preserved');
    }
    if (result.sessionArchetypeId != bp.sessionArchetype.archetypeId) {
      messages.add('session archetype must be preserved');
    }

    for (final cap in bp.requiredCapabilities) {
      if (result.status == MovementSelectionStatus.complete) {
        final covered = result.selections.any(
          (s) => s.matchedCapabilityIds.contains(cap.capabilityId),
        );
        if (!covered && cap.requirementKind == 'primary') {
          messages.add('primary capability ${cap.capabilityId} not covered');
        }
      }
    }

    if (result.selections.isEmpty &&
        result.status == MovementSelectionStatus.complete) {
      messages.add('complete result requires selections');
    }

    for (final sel in result.selections) {
      if (!sel.exerciseId.startsWith('cohort.exercise.')) {
        messages.add('invalid exercise id ${sel.exerciseId}');
      }
    }

    return ExercisePolicyValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }
}
