import '../models/exercise_catalogue_snapshot.dart';
import '../models/coaching_content.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_definition_lookup.dart';
import '../models/exercise_relationship.dart';
import '../models/knowledge_content_common.dart';
import '../models/movement_standard.dart';
import '../models/video_reference.dart';
import '../ports/exercise_knowledge_repository.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../validation/exercise_knowledge_validator.dart';
import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'exercise_catalogue_snapshot_loader.dart';

/// Founder publication / retirement boundary for Exercise Knowledge.
///
/// Draft → validate → founder publish → immutable published version → retire
/// (historically resolvable). UI is not an authority; [actingOwner] must be
/// `founder` for publish/retire.
///
/// Does not persist to Supabase; operates on the supplied repository port.
class ExerciseKnowledgePublicationService {
  const ExerciseKnowledgePublicationService({
    this.validator = const ExerciseKnowledgeValidator(),
    this.loader = const ExerciseCatalogueSnapshotLoader(),
  });

  final ExerciseKnowledgeValidator validator;
  final ExerciseCatalogueSnapshotLoader loader;

  static const founderOwner = 'founder';

  /// Publish a draft catalogue snapshot into [repository] after validation.
  ///
  /// Fail-closed on validation errors. Draft definitions become published;
  /// already-published identities cannot silently change without an explicit
  /// version bump.
  ExerciseKnowledgePublicationResult publishCatalogue({
    required ExerciseKnowledgeRepository repository,
    required ExerciseCatalogueSnapshot draftSnapshot,
    required String actingOwner,
    KnowledgeActorId? reviewerId,
    DateTime? publishedAt,
  }) {
    if (actingOwner.trim() != founderOwner) {
      return ExerciseKnowledgePublicationResult.rejected([
        ExerciseKnowledgeValidationIssue(
          path: 'owner',
          message: 'Only founder may publish exercise knowledge.',
          code: 'founder_authority_required',
        ),
      ]);
    }

    final load = loader.load(draftSnapshot.toJson());
    if (!load.isValid) {
      return ExerciseKnowledgePublicationResult.rejected(load.issues);
    }

    final at = (publishedAt ?? DateTime.now()).toUtc();
    final existing = {
      for (final d in repository.listDefinitions(
        visibility: ExerciseKnowledgeVisibility.authoring,
      ))
        d.id.value: d,
    };
    final existingSnapshot = repository.authoringSnapshot();

    final publishedDefs = <ExerciseDefinition>[];
    final issues = <ExerciseKnowledgeValidationIssue>[];

    for (final def in draftSnapshot.definitions) {
      if (def.owner.trim() != founderOwner) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'definitions[${def.id.value}].owner',
            message: 'Only founder-owned definitions may be published.',
            code: 'non_founder_definition',
          ),
        );
        continue;
      }

      final prior = existing[def.id.value];
      if (prior != null &&
          prior.lifecycleStatus == ExerciseLifecycleStatus.published) {
        // Identity cannot silently change: same id + same version must match.
        if (prior.version == def.version && !_definitionCoreEqual(prior, def)) {
          issues.add(
            ExerciseKnowledgeValidationIssue(
              path: 'definitions[${def.id.value}]',
              message:
                  'Published identity content cannot change silently; bump version.',
              code: 'silent_published_mutation',
            ),
          );
          continue;
        }
      }

      if (def.lifecycleStatus == ExerciseLifecycleStatus.retired) {
        publishedDefs.add(def);
        continue;
      }

      final transitionIssues = validator.validateLifecycleTransition(
        from: def.lifecycleStatus == ExerciseLifecycleStatus.published
            ? ExerciseLifecycleStatus.published
            : ExerciseLifecycleStatus.draft,
        to: ExerciseLifecycleStatus.published,
        path: 'definitions[${def.id.value}].lifecycle',
      );
      if (transitionIssues.isNotEmpty &&
          def.lifecycleStatus != ExerciseLifecycleStatus.published) {
        issues.addAll(transitionIssues);
        continue;
      }

      publishedDefs.add(
        ExerciseDefinition(
          id: def.id,
          canonicalName: def.canonicalName,
          aliases: def.aliases,
          modality: def.modality,
          familyId: def.familyId,
          movementPatterns: def.movementPatterns,
          laterality: def.laterality,
          technicalComplexity: def.technicalComplexity,
          impactLevel: def.impactLevel,
          validPrescriptionDimensions: def.validPrescriptionDimensions,
          validCompletedPerformanceDimensions:
              def.validCompletedPerformanceDimensions,
          equipment: def.equipment,
          environments: def.environments,
          coachingContentRefs: def.coachingContentRefs,
          mediaRefs: def.mediaRefs,
          movementStandardRefs: def.movementStandardRefs,
          sportStandardRefs: def.sportStandardRefs,
          transitionalAliasIds: def.transitionalAliasIds,
          lifecycleStatus: ExerciseLifecycleStatus.published,
          version: def.version,
          owner: founderOwner,
          publishedAt: def.publishedAt ?? at,
          retiredAt: def.retiredAt,
        ),
      );
    }

    if (issues.isNotEmpty) {
      return ExerciseKnowledgePublicationResult.rejected(issues);
    }

    final publishedStandards = _publishStandards(
      draftSnapshot.movementStandards,
      existingSnapshot.movementStandards,
      reviewerId,
      at,
      issues,
    );
    final publishedCoaching = _publishCoaching(
      draftSnapshot.coachingContents,
      existingSnapshot.coachingContents,
      reviewerId,
      at,
      issues,
    );
    final publishedVideos = _publishVideos(
      draftSnapshot.videoReferences,
      existingSnapshot.videoReferences,
      reviewerId,
      at,
      issues,
    );

    if (issues.isNotEmpty) {
      return ExerciseKnowledgePublicationResult.rejected(issues);
    }

    final publishedRels = draftSnapshot.relationships
        .map((rel) {
          if (rel.lifecycleStatus == ExerciseLifecycleStatus.retired) {
            return rel;
          }
          return ExerciseRelationship(
            id: rel.id,
            sourceExerciseId: rel.sourceExerciseId,
            targetExerciseId: rel.targetExerciseId,
            relationshipType: rel.relationshipType,
            substitutionConstraint: rel.substitutionConstraint,
            comparisonProtocolId: rel.comparisonProtocolId,
            preservesIntentNotes: rel.preservesIntentNotes,
            explanationRefId: rel.explanationRefId,
            lifecycleStatus: ExerciseLifecycleStatus.published,
            version: rel.version,
            owner: founderOwner,
            publishedAt: rel.publishedAt ?? at,
            retiredAt: rel.retiredAt,
          );
        })
        .toList(growable: false);

    final published = ExerciseCatalogueSnapshot(
      catalogueVersion: draftSnapshot.catalogueVersion,
      label: draftSnapshot.label,
      definitions: publishedDefs,
      relationships: publishedRels,
      comparisonProtocols: draftSnapshot.comparisonProtocols,
      movementStandards: publishedStandards,
      coachingContents: publishedCoaching,
      videoReferences: publishedVideos,
    );

    final finalCheck = loader.load(published.toJson());
    if (!finalCheck.isValid) {
      return ExerciseKnowledgePublicationResult.rejected(finalCheck.issues);
    }

    repository.replaceCatalogue(published);
    return ExerciseKnowledgePublicationResult.accepted(published);
  }

  /// Retire a published definition; remains historically resolvable.
  ExerciseKnowledgePublicationResult retireDefinition({
    required ExerciseKnowledgeRepository repository,
    required ExerciseId id,
    required String actingOwner,
    DateTime? retiredAt,
  }) {
    if (actingOwner.trim() != founderOwner) {
      return ExerciseKnowledgePublicationResult.rejected([
        const ExerciseKnowledgeValidationIssue(
          path: 'owner',
          message: 'Only founder may retire exercise knowledge.',
          code: 'founder_authority_required',
        ),
      ]);
    }

    final lookup = repository.getDefinition(
      id,
      visibility: ExerciseKnowledgeVisibility.authoring,
    );
    final def = lookup.definition;
    if (def == null) {
      return ExerciseKnowledgePublicationResult.rejected([
        ExerciseKnowledgeValidationIssue(
          path: 'definitions[${id.value}]',
          message: 'Unknown exercise id.',
          code: 'unknown_exercise',
        ),
      ]);
    }

    final transition = validator.validateLifecycleTransition(
      from: def.lifecycleStatus,
      to: ExerciseLifecycleStatus.retired,
      path: 'definitions[${id.value}].lifecycle',
    );
    if (transition.isNotEmpty) {
      return ExerciseKnowledgePublicationResult.rejected(transition);
    }

    final at = (retiredAt ?? DateTime.now()).toUtc();
    repository.upsertDefinition(
      ExerciseDefinition(
        id: def.id,
        canonicalName: def.canonicalName,
        aliases: def.aliases,
        modality: def.modality,
        familyId: def.familyId,
        movementPatterns: def.movementPatterns,
        laterality: def.laterality,
        technicalComplexity: def.technicalComplexity,
        impactLevel: def.impactLevel,
        validPrescriptionDimensions: def.validPrescriptionDimensions,
        validCompletedPerformanceDimensions:
            def.validCompletedPerformanceDimensions,
        equipment: def.equipment,
        environments: def.environments,
        coachingContentRefs: def.coachingContentRefs,
        mediaRefs: def.mediaRefs,
        movementStandardRefs: def.movementStandardRefs,
        sportStandardRefs: def.sportStandardRefs,
        transitionalAliasIds: def.transitionalAliasIds,
        lifecycleStatus: ExerciseLifecycleStatus.retired,
        version: def.version,
        owner: def.owner,
        publishedAt: def.publishedAt,
        retiredAt: at,
      ),
    );

    return ExerciseKnowledgePublicationResult.accepted(
      repository.authoringSnapshot(),
    );
  }
}

