import '../../programme/models/programme_catalog_entry.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';
import '../models/programme_seed_template.dart';
import '../models/programme_version_draft_metadata.dart';

/// Primary authoring orchestration for Programme Builder.
///
/// See `44_Programme_Builder.md`.
abstract class ProgrammeBuilderService {
  Future<ProgrammeBuilderOperationResult> createDraftProgramme({
    required String coachId,
    required ProgrammeVersionDraftMetadata seedMetadata,
    ProgrammeSeedTemplate seedTemplate = ProgrammeSeedTemplate.empty,
  });

  Future<ProgrammeBuilderDocument> loadDocument({
    required String versionId,
  });

  Future<ProgrammeBuilderOperationResult> saveDocument(
    ProgrammeBuilderDocument document,
  );

  Future<ProgrammeBuilderEditResult> addWeek(ProgrammeBuilderDocument document);

  Future<ProgrammeBuilderEditResult> duplicateWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  });

  Future<ProgrammeBuilderEditResult> removeWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  });

  Future<ProgrammeBuilderEditResult> addDay(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  });

  Future<ProgrammeBuilderEditResult> removeDay(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  });

  Future<ProgrammeBuilderEditResult> updateDayMetadata(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    String? title,
    ProgrammeIntent? intent,
    bool clearTitle = false,
    bool clearIntent = false,
  });

  Future<ProgrammeBuilderEditResult> setDayType(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    required ProgrammeDayType dayType,
  });

  Future<ProgrammeBuilderEditResult> addSlot(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  });

  Future<ProgrammeBuilderEditResult> removeSlot(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  });

  Future<ProgrammeBuilderEditResult> assignProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  });

  Future<ProgrammeBuilderEditResult> clearProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  });

  Future<ProgrammeBuilderEditResult> updateSlotMetadata(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    String? displayTitle,
    ProgrammeSessionTimeOfDay? timeOfDay,
    bool? isOptional,
    ProgrammeSessionCompletionExpectation? completionExpectation,
    String? coachNote,
    String? athleteNote,
    bool clearDisplayTitle = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  });

  Future<ProgrammeBuilderEditResult> updateMetadata(
    ProgrammeBuilderDocument document,
    ProgrammeVersionDraftMetadata metadata,
  );

  Future<List<ProgrammeCatalogEntry>> listCoachDrafts({
    required String coachId,
  });

  /// Duplicate Programme — new lineage, version 1 draft.
  Future<ProgrammeBuilderOperationResult> duplicateProgramme({
    required String sourceVersionId,
    required String coachId,
    required String newLineageCode,
    required String newProgrammeName,
  });

  /// Deletes a draft version when safe. Service enforces eligibility rules.
  Future<ProgrammeBuilderOperationResult> deleteDraft({
    required String versionId,
    required String coachId,
  });

  ProgrammeBuilderEditResult? undo(ProgrammeBuilderDocument document);

  ProgrammeBuilderEditResult? redo(ProgrammeBuilderDocument document);
}
