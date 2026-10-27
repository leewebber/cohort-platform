import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';

void main(List<String> args) {
  final body = jsonDecode(
    File(
      'test/session/fixtures/zone2_admission/easy_run.json',
    ).readAsStringSync(),
  );
  final out = StringBuffer(
    'CREATE TABLE public.zone2_fixture_payload(version int PRIMARY KEY,payload jsonb NOT NULL);\n',
  );
  for (final version in [1, 2]) {
    final source =
        File('test/session/fixtures/authored_timed_run_v$version.yaml')
            .readAsStringSync()
            .replaceAll(
              'M23-SOFTWARE-FIXTURE-ONLY',
              'ZONE2-SOFTWARE-FIXTURE-$version',
            )
            .replaceAll('M23-FIXTURE-R1', 'ZONE2-FIXTURE-$version-R1')
            .replaceAll(
              'b3d00000-0000-4000-8000-000000000023',
              'd2300000-0000-4000-8000-00000000000$version',
            );
    final compiled = const PlanPackageCompiler().compile(source);
    if (!compiled.isValid) throw StateError(compiled.issues.toString());
    final payload = const PlanPackageImportPayloadBuilder()
        .buildRetainedPublication(
          compileResult: compiled,
          importedBy: 'local-zone2-fixture-only',
        );
    payload.addAll({
      'publication_kind': 'private_exact_version',
      'programme_version_id': 'd2300000-0000-4000-8000-00000000006$version',
      'library_scope': 'coach_private',
      'owner_id': 'd2300000-0000-4000-8000-000000000003',
      'protocol_graphs': [
        {
          'protocol_id': 'ZONE2-FIXTURE-$version-R1',
          'revision_number': 1,
          'blocks': [
            {
              'position': 1,
              'block_type': 'conditioning',
              'title': '[SOFTWARE FIXTURE ONLY] Easy run',
              'content': 'Never train from this fixture',
              'workout_format': 'steady_state',
              'performance_capture_mode': 'endurance',
              'timer_config': {
                'durationSeconds': 1500,
                'running_workout': body,
              },
              'exercises': [],
            },
          ],
        },
      ],
    });
    out.writeln(
      "INSERT INTO public.zone2_fixture_payload VALUES($version,\$payload\$${jsonEncode(payload)}\$payload\$::jsonb);",
    );
  }
  File(args.single).writeAsStringSync(out.toString());
}
