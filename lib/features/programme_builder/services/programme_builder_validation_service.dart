import '../models/programme_builder_document.dart';
import '../models/programme_publish_readiness.dart';
import '../models/programme_validation_result.dart';

/// Pure programme builder validation and publish-readiness derivation.
abstract class ProgrammeBuilderValidationService {
  ProgrammeValidationResult validate(ProgrammeBuilderDocument document);

  ProgrammeValidationResult validateForPublish(
    ProgrammeBuilderDocument document, {
    Set<String>? knownProtocolIds,
  });

  ProgrammePublishReadiness buildPublishReadiness(
    ProgrammeBuilderDocument document, {
    ProgrammeValidationResult? validation,
    Set<String>? knownProtocolIds,
  });
}
