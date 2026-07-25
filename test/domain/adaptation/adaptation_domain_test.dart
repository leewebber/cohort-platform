import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_event.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/adaptation_scoring_reason.dart';
import 'package:cohort_platform/models/adaptation_session_environment.dart';
import 'package:cohort_platform/models/recovery_state.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enum serialization stability', () {
    test('SessionIntent round-trips all values', () {
      for (final intent in SessionIntent.values) {
        expect(SessionIntentDb.fromDb(intent.dbValue), intent);
      }
    });

    test('persisted vocabulary enums round-trip', () {
      for (final value in SessionModality.values) {
        expect(SessionModalityDb.fromDb(value.dbValue), value);
      }
      for (final value in AdaptationActionType.values) {
        expect(AdaptationActionTypeDb.fromDb(value.dbValue), value);
      }
      for (final value in AdaptationFidelity.values) {
        expect(AdaptationFidelityDb.fromDb(value.dbValue), value);
      }
      for (final value in AdaptationAuditEventType.values) {
        expect(AdaptationAuditEventTypeDb.fromDb(value.dbValue), value);
      }
    });
  });

  group('AdaptationConstraint', () {
    test('hard versus soft representation', () {
      const hard = AdaptationConstraint(
        kind: AdaptationConstraintKind.time,
        scope: AdaptationConstraintScope.session,
        severity: AdaptationConstraintSeverity.moderate,
        isHard: true,
        availableMinutes: 30,
      );
      const soft = AdaptationConstraint(
        kind: AdaptationConstraintKind.time,
        scope: AdaptationConstraintScope.session,
        severity: AdaptationConstraintSeverity.mild,
        isHard: false,
        availableMinutes: 45,
      );

      expect(hard.isHard, isTrue);
      expect(soft.isHard, isFalse);

      final decoded = AdaptationConstraint.fromJson(hard.toJson());
      expect(decoded.isHard, isTrue);
      expect(decoded.availableMinutes, 30);
    });
  });

  group('BlockAdaptationPolicy', () {
    test('serializes flags and minimum viable prescription', () {
      const policy = BlockAdaptationPolicy(
        canRemove: false,
        canShorten: true,
        canReduceVolume: true,
        canReduceIntensity: true,
        canIncreaseRest: true,
        canSuperset: false,
        canReplaceExercises: true,
        canReplaceBlock: false,
        minimumViablePrescription: MinimumViablePrescription(
          sets: 2,
          reps: 5,
          qualitativeLoad: 'moderate',
        ),
      );

      final decoded = BlockAdaptationPolicy.fromJson(policy.toJson());
      expect(decoded.canRemove, isFalse);
      expect(decoded.minimumViablePrescription?.sets, 2);
    });

    test('SessionBlockTypeAdaptationPolicy provides strength defaults', () {
      final policy = SessionBlockTypeAdaptationPolicy.defaultAdaptationPolicy(
        SessionBlockType.strength,
      );
      expect(policy.canReplaceExercises, isTrue);
      expect(policy.canRemove, isFalse);
      expect(
        SessionBlockTypeAdaptationPolicy.defaultPriority(SessionBlockType.warmUp),
        BlockPriority.disposable,
      );
    });
  });

  group('AdaptationFidelityAssessment', () {
    test('qualitative assessment from intent retention', () {
      final assessment = AdaptationFidelityAssessment.fromIntentRetention(
        primaryIntent: SessionIntent.lowerBodyStrength,
        secondaryIntent: SessionIntent.prehabilitation,
        primaryRetained: true,
        secondaryRetained: false,
      );

      expect(assessment.fidelity, AdaptationFidelity.high);
      expect(assessment.primaryIntentRetained, isTrue);
      expect(assessment.secondaryIntentRetained, isFalse);

      final roundTrip =
          AdaptationFidelityAssessment.fromJson(assessment.toJson());
      expect(roundTrip.fidelity, AdaptationFidelity.high);
    });
  });

  group('AdaptationAction', () {
    test('targets entity and serializes', () {
      const action = AdaptationAction(
        actionType: AdaptationActionType.swapExercise,
        targetScope: 'exercise_placement',
        targetId: 'link-123',
        reason: 'Equipment constraint',
        originalReference: 'EX-001',
        adaptedReference: 'EX-042',
        expectedIntentImpact: AdaptationFidelity.high,
      );

      final decoded = AdaptationAction.fromJson(action.toJson());
      expect(decoded.targetId, 'link-123');
      expect(decoded.actionType, AdaptationActionType.swapExercise);
      expect(decoded.expectedIntentImpact, AdaptationFidelity.high);
    });

    test('action type preference order follows adaptation ladder', () {
      expect(
        AdaptationActionType.adjustPrescription.preferenceOrder <
            AdaptationActionType.swapExercise.preferenceOrder,
        isTrue,
      );
      expect(
        AdaptationActionType.replaceBlock.preferenceOrder <
            AdaptationActionType.replaceSession.preferenceOrder,
        isTrue,
      );
    });
  });

  group('AdaptationReasonMapping', () {
    test('maps athlete recovery request to domain and scoring', () {
      const request = AdaptationRequest(
        reason: AdaptationReason.recovery,
        recoveryState: RecoveryState.veryFatigued,
      );

      final constraints = AdaptationReasonMapping.constraintsFromRequest(request);
      expect(constraints, hasLength(1));
      expect(constraints.first.kind, AdaptationConstraintKind.recovery);
      expect(constraints.first.isHard, isTrue);
      expect(constraints.first.severity, AdaptationConstraintSeverity.severe);

      final scoring = AdaptationReasonMapping.scoringReasonsFromConstraints(
        constraints,
      );
      expect(scoring, contains(AdaptationScoringReason.poorRecovery));
    });

    test('maps environment without merging audit types', () {
      const request = AdaptationRequest(
        reason: AdaptationReason.environment,
        environment: AdaptationSessionEnvironment.hotelGym,
      );

      final constraints = AdaptationReasonMapping.constraintsFromRequest(request);
      expect(constraints.first.trainingEnvironment, 'hotel_gym');

      expect(
        AdaptationReasonMapping.primaryScoringReason(AdaptationReason.environment),
        AdaptationScoringReason.travelling,
      );

      expect(ProgrammeAdaptationType.loadProgression.name, isNot('recovery'));
      expect(
        AdaptationAuditEventType.loadProgression.dbValue,
        'load_progression',
      );
    });
  });

  group('AdaptationValidationResult', () {
    test('round-trips unresolved constraints', () {
      final result = AdaptationValidationResult(
        valid: false,
        errors: const ['Primary intent would be lost'],
        retainedPrimaryIntent: SessionIntent.tempo,
        unresolvedConstraints: [
          AdaptationConstraint(
            kind: AdaptationConstraintKind.time,
            scope: AdaptationConstraintScope.session,
            severity: AdaptationConstraintSeverity.moderate,
            isHard: true,
            availableMinutes: 20,
          ),
        ],
      );

      final decoded = AdaptationValidationResult.fromJson(result.toJson());
      expect(decoded.valid, isFalse);
      expect(decoded.retainedPrimaryIntent, SessionIntent.tempo);
      expect(decoded.unresolvedConstraints, hasLength(1));
    });
  });
}
