import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import 'equipment_adaptation_request_validator.dart';
import 'plan_package_session_adaptation_adapter.dart';
import 'programme_adaptation_proposal_mapper.dart';

typedef ProgrammeProtocolDraftLoader =
    Future<ProtocolDraft> Function(String protocolId);

typedef ProgrammeAdaptationPermissionLoader =
    Future<List<PlanPackageAdaptationPermission>> Function(
      String programmeVersionId,
    );

typedef ProgrammeKnowledgeLoader = Future<KnowledgeGraphReader> Function();

/// Compute-only programme adaptation proposal entry (Sprint 1.6B / B4d.19).
///
/// Does not accept, persist, mutate prepared packages, advance cursors, or
/// invoke Adaptive Progression / Plan Library generation / legacy decision
/// routing.
class ProgrammeAdaptationProposalService {
  ProgrammeAdaptationProposalService({
    PlanPackageSessionAdaptationAdapter? adapter,
    ProgrammeProtocolDraftLoader? loadProtocolDraft,
    ProgrammeAdaptationPermissionLoader? loadAdaptationPermissions,
    ProgrammeKnowledgeLoader? loadKnowledge,
    KnowledgeGraphReader? knowledge,
  }) : _loadProtocolDraft =
           loadProtocolDraft ??
           ((protocolId) => ProtocolBuilderService().loadProtocol(protocolId)),
       _loadAdaptationPermissions =
           loadAdaptationPermissions ?? ((_) async => const []),
       _loadKnowledge =
           loadKnowledge ??
           (knowledge != null
               ? () async => knowledge
               : defaultKnowledgeLoader),
       _adapterOverride = adapter;

  final ProgrammeProtocolDraftLoader _loadProtocolDraft;
  final ProgrammeAdaptationPermissionLoader _loadAdaptationPermissions;
  final ProgrammeKnowledgeLoader _loadKnowledge;
  final PlanPackageSessionAdaptationAdapter? _adapterOverride;

  static KnowledgeGraphReader? _cachedKnowledge;

  /// Evaluates a proposal against a currently prepared programme package.
  ///
  /// Always returns a typed proposal/result. Never mutates [package].
  Future<ProgrammeAdaptationProposal> propose({
    required PreparedExecutionPackage package,
    required AdaptationRequest request,
    DateTime? proposedAt,
    String? slotKey,
  }) async {
    if (!_isEligible(package)) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: package.isProgrammeBacked
            ? ProgrammeAdaptationNoSafeReason.staleOrMismatchedPreparedSession
            : ProgrammeAdaptationNoSafeReason.notProgrammeBacked,
        message:
            'Cohort could not safely adapt this session because the prepared '
            'session is missing or invalid. Your programme has not changed.',
        proposedAt: proposedAt,
      );
    }

    try {
      const AdaptationPolicyGate().assertAllowed(
        AdaptationPolicyGate.kindsForDayOf(request.reason),
      );
    } on AdaptationPolicyException {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: request,
        noSafeReason: ProgrammeAdaptationNoSafeReason.policyRejected,
        message:
            'Cohort could not safely adapt this session because the requested '
            'change is not permitted by coaching policy. Your prescribed '
            'programme and prepared session are unchanged.',
        proposedAt: proposedAt,
      );
    }

    final knowledge = await _loadKnowledge();
    var effectiveRequest = request;

    if (request.reason == AdaptationReason.equipment) {
      final validation = const EquipmentAdaptationRequestValidator().validate(
        request: request,
        knowledge: knowledge,
      );
      if (!validation.isValid) {
        final reason =
            validation.issue ==
                    EquipmentAdaptationRequestIssue
                        .availableEquipmentRequired ||
                validation.issue ==
                    EquipmentAdaptationRequestIssue.emptyAvailableEquipment
            ? ProgrammeAdaptationNoSafeReason.availableEquipmentRequired
            : ProgrammeAdaptationNoSafeReason.availableEquipmentRequired;
        return ProgrammeAdaptationProposalMapper.noSafeFromException(
          package: package,
          request: request,
          noSafeReason: reason,
          message:
              'Cohort could not safely adapt this session because available '
              'equipment was not specified clearly. Your prescribed programme '
              'has not changed, and your current prepared session remains '
              'available.',
          proposedAt: proposedAt,
        );
      }
      effectiveRequest = const EquipmentAdaptationRequestValidator()
          .applyNormalized(request, validation.normalizedEquipment);
    }

    final permissions = await _loadAdaptationPermissions(
      package.programmeVersionId!.trim(),
    );

    final adapter =
        _adapterOverride ??
        PlanPackageSessionAdaptationAdapter(knowledge: knowledge);

    try {
      final draft = await _loadProtocolDraft(package.protocolId!.trim());
      final run = adapter.evaluate(
        package: package,
        request: effectiveRequest,
        authoredDraft: draft,
        adaptationPermissions: permissions,
        slotKey: slotKey,
      );
      return ProgrammeAdaptationProposalMapper.fromPipelineRun(
        package: package,
        request: effectiveRequest,
        run: run,
        authoredDraft: draft,
        proposedAt: proposedAt,
      );
    } on PlanPackageAdaptationAdapterException catch (error) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: effectiveRequest,
        noSafeReason: _mapAdapterCode(error.code),
        message:
            'Cohort could not safely adapt this session. ${error.message} '
            'Your prescribed programme has not changed, and your current '
            'prepared session remains available.',
        proposedAt: proposedAt,
      );
    } catch (_) {
      return ProgrammeAdaptationProposalMapper.noSafeFromException(
        package: package,
        request: effectiveRequest,
        noSafeReason: ProgrammeAdaptationNoSafeReason.pipelineUnableToPlan,
        message:
            'Cohort could not safely adapt this session under your current '
            'constraint. Your prescribed programme has not changed, and your '
            'current prepared session remains available.',
        proposedAt: proposedAt,
      );
    }
  }

  bool _isEligible(PreparedExecutionPackage package) {
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.assignmentId!.trim().isNotEmpty &&
        package.plan.blocks.isNotEmpty;
  }

  ProgrammeAdaptationNoSafeReason _mapAdapterCode(String code) {
    return switch (code) {
      'not_programme_backed' =>
        ProgrammeAdaptationNoSafeReason.notProgrammeBacked,
      'draft_protocol_mismatch' ||
      'protocol_mismatch' ||
      'missing_protocol' ||
      'missing_assignment' ||
      'empty_prescription' ||
      'empty_prepared_plan' =>
        ProgrammeAdaptationNoSafeReason.staleOrMismatchedPreparedSession,
      'substitution_not_permitted' =>
        ProgrammeAdaptationNoSafeReason.substitutionNotPermitted,
      _ => ProgrammeAdaptationNoSafeReason.pipelineUnableToPlan,
    };
  }

  /// Shared curated knowledge loader (propose + accept freshness revalidation).
  static Future<KnowledgeGraphReader> defaultKnowledgeLoader() async {
    if (_cachedKnowledge != null) return _cachedKnowledge!;
    final root = await CoachBrainWorkoutPlanService.resolveKnowledgeRoot();
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      root,
    );
    _cachedKnowledge = InMemoryKnowledgeGraphReader(bundle);
    return _cachedKnowledge!;
  }
}
