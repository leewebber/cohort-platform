import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';

/// A source writer, not a new package/hash format. The existing canonicaliser
/// supplies every v1 field and its order; strings are always JSON/YAML quoted.
class PlanPackageV1YamlWriter {
  const PlanPackageV1YamlWriter();

  String write(PlanPackageManifest manifest) {
    if (manifest.packageSchemaVersion != 1) {
      throw const FormatException('D1 exports Plan Package v1 only.');
    }
    return writeDraft(
      jsonDecode(const PlanPackageCanonicaliser().canonicalJson(manifest))
          as Map<String, dynamic>,
    );
  }

  /// Draft text may be invalid. Only the controller's exact-byte compilation
  /// and review gate can make it exportable. No field is filtered here.
  String writeDraft(Map<String, dynamic> tree) {
    if (tree['package_schema_version'] != 1) {
      throw const FormatException('D1 exports Plan Package v1 only.');
    }
    return '${_node(tree, 0).join('\n')}\n';
  }

  List<String> _node(Object? value, int indent) {
    final pad = ' ' * indent;
    if (value is Map) {
      if (value.isEmpty) return ['$pad{}'];
      final keys = value.keys.cast<String>().toList()..sort();
      return [
        for (final key in keys) ..._entry('$pad$key:', value[key], indent),
      ];
    }
    if (value is List) {
      if (value.isEmpty) return ['$pad[]'];
      return [for (final item in value) ..._entry('$pad-', item, indent)];
    }
    return ['$pad${_scalar(value)}'];
  }

  List<String> _entry(String prefix, Object? value, int indent) {
    if (value is Map && value.isNotEmpty || value is List && value.isNotEmpty) {
      return [prefix, ..._node(value, indent + 2)];
    }
    return [
      '$prefix ${value is Map
          ? '{}'
          : value is List
          ? '[]'
          : _scalar(value)}',
    ];
  }

  String _scalar(Object? value) {
    if (value == null || value is String || value is bool || value is int) {
      return jsonEncode(value);
    }
    throw FormatException('Unsupported source scalar ${value.runtimeType}.');
  }
}
