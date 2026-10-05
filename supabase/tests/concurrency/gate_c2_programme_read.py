#!/usr/bin/env python3
"""Local Docker/psql only. Two-session barrier proof; no DB URLs or credentials."""
import json
from pathlib import Path
import os
import signal
import subprocess
import time

def timed_out(signum, frame):
    raise TimeoutError('C2 concurrency gate exceeded its local time bound')

signal.signal(signal.SIGALRM, timed_out)
signal.alarm(180)

container = os.environ['SPRINT12_DB_CONTAINER']
project = os.environ['SPRINT12_PROJECT_ID']
if not project.startswith('s12g') or container != 'supabase_db_' + project:
    raise SystemExit('C2 exact disposable container required')
if subprocess.check_output(['docker', 'inspect', '-f', '{{.State.Running}}', container], text=True).strip() != 'true':
    raise SystemExit('C2 container not running')
base = ['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1']
actor = 'c2000000-0000-4000-8000-000000000001'
record = 'c2000000-0000-4000-8000-000000000070'
block = 'c2000000-0000-4000-8000-000000000071'
auth = f"SET ROLE authenticated; SET request.jwt.claim.sub='{actor}'; "
rpc = f"public.read_performance_tracking_programme_history_v1('{record}',(SELECT claim FROM public.c2p_claim))"

def sql(query):
    return subprocess.check_output(base + ['-c', query], text=True, timeout=30)

def read(query=rpc):
    out = sql(auth + 'SELECT ' + query)
    return json.loads(next(line for line in out.splitlines() if line.startswith('{')))

def state(frame):
    assert frame['status'] == 'ok', frame
    b = next(b for b in frame['blocks'] if b['block_result_id'] == block)
    return b['result_data']['durationSeconds'], len(frame['corrections'])

def marker(process, value):
    # Each query is bounded server-side, and the outer runner bounds this process.
    while True:
        line = process.stdout.readline()
        if not line:
            raise AssertionError('writer failed before ' + value)
        if line.strip() == value:
            return

