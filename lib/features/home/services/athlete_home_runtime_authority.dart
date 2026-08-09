/// Canonical Home runtime-authority classification (Phase 2.4 / 2.8 / 2.10).
///
/// Programme Athlete runtime is the sole canonical authority for materialised
/// programme athletes. Plan Library / Coach Brain Home entry is **retired**
/// (Phase 2.8) and implementations **deleted** (Phase 2.9). Legacy
/// `hasActivePlan` / PlanAssignment never select Home runtime. Persisted
/// legacy data may remain as passive compatibility only (Phase 2.10 freeze).
///
/// Pure decision — no UI side effects, no hosted I/O, does not invoke flows.
enum AthleteHomeRuntimeAuthority {
  /// Materialised authored programme — [ProgrammeAdaptFlow] only.
  programme,

  /// No materialised programme — established no-programme / catalogue entry.
  /// Also used when only legacy Plan Library state remains (ignored for Home).
  none,

  /// Programme evidence not yet resolved.
  loading,

  /// Programme evidence invalid/unavailable — fail closed; no legacy fallback.
  unavailable,
}

/// Resolves mutually exclusive Home runtime authority from programme evidence.
///
/// Legacy Plan Library session state is intentionally **not** an input.
class AthleteHomeRuntimeAuthorityResolver {
  const AthleteHomeRuntimeAuthorityResolver();

  /// [materialisedProgramme]:
  /// - `true` — active assignment is materialised
  /// - `false` — resolved; no materialised programme
  /// - `null` — still loading / unknown (unless [programmeEvidenceUnavailable])
  AthleteHomeRuntimeAuthority resolve({
    required bool? materialisedProgramme,
    bool programmeEvidenceUnavailable = false,
  }) {
    if (programmeEvidenceUnavailable) {
      // Fail closed: never invent a programme runtime from bad evidence.
      return AthleteHomeRuntimeAuthority.unavailable;
    }
    if (materialisedProgramme == null) {
      return AthleteHomeRuntimeAuthority.loading;
    }
    if (materialisedProgramme) {
      return AthleteHomeRuntimeAuthority.programme;
    }
    return AthleteHomeRuntimeAuthority.none;
  }
}

extension AthleteHomeRuntimeAuthorityX on AthleteHomeRuntimeAuthority {
  bool get exposesProgrammeRuntime =>
      this == AthleteHomeRuntimeAuthority.programme;

  bool get activatesAnyAdaptFlow => exposesProgrammeRuntime;

  /// Structural mutual exclusivity: at most one adapt authority.
  bool get isMutuallyExclusiveAdaptAuthority => true;
}
