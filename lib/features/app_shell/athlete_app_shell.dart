import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/cohort_athlete_bottom_nav_bar.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/services/current_user_session.dart';
import '../home/home_screen.dart';
import '../plans/screens/plan_library_screen.dart';
import '../progress/screens/progress_screen.dart';
import 'screens/athlete_profile_screen.dart';

/// Athlete application shell — exactly four destinations.
///
/// Founder/coach tools are absent from this widget tree.
class AthleteAppShell extends StatefulWidget {
  const AthleteAppShell({super.key, this.authController});

  final AuthController? authController;

  static const destinations = [
    CohortAthleteNavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    CohortAthleteNavDestination(
      label: 'Plans',
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week_rounded,
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

  String get _athleteId =>
      AthleteProfileSession.profile?.athleteId ??
      CurrentUserSession.maybeInstance?.athleteId ??
      'athlete.local';

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
            onBrowsePlans: () => setState(() => _index = 1),
          ),
          PlanLibraryScreen(
            athleteId: _athleteId,
            embeddedInShell: true,
          ),
          ProgressScreen(
            embeddedInShell: true,
            onChoosePlan: () => setState(() => _index = 1),
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
