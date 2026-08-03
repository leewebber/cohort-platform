import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 1.7A–1.7D architecture guards for athlete-controlled scheduling.
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
      'apply_programme_schedule_operation',
      'ProgrammeScheduleApplyService',
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

  test('1.7D permits designated Move/Swap apply owners only', () {
    expect(
      File(
        '$root/lib/features/programme/services/'
        'programme_schedule_apply_service.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/lib/features/programme/services/'
        'programme_schedule_apply_supabase_store.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/lib/features/programme/screens/'
        'athlete_programme_schedule_screen.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/supabase/migrations/'
        '20260803140000_apply_programme_schedule_move_swap.sql',
      ).existsSync(),
      isTrue,
    );

    final applyService = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_apply_service.dart',
    ).readAsStringSync();
    for (final token in const [
      'saveSchedule',
      'replaceProjection',
      'writeOccurrences',
      'persistPreview',
      'setDisposition',
      'setCursor',
    ]) {
      expect(applyService.contains(token), isFalse, reason: token);
    }
    expect(applyService.contains('Undo remains unapplied'), isTrue);
    expect(applyService.contains('previewPush'), isTrue);
    expect(applyService.contains('previewSkip'), isTrue);
    expect(applyService.contains('pushCommandFromPreview'), isTrue);
    expect(applyService.contains('skipCommandFromPreview'), isTrue);

    final screen = File(
      '$root/lib/features/programme/screens/'
      'athlete_programme_schedule_screen.dart',
    ).readAsStringSync();
    expect(screen.contains('Preview push'), isTrue);
    expect(screen.contains('Preview skip'), isTrue);
    expect(screen.contains('Confirm undo'), isFalse);
    expect(screen.contains('ProgrammeSchedulingPushRequest'), isFalse);
    expect(screen.contains('previewPush'), isTrue);
    expect(screen.contains('previewSkip'), isTrue);
  });

  test('no generic projection writer and no separate Undo apply service', () {
    final forbiddenPaths = [
      'lib/application/scheduling',
      'lib/features/scheduling',
      'lib/application/programme_scheduling',
      'lib/features/programme/services/athlete_programme_scheduling_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_apply_service.dart',
      'lib/domain/programme_scheduling/services/programme_scheduling_mutation_service.dart',
      'lib/features/programme/services/programme_schedule_push_apply_service.dart',
      'lib/features/programme/services/programme_schedule_skip_apply_service.dart',
      'lib/features/programme/services/programme_schedule_undo_service.dart',
    ];
    for (final path in forbiddenPaths) {
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

  test('only designated adapters know Supabase RPCs for scheduling', () {
    final domainFiles = Directory('$root/lib/domain/programme_scheduling')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in domainFiles) {
      final source = file.readAsStringSync();
      expect(source.contains('supabase'), isFalse, reason: file.path);
      expect(source.contains('SupabaseService'), isFalse, reason: file.path);
    }

    final ensureAdapter = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_projection_supabase_store.dart',
    ).readAsStringSync();
    expect(ensureAdapter.contains('ensure_programme_schedule_projection'), isTrue);
    expect(
      ensureAdapter.contains('apply_programme_schedule_operation'),
      isFalse,
    );

    final applyAdapter = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_apply_supabase_store.dart',
    ).readAsStringSync();
    expect(applyAdapter.contains('SupabaseService'), isTrue);
    expect(
      applyAdapter.contains('apply_programme_schedule_operation'),
      isTrue,
    );
    expect(
      applyAdapter.contains('ensure_programme_schedule_projection'),
      isFalse,
    );

    final applyService = File(
      '$root/lib/features/programme/services/'
      'programme_schedule_apply_service.dart',
    ).readAsStringSync();
    expect(applyService.contains('SupabaseService'), isFalse);
    expect(applyService.contains('apply_programme_schedule_operation'), isFalse);
  });

  test('dates remain outside stable identity', () {
    final source = File(
      '$root/lib/domain/programme_scheduling/value_objects/'
      'scheduled_occurrence_identity.dart',
    ).readAsStringSync();
    expect(source.contains('scheduledDate'), isFalse);
    expect(source.contains('never part of identity'), isTrue);
  });

  test('Plan Package models unchanged by scheduling apply', () {
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

  test('1.7D migration grants Move/Swap apply and keeps Push/Skip unsupported', () {
    final sql = File(
      '$root/supabase/migrations/'
      '20260803140000_apply_programme_schedule_move_swap.sql',
    ).readAsStringSync();
    expect(
      sql.contains(
        'GRANT EXECUTE ON FUNCTION public.apply_programme_schedule_operation(JSONB) TO authenticated',
      ),
      isTrue,
    );
    expect(sql.contains("v_op IN ('push', 'skip', 'undo')"), isTrue);
    expect(sql.contains('client_nominated_projection_forbidden'), isTrue);
    expect(sql.contains('stale_preview_fingerprint'), isTrue);
    expect(sql.contains('cohort_scheduling_apply_fingerprint'), isTrue);
  });

  test('1.7E migration extends apply with Push/Skip and keeps Undo unsupported', () {
    final sql = File(
      '$root/supabase/migrations/'
      '20260803160000_apply_programme_schedule_push_skip.sql',
    ).readAsStringSync();
    expect(sql.contains("v_op NOT IN ('move', 'swap', 'push', 'skip')"), isTrue);
    expect(sql.contains("v_op = 'undo'"), isTrue);
    expect(sql.contains('client_nominated_projection_forbidden'), isTrue);
    expect(sql.contains("payload ? 'cursor_after'"), isTrue);
    expect(sql.contains("payload ? 'resulting_disposition'"), isTrue);
    expect(sql.contains('occurrence_not_current'), isTrue);
    expect(sql.contains('cohort.allow_materialisation_write'), isTrue);
    expect(sql.contains('programme_slot_outcomes'), isTrue);
    expect(
      File(
        '$root/supabase/tests/sql/gate_o_programme_schedule_push_skip.sql',
      ).existsSync(),
      isTrue,
    );
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
