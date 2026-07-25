import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../models/protocol_draft.dart';

/// Persists code-authored [ProtocolDraft] rows through [ProtocolBuilderService].
///
/// Do not write directly to Supabase from programme code — use this boundary.
class ProgrammeCodeAuthoringPersistence {
  const ProgrammeCodeAuthoringPersistence(this._protocolBuilder);

  final ProtocolBuilderService _protocolBuilder;

  Future<void> saveProgrammeSession(ProtocolDraft draft) {
    return _protocolBuilder.saveDraft(draft).then((_) {});
  }

  Future<void> saveReusableSession(ProtocolDraft draft) {
    return _protocolBuilder.saveCoachLibrarySession(draft).then((_) {});
  }

  Future<ProtocolDraft> loadSession(String protocolId) {
    return _protocolBuilder.loadProtocol(protocolId);
  }
}
