import 'dart:convert';

import '../domain/programme_review_models.dart';
import '../projection/programme_review_source.dart';
import 'plan_package_v1_yaml_writer.dart';

/// Immutable synthetic inputs. No live registry, athlete or real programme.
class ProgrammeAuthoringFixture {
  const ProgrammeAuthoringFixture({
    required this.id,
    required this.label,
    required this.source,
    required this.protocolSql,
  });
  final String id;
  final String label;
  final String source;
  final String protocolSql;

  Map<String, dynamic> get sourceTree =>
      jsonDecode(sourceJson) as Map<String, dynamic>;
  // Populated from canonical fixture meaning by the controller, not review JSON.
  String get sourceJson => jsonEncode(_fixtureTree(id == 'contracts'));

  ProgrammeReviewSourceBundle bundle(String yaml) =>
      ProgrammeReviewSourceBundle(
        spec: ProgrammeReviewSourceSpec(
          catalogId: 'd1-$id',
          classification: ProgrammeReviewClassification.fixtureTestExample,
          planPackagePath: 'synthetic/d1-$id.plan-package.yaml',
          fixture: true,
          executableProtocolSqlPaths: const ['synthetic/d1-protocols.sql'],
        ),
        planPackageYaml: yaml,
        executableProtocolSql: [protocolSql],
      );
}

List<ProgrammeAuthoringFixture> get programmeAuthoringFixtures => [
  for (final contracts in [true, false])
    ProgrammeAuthoringFixture(
      id: contracts ? 'contracts' : 'empty',
      label: contracts
          ? 'Synthetic — protected contracts'
          : 'Synthetic — empty contracts',
      source:
          '# Synthetic D1 fixture only. Original formatting is retained for comparison.\n'
          '${const PlanPackageV1YamlWriter().writeDraft(_fixtureTree(contracts))}',
      protocolSql: d1ProtocolSql,
    ),
];

Map<String, dynamic> _fixtureTree(bool contracts) {
  Map<String, dynamic> slot(String key, int order, String session) => {
    'slot_key': key,
    'session_order': order,
    'session_key': session,
    'time_of_day': 'any',
    'is_optional': false,
    'completion_expectation': 'required',
    'progression': {
      'prescription_summary':
          'Synthetic inspection only; no training prescription.',
      'volume_note': 'Fixture volume note',
      'intensity_note': 'Fixture intensity note',
      'coach_note': 'Preserve this authored fixture text.',
    },
  };
  return {
    'package_schema_version': 1,
    'programme': {
      'lineage_code': contracts ? 'SYN-D1-CONTRACTS' : 'SYN-D1-EMPTY',
      'version_number': 1,
      'name': contracts
          ? 'Synthetic authoring — contracts'
          : 'Synthetic authoring — empty',
      'description': 'Local synthetic fixture. No programme publication.',
      'library_scope': 'organisation',
      'owner_type': 'organisation',
      'coaching_intent': 'Synthetic source inspection only.',
      'duration_weeks': 2,
      'sessions_per_week': 1,
      'primary_goal': 'Fixture review',
    },
    'sessions': [
      for (final revision in [1, 2])
        {
          'session_key': 'SYN-SESSION-R$revision',
          'protocol_id': 'SYN-PROTOCOL-R$revision',
          'session_lineage_id': 'SYN-SESSION-LINEAGE',
          'revision_number': revision,
          'title': 'Synthetic session revision $revision',
        },
    ],
    'phases': [
      {
        'phase_key': 'SYN-PHASE',
        'phase_order': 1,
        'title': 'Synthetic phase',
        'intent': 'build',
        'coach_note': 'Locked synthetic phase.',
      },
    ],
    'weeks': [
      for (final week in [1, 2])
        {
          'week_number': week,
          'phase_key': 'SYN-PHASE',
          'title': 'Fixture week $week',
          'intent': 'build',
          'coach_note': 'Existing week note',
          'days': [
            {
              'day_key': 'day_1',
              'day_order': 1,
              'day_type': 'training',
              'title': 'Fixture training day',
              'intent': 'build',
              'coach_note': 'Existing day note',
              'slots': [
                slot('W${week}D1S1', 1, 'SYN-SESSION-R1'),
                if (week == 1) slot('W1D1S2', 2, 'SYN-SESSION-R2'),
              ],
            },
            {
              'day_key': 'day_2',
              'day_order': 2,
              'day_type': 'rest',
              'title': 'Fixture rest day',
              'slots': <Object>[],
            },
          ],
        },
    ],
    'adaptation_permissions': contracts
        ? [
            {
              'id': 'SYN-ADAPT',
              'change_kind': 'reduce_volume',
              'target_ref': 'W1D1S1',
              'athlete_agreement_required': true,
              'scope_note': 'Synthetic locked adaptation.',
            },
          ]
        : [],
    'protected_invariants': contracts
        ? [
            {
              'id': 'SYN-INVARIANT',
              'kind': 'assessment_immutable',
              'target_ref': 'SYN-ASSESS',
              'description': 'Synthetic locked invariant.',
            },
          ]
        : [],
    'assessments': contracts
        ? [
            {
              'id': 'SYN-ASSESS',
              'slot_ref': 'W2D1S1',
              'evidence_requirement': 'fixture_evidence',
              'comparison_identity_id': 'SYN-COMPARE',
              'label': 'Synthetic assessment reference',
            },
          ]
        : [],
    'performance_evidence_requirements': contracts
        ? [
            {
              'id': 'SYN-EVIDENCE',
              'comparison_identity_id': 'SYN-COMPARE',
              'metric': 'fixture_metric',
              'required': true,
            },
          ]
        : [],
    'comparison_identities': contracts
        ? [
            {
              'id': 'SYN-COMPARE',
              'session_lineage_id': 'SYN-SESSION-LINEAGE',
              'label': 'Synthetic comparison reference',
            },
          ]
        : [],
  };
}

// Read-only SQL text for the existing projection reader, never executed.
const d1ProtocolSql = '''
INSERT INTO public.performance_protocols(protocol_id,name,purpose,published,content_kind,authoring_scope,endorsement_status,organisation_id,session_lineage_id,revision_number,lifecycle_status,duration_min,primary_session_intent,coaching_notes) VALUES
 ('SYN-PROTOCOL-R1','Synthetic session revision 1','Fixture','false','session','organisation','organisation_approved','synthetic','SYN-SESSION-LINEAGE',1,'draft',1,'Fixture','Synthetic only'),
 ('SYN-PROTOCOL-R2','Synthetic session revision 2','Fixture','false','session','organisation','organisation_approved','synthetic','SYN-SESSION-LINEAGE',2,'draft',1,'Fixture','Synthetic only');
INSERT INTO public.session_blocks(block_id,session_id,block_type,title,content,workout_format,timer_config,coach_notes,position) VALUES
 ('SYN-BLOCK-R1','SYN-PROTOCOL-R1','custom','Synthetic inspection block','Synthetic review text; no training prescription.','none',NULL,'Read only fixture',1),
 ('SYN-BLOCK-R2','SYN-PROTOCOL-R2','custom','Synthetic inspection block','Synthetic review text; no training prescription.','none',NULL,'Read only fixture',1);
''';
