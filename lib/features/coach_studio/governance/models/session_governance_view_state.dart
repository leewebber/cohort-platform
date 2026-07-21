import '../../../../models/session_revision_vocabulary.dart';
import '../../../session_revision/models/session_revision_action_decision.dart';
import '../../../session_revision/models/session_revision_action_vocabulary.dart';
import '../../../session_revision/models/session_revision_usage_models.dart';

class SessionGovernanceViewState {
  const SessionGovernanceViewState({
    required this.isLoading,
    this.loadError,
    this.sessionDisplayName,
    this.revisionNumber,
    this.lifecycleStatus,
    this.policy,
    this.usageLookup,
    this.revisionNotFound = false,
  });

  const SessionGovernanceViewState.loading()
      : isLoading = true,
        loadError = null,
        sessionDisplayName = null,
        revisionNumber = null,
        lifecycleStatus = null,
        policy = null,
        usageLookup = null,
        revisionNotFound = false;

  final bool isLoading;
  final String? loadError;
  final String? sessionDisplayName;
  final int? revisionNumber;
  final SessionRevisionLifecycleStatus? lifecycleStatus;
  final SessionRevisionActionPolicySummary? policy;
  final SessionRevisionUsageLookupResult? usageLookup;
  final bool revisionNotFound;

  bool get hasPolicy => policy != null;

  SessionRevisionActionDecision? decisionFor(
    SessionRevisionAction action,
  ) {
    return policy?.decisions[action];
  }
}
