import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/compile_package.dart <yaml>');
    exit(2);
  }
  final yaml = File(args.first).readAsStringSync();
  final result = const PlanPackageCompiler().compile(yaml);
  if (!result.isValid) {
    for (final issue in result.issues) {
      stdout.writeln('${issue.path}\t${issue.code}\t${issue.message}');
    }
    exit(1);
  }
  stdout.writeln(result.contentHashSha256);
  stdout.writeln('sessions=${result.manifest!.sessions.length}');
}
