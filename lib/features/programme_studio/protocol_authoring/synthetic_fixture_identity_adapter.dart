import 'package:founder_importer/features/founder_programme_import/founder_programme_identity_resolution.dart';

import '../../../domain/exercise_knowledge/models/transitional_identity_resolution.dart';
import '../../../domain/exercise_knowledge/ports/transitional_exercise_id_bridge.dart';
import '../../../domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';

/// Flutter-local port adapter. The existing tool-only adapter is outside lib
/// and cannot be imported by a Flutter package URI. Conformance is tested
/// against that unchanged adapter; all identity authority stays in the bridge.
class SyntheticFixtureIdentityAdapter
    implements FounderProgrammeTransitionalIdentityResolver {
  const SyntheticFixtureIdentityAdapter(this.bridge);
  final TransitionalExerciseIdBridge bridge;
  @override
  FounderProgrammeTransitionalResolution resolve(String reference) {
    final operational = bridge.resolve(reference);
    if (operational is TransitionalIdentityResolved) {
      return _resolved(operational);
    }
    if (operational is TransitionalIdentityInvalid) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.invalid,
      );
    }
    if (operational is TransitionalIdentityConflict) {
      return _conflict(operational);
    }
    final historical = bridge.resolve(reference, includeHistorical: true);
    if (historical is TransitionalIdentityResolved &&
        historical.mapping.lifecycleStatus == ExerciseLifecycleStatus.retired) {
      return FounderProgrammeTransitionalResolution(
        kind: FounderProgrammeTransitionalResolutionKind.retired,
        canonicalId: historical.canonicalId.value,
      );
    }
    if (historical is TransitionalIdentityConflict) {
      return _conflict(historical);
    }
    return FounderProgrammeTransitionalResolution(
      kind: FounderProgrammeTransitionalResolutionKind.unmapped,
    );
  }

  FounderProgrammeTransitionalResolution _resolved(
    TransitionalIdentityResolved result,
  ) => FounderProgrammeTransitionalResolution(
    kind: FounderProgrammeTransitionalResolutionKind.resolved,
    canonicalId: result.canonicalId.value,
  );
  FounderProgrammeTransitionalResolution _conflict(
    TransitionalIdentityConflict result,
  ) => FounderProgrammeTransitionalResolution(
    kind: FounderProgrammeTransitionalResolutionKind.conflict,
    canonicalCandidates: result.canonicalCandidates
        .map((id) => id.value)
        .toList(growable: false),
  );
}
