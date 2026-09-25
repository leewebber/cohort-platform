import 'dart:io';

import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apollo Plan Package hash remains unchanged', () {
    final yaml = File(
      'tool/programmes/apollo_build_12_week_v1.plan-package.yaml',
    ).readAsStringSync();
    final result = const PlanPackageCompiler().compile(yaml);
    expect(result.isValid, isTrue, reason: result.issues.toString());
    expect(
      result.contentHashSha256,
      '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
    );
  });

  test('projection does not mutate timer configuration', () {
    const configuration = TimerConfiguration(
      workSeconds: 180,
      restSeconds: 90,
      rounds: 4,
    );
    const projector = RunningWorkoutProjector();
    projector.project(
      format: WorkoutFormat.intervals,
      configuration: configuration,
    );
    expect(configuration.workSeconds, 180);
    expect(configuration.restSeconds, 90);
    expect(configuration.rounds, 4);
  });
}
