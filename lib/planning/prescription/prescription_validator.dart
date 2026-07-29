import '../exercise_policy/models/exercise_policy_models.dart';
import '../session_blueprint/models/session_blueprint.dart';
import '../session_blueprint/models/session_blueprint_semantics.dart';
import 'models/prescription_models.dart';

class PrescriptionValidationResult {
  const PrescriptionValidationResult({
    required this.isValid,
    this.messages = const [],
  });

  final bool isValid;
  final List<String> messages;
}

class PrescriptionValidator {
  const PrescriptionValidator();

  PrescriptionValidationResult validateRequest(PrescriptionRequest request) {
    final messages = <String>[];
    if (request.executionPlan.orderedSelections.isEmpty) {
      messages.add('execution plan has no exercise selections');
    }
    if (request.blueprint.blueprintId != request.executionPlan.blueprintId) {
      messages.add('blueprint id mismatch between plan and blueprint');
    }
    if (request.blueprint.status == SessionBlueprintStatus.invalidRecommendation) {
      messages.add('blueprint invalid');
    }
    return PrescriptionValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }

  PrescriptionValidationResult validateResult({
    required PrescriptionRequest request,
    required PrescriptionResult result,
  }) {
    final messages = <String>[];
    if (result.primaryTrainingIntentId !=
        request.blueprint.primaryTrainingIntentId) {
      messages.add('primary training intent must be preserved');
    }
    if (result.sessionArchetypeId !=
        request.blueprint.sessionArchetype.archetypeId) {
      messages.add('session archetype must be preserved');
    }

    final selectionIds = request.executionPlan.orderedSelections
        .map((s) => s.exerciseId)
        .toSet();
    final prescribedIds = result.prescriptions.map((p) => p.exerciseId).toSet();

    if (result.status == PrescriptionStatus.complete) {
      if (!selectionIds.every(prescribedIds.contains)) {
        messages.add('every selected exercise must receive a prescription');
      }
    }

    for (final mapping in request.executionPlan.componentMappings) {
      if (mapping.exerciseIds.isEmpty) continue;
      final hasRx = result.prescriptions.any(
        (p) => p.structuralComponentSequence == mapping.componentSequence,
      );
      if (!hasRx && result.status == PrescriptionStatus.complete) {
        messages.add(
          'component ${mapping.componentSequence} missing prescription',
        );
      }
    }

    return PrescriptionValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }
}