List<MovementStandard> _publishStandards(
  List<MovementStandard> drafts,
  List<MovementStandard> existing,
  KnowledgeActorId? reviewer,
  DateTime at,
  List<ExerciseKnowledgeValidationIssue> issues,
) => _publishContent(
  drafts,
  existing,
  reviewer,
  at,
  issues,
  (record, actor, publishedAt) =>
      record.publish(reviewerId: actor, publishedAt: publishedAt),
);

List<CoachingContent> _publishCoaching(
  List<CoachingContent> drafts,
  List<CoachingContent> existing,
  KnowledgeActorId? reviewer,
  DateTime at,
  List<ExerciseKnowledgeValidationIssue> issues,
) => _publishContent(
  drafts,
  existing,
  reviewer,
  at,
  issues,
  (record, actor, publishedAt) =>
      record.publish(reviewerId: actor, publishedAt: publishedAt),
);

List<VideoReference> _publishVideos(
  List<VideoReference> drafts,
  List<VideoReference> existing,
  KnowledgeActorId? reviewer,
  DateTime at,
  List<ExerciseKnowledgeValidationIssue> issues,
) => _publishContent(
  drafts,
  existing,
  reviewer,
  at,
  issues,
  (record, actor, publishedAt) =>
      record.publish(reviewerId: actor, publishedAt: publishedAt),
);

