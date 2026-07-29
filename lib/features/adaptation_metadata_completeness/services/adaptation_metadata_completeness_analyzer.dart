import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_type.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../session_builder/models/adaptation_metadata_builder_vocabulary.dart';
import '../models/adaptation_metadata_completeness_models.dart';

/// Non-authoritative hints from legacy capability or session naming.
class SessionIntentSuggestionService {
  const SessionIntentSuggestionService();

  SessionIntentSuggestion? suggest({
    required String sessionName,
    String? primaryCapability,
    String? sessionType,
  }) {
    final capabilityMatch = _matchText(primaryCapability);
    if (capabilityMatch != null) {
      return SessionIntentSuggestion(
        intent: capabilityMatch,
        reason:
            'Matched legacy primary_capability text (not saved automatically).',
      );
    }

    final nameMatch = _matchText(sessionName);
    if (nameMatch != null) {
      return SessionIntentSuggestion(
        intent: nameMatch,
        reason: 'Matched session name text (not saved automatically).',
      );
    }

    final typeMatch = _matchText(sessionType);
    if (typeMatch != null) {
      return SessionIntentSuggestion(
        intent: typeMatch,
        reason: 'Matched session type text (not saved automatically).',
      );
    }

    return null;
  }

  SessionIntent? _matchText(String? raw) {
    if (raw == null) return null;
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    for (final intent in SessionIntent.values) {
      final db = intent.dbValue;
      if (normalized == db || normalized == _normalize(db)) {
        return intent;
      }
      final label =
          AdaptationMetadataBuilderVocabulary.sessionIntentDisplayLabel(intent);
      if (normalized == _normalize(label)) {
        return intent;
      }
    }

    for (final entry in _legacyCapabilityPhrases.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static const _legacyCapabilityPhrases = <String, SessionIntent>{
    'threshold': SessionIntent.threshold,
    'vo2': SessionIntent.vo2Max,
    'aerobic base': SessionIntent.aerobicBase,
    'long run': SessionIntent.longRun,
    'tempo': SessionIntent.tempo,
    'upper body strength': SessionIntent.upperBodyStrength,
    'lower body strength': SessionIntent.lowerBodyStrength,
    'hypertrophy': SessionIntent.fullBodyHypertrophy,
    'mobility': SessionIntent.mobility,
    'prehab': SessionIntent.prehabilitation,
    'recovery': SessionIntent.activeRecovery,
  };
}

/// Pure completeness calculations for founder review workflows.
class AdaptationMetadataCompletenessAnalyzer {
  const AdaptationMetadataCompletenessAnalyzer({
    SessionIntentSuggestionService? suggestionService,
  }) : _suggestionService =
           suggestionService ?? const SessionIntentSuggestionService();

  final SessionIntentSuggestionService _suggestionService;

  AdaptationMetadataCompletenessReport buildReport(
    List<AdaptationMetadataCompletenessInput> inputs,
  ) {
    final items = inputs.map(analyzeInput).toList(growable: false);
    final programmeOptions = <ProgrammeFilterOption>[];
    final seenProgrammes = <String>{};
    final sessionTypes = <String>{};

    for (final item in items) {
      sessionTypes.add(item.sessionTypeLabel);
      final versionId = item.programmeVersionId;
      final programmeName = item.programmeName;
      if (versionId != null &&
          programmeName != null &&
          seenProgrammes.add(versionId)) {
        programmeOptions.add(
          ProgrammeFilterOption(versionId: versionId, label: programmeName),
        );
      }
    }

    programmeOptions.sort((a, b) => a.label.compareTo(b.label));
    final sortedSessionTypes = sessionTypes.toList()..sort();

    return AdaptationMetadataCompletenessReport(
      summary: summarizeItems(items),
      items: items,
      programmeOptions: programmeOptions,
      sessionTypeOptions: sortedSessionTypes,
    );
  }

  AdaptationMetadataCompletenessItem analyzeInput(
    AdaptationMetadataCompletenessInput input,
  ) {
    final blockDetails = input.blocks
        .map(classifyBlock)
        .toList(growable: false);
    final missing = <MissingMetadataCategory>{};

    if (input.primarySessionIntent == null) {
      missing.add(MissingMetadataCategory.missingPrimarySessionIntent);
    }
    if (input.minimumViableDurationMin == null) {
      missing.add(MissingMetadataCategory.missingMinimumViableDuration);
    }

    if (blockDetails.any(
      (b) => b.mode == BlockAdaptationMetadataMode.derivedDefaults,
    )) {
      missing.add(MissingMetadataCategory.missingExplicitBlockMetadata);
    }
    if (blockDetails.any(
      (b) => b.mode == BlockAdaptationMetadataMode.unresolved,
    )) {
      missing.add(MissingMetadataCategory.unresolvedBlockMetadata);
    }

    final isSessionTagged =
        input.primarySessionIntent != null &&
        input.minimumViableDurationMin != null &&
        blockDetails.every(
          (b) => b.mode == BlockAdaptationMetadataMode.explicit,
        );

    final isProtocolTagged =
        input.contentKind == TrainingContentKind.cohortProtocol &&
        input.primarySessionIntent != null;

    final suggestion = input.primarySessionIntent == null
        ? _suggestionService.suggest(
            sessionName: input.name,
            primaryCapability: input.primaryCapability,
            sessionType: input.sessionType ?? input.sessionFormat,
          )
        : null;

    return AdaptationMetadataCompletenessItem(
      protocolId: input.protocolId,
      name: input.name,
      blocks: blockDetails,
      scope: input.scope,
      programmeVersionId: input.programmeVersionId,
      programmeName: input.programmeName,
      slotLocationLabel: input.slotLocationLabel,
      sessionType: input.sessionType,
      sessionFormat: input.sessionFormat,
      primaryCapability: input.primaryCapability,
      confirmedPrimarySessionIntent: input.primarySessionIntent,
      suggestedPrimarySessionIntent: suggestion,
      minimumViableDurationMin: input.minimumViableDurationMin,
      isSessionTagged: isSessionTagged,
      isProtocolTagged: isProtocolTagged,
      missingCategories: missing,
      contentKind: input.contentKind,
      authoringScope: input.authoringScope,
      endorsementStatus: input.endorsementStatus,
      programmeLibraryScope: input.programmeLibraryScope,
    );
  }

  BlockCompletenessDetail classifyBlock(SessionBlock block) {
    final mode = _blockMode(block);
    return BlockCompletenessDetail(
      localId: block.localId,
      title: block.title.trim().isEmpty ? block.blockType.name : block.title,
      blockType: block.blockType,
      mode: mode,
    );
  }

  BlockAdaptationMetadataMode _blockMode(SessionBlock block) {
    final hasExplicit =
        block.blockPriority != null || block.adaptationPolicy != null;
    if (hasExplicit) {
      return BlockAdaptationMetadataMode.explicit;
    }

    if (block.blockType == SessionBlockType.custom &&
        block.blockPriority == null &&
        block.adaptationPolicy == null) {
      return BlockAdaptationMetadataMode.unresolved;
    }

    if (block.blockType == SessionBlockType.custom &&
        block.title.trim().isEmpty &&
        block.content.trim().isEmpty) {
      return BlockAdaptationMetadataMode.unresolved;
    }

    return BlockAdaptationMetadataMode.derivedDefaults;
  }

  AdaptationMetadataCompletenessSummary summarizeItems(
    List<AdaptationMetadataCompletenessItem> items,
  ) {
    var sessionsTagged = 0;
    var sessionsUntagged = 0;
    var blocksExplicit = 0;
    var blocksDerived = 0;
    var blocksUnresolved = 0;
    var protocolsTagged = 0;
    var protocolsUntagged = 0;

    for (final item in items) {
      if (item.scope == AdaptationMetadataCompletenessScope.programmeSession) {
        if (item.isSessionTagged) {
          sessionsTagged++;
        } else {
          sessionsUntagged++;
        }
      }

      if (item.contentKind == TrainingContentKind.cohortProtocol) {
        if (item.isProtocolTagged) {
          protocolsTagged++;
        } else {
          protocolsUntagged++;
        }
      }

      for (final block in item.blocks) {
        switch (block.mode) {
          case BlockAdaptationMetadataMode.explicit:
            blocksExplicit++;
          case BlockAdaptationMetadataMode.derivedDefaults:
            blocksDerived++;
          case BlockAdaptationMetadataMode.unresolved:
            blocksUnresolved++;
        }
      }
    }

    return AdaptationMetadataCompletenessSummary(
      sessionsTagged: sessionsTagged,
      sessionsUntagged: sessionsUntagged,
      blocksExplicit: blocksExplicit,
      blocksDerivedDefaults: blocksDerived,
      blocksUnresolved: blocksUnresolved,
      protocolsTagged: protocolsTagged,
      protocolsUntagged: protocolsUntagged,
    );
  }
}

/// Applies a suggestion only when the founder explicitly confirms in builder code paths.
SessionIntent? confirmSuggestedIntent({
  required SessionIntentSuggestion suggestion,
  required bool founderConfirmed,
}) {
  if (!founderConfirmed) return null;
  return suggestion.intent;
}
