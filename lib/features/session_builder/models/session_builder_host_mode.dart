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

  // Reserved for M6+ — not implemented in M5.
  // fromTemplate,
  // duplicateSession,
}
