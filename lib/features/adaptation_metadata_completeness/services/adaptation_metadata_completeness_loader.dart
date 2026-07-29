import '../../../core/services/current_coach_identity.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/coach_studio/programmes/services/programme_catalogue_services.dart';
import '../../../features/programme_builder/services/programme_builder_service.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../session_builder/services/protocol_draft_block_resolver.dart';
import '../models/adaptation_metadata_completeness_models.dart';
import 'adaptation_metadata_completeness_analyzer.dart';
import 'adaptation_metadata_completeness_input_factory.dart';

/// Loads programme sessions and protocols for founder completeness review.
class AdaptationMetadataCompletenessLoader {
  AdaptationMetadataCompletenessLoader({
    ProtocolBuilderService? protocolBuilderService,
    ProgrammeBuilderService? programmeBuilderService,
    ProtocolDraftBlockResolver? blockResolver,
    AdaptationMetadataCompletenessAnalyzer? analyzer,
    CurrentCoachIdentity? coachIdentity,
  }) : _protocolBuilderService =
           protocolBuilderService ?? ProtocolBuilderService(),
       _programmeBuilderService =
           programmeBuilderService ??
           ProgrammeCatalogueServices.createBuilderService(),
       _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver(),
       _analyzer = analyzer ?? const AdaptationMetadataCompletenessAnalyzer(),
       _coachIdentity = coachIdentity ?? const AuthenticatedCoachIdentity();

  final ProtocolBuilderService _protocolBuilderService;
  final ProgrammeBuilderService _programmeBuilderService;
  final ProtocolDraftBlockResolver _blockResolver;
  final AdaptationMetadataCompletenessAnalyzer _analyzer;
  final CurrentCoachIdentity _coachIdentity;

  Future<AdaptationMetadataCompletenessReport> load() async {
    final inputs = <AdaptationMetadataCompletenessInput>[];
    final standaloneProtocolIds = <String>{};

    final summaries = [
      ...await _protocolBuilderService.getPublishedProtocols(),
      ...await _protocolBuilderService.getDraftProtocols(),
    ];
    for (final summary in summaries) {
      standaloneProtocolIds.add(summary.protocolId);
    }

    final programmeBuilder = _programmeBuilderService;
    final coachId = _coachIdentity.coachId?.trim();
    if (coachId != null && coachId.isNotEmpty) {
      final draftProgrammes = await programmeBuilder.listCoachDrafts(
        coachId: coachId,
      );
      for (final entry in draftProgrammes) {
        final document = await programmeBuilder.loadDocument(
          versionId: entry.versionId,
        );
        for (final week in document.template.allWeeks) {
          for (final day in week.days) {
            for (final slot in day.slots) {
              final protocolId = slot.protocolId.trim();
              if (protocolId.isEmpty) continue;

              final draft = await _protocolBuilderService.loadProtocol(
                protocolId,
              );
              inputs.add(
                completenessInputFromProtocolDraft(
                  draft,
                  blockResolver: _blockResolver,
                  scope: AdaptationMetadataCompletenessScope.programmeSession,
                  programmeVersionId: entry.versionId,
                  programmeName: document.metadata.name,
                  slotLocationLabel:
                      'Week ${week.weekNumber} · ${day.dayKey} · #${slot.sessionOrder}',
                  programmeLibraryScope: entry.libraryScope,
                ),
              );
              standaloneProtocolIds.remove(protocolId);
            }
          }
        }
      }
    }

    for (final protocolId in standaloneProtocolIds) {
      final draft = await _protocolBuilderService.loadProtocol(protocolId);
      if (draft.contentKind != TrainingContentKind.cohortProtocol &&
          draft.endorsementStatus != TrainingEndorsementStatus.cohortEndorsed) {
        continue;
      }
      inputs.add(
        completenessInputFromProtocolDraft(
          draft,
          blockResolver: _blockResolver,
        ),
      );
    }

    return _analyzer.buildReport(inputs);
  }
}
