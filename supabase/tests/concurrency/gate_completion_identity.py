#!/usr/bin/env python3
"""Bounded, barrier-driven role/link proof on the exact disposable container."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('completion concurrency bound')))
signal.alarm(180)
project = os.environ['SPRINT12_PROJECT_ID']
container = os.environ['SPRINT12_DB_CONTAINER']
assert project.startswith('s12g') and container == 'supabase_db_' + project
base = ['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1']
actor = 'c2000000-0000-4000-8000-000000000001'
auth = f"SET ROLE authenticated; SET request.jwt.claim.sub='{actor}';"


def sql(q):
    return subprocess.check_output(base + ['-c', q], text=True, timeout=25)


def digest():
    return sql('SELECT public.completion_security_digest()').strip()


def connection(name, commands):
    p = subprocess.Popen(base, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
    p.stdin.write(f"SET application_name='{name}'; SET statement_timeout='20s'; " + commands + '\n')
    p.stdin.flush()
    return p


def marker(p, value):
    while True:
        line = p.stdout.readline()
        if not line:
            raise AssertionError('connection exited before barrier: ' + p.stderr.read())
        if line.strip() == value:
            return


def finish(p, action='ROLLBACK'):
    if p.poll() is None:
        p.stdin.write(action + ';\n\\q\n')
        p.stdin.flush()
    out, err = p.communicate(timeout=25)
    assert p.returncode == 0, err
    return out


def blocked(p, name):
    for _ in range(100):
        if p.poll() is not None:
            raise AssertionError('link change escaped ownership locks: ' + p.stderr.read())
        n = sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{name}' AND cardinality(pg_blocking_pids(pid))>0").strip()
        if n == '1':
            return
        time.sleep(.03)
    raise AssertionError('competing transaction never reached its lock barrier')


# Actual authenticated correction retains all checked physical/programme links.
for label, change in (
    ('outcome', "UPDATE public.programme_slot_outcomes SET training_session_id=987121 WHERE assignment_id='c2000000-0000-4000-8000-000000000080'"),
    ('assignment', "UPDATE public.programme_assignments SET athlete_id='c2000000-0000-4000-8000-000000000002' WHERE id='c2000000-0000-4000-8000-000000000080'"),
    ('parent', "UPDATE public.training_sessions SET athlete_id='c2000000-0000-4000-8000-000000000002' WHERE id=987002"),
):
    before = digest()
    reader = connection('completion_owner_' + label, "BEGIN; " + auth +
        "SELECT public.correct_completed_performance_record('{\"record_id\":\"c2000000-0000-4000-8000-000000000070\",\"athlete_note\":\"lock proof\"}'); SELECT 'OWNER_READY';")
    writer = None
    try:
        marker(reader, 'OWNER_READY')
        # Trusted server-role mutation tests the lock, never a widened client ACL.
        writer = connection('completion_link_' + label, "BEGIN; " + change + "; SELECT 'LINK_DONE'; ROLLBACK;\n\\q")
        blocked(writer, 'completion_link_' + label)
        finish(reader)
        out, err = writer.communicate(timeout=25)
        assert writer.returncode == 0 and 'LINK_DONE' in out, err
        assert before == digest(), 'link race left evidence residue'
    finally:
        for p in (reader, writer):
            if p is not None and p.poll() is None:
                p.kill()
                p.wait()

# A legitimate parent-free draft must also hold its checked assignment owner.
before = digest()
reader = connection('completion_draft_owner', "BEGIN; " + auth +
    "INSERT INTO public.training_session_records(record_id,athlete_id,assignment_id,session_snapshot,status,started_at) VALUES('d8200000-0000-4000-8000-000000000040','" + actor + "','c2000000-0000-4000-8000-000000000080','{}','in_progress',now()); SELECT 'DRAFT_READY';")
writer = None
try:
    marker(reader, 'DRAFT_READY')
    writer = connection('completion_draft_assignment', "BEGIN; UPDATE public.programme_assignments SET athlete_id='c2000000-0000-4000-8000-000000000002' WHERE id='c2000000-0000-4000-8000-000000000080'; SELECT 'LINK_DONE'; ROLLBACK;\n\\q")
    blocked(writer, 'completion_draft_assignment')
    finish(reader)
    out, err = writer.communicate(timeout=25)
    assert writer.returncode == 0 and 'LINK_DONE' in out, err
    assert before == digest(), 'draft assignment lock probe changed evidence'
finally:
    for p in (reader, writer):
        if p is not None and p.poll() is None:
            p.kill()
            p.wait()

# Fixed completion must acquire its retained advisory fence before occurrence
# rows. A fence holder can lock the row NOWAIT while the public call is waiting.
before = digest()
fixed = sql("""SELECT jsonb_build_object('assignment_id',o.assignment_id,'occurrence_id',o.id,
 'session_slot_id',o.session_slot_id,'programme_version_id',o.programme_version_id,
 'materialised_package_content_hash',o.package_content_hash,'programmed_session_key',o.programmed_session_key,
 'logical_completion_key',o.programmed_session_key,'protocol_id',o.protocol_id,'expected_week',o.week_number,
 'expected_day_key',o.day_key,'expected_slot_order',o.session_order,'record_id','c2000000-0000-4000-8000-000000000070',
 'training_session_id',987002,'status','completed','idempotency_key','fixed-fence-proof','actuals_fingerprint','fixed-fence-proof')
 FROM public.programme_schedule_occurrences o WHERE o.id='c2000000-0000-4000-8000-000000000081'""").strip()
fence = connection('completion_fence_owner', "BEGIN; SELECT pg_advisory_xact_lock(84202409,hashtext('c2000000-0000-4000-8000-000000000081')); SELECT 'FENCE_READY';")
waiter = None
try:
    marker(fence, 'FENCE_READY')
    waiter = connection('completion_fixed_waiter', "BEGIN; " + auth + f"SELECT public.complete_fixed_programme_occurrence_and_advance('{fixed}'); ROLLBACK;\n\\q")
    blocked(waiter, 'completion_fixed_waiter')
    assert sql("SELECT wait_event FROM pg_stat_activity WHERE application_name='completion_fixed_waiter'").strip() == 'advisory'
    fence.stdin.write("SELECT 1 FROM public.programme_schedule_occurrences WHERE id='c2000000-0000-4000-8000-000000000081' FOR UPDATE NOWAIT; SELECT 'ROW_AVAILABLE';\n")
    fence.stdin.flush()
    marker(fence, 'ROW_AVAILABLE')
    finish(fence)
    out, err = waiter.communicate(timeout=25)
    assert waiter.returncode == 0, err
    assert before == digest(), 'fixed fence probe mutated evidence'
finally:
    for p in (fence, waiter):
        if p is not None and p.poll() is None:
            p.kill()
            p.wait()

# Isolated own standalone fixtures: no permission or role changes.
before = digest()
sql("""
INSERT INTO public.training_sessions(id,athlete_id,protocol_id,status) VALUES
 (988810,'c2000000-0000-4000-8000-000000000001','review.concurrent','in_progress'),
 (988820,'c2000000-0000-4000-8000-000000000001','review.concurrent','in_progress');
