import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../projection/programme_review_source.dart';

/// A bounded local source policy. Legacy D1 fixtures retain their fixed policy.
abstract interface class ProgrammeAuthoringSource {
  bool get supportsScheduleEditing;
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

/// Optional policy for native graph sources. Fixed D1/D2 policies retain their
/// original writer, supported week shapes and immutable source skeleton.
abstract interface class NativeProgrammeAuthoringSource
    implements ProgrammeAuthoringSource {
  String writeDraft(Map<String, dynamic> tree);
  void checkScheduleShape(Map<String, dynamic> tree);
}
