// LOCAL REHEARSAL ONLY. Never supplies genuine producer approval or identity.
import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

class _FixtureAuthority implements V3PublicationAuthority {
  _FixtureAuthority(this.bundle);
  final Map<String, Object?> bundle;
  Map<String, Object?>? payload;
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String _) async => bundle;
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> p,
  ) async {
    payload = p;
    return {
      'status': 'published',
    }; // Capture only; SQL rehearsal performs admission.
  }
}

Future<void> main(List<String> args) async {
  final dir = Directory(args.single);
  final prepared =
      jsonDecode(File('${dir.path}/prepared.json').readAsStringSync()) as Map;
  if (prepared['classification'] != 'LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE') {
    throw StateError('Local fixture required');
  }
  final dependencies =
      jsonDecode(File('${dir.path}/dependencies.json').readAsStringSync())
          as List;
  final sources = (prepared['sources'] as List).cast<Map>();
  final definitions = (prepared['definitions'] as List).cast<Map>();
  final targets = <Map<String, Object?>>[], resolved = <Map<String, Object?>>[];
  for (final row in sources) {
    final s = row['source'] as Map;
    for (final raw in row['binding_intents'] as List) {
      final intent = raw as Map;
      final kind = intent['kind'] as String;
      final dep = dependencies.cast<Map>().singleWhere(
        (x) => x['kind'] == kind,
      );
      final d = definitions.singleWhere(
        (x) =>
            (x['publication']['approved_binding_kinds'] as List).contains(kind),
      );
      final block = (s['blocks'] as List).cast<Map>().singleWhere(
        (b) =>
            b['block_type'] ==
                (kind == 'backSquat' ? 'strength' : 'conditioning') &&
            (b['exercises'] as List).length == 1 &&
            b['exercises'][0]['exercise_id'] == d['exercise_id'],
      );
      final rule = dep['rule_document'] as Map;
      final benchmark = dep['benchmark_document'] as Map;
      final t = <String, Object?>{
        'id': '${s['session_key']}-$kind',
        'slot_key': '${s['session_key']}-slot',
        'week_number': row['week'],
        'session_key': s['session_key'],
        'protocol_id': s['protocol_id'],
        'protocol_revision': 1,
        'session_body_sha256': personalisationDigest(s),
        'block_id': block['block_id'],
        'step_ids': kind == 'backSquat'
            ? []
            : [
                for (
                  var i = 1;
                  i <= (intent['parameters']['repetitions'] as int);
                  i++
                )
                  'work-$i',
              ],
        'identity_namespace': 'canonical_exercise',
        'exercise': {
          'id': d['exercise_id'],
          'version': 1,
          'digest': d['content_digest'],
        },
        'rule': {
          'id': rule['id'],
          'version': 1,
          'digest': personalisationDigest(rule),
        },
        'benchmark': {
          'id': benchmark['id'],
          'version': 1,
          'digest': personalisationDigest(benchmark),
        },
        'kind': kind,
        'input_unit': rule['input_unit'],
        'output_unit': rule['output_unit'],
        'parameters': intent['parameters'],
      };
      targets.add(t);
      resolved.add({
        'target_id': t['id'],
        'exercise': Map<String, Object?>.from(d),
        'rule': rule,
        'benchmark': benchmark,
      });
    }
  }
  final bySource = {for (final s in sources) s['source_id']: s};
  final sorted = [...sources]
    ..sort(
      (a, b) => (a['source']['session_key'] as String).compareTo(
        b['source']['session_key'] as String,
      ),
    );
  final tree = {
    'package_schema_version': 3,
    'programme': {
      'lineage_code': 'LOCAL-HYROX-BASE-PUBLICATION-REHEARSAL',
      'version_number': 1,
      'name': 'LOCAL REHEARSAL — complete approved HYROX Base content',
      'library_scope': 'coach_private',
      'owner_type': 'coach',
      'duration_weeks': 8,
      'sessions_per_week': 6,
      'coaching_intent': (prepared['policies'] as Map).entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n'),
    },
    'sessions': [
      for (final r in sorted)
        {
          'session_key': r['source']['session_key'],
          'protocol_id': r['source']['protocol_id'],
          'session_lineage_id': r['source']['session_lineage_id'],
          'revision_number': 1,
          'title': r['title'],
        },
    ],
    'phases': [],
    'weeks': [
      for (var w = 1; w <= 8; w++)
        {
          'week_number': w,
          'days': [
            for (final d in (prepared['schedule'] as List).cast<Map>().where(
              (d) => d['week'] == w,
            ))
              {
                'day_key': 'day_${d['day']}',
                'day_order': d['day'],
                'day_type': d['type'],
                'slots': d['type'] == 'rest'
                    ? []
                    : [
                        {
                          'slot_key':
                              '${bySource[d['source_id']]!['source']['session_key']}-slot',
                          'session_order': 1,
                          'session_key':
                              bySource[d['source_id']]!['source']['session_key'],
                          'progression': {
                            'prescription_summary':
                                'Exact approved ${d['source_id']} content; local rehearsal only.',
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
    'sessions': [for (final s in sorted) s['source']],
    'dependencies': resolved,
  };
  final authority = _FixtureAuthority(bundle);
  await AuthoritativeV3Publication(authority).publish(
    source: jsonEncode(tree),
    programmeVersionId: 'bc310000-0000-4000-8000-000000000040',
    ownerId: 'bc310000-0000-4000-8000-000000000001',
    importedBy: 'LOCAL-REHEARSAL-ONLY',
  );
  final payload = authority.payload!;
  final canonical = payload['package_canonical_json'] as String;
  final events = <Map<String, Object?>>[];
  for (final d in definitions) {
    final id = d['publication']['event_id'] as String;
    final e = <String, Object?>{
      'contract': 'cohort.trusted-publication-event.v1',
      'event_id': id,
      'kind': 'exercise_published',
      'approval': {
        'status': 'approved',
        'reference': d['publication']['source_reference'],
      },
      'artifact': {
        'canonical_text': d['canonical_text'],
        'publication': d['publication'],
        'retirement': null,
      },
    };
    VerifiedPublicationEvent.fromTrustedRecord(id, e);
    events.add(e);
  }
  final programmeEvent = <String, Object?>{
    'contract': 'cohort.trusted-publication-event.v1',
    'event_id': 'bc310000-0000-4000-8000-000000000099',
    'kind': 'programme_approved',
    'approval': {
      'status': 'approved',
      'reference': 'LOCAL-REHEARSAL-NOT-REAL-APPROVAL:complete-programme',
    },
    'artifact': {
      'source': canonical,
      'canonical_sha256': payload['package_content_hash'],
      'programme_version_id': payload['programme_version_id'],
      'owner_id': payload['owner_id'],
    },
  };
  VerifiedPublicationEvent.fromTrustedRecord(
    programmeEvent['event_id'] as String,
    programmeEvent,
  );
  events.add(programmeEvent);
  File('${dir.path}/programme.canonical.json').writeAsStringSync(canonical);
  File(
    '${dir.path}/payload.json',
  ).writeAsStringSync(personalisationCanonicalJson(payload));
  File(
    '${dir.path}/fixture_events.json',
  ).writeAsStringSync(personalisationCanonicalJson(events));
  File('${dir.path}/payload.sql').writeAsStringSync(
    "INSERT INTO public.local_hyrox_ops_data VALUES('payload',\$doc\$${jsonEncode(payload)}\$doc\$::jsonb);\n",
  );
  stdout.writeln(
    'LOCAL_REHEARSAL_ARTIFACT: 48 sessions / 8 rest / ${targets.length} bound scopes / ${payload['package_content_hash']}',
  );
}
