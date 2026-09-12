import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../core/theme/colors.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../core/widgets/cohort_button.dart';
import '../features/app_shell/athlete_app_shell.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/models/auth_view_state.dart';
import '../features/auth/services/auth_session_port.dart';
import '../features/auth/services/current_user_session.dart';
import 'athlete_shell_preview_fixture.dart';

/// Disposable local athlete-shell preview. Never imported by production `main`.
class AthleteShellPreviewApp extends StatefulWidget {
  const AthleteShellPreviewApp({super.key});

  @override
  State<AthleteShellPreviewApp> createState() => AthleteShellPreviewAppState();
}

class AthleteShellPreviewAppState extends State<AthleteShellPreviewApp> {
  late AthleteShellPreviewBundle _bundle;
  late AuthController _auth;
  AthleteShellPreviewScenario _scenario =
      AthleteShellPreviewScenario.todayNotStarted;
  int _resets = 0;
  bool _signedOut = false;

  @override
  void initState() {
    super.initState();
    _bundle = AthleteShellPreviewBundle.seed(_scenario);
    _auth = AuthController(authService: const PreviewAuthSession());
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _auth.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    final signedOut = _auth.state.status == AuthStatus.unauthenticated &&
        CurrentUserSession.maybeInstance == null;
    if (signedOut != _signedOut && mounted) {
      setState(() => _signedOut = signedOut);
    }
  }

  void resetPreview({AthleteShellPreviewScenario? scenario}) {
    setState(() {
      _resets += 1;
      _scenario = scenario ?? AthleteShellPreviewScenario.todayNotStarted;
      _signedOut = false;
      _bundle = AthleteShellPreviewBundle.seed(_scenario);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cohort local preview',
      debugShowCheckedModeBanner: false,
      theme: cohortTheme,
      home: Scaffold(
        backgroundColor: CohortColors.background,
        endDrawer: _PreviewControlsDrawer(
          scenario: _scenario,
          onSelect: (scenario) => resetPreview(scenario: scenario),
          onReset: () => resetPreview(scenario: _scenario),
        ),
        body: Column(
          children: [
            Material(
              color: CohortColors.oliveDark,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CohortSpacing.md,
                    vertical: CohortSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'LOCAL PREVIEW',
                          style: CohortTextStyles.sectionLabel,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('preview-reset'),
                        onPressed: () => resetPreview(scenario: _scenario),
                        child: const Text('Reset preview'),
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: 'Preview controls',
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _signedOut
                  ? _SignedOutPreview(onReset: resetPreview)
                  : AthleteAppShell(
                      key: ValueKey('preview-shell-$_resets-$_scenario'),
                      authController: _auth,
                      assignmentStore: _bundle.assignmentStore,
                      fixedOccurrenceStore: _bundle.projectionStore,
                      prepareService: _bundle.prepare,
                      executionLauncher: _bundle.execution,
                      previewService: _bundle.previewService,
                      performanceRecordStore: _bundle.performance,
                      swapStore: _bundle.swapStore,
                      programmeScreenController: _bundle.programmeController,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedOutPreview extends StatelessWidget {
  const _SignedOutPreview({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Preview signed out', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.md),
            const Text(
              'The fixture athlete session was cleared. Reset preview to sign in again.',
              style: CohortTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(label: 'Reset preview', onPressed: onReset),
          ],
        ),
      ),
    );
  }
}

class _PreviewControlsDrawer extends StatelessWidget {
  const _PreviewControlsDrawer({
    required this.scenario,
    required this.onSelect,
    required this.onReset,
  });

  final AthleteShellPreviewScenario scenario;
  final ValueChanged<AthleteShellPreviewScenario> onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            const Text('Preview controls', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            const Text(
              'Disposable fixture only. Does not contact hosted data.',
              style: CohortTextStyles.small,
            ),
            const SizedBox(height: CohortSpacing.lg),
            for (final value in AthleteShellPreviewScenario.values)
              ListTile(
                title: Text(_label(value)),
                selected: value == scenario,
                onTap: () {
                  onSelect(value);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(label: 'Reset preview', onPressed: onReset),
          ],
        ),
      ),
    );
  }

  static String _label(AthleteShellPreviewScenario value) {
    return switch (value) {
      AthleteShellPreviewScenario.todayNotStarted =>
        'Home — today not started',
      AthleteShellPreviewScenario.todayInProgress =>
        'Home — today in progress',
      AthleteShellPreviewScenario.todayComplete => 'Home — today complete',
      AthleteShellPreviewScenario.restDay => 'Home — rest day',
    };
  }
}

class PreviewAuthSession implements AuthSessionPort {
  const PreviewAuthSession();

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    throw UnsupportedError('Preview sign-in is fixture-only.');
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) {
    throw UnsupportedError('Preview sign-up is fixture-only.');
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword({required String email}) async {}
}
