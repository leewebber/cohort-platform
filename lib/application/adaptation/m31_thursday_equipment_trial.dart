import '../../features/adaptation/services/adaptation_policy_gate.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/session/models/prepared_execution_package.dart';
import '../../knowledge/models/knowledge_ontology_models.dart';
import '../../knowledge/read/in_memory_knowledge_graph_reader.dart';
import '../../models/adaptation_request.dart';
import '../../models/authored_int_range.dart';
import '../../models/strength_exercise_prescription.dart';
import 'plan_package_session_adaptation_adapter.dart';

/// The founder-approved alternative for a separate one-session private trial.
class M31ThursdayEquipmentTrial {
  M31ThursdayEquipmentTrial._();

  static const versionId = '5d095027-a4fb-4529-9ade-7a96a75e743f';
  static const protocolId = 'protocol-514e5f5a-c825-49cd-911a-a2bdf4f6c6d3';
  static const packageHash =
      'f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b';
  static const slotKey = 'LW10K-W01-D04';
  static const sourceId = 'EX-078';
  static const replacementId = 'EX-040';
  static const occurrenceId = 'W01-B-barbell_rdl';
  static const permissionId = 'm31-w01-d04-rdl';
  static const barbell = 'cohort.equipment.barbell';
  static const dumbbell = 'cohort.equipment.dumbbell';
  static const loadLabel = 'kg per dumbbell';
  static const cue =
      'Use one of two matching dumbbells in each hand. Hinge with soft knees '
      'and keep the dumbbells close. Stop before spinal position changes.';
  static const prescription = StrengthExercisePrescription(
    sets: 2,
    reps: StrengthRepPrescription(
      type: StrengthRepType.range,
      minReps: 5,
      maxReps: 6,
    ),
    rirRange: AuthoredIntRange(2, 3),
    restSecondsRange: AuthoredIntRange(120, 180),
    load: StrengthLoadPrescription(type: StrengthLoadType.athleteSelected),
    tempo: 'Lower under control for about two seconds.',
    coachCue: cue,
    performanceCapture: ExercisePerformanceCapture(
      loadUnit: 'kg',
      loadLabel: loadLabel,
    ),
  );

  static bool matches(PreparedExecutionPackage package, String? authoredSlot) {
    final key = package.programmedSessionKey;
    return package.programmeVersionId == versionId &&
        package.packageContentHash == packageHash &&
        package.protocolId == protocolId &&
        key.planVersion == versionId &&
        key.protocolId == protocolId &&
        key.programmeAssignmentId == package.assignmentId &&
        key.week == 1 &&
        key.dayKey == 'day_4' &&
        key.slotOrder == 1 &&
        authoredSlot == slotKey;
  }

  static InMemoryKnowledgeGraphReader authorize({
    required PreparedExecutionPackage package,
    required String? authoredSlot,
    required AdaptationRequest request,
    required List<PlanPackageAdaptationPermission> permissions,
  }) {
    final equipment = request.availableEquipment ?? const {};
    if (!matches(package, authoredSlot) ||
        !request.confirmedMatchingDumbbellPairWithoutBarbell ||
        !equipment.contains(dumbbell) ||
        equipment.contains(barbell) ||
        permissions.length != 1 ||
        permissions.single.id != permissionId ||
        permissions.single.targetRef != slotKey ||
        permissions.single.changeKind !=
            AdaptationChangeKind.substituteApprovedEquipment ||
        !permissions.single.athleteAgreementRequired) {
      throw PlanPackageAdaptationAdapterException(
        'substitution_not_permitted',
        'This trial requires its exact permission and confirmation of two '
            'matching dumbbells with no barbell.',
      );
    }
    return _knowledge;
  }

  static final _knowledge = InMemoryKnowledgeGraphReader(
    const KnowledgeOntologyBundle(
      ontologyVersion: 'm31-thursday-trial-v1',
      entityIds: {sourceId, replacementId, 'm31.rdl.equipment'},
      capabilities: [],
      goals: [],
      exercises: [
        ExerciseKnowledge(
          meta: KnowledgeEntityMeta(
            id: sourceId,
            canonicalName: 'romanian_deadlift',
            label: 'Barbell Romanian deadlift',
            ontologyVersion: 'm31-thursday-trial-v1',
            status: 'active',
          ),
          curationStatus: 'approved',
          requiredEquipmentIds: [barbell],
        ),
        ExerciseKnowledge(
          meta: KnowledgeEntityMeta(
            id: replacementId,
            canonicalName: 'dumbbell_romanian_deadlift',
            label: 'Dumbbell Romanian deadlift',
            ontologyVersion: 'm31-thursday-trial-v1',
            status: 'active',
          ),
          curationStatus: 'approved',
          requiredEquipmentIds: [dumbbell],
        ),
      ],
      substitutions: [
        SubstitutionRuleKnowledge(
          meta: KnowledgeEntityMeta(
            id: 'm31.rdl.equipment',
            canonicalName: 'm31_rdl_equipment',
            label: 'Two-dumbbell Romanian deadlift',
            ontologyVersion: 'm31-thursday-trial-v1',
            status: 'active',
          ),
          sourceExerciseId: sourceId,
          candidateExerciseId: replacementId,
          equipmentRemovedIds: [barbell],
          equipmentAddedIds: [dumbbell],
          explanation:
              'Keep the bilateral hinge. Do 2 working sets of 5–6 reps '
              'at 2–3 reps in reserve, resting 120–180 seconds. Lower under '
              'control for about two seconds. Choose your own load and record '
              'kg per dumbbell. Your barbell load will not carry over.',
        ),
      ],
      trainingIntents: [],
      sessionArchetypes: [],
      capabilityIntentMappings: [],
      programmePhases: [],
      trainingBlocks: [],
      weekTypes: [],
      programmeProgressionPaths: [],
      defaultProgressionPathId: null,
      aliasIndex: {},
    ),
  );
}
