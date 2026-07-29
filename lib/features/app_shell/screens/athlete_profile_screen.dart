import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/services/current_user_session.dart';
import '../../beta_support/beta_support_screen.dart';
import '../../performance/screens/training_history_screen.dart';

/// Athlete Profile — settings and identity (not founder tools).
class AthleteProfileScreen extends StatelessWidget {
  const AthleteProfileScreen({super.key, this.authController});

  final AuthController? authController;

  String get _athleteId =>
      AthleteProfileSession.profile?.athleteId ??
      CurrentUserSession.maybeInstance?.athleteId ??
      'athlete.local';

  String get _displayName =>
      AthleteProfileSession.profile?.displayName ??
      CurrentUserSession.maybeInstance?.profile.displayName ??
      'Athlete';

  @override
  Widget build(BuildContext context) {
    final profile = AthleteProfileSession.profile;
    final session = CurrentUserSession.maybeInstance;

    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CohortSpacing.xl,
            CohortSpacing.md,
            CohortSpacing.xl,
            CohortSpacing.xxl,
          ),
          children: [
            Text('PROFILE', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.md),
            Text(_displayName, style: CohortTextStyles.h1),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Who you are, and how your account is configured.',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.xl),
            _SectionHeader('Account'),
            _ProfileRow(
              title: 'Display name',
              subtitle: _displayName,
            ),
            if (authController?.currentEmail != null)
              _ProfileRow(
                title: 'Email',
                subtitle: authController!.currentEmail!,
              ),
            const SizedBox(height: CohortSpacing.lg),
            _SectionHeader('Athlete Profile'),
            _ProfileRow(
              title: 'Athlete ID',
              subtitle: _athleteId,
            ),
            if (profile != null) ...[
              _ProfileRow(
                title: 'Goals',
                subtitle: profile.primaryGoal.label,
              ),
              _ProfileRow(
                title: 'Equipment',
                subtitle: profile.availableEquipment.isEmpty
                    ? 'Not set yet'
                    : profile.availableEquipment.join(', '),
              ),
              _ProfileRow(
                title: 'Training Preferences',
                subtitle:
                    '${profile.trainingDaysPerWeek} days / week · '
                    '${profile.preferredSessionDurationMinutes} min',
              ),
            ] else
              const _ProfileRow(
                title: 'Goals & preferences',
                subtitle: 'Complete onboarding to configure your profile.',
              ),
            const SizedBox(height: CohortSpacing.lg),
            _SectionHeader('Connected Devices'),
            const _ProfileRow(
              title: 'Wearables',
              subtitle: 'Coming later',
              muted: true,
            ),
            const SizedBox(height: CohortSpacing.lg),
            _SectionHeader('History'),
            CohortCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TrainingHistoryScreen(athleteId: _athleteId),
                  ),
                );
              },
              child: const _ProfileRow(
                title: 'Training History',
                subtitle:
                    'Review completed sessions and performance records.',
                showChevron: true,
              ),
            ),
            const SizedBox(height: CohortSpacing.lg),
            _SectionHeader('Support'),
            CohortCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BetaSupportScreen(),
                  ),
                );
              },
              child: const _ProfileRow(
                title: 'Help & feedback',
                subtitle: 'Report a problem or share feedback.',
                showChevron: true,
              ),
            ),
            if (session != null && authController != null) ...[
              const SizedBox(height: CohortSpacing.xxl),
              CohortButton(
                label: 'SIGN OUT',
                variant: CohortButtonVariant.secondary,
                onPressed: () async {
                  await authController!.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Text(label.toUpperCase(), style: CohortTextStyles.sectionLabel),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.title,
    required this.subtitle,
    this.muted = false,
    this.showChevron = false,
  });

  final String title;
  final String subtitle;
  final bool muted;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CohortTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: CohortTextStyles.small.copyWith(
                    color: muted
                        ? CohortColors.textMuted.withValues(alpha: 0.7)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron)
            Icon(
              Icons.chevron_right_rounded,
              color: CohortColors.textMuted,
            ),
        ],
      ),
    );
  }
}
