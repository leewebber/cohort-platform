import 'running_benchmark_policy.dart';
import 'running_pace_calculation.dart';

enum RunningTargetFreezeSource { inAppStart, deviceExport }

enum RunningIntentOnlyReason {
  noAuthoredTargetPolicy,
  noEvidence,
  noAthleteScopedEvidence,
  duplicateEvidenceIdentity,
  noTimezoneMatchedEvidence,
  noEligibleCompletedTest,
  noFreshEvidence,
}

class RunningTargetSnapshotException implements Exception {
  const RunningTargetSnapshotException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RunningTargetSnapshotException($code): $message';
}

class RunningTargetStepScope {
  factory RunningTargetStepScope({
    required String workoutId,
    required Iterable<String> stepIds,
  }) {
    final canonicalWorkoutId = workoutId.trim();
    final canonicalStepIds = stepIds.map((stepId) => stepId.trim()).toList();
    if (canonicalWorkoutId.isEmpty) {
      throw const RunningTargetSnapshotException(
        'missing_workout_scope',
        'An authored target requires a stable workout identity.',
      );
    }
    if (canonicalStepIds.isEmpty || canonicalStepIds.any((id) => id.isEmpty)) {
      throw const RunningTargetSnapshotException(
        'missing_step_scope',
        'A coach must explicitly select at least one authored step.',
      );
    }
    if (canonicalStepIds.toSet().length != canonicalStepIds.length) {
      throw const RunningTargetSnapshotException(
        'duplicate_step_scope',
        'An authored step may appear only once in a target scope.',
      );
    }
    return RunningTargetStepScope._(
      canonicalWorkoutId,
      List<String>.unmodifiable(canonicalStepIds),
    );
  }

  const RunningTargetStepScope._(this.workoutId, this.stepIds);

  final String workoutId;
  final List<String> stepIds;

  Map<String, Object> toJson() => <String, Object>{
    'workout_id': workoutId,
    'step_ids': stepIds,
  };
}

class FrozenRunningPolicyReference {
  const FrozenRunningPolicyReference._({
    required this.policyId,
    required this.policyVersion,
    required this.methodId,
    required this.methodVersion,
    required this.minimumSpeedBasisPoints,
    required this.maximumSpeedBasisPoints,
    required this.displayRounding,
  });

  factory FrozenRunningPolicyReference.fromPolicy(
    RunningPaceCalculationPolicy policy,
  ) {
    return FrozenRunningPolicyReference._(
      policyId: policy.policyId,
      policyVersion: policy.policyVersion,
      methodId: policy.methodId,
      methodVersion: policy.methodVersion,
      minimumSpeedBasisPoints: policy.minimumSpeedBasisPoints,
      maximumSpeedBasisPoints: policy.maximumSpeedBasisPoints,
      displayRounding: policy.displayRounding,
    );
  }

  final String policyId;
  final int policyVersion;
  final String methodId;
  final int methodVersion;
  final int minimumSpeedBasisPoints;
  final int maximumSpeedBasisPoints;
  final RunningPaceDisplayRoundingPolicy displayRounding;

  Map<String, Object> toJson() => <String, Object>{
    'policy_id': policyId,
    'policy_version': policyVersion,
    'method_id': methodId,
    'method_version': methodVersion,
    'minimum_speed_basis_points': minimumSpeedBasisPoints,
    'maximum_speed_basis_points': maximumSpeedBasisPoints,
    'display_rounding': <String, Object>{
      'increment_milliseconds_per_kilometre':
          displayRounding.incrementMillisecondsPerKilometre,
      'direction': _roundingToken(displayRounding.direction),
    },
  };
}

sealed class FrozenRunningTargetSnapshot {
  const FrozenRunningTargetSnapshot({
    required this.scope,
    required this.frozenAtUtc,
    required this.freezeSource,
  });

  static const schemaVersion = 1;
  static const authority = 'advisory';

  final RunningTargetStepScope scope;
  final DateTime frozenAtUtc;
  final RunningTargetFreezeSource freezeSource;

  Map<String, Object?> toJson();

