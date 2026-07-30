/// Where [SessionBuilderView] is hosted.
enum SessionBuilderHostMode {
  /// Standalone admin Protocol Builder route.
  cohortProtocolAdmin,

  /// Programme Editor embedded Session Builder.
  embeddedProgrammeSession,

  /// Standalone Session Library authoring route.
  librarySession,
}

/// Coach-facing vs admin authoring intent for a slot.
enum ProgrammeSessionAuthoringIntent {
  createBlank,
  editCoachSession,
  copyCohortProtocol,

  /// Copy-on-use from a session template into a new programme session draft.
  fromTemplate,

  // Reserved for M6+ .
  // duplicateSession,
}
