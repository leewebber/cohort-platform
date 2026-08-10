import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'plan_package_canonicaliser.dart';
import 'plan_package_manifest.dart';
import 'plan_package_validation_issue.dart';
import 'plan_package_validator.dart';
import 'plan_package_yaml_parser.dart';

/// Pure Plan Package compiler: YAML → validate → canonicalise → SHA-256.
///
/// Side-effect free: no database, network, Coach Brain, PlanDefinition,
/// programme generation, or mutation of existing programme/session versions.
class PlanPackageCompiler {
  const PlanPackageCompiler({
    this.parser = const PlanPackageYamlParser(),
    this.validator = const PlanPackageValidator(),
    this.canonicaliser = const PlanPackageCanonicaliser(),
  });

  final PlanPackageYamlParser parser;
  final PlanPackageValidator validator;
  final PlanPackageCanonicaliser canonicaliser;

  /// Compile [yamlSource] into a validated manifest + content hash, or issues.
  PlanPackageCompileResult compile(String yamlSource) {
    final parsed = parser.parse(yamlSource);
    if (!parsed.isValid || parsed.manifest == null) {
      return PlanPackageCompileResult.invalid(parsed.issues);
    }

    final semanticIssues = validator.validate(parsed.manifest!);
    if (semanticIssues.isNotEmpty) {
      return PlanPackageCompileResult.invalid(semanticIssues);
    }

    final manifest = parsed.manifest!;
    final bytes = canonicaliser.canonicalBytes(manifest);
    final digest = sha256.convert(bytes);
    final hash = digest.toString(); // crypto package: lowercase hex

    return PlanPackageCompileResult.valid(
      manifest: manifest,
      canonicalBytes: bytes,
      contentHashSha256: hash,
    );
  }
}

/// Result of compiling one Authored Plan Package.
class PlanPackageCompileResult {
  const PlanPackageCompileResult._({
    required this.isValid,
    this.manifest,
    this.canonicalBytes,
    this.contentHashSha256,
    required this.issues,
  });

  factory PlanPackageCompileResult.valid({
    required PlanPackageManifest manifest,
    required Uint8List canonicalBytes,
    required String contentHashSha256,
  }) {
    return PlanPackageCompileResult._(
      isValid: true,
      manifest: manifest,
      canonicalBytes: canonicalBytes,
      contentHashSha256: contentHashSha256,
      issues: const [],
    );
  }

  factory PlanPackageCompileResult.invalid(
    List<PlanPackageValidationIssue> issues,
  ) {
    return PlanPackageCompileResult._(
      isValid: false,
      issues: List.unmodifiable(issues),
    );
  }

  final bool isValid;
  final PlanPackageManifest? manifest;
  final Uint8List? canonicalBytes;
  final String? contentHashSha256;
  final List<PlanPackageValidationIssue> issues;

  /// Canonical UTF-8 string when compilation succeeded.
  String? get canonicalJson {
    final bytes = canonicalBytes;
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }
}
