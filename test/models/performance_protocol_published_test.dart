import 'package:cohort_platform/models/performance_protocol_published.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_classification.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceProtocolPublished', () {
    test('accepts exact text true and JSON bool true only', () {
      expect(PerformanceProtocolPublished.isPublished('true'), isTrue);
      expect(PerformanceProtocolPublished.isPublished(true), isTrue);
      expect(PerformanceProtocolPublished.isPublished('false'), isFalse);
      expect(PerformanceProtocolPublished.isPublished('No'), isFalse);
      expect(PerformanceProtocolPublished.isPublished('TRUE'), isFalse);
      expect(PerformanceProtocolPublished.isPublished(' yes '), isFalse);
      expect(PerformanceProtocolPublished.isPublished(null), isFalse);
      expect(PerformanceProtocolPublished.isPublished(false), isFalse);
      expect(PerformanceProtocolPublished.isPublished(1), isFalse);
    });

    test('encodes domain bool as live text values', () {
      expect(PerformanceProtocolPublished.toDb(true), 'true');
      expect(PerformanceProtocolPublished.toDb(false), 'false');
    });
  });

  group('canonical template decode against live text published', () {
    test('text published true yields canonical classification', () {
      final draft = ProtocolDraft(
        protocolId: 'TMP-001',
        name: 'Full-Body Strength',
        steps: const [],
        contentKind: TrainingContentKind.sessionTemplate,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
        published: PerformanceProtocolPublished.isPublished('true'),
      );

      expect(draft.published, isTrue);
      expect(
        TrainingContentClassification.isCanonicalSessionTemplate(draft),
        isTrue,
      );
    });

    test('legacy No and false are not canonical', () {
      for (final value in ['No', 'false', null, false]) {
        final draft = ProtocolDraft(
          protocolId: 'TMP-001',
          name: 'Full-Body Strength',
          steps: const [],
          contentKind: TrainingContentKind.sessionTemplate,
          authoringScope: TrainingAuthoringScope.cohortGlobal,
          endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
          published: PerformanceProtocolPublished.isPublished(value),
        );
        expect(
          TrainingContentClassification.isCanonicalSessionTemplate(draft),
          isFalse,
          reason: 'published=$value must fail closed',
        );
      }
    });

    test(
      'applyTrainingContentMetadata treats text true as published lifecycle',
      () {
        final draft = ProtocolDraft.applyTrainingContentMetadata(
          draft: ProtocolDraft(
            protocolId: 'TMP-001',
            name: 'Full-Body Strength',
            steps: const [],
            published: false,
          ),
          row: {
            'content_kind': 'session_template',
            'authoring_scope': 'cohort_global',
            'endorsement_status': 'cohort_endorsed',
            'published': 'true',
          },
        );

        expect(draft.isRevisionPublished, isTrue);
      },
    );
  });
}
