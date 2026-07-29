import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/adaptation_scoring_reason.dart';
import 'package:cohort_platform/models/recovery_state.dart';

import 'adaptation_training_environment_adapter.dart';

/// Translates legacy athlete/engine vocabulary into canonical domain constraints
/// and scoring inputs without conflating audit outputs.
class AdaptationReasonMapping {
  const AdaptationReasonMapping._();

  /// Maps questionnaire output to domain constraints (hard by default for gating).
  static List<AdaptationConstraint> constraintsFromRequest(
    AdaptationRequest request,
  ) {
    switch (request.reason) {
      case AdaptationReason.recovery:
        return [
          AdaptationConstraint(
            kind: AdaptationConstraintKind.recovery,
            scope: AdaptationConstraintScope.session,
            severity: _recoverySeverity(request.recoveryState),
            isHard: true,
            recoveryStateLabel: request.recoveryState?.label,
          ),
        ];
      case AdaptationReason.environment:
        final env = request.environment;
        return [
          AdaptationConstraint(
            kind: AdaptationConstraintKind.environment,
            scope: AdaptationConstraintScope.session,
            severity: AdaptationConstraintSeverity.moderate,
            isHard: true,
            trainingEnvironment: env == null
                ? null
                : mapAdaptationSessionEnvironmentToTrainingEnvironment(
                    env,
                  ).dbValue,
          ),
        ];
      case AdaptationReason.equipment:
        return [
          AdaptationConstraint(
            kind: AdaptationConstraintKind.equipment,
            scope: AdaptationConstraintScope.equipment,
            severity: AdaptationConstraintSeverity.moderate,
            isHard: true,
            availableEquipment: request.availableEquipment ?? const {},
          ),
        ];
      case AdaptationReason.time:
        return [
          AdaptationConstraint(
            kind: AdaptationConstraintKind.time,
            scope: AdaptationConstraintScope.session,
            severity: AdaptationConstraintSeverity.moderate,
            isHard: true,
            availableMinutes: request.availableMinutes,
          ),
        ];
    }
  }

  /// Maps domain constraints to legacy scoring reasons for [AdaptationService].
  ///
  /// Environment constraints that imply travel (hotel) also activate travelling
  /// scoring — without merging the enums.
  static Set<AdaptationScoringReason> scoringReasonsFromConstraints(
    Iterable<AdaptationConstraint> constraints,
  ) {
    final reasons = <AdaptationScoringReason>{};
    for (final constraint in constraints) {
      switch (constraint.kind) {
        case AdaptationConstraintKind.recovery:
          reasons.add(AdaptationScoringReason.poorRecovery);
        case AdaptationConstraintKind.equipment:
          reasons.add(AdaptationScoringReason.limitedEquipment);
        case AdaptationConstraintKind.time:
          reasons.add(AdaptationScoringReason.shortOnTime);
        case AdaptationConstraintKind.environment:
          reasons.add(AdaptationScoringReason.travelling);
        case AdaptationConstraintKind.programmePolicy:
        case AdaptationConstraintKind.painOrDiscomfort:
        case AdaptationConstraintKind.unknown:
          break;
      }
    }
    return reasons;
  }

  static AdaptationScoringReason? primaryScoringReason(
    AdaptationReason athleteReason,
  ) {
    return switch (athleteReason) {
      AdaptationReason.recovery => AdaptationScoringReason.poorRecovery,
      AdaptationReason.equipment => AdaptationScoringReason.limitedEquipment,
      AdaptationReason.time => AdaptationScoringReason.shortOnTime,
      AdaptationReason.environment => AdaptationScoringReason.travelling,
    };
  }

  /// Audit event types are outputs — never athlete input reasons.
  static bool isAuditEventType(AdaptationAuditEventType type) => true;

  static AdaptationConstraintSeverity _recoverySeverity(RecoveryState? state) {
    return switch (state) {
      RecoveryState.slightlyTired => AdaptationConstraintSeverity.mild,
      RecoveryState.poorSleep => AdaptationConstraintSeverity.moderate,
      RecoveryState.veryFatigued => AdaptationConstraintSeverity.severe,
      RecoveryState.feelingIll => AdaptationConstraintSeverity.severe,
      null => AdaptationConstraintSeverity.moderate,
    };
  }
}
