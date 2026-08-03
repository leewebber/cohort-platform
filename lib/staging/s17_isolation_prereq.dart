import 's17_staging_journey_matrix.dart';

/// Independent PREREQ_A components — never collapsed into a single opaque FAIL.
enum S17IsolationComponentResult { pass, fail, uncertain, unsupported }

extension S17IsolationComponentResultLabel on S17IsolationComponentResult {
  String get label {
    switch (this) {
      case S17IsolationComponentResult.pass:
        return 'PASS';
      case S17IsolationComponentResult.fail:
        return 'FAIL';
      case S17IsolationComponentResult.uncertain:
        return 'UNCERTAIN';
      case S17IsolationComponentResult.unsupported:
        return 'UNSUPPORTED';
    }
  }
}

class S17IsolationAssessment {
  const S17IsolationAssessment({
    required this.authentication,
    required this.ownRowVisibility,
    required this.foreignRowDenial,
    required this.detail,
  });

  final S17IsolationComponentResult authentication;
  final S17IsolationComponentResult ownRowVisibility;
  final S17IsolationComponentResult foreignRowDenial;
  final String detail;

  /// Overall gate result: PASS only when every component passes.
  /// UNSUPPORTED/UNCERTAIN foreign denial blocks the release gate (not PASS).
  S17JourneyResult get overallResult {
    if (authentication == S17IsolationComponentResult.fail ||
        ownRowVisibility == S17IsolationComponentResult.fail ||
        foreignRowDenial == S17IsolationComponentResult.fail) {
      return S17JourneyResult.fail;
    }
    if (authentication == S17IsolationComponentResult.uncertain ||
        ownRowVisibility == S17IsolationComponentResult.uncertain ||
        foreignRowDenial == S17IsolationComponentResult.uncertain) {
      return S17JourneyResult.blocked;
    }
    if (authentication == S17IsolationComponentResult.unsupported ||
        ownRowVisibility == S17IsolationComponentResult.unsupported ||
        foreignRowDenial == S17IsolationComponentResult.unsupported) {
      return S17JourneyResult.blocked;
    }
    return S17JourneyResult.pass;
  }

  String get reportDetail =>
      'AUTH=${authentication.label} OWN=${ownRowVisibility.label} '
      'FOREIGN=${foreignRowDenial.label} $detail';

  bool get isolationBreachProven =>
      foreignRowDenial == S17IsolationComponentResult.fail;
}

/// Pure classifier for Athlete D isolation prerequisites (no network).
class S17IsolationPrereq {
  /// [authenticated] — sign-in succeeded and session uid matches Athlete D.
  /// [isAthlete] / [isCoach] — profile roles.
  /// [ownAssignmentFound] — active assignment row visible for Athlete D.
  /// [ownAssignmentOwned] — that row's athlete_id matches Athlete D.
  /// [foreignProbe] — null = query unsupported/error; true = foreign row seen;
  /// false = empty (denial holds for athlete-only SELECT policy).
  static S17IsolationAssessment assess({
    required bool authenticated,
    required bool isAthlete,
    required bool isCoach,
    required bool ownAssignmentFound,
    required bool ownAssignmentOwned,
    required bool? foreignProbe,
  }) {
    final auth = authenticated
        ? S17IsolationComponentResult.pass
        : S17IsolationComponentResult.fail;

    S17IsolationComponentResult own;
    if (!authenticated) {
      own = S17IsolationComponentResult.fail;
    } else if (!isAthlete) {
      own = S17IsolationComponentResult.fail;
    } else if (isCoach) {
      // Coach SELECT policy can see linked athletes — athlete-isolation proof
      // via empty foreign probe is unsupported for coach/dual-role profiles.
      own = S17IsolationComponentResult.unsupported;
    } else if (!ownAssignmentFound) {
      own = S17IsolationComponentResult.fail;
    } else if (!ownAssignmentOwned) {
      own = S17IsolationComponentResult.fail;
    } else {
      own = S17IsolationComponentResult.pass;
    }

    S17IsolationComponentResult foreign;
    if (!authenticated) {
      foreign = S17IsolationComponentResult.fail;
    } else if (isCoach) {
      foreign = S17IsolationComponentResult.unsupported;
    } else if (foreignProbe == null) {
      foreign = S17IsolationComponentResult.uncertain;
    } else if (foreignProbe) {
      foreign = S17IsolationComponentResult.fail;
    } else {
      foreign = S17IsolationComponentResult.pass;
    }

    final detail = StringBuffer();
    if (!authenticated) detail.write('auth_failed ');
    if (!isAthlete) detail.write('not_athlete ');
    if (isCoach) detail.write('coach_role_blocks_athlete_isolation_proof ');
    if (authenticated && isAthlete && !isCoach && !ownAssignmentFound) {
      detail.write('no_active_own_assignment ');
    }
    if (ownAssignmentFound && !ownAssignmentOwned) {
      detail.write('own_assignment_athlete_mismatch ');
    }
    if (foreignProbe == true) detail.write('foreign_row_visible ');
    if (foreignProbe == null && !isCoach) {
      detail.write('foreign_probe_uncertain ');
    }
    if (detail.isEmpty) detail.write('isolation_components_classified');

    return S17IsolationAssessment(
      authentication: auth,
      ownRowVisibility: own,
      foreignRowDenial: foreign,
      detail: detail.toString().trim(),
    );
  }
}
