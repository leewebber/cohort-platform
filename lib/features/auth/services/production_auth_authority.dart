import '../models/auth_view_state.dart';
import '../models/production_auth_phase.dart';

/// Single mapping from AuthController + Supabase session facts to shell entry.
///
/// [onboardingCompleted] is accepted only so callers can prove it is ignored.
class ProductionAuthAuthority {
  const ProductionAuthAuthority();

  ProductionAuthPhase resolve({
    required AuthStatus status,
    required bool hasPersistedSession,
    required bool hasVerifiedProfile,
    required AuthIdentityFailure failure,
    bool onboardingCompleted = false,
  }) {
    // Onboarding / display-name flags never authorize the athlete shell.
    switch (status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return ProductionAuthPhase.authenticating;
      case AuthStatus.awaitingEmailConfirmation:
        return ProductionAuthPhase.awaitingEmailConfirmation;
      case AuthStatus.profileRequired:
        return hasPersistedSession
            ? ProductionAuthPhase.profileRequired
            : ProductionAuthPhase.unauthenticated;
      case AuthStatus.authenticated:
        if (!hasPersistedSession || !hasVerifiedProfile) {
          return ProductionAuthPhase.unauthenticated;
        }
        return ProductionAuthPhase.authenticatedOnline;
      case AuthStatus.authenticatedOffline:
        if (!hasPersistedSession || !hasVerifiedProfile) {
          return ProductionAuthPhase.unauthenticated;
        }
        return ProductionAuthPhase.authenticatedOffline;
      case AuthStatus.invalidIdentity:
        return ProductionAuthPhase.invalidIdentity;
      case AuthStatus.unauthenticated:
        return ProductionAuthPhase.unauthenticated;
      case AuthStatus.error:
        if (failure == AuthIdentityFailure.invalid) {
          return ProductionAuthPhase.invalidIdentity;
        }
        if (failure == AuthIdentityFailure.network &&
            hasPersistedSession &&
            hasVerifiedProfile) {
          return ProductionAuthPhase.authenticatedOffline;
        }
        return ProductionAuthPhase.unauthenticated;
    }
  }

  bool mayEnterShell(ProductionAuthPhase phase) {
    return phase == ProductionAuthPhase.authenticatedOnline ||
        phase == ProductionAuthPhase.authenticatedOffline;
  }
}
