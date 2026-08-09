import '../models/exercise_identity_mapping.dart';
import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';

/// Founder-approved Phase 3.1F Part 2 transitional → canonical identity mappings.
///
/// Explicit authored records only. Does **not** grant substitution or
/// comparability. Not wired into live consumers in this sprint.
///
/// Provenance: Lee Webber approval of Phase 3.1F Part 1b matrix
/// (Batch A, F-01 A, F-02, F-03, five new canonicals EX-128–EX-132).
class FounderApprovedIdentityMappingsPhase31F {
  FounderApprovedIdentityMappingsPhase31F._();

  static const approvalProvenance =
      'Founder-approved Phase 3.1F Part 2 identity mapping '
      '(Lee Webber decision record). Mapping establishes identity resolution '
      'only; does not grant substitution or comparability.';

  static final publishedAt = DateTime.utc(2026, 8, 9);

  /// Canonical ids required for these mappings (Batch A + F-02/F-03 + new).
  static final Set<String> knownCanonicalIds = {
    for (final m in allMappings) m.canonicalId.value,
  };

  /// New catalogue ids authored in
  /// `supabase/migrations/20260809160000_founder_exercise_library_phase_3_1f_part2.sql`.
  static const newCanonicalIds = <String>{
    'EX-128',
    'EX-129',
    'EX-130',
    'EX-131',
    'EX-132',
  };

  static const newCanonicalNames = <String, String>{
    'EX-128': 'Lat Pulldown',
    'EX-129': 'Running',
    'EX-130': 'Burpee Broad Jump',
    'EX-131': 'Sled Push',
    'EX-132': 'Sled Pull',
  };

  /// Exact Batch A + approved F-02/F-03 + new-id mappings (21).
  static final List<ExerciseIdentityMapping> allMappings = [
    _map('back_squat', 'EX-073'),
    _map('front_squat', 'EX-074'),
    _map('goblet_squat', 'EX-030'),
    _map('romanian_deadlift', 'EX-078'),
    _map('walking_lunge', 'EX-025'),
    _map('pull_up', 'EX-053'),
    _map('lat_pulldown', 'EX-128'),
    _map('bench_press', 'EX-083'),
    _map('strict_press', 'EX-088'),
    _map('push_up', 'EX-012'),
    _map(
      'running',
      'EX-129',
      notes:
          'Generic Running (F-01 A). Not Easy/Threshold/Sprint. '
          'Outdoor/treadmill are context; comparability remains protocol-governed.',
    ),
    _map('rowing', 'EX-049'),
    _map(
      'ski_erg',
      'EX-050',
      notes:
          'F-02: EX-050 is SkiErg device/exercise identity. Banded ski-pattern '
          'work is a different identity and must not share performance history.',
    ),
    _map(
      'burpee_broad_jump',
      'EX-130',
      notes:
          'Combined Burpee Broad Jump. Distinct from EX-009 Burpee and '
          'EX-024 Broad Jump.',
    ),
    _map(
      'sled_push',
      'EX-131',
      notes: 'Distinct from Sled Pull (EX-132).',
    ),
    _map(
      'sled_pull',
      'EX-132',
      notes: 'Distinct from Sled Push (EX-131).',
    ),
    _map('farmer_carry', 'EX-101'),
    _map(
      'wall_ball',
      'EX-052',
      notes:
          'F-03: one Wall Ball identity. Load, target height, sex/category and '
          'HYROX rules remain prescription/standard/protocol layers.',
    ),
    _map('plank', 'EX-021'),
    _map('dead_bug', 'EX-022'),
    _map('box_jump', 'EX-059'),
  ];

  static ExerciseIdentityMapping _map(
    String shortId,
    String canonicalEx, {
    String? notes,
  }) {
    return ExerciseIdentityMapping(
      id: 'map.$shortId.${canonicalEx.toLowerCase()}',
      transitionalId: TransitionalExerciseId.parse('cohort.exercise.$shortId'),
      canonicalId: ExerciseId.parse(canonicalEx),
      lifecycleStatus: ExerciseLifecycleStatus.published,
      version: '1',
      provenance: approvalProvenance,
      owner: 'founder',
      notes: notes,
      publishedAt: publishedAt,
    );
  }
}