  Map<String, Object> commonJson(String state) => <String, Object>{
    'schema_version': schemaVersion,
    'state': state,
    'authority': authority,
    'scope': scope.toJson(),
    'frozen_at_utc': frozenAtUtc.toIso8601String(),
    'freeze_source': _freezeSourceToken(freezeSource),
  };
}

class FrozenCalculatedRunningTarget extends FrozenRunningTargetSnapshot {
  const FrozenCalculatedRunningTarget._({
    required super.scope,
    required super.frozenAtUtc,
    required super.freezeSource,
    required this.policy,
    required this.benchmark,
    required this.exactRange,
  });

  final FrozenRunningPolicyReference policy;
  final RunningBenchmarkEvidence benchmark;
  final ExactCanonicalPaceRange exactRange;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...commonJson('calculated'),
    'policy': policy.toJson(),
    'benchmark': _benchmarkJson(benchmark),
    'calculated_exact_range': <String, Object>{
      'unit': 'milliseconds_per_kilometre',
      'faster': _exactPaceJson(exactRange.fasterPace),
      'slower': _exactPaceJson(exactRange.slowerPace),
    },
  };
}

class FrozenIntentOnlyRunningTarget extends FrozenRunningTargetSnapshot {
  const FrozenIntentOnlyRunningTarget._({
    required super.scope,
    required super.frozenAtUtc,
    required super.freezeSource,
    required this.reason,
    this.policy,
  });

  final RunningIntentOnlyReason reason;
  final FrozenRunningPolicyReference? policy;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...commonJson('intent_only'),
    'reason': _intentOnlyReasonToken(reason),
    if (policy != null) 'policy': policy!.toJson(),
  };
}

class RunningTargetSnapshotFreezer {
  const RunningTargetSnapshotFreezer({
    this.selector = const RunningBenchmarkSelector(),
  });

  final RunningBenchmarkSelector selector;

  FrozenRunningTargetSnapshot freeze({
    FrozenRunningTargetSnapshot? existing,
    required RunningPaceCalculationPolicy? authoredPolicy,
    required RunningTargetStepScope scope,
    required String athleteId,
    required RunningCivilDate evaluationLocalDate,
    required String ianaTimezone,
    required Iterable<RunningBenchmarkEvidence> evidence,
    required DateTime commitmentAtUtc,
    required RunningTargetFreezeSource freezeSource,
  }) {
    // The occurrence-owned stored snapshot wins on every retry. New evidence,
    // policy values, clocks, or callers cannot recalculate it.
    if (existing != null) return existing;
    if (!commitmentAtUtc.isUtc) {
      throw const RunningTargetSnapshotException(
        'non_utc_freeze_timestamp',
        'Execution commitment timestamp must be UTC.',
      );
    }

    if (authoredPolicy == null) {
      return FrozenIntentOnlyRunningTarget._(
        scope: scope,
        frozenAtUtc: commitmentAtUtc,
        freezeSource: freezeSource,
        reason: RunningIntentOnlyReason.noAuthoredTargetPolicy,
      );
    }

    final policy = FrozenRunningPolicyReference.fromPolicy(authoredPolicy);
    final selection = selector.select(
      policy: authoredPolicy,
      athleteId: athleteId,
      evaluationLocalDate: evaluationLocalDate,
      ianaTimezone: ianaTimezone,
      evidence: evidence,
    );
    if (selection case RunningBenchmarkSelectionFailure(:final code)) {
      return FrozenIntentOnlyRunningTarget._(
        scope: scope,
        frozenAtUtc: commitmentAtUtc,
        freezeSource: freezeSource,
        reason: _intentOnlyReason(code),
        policy: policy,
      );
    }

    final selected = selection as RunningBenchmarkSelectionSuccess;
    return FrozenCalculatedRunningTarget._(
      scope: scope,
      frozenAtUtc: commitmentAtUtc,
      freezeSource: freezeSource,
      policy: policy,
      benchmark: selected.evidence,
      exactRange: authoredPolicy.calculateRange(selected.evidence),
    );
  }
}

