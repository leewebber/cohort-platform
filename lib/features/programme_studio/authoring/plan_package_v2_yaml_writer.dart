import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';

/// Schema-aware native source transport. JSON is a strict YAML subset. The
/// existing compiler remains the only canonicaliser and package hash authority.
/// The original v1 writer and its formatting contract are unchanged.
class PlanPackageV2YamlWriter {
  const PlanPackageV2YamlWriter();

  String writeDraft(Map<String, dynamic> tree) {
    if (tree['package_schema_version'] != 2) {
      throw const FormatException('Expected a Plan Package v2 source.');
    }
    return '${const JsonEncoder.withIndent('  ').convert(tree)}\n';
  }

  String write(PlanPackageManifest manifest) => writeDraft(
    jsonDecode(const PlanPackageCanonicaliser().canonicalJson(manifest))
        as Map<String, dynamic>,
  );
}
