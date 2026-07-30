import '../../athlete_profile/services/athlete_planning_input_builder.dart';
import '../../session/models/prepared_execution_package.dart';
import '../../workout_player/services/coach_brain_workout_plan_service.dart';
import '../models/plan_assignment.dart';
import '../models/plan_definition.dart';
import '../models/programmed_session_key.dart';

/// Resolves coach-authored programmed sessions for a Plan version cursor.
///
/// Uses plan-canonical inputs so athlete history / previous performance cannot
/// alter programmed structure. Results are cached by [ProgrammedSessionKey].
class ProgrammedSessionResolver {
  ProgrammedSessionResolver({
    CoachBrainWorkoutPlanService? planService,
    AthletePlanningInputBuilder inputBuilder =
        const AthletePlanningInputBuilder(),
  }) : _planService = planService ?? CoachBrainWorkoutPlanService(),
       _inputBuilder = inputBuilder;

  final CoachBrainWorkoutPlanService _planService;
  final AthletePlanningInputBuilder _inputBuilder;

  static final Map<String, PreparedExecutionPackage> _cache = {};

  /// Test helper — clears in-process programmed cache.
  static void clearCacheForTests() => _cache.clear();

  Future<PreparedExecutionPackage> resolve({
    required PlanDefinition plan,
    required PlanAssignment assignment,
    DateTime? preparedAt,
  }) async {
    final key = ProgrammedSessionKey.fromPlan(
      plan: plan,
      assignment: assignment,
    );
    final ontologyVersion = await _planService.ontologyVersion;
    final cacheKey = '${key.value}|onto:$ontologyVersion';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final input = _inputBuilder.buildPlanCanonical(
      plan: plan,
      assignment: assignment,
      knowledgeOntologyVersion: ontologyVersion,
    );
    final bundle = await _planService.resolveFromPlanningInput(
      input: input,
      availableEquipmentIds: input.equipmentContext?.availableEquipmentIds,
      environmentId: input.environmentContext?.environmentId,
    );

    final package = PreparedExecutionPackage(
      programmedSessionKey: key,
      plan: bundle.plan,
      brief: bundle.brief,
      preparedAt: preparedAt ?? DateTime.now().toUtc(),
      planId: plan.planId,
      planVersion: plan.version,
      assignmentId: assignment.assignmentId,
      coachBrainPlan: bundle,
    );
    _cache[cacheKey] = package;
    return package;
  }

  /// Whether two resolve calls for the same key share structure identity.
  static bool sameProgrammedStructure(
    PreparedExecutionPackage a,
    PreparedExecutionPackage b,
  ) {
    if (a.programmedSessionKey != b.programmedSessionKey) return false;
    if (a.plan.blocks.length != b.plan.blocks.length) return false;
    for (var i = 0; i < a.plan.blocks.length; i++) {
      final ba = a.plan.blocks[i];
      final bb = b.plan.blocks[i];
      if (ba.linkedExercises.length != bb.linkedExercises.length) return false;
      for (var j = 0; j < ba.linkedExercises.length; j++) {
        if (ba.linkedExercises[j].exerciseId !=
            bb.linkedExercises[j].exerciseId) {
          return false;
        }
        final pa = ba.linkedExercises[j].prescription;
        final pb = bb.linkedExercises[j].prescription;
        if (pa?.sets != pb?.sets) return false;
        if (pa?.reps.toLegacyMetadataValue() !=
            pb?.reps.toLegacyMetadataValue()) {
          return false;
        }
      }
    }
    return true;
  }
}
