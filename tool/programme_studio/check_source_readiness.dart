import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/programme_studio/projection/source_readiness_report.dart';

/// Run from the repository root. Exit zero means report generated, never approved.
void main(List<String> args) {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/programme_studio/check_source_readiness.dart [registered-id]',
    );
    exitCode = 64;
    return;
  }
  try {
    final report = sourceReadinessReport(
      catalogId: args.isEmpty ? 'hyrox-base' : args.single,
      readAsset: (path) => File(path).readAsStringSync(),
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 65;
  } on FileSystemException {
    stderr.writeln(
      'Registered source unavailable. No readiness report was generated.',
    );
    exitCode = 66;
  }
}
