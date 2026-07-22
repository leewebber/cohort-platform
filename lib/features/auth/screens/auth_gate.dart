import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../home/home_screen.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_view_state.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.controller,
  });

  final AuthController controller;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.initialize();
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

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;

    return switch (state.status) {
      AuthStatus.initial || AuthStatus.loading => const _AuthLoadingScreen(),
      AuthStatus.authenticated => HomeScreen(
          authController: widget.controller,
        ),
      AuthStatus.profileRequired => ProfileSetupScreen(
          controller: widget.controller,
        ),
      AuthStatus.unauthenticated || AuthStatus.error => LoginScreen(
          controller: widget.controller,
        ),
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
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading Cohort…', style: CohortTextStyles.body),
          ],
        ),
      ),
    );
  }
}
