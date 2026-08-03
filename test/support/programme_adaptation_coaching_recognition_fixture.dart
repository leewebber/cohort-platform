import 'package:cohort_platform/application/adaptation/programme_adaptation_fingerprints.dart';
import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sprint 1.6E Coaching Recognition fixture helpers.
///
/// After any accepted adaptation, a coach reviewing Plan Package identity and
/// programmed session provenance must still recognise the original programme.
/// Adaptations are derived execution decisions, not programme rewrites.
class ProgrammeAdaptationCoachingRecognitionFixture {
  const ProgrammeAdaptationCoachingRecognitionFixture._();

  /// Asserts programmed identity and Plan Package provenance survive adaptation.
  static void assertProgrammeStillRecognisable({
    required PreparedExecutionPackage before,
    required PreparedExecutionPackage after,
    required SessionExecutionPlan reconstructedOriginalPlan,
  }) {
    expect(
      after.programmedSessionKey.value,
      before.programmedSessionKey.value,
      reason: 'Programmed session identity must remain recognisable.',
    );
    expect(after.assignmentId, before.assignmentId);
    expect(after.programmeVersionId, before.programmeVersionId);
    expect(after.packageContentHash, before.packageContentHash);
    expect(after.protocolId, before.protocolId);
    expect(after.dayKey, before.dayKey);
    expect(after.slotOrder, before.slotOrder);

    final decision = after.acceptedAdaptation;
    expect(decision, isA<AcceptedAdaptationDecision>());
    expect(decision!.programmedSessionKey, before.programmedSessionKey.value);
    expect(decision.assignmentId, before.assignmentId);
    expect(decision.programmeVersionId, before.programmeVersionId);
    expect(decision.packageContentHash, before.packageContentHash);
    expect(decision.protocolId, before.protocolId);
    expect(decision.originalPlanFingerprint, isNotNull);

    final reconstructedFp = ProgrammeAdaptationFingerprints.plan(
      reconstructedOriginalPlan,
    );
    expect(
      reconstructedFp,
      decision.originalPlanFingerprint,
      reason:
          'Authored original must remain reconstructible and match acceptance '
          'provenance (Coaching Recognition).',
    );
    expect(
      reconstructedFp,
      ProgrammeAdaptationFingerprints.plan(before.plan),
      reason: 'Reconstructed original must match pre-adaptation authored plan.',
    );
  }

  /// Asserts successful reversion restores the recognisable original prepare.
  static void assertOriginalRestored({
    required PreparedExecutionPackage originalBeforeAdaptation,
    required PreparedExecutionPackage afterRevert,
  }) {
    expect(afterRevert.hasAcceptedAdaptation, isFalse);
    expect(
      afterRevert.programmedSessionKey.value,
      originalBeforeAdaptation.programmedSessionKey.value,
    );
    expect(afterRevert.assignmentId, originalBeforeAdaptation.assignmentId);
    expect(
      afterRevert.programmeVersionId,
      originalBeforeAdaptation.programmeVersionId,
    );
    expect(
      afterRevert.packageContentHash,
      originalBeforeAdaptation.packageContentHash,
    );
    expect(afterRevert.protocolId, originalBeforeAdaptation.protocolId);
    expect(
      ProgrammeAdaptationFingerprints.plan(afterRevert.plan),
      ProgrammeAdaptationFingerprints.plan(originalBeforeAdaptation.plan),
    );
  }
}