INSERT INTO public.training_session_records(record_id,athlete_id,training_session_id,source_protocol_id,status,session_snapshot,started_at) VALUES
 ('d8200000-0000-4000-8000-000000000010','c2000000-0000-4000-8000-000000000001',988810,'review.concurrent','in_progress','{}',now()),
 ('d8200000-0000-4000-8000-000000000020','c2000000-0000-4000-8000-000000000001',988820,'review.concurrent','in_progress','{}',now());
INSERT INTO public.training_block_results(block_result_id,session_record_id,block_snapshot,status,result_type,position) VALUES
 ('d8200000-0000-4000-8000-000000000011','d8200000-0000-4000-8000-000000000010','{}','in_progress','completion',1),
 ('d8200000-0000-4000-8000-000000000021','d8200000-0000-4000-8000-000000000020','{}','in_progress','completion',1);
INSERT INTO public.training_exercise_results(exercise_result_id,block_result_id,exercise_snapshot,position) VALUES
 ('d8200000-0000-4000-8000-000000000012','d8200000-0000-4000-8000-000000000011','{}',1);
INSERT INTO public.training_set_results(set_result_id,exercise_result_id,set_number,position) VALUES
 ('d8200000-0000-4000-8000-000000000013','d8200000-0000-4000-8000-000000000012',1,1);
