/// Disposition of a scheduled programme occurrence in the schedule projection.
enum ProgrammeScheduleDisposition {
  /// Uncompleted and eligible for scheduling operations.
  scheduled,

  /// Skipped scheduling/adherence disposition — not completion.
  skipped,

  /// Completed (mirrored from completion outcomes); immutable.
  completed,
}
