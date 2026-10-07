"""Loopback-only API proof with disposable synthetic identities, no token output."""
import base64
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

workdir = Path(sys.argv[1]).resolve()
assert workdir.name.startswith('sprint12_gate.'), 'not a disposable workdir'
status = json.loads(subprocess.check_output(
    ['supabase', 'status', '-o', 'json', '--workdir', str(workdir)], stderr=subprocess.DEVNULL))
api = status['API_URL']
parsed = urllib.parse.urlparse(api)
assert parsed.scheme == 'http' and parsed.hostname in ('127.0.0.1', 'localhost'), 'not loopback'
secret = status['JWT_SECRET'].encode()
key = status['ANON_KEY']
actors = [f'c2000000-0000-4000-8000-{n:012d}' for n in (1, 2, 3)]


def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()


def token(actor):
    header = b64(b'{"alg":"HS256","typ":"JWT"}')
    payload = b64(json.dumps(dict(role='authenticated', sub=actor, aud='authenticated',
                                 iss='supabase', iat=int(time.time()), exp=int(time.time())+300)).encode())
    message = f'{header}.{payload}'
    return message + '.' + b64(hmac.new(secret, message.encode(), hashlib.sha256).digest())


def request(path, actor=None, body=None, method='GET'):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(api + '/rest/v1/' + path, data=data, method=method,
                                 headers={'apikey': key, 'Authorization': 'Bearer ' + (key if actor is None else token(actor)),
                                          'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


for table in ('training_sessions', 'training_session_records', 'training_block_results',
              'training_exercise_results', 'training_set_results', 'performance_result_corrections',
              'coach_athlete_relationships', 'profiles'):
    code, body = request(table + '?select=*')
    assert code in (401, 403) and body.get('code') == '42501', 'anonymous table read not denied'
code, body = request('training_sessions', actors[0], {'athlete_id': actors[0]}, 'POST')
assert code == 403 and body.get('code') == '42501', 'direct session insert not denied'
for actor, own, foreign in ((actors[0], 987001, 987010), (actors[1], 987010, 987001)):
    code, rows = request(f'training_sessions?select=id&id=eq.{own}', actor)
    assert code == 200 and len(rows) == 1, 'own restore read failed'
    code, rows = request(f'training_sessions?select=id&id=eq.{foreign}', actor)
    assert code == 200 and rows == [], 'foreign session read leaked'
record = 'c2000000-0000-4000-8000-000000000010'
code, rows = request('training_session_records?select=record_id&record_id=eq.' + record, actors[1])
assert code == 200 and rows == [], 'foreign discovery metadata leaked'
code, rows = request('training_session_records?select=record_id&record_id=eq.' + record, actors[2])
assert code == 200 and len(rows) == 1, 'linked coach History read failed'
code, body = request('rpc/read_performance_tracking_history_v1', body={'p_record_id': record}, method='POST')
assert code in (401, 403, 404), 'anonymous C2 executed'
wires = []
for n in (1, 2):
    record_id = f'd7100000-0000-4000-8000-{n:012d}'
    code, body = request('rpc/read_performance_tracking_history_v1', actors[0], {'p_record_id': record_id}, 'POST')
    assert code == 200 and body['status'] == 'ok', 'owned C2 wire unavailable'
    wires.append(body)
(workdir / 'history-wires.json').write_text(json.dumps(wires))
print('HISTORY_PERMISSION_LOOPBACK_API=PASS (8 anonymous denials; owner/foreign/coach/RPC checks)')
