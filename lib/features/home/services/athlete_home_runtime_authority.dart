/// Canonical Home runtime-authority classification (Phase 2.4).
///
/// Programme Athlete runtime is the sole canonical authority for materialised
/// programme athletes. Plan Library / Coach Brain is temporary compatibility
/// only when there is a legacy active plan and no materialised programme.
///
/// Pure decision — no UI side effects, no hosted I/O, does not invoke flows.
enum AthleteHomeRuntimeAuthority {
  /// Materialised authored programme — [ProgrammeAdaptFlow] only.
  programme,

  /// Legacy Plan Library active plan without materialised programme.
  /// Compatibility path — [HomeAdaptFlow] only; not canonical.
  legacyPlanCompatibility,

  /// No materialised programme and no legacy active plan.
  none,

  /// Programme evidence not yet resolved — do not activate legacy prematurely.
  loading,

  /// Programme evidence invalid/unavailable — fail closed; no legacy fallback.
  unavailable,
}

/// Resolves mutually exclusive Home runtime authority from established inputs.
class AthleteHomeRuntimeAuthorityResolver {
  const AthleteHomeRuntimeAuthorityResolver();

  /// [materialisedProgramme]:
  /// - `true` — active assignment is materialised
  /// - `false` — resolved; no materialised programme
  /// - `null` — still loading / unknown (unless [programmeEvidenceUnavailable])
  ///
  /// [legacyActivePlan] is Plan Library session state
  /// (`AthleteProfileSession.hasActivePlan`), not programme materialisation.
  AthleteHomeRuntimeAuthority resolve({
    required bool? materialisedProgramme,
    required bool legacyActivePlan,
    bool programmeEvidenceUnavailable = false,
  }) {
    if (programmeEvidenceUnavailable) {
      // Fail closed for Coach Brain: never unlock legacy from bad evidence.
      // Without a legacy plan, preserve catalogue empty-state (none).
      if (legacyActivePlan) {
        return AthleteHomeRuntimeAuthority.unavailable;
      }
      return AthleteHomeRuntimeAuthority.none;
    }
    if (materialisedProgramme == null) {
      return AthleteHomeRuntimeAuthority.loading;
    }
    if (materialisedProgramme) {
      // Exclusive precedence even when a legacy active plan also exists.
      return AthleteHomeRuntimeAuthority.programme;
    }
    if (legacyActivePlan) {
      return AthleteHomeRuntimeAuthority.legacyPlanCompatibility;
    }
    return AthleteHomeRuntimeAuthority.none;
  }
}

extension AthleteHomeRuntimeAuthorityX on AthleteHomeRuntimeAuthority {
  bool get exposesProgrammeRuntime =>
      this == AthleteHomeRuntimeAuthority.programme;

  bool get exposesLegacyPlanCompatibilityRuntime =>
      this == AthleteHomeRuntimeAuthority.legacyPlanCompatibility;

  bool get activatesAnyAdaptFlow =>
      exposesProgrammeRuntime || exposesLegacyPlanCompatibilityRuntime;

  /// Structural mutual exclusivity: at most one adapt authority.
  bool get isMutuallyExclusiveAdaptAuthority {
    final adaptCount = (exposesProgrammeRuntime ? 1 : 0) +
        (exposesLegacyPlanCompatibilityRuntime ? 1 : 0);
    return adaptCount <= 1;
  }
}
