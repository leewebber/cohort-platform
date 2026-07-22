import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/section_title.dart';
import '../controllers/auth_controller.dart';
import '../services/current_user_session.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final profile = CurrentUserSession.requireInstance.profile;
    final roles = <String>[
      if (profile.isAthlete) 'Athlete',
      if (profile.isCoach) 'Coach',
    ].join(' • ');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const SectionTitle('Account'),
              const SizedBox(height: CohortSpacing.md),
              Text(profile.displayName, style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              Text('Roles: $roles', style: CohortTextStyles.body),
              const Spacer(),
              CohortButton(
                label: 'Sign out',
                onPressed: () async {
                  await controller.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
