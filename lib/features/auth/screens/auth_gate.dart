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
import '../controllers/auth_controller.dart';
import '../models/production_auth_phase.dart';
import '../services/current_user_session.dart';
import '../services/production_auth_authority.dart';
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
  final _authority = const ProductionAuthAuthority();
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
    await _hydrateForAuthenticatedIdentity();
    if (!mounted) return;
    setState(() {
      _hydrating = false;
    });
  }

  Future<void> _hydrateForAuthenticatedIdentity() async {
    if (!AthletePersistence.isInitialized) return;
    final athleteId = CurrentUserSession.maybeInstance?.athleteId;
    if (athleteId == null || athleteId.isEmpty) {
      _hydration = null;
      return;
    }
    try {
      _hydration = await AthletePersistence.hydrate(
        preferredAthleteId: athleteId,
        allowRegenerate: false,
      );
    } catch (e, st) {
      debugPrint('[AuthGate] athlete hydration failed: $e');
      debugPrint('$st');
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    final phase = _phase;
    if (phase == ProductionAuthPhase.authenticatedOnline ||
        phase == ProductionAuthPhase.authenticatedOffline ||
        phase == ProductionAuthPhase.profileRequired) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    setState(() {});
  }

  ProductionAuthPhase get _phase {
    final state = widget.controller.state;
    return _authority.resolve(
      status: state.status,
      hasPersistedSession: widget.controller.hasPersistedSession,
      hasVerifiedProfile:
          state.profile != null || CurrentUserSession.maybeInstance != null,
      failure: state.failure,
    );
  }

  Widget _experienceRoot({required bool offline}) {
    // Offline phase keeps the same shell; drafts stay scoped to the user id.
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
    final phase = _phase;
    if (_hydrating || phase == ProductionAuthPhase.authenticating) {
      return const _AuthLoadingScreen(message: 'Restoring your session');
    }

    return switch (phase) {
      ProductionAuthPhase.authenticating => const _AuthLoadingScreen(
        message: 'Signing in',
      ),
      ProductionAuthPhase.authenticatedOnline => _experienceRoot(
        offline: false,
      ),
      ProductionAuthPhase.authenticatedOffline => _experienceRoot(
        offline: true,
      ),
      ProductionAuthPhase.profileRequired => ProfileSetupScreen(
        controller: widget.controller,
      ),
      ProductionAuthPhase.awaitingEmailConfirmation => EmailVerificationScreen(
        controller: widget.controller,
      ),
      ProductionAuthPhase.unauthenticated ||
      ProductionAuthPhase.invalidIdentity => LoginScreen(
        controller: widget.controller,
      ),
    };
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen({this.message = 'Restoring your session'});

  final String message;

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
            Text(message, style: CohortTextStyles.body),
          ],
        ),
      ),
    );
  }
}
