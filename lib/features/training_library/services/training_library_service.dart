import '../../../data/repositories/protocol_repository.dart';
import '../../../models/protocol.dart';
import '../../../models/training_content_vocabulary.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/training_library_item_summary.dart';

/// Loads Training Library catalogue data without widget-level Supabase access.
class TrainingLibraryService {
  TrainingLibraryService({
    ProtocolRepository? protocolRepository,
  }) : _protocolRepository = protocolRepository ?? ProtocolRepository();

  final ProtocolRepository _protocolRepository;

  Future<List<TrainingLibraryItemSummary>> loadCohortProtocolSummaries({
    int limit = 100,
  }) async {
    final protocols = await _protocolRepository.listCohortProtocols(limit: limit);
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
    );
  }
}
