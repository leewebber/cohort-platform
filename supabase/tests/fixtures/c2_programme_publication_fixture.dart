import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';

/// Synthetic infrastructure fixture only. Never selects a real programme.
void main(List<String> args) {
  final tree = <String, Object?>{
    'package_schema_version': 1,
    'programme': {
      'lineage_code': 'C2-SYNTHETIC-RETENTION',
      'version_number': 1,
      'name': 'Synthetic C2 scope',
      'library_scope': 'coach_private',
      'owner_type': 'coach',
      'coaching_intent': 'Synthetic observational fixture',
      'duration_weeks': 1,
      'sessions_per_week': 1,
    },
    'sessions': [
      {
        'session_key': 'synthetic-session',
        'protocol_id': 'c2.retained.synthetic',
        'session_lineage_id': 'c2000000-0000-4000-8000-000000000050',
        'revision_number': 1,
        'title': 'Synthetic session',
      },
    ],
    'phases': [],
    'weeks': [
      {
        'week_number': 1,
        'days': [
          {
            'day_key': 'day_1',
            'day_order': 1,
            'day_type': 'training',
            'slots': [
              {
                'slot_key': 'synthetic-slot',
                'session_order': 1,
                'session_key': 'synthetic-session',
                'progression': {
                  'prescription_summary': 'Synthetic source fixture',
                },
              },
            ],
          },
        ],
      },
    ],
    'adaptation_permissions': [],
    'protected_invariants': [],
    'assessments': [],
    'performance_evidence_requirements': [],
    'comparison_identities': [],
  };
  final output = StringBuffer(
    'CREATE TABLE public.c2p_payload(kind text PRIMARY KEY,payload jsonb NOT NULL);\n',
  );
  for (final version in [1, 2]) {
    final data = jsonDecode(jsonEncode(tree)) as Map<String, Object?>;
    data['package_schema_version'] = version;
    final programme = data['programme'] as Map<String, dynamic>;
    programme['lineage_code'] = 'C2-SYNTHETIC-RETENTION-$version';
    final sessions = data['sessions'] as List;
    (sessions.single as Map)['protocol_id'] = 'c2.retained.synthetic.$version';
    (sessions.single as Map)['session_lineage_id'] =
        'c2000000-0000-4000-8000-00000000005$version';
    if (version == 2) {
      final digest = md5
          .convert(utf8.encode('c2.retained.synthetic.2:block:1'))
          .toString();
      final blockId =
          '${digest.substring(0, 8)}-${digest.substring(8, 12)}-4${digest.substring(12, 15)}-8${digest.substring(16, 19)}-${digest.substring(20, 32)}';
      final token = 'steady_state|d=12|w=|r=|n=|src=$blockId';
      final workout =
          'rw1:p:${sha256.convert(utf8.encode(token)).toString().substring(0, 16)}';
      final slot = (data['weeks'] as List).single['days'][0]['slots'][0] as Map;
      slot['authored_running_v1'] = {
        'schema_version': 1,
        'workout_id': workout,
        'step_ids': ['$workout:s:0'],
        'executable_step_bindings': [
          {'step_id': '$workout:s:0', 'session_block_id': blockId},
        ],
        'advisory_attachments': [
          {
            'attachment_id': 'SYNTHETIC-C2-ATTACHMENT',
            'step_ids': ['$workout:s:0'],
            'policy': {
              'policy_id': 'SYNTHETIC-C2-POLICY',
              'policy_version': 1,
              'method_id': 'PERCENT-BENCHMARK-SPEED',
              'method_version': 1,
              'benchmark_eligibility': {
                'cohort_completed_tests_eligible': false,
                'manual_completed_tests_eligible': true,
                'external_completed_tests_eligible': false,
              },
              'freshness_local_civil_days': 90,
              'minimum_speed_basis_points': 8123,
              'maximum_speed_basis_points': 9345,
              'display_rounding': {
                'increment_milliseconds_per_kilometre': 1000,
                'direction': 'nearest',
              },
            },
          },
        ],
      };
    }
    final compiled = const PlanPackageCompiler().compile(jsonEncode(data));
    if (!compiled.isValid) throw StateError(compiled.issues.toString());
    final payload = const PlanPackageImportPayloadBuilder()
        .buildRetainedPublication(
          compileResult: compiled,
          importedBy: 'synthetic-local-gate',
        );
    payload.addAll({
      'publication_kind': 'private_exact_version',
      'programme_version_id': 'c2000000-0000-4000-8000-00000000006$version',
      'library_scope': 'coach_private',
      'owner_id': 'c2000000-0000-4000-8000-000000000003',
      'protocol_graphs': [
        {
          'protocol_id': 'c2.retained.synthetic.$version',
          'blocks': [
            {
              'position': 1,
              'block_type': 'conditioning',
              'title': 'Synthetic observed block',
              'content': 'Synthetic source',
              'workout_format': 'steady_state',
              'timer_config': {'duration_seconds': 12},
              'performance_capture_mode': 'auto',
              'exercises': [
                {
                  'exercise_id': 'c2.synthetic.movement',
                  'position': 1,
                  'prescription': {'sets': 1},
                },
              ],
            },
          ],
        },
      ],
    });
    output.writeln(
      "INSERT INTO public.c2p_payload VALUES('v$version',\$payload\$${jsonEncode(payload)}\$payload\$::jsonb);",
    );
  }
  File(args.single).writeAsStringSync(output.toString());
}
