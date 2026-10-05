#!/usr/bin/env python3
"""Local Docker/psql only. Two-session barrier proof; no DB URLs or credentials."""
import json
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
record = 'c2000000-0000-4000-8000-000000000010'
block = 'c2000000-0000-4000-8000-000000000011'
auth = f"SET ROLE authenticated; SET request.jwt.claim.sub='{actor}'; "
rpc = f"public.read_performance_tracking_history_v1('{record}')"

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
    lock = 6200513 + iteration
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
        print(f'C2_CORRECTION_RACE_{iteration + 1}=PASS')
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

sql("SELECT public.c2_assert(NOT EXISTS(SELECT 1 FROM public.c2_unchanged_permissions b "
    "JOIN pg_class c ON c.oid=b.oid WHERE c.relacl::text IS DISTINCT FROM b.acl "
    "OR c.relrowsecurity IS DISTINCT FROM b.relrowsecurity "
    "OR c.relforcerowsecurity IS DISTINCT FROM b.relforcerowsecurity),'unchanged table ACL/RLS'); "
    "SELECT public.c2_assert((SELECT hash FROM public.c2_unchanged_mutation)="
    "md5(pg_get_functiondef('public.correct_completed_performance_record(jsonb)'::regprocedure)),"
    "'unchanged existing correction authority');")
print('C2_CONCURRENCY_AND_PERMISSION_GATE=PASS')
