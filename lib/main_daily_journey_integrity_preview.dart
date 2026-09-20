import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/auth_view_state.dart';
import 'package:cohort_platform/features/auth/models/production_auth_phase.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/screens/login_screen.dart';
import 'package:cohort_platform/features/auth/services/auth_session_port.dart';
import 'package:cohort_platform/features/auth/services/last_verified_auth_profile_store.dart';
import 'package:cohort_platform/features/auth/services/production_auth_authority.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_recovery_session_policy.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/features/session/services/production_session_draft_classifier.dart';
import 'package:cohort_platform/features/session/services/workout_progress_snapshot_policy.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Internal Daily Journey Integrity preview. Fixtures only. Not imported by
/// `lib/main.dart`.
///
///   flutter run -t lib/main_daily_journey_integrity_preview.dart
///
/// Chrome (optional):
///   flutter run -d chrome --web-port 4191 -t lib/main_daily_journey_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyJourneyIntegrityPreviewApp());
}

class DailyJourneyIntegrityPreviewApp extends StatelessWidget {
  const DailyJourneyIntegrityPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: const DailyJourneyIntegrityPreviewScreen(),
    );
  }
}

class DailyJourneyIntegrityPreviewScreen extends StatelessWidget {
  const DailyJourneyIntegrityPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const authority = ProductionAuthAuthority();
    const classifier = ProductionSessionDraftClassifier();
    const recovery = ProductionRecoverySessionPolicy();
    const restore = ProductionRestoreResolver();
    const snapshotPolicy = WorkoutProgressSnapshotPolicy();

    final signedOut = authority.resolve(
      status: AuthStatus.unauthenticated,
      hasPersistedSession: false,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.none,
      onboardingCompleted: true,
    );
    final online = authority.resolve(
      status: AuthStatus.authenticated,
      hasPersistedSession: true,
      hasVerifiedProfile: true,
      failure: AuthIdentityFailure.none,
    );
    final offline = authority.resolve(
      status: AuthStatus.authenticatedOffline,
      hasPersistedSession: true,
      hasVerifiedProfile: true,
      failure: AuthIdentityFailure.network,
    );
    final revoked = authority.resolve(
      status: AuthStatus.invalidIdentity,
      hasPersistedSession: false,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.invalid,
    );

    const draftAuthority = ProductionSessionDraftAuthority(
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      programmeVersionId: 'preview-version',
      programmedSessionKey: 'preview-key',
      occurrenceId: 'preview-occ',
    );
    final compatible = ProductionSessionDraft(
      schemaVersion: 1,
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      programmeVersionId: 'preview-version',
      programmedSessionKey: 'preview-key',
      packageContentHash: 'a' * 64,
      trainingSessionId: 1,
      entryMode: 'live',
      occurrenceId: 'preview-occ',
    );
    final foreign = ProductionSessionDraft(
      schemaVersion: 1,
      athleteId: 'other-athlete',
      assignmentId: 'preview-assignment',
      programmeVersionId: 'preview-version',
      programmedSessionKey: 'preview-key',
      packageContentHash: 'a' * 64,
      trainingSessionId: 1,
      entryMode: 'live',
    );

