import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_view_state.dart';
import '../models/user_role.dart';
import '../widgets/auth_form_field.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/role_selection_chips.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Set<UserRole> _selectedRoles = {UserRole.athlete, UserRole.coach};

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.controller.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _displayNameController.text,
      roles: _selectedRoles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isLoading = state.status == AuthStatus.loading;

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Set up your Cohort profile to train and coach.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFormField(
            label: 'DISPLAY NAME',
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: CohortSpacing.md),
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
          const SizedBox(height: CohortSpacing.lg),
          Text('YOUR ROLES', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.sm),
          RoleSelectionChips(
            selectedRoles: _selectedRoles,
            onChanged: (roles) => setState(() => _selectedRoles = roles),
          ),
          if (state.status == AuthStatus.awaitingEmailConfirmation) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Account created. Check your email to confirm, then sign in.',
              style: CohortTextStyles.small.copyWith(color: CohortColors.success),
            ),
          ],
          if (state.errorMessage != null &&
              state.status != AuthStatus.awaitingEmailConfirmation) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              state.errorMessage!,
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: isLoading ? 'Creating account…' : 'Create account',
            onPressed: isLoading ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}
