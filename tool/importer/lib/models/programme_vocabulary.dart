/// Shared vocabulary for the Programme Engine.
///
/// See `07 Documentation/41_Programme_Engine.md`.
library;

/// Where a programme may appear in platform libraries.
enum ProgrammeLibraryScope {
  /// Curated Cohort Global catalogue — requires explicit global approval.
  cohortGlobal,

  /// Visible only to the authoring coach and their assigned athletes.
  coachPrivate,

  /// Shared within an organisation's coach and athlete population.
  organisation,
}

/// Authoring and catalogue lifecycle for a programme lineage.
enum ProgrammeLifecycleStatus {
  /// Mutable; not assignable.
  draft,

  /// Immutable version snapshot; assignable.
  published,

  /// Retired; no new assignments.
  archived,
}

/// Macro intent for a phase, week, or day.
enum ProgrammeIntent {
  build,
  maintain,
  deload,
  test,
  recover,
  technique,
}

/// Athlete enrolment lifecycle on a published programme version.
enum ProgrammeAssignmentStatus {
  /// Driving Today's Session resolution.
  active,

  /// Temporarily halted; no progression or today resolution.
  paused,

  /// Athlete finished the programme arc.
  completed,

  /// Superseded by a newer assignment.
  reassigned,
}

/// Day classification within a programme week.
enum ProgrammeDayType {
  /// One or more session slots scheduled.
  training,

  /// No sessions; recovery day.
  rest,

  /// Optional work may be scheduled; not required for progression.
  optional,
}

/// Informational time-of-day hint for a session slot.
enum ProgrammeSessionTimeOfDay {
  morning,
  afternoon,
  evening,
  any,
}

/// How strongly completion is expected for progression.
enum ProgrammeSessionCompletionExpectation {
  /// Required for normal progression in v1.
  required,

  /// Supplementary; not required to advance.
  optional,

  /// Expected unless adaptation demotes the slot.
  recommended,
}

/// Owner identity for a programme template.
enum ProgrammeOwnerType {
  global,
  coach,
  organisation,
}

/// Per-assignment resolution of a programme session slot.
///
/// Separate from [TrainingSessionStatus] — see `42_Programme_Engine_Schema.md` §5.
enum ProgrammeSlotOutcomeStatus {
  /// Prescribed; not yet started.
  scheduled,

  /// Athlete has an open execution session for this slot.
  inProgress,

  /// Slot fully satisfied.
  completed,

  /// Session ended early — slot touched but not fully satisfied.
  completedPartial,

  /// Slot intentionally bypassed.
  skipped,

  /// Moved off default calendar position (future).
  rescheduled,

  /// Different protocol executed (Decision Engine substitution).
  replaced,
}

extension ProgrammeLibraryScopeLabels on ProgrammeLibraryScope {
  String get displayLabel {
    return switch (this) {
      ProgrammeLibraryScope.cohortGlobal => 'Cohort Global',
      ProgrammeLibraryScope.coachPrivate => 'Coach Private',
      ProgrammeLibraryScope.organisation => 'Organisation',
    };
  }
}

extension ProgrammeIntentLabels on ProgrammeIntent {
  String get displayLabel {
    return switch (this) {
      ProgrammeIntent.build => 'Build',
      ProgrammeIntent.maintain => 'Maintain',
      ProgrammeIntent.deload => 'Deload',
      ProgrammeIntent.test => 'Test',
      ProgrammeIntent.recover => 'Recover',
      ProgrammeIntent.technique => 'Technique',
    };
  }
}

extension ProgrammeLibraryScopeDb on ProgrammeLibraryScope {
  String get dbValue {
    return switch (this) {
      ProgrammeLibraryScope.cohortGlobal => 'cohort_global',
      ProgrammeLibraryScope.coachPrivate => 'coach_private',
      ProgrammeLibraryScope.organisation => 'organisation',
    };
  }

  static ProgrammeLibraryScope fromDb(String? value) {
    return switch (value?.trim()) {
      'cohort_global' => ProgrammeLibraryScope.cohortGlobal,
      'organisation' => ProgrammeLibraryScope.organisation,
      'coach_private' => ProgrammeLibraryScope.coachPrivate,
      _ => ProgrammeLibraryScope.coachPrivate,
    };
  }
}

extension ProgrammeLifecycleStatusDb on ProgrammeLifecycleStatus {
  String get dbValue {
    return switch (this) {
      ProgrammeLifecycleStatus.draft => 'draft',
      ProgrammeLifecycleStatus.published => 'published',
      ProgrammeLifecycleStatus.archived => 'archived',
    };
  }

  static ProgrammeLifecycleStatus fromDb(String? value) {
    return switch (value?.trim()) {
      'published' => ProgrammeLifecycleStatus.published,
      'archived' => ProgrammeLifecycleStatus.archived,
      'draft' => ProgrammeLifecycleStatus.draft,
      _ => ProgrammeLifecycleStatus.draft,
    };
  }
}

extension ProgrammeIntentDb on ProgrammeIntent {
  String get dbValue => name;

  static ProgrammeIntent? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    for (final intent in ProgrammeIntent.values) {
      if (intent.name == value.trim()) return intent;
    }

    return null;
  }
}

extension ProgrammeAssignmentStatusDb on ProgrammeAssignmentStatus {
  String get dbValue => name;

