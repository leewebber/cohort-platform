import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';

/// Programme document mutation port for Session attach flows.
abstract interface class ProgrammeSessionAssignmentPort {
  ProgrammeBuilderDocument? get document;

  bool get isEditable;

  String get programmeVersionId;

  bool slotExists({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  });

  Future<ProgrammeBuilderEditResult> assignSession({
    required String slotLocalId,
    required String contentId,
    required String displayTitle,
  });
}
