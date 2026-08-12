import '../../domain/exercise_knowledge/models/exercise_definition_lookup.dart';
import '../../domain/exercise_knowledge/models/knowledge_content_common.dart';
import '../../domain/exercise_knowledge/ports/exercise_knowledge_repository.dart';
import '../../domain/exercise_knowledge/validation/exercise_movement_content_validator.dart';
import '../../domain/exercise_knowledge/value_objects/exercise_id.dart';
import '../../domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import 'operational_exercise_text_guidance.dart';

enum OperationalExerciseTextGuidanceFailureCode {
  invalidCanonicalExerciseId('invalid_canonical_exercise_id'),
  missingPublishedExerciseDefinition('missing_published_exercise_definition'),
  operationalTextGuidanceUnavailable('operational_text_guidance_unavailable'),
  contentProjectionInvariantViolation('content_projection_invariant_violation');

  const OperationalExerciseTextGuidanceFailureCode(this.wireValue);

  final String wireValue;
}

sealed class OperationalExerciseTextGuidanceQueryResult {
  const OperationalExerciseTextGuidanceQueryResult();

  bool get isResolved => this is OperationalExerciseTextGuidanceResolved;

  Map<String, Object?> toJson();
}

final class OperationalExerciseTextGuidanceResolved
    extends OperationalExerciseTextGuidanceQueryResult {
  const OperationalExerciseTextGuidanceResolved(this.guidance);

  final OperationalExerciseTextGuidance guidance;

  @override
  Map<String, Object?> toJson() => {
    'status': 'resolved',
    'guidance': guidance.toJson(),
  };
}

final class OperationalExerciseTextGuidanceRejected
    extends OperationalExerciseTextGuidanceQueryResult {
  const OperationalExerciseTextGuidanceRejected({
    required this.code,
    required this.message,
  });

  final OperationalExerciseTextGuidanceFailureCode code;
  final String message;

  @override
  Map<String, Object?> toJson() => {
    'status': 'rejected',
    'code': code.wireValue,
    'message': message,
  };
}

/// UI-neutral application query over operational Exercise Knowledge text.
///
/// The repository is caller-supplied. This service performs no persistence,
/// identity inference, relationship traversal, prescription merge, or media
/// projection.
class OperationalExerciseTextGuidanceQueryService {
  const OperationalExerciseTextGuidanceQueryService({
    required this.repository,
    this.validator = const ExerciseMovementContentValidator(),
  });

  final ExerciseKnowledgeRepository repository;
  final ExerciseMovementContentValidator validator;

  OperationalExerciseTextGuidanceQueryResult query(
    String rawCanonicalExerciseId,
  ) {
    final ExerciseId exerciseId;
    try {
      exerciseId = ExerciseId.parse(rawCanonicalExerciseId);
    } on FormatException {
      return const OperationalExerciseTextGuidanceRejected(
        code: OperationalExerciseTextGuidanceFailureCode
            .invalidCanonicalExerciseId,
        message: 'Canonical exercise identity must match EX-<digits>.',
      );
    }

    try {
      final lookup = repository.getDefinition(
        exerciseId,
        visibility: ExerciseKnowledgeVisibility.operational,
      );
      final definition = lookup.definition;
      if (definition == null) {
        return OperationalExerciseTextGuidanceRejected(
          code: OperationalExerciseTextGuidanceFailureCode
              .missingPublishedExerciseDefinition,
          message:
              'No published canonical Exercise Definition exists for '
              '${exerciseId.value}.',
        );
      }
      if (lookup.id != exerciseId ||
          definition.id != exerciseId ||
          definition.lifecycleStatus != ExerciseLifecycleStatus.published) {
        return _invariantViolation;
      }

      final knowledge = repository.operationalMovementKnowledge(exerciseId);
      if (knowledge.exerciseId != exerciseId) {
        return _invariantViolation;
      }

      final standards = knowledge.movementStandards.toList(growable: false)
        ..sort(_compareContent);
      final coaching = knowledge.coachingContents.toList(growable: false)
        ..sort(_compareContent);

      final allRecords = <ExerciseKnowledgeContentRecord>[
        ...standards,
        ...coaching,
      ];
      if (allRecords.any(
        (record) =>
            record.exerciseId != exerciseId ||
            record.lifecycleStatus != ExerciseLifecycleStatus.published,
      )) {
        return _invariantViolation;
      }

      // Publication already validates canonical definition references. Re-run
      // the existing content validator over this text-only projection input.
      // Unknown-definition issues are excluded here because the operational
      // definition was independently resolved above; no VideoReference enters
      // this validation or output boundary.
      final issues = validator
          .validate(
            definitions: const [],
            movementStandards: standards,
            coachingContents: coaching,
            videoReferences: const [],
          )
          .where((issue) => issue.code != 'content_unknown_exercise')
          .toList(growable: false);
      if (issues.isNotEmpty) {
        return _invariantViolation;
      }

      final guidance = OperationalExerciseTextGuidance(
        exerciseId: exerciseId.value,
        canonicalName: definition.canonicalName,
        movementStandards: standards
            .map(OperationalMovementStandardProjection.fromDomain)
            .toList(growable: false),
        coachingContents: coaching
            .map(OperationalCoachingContentProjection.fromDomain)
            .toList(growable: false),
      );
      if (!guidance.hasTextGuidance) {
        return OperationalExerciseTextGuidanceRejected(
          code: OperationalExerciseTextGuidanceFailureCode
              .operationalTextGuidanceUnavailable,
          message:
              'No published operational text guidance exists for '
              '${exerciseId.value}.',
        );
      }
      return OperationalExerciseTextGuidanceResolved(guidance);
    } on Object {
      return _invariantViolation;
    }
  }

  static const _invariantViolation = OperationalExerciseTextGuidanceRejected(
    code: OperationalExerciseTextGuidanceFailureCode
        .contentProjectionInvariantViolation,
    message:
        'Operational text guidance violated the published '
        'Exercise Knowledge contract.',
  );
}

int _compareContent(
  ExerciseKnowledgeContentRecord left,
  ExerciseKnowledgeContentRecord right,
) {
  final byId = left.id.value.compareTo(right.id.value);
  return byId != 0 ? byId : left.version.compareTo(right.version);
}
