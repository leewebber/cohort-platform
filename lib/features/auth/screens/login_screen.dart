import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_view_state.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_scaffold.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;

    final status = widget.controller.state.status;
    if (status == AuthStatus.authenticated ||
        status == AuthStatus.profileRequired) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first.')),
      );
      return;
    }

    await widget.controller.requestPasswordReset(email: email);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isLoading = state.status == AuthStatus.loading;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue training and coaching in Cohort.',
      footer: TextButton(
        onPressed: isLoading
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SignUpScreen(controller: widget.controller),
                  ),
                );
              },
        child: const Text('Create an account'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFormField(
            label: 'EMAIL',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          const SizedBox(height: CohortSpacing.md),
          AuthFormField(
            label: 'PASSWORD',
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autocorrect: false,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          if (state.status == AuthStatus.awaitingEmailConfirmation) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Check your email to confirm your account, then sign in.',
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              state.errorMessage!,
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: isLoading ? 'Signing in…' : 'Sign in',
            onPressed: isLoading ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}
