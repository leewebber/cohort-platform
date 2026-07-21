import 'package:flutter/foundation.dart';

import '../../../../data/repositories/session_lineage_store.dart';
import '../../../../models/session_revision_vocabulary.dart';
import '../../../admin/services/protocol_builder_service.dart';
import '../../../session_revision/models/session_revision_action_decision.dart';
import '../../../session_revision/models/session_revision_action_vocabulary.dart';
import '../../../session_revision/services/session_revision_action_policy_service.dart';
import '../../../session_revision/services/session_revision_relationship_service.dart';
import '../models/session_governance_view_state.dart';

/// Loads Session Revision identity, policy, and usage for Coach Studio (M9.5).
class SessionGovernanceController extends ChangeNotifier {
  SessionGovernanceController({
    required String protocolId,
    required SessionRevisionActionPolicyService actionPolicyService,
    required SessionRevisionRelationshipService relationshipService,
    required SessionLineageStore lineageStore,
    required ProtocolBuilderService protocolBuilderService,
    String? sessionDisplayName,
  })  : _protocolId = protocolId.trim(),
        _actionPolicyService = actionPolicyService,
        _relationshipService = relationshipService,
        _lineageStore = lineageStore,
        _protocolBuilderService = protocolBuilderService,
        _sessionDisplayName = sessionDisplayName?.trim() {
    _state = SessionGovernanceViewState.loading();
  }

  final String _protocolId;
  final SessionRevisionActionPolicyService _actionPolicyService;
  final SessionRevisionRelationshipService _relationshipService;
  final SessionLineageStore _lineageStore;
  final ProtocolBuilderService _protocolBuilderService;
  String? _sessionDisplayName;

  SessionGovernanceViewState _state = SessionGovernanceViewState.loading();

  SessionGovernanceViewState get state => _state;
  String get protocolId => _protocolId;

  void updateSessionDisplayName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == _sessionDisplayName) return;
    _sessionDisplayName = trimmed;
    if (_state.sessionDisplayName != trimmed && !_state.isLoading) {
      _state = SessionGovernanceViewState(
        isLoading: _state.isLoading,
        loadError: _state.loadError,
        sessionDisplayName: trimmed ?? _state.sessionDisplayName,
        revisionNumber: _state.revisionNumber,
        lifecycleStatus: _state.lifecycleStatus,
        policy: _state.policy,
        usageLookup: _state.usageLookup,
        revisionNotFound: _state.revisionNotFound,
      );
      notifyListeners();
    }
  }

  Future<void> load() async {
    if (_protocolId.isEmpty) {
      _state = const SessionGovernanceViewState(
        isLoading: false,
        revisionNotFound: true,
      );
      notifyListeners();
      return;
    }

    _state = SessionGovernanceViewState.loading();
    notifyListeners();

    try {
      final identity = await _lineageStore.getRevisionIdentity(_protocolId);
      if (identity == null) {
        _state = const SessionGovernanceViewState(
          isLoading: false,
          revisionNotFound: true,
        );
        notifyListeners();
        return;
      }

      final lifecycleStatus =
          await _lineageStore.getRevisionLifecycleStatus(_protocolId);

      String? displayName = _sessionDisplayName;
      if (displayName == null || displayName.isEmpty) {
        try {
          final draft = await _protocolBuilderService.loadProtocol(_protocolId);
          displayName = draft.name.trim().isEmpty ? 'Session' : draft.name.trim();
        } catch (_) {
          displayName = 'Session';
        }
      }

      final results = await Future.wait([
        _actionPolicyService.evaluateAll(_protocolId),
        _relationshipService.tryGetUsageForRevision(_protocolId),
      ]);

      _state = SessionGovernanceViewState(
        isLoading: false,
        sessionDisplayName: displayName,
        revisionNumber: identity.revisionNumber,
        lifecycleStatus: lifecycleStatus,
        policy: results[0] as SessionRevisionActionPolicySummary,
        usageLookup: results[1] as SessionRevisionUsageLookupResult,
      );
    } catch (error) {
      _state = SessionGovernanceViewState(
        isLoading: false,
        loadError: error.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> refresh() => load();

  SessionRevisionActionDecision? decisionFor(SessionRevisionAction action) {
    return _state.decisionFor(action);
  }

  bool get isEditAllowed =>
      _state.decisionFor(SessionRevisionAction.edit)?.allowed ?? false;
}
