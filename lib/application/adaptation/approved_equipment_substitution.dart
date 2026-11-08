import '../../features/adaptation/services/adaptation_policy_gate.dart';
import '../../features/authored_plan_package/plan_package_manifest.dart';
import '../../features/programme/models/programme_execution_context.dart';
import '../../features/session/models/prepared_execution_package.dart';
import '../../knowledge/models/knowledge_ontology_models.dart';
import '../../knowledge/read/in_memory_knowledge_graph_reader.dart';
import '../../models/adaptation_request.dart';
import '../../models/strength_exercise_prescription.dart';
import '../ports/knowledge_graph_reader.dart';
import 'plan_package_session_adaptation_adapter.dart';

typedef ProgrammeEquipmentApprovalLoader =
    Future<ApprovedEquipmentSubstitution?> Function(
      ProgrammeExecutionContext context,
    );

/// The signed-in athlete projection of one immutable publisher approval.
class ApprovedEquipmentSubstitution {
  ApprovedEquipmentSubstitution.fromJson(Map<String, dynamic> json)
    : packageHash = json['package_hash'] as String,
      protocolId = json['protocol_id'] as String,
      slotKey = json['slot_key'] as String,
      sourceId = json['source_exercise_id'] as String,
      replacementId = json['replacement_exercise_id'] as String,
      occurrenceKey = json['source_occurrence_id'] as String,
      permissionKey = json['permission_key'] as String,
      sourceLabel = json['source_label'] as String,
      replacementLabel = json['replacement_label'] as String,
      missingEquipment = json['missing_equipment'] as String,
      requiredEquipment = json['required_equipment'] as String,
      matchingDumbbellPair = json['matching_dumbbell_pair'] as bool,
      explanation = json['explanation'] as String,
      blockPosition = json['block_position'] as int,
      exercisePosition = json['exercise_position'] as int,
      prescription = StrengthExercisePrescription.fromJson(
        json['prescription'] as Map<String, dynamic>,
      );

  static const provenance = 'sealed_equipment_approval';

  final String packageHash;
  final String protocolId;
  final String slotKey;
  final String sourceId;
  final String replacementId;
  final String occurrenceKey;
  final String permissionKey;
  final String sourceLabel;
  final String replacementLabel;
  final String missingEquipment;
  final String requiredEquipment;
  final bool matchingDumbbellPair;
  final String explanation;
  final int blockPosition;
  final int exercisePosition;
  final StrengthExercisePrescription prescription;

  PlanPackageAdaptationPermission get permission =>
      PlanPackageAdaptationPermission(
        id: permissionKey,
        changeKind: AdaptationChangeKind.substituteApprovedEquipment,
        targetRef: slotKey,
        athleteAgreementRequired: true,
      );

  KnowledgeGraphReader authorize({
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext context,
    required AdaptationRequest request,
  }) {
    final equipment = request.availableEquipment ?? const {};
    if (package.assignmentId != context.assignmentId ||
        package.programmeVersionId != context.programmeVersionId ||
        package.programmedSessionKey.value != context.programmedSessionKey ||
        package.packageContentHash != packageHash ||
        context.packageContentHash != packageHash ||
        package.protocolId != protocolId ||
        context.plannedProtocolId != protocolId ||
        context.packageSlotKey != slotKey ||
        context.occurrenceId == null ||
        !equipment.contains(requiredEquipment) ||
        equipment.contains(missingEquipment) ||
        (matchingDumbbellPair && !request.confirmedMatchingDumbbellPair)) {
      throw PlanPackageAdaptationAdapterException(
        'substitution_not_permitted',
        'This approved replacement requires the exact session and confirmed equipment.',
      );
    }
    return _knowledge;
  }

  KnowledgeGraphReader get _knowledge => InMemoryKnowledgeGraphReader(
    KnowledgeOntologyBundle(
      ontologyVersion: 'sealed-equipment-approval-v1',
      entityIds: {sourceId, replacementId, permissionKey},
      capabilities: [],
      goals: [],
      exercises: [
        ExerciseKnowledge(
          meta: KnowledgeEntityMeta(
            id: sourceId,
            canonicalName: sourceId,
            label: sourceLabel,
            ontologyVersion: 'sealed-equipment-approval-v1',
            status: 'active',
          ),
          curationStatus: 'approved',
          requiredEquipmentIds: [missingEquipment],
        ),
        ExerciseKnowledge(
          meta: KnowledgeEntityMeta(
            id: replacementId,
            canonicalName: replacementId,
            label: replacementLabel,
            ontologyVersion: 'sealed-equipment-approval-v1',
            status: 'active',
          ),
          curationStatus: 'approved',
          requiredEquipmentIds: [requiredEquipment],
        ),
      ],
      substitutions: [
        SubstitutionRuleKnowledge(
          meta: KnowledgeEntityMeta(
            id: permissionKey,
            canonicalName: permissionKey,
            label: replacementLabel,
            ontologyVersion: 'sealed-equipment-approval-v1',
            status: 'active',
          ),
          sourceExerciseId: sourceId,
          candidateExerciseId: replacementId,
          equipmentRemovedIds: [missingEquipment],
          equipmentAddedIds: [requiredEquipment],
          explanation: explanation,
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
