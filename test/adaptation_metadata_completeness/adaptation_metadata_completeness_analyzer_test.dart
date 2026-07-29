import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation_metadata_completeness/models/adaptation_metadata_completeness_models.dart';
import 'package:cohort_platform/features/adaptation_metadata_completeness/services/adaptation_metadata_completeness_analyzer.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = AdaptationMetadataCompletenessAnalyzer();

  group('AdaptationMetadataCompletenessAnalyzer', () {
    test(
      'flags missing session intent, min duration, and derived block defaults',
      () {
        final report = analyzer.buildReport([
          AdaptationMetadataCompletenessInput(
            protocolId: 'sess-1',
            name: 'Threshold intervals',
            primaryCapability: 'Threshold',
            sessionFormat: 'intervals',
            scope: AdaptationMetadataCompletenessScope.programmeSession,
            programmeVersionId: 'prog-1',
            programmeName: 'Beta block',
            blocks: [
              SessionBlock.create(
                blockType: SessionBlockType.strength,
                position: 1,
              ).copyWith(title: 'Main'),
            ],
          ),
        ]);

        expect(report.summary.sessionsUntagged, 1);
        expect(report.summary.blocksDerivedDefaults, 1);
        final item = report.items.single;
        expect(
          item.missingCategories,
          contains(MissingMetadataCategory.missingPrimarySessionIntent),
        );
        expect(
          item.missingCategories,
          contains(MissingMetadataCategory.missingMinimumViableDuration),
        );
        expect(
          item.missingCategories,
          contains(MissingMetadataCategory.missingExplicitBlockMetadata),
        );
        expect(
          item.suggestedPrimarySessionIntent?.intent,
          SessionIntent.threshold,
        );
        expect(item.confirmedPrimarySessionIntent, isNull);
      },
    );

    test(
      'session tagged only when canonical fields and explicit blocks present',
      () {
        final report = analyzer.buildReport([
          AdaptationMetadataCompletenessInput(
            protocolId: 'sess-tagged',
            name: 'Tagged',
            sessionFormat: 'structured_strength',
            primarySessionIntent: SessionIntent.upperBodyStrength,
            minimumViableDurationMin: 30,
            scope: AdaptationMetadataCompletenessScope.programmeSession,
            programmeVersionId: 'prog-1',
            programmeName: 'Programme',
            blocks: [
              SessionBlock.create(
                blockType: SessionBlockType.strength,
                position: 1,
              ).copyWith(title: 'Main', blockPriority: BlockPriority.essential),
            ],
          ),
        ]);

        expect(report.summary.sessionsTagged, 1);
        expect(report.summary.sessionsUntagged, 0);
        expect(report.summary.blocksExplicit, 1);
      },
    );

    test('classifies custom empty blocks as unresolved', () {
      final mode = analyzer.classifyBlock(
        SessionBlock.create(blockType: SessionBlockType.custom, position: 1),
      );
      expect(mode.mode, BlockAdaptationMetadataMode.unresolved);
    });

    test('summary counts cohort protocols tagged vs untagged', () {
      final report = analyzer.buildReport([
        AdaptationMetadataCompletenessInput(
          protocolId: 'proto-tagged',
          name: 'Cohort',
          blocks: const [],
          contentKind: TrainingContentKind.cohortProtocol,
          primarySessionIntent: SessionIntent.tempo,
        ),
        AdaptationMetadataCompletenessInput(
          protocolId: 'proto-open',
          name: 'Open',
          blocks: const [],
          contentKind: TrainingContentKind.cohortProtocol,
        ),
      ]);

      expect(report.summary.protocolsTagged, 1);
      expect(report.summary.protocolsUntagged, 1);
    });

    test('filters by programme, session type, and missing category', () {
      final report = analyzer.buildReport([
        AdaptationMetadataCompletenessInput(
          protocolId: 'a',
          name: 'A',
          sessionFormat: 'intervals',
          programmeVersionId: 'v1',
          programmeName: 'One',
          scope: AdaptationMetadataCompletenessScope.programmeSession,
          blocks: const [],
        ),
        AdaptationMetadataCompletenessInput(
          protocolId: 'b',
          name: 'B',
          sessionFormat: 'structured_strength',
          programmeVersionId: 'v2',
          programmeName: 'Two',
          scope: AdaptationMetadataCompletenessScope.programmeSession,
          blocks: const [],
          primarySessionIntent: SessionIntent.fullBodyStrength,
          minimumViableDurationMin: 20,
        ),
      ]);

      final filtered = report.filtered(
        const AdaptationMetadataCompletenessFilters(
          programmeVersionId: 'v1',
          sessionType: 'intervals',
          missingCategory: MissingMetadataCategory.missingPrimarySessionIntent,
        ),
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.protocolId, 'a');
    });
  });

  group('Suggestion vs confirmed intent', () {
    test('suggestions are never authoritative', () {
      const suggestion = SessionIntentSuggestion(
        intent: SessionIntent.threshold,
        reason:
            'Matched legacy primary_capability text (not saved automatically).',
      );
      expect(suggestion.isAuthoritative, isFalse);
    });

    test(
      'confirmSuggestedIntent returns null without founder confirmation',
      () {
        const suggestion = SessionIntentSuggestion(
          intent: SessionIntent.threshold,
          reason: 'test',
        );
        expect(
          confirmSuggestedIntent(
            suggestion: suggestion,
            founderConfirmed: false,
          ),
          isNull,
        );
        expect(
          confirmSuggestedIntent(
            suggestion: suggestion,
            founderConfirmed: true,
          ),
          SessionIntent.threshold,
        );
      },
    );

    test('analyzer does not treat suggestion as confirmed intent', () {
      const analyzer = AdaptationMetadataCompletenessAnalyzer();
      final item = analyzer.analyzeInput(
        const AdaptationMetadataCompletenessInput(
          protocolId: 'sess',
          name: 'Threshold run',
          primaryCapability: 'Threshold',
          blocks: [],
        ),
      );

      expect(item.suggestedPrimarySessionIntent, isNotNull);
      expect(item.confirmedPrimarySessionIntent, isNull);
      expect(item.isProtocolTagged, isFalse);
    });
  });
}
