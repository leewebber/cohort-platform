import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';

import 'programme_session_authoring_test_support.dart';

ProtocolDraft buildValidLibrarySessionDraft({
  String protocolId = 'local-library-session-test',
  String name = 'Library Session',
}) {
  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    sessionFormat: 'structured_strength',
    steps: buildValidProgrammeSessionDraft().steps,
    published: true,
    contentKind: TrainingContentKind.session,
    authoringScope: TrainingAuthoringScope.coachPrivate,
    endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    ownerId: 'dev-coach',
  );
}