RunningIntentOnlyReason _intentOnlyReason(
  RunningBenchmarkSelectionFailureCode code,
) {
  return switch (code) {
    RunningBenchmarkSelectionFailureCode.noEvidence =>
      RunningIntentOnlyReason.noEvidence,
    RunningBenchmarkSelectionFailureCode.noAthleteScopedEvidence =>
      RunningIntentOnlyReason.noAthleteScopedEvidence,
    RunningBenchmarkSelectionFailureCode.duplicateEvidenceIdentity =>
      RunningIntentOnlyReason.duplicateEvidenceIdentity,
    RunningBenchmarkSelectionFailureCode.noTimezoneMatchedEvidence =>
      RunningIntentOnlyReason.noTimezoneMatchedEvidence,
    RunningBenchmarkSelectionFailureCode.noEligibleCompletedTest =>
      RunningIntentOnlyReason.noEligibleCompletedTest,
    RunningBenchmarkSelectionFailureCode.noFreshEvidence =>
      RunningIntentOnlyReason.noFreshEvidence,
  };
}

Map<String, Object> _benchmarkJson(RunningBenchmarkEvidence benchmark) {
  return <String, Object>{
    'evidence_id': benchmark.evidenceId,
    'athlete_id': benchmark.athleteId,
    'distance_metres': benchmark.distanceMetres,
    // This is elapsed time including pauses, never moving time.
    'elapsed_duration_milliseconds': benchmark.elapsedDurationMilliseconds,
    'duration_basis': 'elapsed_including_pauses',
    'local_test_date': benchmark.localTestDate.toString(),
    'iana_timezone': benchmark.ianaTimezone,
    'source_kind': _sourceKindToken(benchmark.provenance.sourceKind),
    'source_reference': benchmark.provenance.sourceReference,
    'declaration': _declarationToken(benchmark.declaration),
    'surface_context': _surfaceContextToken(benchmark.surfaceContext),
  };
}

String _freezeSourceToken(RunningTargetFreezeSource source) {
  return switch (source) {
    RunningTargetFreezeSource.inAppStart => 'in_app_start',
    RunningTargetFreezeSource.deviceExport => 'device_export',
  };
}

String _declarationToken(RunningBenchmarkDeclaration declaration) {
  return switch (declaration) {
    RunningBenchmarkDeclaration.completedFiveKilometreTest =>
      'completed_five_kilometre_test',
    RunningBenchmarkDeclaration.fiveKilometreActivity =>
      'five_kilometre_activity',
  };
}

String _sourceKindToken(RunningBenchmarkSourceKind sourceKind) {
  return switch (sourceKind) {
    RunningBenchmarkSourceKind.cohort => 'cohort',
    RunningBenchmarkSourceKind.manual => 'manual',
    RunningBenchmarkSourceKind.external => 'external',
  };
}

String _surfaceContextToken(RunningBenchmarkSurfaceContext context) {
  return switch (context) {
    RunningBenchmarkSurfaceContext.outdoor => 'outdoor',
    RunningBenchmarkSurfaceContext.treadmill => 'treadmill',
    RunningBenchmarkSurfaceContext.unspecified => 'unspecified',
  };
}

String _roundingToken(CanonicalPaceRounding rounding) {
  return switch (rounding) {
    CanonicalPaceRounding.down => 'down',
    CanonicalPaceRounding.nearest => 'nearest',
    CanonicalPaceRounding.up => 'up',
  };
}

String _intentOnlyReasonToken(RunningIntentOnlyReason reason) {
  return switch (reason) {
    RunningIntentOnlyReason.noAuthoredTargetPolicy =>
      'no_authored_target_policy',
    RunningIntentOnlyReason.noEvidence => 'no_evidence',
    RunningIntentOnlyReason.noAthleteScopedEvidence =>
      'no_athlete_scoped_evidence',
    RunningIntentOnlyReason.duplicateEvidenceIdentity =>
      'duplicate_evidence_identity',
    RunningIntentOnlyReason.noTimezoneMatchedEvidence =>
      'no_timezone_matched_evidence',
    RunningIntentOnlyReason.noEligibleCompletedTest =>
      'no_eligible_completed_test',
    RunningIntentOnlyReason.noFreshEvidence => 'no_fresh_evidence',
  };
}

Map<String, Object> _exactPaceJson(ExactCanonicalPace pace) {
  return <String, Object>{
    'numerator': pace.numeratorMillisecondsPerKilometre,
    'denominator': pace.denominator,
  };
}