for iteration in range(3):
    before = read()
    old_value, old_count = state(before)
    next_value = old_value + 1
    lock = 6200514 + iteration
    writer = subprocess.Popen(base, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, text=True, bufsize=1)
    reader = None
    try:
        payload = json.dumps({'record_id': record, 'blocks': [{'block_result_id': block,
                    'result_data': {'resultType': 'duration', 'durationSeconds': next_value}}]})
        writer.stdin.write("SET statement_timeout='15s'; BEGIN; " + auth +
            f"SELECT pg_advisory_xact_lock({lock}); " +
            f"SELECT public.correct_completed_performance_record('{payload}'); " +
            "SELECT 'C2_WRITER_READY';\n")
        writer.stdin.flush()
        marker(writer, 'C2_WRITER_READY')
        # Only the gate monitor uses postgres to inspect pg_stat_activity. The
        # correction and every RPC read execute as authenticated. No grant change.
        writer.stdin.write("RESET ROLE; SELECT 'C2_MONITOR_READY';\n")
        writer.stdin.flush()
        marker(writer, 'C2_MONITOR_READY')
        # Actuals and audit exist only in the uncommitted writer. A normal reader
        # must observe the complete previous committed frame, without blocking.
        assert read() == before, 'uncommitted actuals/audit leaked'
        reader = subprocess.Popen(base + ['-c',
            "SET statement_timeout='15s'; " + auth +
            f"SELECT {rpc} FROM (SELECT pg_advisory_xact_lock({lock})) AS fence;"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        # Use the same writer connection to confirm the read statement is waiting
        # at the advisory barrier, with its snapshot already taken. No timing guess.
        waiting = False
        for _ in range(100):
            if reader.poll() is not None:
                raise AssertionError('reader exited before barrier: ' + reader.stderr.read())
            writer.stdin.write("SELECT pg_stat_clear_snapshot(); SELECT 'C2_WAIT_' || count(*) FROM pg_stat_activity "
                "WHERE wait_event='advisory' AND query LIKE '%AS fence%';\n")
            writer.stdin.flush()
            while True:
                line = writer.stdout.readline().strip()
                if line.startswith('C2_WAIT_'):
                    waiting = line != 'C2_WAIT_0'
                    break
            if waiting:
                break
            time.sleep(0.02)
        assert waiting, 'reader never reached snapshot barrier'
        writer.stdin.write("COMMIT; SELECT 'C2_WRITER_COMMITTED';\n")
        writer.stdin.flush()
        marker(writer, 'C2_WRITER_COMMITTED')
        output, error = reader.communicate(timeout=20)
        assert reader.returncode == 0, error
        overlapping = json.loads(next(l for l in output.splitlines() if l.startswith('{')))
        assert overlapping == before, 'read committed during statement mixed snapshots'
        after = read()
        assert state(after) == (next_value, old_count + 1), 'postcommit actual/audit mismatch'
        key = f'block:{block}:result_data'
        added = [c for c in after['corrections'] if c['correction_id'] not in
                 {c['correction_id'] for c in before['corrections']}]
        assert len(added) == 1 and added[0]['after_values'][key]['durationSeconds'] == next_value
        # Negative control for the old hydration model: an earlier actual paired
        # with the later audit is observably incoherent.
        assert old_value != added[0]['after_values'][key]['durationSeconds']
        print(f'C2_PROGRAMME_CORRECTION_RACE_{iteration + 1}=PASS')
    finally:
        if reader and reader.poll() is None:
            reader.kill()
            reader.wait()
        if writer.poll() is None:
            writer.stdin.close()
            try:
                writer.wait(timeout=5)
            except subprocess.TimeoutExpired:
                writer.kill()
                writer.wait()

# Publication and its artifact/scope seal are also invisible until one commit.
import hashlib
payload = json.loads(sql("SELECT payload FROM public.c2p_payload WHERE kind='v1'").strip())
canonical = json.loads(payload['package_canonical_json'])
canonical['programme']['lineage_code'] = 'C2-SYNTHETIC-PUBLICATION-RACE'
payload['programme']['lineage_code'] = canonical['programme']['lineage_code']
payload['programme_version_id'] = 'c2000000-0000-4000-8000-000000000065'
payload['package_canonical_json'] = json.dumps(canonical, sort_keys=True, ensure_ascii=False, separators=(',', ':'))
payload['package_content_hash'] = hashlib.sha256(payload['package_canonical_json'].encode()).hexdigest()
future_claim = json.loads(sql('SELECT claim FROM public.c2p_claim').strip())
future_claim.update(assignment_id='c2000000-0000-4000-8000-000000000086', occurrence_id='c2000000-0000-4000-8000-000000000087', training_session_id='987005', programme_version_id=payload['programme_version_id'], package_hash=payload['package_content_hash'])
future_record = 'c2000000-0000-4000-8000-000000000076'
future_rpc = f"public.read_performance_tracking_programme_history_v1('{future_record}',$claim${json.dumps(future_claim)}$claim$::jsonb)"
lock = 6200599
writer = subprocess.Popen(base, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
reader = None
try:
    writer.stdin.write("SET statement_timeout='15s'; BEGIN; " + f"SELECT pg_advisory_xact_lock({lock}); SET ROLE service_role; " +
        f"SELECT public.publish_private_exact_programme_version_retained_v1($payload${json.dumps(payload)}$payload$::jsonb); RESET ROLE; " +
        f"SELECT public.c2p_make_links('{payload['programme_version_id']}','{future_claim['assignment_id']}','{future_claim['occurrence_id']}','{future_record}','c2000000-0000-4000-8000-000000000077',987005); " + "SELECT 'PUBLICATION_READY';\n")
    writer.stdin.flush(); marker(writer,'PUBLICATION_READY')
    before = read(future_rpc)
    assert before == {'status':'failure','code':'programme_scope_unproven'}, before
    reader = subprocess.Popen(base + ['-c', "SET statement_timeout='15s'; " + auth + f"SELECT {future_rpc} FROM (SELECT pg_advisory_xact_lock({lock})) AS fence;"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    waiting = False
    for _ in range(100):
        writer.stdin.write("SELECT pg_stat_clear_snapshot(); SELECT 'PUB_WAIT_' || count(*) FROM pg_stat_activity WHERE wait_event='advisory' AND query LIKE '%AS fence%';\n")
        writer.stdin.flush()
        while True:
            line=writer.stdout.readline().strip()
            if line.startswith('PUB_WAIT_'):
                waiting = line != 'PUB_WAIT_0'; break
        if waiting: break
        time.sleep(0.02)
    assert waiting, 'publication reader never reached snapshot barrier'
    writer.stdin.write("COMMIT; SELECT 'PUBLICATION_COMMITTED';\n"); writer.stdin.flush(); marker(writer,'PUBLICATION_COMMITTED')
    output,error=reader.communicate(timeout=20)
    assert reader.returncode==0,error
    overlapping=json.loads(next(l for l in output.splitlines() if l.startswith('{')))
    assert overlapping==before, 'publication/read observed a torn version/artifact/owned tree'
    after=read(future_rpc)
    assert after['status']=='ok' and after['programme']['artifact']['canonical_text']==payload['package_canonical_json']
    print('C2_PUBLICATION_SNAPSHOT_RACE=PASS')
finally:
    if reader and reader.poll() is None: reader.kill(); reader.wait()
    if writer.poll() is None:
        writer.stdin.close()
        try: writer.wait(timeout=5)
        except subprocess.TimeoutExpired: writer.kill(); writer.wait()

# Export the final synthetic frame for independent typed-bridge fixtures.
Path('/tmp/c2_programme_frame.json').write_text(json.dumps(read(), ensure_ascii=False, indent=2)+'\n')
Path('/tmp/c2_programme_running_frame.json').write_text(json.dumps(read("public.read_performance_tracking_programme_history_v1('c2000000-0000-4000-8000-000000000078',(SELECT claim FROM public.c2p_running_claim))"), ensure_ascii=False, indent=2)+'\n')

sql("SELECT public.c2_assert(NOT EXISTS(SELECT 1 FROM public.c2_unchanged_permissions b "
    "JOIN pg_class c ON c.oid=b.oid WHERE c.relacl::text IS DISTINCT FROM b.acl "
    "OR c.relrowsecurity IS DISTINCT FROM b.relrowsecurity "
    "OR c.relforcerowsecurity IS DISTINCT FROM b.relforcerowsecurity),'unchanged table ACL/RLS'); "
    "SELECT public.c2_assert((SELECT hash FROM public.c2_unchanged_mutation)="
    "md5(pg_get_functiondef('public.correct_completed_performance_record(jsonb)'::regprocedure)),"
    "'unchanged existing correction authority');")
print('C2_CONCURRENCY_AND_PERMISSION_GATE=PASS')
