import 'dart:io';

import 'package:flutter/services.dart';

import '../../../knowledge/gap_analysis/capability_gap_analysis_service.dart';
import '../../../knowledge/io/yaml_knowledge_ontology_loader.dart';
import '../../../knowledge/read/in_memory_knowledge_graph_reader.dart';
import '../../../knowledge/training_intent/training_intent_from_gaps_service.dart';
import '../../../planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import '../../../planning/models/planning_input.dart';
import '../../../planning/orchestration/coach_brain_service.dart';
import '../../../planning/orchestration/models/coach_brain_orchestration_request.dart';
import '../../../planning/orchestration/models/planning_context.dart';
import '../../../planning/planning_engine_service.dart';
import '../../../planning/prescription/deterministic_prescription_engine.dart';
import '../../../planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import '../../../planning/session_blueprint/models/session_blueprint.dart';
import '../../athlete_profile/models/athlete_profile.dart';
import '../../athlete_profile/services/athlete_planning_input_builder.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../plans/models/plan.dart';
import '../../plans/models/plan_assignment.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/workout_session_brief.dart';
import 'workout_plan_from_planning_context.dart';

/// Resolved athlete workout for the Workout Player (engine output only).
class CoachBrainWorkoutPlan {
  const CoachBrainWorkoutPlan({
    required this.planningContext,
    required this.plan,
    required this.brief,
  });

  final PlanningContext planningContext;
  final SessionExecutionPlan plan;
  final WorkoutSessionBrief brief;
}

/// Resolves today's [SessionExecutionPlan] via Coach Brain (no engine changes).
///
/// Prefer [AthleteProfile] / [PlanningInput]. Reference scenarios are not used.
class CoachBrainWorkoutPlanService {
  CoachBrainWorkoutPlanService({
    CoachBrainService? coachBrain,
    String? knowledgeRoot,
    WorkoutPlanFromPlanningContext projector =
        const WorkoutPlanFromPlanningContext(),
    AthletePlanningInputBuilder inputBuilder =
        const AthletePlanningInputBuilder(),
  }) : _injectedBrain = coachBrain,
       _forcedKnowledgeRoot = knowledgeRoot,
       _projector = projector,
       _inputBuilder = inputBuilder;

  final CoachBrainService? _injectedBrain;
  final String? _forcedKnowledgeRoot;
  final WorkoutPlanFromPlanningContext _projector;
  final AthletePlanningInputBuilder _inputBuilder;

  CoachBrainService? _cachedBrain;
  InMemoryKnowledgeGraphReader? _cachedKnowledge;
  String? _knowledgeRoot;

  Future<String> get ontologyVersion async {
    await _ensureBrain();
    return _cachedKnowledge!.ontologyVersion;
  }

  /// Primary path: athlete profile (+ optional active plan) → PlanningInput → Coach Brain.
  Future<CoachBrainWorkoutPlan> resolveFromProfile({
    required AthleteProfile profile,
    Plan? activePlan,
    PlanAssignment? assignment,
    DateTime? asOf,
  }) async {
    await _ensureBrain();
    final input = _inputBuilder.build(
      profile: profile,
      knowledgeOntologyVersion: _cachedKnowledge!.ontologyVersion,
      activePlan: activePlan ?? AthleteProfileSession.activePlan,
      assignment: assignment ?? AthleteProfileSession.activeAssignment,
      asOf: asOf,
    );
    return resolveFromPlanningInput(
      input: input,
      availableEquipmentIds: profile.availableEquipment,
      environmentId: profile.environmentId,
    );
  }

  /// Direct PlanningInput path (tests / advanced callers).
  Future<CoachBrainWorkoutPlan> resolveFromPlanningInput({
    required PlanningInput input,
    List<String>? availableEquipmentIds,
    String? environmentId,
  }) async {
    final brain = await _ensureBrain();
    final equipment =
        availableEquipmentIds ??
        input.equipmentContext?.availableEquipmentIds ??
        const <String>[];

    final context = brain.run(
      CoachBrainOrchestrationRequest(
        planningInput: input,
        blueprintContext: SessionBlueprintGenerationContext(
          equipmentContext: input.equipmentContext,
          environmentContext: input.environmentContext,
          recoverySummary: input.recoverySummary,
        ),
        availableEquipmentIds: equipment,
        environmentId:
            environmentId ?? input.environmentContext?.environmentId,
      ),
    );

    return _requirePlan(context);
  }

  /// Resolves today's plan from the bound athlete session, if present.
  Future<CoachBrainWorkoutPlan> resolveTodayPlan({
    required String athleteId,
    DateTime? asOf,
    List<String>? availableEquipmentIds,
    String? environmentId,
  }) async {
    final cached = AthleteProfileSession.programme;
    final profile = AthleteProfileSession.profile;
    if (cached != null &&
        profile != null &&
        profile.athleteId == athleteId &&
        cached.planBundle.plan.blocks.isNotEmpty) {
      return cached.planBundle;
    }

    if (profile != null && profile.athleteId == athleteId) {
      return resolveFromProfile(profile: profile, asOf: asOf);
    }

    throw CoachBrainWorkoutPlanException(
      'No AthleteProfile for $athleteId. Complete athlete onboarding first.',
    );
  }

