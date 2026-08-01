import 'package:flutter/material.dart';

import '../../core/theme/cohort_lighting.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/services/current_user_session.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../athlete_profile/widgets/athlete_generated_today_section.dart';
import '../daily_briefing/widgets/daily_briefing_section.dart';
import '../programme/screens/athlete_programme_screen.dart';
import 'controllers/home_today_session_refresh_controller.dart';
import 'services/home_adapt_flow.dart';

/// Athlete Home — entirely focused on today.
///
/// Founder/coach/knowledge cards are absent. Navigation lives in [AthleteAppShell].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authController,
    this.embeddedInShell = false,
    this.refreshController,
  });

  final AuthController? authController;

  /// When true, bottom nav is owned by the shell (do not render here).
  final bool embeddedInShell;

  /// Optional today refresh after catalogue enrolment.
  final HomeTodaySessionRefreshController? refreshController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _adaptFlow = HomeAdaptFlow();
  late final HomeTodaySessionRefreshController _refreshController =
      widget.refreshController ?? HomeTodaySessionRefreshController();

  String get _athleteId =>
      AthleteProfileSession.profile?.athleteId ??
      CurrentUserSession.maybeInstance?.athleteId ??
      'athlete.local';

  String get _displayName =>
      AthleteProfileSession.profile?.displayName ??
      CurrentUserSession.maybeInstance?.profile.displayName ??
      'Athlete';

  /// Sprint 1.3 catalogue enrolment entry (exact-version programme access).
  Future<void> _openProgrammeCatalogue() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeScreen(
          athleteId: _athleteId,
          refreshController: _refreshController,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      _refreshController.requestRefresh(source: 'athlete_catalogue_enrolment');
      setState(() {});
    }
  }

  Future<void> _openAdapt() => _adaptFlow.open(context, athleteId: _athleteId);

  @override
  Widget build(BuildContext context) {
    final hasActivePlan = AthleteProfileSession.hasActivePlan;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad = widget.embeddedInShell ? 24.0 : 24.0 + 72.0 + bottomInset;

    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeBrandHeader(displayName: _displayName),
              const SizedBox(height: CohortSpacing.lg),
              if (hasActivePlan) ...[
                DailyBriefingSection(
                  onSessionReturned: (_) {
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: CohortSpacing.xl),
                Text('NEED TO ADAPT?', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  onTap: _openAdapt,
                  child: const _AdaptationPromptRow(),
                ),
              ] else
                ChoosePlanEntryCard(onChoosePlan: _openProgrammeCatalogue),
              const SizedBox(height: CohortSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: _openProgrammeCatalogue,
                  style: TextButton.styleFrom(
                    foregroundColor: CohortColors.textMuted,
                    textStyle: CohortTextStyles.muted,
                  ),
                  child: const Text('Programme'),
                ),
              ),
              const SizedBox(height: CohortSpacing.xl),
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

class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.displayName});

  final String displayName;

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
        Text(
          displayName.split(' ').first,
          style: CohortTextStyles.statusActive.copyWith(
            color: CohortColors.phosphor,
            letterSpacing: 0.4,
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CohortColors.background.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CohortColors.edgeHighlight.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(
            Icons.psychology_outlined,
            color: CohortColors.phosphor,
            size: 22,
          ),
        ),
        const SizedBox(width: CohortSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need to Adapt?', style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Recovery, environment, equipment, or time.',
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
        Text('ADAPT', style: CohortTextStyles.eyebrow),
      ],
    );
  }
}
