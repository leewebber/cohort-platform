import 'package:founder_importer/models/protocol_draft.dart';
import 'package:founder_importer/features/admin/services/protocol_builder_service.dart';

/// Persists programme-bound session drafts during founder import.
abstract class FounderProgrammeProtocolWriter {
  Future<void> saveDraft(ProtocolDraft draft);
}

class ProtocolBuilderProgrammeProtocolWriter
    implements FounderProgrammeProtocolWriter {
  ProtocolBuilderProgrammeProtocolWriter(this._service);

  final ProtocolBuilderService _service;

  @override
  Future<void> saveDraft(ProtocolDraft draft) async {
    await _service.saveDraft(draft);
  }
}
