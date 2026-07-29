import 'package:flutter/material.dart';

import '../../core/access/app_role_access.dart';
import '../../core/config/production_navigation_policy.dart';
import '../../core/theme/cohort_lighting.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/adaptation_bottom_sheet.dart';
import '../../core/widgets/adaptation_decision_bottom_sheet.dart';
import '../../core/widgets/cohort_athlete_bottom_nav_bar.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../application/adaptation/athlete_workout_adaptation_application_service.dart';
import '../admin/services/protocol_builder_service.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/screens/account_screen.dart';
import '../auth/services/current_user_session.dart';
import '../beta_support/beta_support_screen.dart';
import '../coach_operations/screens/coach_home_dashboard_screen.dart';
import '../coach_studio/coach_studio_access.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../internal_tools/internal_tools_screen.dart';
import '../performance/screens/training_history_screen.dart';
import '../protocols/protocol_library_screen.dart';
import '../programme/screens/athlete_programme_screen.dart';
import 'controllers/home_today_session_refresh_controller.dart';
import 'widgets/home_today_session_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authController});

  final AuthController? authController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _todaySessionSectionKey = GlobalKey<HomeTodaySessionSectionState>();
  final _todaySessionRefreshController = HomeTodaySessionRefreshController();
  final _homeAdaptationService = AthleteWorkoutAdaptationApplicationService(
    loadProtocolDraft: (protocolId) =>
        ProtocolBuilderService().loadProtocol(protocolId),
  );
  int _bottomNavIndex = 0;

  String get _athleteId => CurrentUserSession.requireInstance.athleteId;

  void _openAccount(BuildContext context) {
    final controller = widget.authController;
    if (controller == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AccountScreen(controller: controller)),
    );
  }

  void _openProtocolLibrary(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProtocolLibraryScreen()));
  }

  void _openExerciseLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(athleteId: _athleteId),
      ),
    );
  }

  void _openCoachHome(BuildContext context) {
    if (!AppRoleAccess.canAccessCoachOperations) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CoachHomeDashboardScreen()));
  }

  void _openCoachStudio(BuildContext context) {
    if (!AppRoleAccess.canAccessCoachOperations) return;
    CoachStudioAccess.open(context);
  }

  void _openInternalTools(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InternalToolsScreen()));
  }

  Future<void> _openProgramme(BuildContext context) async {
    final switched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeScreen(
          athleteId: _athleteId,
          refreshController: _todaySessionRefreshController,
        ),
      ),
    );

    if (switched == true) {
      _todaySessionRefreshController.requestRefresh(
        source: 'athlete_programme_screen',
      );
    }
  }

  Future<void> _openAdaptationSheet(BuildContext context) async {
    final request = await showAdaptationBottomSheet(context);
    if (request == null || !context.mounted) return;

    final section = _todaySessionSectionKey.currentState;
    final protocol = section?.programmeSessionProtocol;
    if (protocol == null) {
      return;
    }

    final decision = await _homeAdaptationService.evaluateSessionAdaptation(
      athleteId: _athleteId,
      currentProtocol: protocol,
      request: request,
    );

    if (!context.mounted) return;

    final accepted = await showAdaptationDecisionBottomSheet(context, decision);
    if (accepted == true && context.mounted) {
      await section?.commitDayOfAdaptation(request: request);
    }
  }

  String _greetingName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'ATHLETE';
    return trimmed.split(' ').first.toUpperCase();
  }

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  void _onBottomNavSelected(int index) {
    setState(() => _bottomNavIndex = index);
    switch (index) {
      case 0:
        return;
      case 1:
        _openProgramme(context);
      case 2:
        _openProtocolLibrary(context);
      case 4:
        if (widget.authController != null) {
          _openAccount(context);
        }
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = CurrentUserSession.requireInstance.profile;
    final showAthlete = ProductionNavigationPolicy.showAthleteTodayExperience();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navBarHeight = showAthlete ? 72.0 + bottomInset : 0.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + navBarHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeBrandHeader(
                displayName: profile.displayName,
                onProfileTap: widget.authController != null
                    ? () => _openAccount(context)
                    : null,
              ),
              if (ProductionNavigationPolicy.showCoachLandingMessage()) ...[
                const SizedBox(height: CohortSpacing.lg),
                const Text('Coach', style: CohortTextStyles.h1),
                const SizedBox(height: CohortSpacing.sm),
                const Text(
                  'Manage athletes and programmes from Coach Studio and My Athletes.',
                  style: CohortTextStyles.body,
                ),
              ],
              if (showAthlete) ...[
                const SizedBox(height: CohortSpacing.lg),
                Text(
                  '${_timeOfDayGreeting()}, ${_greetingName(profile.displayName)}',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('EXECUTE TODAY', style: CohortTextStyles.hero),
                    Text(
                      '.',
                      style: CohortTextStyles.hero.copyWith(
                        color: CohortColors.phosphor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CohortSpacing.sm),
                const Text(
                  'Discipline in the present. Results in the future.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.xl),
                HomeTodaySessionSection(
                  key: _todaySessionSectionKey,
                  refreshController: _todaySessionRefreshController,
                  athleteId: _athleteId,
                ),
              ],
              if (ProductionNavigationPolicy.showTrainingHistory()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const Text('PROGRAMME', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TrainingHistoryScreen(athleteId: _athleteId),
                      ),
                    );
                  },
                  child: const _HomeActionRow(
                    icon: Icons.fitness_center_outlined,
                    title: 'Training History',
                    subtitle:
                        'Review completed sessions and performance records.',
                    trailing: Icons.trending_up_rounded,
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showAdaptationPrompt()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const Text(
                  'OPTIMISE TODAY',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openAdaptationSheet(context),
                  child: const _AdaptationPromptRow(),
                ),
              ],
              if (ProductionNavigationPolicy.showAthleteKnowledge()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Knowledge'),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openProtocolLibrary(context),
                  child: const _HomeActionRow(
                    title: 'Protocol Library',
                    subtitle: 'Browse structured training sessions.',
                    icon: Icons.menu_book_outlined,
                    status: 'OPEN',
                  ),
                ),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openExerciseLibrary(context),
                  child: const _HomeActionRow(
                    title: 'Exercise Library',
                    subtitle: 'Browse movements, cues and coaching knowledge.',
                    icon: Icons.sports_gymnastics_outlined,
                    status: 'OPEN',
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showCoachHome()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Coach Home'),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openCoachHome(context),
                  child: const _HomeActionRow(
                    title: 'My Athletes',
                    subtitle:
                        'Daily operations — who trained, who is due, who needs attention.',
                    icon: Icons.groups_outlined,
                    status: 'COACH',
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showCoachStudio()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Coach Studio'),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openCoachStudio(context),
                  child: const _HomeActionRow(
                    title: 'Coach Studio',
                    subtitle:
                        'Programmes, protocols, and coach authoring tools.',
                    icon: Icons.dashboard_customize_outlined,
                    status: 'COACH',
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showHelpAndFeedback()) ...[
                const SizedBox(height: CohortSpacing.xl),
                CohortCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BetaSupportScreen(),
                      ),
                    );
                  },
                  child: const _HomeActionRow(
                    title: 'Help & feedback',
                    subtitle:
                        'Report a problem or share beta feedback with the Cohort team.',
                    icon: Icons.support_agent_outlined,
                    status: 'HELP',
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showInternalToolsEntry()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Engineering'),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openInternalTools(context),
                  child: const _HomeActionRow(
                    title: 'Internal tools',
                    subtitle:
                        'Explicitly enabled engineering utilities. Not shown in production athlete builds.',
                    icon: Icons.build_outlined,
                    status: 'DEV',
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.xxl),
              const Center(
                child: Text(
                  'Build physical capability.',
                  style: CohortTextStyles.muted,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showAthlete
          ? CohortAthleteBottomNavBar(
              selectedIndex: _bottomNavIndex,
              onDestinationSelected: _onBottomNavSelected,
            )
          : null,
    );
  }
}

class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.displayName, this.onProfileTap});

  final String displayName;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CohortColors.oliveSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: CohortColors.edgeHighlight.withValues(alpha: 0.28),
            ),
            boxShadow: CohortLighting.emissive(opacity: 0.06, blurRadius: 10),
          ),
          child: Icon(
            Icons.hexagon_outlined,
            color: CohortColors.phosphor,
            size: 22,
            shadows: [
              Shadow(
                color: CohortColors.phosphor.withValues(alpha: 0.4),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.md),
        Text(
          'COHORT',
          style: CohortTextStyles.h2.copyWith(letterSpacing: 2, fontSize: 18),
        ),
        const Spacer(),
        if (onProfileTap != null)
          TextButton(
            onPressed: onProfileTap,
            style: TextButton.styleFrom(
              foregroundColor: CohortColors.phosphor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              displayName,
              style: CohortTextStyles.statusActive.copyWith(
                color: CohortColors.phosphor,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdaptationPromptRow extends StatelessWidget {
  const _AdaptationPromptRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HexIcon(icon: Icons.psychology_outlined),
        const SizedBox(width: CohortSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need to Adapt?', style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Tell us what is affecting today’s session.',
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: CohortColors.oliveSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: CohortColors.borderAccent),
          ),
          child: Text(
            'SMART ADAPT',
            style: CohortTextStyles.sectionLabel.copyWith(fontSize: 9),
          ),
        ),
      ],
    );
  }
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({
    required this.title,
    required this.subtitle,
    this.icon = Icons.arrow_forward_ios_rounded,
    this.trailing,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HexIcon(icon: icon),
        const SizedBox(width: CohortSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
        if (trailing != null)
          Icon(
            trailing,
            color: CohortColors.phosphor,
            size: 22,
            shadows: [
              Shadow(
                color: CohortColors.phosphor.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          )
        else if (status != null)
          Text(status!, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}

class _HexIcon extends StatelessWidget {
  const _HexIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: CohortColors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CohortColors.edgeHighlight.withValues(alpha: 0.22),
        ),
        boxShadow: CohortLighting.emissive(opacity: 0.05, blurRadius: 8),
      ),
      child: Icon(
        icon,
        color: CohortColors.phosphor,
        size: 22,
        shadows: [
          Shadow(
            color: CohortColors.phosphor.withValues(alpha: 0.32),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
