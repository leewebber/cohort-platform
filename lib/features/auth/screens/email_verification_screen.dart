import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_view_state.dart';
import '../widgets/auth_scaffold.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final email = state.pendingEmail ?? 'your email address';
    final isLoading = state.status == AuthStatus.loading;

    return AuthScaffold(
      title: 'Check your email',
      subtitle:
          'Verify your email, then return to Cohort to finish setting up your account.',
      footer: TextButton(
        onPressed: isLoading
            ? null
            : () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(controller: controller),
                  ),
                );
              },
        child: const Text('Back to sign in'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We sent a verification link to',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            email,
            style: CohortTextStyles.cardTitle,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(
            'Open the link in your email, then sign in to continue.',
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              state.errorMessage!,
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: isLoading ? 'Sending…' : 'Resend verification email',
            onPressed: isLoading ? () {} : controller.resendVerificationEmail,
          ),
        ],
      ),
    );
  }
}
