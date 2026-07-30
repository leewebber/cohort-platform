import '../../../data/repositories/protocol_repository.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/session_template_taxonomy.dart';
import '../models/training_library_item_summary.dart';
import 'cohort_session_template_catalogue.dart';

/// Loads Training Library catalogue data without widget-level Supabase access.
class TrainingLibraryService {
  TrainingLibraryService({
    ProtocolRepository? protocolRepository,
    SessionTemplateTaxonomy taxonomy = const SessionTemplateTaxonomy(),
  }) : _protocolRepository = protocolRepository ?? ProtocolRepository(),
       _taxonomy = taxonomy;

  final ProtocolRepository _protocolRepository;
  final SessionTemplateTaxonomy _taxonomy;

  Future<List<TrainingLibraryItemSummary>> loadCohortProtocolSummaries({
    int limit = 100,
  }) async {
    final protocols = await _protocolRepository.listCohortProtocols(
      limit: limit,
    );
    TrainingLibraryDiagnostics.log('cohortLoaded count=${protocols.length}');
    return protocols.map(_cohortSummaryFromProtocol).toList();
  }

  Future<List<TrainingLibraryItemSummary>> loadReusableSessionSummaries({
    required String ownerId,
    String? searchTerm,
    int limit = 100,
  }) async {
    final protocols = await _protocolRepository.listReusableCoachSessions(
      ownerId,
      limit: limit,
    );

    var summaries = protocols.map(_sessionSummaryFromProtocol).toList();
    final term = searchTerm?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      summaries = summaries
          .where((item) => item.title.toLowerCase().contains(term))
          .toList();
    }

