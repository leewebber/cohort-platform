/// Production athlete identity phases. Local onboarding is never a phase.
enum ProductionAuthPhase {
  unauthenticated,
  authenticating,
  authenticatedOnline,
  authenticatedOffline,
  invalidIdentity,
  profileRequired,
  awaitingEmailConfirmation,
}

/// Why the last auth attempt failed. Network is not revocation.
enum AuthIdentityFailure {
  none,
  network,
  invalid,
  unknown,
}
