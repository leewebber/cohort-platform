/// Explicit empty-slot session source choices (product language).
enum ProgrammeSessionSourceChoice {
  /// Official Cohort Protocol (read-only attach or copy-and-customise).
  useCohortProtocol,

  /// Coach-owned reusable My Sessions (live reference attach).
  useMySession,

  /// Create a new coach-owned / programme-bound session in the builder.
  buildNewSession,

  /// Session template (copy-on-use into a new session draft).
  useTemplate,
}

extension ProgrammeSessionSourceChoiceLabels on ProgrammeSessionSourceChoice {
  String get coachFacingLabel {
    return switch (this) {
      ProgrammeSessionSourceChoice.useCohortProtocol => 'Use Cohort Protocol',
      ProgrammeSessionSourceChoice.useMySession => 'Use My Session',
      ProgrammeSessionSourceChoice.buildNewSession => 'Build New Session',
      ProgrammeSessionSourceChoice.useTemplate => 'Use Template',
    };
  }
}
