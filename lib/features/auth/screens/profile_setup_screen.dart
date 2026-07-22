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

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _displayNameController = TextEditingController();
  Set<UserRole> _selectedRoles = {UserRole.athlete};

  @override
  void initState() {
    super.initState();
    final state = widget.controller.state;
    final pendingName = state.pendingDisplayName;
    if (pendingName != null && pendingName.trim().isNotEmpty) {
      _displayNameController.text = pendingName.trim();
    }
    if (state.pendingRoles != null && state.pendingRoles!.isNotEmpty) {
      _selectedRoles = Set<UserRole>.from(state.pendingRoles!);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await widget.controller.completeProfile(
      displayName: _displayNameController.text,
      roles: _selectedRoles,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final isLoading = state.status == AuthStatus.loading;

    return AuthScaffold(
      title: 'Finish setup',
      subtitle: 'Tell us how you will use Cohort.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFormField(
            label: 'DISPLAY NAME',
            controller: _displayNameController,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text('YOUR ROLES', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'Select all that apply.',
            style: CohortTextStyles.small.copyWith(color: CohortColors.textSecondary),
          ),
          const SizedBox(height: CohortSpacing.sm),
          RoleSelectionChips(
            selectedRoles: _selectedRoles,
            onChanged: (roles) => setState(() => _selectedRoles = roles),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              state.errorMessage!,
              style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: isLoading ? 'Saving…' : 'Continue',
            onPressed: isLoading ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}
