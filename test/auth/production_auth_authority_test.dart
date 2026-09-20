import 'package:cohort_platform/features/auth/models/auth_view_state.dart';
import 'package:cohort_platform/features/auth/models/production_auth_phase.dart';
import 'package:cohort_platform/features/auth/services/production_auth_authority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const authority = ProductionAuthAuthority();

  test('local onboarding alone cannot enter the athlete shell', () {
    final phase = authority.resolve(
      status: AuthStatus.unauthenticated,
      hasPersistedSession: false,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.none,
      onboardingCompleted: true,
    );
    expect(phase, ProductionAuthPhase.unauthenticated);
    expect(authority.mayEnterShell(phase), isFalse);
  });

  test('no identity resolves to sign in', () {
    expect(
      authority.resolve(
        status: AuthStatus.unauthenticated,
        hasPersistedSession: false,
        hasVerifiedProfile: false,
        failure: AuthIdentityFailure.none,
      ),
      ProductionAuthPhase.unauthenticated,
    );
  });

  test('valid authenticated session may enter the shell', () {
    final phase = authority.resolve(
      status: AuthStatus.authenticated,
      hasPersistedSession: true,
      hasVerifiedProfile: true,
      failure: AuthIdentityFailure.none,
    );
    expect(phase, ProductionAuthPhase.authenticatedOnline);
    expect(authority.mayEnterShell(phase), isTrue);
  });

  test('temporary offline cached identity may enter the shell', () {
    final phase = authority.resolve(
      status: AuthStatus.authenticatedOffline,
      hasPersistedSession: true,
      hasVerifiedProfile: true,
      failure: AuthIdentityFailure.network,
    );
    expect(phase, ProductionAuthPhase.authenticatedOffline);
    expect(authority.mayEnterShell(phase), isTrue);
  });

  test('network error without cached profile does not enter the shell', () {
    final phase = authority.resolve(
      status: AuthStatus.error,
      hasPersistedSession: true,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.network,
    );
    expect(phase, ProductionAuthPhase.unauthenticated);
    expect(authority.mayEnterShell(phase), isFalse);
  });

  test('definitively invalid identity fails closed to sign in', () {
    final phase = authority.resolve(
      status: AuthStatus.invalidIdentity,
      hasPersistedSession: false,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.invalid,
    );
    expect(phase, ProductionAuthPhase.invalidIdentity);
    expect(authority.mayEnterShell(phase), isFalse);
  });

  test('error + invalid failure fails closed even if onboarding completed', () {
    final phase = authority.resolve(
      status: AuthStatus.error,
      hasPersistedSession: false,
      hasVerifiedProfile: false,
      failure: AuthIdentityFailure.invalid,
      onboardingCompleted: true,
    );
    expect(phase, ProductionAuthPhase.invalidIdentity);
    expect(authority.mayEnterShell(phase), isFalse);
  });
}
