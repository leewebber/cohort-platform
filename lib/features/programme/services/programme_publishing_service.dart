import '../../../models/programme_version.dart';

/// Draft → published lifecycle for programme versions.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.2.
abstract class ProgrammePublishingService {
  Future<ProgrammeVersion> publishDraft({
    required String versionId,
    required String publishedByCoachId,
  });

  Future<ProgrammeVersion> archiveVersion(String versionId);

  Future<ProgrammeVersion> cloneToNewDraft({
    required String publishedVersionId,
  });
}
