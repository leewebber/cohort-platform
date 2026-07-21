import 'session_revision_action_vocabulary.dart';
import 'session_revision_usage_models.dart';

/// Typed policy decision for one Session Revision action.
class SessionRevisionActionDecision {
  const SessionRevisionActionDecision({
    required this.action,
    required this.allowed,
    required this.severity,
    required this.primaryReasonCode,
    required this.reasons,
    required this.userMessage,
    this.recommendedAlternative,
    this.usageSummary,
  });

  final SessionRevisionAction action;
  final bool allowed;
  final SessionRevisionActionSeverity severity;
  final SessionRevisionActionReasonCode primaryReasonCode;
  final List<SessionRevisionActionReasonCode> reasons;
  final String userMessage;
  final String? recommendedAlternative;
  final SessionRevisionUsageSummary? usageSummary;

  bool get isBlocking =>
      !allowed && severity == SessionRevisionActionSeverity.blocking;
}

/// All supported action decisions for one Session Revision.
class SessionRevisionActionPolicySummary {
  const SessionRevisionActionPolicySummary({
    required this.protocolId,
    required this.decisions,
  });

  final String protocolId;
  final Map<SessionRevisionAction, SessionRevisionActionDecision> decisions;

  SessionRevisionActionDecision decisionFor(SessionRevisionAction action) {
    return decisions[action]!;
  }
}

/// Result of loading exact usage for policy evaluation.
enum SessionRevisionUsageLookupStatus {
  success,
  revisionNotFound,
  lookupFailed,
}

class SessionRevisionUsageLookupResult {
  const SessionRevisionUsageLookupResult._({
    required this.status,
    this.summary,
    this.message,
  });

  const SessionRevisionUsageLookupResult.success(
    SessionRevisionUsageSummary summary,
  ) : this._(
          status: SessionRevisionUsageLookupStatus.success,
          summary: summary,
        );

  const SessionRevisionUsageLookupResult.revisionNotFound()
      : this._(status: SessionRevisionUsageLookupStatus.revisionNotFound);

  const SessionRevisionUsageLookupResult.lookupFailed(String message)
      : this._(
          status: SessionRevisionUsageLookupStatus.lookupFailed,
          message: message,
        );

  final SessionRevisionUsageLookupStatus status;
  final SessionRevisionUsageSummary? summary;
  final String? message;

  bool get isSuccess => status == SessionRevisionUsageLookupStatus.success;
}

class SessionRevisionPolicyException implements Exception {
  const SessionRevisionPolicyException(this.message, {this.decision});

  final String message;
  final SessionRevisionActionDecision? decision;

  @override
  String toString() => 'SessionRevisionPolicyException: $message';
}
