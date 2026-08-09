import '../models/comparison_protocol.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_relationship.dart';
import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import '../vocabulary/exercise_relationship_type.dart';
import '../vocabulary/performance_dimension.dart';
import 'exercise_knowledge_validation_issue.dart';

/// Deterministic validation for Exercise Knowledge Authority aggregates.
///
/// Does not silently correct invalid authored knowledge.
class ExerciseKnowledgeValidator {
  const ExerciseKnowledgeValidator();

  List<ExerciseKnowledgeValidationIssue> validateDefinition(
    ExerciseDefinition definition, {
    String pathPrefix = 'definitions',
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final path = '$pathPrefix[${definition.id.value}]';

    // Identity already enforced by ExerciseId.parse for constructed defs;
    // still guard transitional aliases listed as canonical.
    for (final alias in definition.transitionalAliasIds) {
      if (!ExerciseId.isTransitionalKnowledgeId(alias)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.transitional_alias_ids',
            message:
                'Transitional alias must use cohort.exercise.* namespace: $alias',
            code: 'invalid_transitional_alias',
          ),
        );
      }
      if (ExerciseId.isCanonical(alias)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.transitional_alias_ids',
            message: 'Canonical EX-* id must not appear as transitional alias.',
            code: 'canonical_as_transitional_alias',
          ),
        );
      }
    }

    if (definition.canonicalName.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.canonical_name',
          message: 'Canonical name must not be blank.',
          code: 'blank_canonical_name',
        ),
      );
    }

    final seenAliases = <String>{};
    for (final alias in definition.aliases) {
      final normalized = alias.trim().toLowerCase();
      if (normalized.isEmpty) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.aliases',
            message: 'Alias must not be blank.',
            code: 'blank_alias',
          ),
        );
        continue;
      }
      if (!seenAliases.add(normalized)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.aliases',
            message: 'Duplicate alias: $alias',
            code: 'duplicate_alias',
          ),
        );
      }
    }

    if (definition.version.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.version',
          message: 'Version must not be blank.',
          code: 'blank_version',
        ),
      );
    }

    if (definition.owner.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.owner',
          message: 'Owner must not be blank.',
          code: 'blank_owner',
        ),
      );
    }

    // Forbidden: prescription/completion values embedded in definition JSON.
    final json = definition.toJson();
    for (final forbidden in const [
      'sets',
      'reps',
      'load',
      'tempo',
      'rest',
      'session_position',
      'completed_load',
      'athlete_result',
      'prescription_values',
      'completed_values',
    ]) {
      if (json.containsKey(forbidden)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.$forbidden',
            message:
                'ExerciseDefinition must not embed prescription or completion values.',
            code: 'forbidden_prescription_or_evidence_field',
          ),
        );
      }
    }

    final suitable = definition.environments.suitable.toSet();
    final unsuitable = definition.environments.unsuitable.toSet();
    final overlap = suitable.intersection(unsuitable);
    if (overlap.isNotEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.environments',
          message:
              'Environment listed as both suitable and unsuitable: $overlap',
          code: 'contradictory_environment_suitability',
        ),
      );
    }

    final required = definition.equipment.requiredTokens.map(_norm).toSet();
    final optional = definition.equipment.optionalTokens.map(_norm).toSet();
    final both = required.intersection(optional);
    if (both.isNotEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.equipment',
          message: 'Equipment token cannot be both required and optional: $both',
          code: 'impossible_equipment_combination',
        ),
      );
    }

    if (definition.lifecycleStatus == ExerciseLifecycleStatus.published &&
        definition.publishedAt == null) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.published_at',
          message: 'Published definition requires published_at.',
          code: 'missing_published_at',
        ),
      );
    }

    if (definition.lifecycleStatus == ExerciseLifecycleStatus.retired &&
        definition.retiredAt == null) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.retired_at',
          message: 'Retired definition requires retired_at.',
          code: 'missing_retired_at',
        ),
      );
    }

    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> validateRelationship(
    ExerciseRelationship relationship, {
    Set<String> knownExerciseIds = const {},
    Set<String> knownComparisonProtocolIds = const {},
    String pathPrefix = 'relationships',
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final path = '$pathPrefix[${relationship.id}]';

    if (relationship.id.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.id',
          message: 'Relationship id must not be blank.',
          code: 'blank_relationship_id',
        ),
      );
    }

    if (relationship.sourceExerciseId == relationship.targetExerciseId) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: path,
          message: 'Self-relationships are not allowed.',
          code: 'self_relationship',
        ),
      );
    }

    if (knownExerciseIds.isNotEmpty) {
      if (!knownExerciseIds.contains(relationship.sourceExerciseId.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.source_exercise_id',
            message:
                'Unknown source exercise: ${relationship.sourceExerciseId.value}',
            code: 'unknown_source_exercise',
          ),
        );
      }
      if (!knownExerciseIds.contains(relationship.targetExerciseId.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.target_exercise_id',
            message:
                'Unknown target exercise: ${relationship.targetExerciseId.value}',
            code: 'unknown_target_exercise',
          ),
        );
      }
    }

    if (relationship.claimsDirectComparability) {
      final protocolId = relationship.comparisonProtocolId?.trim() ?? '';
      if (protocolId.isEmpty) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.comparison_protocol_id',
            message:
                'directly_comparable_variant requires an explicit comparison protocol.',
            code: 'missing_comparison_protocol',
          ),
        );
      } else if (knownComparisonProtocolIds.isNotEmpty &&
          !knownComparisonProtocolIds.contains(protocolId)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.comparison_protocol_id',
            message: 'Unknown comparison protocol: $protocolId',
            code: 'unknown_comparison_protocol',
          ),
        );
      }
    } else if ((relationship.comparisonProtocolId?.trim().isNotEmpty ??
            false) &&
        relationship.relationshipType !=
            ExerciseRelationshipType.directlyComparableVariant) {
      // Protocol may exist for documentation, but must not claim comparability
      // via non-comparable relationship types without the explicit type.
      // Allowed as optional metadata — no error.
    }

    if (relationship.lifecycleStatus == ExerciseLifecycleStatus.published &&
        relationship.owner.trim() != 'founder') {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.owner',
          message:
              'Only founder-owned relationships may be published at launch.',
          code: 'non_founder_published_relationship',
        ),
      );
    }

    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> validateComparisonProtocol(
    ComparisonProtocol protocol, {
    String pathPrefix = 'comparison_protocols',
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final path = '$pathPrefix[${protocol.id}]';

    if (protocol.id.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.id',
          message: 'Comparison protocol id must not be blank.',
          code: 'blank_comparison_protocol_id',
        ),
      );
    }
    if (protocol.version.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.version',
          message: 'Comparison protocol version must not be blank.',
          code: 'blank_comparison_protocol_version',
        ),
      );
    }
    if (protocol.validDimensions.isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.valid_dimensions',
          message: 'Comparison protocol requires at least one valid dimension.',
          code: 'empty_comparison_dimensions',
        ),
      );
    }
    for (final dim in protocol.validDimensions) {
      // All enum values are supported; guard against empty wire anomalies.
      if (dim.wireValue.isEmpty) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.valid_dimensions',
            message: 'Unsupported performance dimension.',
            code: 'unsupported_comparison_dimension',
          ),
        );
      }
    }
    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> validateLifecycleTransition({
    required ExerciseLifecycleStatus from,
    required ExerciseLifecycleStatus to,
    String path = 'lifecycle',
  }) {
    if (from.canTransitionTo(to)) return const [];
    return [
      ExerciseKnowledgeValidationIssue(
        path: path,
        message: 'Invalid lifecycle transition: ${from.wireValue} → ${to.wireValue}',
        code: 'invalid_lifecycle_transition',
      ),
    ];
  }

  /// Governed search aliases must be unique across the catalogue when present.
  List<ExerciseKnowledgeValidationIssue> validateGovernedAliases(
    List<ExerciseDefinition> definitions,
  ) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final seen = <String, String>{};
    for (final def in definitions) {
      for (final alias in def.aliases) {
        final key = alias.trim().toLowerCase();
        if (key.isEmpty) continue;
        final prior = seen[key];
        if (prior != null && prior != def.id.value) {
          issues.add(
            ExerciseKnowledgeValidationIssue(
              path: 'definitions[${def.id.value}].aliases',
              message:
                  'Alias "$alias" collides with definition $prior.',
              code: 'duplicate_governed_alias',
            ),
          );
        } else {
          seen[key] = def.id.value;
        }
      }
    }
    return issues;
  }

  /// Aggregate validation across definitions, relationships, and protocols.
  List<ExerciseKnowledgeValidationIssue> validateCatalogue({
    required List<ExerciseDefinition> definitions,
    required List<ExerciseRelationship> relationships,
    required List<ComparisonProtocol> comparisonProtocols,
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final knownIds = <String>{};
    final seenDefIds = <String>{};

    for (final def in definitions) {
      if (!seenDefIds.add(def.id.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'definitions[${def.id.value}]',
            message: 'Duplicate exercise definition id.',
            code: 'duplicate_definition_id',
          ),
        );
      }
      knownIds.add(def.id.value);
      issues.addAll(validateDefinition(def));
    }
    issues.addAll(validateGovernedAliases(definitions));

    final protocolIds = <String>{};
    for (final protocol in comparisonProtocols) {
      protocolIds.add(protocol.id);
      issues.addAll(validateComparisonProtocol(protocol));
      if (!knownIds.contains(protocol.exerciseId.value) &&
          knownIds.isNotEmpty) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'comparison_protocols[${protocol.id}].exercise_id',
            message: 'Protocol references unknown exercise.',
            code: 'protocol_unknown_exercise',
          ),
        );
      }
    }

    final seenRelKeys = <String>{};
    final seenRelIds = <String>{};
    for (final rel in relationships) {
      if (!seenRelIds.add(rel.id)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'relationships[${rel.id}]',
            message: 'Duplicate relationship id.',
            code: 'duplicate_relationship_id',
          ),
        );
      }
      if (!seenRelKeys.add(rel.uniquenessKey)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'relationships[${rel.id}]',
            message: 'Duplicate relationship for ${rel.uniquenessKey}.',
            code: 'duplicate_relationship',
          ),
        );
      }
      issues.addAll(
        validateRelationship(
          rel,
          knownExerciseIds: knownIds,
          knownComparisonProtocolIds: protocolIds,
        ),
      );
    }

    return issues;
  }
}

String _norm(String value) => value.trim().toLowerCase();
