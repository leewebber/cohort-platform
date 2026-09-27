import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vectors =
      jsonDecode(
            File(
              'test/running_workout/fixtures/running_pace_b2_golden_vectors.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('selection golden vectors match the pure-Dart authority', () {
    const selector = RunningBenchmarkSelector();
    for (final raw in (vectors['selection_cases'] as List<dynamic>)) {
      final vector = raw as Map<String, dynamic>;
      final result = selector.select(
        policy: _policy(vector['policy'] as Map<String, dynamic>),
        athleteId: vector['athlete_id'] as String,
        evaluationLocalDate: _date(vector['evaluation_local_date'] as String),
        ianaTimezone: vector['iana_timezone'] as String,
        evidence: (vector['evidence'] as List<dynamic>)
            .map((item) => _evidence(item as Map<String, dynamic>))
            .toList(growable: false),
      );
      final actual = switch (result) {
        RunningBenchmarkSelectionSuccess success => <String, dynamic>{
          'status': 'success',
          'selected_evidence_id': success.evidence.evidenceId,
          'age_local_civil_days': success.ageLocalCivilDays,
        },
        RunningBenchmarkSelectionFailure failure => <String, dynamic>{
          'status': 'failure',
          'code': failure.code.name,
        },
      };
      expect(actual, vector['expected'], reason: vector['id'] as String);
    }
  });

  test(
    'calculation golden vectors retain exact fractions and display pace',
    () {
      const calculator = FiveKilometreBenchmarkSpeedCalculator();
      for (final raw in (vectors['calculation_cases'] as List<dynamic>)) {
        final vector = raw as Map<String, dynamic>;
        final range = calculator.calculateRange(
          benchmarkDurationMilliseconds:
              vector['benchmark_duration_milliseconds'] as int,
          minimumSpeedBasisPoints: vector['minimum_speed_basis_points'] as int,
          maximumSpeedBasisPoints: vector['maximum_speed_basis_points'] as int,
        );
        final rounding = _rounding(vector['rounding_direction'] as String);
        final increment = vector['rounding_increment_milliseconds'] as int;
        final actual = <String, dynamic>{
          'status': 'success',
          'faster_pace': _pace(range.fasterPace, increment, rounding),
          'slower_pace': _pace(range.slowerPace, increment, rounding),
        };
        expect(actual, vector['expected'], reason: vector['id'] as String);
      }
    },
  );
}

RunningPaceCalculationPolicy _policy(Map<String, dynamic> json) {
  final eligibility = json['benchmark_eligibility'] as Map<String, dynamic>;
  final rounding = json['display_rounding'] as Map<String, dynamic>;
  return RunningPaceCalculationPolicy(
    policyId: json['policy_id'] as String,
    policyVersion: json['policy_version'] as int,
    methodId: json['method_id'] as String,
    methodVersion: json['method_version'] as int,
    benchmarkEligibility: RunningBenchmarkEligibilityRules(
      cohortCompletedTestsEligible:
          eligibility['cohort_completed_tests_eligible'] as bool,
      manualCompletedTestsEligible:
          eligibility['manual_completed_tests_eligible'] as bool,
      externalCompletedTestsEligible:
          eligibility['external_completed_tests_eligible'] as bool,
    ),
    freshnessLocalCivilDays: json['freshness_local_civil_days'] as int,
    minimumSpeedBasisPoints: json['minimum_speed_basis_points'] as int,
    maximumSpeedBasisPoints: json['maximum_speed_basis_points'] as int,
    displayRounding: RunningPaceDisplayRoundingPolicy(
      incrementMillisecondsPerKilometre:
          rounding['increment_milliseconds_per_kilometre'] as int,
      direction: _rounding(rounding['direction'] as String),
    ),
  );
}

RunningBenchmarkEvidence _evidence(Map<String, dynamic> json) {
  return RunningBenchmarkEvidence(
    evidenceId: json['evidence_id'] as String,
    athleteId: json['athlete_id'] as String,
    distanceMetres: json['distance_metres'] as int,
    elapsedDurationMilliseconds: json['elapsed_duration_milliseconds'] as int,
    localTestDate: _date(json['local_test_date'] as String),
    ianaTimezone: json['iana_timezone'] as String,
    provenance: RunningBenchmarkProvenance(
      sourceKind: switch (json['source_kind']) {
        'cohort' => RunningBenchmarkSourceKind.cohort,
        'manual' => RunningBenchmarkSourceKind.manual,
        'external' => RunningBenchmarkSourceKind.external,
        _ => throw StateError('unsupported golden source'),
      },
      sourceReference: json['source_reference'] as String,
    ),
    declaration: switch (json['declaration']) {
      'completed_five_kilometre_test' =>
        RunningBenchmarkDeclaration.completedFiveKilometreTest,
      'five_kilometre_activity' =>
        RunningBenchmarkDeclaration.fiveKilometreActivity,
      _ => throw StateError('unsupported golden declaration'),
    },
    surfaceContext: switch (json['surface_context']) {
      'outdoor' => RunningBenchmarkSurfaceContext.outdoor,
      'treadmill' => RunningBenchmarkSurfaceContext.treadmill,
      'unspecified' => RunningBenchmarkSurfaceContext.unspecified,
      _ => throw StateError('unsupported golden context'),
    },
  );
}

RunningCivilDate _date(String value) {
  final parts = value.split('-').map(int.parse).toList(growable: false);
  return RunningCivilDate(year: parts[0], month: parts[1], day: parts[2]);
}

CanonicalPaceRounding _rounding(String value) => switch (value) {
  'down' => CanonicalPaceRounding.down,
  'nearest' => CanonicalPaceRounding.nearest,
  'up' => CanonicalPaceRounding.up,
  _ => throw StateError('unsupported golden rounding'),
};

Map<String, dynamic> _pace(
  ExactCanonicalPace pace,
  int increment,
  CanonicalPaceRounding rounding,
) => <String, dynamic>{
  'numerator_milliseconds_per_kilometre':
      pace.numeratorMillisecondsPerKilometre,
  'denominator': pace.denominator,
  'display_milliseconds_per_kilometre': pace.roundToIncrement(
    increment,
    rounding,
  ),
};
