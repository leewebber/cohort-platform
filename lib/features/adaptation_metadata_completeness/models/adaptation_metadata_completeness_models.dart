import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_type.dart';
import '../../../models/training_content_vocabulary.dart';

/// What kind of authoring record this row represents.
enum AdaptationMetadataCompletenessScope {
  programmeSession,
  standaloneProtocol,
}

/// Filter for missing metadata gaps.
enum MissingMetadataCategory {
  missingPrimarySessionIntent,
  missingMinimumViableDuration,
  missingExplicitBlockMetadata,
  unresolvedBlockMetadata,
}

/// Founder / beta / coach ownership filter.
enum AdaptationMetadataOwnershipFilter {
  all,
  cohortEndorsed,
  coachAuthored,
  cohortGlobalProgramme,
}

enum BlockAdaptationMetadataMode { explicit, derivedDefaults, unresolved }

class SessionIntentSuggestion {
  const SessionIntentSuggestion({required this.intent, required this.reason});

  final SessionIntent intent;
  final String reason;

  /// Suggestions are display-only until confirmed in Session / Protocol Builder.
  bool get isAuthoritative => false;
}

class BlockCompletenessDetail {
  const BlockCompletenessDetail({
    required this.localId,
    required this.title,
    required this.blockType,
    required this.mode,
  });

  final String localId;
  final String title;
  final SessionBlockType blockType;
  final BlockAdaptationMetadataMode mode;
}

class AdaptationMetadataCompletenessInput {
  const AdaptationMetadataCompletenessInput({
    required this.protocolId,
    required this.name,
    required this.blocks,
    this.scope = AdaptationMetadataCompletenessScope.standaloneProtocol,
    this.programmeVersionId,
    this.programmeName,
    this.slotLocationLabel,
    this.sessionType,
    this.sessionFormat,
    this.primaryCapability,
    this.primarySessionIntent,
    this.minimumViableDurationMin,
    this.contentKind = TrainingContentKind.cohortProtocol,
    this.authoringScope = TrainingAuthoringScope.cohortGlobal,
    this.endorsementStatus = TrainingEndorsementStatus.cohortEndorsed,
    this.programmeLibraryScope,
  });

  final String protocolId;
  final String name;
  final List<SessionBlock> blocks;
  final AdaptationMetadataCompletenessScope scope;
  final String? programmeVersionId;
  final String? programmeName;
  final String? slotLocationLabel;
  final String? sessionType;
  final String? sessionFormat;
  final String? primaryCapability;
  final SessionIntent? primarySessionIntent;
  final int? minimumViableDurationMin;
  final TrainingContentKind contentKind;
  final TrainingAuthoringScope authoringScope;
  final TrainingEndorsementStatus endorsementStatus;
  final ProgrammeLibraryScope? programmeLibraryScope;
}

class AdaptationMetadataCompletenessItem {
  const AdaptationMetadataCompletenessItem({
    required this.protocolId,
    required this.name,
    required this.blocks,
    required this.scope,
    required this.missingCategories,
    required this.isSessionTagged,
    required this.isProtocolTagged,
    this.programmeVersionId,
    this.programmeName,
    this.slotLocationLabel,
    this.sessionType,
    this.sessionFormat,
    this.primaryCapability,
    this.confirmedPrimarySessionIntent,
    this.suggestedPrimarySessionIntent,
    this.minimumViableDurationMin,
    this.contentKind = TrainingContentKind.cohortProtocol,
    this.authoringScope = TrainingAuthoringScope.cohortGlobal,
    this.endorsementStatus = TrainingEndorsementStatus.cohortEndorsed,
    this.programmeLibraryScope,
  });