  CoachBrainWorkoutPlan _requirePlan(PlanningContext context) {
    final plan = _projector.planFrom(context);
    if (plan == null || plan.blocks.isEmpty) {
      throw CoachBrainWorkoutPlanException(
        'Coach Brain did not produce a SessionExecutionPlan '
        '(status=${context.orchestrationStatus.name}).',
      );
    }
    return CoachBrainWorkoutPlan(
      planningContext: context,
      plan: plan,
      brief: _projector.briefFrom(context),
    );
  }

  Future<CoachBrainService> _ensureBrain() async {
    if (_injectedBrain != null) {
      if (_knowledgeRoot == null) {
        final root = _forcedKnowledgeRoot ?? await resolveKnowledgeRoot();
        _knowledgeRoot = root;
        if (_cachedKnowledge == null) {
          final bundle = await const YamlKnowledgeOntologyLoader()
              .loadFromDirectory(root);
          _cachedKnowledge = InMemoryKnowledgeGraphReader(bundle);
        }
      }
      return _injectedBrain;
    }
    if (_cachedBrain != null) return _cachedBrain!;

    final root = _forcedKnowledgeRoot ?? await resolveKnowledgeRoot();
    _knowledgeRoot = root;
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      root,
    );
    final knowledge = InMemoryKnowledgeGraphReader(bundle);
    _cachedKnowledge = knowledge;
    _cachedBrain = CoachBrainService(
      planningEngine: PlanningEngineService(
        knowledge: knowledge,
        gapAnalysis: CapabilityGapAnalysisService(knowledge),
        intentResolution: TrainingIntentFromGapsService(knowledge),
      ),
      blueprintGenerator: DeterministicSessionBlueprintGenerator(
        knowledge: knowledge,
      ),
      exercisePolicy: DeterministicExercisePolicyEngine(knowledge: knowledge),
      prescriptionEngine: DeterministicPrescriptionEngine(knowledge: knowledge),
    );
    return _cachedBrain!;
  }

  static Future<String> resolveKnowledgeRoot() async {
    final fromDisk = _findKnowledgeRootOnDisk(Directory.current);
    if (fromDisk != null) return fromDisk;
    return _materializeKnowledgeAssets();
  }

  static String? _findKnowledgeRootOnDisk(Directory start) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      final manifest = File('${dir.path}/knowledge/manifest.yaml');
      if (manifest.existsSync()) return '${dir.path}/knowledge';
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
    return null;
  }

  static Future<String> _materializeKnowledgeAssets() async {
    final temp = await Directory.systemTemp.createTemp('cohort_knowledge_');
    for (final asset in _knowledgeAssetFiles) {
      final data = await rootBundle.loadString(asset);
      final relative = asset.substring('knowledge/'.length);
      final out = File('${temp.path}/$relative');
      await out.parent.create(recursive: true);
      await out.writeAsString(data);
    }
    return temp.path;
  }
}

class CoachBrainWorkoutPlanException implements Exception {
  CoachBrainWorkoutPlanException(this.message);
  final String message;

  @override
  String toString() => message;
}

const _knowledgeAssetFiles = [
  'knowledge/manifest.yaml',
  'knowledge/reference/capabilities.yaml',
  'knowledge/reference/capability_intent_mappings.yaml',
  'knowledge/reference/energy_systems.yaml',
  'knowledge/reference/environments.yaml',
  'knowledge/reference/equipment.yaml',
  'knowledge/reference/exercises_reference.yaml',
  'knowledge/reference/gap_analysis_scenarios.yaml',
  'knowledge/reference/goal_requirements.yaml',
  'knowledge/reference/joint_actions.yaml',
  'knowledge/reference/movement_patterns.yaml',
  'knowledge/reference/muscle_groups.yaml',
  'knowledge/reference/programme_phases.yaml',
  'knowledge/reference/programme_progression.yaml',
  'knowledge/reference/session_archetypes.yaml',
  'knowledge/reference/substitutions_reference.yaml',
  'knowledge/reference/training_blocks.yaml',
  'knowledge/reference/training_intents.yaml',
  'knowledge/reference/week_types.yaml',
  'knowledge/schemas/capability.schema.yaml',
  'knowledge/schemas/capability_intent_mapping.schema.yaml',
  'knowledge/schemas/exercise.schema.yaml',
  'knowledge/schemas/goal_requirement.schema.yaml',
  'knowledge/schemas/ontology_entity.schema.yaml',
  'knowledge/schemas/programme_phase.schema.yaml',
  'knowledge/schemas/relationships.schema.yaml',
  'knowledge/schemas/session_archetype.schema.yaml',
  'knowledge/schemas/substitution_rule.schema.yaml',
  'knowledge/schemas/training_block.schema.yaml',
  'knowledge/schemas/training_intent.schema.yaml',
  'knowledge/schemas/week_type.schema.yaml',
];
