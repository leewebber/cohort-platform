#!/usr/bin/env python3
"""Pure guards plus opt-in disposable real PostgreSQL transaction proof.

M11_LOCAL_DB=1 starts one uniquely named local container using an already cached
image and no network. It never selects or stops any existing container/stack.
"""
import copy
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
import uuid

import m11_setup_operation as op


class Guards(unittest.TestCase):
    def test_offline_request_has_exact_scope_no_allocated_identity_or_retention(self):
        request = op.approved_request()
        self.assertEqual(tuple(o['source_variant'] for o in request['operations']), op.VARIANTS)
        self.assertFalse(request['hosted_retention'])
        self.assertIsNone(request['seed'])
        self.assertEqual(request['assigned_real_ids'], [])

    def test_no_connection_strings_or_missing_operator_connection(self):
        for service in ['', 'postgres://secret', 'bad value', 'a\npassword']:
            with self.assertRaises(ValueError): op.Psql(service)

    def test_duplicate_json_keys_refused(self):
        with tempfile.TemporaryDirectory(prefix='m11_guard_') as directory:
            path = Path(directory) / 'input.json'
            path.write_text('{"target":1,"target":2}')
            with self.assertRaises(ValueError): op.load(path)


@unittest.skipUnless(os.environ.get('M11_LOCAL_DB') == '1', 'Explicit disposable local DB proof only')
class LocalDatabase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.container = 'm11_catalogue_' + uuid.uuid4().hex[:12]
        cls.local('docker', 'run', '-d', '--name', cls.container, '--network', 'none',
                  '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', 'public.ecr.aws/supabase/postgres:17.6.1.143')
        for _ in range(200):
            # The image briefly starts a temporary init server. Wait for PID 1
            # to become the final postgres process, then prove the actual role.
            health = subprocess.run(['docker', 'inspect', '--format', '{{.State.Health.Status}}', cls.container], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            if health.stdout.strip() == b'healthy' and subprocess.run(['docker', 'exec', cls.container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-q', '-t', '-c', 'SELECT current_user'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(.2)
        else:
            cls.local('docker', 'rm', '-f', cls.container)
            raise RuntimeError('Disposable local database did not become ready')
        cls.db = LocalPsql(cls.container)

    @classmethod
    def tearDownClass(cls):
        cls.local('docker', 'rm', '-f', cls.container)

    @staticmethod
    def local(*command):
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode: raise RuntimeError('Disposable local database command failed')
        return result.stdout

    def setUp(self):
        # Fixture schema ONLY, derived from the repository's hosted-faithful
        # local baseline. Tool/seed contains no DDL or grant statements.
        baseline = (op.ROOT / 'supabase/tests/fixtures/local_test_baseline_prereq.sql').read_text()
        table = baseline[baseline.index('CREATE TABLE public.exercises_v2 ('):baseline.index('-- Hosted: RLS disabled, zero policies on exercises_v2')]
        ddl = 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;\n' + table
        for t in op.CONSUMERS:
            ddl += f'CREATE TABLE public.{t}(id text PRIMARY KEY, retained text); INSERT INTO public.{t} VALUES (\'fixture\',\'unchanged\');\n'
        for i in sorted(op.PROTECTED):
            ddl += "INSERT INTO public.exercises_v2(exercise_id,name,slug,published) VALUES ('%s','Protected %s','protected-%s',true);\n" % (i, i, i.lower())
        self.db.run(ddl)
        raw, state = op.inspect_state(self.db)
        self.snapshot = {'kind': 'SYNTHETIC_LOCAL_FIXTURE', 'target_ref': op.TARGET,
                         'provenance': 'Disposable PostgreSQL fixture; not hosted retention',
                         'operator_authorisation': {'principal': 'postgres', 'role': 'postgres', 'reference': 'Local proof only', 'expires_at': (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()},
                         'audit_reference': 'synthetic-test-only', 'state': state, 'raw_state': raw.decode()}
        self.decisions = [{'source_variant': variant, 'action': 'create', 'reuse_id': None,
                           'slug': 'fixture-setup-' + str(i), 'exact_setup_review_reference': 'SYNTHETIC explicit exact setup',
                           'reviewed_extra_fields': {}, 'field_review_reference': None}
                          for i, variant in enumerate(op.VARIANTS)]
        self.manifest = op.prepare(self.snapshot, self.decisions, 'm11-local-fixed-request')
        self.seed = op.seed(self.manifest).encode()

    def test_exact_insert_replay_independent_raw_retention_and_tampering(self):
        receipt = op.apply(self.db, self.manifest, self.seed)
        self.assertEqual(receipt['status'], 'APPLIED')
        replay = op.apply(self.db, self.manifest, self.seed)
        self.assertEqual(replay['status'], 'EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED')
        with tempfile.TemporaryDirectory(prefix='m11_receipt_') as directory:
            retained = op.retain(self.db, self.manifest, self.seed, receipt, Path(directory) / 'retained')
            self.assertFalse(retained['hosted_retention'])
            self.assertEqual(retained['query_sha256'], op.sha(op.state_sql().encode()))
            self.assertEqual(len(retained['result_rows']), 3)
            corrupted = copy.deepcopy(receipt)
            rows = json.loads(corrupted['after_raw'])
            rows['rows'][-1]['setup'] = 'tampered'
            corrupted['after_raw'] = op.encode(rows)
            with self.assertRaises(ValueError):
                op.retain(self.db, self.manifest, self.seed, corrupted, Path(directory) / 'tampered')

    def test_partial_state_and_slug_collision_abort_whole_batch(self):
        first = self.manifest['operations'][0]['fields']
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES (%s,%s);" % (op.sql_text(first['exercise_id']), op.sql_text(first['slug'])))
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)
        _, state = op.inspect_state(self.db)
        self.assertEqual(len(state['rows']), 4)
        self.db.run('DELETE FROM public.exercises_v2 WHERE exercise_id=' + op.sql_text(first['exercise_id']) + ';')
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES ('EX-999',%s);" % op.sql_text(first['slug']))
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)
        self.assertEqual(len(op.inspect_state(self.db)[1]['rows']), 4)

    def test_protected_rows_consumers_and_live_constraint_drift_refuse(self):
        self.db.run("UPDATE public.exercises_v2 SET setup='unexpected' WHERE exercise_id='EX-026';")
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)
        self.db.run("UPDATE public.exercises_v2 SET setup=NULL WHERE exercise_id='EX-026';")
        self.db.run("UPDATE public.training_sessions SET retained='unexpected';")
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)
        self.db.run("UPDATE public.training_sessions SET retained='unchanged'; ALTER TABLE public.exercises_v2 ADD CONSTRAINT slug_fixture UNIQUE(slug);")
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)

    def test_role_mismatch_and_no_insert_role_cannot_apply(self):
        self.db.run("CREATE ROLE m11_reader; GRANT USAGE ON SCHEMA public TO m11_reader; GRANT SELECT ON ALL TABLES IN SCHEMA public TO m11_reader;")
        reader = LocalPsql(self.container, role='m11_reader')
        with self.assertRaises(ValueError): op.apply(reader, self.manifest, self.seed)
        with self.assertRaises(ValueError): reader.run(self.seed.decode())
        self.assertEqual(len(op.inspect_state(self.db)[1]['rows']), 3)

    def test_exact_dedup_ambiguity_unknown_required_fields_and_manifest_replacement(self):
        bad = copy.deepcopy(self.decisions); bad[0]['extra'] = 'unknown'
        with self.assertRaises(ValueError): op.prepare(self.snapshot, bad, 'm11-local-request')
        mutated = copy.deepcopy(self.manifest); mutated['operations'][0]['fields']['name'] = 'replacement'
        with self.assertRaises(ValueError): op.seed(mutated)
        altered = copy.deepcopy(self.snapshot)
        altered['state']['columns'].append({'name': 'new_taxonomy', 'type': 'text', 'nullable': 'NO', 'default': None})
        altered['raw_state'] = op.encode(altered['state'])
        with self.assertRaisesRegex(ValueError, 'Unknown required catalogue field'): op.prepare(altered, self.decisions, 'm11-local-request')
        op.apply(self.db, self.manifest, self.seed)
        _, state = op.inspect_state(self.db)
        snap = {**self.snapshot, 'state': state, 'raw_state': op.encode(state)}
        with self.assertRaises(ValueError): op.prepare(snap, self.decisions, 'm11-local-request')
        reuse = copy.deepcopy(self.decisions)
        for d, o in zip(reuse, self.manifest['operations']):
            d.update(action='reuse', reuse_id=o['fields']['exercise_id'])
        m = op.prepare(snap, reuse, 'm11-local-reuse-request')
        self.assertEqual(len([o for o in m['operations'] if o['action'] == 'create']), 0)
        self.assertEqual(op.apply(self.db, m, op.seed(m).encode())['status'], 'EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED')
        duplicate = {**self.manifest['operations'][0]['fields'], 'exercise_id': 'EX-997', 'slug': 'distinct-slug-same-setup'}
        names = ','.join(duplicate)
        self.db.run('INSERT INTO public.exercises_v2 (' + names + ') SELECT ' + names + ' FROM jsonb_populate_record(NULL::public.exercises_v2,' + op.literal(duplicate) + ');')
        raw, ambiguous = op.inspect_state(self.db)
        with self.assertRaisesRegex(ValueError, 'Ambiguous exact setup'):
            op.prepare({**self.snapshot, 'state': ambiguous, 'raw_state': raw.decode()}, reuse, 'm11-local-ambiguous')

    def test_insert_failure_rolls_back_all_three_and_unrelated_writers_are_excluded(self):
        # A real role/table check rejects the second insert after the first would
        # succeed; the tool has no compensating DELETE path.
        second = self.manifest['operations'][1]['fields']['exercise_id']
        self.db.run('ALTER TABLE public.exercises_v2 ADD CONSTRAINT fixture_reject CHECK (exercise_id <> ' + op.sql_text(second) + ');')
        _, state = op.inspect_state(self.db)
        m = op.prepare({**self.snapshot, 'state': state, 'raw_state': op.encode(state)}, self.decisions, 'm11-local-rollback')
        with self.assertRaises(ValueError): op.apply(self.db, m, op.seed(m).encode())
        self.assertEqual(len(op.inspect_state(self.db)[1]['rows']), 3)
        held = subprocess.Popen(self.db.command(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        held.stdin.write(b"BEGIN; LOCK TABLE public.exercises_v2 IN EXCLUSIVE MODE; SELECT pg_sleep(1.5); COMMIT;\n")
        held.stdin.close()
        time.sleep(.3)
        started = time.monotonic()
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES ('EX-999','concurrent');")
        self.assertGreater(time.monotonic() - started, .8)
        held.wait(timeout=5)
        held.stdout.close()
        held.stderr.close()
        with self.assertRaises(ValueError): op.apply(self.db, self.manifest, self.seed)

    def test_deferred_consumer_side_effect_is_forced_and_rolled_back_before_commit(self):
        self.db.run("""CREATE FUNCTION public.m11_fixture_deferred_change() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN UPDATE public.training_sessions SET retained='unexpected'; RETURN NEW; END $$;
        CREATE CONSTRAINT TRIGGER m11_fixture_deferred_change AFTER INSERT ON public.exercises_v2
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.m11_fixture_deferred_change();""")
        raw, state = op.inspect_state(self.db)
        manifest = op.prepare({**self.snapshot, 'state': state, 'raw_state': raw.decode()}, self.decisions, 'm11-local-deferred-request')
        with self.assertRaises(ValueError): op.apply(self.db, manifest, op.seed(manifest).encode())
        _, after = op.inspect_state(self.db)
        self.assertEqual(after['rows'], state['rows'])
        self.assertEqual(after['consumer_guard'], state['consumer_guard'])


class LocalPsql:
    def __init__(self, container, role=None):
        self.container, self.role = container, role

    def command(self):
        return ['docker', 'exec', '-i', self.container, 'psql', '-U', 'postgres', '-d', 'postgres', '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1']

    def run(self, sql):
        if self.role: sql = 'SET ROLE ' + self.role + ';\n' + sql
        result = subprocess.run(self.command(), input=sql.encode(), stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90)
        if result.returncode: raise ValueError('Synthetic local SQL refused: ' + result.stderr.decode())
        return result.stdout


if __name__ == '__main__': unittest.main()
