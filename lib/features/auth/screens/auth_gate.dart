import 'package:flutter/material.dart';

import '../../../core/access/app_access_role.dart';
import '../../../core/access/app_experience_resolver.dart';
import '../../../core/access/founder_access_policy.dart';
import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/persistence/athlete_state_hydrator.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../app_shell/athlete_app_shell.dart';
import '../../app_shell/founder_workspace_shell.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_view_state.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.controller});

  final AuthController controller;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _experienceResolver = const AppExperienceResolver();
  bool _hydrating = true;
  AthleteHydrationResult? _hydration;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.controller.initialize();
    AthleteHydrationResult? hydration;
    if (AthletePersistence.isInitialized) {
      try {
        hydration = await AthletePersistence.hydrate(allowRegenerate: true);
      } catch (e, st) {
        debugPrint('[AuthGate] athlete hydration failed: $e');
        debugPrint('$st');
      }
    }
    if (!mounted) return;
    setState(() {
      _hydration = hydration;
      _hydrating = false;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    final status = widget.controller.state.status;
    if (status == AuthStatus.authenticated ||
        status == AuthStatus.profileRequired) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    setState(() {});
  }

  Widget _experienceRoot() {
    final email = widget.controller.currentEmail;
    FounderAccessPolicy.bindSessionEmail(email);
    final role = _experienceResolver.resolve(email: email);
    if (role == AppAccessRole.founder) {
      return FounderWorkspaceShell(authController: widget.controller);
    }
    return AthleteAppShell(
      authController: widget.controller,
      pendingWorkoutProgress: _hydration?.pendingWorkoutProgress,
      planDefinitionMissing: _hydration?.planDefinitionMissing ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hydrating ||
        widget.controller.state.status == AuthStatus.initial ||
        widget.controller.state.status == AuthStatus.loading) {
      return const _AuthLoadingScreen();
    }

    final state = widget.controller.state;

    return switch (state.status) {
      AuthStatus.initial || AuthStatus.loading => const _AuthLoadingScreen(),
      AuthStatus.authenticated => _experienceRoot(),
      AuthStatus.profileRequired => ProfileSetupScreen(
        controller: widget.controller,
      ),
      AuthStatus.unauthenticated || AuthStatus.error =>
        AthleteProfileSession.hasCompletedOnboarding
            ? AthleteAppShell(
                authController: widget.controller,
                pendingWorkoutProgress: _hydration?.pendingWorkoutProgress,
                planDefinitionMissing:
                    _hydration?.planDefinitionMissing ?? false,
              )
            : LoginScreen(controller: widget.controller),
      AuthStatus.awaitingEmailConfirmation => EmailVerificationScreen(
        controller: widget.controller,
      ),
    };
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('COHORT', style: CohortTextStyles.eyebrow),
            const SizedBox(height: 16),
            Text('Preparing…', style: CohortTextStyles.body),
          ],
        ),
      ),
    );
  }
}
