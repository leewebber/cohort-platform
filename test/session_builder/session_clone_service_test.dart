import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

void main() {
  const cloneService = SessionCloneService();

  group('SessionCloneService', () {
    test('creates independent ProtocolDraft and step objects', () {
      final source = buildEligibleCohortProtocolDraft();
      final clone = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: SessionCloneService.newLocalCloneDraftId(),
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: '11111111-1111-1111-1111-111111111111',
      );

      expect(clone.protocolId, isNot(source.protocolId));
      expect(clone.steps.length, source.steps.length);
      expect(identical(clone.steps, source.steps), isFalse);
      expect(identical(clone.steps.first, source.steps.first), isFalse);
      expect(clone.steps.first.persistedId, isNull);
      expect(clone.steps.first.localId, isNot(source.steps.first.localId));
    });

    test('source remains unchanged after clone edits', () {
      final source = buildEligibleCohortProtocolDraft();
      final clone = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: 'local-copy-session-test',
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: '11111111-1111-1111-1111-111111111111',
      );

      final editedClone = clone.copyWith(
        name: 'Edited clone',
        steps: [
          clone.steps.first.copyWith(title: 'Changed step'),
        ],
      );

      expect(source.name, 'Threshold Intervals');
      expect(source.steps.first.title, 'Warm-up');
      expect(editedClone.name, 'Edited clone');
    });

    test('removes cohort classification and sets lineage', () {
      final source = buildEligibleCohortProtocolDraft();
      final clone = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: 'local-copy-session-test',
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.sessionLibrary,
      );

      expect(clone.contentKind, TrainingContentKind.session);
      expect(clone.authoringScope, TrainingAuthoringScope.coachPrivate);
      expect(clone.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(clone.published, isTrue);
      expect(clone.programmeVersionId, isNull);
      expect(clone.sourceContentId, source.protocolId);
      expect(clone.sourceContentKind, TrainingContentKind.cohortProtocol);
      expect(clone.sourceVersionId, isNull);
      expect(clone.name, 'Threshold Intervals — Custom');
    });

    test('programme-only destination sets programme metadata', () {
      const versionId = '11111111-1111-1111-1111-111111111111';
      final clone = cloneService.cloneCohortProtocolToSession(
        source: buildEligibleCohortProtocolDraft(),
        newContentId: 'local-copy-session-test',
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: versionId,
      );

      expect(clone.authoringScope, TrainingAuthoringScope.programmeOnly);
      expect(clone.published, isFalse);
      expect(clone.programmeVersionId, versionId);
    });
  });
}
