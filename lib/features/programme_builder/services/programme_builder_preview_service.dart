import '../models/programme_builder_document.dart';
import '../models/programme_builder_preview.dart';

/// Read-only programme preview for coach structural and athlete-facing views.
abstract class ProgrammeBuilderPreviewService {
  Future<ProgrammeBuilderPreview> buildPreview(
    ProgrammeBuilderDocument document, {
    Map<String, String> protocolNamesById = const {},
  });
}
