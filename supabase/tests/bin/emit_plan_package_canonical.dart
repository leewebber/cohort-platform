import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';

void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart run supabase/tests/bin/emit_plan_package_canonical.dart '
      '<input-yaml> <output-canonical-json> <output-sha256>',
    );
    exitCode = 64;
    return;
  }

  final compiled = const PlanPackageCompiler().compile(
    File(arguments[0]).readAsStringSync(),
  );
  if (!compiled.isValid) {
    stderr.writeln('Plan Package compilation failed: ${compiled.issues}');
    exitCode = 1;
    return;
  }
  File(arguments[1]).writeAsStringSync('${compiled.canonicalJson!}\n');
  File(arguments[2]).writeAsStringSync('${compiled.contentHashSha256!}\n');
}
