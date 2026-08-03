import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layer ownership and module presence (Phase 4.5 freeze).
void main() {
  final root = Directory.current.path.contains('cohort_platform')
      ? Directory.current.path
      : _repoRoot(Directory.current);

  test('planning pipeline modules exist under lib/planning', () {
    final required = [
      'lib/planning/planning_engine_service.dart',
      'lib/planning/session_blueprint/deterministic_session_blueprint_generator.dart',
      'lib/planning/exercise_policy/deterministic_exercise_policy_engine.dart',
      'lib/planning/prescription/deterministic_prescription_engine.dart',
      'lib/planning/orchestration/coach_brain_service.dart',
    ];
    for (final path in required) {
      expect(File('$root/$path').existsSync(), isTrue, reason: path);
    }
  });

  test('application ports exist for each engine stage', () {
    final ports = [
      'lib/application/ports/planning_engine_reader.dart',
      'lib/application/ports/session_blueprint_generator.dart',
      'lib/application/ports/exercise_policy_engine.dart',
      'lib/application/ports/prescription_engine.dart',
      'lib/application/ports/coach_brain_orchestrator.dart',
    ];
    for (final path in ports) {
      expect(File('$root/$path').existsSync(), isTrue, reason: path);
    }
  });

  test('canonical architecture ADRs 023-027 exist', () {
    const ids = ['023', '024', '025', '026', '027'];
    final dir = Directory('$root/docs/architecture/adrs');
    for (final id in ids) {
      final match = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('ADR-$id-'))
          .toList();
      expect(match, isNotEmpty, reason: 'ADR-$id');
    }
  });

  test('Phase 1 programme adaptation authority contract exists', () {
    final path =
        '$root/docs/architecture/Athlete_Programme_Acceptance_Gated_Adaptation_v1.md';
    expect(File(path).existsSync(), isTrue, reason: path);
  });

  test('Sprint 1.6B–1.6E programme adaptation modules and hardening fixtures exist',
      () {
    final required = [
      'lib/application/adaptation/plan_package_session_adaptation_adapter.dart',
      'lib/application/adaptation/programme_adaptation_proposal_service.dart',
      'lib/application/adaptation/programme_adaptation_proposal_mapper.dart',
      'lib/application/adaptation/programme_adaptation_acceptance_service.dart',
      'lib/application/adaptation/programme_adaptation_reversion_service.dart',
      'lib/application/adaptation/programme_adaptation_plan_applier.dart',
      'lib/features/adaptation/models/programme_adaptation_proposal.dart',
      'lib/features/home/services/programme_adapt_flow.dart',
      'lib/core/widgets/programme_adaptation_revert_sheet.dart',
      'test/application/adaptation/programme_adaptation_hardening_1_6e_test.dart',
      'test/support/programme_adaptation_coaching_recognition_fixture.dart',
    ];
    for (final path in required) {
      expect(File('$root/$path').existsSync(), isTrue, reason: path);
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
