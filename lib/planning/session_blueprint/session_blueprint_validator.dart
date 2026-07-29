import '../models/planning_recommendation.dart';
import 'models/session_blueprint.dart';

class SessionBlueprintValidationResult {
  const SessionBlueprintValidationResult({
    required this.isValid,
    this.messages = const [],
  });

  final bool isValid;
  final List<String> messages;
}

/// Central validation for blueprint inputs and outputs.
class SessionBlueprintValidator {
  const SessionBlueprintValidator();

  SessionBlueprintValidationResult validateRecommendation({
    required PlanningRecommendation recommendation,
    required String bundleOntologyVersion,
  }) {
    final messages = <String>[];
    if (recommendation.status == PlanningRecommendationStatus.invalidInput) {
      messages.add('Planning recommendation status is invalidInput');
    }
    if (recommendation.ontologyVersion != bundleOntologyVersion) {
      messages.add(
        'Recommendation ontology ${recommendation.ontologyVersion} != bundle $bundleOntologyVersion',
      );
    }
    if (recommendation.athleteId.trim().isEmpty) {
      messages.add('Recommendation athleteId is required');
    }
    return SessionBlueprintValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }

  SessionBlueprintValidationResult validateBlueprint(SessionBlueprint blueprint) {
    final messages = <String>[];

    if (blueprint.athleteId.trim().isEmpty) {
      messages.add('blueprint athleteId required');
    }
    if (blueprint.sessionArchetype.archetypeId.trim().isEmpty) {
      messages.add('session archetype required');
    }
    if (blueprint.primaryTrainingIntentId.trim().isEmpty) {
      messages.add('primary training intent required');
    }
    if (blueprint.structuralComponents.isEmpty &&
        blueprint.status == SessionBlueprintStatus.complete) {
      messages.add('complete blueprint requires structural components');
    }

    var prevSeq = 0;
    for (final c in blueprint.structuralComponents) {
      if (c.sequence <= prevSeq) {
        messages.add('structural components must have strictly increasing sequence');
        break;
      }
      prevSeq = c.sequence;
    }

    if (blueprint.status == SessionBlueprintStatus.infeasible &&
        blueprint.explainability.factors.isEmpty &&
        blueprint.warnings.isEmpty) {
      messages.add('infeasible blueprint requires rationale');
    }

    if (blueprint.status == SessionBlueprintStatus.invalidRecommendation &&
        blueprint.explainability.narrativeSummary.trim().isEmpty) {
      messages.add('invalidRecommendation requires narrative rationale');
    }

    return SessionBlueprintValidationResult(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }
}

/// Contract guard — model shape excludes prescriptions; this audits string fields.
class SessionBlueprintContract {
  const SessionBlueprintContract._();

  static const forbiddenPatterns = [
    'cohort.exercise.',
    ' sets ',
    ' reps ',
    '1RM',
    ' bpm',
    ' min/km',
  ];

  static void assertNoPrescriptionContent(SessionBlueprint blueprint) {
    final buffer = StringBuffer()
      ..write(blueprint.objective.summary)
      ..write(blueprint.explainability.narrativeSummary);
    for (final c in blueprint.structuralComponents) {
      buffer
        ..write(c.purpose)
        ..write(c.rationale);
    }
    for (final a in blueprint.desiredAdaptations) {
      buffer.write(a.rationale);
    }
    final blob = buffer.toString().toLowerCase();
    for (final pattern in forbiddenPatterns) {
      if (blob.contains(pattern.toLowerCase())) {
        throw StateError('Forbidden prescription pattern: $pattern');
      }
    }
  }
}
