/// Training content classification vocabulary for `performance_protocols`.
///
/// See `07 Documentation/47_Embedded_Session_Authoring.md`.
library;

/// What kind of training content a row represents.
enum TrainingContentKind {
  /// Official Cohort-endorsed protocol content.
  cohortProtocol,

  /// Coach-authored or customised workout (including programme-only).
  session,

  /// Reusable starting structure copied on use.
  sessionTemplate,
}

/// Where and for whom content was authored.
enum TrainingAuthoringScope {
  /// Cohort global official catalogue.
  cohortGlobal,

  /// Private to a coach (reusable coach library).
  coachPrivate,

  /// Shared within an organisation.
  organisation,

  /// Bound to a single programme version draft slot.
  programmeOnly,
}

/// Endorsement / review state for training content.
enum TrainingEndorsementStatus {
  /// Official Cohort-endorsed content.
  cohortEndorsed,

  /// Approved by an organisation.
  organisationApproved,

  /// Coach-authored without Cohort endorsement.
  coachAuthored,

  /// Not yet reviewed or unknown legacy value.
  unreviewed,
}

extension TrainingContentKindDb on TrainingContentKind {
  String get dbValue {
    return switch (this) {
      TrainingContentKind.cohortProtocol => 'cohort_protocol',
      TrainingContentKind.session => 'session',
      TrainingContentKind.sessionTemplate => 'session_template',
    };
  }

  /// Parses database values safely. Unknown values fall back to [session]
  /// — never [cohortProtocol] (avoid silent Cohort-endorsed classification).
  static TrainingContentKind fromDb(String? value) {
    return switch (value?.trim()) {
      'cohort_protocol' => TrainingContentKind.cohortProtocol,
      'session_template' => TrainingContentKind.sessionTemplate,
      'session' => TrainingContentKind.session,
      _ => TrainingContentKind.session,
    };
  }
}

extension TrainingAuthoringScopeDb on TrainingAuthoringScope {
  String get dbValue {
    return switch (this) {
      TrainingAuthoringScope.cohortGlobal => 'cohort_global',
      TrainingAuthoringScope.coachPrivate => 'coach_private',
      TrainingAuthoringScope.organisation => 'organisation',
      TrainingAuthoringScope.programmeOnly => 'programme_only',
    };
  }

  /// Unknown values fall back to [coachPrivate] — not [cohortGlobal].
  static TrainingAuthoringScope fromDb(String? value) {
    return switch (value?.trim()) {
      'cohort_global' => TrainingAuthoringScope.cohortGlobal,
      'organisation' => TrainingAuthoringScope.organisation,
      'programme_only' => TrainingAuthoringScope.programmeOnly,
      'coach_private' => TrainingAuthoringScope.coachPrivate,
      _ => TrainingAuthoringScope.coachPrivate,
    };
  }
}

extension TrainingEndorsementStatusDb on TrainingEndorsementStatus {
  String get dbValue {
    return switch (this) {
      TrainingEndorsementStatus.cohortEndorsed => 'cohort_endorsed',
      TrainingEndorsementStatus.organisationApproved =>
        'organisation_approved',
      TrainingEndorsementStatus.coachAuthored => 'coach_authored',
      TrainingEndorsementStatus.unreviewed => 'unreviewed',
    };
  }

  /// Unknown or null values fall back to [unreviewed] — never [cohortEndorsed].
  static TrainingEndorsementStatus fromDb(String? value) {
    return switch (value?.trim()) {
      'cohort_endorsed' => TrainingEndorsementStatus.cohortEndorsed,
      'organisation_approved' =>
        TrainingEndorsementStatus.organisationApproved,
      'coach_authored' => TrainingEndorsementStatus.coachAuthored,
      'unreviewed' => TrainingEndorsementStatus.unreviewed,
      _ => TrainingEndorsementStatus.unreviewed,
    };
  }
}
