import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';

import 's17_staging_journey_matrix.dart';

/// Explicit athlete actions for journey D (never silent DB writes).
enum S17AdaptationAthleteAction { none, reject, accept }

class S17AdaptationProposalView {
  const S17AdaptationProposalView({
    required this.proposalId,
    required this.changeKinds,
    required this.packageFingerprint,
  });

  final String proposalId;
  final List<AdaptationChangeKind> changeKinds;
  final String packageFingerprint;
}

class S17AdaptationHarnessResult {
  const S17AdaptationHarnessResult({
    required this.result,
    required this.detail,
  });

  final S17JourneyResult result;
  final String detail;
}

/// Journey D — suggestion / reject / accept through explicit athlete actions.
class S17AdaptationHarness {
  const S17AdaptationHarness({this.policy = const AdaptationPolicyGate()});

  final AdaptationPolicyGate policy;

  S17AdaptationHarnessResult evaluate({
    required S17AdaptationProposalView? proposal,
    required S17AdaptationAthleteAction action,
    required String fingerprintBefore,
    required String fingerprintAfterSuggestionOnly,
    required String fingerprintAfterAction,
    required bool acceptInvokedExplicitly,
    required bool autoApplied,
    String? noProposalSafeDetail,
  }) {
    if (autoApplied) {
      return const S17AdaptationHarnessResult(
        result: S17JourneyResult.fail,
        detail: 'Adaptation auto-applied without explicit athlete action',
      );
    }

    // Suggestion alone must not mutate prepared execution fingerprint.
    if (fingerprintBefore != fingerprintAfterSuggestionOnly) {
      return const S17AdaptationHarnessResult(
        result: S17JourneyResult.fail,
        detail: 'Suggestion mutated prepared package without agreement',
      );
    }

    if (proposal == null) {
      final detail =
          (noProposalSafeDetail == null || noProposalSafeDetail.trim().isEmpty)
          ? 'No adaptation proposal available under current constraints'
          : noProposalSafeDetail.trim();
      // Lack of an acceptable proposal is never PASS.
      return S17AdaptationHarnessResult(
        result: S17JourneyResult.blocked,
        detail: detail,
      );
    }

    final rejectedKinds = policy.rejectUnsupported(proposal.changeKinds);
    final withinPolicy = rejectedKinds.isEmpty;

    switch (action) {
      case S17AdaptationAthleteAction.none:
        return const S17AdaptationHarnessResult(
          result: S17JourneyResult.fail,
          detail: 'Explicit accept/reject required; none recorded',
        );
      case S17AdaptationAthleteAction.reject:
        final unchanged = fingerprintBefore == fingerprintAfterAction;
        return S17AdaptationHarnessResult(
          result: unchanged ? S17JourneyResult.pass : S17JourneyResult.fail,
          detail: unchanged
              ? 'Reject left schedule/prescription unchanged'
              : 'Reject mutated prepared package',
        );
      case S17AdaptationAthleteAction.accept:
        if (!acceptInvokedExplicitly) {
          return const S17AdaptationHarnessResult(
            result: S17JourneyResult.fail,
            detail: 'Accept marked without explicit Athlete D action',
          );
        }
        if (!withinPolicy) {
          return S17AdaptationHarnessResult(
            result: S17JourneyResult.fail,
            detail:
                'Accepted changes outside AdaptationPolicyGate.allowed: '
                '${rejectedKinds.map((e) => e.name).join(',')}',
          );
        }
        final changed = fingerprintBefore != fingerprintAfterAction;
        return S17AdaptationHarnessResult(
          result: changed ? S17JourneyResult.pass : S17JourneyResult.fail,
          detail: changed
              ? 'Explicit accept applied within policy'
              : 'Accept produced no durable prepared-package change',
        );
    }
  }
}