List<T> _publishContent<T extends ExerciseKnowledgeContentRecord>(
  List<T> drafts,
  List<T> existing,
  KnowledgeActorId? reviewer,
  DateTime at,
  List<ExerciseKnowledgeValidationIssue> issues,
  T Function(T record, KnowledgeActorId reviewer, DateTime at) publish,
) {
  final existingByVersion = {
    for (final record in existing)
      '${record.id.value}:${record.version}': record,
  };
  final result = <T>[];
  for (final record in drafts) {
    final path =
        '${record.contentKind.wireValue}s[${record.id.value}:${record.version}]';
    final prior = existingByVersion['${record.id.value}:${record.version}'];
    if (prior != null &&
        prior.lifecycleStatus == ExerciseLifecycleStatus.published &&
        !_contentCoreEqual(prior, record)) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: path,
          message:
              'Published content cannot change silently; use a new content version.',
          code: 'silent_published_content_mutation',
        ),
      );
      continue;
    }
    if (record.lifecycleStatus == ExerciseLifecycleStatus.retired ||
        record.lifecycleStatus == ExerciseLifecycleStatus.published) {
      result.add(record);
      continue;
    }
    if (reviewer == null) {
      issues.add(
        ExerciseKnowledgeValidationIssue(
          path: '$path.reviewer',
          message: 'Publishing movement content requires an explicit reviewer.',
          code: 'content_reviewer_required',
        ),
      );
      continue;
    }
    result.add(publish(record, reviewer, at));
  }
  return List.unmodifiable(result);
}

class ExerciseKnowledgePublicationResult {
  const ExerciseKnowledgePublicationResult._({
    required this.isAccepted,
    this.snapshot,
    this.issues = const [],
  });

  factory ExerciseKnowledgePublicationResult.accepted(
    ExerciseCatalogueSnapshot snapshot,
  ) => ExerciseKnowledgePublicationResult._(
    isAccepted: true,
    snapshot: snapshot,
  );

  factory ExerciseKnowledgePublicationResult.rejected(
    List<ExerciseKnowledgeValidationIssue> issues,
  ) => ExerciseKnowledgePublicationResult._(isAccepted: false, issues: issues);

  final bool isAccepted;
  final ExerciseCatalogueSnapshot? snapshot;
  final List<ExerciseKnowledgeValidationIssue> issues;
}

bool _definitionCoreEqual(ExerciseDefinition a, ExerciseDefinition b) {
  // Compare serialized knowledge facts excluding lifecycle timestamps.
  final aj = Map<String, Object?>.from(a.toJson())
    ..remove('published_at')
    ..remove('retired_at')
    ..remove('lifecycle_status');
  final bj = Map<String, Object?>.from(b.toJson())
    ..remove('published_at')
    ..remove('retired_at')
    ..remove('lifecycle_status');
  return aj.toString() == bj.toString();
}

bool _contentCoreEqual(
  ExerciseKnowledgeContentRecord a,
  ExerciseKnowledgeContentRecord b,
) {
  final aj = Map<String, Object?>.from(a.toJson())
    ..remove('reviewer')
    ..remove('reviewed_at')
    ..remove('published_at')
    ..remove('lifecycle_status');
  final bj = Map<String, Object?>.from(b.toJson())
    ..remove('reviewer')
    ..remove('reviewed_at')
    ..remove('published_at')
    ..remove('lifecycle_status');
  return aj.toString() == bj.toString();
}
