import 'package:cohort_platform/core/services/current_coach_identity.dart';
import 'package:cohort_platform/core/services/training_content_id_generator.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_operation_result.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_template_draft.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/ports/programme_session_assignment_port.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_edit_operations.dart';
import 'package:cohort_platform/models/programme_day_draft.dart';
import 'package:cohort_platform/models/programme_session_slot_draft.dart';
import 'package:cohort_platform/models/programme_week_draft.dart';
import 'package:cohort_platform/models/protocol_builder_save_result.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';

const testProgrammeVersionId = '11111111-1111-1111-1111-111111111111';
const testSlotLocalId = 'slot-am';
const testDayLocalId = 'day-tue';
const testWeekLocalId = 'week-2';
const testDurableSessionId = '22222222-2222-2222-2222-222222222222';

ProtocolDraft buildValidProgrammeSessionDraft({
  String protocolId = 'local-session-slot-am',
  String name = 'Morning Strength',
  String programmeVersionId = testProgrammeVersionId,
}) {
  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    sessionFormat: 'structured_strength',
    steps: const [
      ProtocolStepDraft(
        localId: 'step-1',
        stepOrder: 1,
        title: 'Warm-up',
      ),
    ],
    published: false,
    contentKind: TrainingContentKind.session,
    authoringScope: TrainingAuthoringScope.programmeOnly,
    endorsementStatus: TrainingEndorsementStatus.coachAuthored,
    programmeVersionId: programmeVersionId,
  );
}

ProgrammeBuilderDocument buildProgrammeDocumentWithSlot({
  String versionId = testProgrammeVersionId,
  String slotLocalId = testSlotLocalId,
  String dayLocalId = testDayLocalId,
  String weekLocalId = testWeekLocalId,
}) {
  return ProgrammeBuilderDocument.clean(
    metadata: ProgrammeVersionDraftMetadata(
      versionId: versionId,
      lineageId: 'lineage-1',
      lineageCode: 'COHORT-TEST',
      versionNumber: 1,
      name: 'Foundation Test',
    ),
    template: ProgrammeTemplateDraft(
      weeks: [
        ProgrammeWeekDraft(
          localId: weekLocalId,
          weekNumber: 2,
          days: [
            ProgrammeDayDraft(
              localId: dayLocalId,
              dayKey: 'day_1',
              dayOrder: 1,
              title: 'Tuesday',
              slots: [
                ProgrammeSessionSlotDraft(
                  localId: slotLocalId,
                  sessionOrder: 1,
                  protocolId: '',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

const testCohortProtocolId = '33333333-3333-3333-3333-333333333333';

ProtocolDraft buildEligibleCohortProtocolDraft({
  String protocolId = testCohortProtocolId,
  String name = 'Threshold Intervals',
}) {
  return ProtocolDraft(
    protocolId: protocolId,
    name: name,
    sessionFormat: 'intervals',
    sessionType: 'Running',
    durationMin: 45,
    coachingNotes: 'Hold threshold pace.',
    steps: const [
      ProtocolStepDraft(
        localId: 'step-1',
        stepOrder: 1,
        title: 'Warm-up',
        sets: '1',
        duration: '10 min',
      ),
      ProtocolStepDraft(
        localId: 'step-2',
        stepOrder: 2,
        title: 'Intervals',
        sets: '5',
        duration: '3 min',
      ),
    ],
    published: true,
    contentKind: TrainingContentKind.cohortProtocol,
    authoringScope: TrainingAuthoringScope.cohortGlobal,
    endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
  );
}

class FixedSessionIdGenerator implements TrainingContentIdGenerator {
  FixedSessionIdGenerator(this.id);

  final String id;

  @override
  String newSessionId() => id;
}

class FixedCoachIdentity implements CurrentCoachIdentity {
  const FixedCoachIdentity(this.coachId);

  @override
  final String? coachId;
}

class FakeProtocolBuilderService extends ProtocolBuilderService {
  FakeProtocolBuilderService();

  final Map<String, ProtocolDraft> drafts = {};
  final Map<String, ProtocolDraft> libraryDrafts = {};
  bool failSave = false;
  int saveCallCount = 0;
  int librarySaveCallCount = 0;

  @override
  Future<ProtocolBuilderSaveResult> saveDraft(ProtocolDraft draft) async {
    saveCallCount++;
    if (failSave) {
      throw const ProtocolBuilderException('Save failed.');
    }

    drafts[draft.protocolId] = draft;
    return ProtocolBuilderSaveResult.draft(
      protocolId: draft.protocolId,
      created: !drafts.containsKey(draft.protocolId),
      stepCount: draft.steps.length,
    );
  }

  @override
  Future<ProtocolBuilderSaveResult> saveCoachLibrarySession(
    ProtocolDraft draft,
  ) async {
    librarySaveCallCount++;
    if (failSave) {
      throw const ProtocolBuilderException('Save failed.');
    }

    libraryDrafts[draft.protocolId] = draft;
    drafts[draft.protocolId] = draft;
    return ProtocolBuilderSaveResult.draft(
      protocolId: draft.protocolId,
      created: !libraryDrafts.containsKey(draft.protocolId),
      stepCount: draft.steps.length,
    );
  }

  @override
  Future<ProtocolDraft> loadProtocol(String protocolId) async {
    final draft = libraryDrafts[protocolId] ?? drafts[protocolId];
    if (draft == null) {
      throw ProtocolBuilderException('Protocol $protocolId could not be found.');
    }
    return draft;
  }
}

class FakeProgrammeSessionAssignmentPort implements ProgrammeSessionAssignmentPort {
  FakeProgrammeSessionAssignmentPort({
    required ProgrammeBuilderDocument document,
    this.isEditable = true,
    this.failAttach = false,
    this.slotExistsOverride,
  }) : _document = document;

  ProgrammeBuilderDocument _document;
  final bool isEditable;
  bool failAttach;
  final bool Function({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  })? slotExistsOverride;

  int assignCallCount = 0;
  String? lastAssignedContentId;
  String? lastAssignedDisplayTitle;

  @override
  ProgrammeBuilderDocument? get document => _document;

  @override
  String get programmeVersionId => _document.metadata.versionId ?? '';

  @override
  bool slotExists({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  }) {
    if (slotExistsOverride != null) {
      return slotExistsOverride!(
        weekLocalId: weekLocalId,
        dayLocalId: dayLocalId,
        slotLocalId: slotLocalId,
      );
    }

    for (final week in _document.template.allWeeks) {
      if (week.localId != weekLocalId) continue;
      for (final day in week.days) {
        if (day.localId != dayLocalId) continue;
        for (final slot in day.slots) {
          if (slot.localId == slotLocalId) return true;
        }
      }
    }

    return false;
  }

  @override
  Future<ProgrammeBuilderEditResult> assignSession({
    required String slotLocalId,
    required String contentId,
    required String displayTitle,
  }) async {
    assignCallCount++;
    lastAssignedContentId = contentId;
    lastAssignedDisplayTitle = displayTitle;

    if (failAttach) {
      throw StateError('Attach failed.');
    }

    _document = const ProgrammeBuilderEditOperations().assignProtocol(
      _document,
      slotLocalId: slotLocalId,
      protocolId: contentId,
      displayTitle: displayTitle,
    );

    return ProgrammeBuilderEditResult(document: _document);
  }
}
