import '../models/exercise_identity_mapping.dart';
import '../ports/transitional_exercise_id_bridge.dart';
import '../validation/exercise_identity_mapping_validator.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../vocabulary/exercise_lifecycle_status.dart';

/// Founder publication / retirement for identity mappings.
///
/// Draft → validate → founder publish → retire (historically resolvable).
/// Does not rewrite completion evidence or programme prescriptions.
class ExerciseIdentityMappingPublicationService {
  const ExerciseIdentityMappingPublicationService({
    this.validator = const ExerciseIdentityMappingValidator(),
  });

  final ExerciseIdentityMappingValidator validator;

  static const founderOwner = 'founder';

  ExerciseIdentityMappingPublicationResult publishMappings({
    required TransitionalExerciseIdBridge bridge,
    required List<ExerciseIdentityMapping> draftMappings,
    required Set<String> knownCanonicalIds,
    required String actingOwner,
    DateTime? publishedAt,
  }) {
    if (actingOwner.trim() != founderOwner) {
      return ExerciseIdentityMappingPublicationResult.rejected([
        const ExerciseKnowledgeValidationIssue(
          path: 'owner',
          message: 'Only founder may publish identity mappings.',
          code: 'founder_authority_required',
        ),
      ]);
    }

    final at = (publishedAt ?? DateTime.now()).toUtc();
    final published = <ExerciseIdentityMapping>[];
    for (final mapping in draftMappings) {
      if (mapping.lifecycleStatus == ExerciseLifecycleStatus.retired) {
        published.add(mapping);
        continue;
      }
      published.add(
        ExerciseIdentityMapping(
          id: mapping.id,
          transitionalId: mapping.transitionalId,
          canonicalId: mapping.canonicalId,
          lifecycleStatus: ExerciseLifecycleStatus.published,
          version: mapping.version,
          provenance: mapping.provenance,
          owner: founderOwner,
          notes: mapping.notes,
          publishedAt: mapping.publishedAt ?? at,
          retiredAt: mapping.retiredAt,
        ),
      );
    }

    final issues = validator.validateCatalogue(
      mappings: published,
      knownCanonicalIds: knownCanonicalIds,
    );
    if (issues.isNotEmpty) {
      return ExerciseIdentityMappingPublicationResult.rejected(issues);
    }

    bridge.replaceMappings(published);
    return ExerciseIdentityMappingPublicationResult.accepted(published);
  }

  ExerciseIdentityMappingPublicationResult retireMapping({
    required TransitionalExerciseIdBridge bridge,
    required String mappingId,
    required String actingOwner,
    DateTime? retiredAt,
  }) {
    if (actingOwner.trim() != founderOwner) {
      return ExerciseIdentityMappingPublicationResult.rejected([
        const ExerciseKnowledgeValidationIssue(
          path: 'owner',
          message: 'Only founder may retire identity mappings.',
          code: 'founder_authority_required',
        ),
      ]);
    }

    final existing = bridge.listMappings(includeHistorical: true).where(
          (m) => m.id == mappingId,
        );
    if (existing.isEmpty) {
      return ExerciseIdentityMappingPublicationResult.rejected([
        ExerciseKnowledgeValidationIssue(
          path: 'identity_mappings[$mappingId]',
          message: 'Unknown mapping id.',
          code: 'unknown_mapping',
        ),
      ]);
    }
    final mapping = existing.first;
    final transitionOk = mapping.lifecycleStatus.canTransitionTo(
      ExerciseLifecycleStatus.retired,
    );
    if (!transitionOk) {
      return ExerciseIdentityMappingPublicationResult.rejected([
        ExerciseKnowledgeValidationIssue(
          path: 'identity_mappings[$mappingId].lifecycle',
          message: 'Invalid lifecycle transition to retired.',
          code: 'invalid_lifecycle_transition',
        ),
      ]);
    }

    final at = (retiredAt ?? DateTime.now()).toUtc();
    bridge.upsertMapping(
      ExerciseIdentityMapping(
        id: mapping.id,
        transitionalId: mapping.transitionalId,
        canonicalId: mapping.canonicalId,
        lifecycleStatus: ExerciseLifecycleStatus.retired,
        version: mapping.version,
        provenance: mapping.provenance,
        owner: mapping.owner,
        notes: mapping.notes,
        publishedAt: mapping.publishedAt,
        retiredAt: at,
      ),
    );
    return ExerciseIdentityMappingPublicationResult.accepted(
      bridge.listMappings(includeHistorical: true),
    );
  }
}

class ExerciseIdentityMappingPublicationResult {
  const ExerciseIdentityMappingPublicationResult._({
    required this.isAccepted,
    this.mappings = const [],
    this.issues = const [],
  });

  factory ExerciseIdentityMappingPublicationResult.accepted(
    List<ExerciseIdentityMapping> mappings,
  ) =>
      ExerciseIdentityMappingPublicationResult._(
        isAccepted: true,
        mappings: mappings,
      );

  factory ExerciseIdentityMappingPublicationResult.rejected(
    List<ExerciseKnowledgeValidationIssue> issues,
  ) =>
      ExerciseIdentityMappingPublicationResult._(
        isAccepted: false,
        issues: issues,
      );

  final bool isAccepted;
  final List<ExerciseIdentityMapping> mappings;
  final List<ExerciseKnowledgeValidationIssue> issues;
}
