import 'package:cohort_platform/features/coach_studio/coach_studio_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes postgres schema errors for coach UI', () {
    expect(
      CoachStudioErrorMessages.fromObject(
        Exception(
          'PostgrestException(message: column protocol_steps.step_id does not exist, code: 42703)',
        ),
      ),
      'This panel could not load right now. Please try again.',
    );
  });
}
