#!/usr/bin/env python3
"""Offline approval-package builder; never authorises or performs publication.

Only reads retained source/metadata and a clearly labelled local rehearsal. No
network, credentials, role grants or hosted execution are implemented here.
"""
import argparse,copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
REL=Path('docs/checkpoints/hyrox_publication_operations')
BASE='e5a5b8f387d084d6f446c0f23ee1fa43a4438382'
def canonical(x):return json.dumps(x,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False)
def digest(x):return hashlib.sha256(x if isinstance(x,bytes) else canonical(x).encode()).hexdigest()
def encoded(x):return (json.dumps(x,ensure_ascii=False,sort_keys=True,indent=2,allow_nan=False)+'\n').encode()
def stable_uuid(seed):
    h=hashlib.md5(seed.encode()).hexdigest()
    return h[:8]+'-'+h[8:12]+'-4'+h[12:15]+'-8'+h[16:19]+'-'+h[20:32]
def content_projection(definition):
    # Structural comparison only. It grants no lifecycle/event/variant authority.
    return {k:v for k,v in definition.items() if k not in {'id','version','lifecycle_status','published_at','retired_at'}}
def analyse_matches(template,records):
    expected=content_projection(template)
    if not records:return dict(disposition='AUTHORITY_INVENTORY_UNAVAILABLE_OR_EMPTY',authority_verified=False)
    matches=[]
    for r in records:
        d=r.get('definition',{})
        if template.get('id') is not None and d.get('id')==template['id'] and content_projection(d)!=expected:
            return dict(disposition='CONFLICT_REQUIRES_PRODUCER_REVIEW',authority_verified=False)
        if content_projection(d)==expected:matches.append(r)
    if len(matches)>1:return dict(disposition='AMBIGUOUS_REQUIRES_EXPLICIT_PRODUCER_PIN',authority_verified=False)
    if len(matches)==1:return dict(disposition='STRUCTURAL_MATCH_ONLY_REQUIRES_EXISTING_TRUSTED_VERIFICATION',authority_verified=False,
        identity=matches[0]['definition'].get('id'),version=matches[0]['definition'].get('version'))
    return dict(disposition='NO_STRUCTURAL_MATCH_CREATION_NOT_AUTHORISED',authority_verified=False)
def normalise_rehearsal(document):
    if document.get('classification')=='LOCAL_REHEARSAL_ONLY_NOT_REAL_PUBLICATION':
        return dict(classification='LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE',definitions=document['exercise_definitions'],
            sources=[dict(source_id=s['source_id'],input_sha256=s['approved_source_sha256'],source=s['rehearsal_source']) for s in document['sources']])
    return document

