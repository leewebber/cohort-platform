import 'package:cohort_platform/domain/exercise_knowledge/models/transitional_identity_resolution.dart';
import 'package:cohort_platform/domain/exercise_knowledge/ports/transitional_exercise_id_bridge.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_identity_resolution.dart';

/// Repository-level adapter from the pure importer port to Cohort's bridge.
///
/// This adapter consumes identity contracts only. It does not read Exercise
/// Knowledge content or publish mappings.
class RepositoryTransitionalIdentityAdapter
    implements FounderProgrammeTransitionalIdentityResolver {
  const RepositoryTransitionalIdentityAdapter(this._bridge);

  final TransitionalExerciseIdBridge _bridge;

  @override
  FounderProgrammeTransitionalResolution resolve(String rawReference) {
    final operational = _bridge.resolve(rawReference);
    if (operational is TransitionalIdentityResolved) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.resolved,
        canonicalId: operational.canonicalId.value,
      );
    }
    if (operational is TransitionalIdentityInvalid) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.invalid,
      );
    }
    if (operational is TransitionalIdentityConflict) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.conflict,
        canonicalCandidates: operational.canonicalCandidates
            .map((candidate) => candidate.value)
            .toList(growable: false),
      );
    }

    final historical = _bridge.resolve(rawReference, includeHistorical: true);
    if (historical is TransitionalIdentityResolved &&
        historical.mapping.lifecycleStatus == ExerciseLifecycleStatus.retired) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.retired,
        canonicalId: historical.canonicalId.value,
      );
    }
    if (historical is TransitionalIdentityConflict) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.conflict,
        canonicalCandidates: historical.canonicalCandidates
            .map((candidate) => candidate.value)
            .toList(growable: false),
      );
    }
    return FounderProgrammeTransitionalResolution(
      kind: FounderProgrammeTransitionalResolutionKind.unmapped,
    );
  }
}
