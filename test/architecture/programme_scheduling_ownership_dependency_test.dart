import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sprint 1.7A architecture guards for athlete-controlled scheduling.
///
/// Locks the contract boundary before any product scheduling implementation.
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
    // Skip must not equal completion.
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

  test('1.7A must not introduce production scheduling mutate services yet', () {
    final candidates = [
      'lib/application/scheduling',
      'lib/features/scheduling',
      'lib/application/programme_scheduling',
      'lib/features/programme/services/athlete_programme_scheduling_service.dart',
    ];
    for (final path in candidates) {
      final entity = File('$root/$path').existsSync()
          ? File('$root/$path')
          : Directory('$root/$path');
      expect(
        entity.existsSync(),
        isFalse,
        reason:
            'Sprint 1.7A is contract-only; unexpected production path: $path',
      );
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
