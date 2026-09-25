import 'programme_review_catalog.dart';
import 'programme_review_projector.dart';
import 'programme_review_source.dart';
import '../domain/programme_review_models.dart';

typedef ProgrammeReviewAssetRead = String Function(String relativePath);

class ProgrammeReviewWorkspace {
  ProgrammeReviewWorkspace({
    required this.readAsset,
    this.projector = const ProgrammeReviewProjector(),
  });

  final ProgrammeReviewAssetRead readAsset;
  final ProgrammeReviewProjector projector;

  ProgrammeReviewCatalog loadRealCatalog() {
    return projector.project(
      ProgrammeReviewProjectionRequest(
        bundles: [
          for (final spec in ProgrammeReviewCatalogRegistry.realSpecs)
            loadBundle(spec),
        ],
        plannedFamilies: ProgrammeReviewCatalogRegistry.plannedFamilies,
      ),
    );
  }

  ProgrammeReviewSourceBundle loadBundle(ProgrammeReviewSourceSpec spec) {
    return ProgrammeReviewSourceBundle(
      spec: spec,
      planPackageYaml: readAsset(spec.planPackagePath),
      founderYaml: spec.founderYamlPath == null
          ? null
          : readAsset(spec.founderYamlPath!),
      publicationJson: spec.publicationJsonPath == null
          ? null
          : readAsset(spec.publicationJsonPath!),
      executableProtocolSql: [
        for (final path in spec.executableProtocolSqlPaths) readAsset(path),
      ],
      correctionSql: [
        for (final path in spec.correctionSqlPaths)
          ProgrammeSqlSource(path: path, sql: readAsset(path)),
      ],
    );
  }
}
