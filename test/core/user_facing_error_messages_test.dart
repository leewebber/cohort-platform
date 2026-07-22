import 'package:cohort_platform/core/errors/user_facing_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserFacingErrorMessages', () {
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
        'Your session could not be saved. Your progress has not been advanced.',
      );
    });

    test('does not include raw uuid-like tokens in generic fallback', () {
      final message = UserFacingErrorMessages.from(
        Exception('unexpected server response'),
        fallback: 'Something went wrong. Please try again.',
      );
      expect(message, 'Something went wrong. Please try again.');
      expect(message.contains('00000000'), isFalse);
    });
  });
}
