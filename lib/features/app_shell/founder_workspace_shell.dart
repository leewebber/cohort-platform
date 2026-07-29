import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/screens/account_screen.dart';
import '../auth/services/current_user_session.dart';
import '../beta_support/beta_support_screen.dart';
import '../coach_operations/screens/coach_home_dashboard_screen.dart';
import '../coach_studio/coach_studio_access.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../internal_tools/internal_tools_screen.dart';
import '../plans/screens/plan_library_screen.dart';
import '../protocols/protocol_library_screen.dart';
import 'athlete_app_shell.dart';

/// Founder Workspace — authorised founder tools only.
///
/// Not mixed into athlete Home. Preview Athlete App is an explicit action.
class FounderWorkspaceShell extends StatefulWidget {
  const FounderWorkspaceShell({super.key, this.authController});

  final AuthController? authController;

  @override
  State<FounderWorkspaceShell> createState() => _FounderWorkspaceShellState();
}

class _FounderWorkspaceShellState extends State<FounderWorkspaceShell> {
  int _index = 0;

  String get _athleteId =>
      AthleteProfileSession.profile?.athleteId ??
      CurrentUserSession.maybeInstance?.athleteId ??
      'athlete.local';

  static const _destinations = [
    _FounderNav('Overview', Icons.dashboard_outlined),
    _FounderNav('Athletes', Icons.groups_outlined),
    _FounderNav('Studio', Icons.dashboard_customize_outlined),
    _FounderNav('Knowledge', Icons.menu_book_outlined),
    _FounderNav('Settings', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            _FounderOverview(
              athleteId: _athleteId,
              authController: widget.authController,
              onOpenAthletes: () => setState(() => _index = 1),
              onOpenStudio: () => CoachStudioAccess.open(context),
              onOpenKnowledge: () => setState(() => _index = 3),
            ),
            const CoachHomeDashboardScreen(),
            _StudioTab(onOpenStudio: () => CoachStudioAccess.open(context)),
            _KnowledgeTab(athleteId: _athleteId),
            _SettingsTab(authController: widget.authController),
          ],
        ),
      ),
      bottomNavigationBar: _FounderBottomBar(
        selectedIndex: _index,
        destinations: _destinations,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _FounderNav {
  const _FounderNav(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _FounderBottomBar extends StatelessWidget {
  const _FounderBottomBar({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_FounderNav> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: CohortColors.background.withValues(alpha: 0.94),
      child: Padding(
        padding: EdgeInsets.only(top: 8, bottom: bottom + 6),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        destinations[i].icon,
                        size: 22,
                        color: selectedIndex == i
                            ? CohortColors.phosphor
                            : CohortColors.textMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destinations[i].label,
                        style: CohortTextStyles.muted.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: selectedIndex == i
                              ? CohortColors.phosphor
                              : CohortColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FounderOverview extends StatelessWidget {
  const _FounderOverview({
    required this.athleteId,
    required this.onOpenAthletes,
    required this.onOpenStudio,
    required this.onOpenKnowledge,
    this.authController,
  });

  final String athleteId;
  final AuthController? authController;
  final VoidCallback onOpenAthletes;
  final VoidCallback onOpenStudio;
  final VoidCallback onOpenKnowledge;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CohortSpacing.xl),
      children: [
        Text('FOUNDER WORKSPACE', style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.md),
        Text('Overview', style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          'Authoring, athlete operations, and internal tools. '
          'Separate from the athlete experience.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.xl),
        CohortButton(
          label: 'PREVIEW ATHLETE APP',
          showTrailingArrow: true,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AthleteAppShell(authController: authController),
              ),
            );
          },
        ),
        const SizedBox(height: CohortSpacing.xl),
        CohortCard(
          onTap: onOpenAthletes,
          child: const _Row(
            title: 'My Athletes',
            subtitle: 'Daily operations and athlete attention.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: onOpenStudio,
          child: const _Row(
            title: 'Coach Studio',
            subtitle: 'Plans, protocols, and authoring tools.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlanLibraryScreen(athleteId: athleteId),
              ),
            );
          },
          child: const _Row(
            title: 'Plan authoring entry',
            subtitle: 'Browse and inspect plan products.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: onOpenKnowledge,
          child: const _Row(
            title: 'Knowledge tools',
            subtitle: 'Protocol and Exercise libraries.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InternalToolsScreen()),
            );
          },
          child: const _Row(
            title: 'Diagnostics',
            subtitle: 'Internal engineering utilities.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BetaSupportScreen()),
            );
          },
          child: const _Row(
            title: 'Help / feedback',
            subtitle: 'Beta support administration.',
          ),
        ),
        const SizedBox(height: CohortSpacing.xxl),
      ],
    );
  }
}

class _StudioTab extends StatelessWidget {
  const _StudioTab({required this.onOpenStudio});

  final VoidCallback onOpenStudio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STUDIO', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.md),
          Text('Coach Studio', style: CohortTextStyles.h1),
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: 'OPEN COACH STUDIO',
            showTrailingArrow: true,
            onPressed: onOpenStudio,
          ),
        ],
      ),
    );
  }
}

class _KnowledgeTab extends StatelessWidget {
  const _KnowledgeTab({required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(CohortSpacing.xl),
      children: [
        Text('KNOWLEDGE', style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.md),
        Text('Libraries', style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.xl),
        CohortCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProtocolLibraryScreen(),
              ),
            );
          },
          child: const _Row(
            title: 'Protocol Library',
            subtitle: 'Structured session protocols.',
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseLibraryScreen(athleteId: athleteId),
              ),
            );
          },
          child: const _Row(
            title: 'Exercise Library',
            subtitle: 'Movements, cues, and coaching knowledge.',
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({this.authController});

  final AuthController? authController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SETTINGS', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.md),
          Text('Founder settings', style: CohortTextStyles.h1),
          const SizedBox(height: CohortSpacing.lg),
          if (authController != null)
            CohortCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AccountScreen(controller: authController!),
                  ),
                );
              },
              child: const _Row(
                title: 'Account',
                subtitle: 'Signed-in identity and sign out.',
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CohortTextStyles.cardTitle),
        const SizedBox(height: CohortSpacing.sm),
        Text(subtitle, style: CohortTextStyles.small),
      ],
    );
  }
}