def build(root,readiness,rehearsal):
    docs=root/'docs/programmes/hyrox_base'
    authored=json.loads((docs/'SESSIONS.json').read_bytes())
    review=json.loads((docs/'PRODUCER_REVIEW_BUNDLE.json').read_bytes())
    if len(authored['sessions'])!=48 or any(s['source_status']!='prescription_content_complete' for s in authored['sessions']):raise ValueError('Complete retained prescriptions required')
    if rehearsal['classification']!='LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE':raise ValueError('Explicit local namespace required')
    input_files=['SESSIONS.json','PRODUCER_REVIEW_BUNDLE.json','EXERCISE_DEFINITION_PROPOSALS.json','PREPARATION_PROPOSALS.json','APPROVAL_2026_10_25.txt','MANIFEST.json']
    inputs={str((docs/n).relative_to(root)):digest((docs/n).read_bytes()) for n in input_files}
    identity_evidence=[
      'lib/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart',
      'lib/domain/exercise_knowledge/seed/founder_approved_movement_knowledge_phase_3_2d.dart',
      'docs/architecture/reviews/exercises_v2_published_export_phase_3_1f_part1b.meta.json',
      'lib/application/exercise_knowledge/published_version_retention.dart',
      'server/trusted_plan_package_import/lib/src/publication_events.dart',
      'server/trusted_plan_package_import/lib/src/exercise_publication_producer.dart']
    inputs.update({name:digest((root/name).read_bytes()) for name in identity_evidence})
    exercise_ops=[]
    label_keys={b['authored_label']:b['definition_key'] for b in review['bindings']}
    for d in sorted(review['definitions'],key=lambda d:d['definition_key']):
        key=d['definition_key'];labels=sorted(k for k,v in label_keys.items() if v==key)
        exercise_ops.append(dict(operation_id='exercise.resolve.'+key,labels=labels,
          proposed_definition_content=d['definition_content'],proposed_movement_content=d['movement_content'],source_evidence=d['source_evidence'],
          required_binding_kinds=d['required_binding_kinds'],
          approved_definition_content_sha256=digest(d['definition_content']),approved_movement_content_sha256=digest(d['movement_content']),
          content_approval=d['content_approval'],existing_identity_candidate=d['identity_candidate'],
          resolution=analyse_matches(d['definition_content'],[]),assigned_identity=None,assigned_version=None,
          genuine_approval_event=None,retained_version_digest=None,
          branches=dict(reuse='Reuse only an exact operational retained version with genuine producer event and explicit approved variant binding; no new historical event/version.',
            new_version='Only after producer confirms existing identity and approves changed exact definition content; producer assigns its prospective current version.',
            new_definition='Only after authoritative inventory/deduplication confirms absence and producer assigns a new canonical identity/current version.',
            conflict='Stop on ambiguous matches, wrong variants, retirement, event mismatch or same ID/version with different bytes; no highest-version/name-similarity choice.'),
          dependencies=['schema.current_preflight','producer.verified_inventory_and_event_source'],
          expected_effect='Zero writes for exact retained reuse; otherwise one genuine approved immutable retention per assigned version. No catalogue row is version authority.',
          recovery='Retry the same genuine event ID after lost acknowledgement; do not replace history, delete retained versions or infer retirement.'))
    source_ops=[];source_inventory=[];fixture_by_id={s['source_id']:s for s in rehearsal['sources']}
    for s in authored['sessions']:
        fixture=fixture_by_id[s['source_id']]
        if fixture['input_sha256']!=digest(s):raise ValueError('Rehearsal changed an approved source')
        protocol='PROPOSED-HYROX-'+s['source_id'][5:].replace('_','-')+'-R1'
        block_ids=[dict(position=b['position'],candidate_id=stable_uuid(protocol+':block:'+str(b['position']))) for b in fixture['source']['blocks']]
        labels=sorted(s['exercise_variants'])
        proposed_graph=copy.deepcopy(fixture['source'])
        proposed_graph.update(protocol_id=protocol,session_key=protocol,session_lineage_id=stable_uuid('proposed-hyrox-lineage:'+s['source_id']),revision_number=None)
        for b in proposed_graph['blocks']:
            b.update(block_id=stable_uuid(protocol+':block:'+str(b['position'])),session_id=protocol)
            for e in b['exercises']:
                e.update(block_id=b['block_id'],id=stable_uuid(protocol+':ex:'+str(b['position'])+':'+str(e['position'])),
                    exercise_id=None,unresolved_definition_key=label_keys[e['display_label_override']],unresolved_exact_version=None)
        source_ops.append(dict(operation_id='source.register.'+s['source_id'],source_id=s['source_id'],approved_source_sha256=digest(s),
          approved_binding_intents=s['binding_intents'],
          candidate_identity=dict(classification='PROVISIONAL_NOT_ASSIGNED',protocol_id=protocol,
              session_lineage_id=stable_uuid('proposed-hyrox-lineage:'+s['source_id']),proposed_new_namespace_revision=1,assigned_revision=None,blocks=block_ids),
          identity_convention='cohort_stable_uuid(protocol:block:position) and cohort_stable_uuid(protocol:ex:block-position:exercise-position). Candidate values do not establish existing history.',
          dependencies=['exercise.resolve.'+k for k in sorted(set(label_keys[label] for label in labels))],
          executor='Existing authorised source-publication/operator boundary; not the ordinary caller or a new public API. Actual operator is not identified/configured.',
          required_checks=['Resolve all exact identity/version/variant bindings first','Confirm namespace/revision availability against live authoritative inventory',
            'Compare the complete immutable source body, not title/counts only','Reject any conflicting existing published protocol/lineage/block/exercise/step mapping'],
          expected_effect='One new immutable session revision with its complete graph, or zero writes for byte-identical existing revision. No UPDATE to an existing published source.',
          transaction='One source/graph transaction; a failed source rolls back its parent/blocks/links; prior completed sources remain.',
          provisional_graph_template=proposed_graph,template_sha256=digest(proposed_graph),
          body_sha256=None,status='BLOCKED_BEFORE_AUTHORITATIVE_BINDING',
          blockers=['T1: exact real published variant/version/event bindings unavailable','B3: real assigned immutable source revision and approved artifact unavailable']))
        steps=[]
        for b in fixture['source']['blocks']:
            if b['workout_format']!='intervals':continue
            t=b['timer_config'];rounds=t['rounds'];
            for i in range(1,rounds+1):
                steps.append(dict(block_id=b['block_id'],step_id='work-'+str(i),phase='work',seconds=t['workSeconds']))
                if i<rounds:steps.append(dict(block_id=b['block_id'],step_id='recovery-'+str(i),phase='recovery',seconds=t['restSeconds']))
        source_inventory.append(dict(source_id=s['source_id'],approved_source_sha256=digest(s),authored_source=s,rehearsal_source=fixture['source'],
            timer_derived_steps=steps,step_convention='Existing block-scoped work-N/recovery-N addresses; no invented protocol_steps rows or unsupported step registry.'))
    schema=[dict(file=str(p.relative_to(root)),sha256=digest(p.read_bytes())) for p in sorted((root/'supabase/migrations').glob('*.sql'))]
    suffix=[r for r in schema if Path(r['file']).name[:14]>='20261022120000']
    manifest=dict(format='hyrox-authoritative-operation-plan-v1',base=BASE,
       status='PREPARED_LOCAL_PLAN_NOT_AUTHORISED_OR_EXECUTABLE_HOSTED',
       digest_convention='Object fingerprints: sorted-key compact UTF-8 JSON, no ASCII escaping/NaN. Input file digests: exact bytes. ARTIFACTS.json separately records physical retained file hashes.',inputs=inputs,readiness_sha256=digest(readiness),
       real_producer='NOT_IDENTIFIED_OR_CONFIGURED_IN_OBSERVED_RECEIVER',real_authoritative_inventory='UNAVAILABLE_WHILE_FIELD_MANUAL_INACTIVE',
       real_programme_owner=None,real_programme_version_id=None,real_canonical_artifact=None,
       exercise_operations=exercise_ops,source_operations=source_ops,
       programme_operation=dict(operation_id='programme.publish',dependencies=[r['operation_id'] for r in source_ops],
          boundary='Existing Founder-authenticated programme_approved event → AuthoritativeV3Publication → publish_private_exact_programme_version_v3',
          required_before_approval=['Producer-assigned actual identities/versions/events and exact variant matches','Actual owner/version UUID and source revision inventory',
            'Recomputed canonical artifact fingerprint verified against those real assignments','Verified durable approval event/source and configured receiver/capability'],
          expected_effect='One private exact programme version and immutable v3 artifact/source seal, no enrolment or athlete write.',
          recovery='Atomic programme/claim/artifact rollback on failure; prior exercise/source operations remain. Exact retry checks owner/scope/hash; conflict never overwrites.'),
       real_execution_performed=False,local_rehearsal_does_not_resolve_hosted_T1_B3=True)
    approvals=dict(format='hyrox-publication-approval-stages-v1',target=dict(supabase_ref='otnhhdxstdnwccehacku',name='Cohort Field Manual',region='eu-west-1',
        cloud_project='cohort-platform-production',cloud_project_number='809647670049',cloud_run_region='europe-west1',receiver='cohort-trusted-plan-import'),
       stages=[
        dict(stage='1-project-resumption',status='REQUIRES_FOUNDER_AUTHORITY',target='Cohort Field Manual / otnhhdxstdnwccehacku',
          inputs={'readiness_sha256':digest(readiness)},expected_changes='Resume only this inactive project; no schema/content/credential writes.',
          prerequisites=['Operator receipt for a complete reversible writer hold: app/device clients, legacy importer callers, jobs, direct writers, queues/retries. No repository maintenance switch is assumed.'],
          smallest_next_action='Authorise this bounded resumption only after the verified writer hold, followed by read-only ledger/catalogue/definition/source/capability preflight.',
          recovery_limits='Resumption can reconnect existing writers. Do not resume before hold verification; re-pausing is not rollback of any intervening writes.'),
        dict(stage='2-schema',status='BLOCKED_CURRENT_LEDGER_UNKNOWN',target='Same Supabase project',reviewed_schema_inventory_sha256=digest(schema),
          exact_pending_batch=None,conditional_suffix=suffix,expected_changes='Only actual missing, individually hash-approved migration files after exact ledger/security comparison; no seeds/repair/include-all.',
          prerequisites=['ACTIVE_HEALTHY read-only identity/ledger/object/ACL/RLS/defaults/role proof','Exact later approved pending set and fresh dry-run under hold'],
          recovery_limits='Per-file transactions, not one global batch. Stop after partial failure; reconcile committed ledger and effects, no down migration or ledger repair.'),
        dict(stage='3-producer-and-receiver',status='UNCONFIGURED_REQUIRES_SEPARATE_REVIEW',target='Existing Cloud Run receiver plus a genuinely governed producer/event store',
          reviewed_contracts=['docs/checkpoints/hyrox_v3_http/CONTRACT.md','docs/checkpoints/hyrox_v3_http/DEPLOYMENT.md'],
          expected_changes='Later named producer identity, approval/event store, durable retry delivery, pinned server-only source credential and dedicated exercise capability; reviewed receiver image/config revision. No resources are created by this package.',
          prerequisites=['Identify responsible producer/operator and real approved event source','Review exact role graph and credential issuance/rotation/revocation without ordinary service-role substitution',
            'Name durable event retention/redelivery owner; current endpoint is synchronous, not a subscribed webhook','Review immutable image digest, pinned secret versions, caller policy, traffic/timeout and rollback plan'],
          recovery_limits='Disable opt-in/route new work only under reviewed config authority. Do not revoke or rewrite immutable history as compensation; reconcile event IDs after timeouts.'),
        dict(stage='4-exercise-source-artifact-publication',status='BLOCKED_REAL_ASSIGNMENTS_EVENTS_AND_ARTIFACT_MISSING',target='Same Supabase project through existing trusted boundaries',
          operation_plan_sha256=digest(manifest),expected_changes='Exact assigned exercise retention/reuse, 48 immutable source revisions and one private canonical programme artifact; no assignment.',
          prerequisites=['Complete stages 1–3 and populate every unassigned real identity/version/event/owner slot','Regenerate all dependent source/body/artifact digests and review them before authorising exact operations'],
          recovery_limits='Exercise events, each source and programme admission are separate transactions. Persist stage receipts; exact retries only, no compensating deletions or invented events.'),
        dict(stage='5-client-device',status='LATER_SEPARATE_AUTHORITY',target='Matched client build and founder-controlled validation actors/devices',
          expected_changes='Later reviewed client distribution/native usability and supported capture/History validation, only under named authority.',
          prerequisites=['Verified hosted publication/configuration and separate synthetic/private assignment scope','Exact matching build/artifact and explicit device/browser authority'],
          recovery_limits='Local model/SQL rehearsal does not establish native acceptance, commercial readiness or broader Stage 2/Sprint C closure.')])
    inventory=dict(classification='LOCAL_REHEARSAL_ONLY_NOT_REAL_PUBLICATION',sources=source_inventory,
       source_count=48,authored_root_metadata={k:v for k,v in authored.items() if k!='sessions'},rest_entries=[r for r in authored['schedule'] if r['type']=='rest'],exercise_definitions=rehearsal['definitions'],
       warnings=['Fixture EX-901xxx and version 1 values are prospective software fixtures, never assigned real IDs/history/events.',
         'Provisional real plan identifiers are not reserved or retained. Real assigned bindings require regenerated bytes and approval.'])
    return {'OPERATIONS.json':encoded(manifest),'APPROVAL_STAGES.json':encoded(approvals),'SCHEMA_INVENTORY.json':encoded(dict(source_base=BASE,migrations=schema,current_hosted_ledger=None,actual_pending_set=None,conditional_suffix=suffix)),
       'LOCAL_REHEARSAL_SOURCE_INVENTORY.json':encoded(inventory)}
def main():
    p=argparse.ArgumentParser();p.add_argument('--readiness',type=Path,required=True);p.add_argument('--rehearsal',type=Path,required=True);p.add_argument('--write',action='store_true');p.add_argument('--check',action='store_true');a=p.parse_args()
    if a.write==a.check:p.error('Choose exactly one of --write or --check')
    outputs=build(ROOT,json.loads(a.readiness.read_bytes()),normalise_rehearsal(json.loads(a.rehearsal.read_bytes())))
    out=ROOT/REL
    if a.write:out.mkdir(parents=True,exist_ok=True)
    for name,data in outputs.items():
        target=out/name
        if a.write:target.write_bytes(data)
        elif not target.exists() or target.read_bytes()!=data:raise SystemExit('Stale operation artifact: '+name)
    print(json.dumps(dict(exercise_operations=27,source_operations=48,rest_entries=8,hosted_execution=False,result='written' if a.write else 'exact')))
if __name__=='__main__':main()
