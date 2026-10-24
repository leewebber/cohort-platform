import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

/// Only for disposable synthetic integration proof. This is not a deployment
/// authority provider; production uses the independently validating SQL reader.
Future<void> main(List<String> args) async {
  final inputs =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final source = inputs['source'] as Map;
  final all = inputs['dependencies'] as List;
  final exercises = (inputs['exercises'] as List).cast<Map>();
  final targets = <Map<String, Object?>>[];
  final resolved = <Map<String, Object?>>[];
  for (final slot in ['slot-a', 'slot-b']) {
    for (final raw in all) {
      final dep = raw as Map;
      final kind = dep['kind'] as String;
      final exercise = exercises.singleWhere(
        (e) => ((e['publication'] as Map)['approved_binding_kinds'] as List)
            .contains(kind),
      );
      final block = (source['blocks'] as List).cast<Map>().singleWhere(
        (b) =>
            b['workout_format'] ==
                (kind == 'backSquat' ? 'none' : 'intervals') &&
            (b['exercises'] as List).length == 1 &&
            (b['exercises'] as List).single['exercise_id'] ==
                exercise['exercise_id'],
      );
      final params = Map<String, Object?>.from(
        (dep['rule_document']['weeks'] as List).first as Map,
      )..remove('week');
      final t = <String, Object?>{
        'id': '$slot-$kind',
        'slot_key': slot,
        'week_number': 1,
        'session_key': 'synthetic-source',
        'protocol_id': 'v3.synthetic.source',
        'protocol_revision': 1,
        'session_body_sha256': personalisationDigest(source),
        'block_id': block['block_id'],
        'step_ids': kind == 'backSquat'
            ? []
            : [
                for (var i = 1; i <= (params['repetitions']! as int); i++)
                  'work-$i',
              ],
        'identity_namespace': 'canonical_exercise',
        'exercise': {
          'id': exercise['exercise_id'],
          'version': int.parse(exercise['definition_version'] as String),
          'digest': exercise['content_digest'],
        },
        'rule': {
          'id': dep['rule_document']['id'],
          'version': 1,
          'digest': personalisationDigest(dep['rule_document']),
        },
        'benchmark': {
          'id': dep['benchmark_document']['id'],
          'version': 1,
          'digest': personalisationDigest(dep['benchmark_document']),
        },
        'kind': kind,
        'input_unit': dep['rule_document']['input_unit'],
        'output_unit': dep['rule_document']['output_unit'],
        'parameters': params,
      };
      targets.add(t);
      resolved.add({
        'target_id': t['id'],
        'exercise': exercise,
        'rule': dep['rule_document'],
        'benchmark': dep['benchmark_document'],
      });
    }
  }
  final tree = {
    'package_schema_version': 3,
    'programme': {
      'lineage_code': 'V3-SYNTHETIC-AUTHORITY',
      'version_number': 1,
      'name': 'Synthetic authority integration',
      'library_scope': 'coach_private',
      'owner_type': 'coach',
      'coaching_intent': 'Disposable synthetic proof; no commercial programme',
      'duration_weeks': 1,
      'sessions_per_week': 2,
    },
    'sessions': [
      {
        'session_key': 'synthetic-source',
        'protocol_id': 'v3.synthetic.source',
        'session_lineage_id': source['session_lineage_id'],
        'revision_number': 1,
        'title': 'Synthetic source',
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
              for (var i = 1; i <= 2; i++)
                {
                  'slot_key': i == 1 ? 'slot-a' : 'slot-b',
                  'session_order': i,
                  'session_key': 'synthetic-source',
                  'progression': {
                    'prescription_summary': 'Approved arithmetic fixture only',
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
    'personalisation_binding': {
      'binding_schema_version': 1,
      'freshness': 'none',
      'replacement_policy': 'explicit_consent_future_unstarted_only',
      'missing_input_policy': 'unavailable_with_authored_effort_only',
      'targets': targets,
    },
  };
  final bundle = <String, Object?>{
    'sessions': [source],
    'dependencies': resolved,
  };
  final authority = FixtureAuthority(bundle);
  final publisher = AuthoritativeV3Publication(authority);
  await publisher.publish(
    source: jsonEncode(tree),
    programmeVersionId: 'bc230000-0000-4000-8000-000000000040',
    ownerId: 'bc230000-0000-4000-8000-000000000001',
    importedBy: 'synthetic-trusted-fixture',
  );
  final payload = authority.payload!;
  File(args[1]).writeAsStringSync(
    "INSERT INTO public.v3_gate_data VALUES ('payload',\$doc\$${jsonEncode(payload)}\$doc\$::jsonb);\n",
  );
  if (args.length > 2) {
    File(args[2]).writeAsStringSync(
      jsonEncode({'source': tree, 'bundle': bundle, 'payload': payload}),
    );
  }
}

class FixtureAuthority implements V3PublicationAuthority {
  FixtureAuthority(this.bundle);
  final Map<String, Object?> bundle;
  Map<String, Object?>? payload;
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String text) async =>
      bundle;
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> value,
  ) async {
    payload = value;
    return {'status': 'published'};
  }
}
