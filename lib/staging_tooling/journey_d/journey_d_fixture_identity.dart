/// Canonical Journey D fixture marker → synthetic Auth email derivation.
///
/// Uniqueness preflight, Auth Admin create, and hosted verification must use
/// [journeyDFixtureEmail] with the same marker string — never a hard-coded or
/// stale prior email.
library;

/// Retired / poisoned live markers. Still valid as local test strings unless
/// [rejectRetiredLiveMarker] is applied on a live path.
const retiredLiveJourneyDMarkers = <String>{
  's17_jd_adapt_20260805T012428Z_933d9364',
};

/// Deterministic fixture Auth email for [marker].
String journeyDFixtureEmail(String marker) =>
    '$marker.athlete.jd@example.invalid';

/// Normalized identity used for Auth create and lookup comparison.
String journeyDNormalizedFixtureEmail(String marker) =>
    journeyDFixtureEmail(marker.trim()).toLowerCase();

/// Refuse poisoned markers on live create/execute paths.
void rejectRetiredLiveMarker(String marker) {
  final m = marker.trim();
  if (retiredLiveJourneyDMarkers.contains(m)) {
    throw StateError(
      'REFUSED: retired/poisoned Journey D fixture marker '
      '(choose a fresh s17_jd_adapt_* identity)',
    );
  }
}
