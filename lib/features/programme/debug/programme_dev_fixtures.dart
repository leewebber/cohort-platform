import '../../founder_acceptance/founder_acceptance_content.dart';
import '../../founder_acceptance/founder_acceptance_dev_fixtures.dart';

/// Development programme fixture identifiers.
class ProgrammeDevFixtures {
  ProgrammeDevFixtures._();

  static const foundationTestLineageCode = 'COHORT-FOUNDATION-TEST';

  /// Fixed UUID from `supabase/seed/cohort_foundation_test_programme.sql`.
  static const foundationTestVersionId =
      'aaaaaaaa-bbbb-cccc-dddd-000000000002';

  static const founderAcceptanceLineageCode =
      FounderAcceptanceContent.programmeLineageCode;

  /// Fixed UUID from founder acceptance developer install tooling.
  static const founderAcceptanceVersionId =
      FounderAcceptanceDevFixtures.versionId;
}
