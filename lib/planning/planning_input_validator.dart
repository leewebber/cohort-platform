import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';

import 'models/planning_input.dart';

/// Outcome of planning input validation (normal path — not thrown).
enum PlanningValidationCode {
  ok,
  missingRequired,
  ontologyVersionMismatch,
  unknownGoal,
  unknownPhase,
  unknownBlock,
  unknownWeekType,
  precomputedGapsIncompatible,
  precomputedIntentsIncompatible,
}

class PlanningValidationResult {
  const PlanningValidationResult({
    required this.code,
    this.messages = const [],
  });

  const PlanningValidationResult.ok()
    : code = PlanningValidationCode.ok,
      messages = const [];

  final PlanningValidationCode code;
  final List<String> messages;

  bool get isOk => code == PlanningValidationCode.ok;
}

/// Centralised [PlanningInput] validation against live knowledge bundle.
class PlanningInputValidator {
  const PlanningInputValidator();

  PlanningValidationResult validate({
    required PlanningInput input,
    required String bundleOntologyVersion,
    required KnowledgeGraphReader knowledge,
  }) {
    final messages = <String>[];

    if (input.athleteId.trim().isEmpty) {
      messages.add('athleteId is required');
    }
    if (input.goalContext.goalId.trim().isEmpty) {
      messages.add('goalContext.goalId is required');
    }
    if (input.knowledgeOntologyVersion.trim().isEmpty) {
      messages.add('knowledgeOntologyVersion is required');
    }

    if (messages.isNotEmpty) {
      return PlanningValidationResult(
        code: PlanningValidationCode.missingRequired,
        messages: messages,
      );
    }

    if (input.knowledgeOntologyVersion != bundleOntologyVersion) {
      return PlanningValidationResult(
        code: PlanningValidationCode.ontologyVersionMismatch,
        messages: [
          'Input ontology ${input.knowledgeOntologyVersion} != bundle $bundleOntologyVersion',
        ],
      );
    }

    if (knowledge.goalRequirements(input.goalContext.goalId) == null) {
      return PlanningValidationResult(
        code: PlanningValidationCode.unknownGoal,
        messages: ['Unknown goal: ${input.goalContext.goalId}'],
      );
    }

    if (input.activeProgrammePhaseId != null &&
        knowledge.programmePhaseById(input.activeProgrammePhaseId!) == null) {
      return PlanningValidationResult(
        code: PlanningValidationCode.unknownPhase,
        messages: ['Unknown programme phase: ${input.activeProgrammePhaseId}'],
      );
    }

    if (input.activeTrainingBlockId != null) {
      final block = knowledge.trainingBlockById(input.activeTrainingBlockId!);
      if (block == null) {
        return PlanningValidationResult(
          code: PlanningValidationCode.unknownBlock,
          messages: ['Unknown training block: ${input.activeTrainingBlockId}'],
        );
      }
    }

    if (input.activeWeekTypeId != null &&
        knowledge.weekTypeById(input.activeWeekTypeId!) == null) {
      return PlanningValidationResult(
        code: PlanningValidationCode.unknownWeekType,
        messages: ['Unknown week type: ${input.activeWeekTypeId}'],
      );
    }

    final preGaps = input.precomputedCapabilityGaps;
    if (preGaps != null) {
      if (preGaps.goalId != input.goalContext.goalId ||
          preGaps.ontologyVersion != input.knowledgeOntologyVersion) {
        return PlanningValidationResult(
          code: PlanningValidationCode.precomputedGapsIncompatible,
          messages: ['Precomputed gaps do not match goal or ontology version'],
        );
      }
    }

    final preIntents = input.precomputedTrainingIntents;
    if (preIntents != null) {
      if (preIntents.goalId != input.goalContext.goalId ||
          preIntents.ontologyVersion != input.knowledgeOntologyVersion) {
        return PlanningValidationResult(
          code: PlanningValidationCode.precomputedIntentsIncompatible,
          messages: [
            'Precomputed intents do not match goal or ontology version',
          ],
        );
      }
    }

    if (input.progressionPathId != null &&
        knowledge.progressionPath(pathId: input.progressionPathId) == null) {
      return PlanningValidationResult(
        code: PlanningValidationCode.unknownPhase,
        messages: ['Unknown progression path: ${input.progressionPathId}'],
      );
    }

    return const PlanningValidationResult.ok();
  }
}
