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

      expect(source, contains('ProgrammeTrainingSessionStartStore'));
      expect(source, contains('createOrResumeTrainingSession'));
      expect(source, contains('launchActiveSessionWithPlan'));
      expect(source, contains('trainingSessionId: trainingSession.id'));
      expect(source, isNot(contains('TrainingSessionRepository')));
      expect(source, isNot(contains('markSessionStartedIfProgrammeBacked')));
      expect(source, isNot(contains('plan_package')));
      expect(source, isNot(contains('exercise_knowledge')));
      expect(source, isNot(contains('substitution')));
    },
  );

  test('provenance is checked before transactional start or execution', () {
    final source = File(
      'lib/features/session/services/programme_session_execution_launcher.dart',
    ).readAsStringSync();
    final provenanceCheck = source.indexOf('_validatePreparedIdentity(');
    final createOrResume = source.indexOf(
      'final trainingSession = await createOrResumeTrainingSession(',
    );
    final atomicStart = source.indexOf('_startStore.createOrResume');
    final activeLaunch = source.indexOf('launchActiveSessionWithPlan');

    expect(provenanceCheck, greaterThan(-1));
    expect(createOrResume, greaterThan(provenanceCheck));
    expect(activeLaunch, greaterThan(createOrResume));
    expect(atomicStart, greaterThan(activeLaunch));
    expect(source, contains('preparedHash != expectedHash'));
    expect(source, contains(r"RegExp(r'^[0-9a-f]{64}$')"));
  });

  test('completion rejects malformed provenance before draft persistence', () {
    final source = File(
      'lib/features/programme/services/'
      'athlete_programme_completion_service.dart',
    ).readAsStringSync();
    final hashCheck = source.indexOf('_canonicalPackageHash.hasMatch(hash)');
    final saveDraft = source.indexOf('_performanceStore.saveDraft');

    expect(hashCheck, greaterThan(-1));
    expect(saveDraft, greaterThan(hashCheck));
  });

  test('Active Session uses one injected save coordinator', () {
    final source = File(
      'lib/features/session/screens/active_session_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('widget.saveCoordinator ?? PerformanceRecordSaveCoordinator()'),
    );
    expect(
      source,
      isNot(
        contains('final _saveCoordinator = PerformanceRecordSaveCoordinator()'),
      ),
    );
    expect(source, contains('saveCoordinator: _saveCoordinator'));
  });

  test(
    'leaving Active Session saves before navigation and never completes',
    () {
      final source = File(
        'lib/features/session/screens/active_session_screen.dart',
      ).readAsStringSync();
      final leaveHandler = source.indexOf('Future<void> _returnToHome()');
      final save = source.indexOf('await _persistDraft()', leaveHandler);
      final pop = source.indexOf('Navigator.of(context).pop()', leaveHandler);

      expect(source, contains('PopScope('));
      expect(leaveHandler, greaterThan(-1));
      expect(save, greaterThan(leaveHandler));
      expect(pop, greaterThan(save));
      expect(
        source.substring(leaveHandler, source.indexOf('void _refresh()')),
        isNot(contains('completeSession')),
      );
    },
  );

  test('Finish remains eligibility-gated before review authority', () {
    final source = File(
      'lib/features/session/screens/active_session_screen.dart',
    ).readAsStringSync();

    expect(source, contains('SessionFinishEligibilityEvaluator'));
    expect(source, contains('onPressed: finishEligibility.canFinish'));
    expect(source, contains('? _finishSession'));
    expect(source, isNot(contains('allowIncomplete:')));
    expect(source, isNot(contains('Finish with incomplete blocks?')));
  });

  test('structured warm-up grouping never parses coach notes at runtime', () {
    final source = File(
      'lib/features/session/widgets/athlete/athlete_block_card.dart',
    ).readAsStringSync();

    expect(source, contains('executionGroup'));
    expect(source, isNot(contains('coachNotes.split')));
    expect(source, isNot(contains('RegExp')));
  });

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
