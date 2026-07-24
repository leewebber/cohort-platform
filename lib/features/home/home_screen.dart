import 'package:flutter/material.dart';

import '../../core/config/production_navigation_policy.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/adaptation_bottom_sheet.dart';
import '../../core/widgets/adaptation_decision_bottom_sheet.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/repositories/athlete_state_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../adaptation/services/adaptation_decision_service.dart';
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CoachHomeDashboardScreen()));
  }

  void _openCoachStudio(BuildContext context) {
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

    const athleteStateRepository = AthleteStateRepository();
    final protocolRepository = ProtocolRepository();

    final athleteState = await athleteStateRepository.getAthleteState(
      _athleteId,
    );
    final protocolId = athleteState?.currentProtocolId;
    if (protocolId == null) {
      return;
    }

    final currentProtocol = await protocolRepository.getProtocolById(
      protocolId,
    );
    if (currentProtocol == null) {
      return;
    }

    const decisionService = AdaptationDecisionService();
    final decision = decisionService.evaluate(
      currentProtocol: currentProtocol,
      request: request,
    );

    if (!context.mounted) return;

    await showAdaptationDecisionBottomSheet(context, decision);
  }

  @override
  Widget build(BuildContext context) {
    final profile = CurrentUserSession.requireInstance.profile;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionTitle('Cohort')),
                  if (widget.authController != null)
                    TextButton(
                      onPressed: () => _openAccount(context),
                      child: Text(profile.displayName),
                    ),
                ],
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
              if (ProductionNavigationPolicy.showAthleteTodayExperience()) ...[
                const SizedBox(height: CohortSpacing.lg),
                const Text('Today', style: CohortTextStyles.h1),
                const SizedBox(height: CohortSpacing.md),
                const Text(
                  'Know the plan. Execute with confidence.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.xl),
                HomeTodaySessionSection(
                  key: _todaySessionSectionKey,
                  refreshController: _todaySessionRefreshController,
                  athleteId: _athleteId,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () => _openProgramme(context),
                    style: TextButton.styleFrom(
                      foregroundColor: CohortColors.textMuted,
                      textStyle: CohortTextStyles.muted,
                    ),
                    child: const Text('Programme'),
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showTrainingHistory()) ...[
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
                    title: 'Training History',
                    subtitle:
                        'Review completed sessions and performance records.',
                    status: 'OPEN',
                  ),
                ),
              ],
              if (ProductionNavigationPolicy.showAdaptationPrompt()) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Need to Adapt?'),
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
                    status: 'OPEN',
                  ),
                ),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: () => _openExerciseLibrary(context),
                  child: const _HomeActionRow(
                    title: 'Exercise Library',
                    subtitle: 'Browse movements, cues and coaching knowledge.',
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
    );
  }
}

class _AdaptationPromptRow extends StatelessWidget {
  const _AdaptationPromptRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adjust Today’s Session', style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Tell us what is affecting today’s session.',
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.lg),
        Text('OPEN', style: CohortTextStyles.eyebrow),
      ],
    );
  }
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        const SizedBox(width: CohortSpacing.lg),
        Text(status, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}
