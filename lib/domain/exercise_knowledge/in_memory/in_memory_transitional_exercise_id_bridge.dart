import '../models/exercise_identity_mapping.dart';
import '../models/transitional_identity_resolution.dart';
import '../ports/transitional_exercise_id_bridge.dart';
import '../validation/exercise_identity_mapping_validator.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';

/// Deterministic in-memory bridge for tests and local verification.
///
/// Not production persistence. No Supabase / hosted access.
class InMemoryTransitionalExerciseIdBridge
    implements TransitionalExerciseIdBridge {
  InMemoryTransitionalExerciseIdBridge({
    Iterable<ExerciseIdentityMapping>? initial,
    this.validator = const ExerciseIdentityMappingValidator(),
  }) {
    if (initial != null) replaceMappings(initial);
  }

  final ExerciseIdentityMappingValidator validator;
  final Map<String, ExerciseIdentityMapping> _byRecordId = {};

  @override
  void replaceMappings(Iterable<ExerciseIdentityMapping> mappings) {
    _byRecordId.clear();
    for (final mapping in mappings) {
      _byRecordId[mapping.id] = mapping;
    }
  }

  @override
  void upsertMapping(ExerciseIdentityMapping mapping) {
    _byRecordId[mapping.id] = mapping;
  }

  @override
  List<ExerciseIdentityMapping> listMappings({bool includeHistorical = true}) {
    final out = _byRecordId.values.where((m) {
      // Authoring/audit includes draft; operational listing is published only.
      if (includeHistorical) return true;
      return m.isOperational;
    }).toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  @override
  ExerciseId? toCanonical(String transitionalKnowledgeId) {
    final result = resolve(transitionalKnowledgeId);
    return result is TransitionalIdentityResolved ? result.canonicalId : null;
  }

  @override
  TransitionalIdentityResolution resolve(
    String transitionalKnowledgeId, {
    bool includeHistorical = false,
  }) {
    final parsed = TransitionalExerciseId.tryParse(transitionalKnowledgeId);
    if (parsed == null) {
      return TransitionalIdentityInvalid(
        transitionalKnowledgeId,
        message: 'Not a valid cohort.exercise.* transitional id.',
      );
    }
    return resolveTyped(parsed, includeHistorical: includeHistorical);
  }

  @override
  TransitionalIdentityResolution resolveTyped(
    TransitionalExerciseId transitionalId, {
    bool includeHistorical = false,
  }) {
    final candidates = _byRecordId.values.where((m) {
      if (m.transitionalId != transitionalId) return false;
      if (includeHistorical) {
        return m.isHistoricallyResolvable;
      }
      return m.isOperational;
    }).toList(growable: false);

    if (candidates.isEmpty) {
      return TransitionalIdentityUnmapped(transitionalId);
    }

    final targets = candidates.map((m) => m.canonicalId).toSet();
    if (targets.length > 1) {
      final sorted = targets.toList()..sort();
      return TransitionalIdentityConflict(
        transitionalId: transitionalId,
        canonicalCandidates: List.unmodifiable(sorted),
        message: 'Conflicting canonical targets for ${transitionalId.value}.',
      );
    }

    // Prefer published over retired when historical includes both.
    candidates.sort((a, b) {
      final rank = (ExerciseLifecycleStatus s) => switch (s) {
            ExerciseLifecycleStatus.published => 0,
            ExerciseLifecycleStatus.retired => 1,
            ExerciseLifecycleStatus.draft => 2,
          };
      final byStatus =
          rank(a.lifecycleStatus).compareTo(rank(b.lifecycleStatus));
      if (byStatus != 0) return byStatus;
      return a.id.compareTo(b.id);
    });

    final chosen = candidates.first;
    return TransitionalIdentityResolved(
      transitionalId: transitionalId,
      canonicalId: chosen.canonicalId,
      mapping: chosen,
    );
  }

  @override
  List<ExerciseKnowledgeValidationIssue> validate({
    required Set<String> knownCanonicalIds,
  }) {
    return validator.validateCatalogue(
      mappings: listMappings(includeHistorical: true),
      knownCanonicalIds: knownCanonicalIds,
    );
  }
}