    SessionLibraryDiagnostics.log('loaded count=${summaries.length}');
    return summaries;
  }

  /// Canonical Cohort Templates for Training Library + Programme Builder.
  ///
  /// Does not filter by coach owner. Coach-owned template creation is out of
  /// V1 scope; this catalogue is product-owned starter content only.
  Future<List<TrainingLibraryItemSummary>> loadCanonicalTemplateSummaries({
    String? searchTerm,
    SessionTemplateModalityFilter modality = SessionTemplateModalityFilter.all,
    SessionTemplateEquipmentFilter equipment =
        SessionTemplateEquipmentFilter.all,
    int limit = 100,
  }) async {
    final protocols = await _protocolRepository.listCanonicalSessionTemplates(
      limit: limit,
    );

    var summaries = protocols
        .map(_canonicalTemplateSummaryFromProtocol)
        .toList();

    summaries = _applyTemplateFilters(
      summaries,
      searchTerm: searchTerm,
      modality: modality,
      equipment: equipment,
    );

    TrainingLibraryDiagnostics.log(
      'templatesLoaded count=${summaries.length} modality=${modality.name} '
      'equipment=${equipment.name}',
    );
    return summaries;
  }

  /// Prefer [loadCanonicalTemplateSummaries] for product catalogue surfaces.
  @Deprecated('Use loadCanonicalTemplateSummaries for the shared catalogue')
  Future<List<TrainingLibraryItemSummary>> loadSessionTemplateSummaries({
    String? ownerId,
    String? searchTerm,
    int limit = 100,
  }) {
    // Ignore ownerId for the shared Cohort catalogue path.
    return loadCanonicalTemplateSummaries(searchTerm: searchTerm, limit: limit);
  }

  /// In-memory catalogue summaries for tests and offline seed inspection.
  List<TrainingLibraryItemSummary> catalogueFixtureSummaries({
    String? searchTerm,
    SessionTemplateModalityFilter modality = SessionTemplateModalityFilter.all,
    SessionTemplateEquipmentFilter equipment =
        SessionTemplateEquipmentFilter.all,
  }) {
    final summaries = CohortSessionTemplateCatalogue.all()
        .map(_canonicalTemplateSummaryFromDraft)
        .toList();
    return _applyTemplateFilters(
      summaries,
      searchTerm: searchTerm,
      modality: modality,
      equipment: equipment,
    );
  }

  List<TrainingLibraryItemSummary> _applyTemplateFilters(
    List<TrainingLibraryItemSummary> summaries, {
    String? searchTerm,
    required SessionTemplateModalityFilter modality,
    required SessionTemplateEquipmentFilter equipment,
  }) {
    var filtered = summaries;
    final term = searchTerm?.trim().toLowerCase();
    if (term != null && term.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item.title.toLowerCase().contains(term) ||
                (item.purpose?.toLowerCase().contains(term) ?? false) ||
                (item.sessionType?.toLowerCase().contains(term) ?? false),
          )
          .toList();
    }

    filtered = filtered
        .where(
          (item) =>
              _taxonomy.matchesModality(
                modality,
                itemModality: item.modalityFilter,
              ) &&
              _taxonomy.matchesEquipment(
                equipment,
                itemEquipment: item.equipmentFilter,
              ),
        )
        .toList();

    return filtered;
  }

  TrainingLibraryItemSummary _cohortSummaryFromProtocol(Protocol protocol) {
    return TrainingLibraryItemSummary(
      contentId: protocol.protocolId,
      contentKind: TrainingContentKind.cohortProtocol,
      title: protocol.name,
      sessionType: protocol.sessionType,
      durationMin: protocol.durationMin,
      endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      authoringScope: TrainingAuthoringScope.cohortGlobal,
      publicCode: protocol.protocolId,
      purpose: protocol.description,
      requiredEquipment: protocol.requiredEquipment ?? protocol.equipment,
      technicalComplexity: protocol.technicalComplexity,
    );
  }

  TrainingLibraryItemSummary _sessionSummaryFromProtocol(Protocol protocol) {
    return TrainingLibraryItemSummary(
      contentId: protocol.protocolId,
      contentKind: TrainingContentKind.session,
      title: protocol.name,
      sessionType: protocol.sessionType,
      durationMin: protocol.durationMin,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      purpose: protocol.description,
      requiredEquipment: protocol.requiredEquipment ?? protocol.equipment,
      technicalComplexity: protocol.technicalComplexity,
    );
  }

  TrainingLibraryItemSummary _canonicalTemplateSummaryFromProtocol(
    Protocol protocol,
  ) {
    final modality = _taxonomy.modalityForProtocol(protocol);
    final equipment = _taxonomy.equipmentBucketFor(
      requiredEquipment: protocol.requiredEquipment,
      legacyEquipment: protocol.equipment,
    );
    return TrainingLibraryItemSummary(
      contentId: protocol.protocolId,
      contentKind: TrainingContentKind.sessionTemplate,
      title: protocol.name,
      sessionType: protocol.sessionType,
      durationMin: protocol.durationMin,
      endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      authoringScope: TrainingAuthoringScope.cohortGlobal,
      publicCode: protocol.protocolId,
      purpose: protocol.description,
      requiredEquipment: protocol.requiredEquipment ?? protocol.equipment,
      technicalComplexity: protocol.technicalComplexity,
      primarySessionIntent: protocol.primarySessionIntent,
      modalityFilter: modality,
      equipmentFilter: equipment,
    );
  }

  TrainingLibraryItemSummary _canonicalTemplateSummaryFromDraft(
    ProtocolDraft draft,
  ) {
    final modality = _taxonomy.modalityForDraft(draft);
    final equipment = _taxonomy.equipmentBucketFor(
      requiredEquipment: draft.requiredEquipment,
    );
    return TrainingLibraryItemSummary(
      contentId: draft.protocolId,
      contentKind: TrainingContentKind.sessionTemplate,
      title: draft.name,
      sessionType: draft.sessionType,
      durationMin: draft.durationMin,
      stepCount: draft.steps.length,
      endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      authoringScope: TrainingAuthoringScope.cohortGlobal,
      publicCode: draft.protocolId,
      purpose: draft.purpose,
      requiredEquipment: draft.requiredEquipment,
      technicalComplexity: draft.technicalComplexity,
      primarySessionIntent: draft.primarySessionIntent,
      modalityFilter: modality,
      equipmentFilter: equipment,
    );
  }
}
