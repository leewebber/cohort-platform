import 'package:cohort_platform/staging/s17_staging_journey_matrix.dart';
import 'package:cohort_platform/staging/s17_staging_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S17StagingRuntimeConfig', () {
    test('rejects production host marker', () {
      const config = S17StagingRuntimeConfig(
        enabled: true,
        supabaseUrl: 'https://otnhhdxstdnwccehacku.supabase.co',
        supabaseAnonKey: 'anon',
        athleteEmail:
            's17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid',
        athletePassword: 'x',
        athleteId: '11111111-1111-1111-1111-111111111111',
        assignmentId: '22222222-2222-2222-2222-222222222222',
        versionId: '33333333-3333-3333-3333-333333333333',
        packageHash: 'hash',
        runMarker: 's17_stage_20260803T000000Z_abcd1234',
        lineageCode: 'PROG-S13-ELIG',
      );
      expect(config.validationError(), contains('Production'));
    });

    test('rejects service_role in anon key', () {
      const config = S17StagingRuntimeConfig(
        enabled: true,
        supabaseUrl: 'https://tsbadngzgvsyfqjupkng.supabase.co',
        supabaseAnonKey: 'service_role_secret',
        athleteEmail:
            's17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid',
        athletePassword: 'x',
        athleteId: '11111111-1111-1111-1111-111111111111',
        assignmentId: '22222222-2222-2222-2222-222222222222',
        versionId: '33333333-3333-3333-3333-333333333333',
        packageHash: 'hash',
        runMarker: 's17_stage_20260803T000000Z_abcd1234',
        lineageCode: 'PROG-S13-ELIG',
      );
      expect(config.validationError(), contains('service_role'));
    });

    test('accepts valid Athlete D staging config', () {
      const config = S17StagingRuntimeConfig(
        enabled: true,
        supabaseUrl: 'https://tsbadngzgvsyfqjupkng.supabase.co',
        supabaseAnonKey: 'anon-public',
        athleteEmail:
            's17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid',
        athletePassword: 'x',
        athleteId: '11111111-1111-1111-1111-111111111111',
        assignmentId: '22222222-2222-2222-2222-222222222222',
        versionId: '33333333-3333-3333-3333-333333333333',
        packageHash: 'hash',
        runMarker: 's17_stage_20260803T000000Z_abcd1234',
        lineageCode: 'PROG-S13-ELIG',
      );
      expect(config.validationError(), isNull);
      final redacted = config.redactedIdentity();
      expect(redacted['run_marker'], startsWith('s17_stage_'));
      expect(redacted.values.join(' '), isNot(contains('anon-public')));
      expect(redacted.values.join(' '), isNot(contains('athlete.d@')));
    });

    test('disabled config fails closed', () {
      const config = S17StagingRuntimeConfig(
        enabled: false,
        supabaseUrl: '',
        supabaseAnonKey: '',
        athleteEmail: '',
        athletePassword: '',
        athleteId: '',
        assignmentId: '',
        versionId: '',
        packageHash: '',
        runMarker: '',
        lineageCode: 'PROG-S13-ELIG',
      );
      expect(config.validationError(), isNotNull);
    });
  });

  group('S17StagingJourneyMatrix', () {
    test(
      'includes A–K with required assertions for schedule and adaptation',
      () {
        expect(S17StagingJourneyMatrix.codes, [
          'A',
          'B',
          'C',
          'D',
          'E',
          'F',
          'G',
          'H',
          'I',
          'J',
          'K',
        ]);
        final byCode = {
          for (final j in S17StagingJourneyMatrix.journeys) j.code: j,
        };
        expect(
          byCode['F']!.requiredAssertions,
          contains('invalid_move_rejected_atomically'),
        );
        expect(
          byCode['G']!.requiredAssertions,
          contains('invalid_swap_rejected_atomically'),
        );
        expect(
          byCode['H']!.requiredAssertions,
          contains('invalid_push_rejected_atomically'),
        );
        expect(
          byCode['J']!.requiredAssertions,
          contains('undo_restores_prior_state'),
        );
        expect(
          byCode['D']!.requiredAssertions,
          contains('accept_requires_explicit_action'),
        );
        expect(
          byCode['C']!.requiredAssertions,
          contains('reference_does_not_rewrite_prescription'),
        );
        expect(
          byCode['K']!.requiredAssertions,
          contains('completion_bound_to_package_session'),
        );
      },
    );

    test('all result categories are represented', () {
      final labels = S17JourneyResult.values.map((e) => e.label).toSet();
      expect(labels, containsAll(['PASS', 'FAIL', 'BLOCKED', 'NOT RUN']));
      final notRun = S17StagingJourneyMatrix.allNotRun();
      expect(notRun.values.every((r) => r == S17JourneyResult.notRun), isTrue);
    });
  });
}
