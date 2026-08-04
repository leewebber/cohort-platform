import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';

/// Typed result of validating an equipment adaptation request.
enum EquipmentAdaptationRequestIssue {
  availableEquipmentRequired,
  emptyAvailableEquipment,
  invalidEquipmentToken,
  unknownEquipmentToken,
  contradictoryEquipmentSet,
}

class EquipmentAdaptationRequestValidation {
  const EquipmentAdaptationRequestValidation._({
    required this.isValid,
    this.normalizedEquipment = const {},
    this.issue,
    this.detail,
  });

  factory EquipmentAdaptationRequestValidation.ok(Set<String> normalized) {
    return EquipmentAdaptationRequestValidation._(
      isValid: true,
      normalizedEquipment: Set<String>.unmodifiable(normalized),
    );
  }

  factory EquipmentAdaptationRequestValidation.invalid({
    required EquipmentAdaptationRequestIssue issue,
    String? detail,
  }) {
    return EquipmentAdaptationRequestValidation._(
      isValid: false,
      issue: issue,
      detail: detail,
    );
  }

  final bool isValid;
  final Set<String> normalizedEquipment;
  final EquipmentAdaptationRequestIssue? issue;
  final String? detail;
}

/// Normalizes and fail-closes equipment adaptation requests.
///
/// Known equipment ids are derived from the curated knowledge graph (exercise
/// required/optional equipment and substitution equipment deltas). Tokens that
/// are absent, empty, or unknown fail closed. Availability is never assumed.
class EquipmentAdaptationRequestValidator {
  const EquipmentAdaptationRequestValidator();

  EquipmentAdaptationRequestValidation validate({
    required AdaptationRequest request,
    required KnowledgeGraphReader knowledge,
  }) {
    if (request.reason != AdaptationReason.equipment) {
      return EquipmentAdaptationRequestValidation.ok(
        request.availableEquipment ?? const {},
      );
    }

    final raw = request.availableEquipment;
    if (raw == null) {
      return EquipmentAdaptationRequestValidation.invalid(
        issue: EquipmentAdaptationRequestIssue.availableEquipmentRequired,
        detail: 'availableEquipment is required for equipment adaptation',
      );
    }
    if (raw.isEmpty) {
      return EquipmentAdaptationRequestValidation.invalid(
        issue: EquipmentAdaptationRequestIssue.emptyAvailableEquipment,
        detail: 'availableEquipment must not be empty',
      );
    }

    final known = knownEquipmentIds(knowledge);
    final normalized = <String>{};
    for (final token in raw) {
      final trimmed = token.trim();
      if (trimmed.isEmpty) {
        return EquipmentAdaptationRequestValidation.invalid(
          issue: EquipmentAdaptationRequestIssue.invalidEquipmentToken,
          detail: 'blank equipment token',
        );
      }
      final canonical = canonicalize(trimmed, known);
      if (canonical == null) {
        return EquipmentAdaptationRequestValidation.invalid(
          issue: EquipmentAdaptationRequestIssue.unknownEquipmentToken,
          detail: trimmed,
        );
      }
      normalized.add(canonical);
    }

    if (normalized.isEmpty) {
      return EquipmentAdaptationRequestValidation.invalid(
        issue: EquipmentAdaptationRequestIssue.emptyAvailableEquipment,
      );
    }

    return EquipmentAdaptationRequestValidation.ok(normalized);
  }

  AdaptationRequest applyNormalized(
    AdaptationRequest request,
    Set<String> normalized,
  ) {
    return AdaptationRequest(
      reason: request.reason,
      recoveryState: request.recoveryState,
      environment: request.environment,
      availableEquipment: normalized,
      availableMinutes: request.availableMinutes,
    );
  }

  static Set<String> knownEquipmentIds(KnowledgeGraphReader knowledge) {
    final ids = <String>{};
    for (final exercise in knowledge.allExercises) {
      ids.addAll(exercise.requiredEquipmentIds);
      ids.addAll(exercise.optionalEquipmentIds);
      for (final rule in knowledge.substitutionsForSource(exercise.id)) {
        ids.addAll(rule.equipmentRemovedIds);
        ids.addAll(rule.equipmentAddedIds);
      }
    }
    return ids;
  }

  static String? canonicalize(String token, Set<String> known) {
    if (known.contains(token)) return token;
    final lower = token.toLowerCase();
    for (final id in known) {
      if (id.toLowerCase() == lower) return id;
      final leaf = id.split('.').last;
      if (leaf.toLowerCase() == lower) return id;
    }
    return null;
  }
}
