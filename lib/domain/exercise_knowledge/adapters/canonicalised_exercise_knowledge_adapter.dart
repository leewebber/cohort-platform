import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';

import '../models/transitional_identity_resolution.dart';
import '../ports/transitional_exercise_id_bridge.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../value_objects/exercise_id.dart';

/// Exposes existing transitional [ExerciseKnowledge] facts under canonical
/// `EX-*` identity via the explicit bridge.
///
/// Does not duplicate definitions into a second authority. Does not copy
/// programme prescription or athlete evidence. Unmapped/conflicting entries
/// are quarantined with structured issues — never silently discarded.
class CanonicalisedExerciseKnowledgeAdapter {
  const CanonicalisedExerciseKnowledgeAdapter({required this.bridge});

  final TransitionalExerciseIdBridge bridge;

  /// Resolve one ontology exercise through the bridge.
  CanonicalisedExerciseKnowledgeResult canonicalise(
    ExerciseKnowledge knowledge,
  ) {
    final resolution = bridge.resolve(knowledge.id);
    return switch (resolution) {
      TransitionalIdentityResolved(:final canonicalId, :final mapping) =>
        CanonicalisedExerciseKnowledgeResult.resolved(
          CanonicalisedExerciseKnowledgeView(
            canonicalId: canonicalId,
            transitionalId: knowledge.id,
            knowledge: knowledge,
            mappingId: mapping.id,
            mappingProvenance: mapping.provenance,
          ),
        ),
      TransitionalIdentityUnmapped() =>
        CanonicalisedExerciseKnowledgeResult.quarantined(
          transitionalId: knowledge.id,
          knowledge: knowledge,
          issues: [
            ExerciseKnowledgeValidationIssue(
              path: 'exercises[${knowledge.id}]',
              message:
                  'No published identity mapping to a canonical EX-* id.',
              code: 'unmapped_transitional_exercise',
            ),
          ],
        ),
      TransitionalIdentityConflict(:final canonicalCandidates) =>
        CanonicalisedExerciseKnowledgeResult.quarantined(
          transitionalId: knowledge.id,
          knowledge: knowledge,
          issues: [
            ExerciseKnowledgeValidationIssue(
              path: 'exercises[${knowledge.id}]',
              message:
                  'Conflicting canonical targets: '
                  '${canonicalCandidates.map((e) => e.value).join(', ')}',
              code: 'conflicting_identity_mapping',
            ),
          ],
        ),
      TransitionalIdentityInvalid(:final message) =>
        CanonicalisedExerciseKnowledgeResult.quarantined(
          transitionalId: knowledge.id,
          knowledge: knowledge,
          issues: [
            ExerciseKnowledgeValidationIssue(
              path: 'exercises[${knowledge.id}]',
              message: message ?? 'Invalid transitional exercise id.',
              code: 'invalid_transitional_exercise',
            ),
          ],
        ),
    };
  }

  /// Partition a catalogue into resolved views and quarantined leftovers.
  CanonicalisedExerciseKnowledgeBatch canonicaliseAll(
    Iterable<ExerciseKnowledge> knowledgeEntries,
  ) {
    final resolved = <CanonicalisedExerciseKnowledgeView>[];
    final quarantined = <QuarantinedExerciseKnowledge>[];
    for (final entry in knowledgeEntries) {
      final result = canonicalise(entry);
      switch (result) {
        case CanonicalisedExerciseKnowledgeResolved(:final view):
          resolved.add(view);
        case CanonicalisedExerciseKnowledgeQuarantined(
            :final transitionalId,
            :final knowledge,
            :final issues,
          ):
          quarantined.add(
            QuarantinedExerciseKnowledge(
              transitionalId: transitionalId,
              knowledge: knowledge,
              issues: issues,
            ),
          );
      }
    }
    resolved.sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
    quarantined.sort((a, b) => a.transitionalId.compareTo(b.transitionalId));
    return CanonicalisedExerciseKnowledgeBatch(
      resolved: List.unmodifiable(resolved),
      quarantined: List.unmodifiable(quarantined),
    );
  }
}

/// Canonical view over an existing transitional knowledge record.
class CanonicalisedExerciseKnowledgeView {
  const CanonicalisedExerciseKnowledgeView({
    required this.canonicalId,
    required this.transitionalId,
    required this.knowledge,
    required this.mappingId,
    required this.mappingProvenance,
  });

  final ExerciseId canonicalId;
  final String transitionalId;
  final ExerciseKnowledge knowledge;
  final String mappingId;
  final String mappingProvenance;

  /// Mapping never implies comparison compatibility.
  bool get grantsComparability => false;

  /// Mapping never implies substitution permission.
  bool get grantsSubstitutionPermission => false;
}

sealed class CanonicalisedExerciseKnowledgeResult {
  const CanonicalisedExerciseKnowledgeResult();

  factory CanonicalisedExerciseKnowledgeResult.resolved(
    CanonicalisedExerciseKnowledgeView view,
  ) = CanonicalisedExerciseKnowledgeResolved;

  factory CanonicalisedExerciseKnowledgeResult.quarantined({
    required String transitionalId,
    required ExerciseKnowledge knowledge,
    required List<ExerciseKnowledgeValidationIssue> issues,
  }) = CanonicalisedExerciseKnowledgeQuarantined;
}

class CanonicalisedExerciseKnowledgeResolved
    extends CanonicalisedExerciseKnowledgeResult {
  const CanonicalisedExerciseKnowledgeResolved(this.view);

  final CanonicalisedExerciseKnowledgeView view;
}

class CanonicalisedExerciseKnowledgeQuarantined
    extends CanonicalisedExerciseKnowledgeResult {
  const CanonicalisedExerciseKnowledgeQuarantined({
    required this.transitionalId,
    required this.knowledge,
    required this.issues,
  });

  final String transitionalId;
  final ExerciseKnowledge knowledge;
  final List<ExerciseKnowledgeValidationIssue> issues;
}

class QuarantinedExerciseKnowledge {
  const QuarantinedExerciseKnowledge({
    required this.transitionalId,
    required this.knowledge,
    required this.issues,
  });

  final String transitionalId;
  final ExerciseKnowledge knowledge;
  final List<ExerciseKnowledgeValidationIssue> issues;
}

class CanonicalisedExerciseKnowledgeBatch {
  const CanonicalisedExerciseKnowledgeBatch({
    required this.resolved,
    required this.quarantined,
  });

  final List<CanonicalisedExerciseKnowledgeView> resolved;
  final List<QuarantinedExerciseKnowledge> quarantined;

  bool get hasQuarantine => quarantined.isNotEmpty;
}
