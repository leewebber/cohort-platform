import '../../../../data/repositories/session_lineage_store.dart';
import '../../../../data/repositories/session_lineage_supabase_store.dart';
import '../../../../data/repositories/session_revision_delete_store.dart';
import '../../../../data/repositories/session_revision_delete_supabase_store.dart';
import '../../../admin/services/protocol_builder_service.dart';
import '../../../exercise_relationship/services/exercise_relationship_service.dart';
import '../../../session_revision/services/session_revision_action_policy_service.dart';
import '../../../session_revision/services/session_revision_relationship_service.dart';
import '../../../session_revision/services/session_revision_service.dart';
import '../controllers/session_governance_controller.dart';

/// Production wiring for Coach Studio governance UI (M9.5).
class CoachStudioGovernanceServices {
  CoachStudioGovernanceServices._();

  static SessionRevisionActionPolicyService createActionPolicyService({
    SessionLineageStore? lineageStore,
    SessionRevisionRelationshipService? relationshipService,
    ProtocolBuilderService? protocolBuilderService,
  }) {
    final resolvedLineageStore =
        lineageStore ?? const SessionLineageSupabaseStore();
    return SessionRevisionActionPolicyService(
      lineageStore: resolvedLineageStore,
      protocolBuilderService: protocolBuilderService ?? ProtocolBuilderService(),
      relationshipService: relationshipService ??
          SessionRevisionRelationshipService(
            lineageStore: resolvedLineageStore,
          ),
    );
  }

  static SessionRevisionRelationshipService createRelationshipService({
    SessionLineageStore? lineageStore,
  }) {
    final resolvedLineageStore =
        lineageStore ?? const SessionLineageSupabaseStore();
    return SessionRevisionRelationshipService(
      lineageStore: resolvedLineageStore,
    );
  }

  static SessionRevisionService createRevisionService({
    SessionLineageStore? lineageStore,
    ProtocolBuilderService? protocolBuilderService,
    SessionRevisionActionPolicyService? actionPolicyService,
    SessionRevisionDeleteStore? deleteStore,
  }) {
    final resolvedLineageStore =
        lineageStore ?? const SessionLineageSupabaseStore();
    final resolvedBuilder =
        protocolBuilderService ?? ProtocolBuilderService();
    return SessionRevisionService(
      lineageStore: resolvedLineageStore,
      protocolBuilderService: resolvedBuilder,
      actionPolicyService: actionPolicyService ??
          createActionPolicyService(
            lineageStore: resolvedLineageStore,
            protocolBuilderService: resolvedBuilder,
          ),
      deleteStore: deleteStore ?? const SessionRevisionDeleteSupabaseStore(),
    );
  }

  static ExerciseRelationshipService createExerciseRelationshipService() {
    return ExerciseRelationshipService();
  }

  static SessionGovernanceController createSessionGovernanceController({
    required String protocolId,
    String? sessionDisplayName,
    SessionLineageStore? lineageStore,
    ProtocolBuilderService? protocolBuilderService,
    SessionRevisionActionPolicyService? actionPolicyService,
    SessionRevisionRelationshipService? relationshipService,
  }) {
    final resolvedLineageStore =
        lineageStore ?? const SessionLineageSupabaseStore();
    final resolvedBuilder =
        protocolBuilderService ?? ProtocolBuilderService();
    final resolvedRelationshipService = relationshipService ??
        createRelationshipService(lineageStore: resolvedLineageStore);
    return SessionGovernanceController(
      protocolId: protocolId,
      sessionDisplayName: sessionDisplayName,
      lineageStore: resolvedLineageStore,
      protocolBuilderService: resolvedBuilder,
      actionPolicyService: actionPolicyService ??
          createActionPolicyService(
            lineageStore: resolvedLineageStore,
            protocolBuilderService: resolvedBuilder,
            relationshipService: resolvedRelationshipService,
          ),
      relationshipService: resolvedRelationshipService,
    );
  }
}