  static ProgrammeAssignmentStatus fromDb(String? value) {
    return switch (value?.trim()) {
      'paused' => ProgrammeAssignmentStatus.paused,
      'completed' => ProgrammeAssignmentStatus.completed,
      'reassigned' => ProgrammeAssignmentStatus.reassigned,
      'active' => ProgrammeAssignmentStatus.active,
      _ => ProgrammeAssignmentStatus.active,
    };
  }
}

extension ProgrammeDayTypeDb on ProgrammeDayType {
  String get dbValue => name;

  static ProgrammeDayType fromDb(String? value) {
    return switch (value?.trim()) {
      'rest' => ProgrammeDayType.rest,
      'optional' => ProgrammeDayType.optional,
      'training' => ProgrammeDayType.training,
      _ => ProgrammeDayType.training,
    };
  }
}

extension ProgrammeSessionTimeOfDayDb on ProgrammeSessionTimeOfDay {
  String get dbValue => name;

  static ProgrammeSessionTimeOfDay fromDb(String? value) {
    return switch (value?.trim()) {
      'morning' => ProgrammeSessionTimeOfDay.morning,
      'afternoon' => ProgrammeSessionTimeOfDay.afternoon,
      'evening' => ProgrammeSessionTimeOfDay.evening,
      'any' => ProgrammeSessionTimeOfDay.any,
      _ => ProgrammeSessionTimeOfDay.any,
    };
  }
}

extension ProgrammeSessionCompletionExpectationDb
    on ProgrammeSessionCompletionExpectation {
  String get dbValue => name;

  static ProgrammeSessionCompletionExpectation fromDb(String? value) {
    return switch (value?.trim()) {
      'optional' => ProgrammeSessionCompletionExpectation.optional,
      'recommended' => ProgrammeSessionCompletionExpectation.recommended,
      'required' => ProgrammeSessionCompletionExpectation.required,
      _ => ProgrammeSessionCompletionExpectation.required,
    };
  }
}

extension ProgrammeOwnerTypeDb on ProgrammeOwnerType {
  String get dbValue => name;

  static ProgrammeOwnerType fromDb(String? value) {
    return switch (value?.trim()) {
      'global' => ProgrammeOwnerType.global,
      'organisation' => ProgrammeOwnerType.organisation,
      'coach' => ProgrammeOwnerType.coach,
      _ => ProgrammeOwnerType.coach,
    };
  }
}

extension ProgrammeSlotOutcomeStatusDb on ProgrammeSlotOutcomeStatus {
  String get dbValue {
    return switch (this) {
      ProgrammeSlotOutcomeStatus.scheduled => 'scheduled',
      ProgrammeSlotOutcomeStatus.inProgress => 'in_progress',
      ProgrammeSlotOutcomeStatus.completed => 'completed',
      ProgrammeSlotOutcomeStatus.completedPartial => 'completed_partial',
      ProgrammeSlotOutcomeStatus.skipped => 'skipped',
      ProgrammeSlotOutcomeStatus.rescheduled => 'rescheduled',
      ProgrammeSlotOutcomeStatus.replaced => 'replaced',
    };
  }

  static ProgrammeSlotOutcomeStatus fromDb(String? value) {
    return switch (value?.trim()) {
      'in_progress' => ProgrammeSlotOutcomeStatus.inProgress,
      'completed' => ProgrammeSlotOutcomeStatus.completed,
      'completed_partial' => ProgrammeSlotOutcomeStatus.completedPartial,
      'skipped' => ProgrammeSlotOutcomeStatus.skipped,
      'rescheduled' => ProgrammeSlotOutcomeStatus.rescheduled,
      'replaced' => ProgrammeSlotOutcomeStatus.replaced,
      'scheduled' => ProgrammeSlotOutcomeStatus.scheduled,
      _ => ProgrammeSlotOutcomeStatus.scheduled,
    };
  }

  bool get isTerminal {
    return switch (this) {
      ProgrammeSlotOutcomeStatus.completed => true,
      ProgrammeSlotOutcomeStatus.completedPartial => true,
      ProgrammeSlotOutcomeStatus.skipped => true,
      ProgrammeSlotOutcomeStatus.replaced => true,
      ProgrammeSlotOutcomeStatus.scheduled => false,
      ProgrammeSlotOutcomeStatus.inProgress => false,
      ProgrammeSlotOutcomeStatus.rescheduled => false,
    };
  }

  bool get blocksDayAdvancement {
    return switch (this) {
      ProgrammeSlotOutcomeStatus.scheduled => true,
      ProgrammeSlotOutcomeStatus.inProgress => true,
      ProgrammeSlotOutcomeStatus.rescheduled => true,
      ProgrammeSlotOutcomeStatus.completed => false,
      ProgrammeSlotOutcomeStatus.completedPartial => false,
      ProgrammeSlotOutcomeStatus.skipped => false,
      ProgrammeSlotOutcomeStatus.replaced => false,
    };
  }
}

extension ProgrammeSessionTimeOfDayLabels on ProgrammeSessionTimeOfDay {
  String get displayLabel {
    return switch (this) {
      ProgrammeSessionTimeOfDay.morning => 'Morning',
      ProgrammeSessionTimeOfDay.afternoon => 'Afternoon',
      ProgrammeSessionTimeOfDay.evening => 'Evening',
      ProgrammeSessionTimeOfDay.any => 'Any time',
    };
  }
}
