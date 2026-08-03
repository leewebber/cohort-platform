import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 1.7A–1.7C architecture guards for athlete-controlled scheduling.
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
    expect(source.toLowerCase(), contains('skip is not completion'));
    expect(source.contains('ProgrammedSessionKey'), isTrue);
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
      'ensure_programme_schedule_projection',
      'ProgrammeScheduleRestoreService',
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

  test('1.7B preview owner remains compute-only and repository-free', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/services/'
      'programme_scheduling_preview_engine.dart',
    ).readAsStringSync();
    expect(source.contains('compute-only'), isTrue);
    expect(source.contains('Never mutates the input projection'), isTrue);
    for (final token in const [
      'supabase',
      'Supabase',
      'Repository',
      'ensure_programme_schedule',
      'AthleteLocalRepository',
      'CoachBrain',
      'AdaptiveProgression',
      'AthleteProgrammeCompletionService',
    ]) {
      expect(source.contains(token), isFalse, reason: token);
    }
  });

  test('1.7C permits persistence adapter and restore service only', () {
    expect(
      File(
        '$root/lib/features/programme/services/'
        'programme_schedule_projection_supabase_store.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/lib/features/programme/services/'
        'programme_schedule_restore_service.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/supabase/migrations/'
        '20260803120000_add_programme_schedule_projection.sql',
      ).existsSync(),
      isTrue,
    );
  });

  test('no Move/Swap/Push/Skip apply service and no generic writer', () {
    final candidates = [
      'lib/application/scheduling',
      'lib/features/scheduling',
      'lib/application/programme_scheduling',
      'lib/features/programme/services/athlete_programme_scheduling_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_apply_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_mutation_service.dart',
      'lib/features/programme/services/programme_schedule_apply_service.dart',
    ];
    for (final path in candidates) {
      final entity = File('$root/$path').existsSync()
          ? File('$root/$path')
          : Directory('$root/$path');
      expect(entity.existsSync(), isFalse, reason: path);
    }

    final store = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_projection_store.dart',
    ).readAsStringSync();
    expect(store.contains('ensureBaseline'), isTrue);
    for (final token in const [
      'saveSchedule',
      'replaceProjection',
      'persistPreview',
      'writeOccurrences',
      'updateScheduledDate',
      'applySchedulingOperation',
    ]) {
      expect(store.contains(token), isFalse, reason: token);
    }
  });

  test('only designated persistence adapter knows Supabase for scheduling', () {
    final domainFiles = Directory('$root/lib/domain/programme_scheduling')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source.contains('supabase'), isFalse, reason: file.path);
      expect(source.contains('SupabaseService'), isFalse, reason: file.path);
    }

    final adapter = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_projection_supabase_store.dart',
    ).readAsStringSync();
    expect(adapter.contains('SupabaseService'), isTrue);
    expect(adapter.contains('ensure_programme_schedule_projection'), isTrue);
    expect(adapter.contains('apply_programme_schedule_operation'), isFalse);
  });

  test('dates remain outside stable identity', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/value_objects/'
      'scheduled_occurrence_identity.dart',
    ).readAsStringSync();
    expect(source.contains('scheduledDate'), isFalse);
    expect(source.contains('never part of identity'), isTrue);
  });

  test('Plan Package models unchanged by scheduling persistence', () {
    final domainFiles = Directory('$root/lib/domain/programme_scheduling')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source.contains('class PlanPackage'), isFalse, reason: file.path);
      expect(source.contains('schedulingPermission'), isFalse, reason: file.path);
    }
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
