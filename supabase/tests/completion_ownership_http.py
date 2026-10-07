"""Reuse the bounded loopback transport, then prove completion HTTP authority."""
import json
import runpy
from pathlib import Path
import os
import subprocess

helpers = runpy.run_path(str(Path(__file__).with_name('history_permission_remediation_http.py')))
transport = helpers['request']

def digest():
    return subprocess.check_output(['docker', 'exec', os.environ['SPRINT12_DB_CONTAINER'],
        'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-Atqc',
        'SELECT public.completion_security_digest()'], text=True).strip()

def request(path, actor=None, body=None, method='GET'):
    return transport(path, actor, {'payload': body} if path.startswith('rpc/') else body, method)

def rejected(path, actor, body):
    before = digest()
    result = request(path, actor, body, 'POST')
    assert before == digest(), 'HTTP rejection left evidence residue'
    return result

actors = helpers['actors']
owner = actors[0]
foreign = actors[1]
record = 'd7600000-0000-4000-8000-000000000001'
payload = dict(record_id=record, athlete_id=owner, training_session_id=987121,
               source_protocol_id='security.http', status='completed', session_snapshot={},
               started_at='2026-01-01T12:00:00Z', completed_at='2026-01-01T12:01:00Z')
denied = dict(status='authorization_failure', code='completion_identity_denied')
for function in ('complete_training_session_record', 'complete_programme_session_and_advance',
                 'complete_fixed_programme_occurrence_and_advance', 'complete_backfilled_fixed_programme_occurrence',
                 'correct_completed_performance_record'):
    code, body = rejected('rpc/' + function, None, payload)
    assert code in (401, 403, 404), 'anonymous completion entrypoint reachable'
# A canonical, exact active-assignment retry also traverses PostgREST.
programme = json.loads(subprocess.check_output(['docker', 'exec', os.environ['SPRINT12_DB_CONTAINER'],
    'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-Atqc', """
    SELECT jsonb_build_object('assignment_id',a.id,'session_slot_id',o.session_slot_id,
      'programme_version_id',a.programme_version_id,'materialised_package_content_hash',a.materialised_package_content_hash,
      'programmed_session_key',o.programmed_session_key,'logical_completion_key',o.logical_completion_key,
      'idempotency_key',o.idempotency_key,'actuals_fingerprint',o.actuals_fingerprint,'protocol_id','PROT-GATE-L-A',
      'expected_week',1,'expected_day_key','day_1','expected_slot_order',1,'training_session_id',o.training_session_id,
      'record_id',o.completion_record_id,'status','completed','completion_record','{}'::jsonb)
    FROM public.programme_slot_outcomes o JOIN public.programme_assignments a ON a.id=o.assignment_id
    WHERE o.completion_record_id='11111111-1111-4111-8111-111111111111'
    """], text=True))
code, body = rejected('rpc/complete_programme_session_and_advance', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', programme)
assert code == 200 and body['status'] == 'already_committed', 'canonical HTTP retry failed or changed evidence'
code, body = rejected('rpc/complete_training_session_record', actors[2], payload)
assert code == 200 and body == denied, 'coach History visibility granted completion authority'
for parent in (987010, 987999):
    code, body = rejected('rpc/complete_training_session_record', owner,
                         dict(payload, training_session_id=parent))
    assert code == 200 and body == denied, 'foreign/missing standalone parent not uniformly denied'
code, body = request('rpc/complete_training_session_record', owner, payload, 'POST')
assert code == 200 and body['status'] == 'completed', 'own standalone HTTP completion failed'
code, body = request('rpc/complete_training_session_record', owner, payload, 'POST')
assert code == 200 and body['record_id'] == record, 'own standalone HTTP retry failed'
for actor in (foreign, owner):
    correction = dict(record_id=record, overall_rpe=5)
    if actor == owner:
        correction['training_session_id'] = 987010
    code, body = rejected('rpc/correct_completed_performance_record', actor, correction)
    assert code == 403 and body.get('code') == '42501' and body.get('message') == 'completion_identity_denied', 'correction identity mismatch accepted'
code, body = request('rpc/correct_completed_performance_record', owner,
                     dict(record_id=record, overall_rpe=5), 'POST')
assert code == 200 and body['status'] == 'corrected', 'own HTTP correction failed'
for function in ('complete_programme_session_and_advance', 'complete_fixed_programme_occurrence_and_advance',
                 'complete_backfilled_fixed_programme_occurrence'):
    code, body = rejected('rpc/' + function, foreign,
                         dict(record_id=record, assignment_id='c2000000-0000-4000-8000-000000000099',
                              occurrence_id='c2000000-0000-4000-8000-000000000081', training_session_id=987121))
    assert code == 200 and body == denied, 'completion HTTP cross-owner request accepted'
for function in ('cohort_completion_programme_body_v1', 'cohort_completion_fixed_body_v1',
                 'cohort_completion_standalone_body_v1', 'cohort_completion_correction_body_v1'):
    code, body = request('rpc/' + function, owner, payload, 'POST')
    assert code in (401, 403, 404), 'unguarded body reachable from HTTP'
code, rows = request('training_sessions?select=id,status&id=eq.987121', owner)
assert code == 200 and len(rows) == 1 and rows[0]['status'] == 'completed', 'own HTTP parent state unavailable'
print('COMPLETION_OWNERSHIP_LOOPBACK_API=PASS')
