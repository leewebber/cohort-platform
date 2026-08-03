import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 1.7A/1.7B architecture guards for athlete-controlled scheduling.
///
/// Permits pure domain + compute-only preview; forbids mutation/apply services.
void main() {
  final root = _repoRoot(Directory.current);

  test('Sprint 1.7A scheduling contract document exists', () {
    final path =
        '$root/docs/architecture/Athlete_Controlled_Programme_Scheduling_v1.md';
    expect(File(path).existsSync(), isTrue, reason: path);
    final source = File(path).readAsStringSync();
    expect(source.contains('Sprint 1.7A'), isTrue);
    expect(source.contains('Binding for Phase 1'), isTrue);
    expect(source.contains('Preview'), isTrue);
    expect(source.contains('Move'), isTrue);
    expect(source.contains('Swap'), isTrue);
    expect(source.contains('Push'), isTrue);
    expect(source.contains('Skip'), isTrue);
    expect(source.contains('Undo'), isTrue);
    expect(source.toLowerCase(), contains('skip is not completion'));
    expect(
      source.contains('ProgrammedSessionKey'),
      isTrue,
      reason: 'Stable authored identity required',
    );
    expect(
      source.contains('display label'),
      isTrue,
      reason: 'Must forbid display-label sole identity',
    );
  });

  test('scheduling contract forbids prescription and progression couplings', () {
    final source = File(
      '$root/docs/architecture/Athlete_Controlled_Programme_Scheduling_v1.md',
    ).readAsStringSync();
    for (final token in const [
      'Must **not** call adaptation pipeline',
      'Coach Brain',
      'Adaptive Progression',
      'never fabricates',
      'immutable prescription authority',
    ]) {
      expect(source.contains(token), isTrue, reason: 'missing boundary: $token');
    }
  });

  test('programme adaptation owners still forbid scheduling mutate APIs', () {
    final owners = [
      'lib/application/adaptation/programme_adaptation_proposal_service.dart',
      'lib/application/adaptation/programme_adaptation_acceptance_service.dart',
      'lib/application/adaptation/programme_adaptation_reversion_service.dart',
      'lib/features/home/services/programme_adapt_flow.dart',
    ];
    const forbidden = [
      'pushRight',
      'swapSession',
      'rescheduleProgramme',
      'AthleteControlledSchedule',
      'AdaptiveProgressionCoordinator',
      'AthleteProgrammeGenerationService',
      'CoachDecisionRouter',
    ];
    for (final path in owners) {
      final source = File('$root/$path').readAsStringSync();
      for (final token in forbidden) {
        expect(
          source.contains(token),
          isFalse,
          reason: '$path must not reference $token',
        );
      }
    }
  });

  test('1.7B permits pure scheduling domain and compute-only preview owner', () {
    final domainDir = Directory('$root/lib/domain/programme_scheduling');
    expect(domainDir.existsSync(), isTrue);
    final previewEngine = File(
      '$root/lib/domain/programme_scheduling/services/'
      'programme_scheduling_preview_engine.dart',
    );
    expect(previewEngine.existsSync(), isTrue);
    final source = previewEngine.readAsStringSync();
    expect(source.contains('compute-only'), isTrue);
    expect(source.contains('Never mutates the input projection'), isTrue);
  });

  test('schedule mutation/apply services still do not exist', () {
    final candidates = [
      'lib/application/scheduling',
      'lib/features/scheduling',
      'lib/application/programme_scheduling',
      'lib/features/programme/services/athlete_programme_scheduling_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_apply_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_mutation_service.dart',
      'lib/domain/programme_scheduling/repositories',
    ];
    for (final path in candidates) {
      final entity = File('$root/$path').existsSync()
          ? File('$root/$path')
          : Directory('$root/$path');
      expect(
        entity.existsSync(),
        isFalse,
        reason: 'Mutation/apply/persist path must not exist yet: $path',
      );
    }
  });

  test('preview engine has no forbidden couplings', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/services/'
      'programme_scheduling_preview_engine.dart',
    ).readAsStringSync();
    for (final token in const [
      'supabase',
      'Supabase',
      'package:cohort_platform/application/adaptation',
      'package:cohort_platform/features/home/services/programme_adapt',
      'CoachBrain',
      'CoachDecisionRouter',
      'AdaptiveProgression',
      'AthleteProgrammeCompletionService',
      'complete_programme_session',
      'PreparedSession',
      'Repository',
    ]) {
      expect(
        source.contains(token),
        isFalse,
        reason: 'preview engine must not reference $token',
      );
    }
  });

  test('scheduling domain does not alter Plan Package models', () {
    final domainFiles = Directory('$root/lib/domain/programme_scheduling')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(
        source.contains('class PlanPackage'),
        isFalse,
        reason: file.path,
      );
      expect(
        source.contains('schedulingPermission'),
        isFalse,
        reason: 'no package permission schema fields: ${file.path}',
      );
    }
  });

  test('Skip preview source never fabricates completion or actuals', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/services/'
      'programme_scheduling_preview_engine.dart',
    ).readAsStringSync();
    expect(source.contains('_previewSkip'), isTrue);
    expect(source.contains('ProgrammeScheduleDisposition.skipped'), isTrue);
    expect(source.contains('training_sessions'), isFalse);
    expect(source.contains('previousPerformance'), isFalse);
    expect(source.contains('fabricat'), isTrue);
  });

  test('dates are not part of scheduled occurrence identity', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/value_objects/'
      'scheduled_occurrence_identity.dart',
    ).readAsStringSync();
    expect(source.contains('scheduledDate'), isFalse);
    expect(source.contains('Date is never part of identity') ||
        source.contains('never part of identity'), isTrue);
  });
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return start.path;
    dir = dir.parent;
  }
}
