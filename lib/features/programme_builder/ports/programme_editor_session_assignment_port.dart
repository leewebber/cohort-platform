import '../../../features/coach_studio/programmes/controllers/programme_editor_controller.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';
import 'programme_session_assignment_port.dart';

/// Applies Session attachment through [ProgrammeEditorController].
class ProgrammeEditorSessionAssignmentPort
    implements ProgrammeSessionAssignmentPort {
  ProgrammeEditorSessionAssignmentPort({
    required ProgrammeEditorController controller,
  }) : _controller = controller;

  final ProgrammeEditorController _controller;

  @override
  ProgrammeBuilderDocument? get document => _controller.document;

  @override
  bool get isEditable => !_controller.isReadOnly;

  @override
  String get programmeVersionId => _controller.versionId;

  @override
  bool slotExists({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  }) {
    final doc = document;
    if (doc == null) return false;

    for (final week in doc.template.allWeeks) {
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
    final doc = document;
    if (doc == null) {
      throw StateError('Programme document is not loaded.');
    }

    await _controller.assignProtocol(
      slotLocalId: slotLocalId,
      protocolId: contentId,
      displayTitle: displayTitle,
    );

    return ProgrammeBuilderEditResult(
      document: _controller.document ?? doc,
    );
  }
}
