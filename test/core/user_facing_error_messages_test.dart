import 'package:cohort_platform/core/errors/user_facing_error_messages.dart';
import 'package:cohort_platform/core/presentation/athlete_safe_error_presenter.dart';
import 'package:cohort_platform/core/services/authenticated_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('UserFacingErrorMessages', () {
    test('maps authenticated identity failures', () {
      expect(
        UserFacingErrorMessages.from(
          const AuthenticatedIdentityException(
            'Coach access is required to open Coach Studio.',
          ),
        ),
        'Coach access is required to open Coach Studio.',
      );
    });

    test('maps PostgREST statement timeout to athlete-safe copy', () {
      expect(
        UserFacingErrorMessages.from(
          PostgrestException(
            message: 'canceling statement due to statement timeout',
            code: '57014',
          ),
        ),
        UserFacingErrorMessages.timeout,
      );
    });

    test('maps permission denied', () {
      expect(
        UserFacingErrorMessages.from(Exception('permission denied for table x')),
        'You do not have permission to perform this action.',
      );
    });

    test('maps invite failures', () {
      expect(
        UserFacingErrorMessages.from(Exception('Invite expired')),
        'This invitation is invalid or has expired.',
      );
    });

    test('maps session save failures', () {
      expect(
        UserFacingErrorMessages.sessionSaveFailure(
          Exception('PerformanceRecordStoreException: complete record failed'),
        ),
        UserFacingErrorMessages.saveFailure,
      );
    });

    test('AthleteSafeErrorPresenter returns safe message for PostgREST timeout', () {
      final message = AthleteSafeErrorPresenter.message(
        PostgrestException(message: 'timeout', code: '57014'),
        logTag: 'test',
      );
      expect(message, UserFacingErrorMessages.timeout);
    });

    test('does not include raw uuid-like tokens in generic fallback', () {
      final message = UserFacingErrorMessages.from(
        Exception('unexpected server response'),
        fallback: UserFacingErrorMessages.genericFailure,
      );
      expect(message, UserFacingErrorMessages.genericFailure);
      expect(message.contains('00000000'), isFalse);
    });
  });
}
