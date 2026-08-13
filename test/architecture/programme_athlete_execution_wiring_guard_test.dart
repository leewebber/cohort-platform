import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('programme Home uses canonical block-aware execution launcher', () {
    final source = File(
      'lib/features/home/widgets/athlete_programme_today_section.dart',
    ).readAsStringSync();

    expect(source, contains('ProgrammeSessionExecutionLauncher'));
    expect(source, contains('_executionLauncher.launch('));
    expect(source, isNot(contains('WorkoutPlayerLauncher')));
    expect(source, isNot(contains('launchWithPlan(')));
  });

  test(
    'programme execution bridge carries stable session id to ActiveSession',
    () {
      final source = File(
        'lib/features/session/services/programme_session_execution_launcher.dart',
      ).readAsStringSync();

      expect(source, contains('ProgrammeSlotOutcomeStore'));
      expect(source, contains('createOrResumeTrainingSession'));
      expect(source, contains('launchActiveSessionWithPlan'));
      expect(source, contains('trainingSessionId: trainingSession.id'));
      expect(source, isNot(contains('plan_package')));
      expect(source, isNot(contains('exercise_knowledge')));
      expect(source, isNot(contains('substitution')));
    },
  );

  test(
    'programme completion checks authority before local success projection',
    () {
      final source = File(
        'lib/features/performance/screens/session_finish_review_screen.dart',
      ).readAsStringSync();
      final failureCheck = source.indexOf('if (result.progressionFailed)');
      final localCompletion = source.indexOf(
        'widget.executionController.completeSession',
      );

      expect(failureCheck, greaterThan(-1));
      expect(localCompletion, greaterThan(failureCheck));
      expect(source, contains('programmeCompletion?.isSuccess != true'));
    },
  );
}