""")
try:
    for change in (
        "UPDATE public.training_exercise_results SET block_result_id='d8200000-0000-4000-8000-000000000021' WHERE exercise_result_id='d8200000-0000-4000-8000-000000000012'",
        "UPDATE public.training_set_results SET set_result_id='d8200000-0000-4000-8000-000000000099' WHERE set_result_id='d8200000-0000-4000-8000-000000000013'",
        "UPDATE public.training_session_records SET record_id='d8200000-0000-4000-8000-000000000099' WHERE record_id='d8200000-0000-4000-8000-000000000020'",
    ):
        d = digest()
        out = sql("BEGIN; " + auth + "DO $$ BEGIN " + change + "; RAISE EXCEPTION 'identity substitution accepted'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'IDENTITY_DENIED'; END $$; ROLLBACK;")
        assert d == digest(), 'direct identity rejection changed evidence'
    # Direct child writes also freeze the physical parent's checked ownership.
    d = digest()
    reader = connection('completion_child_owner', "BEGIN; " + auth +
        "UPDATE public.training_block_results SET athlete_note='draft lock proof' WHERE block_result_id='d8200000-0000-4000-8000-000000000011'; SELECT 'CHILD_READY';")
    writer = None
    try:
        marker(reader, 'CHILD_READY')
        writer = connection('completion_child_parent', "BEGIN; UPDATE public.training_sessions SET athlete_id='c2000000-0000-4000-8000-000000000002' WHERE id=988810; SELECT 'LINK_DONE'; ROLLBACK;\n\\q")
        blocked(writer, 'completion_child_parent')
        finish(reader)
        out, err = writer.communicate(timeout=25)
        assert writer.returncode == 0 and 'LINK_DONE' in out, err
        assert d == digest(), 'direct child parent lock probe changed evidence'
    finally:
        for p in (reader, writer):
            if p is not None and p.poll() is None:
                p.kill()
                p.wait()
    # A direct child statement starts against the old in-progress snapshot, waits
    # behind completion, then must reject the newly terminal record explicitly.
    payload = json.dumps(dict(record_id='d8200000-0000-4000-8000-000000000010', athlete_id=actor,
        training_session_id=988810, source_protocol_id='review.concurrent', status='partially_completed',
        session_snapshot={}, started_at='2026-01-01T12:00:00Z', completed_at='2026-01-01T12:01:00Z'))
    owner = connection('completion_terminal', "BEGIN; " + auth + f"SELECT public.complete_training_session_record('{payload}'); SELECT 'TERMINAL_READY';")
    waiter = None
    try:
        marker(owner, 'TERMINAL_READY')
        waiter = connection('completion_late_child', "BEGIN; " + auth + "DO $$ BEGIN INSERT INTO public.training_block_results(block_result_id,session_record_id,block_snapshot,status,result_type,position) VALUES('d8200000-0000-4000-8000-000000000031','d8200000-0000-4000-8000-000000000010','{}','completed','completion',2); RAISE EXCEPTION 'late child accepted'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'LATE_CHILD_DENIED'; END $$; SELECT 'LATE_DONE'; ROLLBACK;\n\\q")
        blocked(waiter, 'completion_late_child')
        finish(owner, 'COMMIT')
        out, err = waiter.communicate(timeout=25)
        assert waiter.returncode == 0 and 'LATE_CHILD_DENIED' in err, err
        assert sql("SELECT count(*) FROM public.training_block_results WHERE block_result_id='d8200000-0000-4000-8000-000000000031'").strip() == '0'
        assert sql('SELECT ended_early FROM public.training_sessions WHERE id=988810').strip() == 't'
    finally:
        for p in (owner, waiter):
            if p is not None and p.poll() is None:
                p.kill()
                p.wait()
finally:
    sql("DELETE FROM public.training_session_records WHERE record_id IN ('d8200000-0000-4000-8000-000000000010','d8200000-0000-4000-8000-000000000020'); DELETE FROM public.training_sessions WHERE id IN (988810,988820);")
assert before == digest(), 'concurrency fixture cleanup changed other evidence'
# A UUID winner can commit after the pre-insert check. Backfill must revalidate
# the conflict's exact parent even with a block-only tree (no descendant guard).
before = digest()
fixture = (Path(__file__).resolve().parents[1] / 'sql' / 'gate_completion_child_identity.sql').read_text().split('DO $$ DECLARE')[0]
owner = connection('completion_collision_owner', fixture + " SELECT 'BACKFILL_READY';")
writer = None
try:
    marker(owner, 'BACKFILL_READY')
    writer = connection('completion_collision_writer', "BEGIN; INSERT INTO public.training_block_results(block_result_id,session_record_id,block_snapshot,status,result_type,position) VALUES('d8100000-0000-4000-8000-000000000021','c2000000-0000-4000-8000-000000000030','{}','completed','completion',2); SELECT 'FOREIGN_READY';")
    marker(writer, 'FOREIGN_READY')
    payload = json.dumps(dict(assignment_id='d8100000-0000-4000-8000-000000000001',
        occurrence_id='d8100000-0000-4000-8000-000000000002',record_id='d8100000-0000-4000-8000-000000000003',
        idempotency_key='backfill:' + actor + ':d8100000-0000-4000-8000-000000000001:d8100000-0000-4000-8000-000000000002',
        actuals_fingerprint='collision-race',status='completed',performed_on='2026-01-01',
        completion_record=dict(session_snapshot={}, block_results=[dict(block_result_id='d8100000-0000-4000-8000-000000000021',status='completed',result_type='completion')])))
    owner.stdin.write(auth + f" SELECT public.complete_backfilled_fixed_programme_occurrence('{payload}'); SELECT 'COLLISION_DONE';\n")
    owner.stdin.flush()
    blocked(owner, 'completion_collision_owner')
    finish(writer, 'COMMIT')
    reply = None
    while True:
        line = owner.stdout.readline().strip()
        if line.startswith('{'):
            reply = json.loads(line)
        if line == 'COLLISION_DONE':
            break
        if not line and owner.poll() is not None:
            raise AssertionError('backfill collision transaction exited')
    assert reply == dict(status='authorization_failure',code='completion_identity_denied'), 'concurrent foreign UUID was accepted'
    finish(owner)
finally:
    for p in (owner, writer):
        if p is not None and p.poll() is None:
            p.kill()
            p.wait()
    sql("DELETE FROM public.training_block_results WHERE block_result_id='d8100000-0000-4000-8000-000000000021'")
assert before == digest(), 'UUID collision race changed retained evidence'
print('COMPLETION_LINK_AND_TERMINAL_CONCURRENCY=PASS (five link barriers, immutable identities, late child denial, concurrent UUID collision)')
