import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../projection/programme_review_source.dart';

/// A bounded local source policy. Legacy D1 fixtures retain their fixed policy.
abstract interface class ProgrammeAuthoringSource {
  String get id;
  String get label;
  String get originalSource;
  Map<String, dynamic> get trustedTree;
  List<Map<String, dynamic>> get sessionReferences;
  List<PlanPackageValidationIssue> catalogueIssues(
    PlanPackageManifest manifest,
  );
  ProgrammeReviewSourceBundle bundle(String exactYaml);
}