    final validCursor = const ProductionSessionUiCursor(
      schemaVersion: 1,
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      trainingSessionId: 1,
      occurrenceId: 'preview-occ',
      activeBlockId: 'strength',
    );
    final futureCursor = const ProductionSessionUiCursor(
      schemaVersion: 99,
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      trainingSessionId: 1,
      activeBlockId: 'strength',
    );
    final restoreRequest = ProductionRestoreRequest(
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      programmeVersionId: 'preview-version',
      programmedSessionKey: 'preview-key',
      packageContentHash: 'a' * 64,
      occurrenceId: 'preview-occ',
      trainingSessionId: 1,
      persistedIdentity: compatible,
      cursor: validCursor,
    );
    final snapshot = WorkoutProgressSnapshot(
      sessionId: 'legacy',
      athleteId: 'preview-athlete',
      currentExerciseIndex: 0,
      currentSet: 1,
      completedExerciseIndexes: const [],
      startedAt: DateTime.utc(2026, 1, 1),
      lastUpdatedAt: DateTime.utc(2026, 1, 1),
    );
    const restPlan = SessionExecutionPlan(
      sessionId: 'preview-rest',
      sessionTitle: 'Rest',
      blocks: [],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Journey Integrity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Deterministic local preview. No hosted data.'),
          const SizedBox(height: 12),
          Text('1 Signed out (onboarding ignored): $signedOut'),
          Text('2 Authenticated online: $online'),
          Text('3 Temporary offline: $offline'),
          Text('4 Invalid/revoked: $revoked'),
          Text(
            '8 Compatible draft: ${classifier.classify(draft: compatible, authority: draftAuthority)}',
          ),
          Text(
            '10 Foreign draft: ${classifier.classify(draft: foreign, authority: draftAuthority)}',
          ),
          Text(
            '5–7 Begin/Resume/Train today: ProgrammeSessionExecutionLauncher + resolver',
          ),
          Text(
            '8 Valid durable identity: ${restore.resolve(restoreRequest).outcome}',
          ),
          Text(
            '9 Memory newer is ignored: ${restore.resolve(restoreRequest).discardMemory}',
          ),
          Text(
            '10 Foreign draft: ${classifier.classify(draft: foreign, authority: draftAuthority)}',
          ),
          Text(
            '11 Legacy snapshot without draft: ${snapshotPolicy.bootAction(snapshot: snapshot, currentAthleteId: 'preview-athlete')}',
          ),
          Text(
            '12 Hosted completed: ${restore.resolve(ProductionRestoreRequest(
              athleteId: 'preview-athlete',
              assignmentId: 'preview-assignment',
              programmeVersionId: 'preview-version',
              programmedSessionKey: 'preview-key',
              packageContentHash: 'a' * 64,
              hostedCompleted: true,
              persistedIdentity: compatible,
            )).outcome}',
          ),
          Text(
            '13 Missing cursor still resumable when identity matches: ${restore.resolve(ProductionRestoreRequest(
              athleteId: 'preview-athlete',
              assignmentId: 'preview-assignment',
              programmeVersionId: 'preview-version',
              programmedSessionKey: 'preview-key',
              packageContentHash: 'a' * 64,
              occurrenceId: 'preview-occ',
              trainingSessionId: 1,
              persistedIdentity: compatible,
            )).restoreCursor}',
          ),
          Text(
            '14 Unsupported cursor ignored: ${restore.resolve(ProductionRestoreRequest(
              athleteId: 'preview-athlete',
              assignmentId: 'preview-assignment',
              programmeVersionId: 'preview-version',
              programmedSessionKey: 'preview-key',
              packageContentHash: 'a' * 64,
              occurrenceId: 'preview-occ',
              trainingSessionId: 1,
              persistedIdentity: compatible,
              cursor: futureCursor,
            )).restoreCursor}',
          ),
          Text(
            '20 Recovery/rest: ${recovery.decide(plan: restPlan, authoredAsRecoveryOrRest: true)}',
          ),
          const Text('12 Offline completion queue: deferred — pending/retry only'),
          const Text(
            '15–19 Format restore: ActiveSessionScreen + ActivePerformanceDraft (see tests)',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              LastVerifiedAuthProfileStore.clear();
              final controller = AuthController(
                authService: _PreviewSignedOutPort(),
                profileProvisioningService: ProfileProvisioningService(),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(controller: controller),
                ),
              );
            },
            child: const Text('Open signed-out login'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              LastVerifiedAuthProfileStore.remember(
                const UserProfile(
                  id: 'preview-athlete',
                  displayName: 'Preview athlete',
                  isCoach: false,
                  isAthlete: true,
                ),
              );
              final controller = AuthController(
                authService: _PreviewSignedOutPort(),
                profileProvisioningService: ProfileProvisioningService(),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AuthGate(controller: controller),
                ),
              );
            },
            child: const Text('Open AuthGate signed out'),
          ),
        ],
      ),
    );
  }
}

class _PreviewSignedOutPort implements AuthSessionPort {
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
  }) async {
    throw const AuthException('Invalid login credentials');
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword({required String email}) async {}
}