  final String protocolId;
  final String name;
  final List<BlockCompletenessDetail> blocks;
  final AdaptationMetadataCompletenessScope scope;
  final String? programmeVersionId;
  final String? programmeName;
  final String? slotLocationLabel;
  final String? sessionType;
  final String? sessionFormat;
  final String? primaryCapability;
  final SessionIntent? confirmedPrimarySessionIntent;
  final SessionIntentSuggestion? suggestedPrimarySessionIntent;
  final int? minimumViableDurationMin;
  final bool isSessionTagged;
  final bool isProtocolTagged;
  final Set<MissingMetadataCategory> missingCategories;
  final TrainingContentKind contentKind;
  final TrainingAuthoringScope authoringScope;
  final TrainingEndorsementStatus endorsementStatus;
  final ProgrammeLibraryScope? programmeLibraryScope;

  String get sessionTypeLabel =>
      (sessionFormat ?? sessionType ?? 'unknown').trim();
}

class AdaptationMetadataCompletenessSummary {
  const AdaptationMetadataCompletenessSummary({
    required this.sessionsTagged,
    required this.sessionsUntagged,
    required this.blocksExplicit,
    required this.blocksDerivedDefaults,
    required this.blocksUnresolved,
    required this.protocolsTagged,
    required this.protocolsUntagged,
  });

  final int sessionsTagged;
  final int sessionsUntagged;
  final int blocksExplicit;
  final int blocksDerivedDefaults;
  final int blocksUnresolved;
  final int protocolsTagged;
  final int protocolsUntagged;
}

class AdaptationMetadataCompletenessFilters {
  const AdaptationMetadataCompletenessFilters({
    this.programmeVersionId,
    this.sessionType,
    this.missingCategory,
    this.ownership = AdaptationMetadataOwnershipFilter.all,
  });

  final String? programmeVersionId;
  final String? sessionType;
  final MissingMetadataCategory? missingCategory;
  final AdaptationMetadataOwnershipFilter ownership;
}

class AdaptationMetadataCompletenessReport {
  const AdaptationMetadataCompletenessReport({
    required this.summary,
    required this.items,
    required this.programmeOptions,
    required this.sessionTypeOptions,
  });

  final AdaptationMetadataCompletenessSummary summary;
  final List<AdaptationMetadataCompletenessItem> items;
  final List<ProgrammeFilterOption> programmeOptions;
  final List<String> sessionTypeOptions;

  List<AdaptationMetadataCompletenessItem> filtered(
    AdaptationMetadataCompletenessFilters filters,
  ) {
    return items
        .where((item) {
          if (filters.programmeVersionId != null &&
              item.programmeVersionId != filters.programmeVersionId) {
            return false;
          }
          if (filters.sessionType != null &&
              item.sessionTypeLabel.toLowerCase() !=
                  filters.sessionType!.toLowerCase()) {
            return false;
          }
          if (filters.missingCategory != null &&
              !item.missingCategories.contains(filters.missingCategory)) {
            return false;
          }
          if (!_matchesOwnership(item, filters.ownership)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  static bool _matchesOwnership(
    AdaptationMetadataCompletenessItem item,
    AdaptationMetadataOwnershipFilter ownership,
  ) {
    return switch (ownership) {
      AdaptationMetadataOwnershipFilter.all => true,
      AdaptationMetadataOwnershipFilter.cohortEndorsed =>
        item.endorsementStatus == TrainingEndorsementStatus.cohortEndorsed ||
            item.contentKind == TrainingContentKind.cohortProtocol,
      AdaptationMetadataOwnershipFilter.coachAuthored =>
        item.endorsementStatus == TrainingEndorsementStatus.coachAuthored ||
            item.authoringScope == TrainingAuthoringScope.coachPrivate ||
            item.authoringScope == TrainingAuthoringScope.programmeOnly,
      AdaptationMetadataOwnershipFilter.cohortGlobalProgramme =>
        item.programmeLibraryScope == ProgrammeLibraryScope.cohortGlobal,
    };
  }
}

class ProgrammeFilterOption {
  const ProgrammeFilterOption({required this.versionId, required this.label});

  final String versionId;
  final String label;
}
