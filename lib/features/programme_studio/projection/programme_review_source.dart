import '../domain/programme_review_models.dart';

class ProgrammeReviewSourceSpec {
  const ProgrammeReviewSourceSpec({
    required this.catalogId,
    required this.classification,
    required this.planPackagePath,
    this.founderYamlPath,
    this.publicationJsonPath,
    this.executableProtocolSqlPaths = const [],
    this.unreplayedSqlPaths = const [],
    this.fixture = false,
  });

  final String catalogId;
  final ProgrammeReviewClassification classification;
  final String planPackagePath;
  final String? founderYamlPath;
  final String? publicationJsonPath;
  final List<String> executableProtocolSqlPaths;
  final List<String> unreplayedSqlPaths;
  final bool fixture;
}

class ProgrammeReviewSourceBundle {
  const ProgrammeReviewSourceBundle({
    required this.spec,
    required this.planPackageYaml,
    this.founderYaml,
    this.publicationJson,
    this.executableProtocolSql = const [],
  });

  final ProgrammeReviewSourceSpec spec;
  final String planPackageYaml;
  final String? founderYaml;
  final String? publicationJson;
  final List<String> executableProtocolSql;
}

class ProgrammeReviewProjectionRequest {
  const ProgrammeReviewProjectionRequest({
    required this.bundles,
    this.plannedFamilies = const [],
    this.includeDeveloperFixtures = false,
  });

  final List<ProgrammeReviewSourceBundle> bundles;
  final List<ProgrammeReviewPlannedFamily> plannedFamilies;
  final bool includeDeveloperFixtures;
}
