import 'package:flutter/material.dart';

import '../../core/persistence/athlete_persistence.dart';
import '../../core/persistence/models/execution_result_models.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_athlete_bottom_nav_bar.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/services/current_user_session.dart';
import '../home/home_screen.dart';
import '../programme/controllers/athlete_programme_controllers.dart';
import '../programme/screens/athlete_calendar_screen.dart';
import '../programme/screens/athlete_programme_screen.dart';
import '../programme/services/fixed_programme_occurrence_projection_store.dart';
import '../programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../progress/screens/progress_screen.dart';
import 'screens/athlete_profile_screen.dart';

/// Athlete application shell — the athlete's five primary destinations.
///
/// Founder/coach tools are absent from this widget tree.
///
/// Phase 2.6: the Programmes tab mounts the canonical [AthleteProgrammeScreen], not
/// Plan Library. New legacy Plan Library starts are closed at this boundary.
class AthleteAppShell extends StatefulWidget {
  const AthleteAppShell({
    super.key,
    this.authController,
    this.pendingWorkoutProgress,
    this.planDefinitionMissing = false,
    this.programmeScreenController,
    this.fixedOccurrenceStore,
  });

  final AuthController? authController;
  final WorkoutProgressSnapshot? pendingWorkoutProgress;
  final bool planDefinitionMissing;

  /// Optional programme tab controller (tests / local wiring).
  final AthleteProgrammeScreenController? programmeScreenController;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;

  static const destinations = [
    CohortAthleteNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Calendar',
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Programmes',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Progress',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  State<AthleteAppShell> createState() => _AthleteAppShellState();
}

class _AthleteAppShellState extends State<AthleteAppShell> {
  int _index = 0;
  bool _recoveryPromptShown = false;

  FixedProgrammeOccurrenceProjectionStore get _fixedOccurrenceStore =>
      widget.fixedOccurrenceStore ??
      const FixedProgrammeOccurrenceProjectionSupabaseStore();

  String get _athleteId =>
      AthleteProfileSession.profile?.athleteId ??
      CurrentUserSession.maybeInstance?.athleteId ??
      'athlete.local';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowRecoveryPrompts();
    });
  }

  Future<void> _maybeShowRecoveryPrompts() async {
    if (!mounted || _recoveryPromptShown) return;
    _recoveryPromptShown = true;

    if (widget.planDefinitionMissing) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text('Plan unavailable', style: CohortTextStyles.h2),
          content: Text(
            'Your active Plan could not be restored. '
            'Browse programmes to continue training.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _index = 2);
              },
              child: const Text('Browse Programmes'),
            ),
          ],
        ),
      );
    }

    final progress = widget.pendingWorkoutProgress;
    if (!mounted || progress == null || progress.phase != 'active') return;

    final choice = await showDialog<_WorkoutRecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: CohortColors.surface,
        title: Text('Resume training?', style: CohortTextStyles.h2),
        content: Text(
          'You have an unfinished session. '
          'Resume continues from where you left off. '
          'Discard clears the in-progress session without marking it complete.',
          style: CohortTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_WorkoutRecoveryChoice.discard),
            child: const Text('Discard In-Progress Session'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_WorkoutRecoveryChoice.resume),
            child: const Text('Resume Training'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == _WorkoutRecoveryChoice.discard) {
      if (AthletePersistence.isInitialized) {
        await AthletePersistence.hydrator.discardWorkoutProgress(_athleteId);
      }
      return;
    }

    if (choice == _WorkoutRecoveryChoice.resume) {
      // Safe subset: acknowledge resume intent; full player restore is limited
      // to clearing the prompt and returning Home so the athlete can relaunch
      // today's session. Cursor indexes are retained in the snapshot for later.
      setState(() => _index = 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open Today\'s Training to continue. '
            'Your in-progress position was saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            authController: widget.authController,
            embeddedInShell: true,
            fixedOccurrenceStore: _fixedOccurrenceStore,
            onOpenCalendar: () => setState(() => _index = 1),
          ),
          AthleteCalendarScreen(
            athleteId: _athleteId,
            fixedOccurrenceStore: _fixedOccurrenceStore,
            onOpenProgrammes: () => setState(() => _index = 2),
          ),
          // Phase 2.6: athlete Programmes tab is canonical programme catalogue entry.
          // Plan Library start UI is no longer mounted here (RETIRE decision).
          AthleteProgrammeScreen(
            athleteId: _athleteId,
            embeddedInShell: true,
            controller: widget.programmeScreenController,
            fixedOccurrenceStore: _fixedOccurrenceStore,
            onOpenCalendar: () => setState(() => _index = 1),
          ),
          ProgressScreen(
            embeddedInShell: true,
            onChoosePlan: () => setState(() => _index = 2),
            onStartToday: () => setState(() => _index = 0),
          ),
          AthleteProfileScreen(authController: widget.authController),
        ],
      ),
      bottomNavigationBar: CohortAthleteBottomNavBar(
        selectedIndex: _index,
        destinations: AthleteAppShell.destinations,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

enum _WorkoutRecoveryChoice { resume, discard }
