"""Loopback-only authenticated API and concurrent selection proof; synthetic users.

Reads only the disposable project's generated credentials in memory. Never logs
JWTs, keys, credentials or raw status output. No hosted URL or athlete input.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

workdir = Path(sys.argv[1]).resolve()
assert workdir.name.startswith('sprint12_gate.'), 'disposable project required'
status = json.loads(subprocess.check_output(
    ['supabase', 'status', '-o', 'json', '--workdir', str(workdir)], stderr=subprocess.DEVNULL))
api = status['API_URL']
assert urllib.parse.urlparse(api).hostname in ('127.0.0.1', 'localhost')
assert urllib.parse.urlparse(api).scheme == 'http'
secret, key = status['JWT_SECRET'].encode(), status['ANON_KEY']
actors = [f'ba220000-0000-4000-8000-{n:012d}' for n in (1, 2)]
checks = 0


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()


def token(actor, role):
    message = b64(b'{"alg":"HS256","typ":"JWT"}') + '.' + b64(json.dumps({
        'sub': actor, 'role': role, 'aud': 'authenticated',
        'iat': int(time.time()), 'exp': int(time.time()) + 600}).encode())
    return message + '.' + b64(hmac.new(secret, message.encode(), hashlib.sha256).digest())


def request(path, actor=actors[0], body=None, method='POST', role='authenticated'):
    req = urllib.request.Request(api + '/rest/v1/' + path,
        data=None if body is None else json.dumps(body).encode(), method=method,
        headers={'apikey': key, 'Authorization': 'Bearer ' + token(actor, role),
                 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def check(ok, label):
    global checks
    assert ok, label
    checks += 1


def record_payload(reference='api-row', value='480', previous=None):
    return dict(command_id=str(uuid.uuid4()), metric='row2km', value=value,
        unit='seconds', test_date='2026-10-22', source_type='recordedResult',
        source_reference=reference, previous_revision_id=previous,
        correction_reason=None if previous is None else 'declared transcription correction')


def call(name, payload, actor=actors[0]):
    code, body = request('rpc/' + name, actor, {'payload': payload})
    check(code == 200, name + ' transport')
    return body


def selection(revision, expected=None):
    return dict(command_id=str(uuid.uuid4()), metric='row2km', selected_revision_id=revision,
        expected_selection_id=expected, consent='use_declared_benchmark_for_future_previews_only')


# Effective roles, including a service JWT with a real athlete sub, fail closed.
for role in ('anon', 'service_role'):
    for rpc, body in [('read_hyrox_base_selections', {}),
                      ('record_hyrox_base_benchmark', {'payload': record_payload()}),
                      ('select_hyrox_base_benchmark', {'payload': selection(None)})]:
        code, _ = request('rpc/' + rpc, body=body, role=role)
        check(code in (401, 403, 404), role + ' RPC denial ' + rpc)
    for table in ('hyrox_base_benchmark_revisions', 'hyrox_base_benchmark_selections'):
        code, _ = request(table + '?select=*', method='GET', role=role)
        check(code in (401, 403), role + ' table denial')
for name in ('cohort_base_actor', 'cohort_base_calculate_v1',
             'cohort_create_or_resume_fixed_occurrence_pre_v3',
             'cohort_create_or_resume_programme_training_session_pre_v3'):
    code, _ = request('rpc/' + name, body={})
    check(code in (401, 403, 404), 'private helper not API ' + name)

# Concurrent identical retries persist exactly one revision and return the same ID.
payload = record_payload(reference='api-row-' + str(uuid.uuid4()))
with ThreadPoolExecutor(2) as pool:
    results = list(pool.map(lambda _: call('record_hyrox_base_benchmark', payload), range(2)))
check(sorted(r['status'] for r in results) == ['recorded', 'replayed'], 'duplicate record ordering')
revision = results[0]['revision_id']
check(all(r['revision_id'] == revision for r in results), 'same server revision')

# Foreign reads, writes, consent and command replay cannot claim the first actor.
code, rows = request('hyrox_base_benchmark_revisions?select=revision_id&revision_id=eq.' + revision,
                     actors[1], method='GET')
check(code == 200 and rows == [], 'foreign read')
check(call('record_hyrox_base_benchmark', payload, actors[1])['code'] == 'command_conflict', 'foreign retry')
check(call('select_hyrox_base_benchmark', selection(revision), actors[1])['code'] == 'unresolved_owned_benchmark', 'foreign consent')
for table in ('hyrox_base_benchmark_revisions', 'hyrox_base_benchmark_selections'):
    for method in ('POST', 'PATCH', 'DELETE'):
        code, _ = request(table + ('?athlete_id=eq.' + actors[0] if method != 'POST' else ''), body={'athlete_id': actors[1]} if method != 'DELETE' else None, method=method)
        check(code in (401, 403), 'direct mutation denied ' + method + table)

# Ownership/source/hash/targets/approval cannot be nominated by a client.
for field, forged in [('athlete_id', actors[1]), ('canonical_value', 1), ('retained_digest', 'a' * 64),
                      ('programme_version_id', str(uuid.uuid4())), ('calculated_target', {}), ('approved', True)]:
    check(call('record_hyrox_base_benchmark', dict(payload, **{field: forged}))['status'] == 'validation_failure', 'tampered ' + field)
check(call('select_hyrox_base_benchmark', dict(selection(revision), consent='accepted'))['status'] == 'validation_failure', 'forged consent')

# Concurrent different selections against the same review token: exactly one wins.
with ThreadPoolExecutor(2) as pool:
    selected = list(pool.map(lambda p: call('select_hyrox_base_benchmark', p), [selection(revision), selection(None)]))
check(sorted(r['status'] for r in selected) == ['accepted', 'refused'], 'selection CAS race')
head = next(r['selection_id'] for r in selected if r['status'] == 'accepted')
head_result = call('select_hyrox_base_benchmark', selection(revision, head))
head = head_result['selection_id']

# Correction and selection serialise on one actor/metric lock. Either ordering
# leaves a corrected old selection unusable; neither auto-selects the replacement.
correction = record_payload(reference=payload['source_reference'], value='500', previous=revision)
with ThreadPoolExecutor(2) as pool:
    futures = [pool.submit(call, 'record_hyrox_base_benchmark', correction),
               pool.submit(call, 'select_hyrox_base_benchmark', selection(revision, head))]
    corrected, competing = [f.result() for f in futures]
check(corrected['status'] == 'recorded', 'correction persisted')
check(competing['status'] == 'accepted' or competing.get('code') == 'superseded_benchmark', 'correction-selection race')
code, read = request('rpc/read_hyrox_base_selections', body={})
row = next(s for s in read['selections'] if s['metric'] == 'row2km')
check(code == 200 and row['preview_state'] == 'unavailable_stale_selection', 'stale after correction in both orderings')
check(row['selected_revision_id'] == revision, 'no automatic replacement')
accepted_payload = selection(corrected['revision_id'], row['selection_id'])
accepted = call('select_hyrox_base_benchmark', accepted_payload)
check(accepted['status'] == 'accepted', 'explicit replacement')
check(call('select_hyrox_base_benchmark', accepted_payload)['status'] == 'replayed', 'idempotent consent retry')
withdrawn = call('select_hyrox_base_benchmark', selection(None, accepted['selection_id']))
check(withdrawn['status'] == 'accepted', 'explicit withdrawal')
code, read = request('rpc/read_hyrox_base_selections', body={})
check(any(s['metric'] == 'row2km' and s['preview_state'] == 'unavailable_withdrawn'
          for s in read['selections']), 'withdrawal read')
print(f'HYROX_BASE_LOOPBACK_API_CONCURRENCY=PASS ({checks} assertions; no v3 start or target-consent claim)')
