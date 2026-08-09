import '../models/exercise_identity_mapping.dart';
import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'exercise_knowledge_validation_issue.dart';

/// Deterministic validation for transitional → canonical identity mappings.
class ExerciseIdentityMappingValidator {
  const ExerciseIdentityMappingValidator();

  List<ExerciseKnowledgeValidationIssue> validateMapping(
    ExerciseIdentityMapping mapping, {
    Set<String> knownCanonicalIds = const {},
    String pathPrefix = 'identity_mappings',
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final path = '$pathPrefix[${mapping.id}]';

    if (mapping.id.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.id',
          message: 'Mapping id must not be blank.',
          code: 'blank_mapping_id',
        ),
      );
    }

    if (mapping.provenance.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.provenance',
          message:
              'Mapping provenance is required; name similarity is not identity.',
          code: 'blank_mapping_provenance',
        ),
      );
    }

    final forbiddenProvenance = mapping.provenance.trim().toLowerCase();
    for (final token in const [
      'name_match',
      'name similarity',
      'heuristic',
      'guess',
      'alias_match',
      'display_name',
    ]) {
      if (forbiddenProvenance.contains(token)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.provenance',
            message:
                'Self-derived or name-derived mapping provenance is forbidden.',
            code: 'heuristic_mapping_provenance',
          ),
        );
        break;
      }
    }

    if (mapping.version.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.version',
          message: 'Mapping version must not be blank.',
          code: 'blank_mapping_version',
        ),
      );
    }

    if (mapping.owner.trim().isEmpty) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.owner',
          message: 'Mapping owner must not be blank.',
          code: 'blank_mapping_owner',
        ),
      );
    }

    if (mapping.lifecycleStatus == ExerciseLifecycleStatus.published &&
        mapping.owner.trim() != 'founder') {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.owner',
          message: 'Only founder-owned mappings may be published.',
          code: 'non_founder_published_mapping',
        ),
      );
    }

    if (mapping.lifecycleStatus == ExerciseLifecycleStatus.published &&
        mapping.publishedAt == null) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.published_at',
          message: 'Published mapping requires published_at.',
          code: 'missing_published_at',
        ),
      );
    }

    if (mapping.lifecycleStatus == ExerciseLifecycleStatus.retired &&
        mapping.retiredAt == null) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.retired_at',
          message: 'Retired mapping requires retired_at.',
          code: 'missing_retired_at',
        ),
      );
    }

    if (knownCanonicalIds.isNotEmpty &&
        !knownCanonicalIds.contains(mapping.canonicalId.value)) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.canonical_id',
          message:
              'Canonical target ${mapping.canonicalId.value} is not in the '
              'supplied catalogue.',
          code: 'missing_canonical_target',
        ),
      );
    }

    // Guard: transitional parse already enforced; still reject EX-* as source.
    if (ExerciseId.isCanonical(mapping.transitionalId.value)) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.transitional_id',
          message: 'Canonical EX-* cannot be used as transitional source.',
          code: 'canonical_as_transitional_source',
        ),
      );
    }
    if (!TransitionalExerciseId.isTransitional(mapping.transitionalId.value)) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.transitional_id',
          message: 'Source must use cohort.exercise.* format.',
          code: 'invalid_transitional_source',
        ),
      );
    }

    return issues;
  }

  List<ExerciseKnowledgeValidationIssue> validateCatalogue({
    required List<ExerciseIdentityMapping> mappings,
    required Set<String> knownCanonicalIds,
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];
    final seenIds = <String>{};
    final activeBySource = <String, List<ExerciseIdentityMapping>>{};

    for (final mapping in mappings) {
      if (!seenIds.add(mapping.id)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'identity_mappings[${mapping.id}]',
            message: 'Duplicate mapping record id.',
            code: 'duplicate_mapping_id',
          ),
        );
      }
      issues.addAll(
        validateMapping(mapping, knownCanonicalIds: knownCanonicalIds),
      );
      if (mapping.lifecycleStatus == ExerciseLifecycleStatus.published) {
        activeBySource
            .putIfAbsent(mapping.transitionalId.value, () => [])
            .add(mapping);
      }
    }

    for (final entry in activeBySource.entries) {
      final targets = entry.value.map((m) => m.canonicalId.value).toSet();
      if (targets.length > 1) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'identity_mappings[${entry.key}]',
            message:
                'Transitional id maps to multiple active canonical targets: '
                '$targets',
            code: 'conflicting_active_mapping',
          ),
        );
      } else if (entry.value.length > 1) {
        // Same target duplicated as separate published records — reject.
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'identity_mappings[${entry.key}]',
            message: 'Duplicate active mapping records for ${entry.key}.',
            code: 'duplicate_active_mapping',
          ),
        );
      }
    }

    return issues;
  }
}
