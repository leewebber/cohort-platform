import 'package:flutter/foundation.dart';

/// Debug-only identity constants for local programme validation helpers.
///
/// Compile-time excluded from release behaviour via [kDebugMode] guards at call sites.
class ProgrammeDebugIdentity {
  ProgrammeDebugIdentity._();

  static const athleteId = 'lee';

  static const coachId = 'dev-coach';

  static void assertDebugMode() {
    assert(kDebugMode, 'ProgrammeDebugIdentity is debug-only.');
  }
}
