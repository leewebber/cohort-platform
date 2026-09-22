import '../models/programme_catalog_entry.dart';
import '../../../models/programme_vocabulary.dart';

enum ProgrammeDiscoveryDecisionPreviewState {
  catalogueDiscovery,
  detailApollo,
  detailSpartan,
  comparison,
  comparisonNarrow,
  comparisonLargeText,
  comparisonMissingFacts,
  enrolmentReview,
  enrolmentPending,
  enrolmentSuccess,
  enrolmentRejected,
  activeCurrent,
  activeInspectOther,
  emptyCatalogue,
  catalogueUnavailable,
  largeTextNarrow,
}

class ProgrammeDiscoveryPreviewFixtures {
  const ProgrammeDiscoveryPreviewFixtures._();

  static ProgrammeCatalogEntry apollo({
    bool missingOptional = false,
  }) {
    return ProgrammeCatalogEntry(
      versionId: 'preview-apollo',
      lineageCode: 'APOLLO',
      versionNumber: 2,
      name: 'Apollo',
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      approvedForGlobal: true,
      primaryGoal: 'Hybrid performance',
      description: missingOptional
          ? null
          : 'A twelve-week hybrid programme for concurrent strength and running.',
      durationWeeks: missingOptional ? null : 12,
      sessionsPerWeek: missingOptional ? null : 5,
      difficulty: missingOptional ? null : 'Intermediate',
      equipmentRequirements: missingOptional ? null : 'Barbell, run route',
    );
  }

  static ProgrammeCatalogEntry spartan({bool missingOptional = false}) {
    return ProgrammeCatalogEntry(
      versionId: 'preview-spartan',
      lineageCode: 'SPARTAN',
      versionNumber: 3,
      name: 'Spartan',
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      approvedForGlobal: true,
      primaryGoal: 'Strength endurance',
      description: missingOptional ? null : 'An eight-week strength-endurance block.',
      durationWeeks: missingOptional ? null : 8,
      sessionsPerWeek: missingOptional ? null : 4,
      difficulty: missingOptional ? null : 'Advanced',
      equipmentRequirements: missingOptional ? null : 'Full gym',
    );
  }
}
