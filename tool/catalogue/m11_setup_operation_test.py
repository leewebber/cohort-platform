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
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
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

    def test_operator_role_is_fixed_session_initialisation_not_startup_option(self):
        with patch.object(op.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, b'{}', b'')) as run:
            self.assertEqual(op.Psql('ReviewedService', role='postgres').run('SELECT 1;'), b'{}')
            self.assertEqual(run.call_args.kwargs['input'], b'SET ROLE "postgres";\nSELECT 1;')
            self.assertIn('--dbname=service=ReviewedService sslmode=verify-full', run.call_args.args[0])
        for role in ['', 'postgres;RESET ROLE', 'a"b', 'a\npostgres', 'a' * 64]:
            with self.assertRaises(ValueError): op.Psql('ReviewedService', role=role)

    def test_duplicate_primary_identity_still_refuses(self):
        snapshot = retained_snapshot()
        snapshot['state']['rows'].append(copy.deepcopy(snapshot['state']['rows'][0]))
        snapshot['raw_state'] = op.encode(snapshot['state'])
        with self.assertRaisesRegex(ValueError, 'Incomplete/duplicate inventory'):
            op.validate_snapshot(snapshot)

    def test_two_planned_records_cannot_share_a_new_slug(self):
        decisions = [{'source_variant': v, 'action': 'create', 'reuse_id': None,
                      'slug': slug, 'exact_setup_review_reference': 'Synthetic exact content',
                      'reviewed_extra_fields': {}, 'field_review_reference': None}
                     for v, slug in zip(op.VARIANTS, SLUGS)]
        decisions[1]['slug'] = decisions[0]['slug']
        with self.assertRaisesRegex(ValueError, 'Duplicate planned identities/slugs'):
            op.prepare(retained_snapshot(), decisions, 'm11-two-planned-slugs')

    def test_canonical_manifest_roundtrip_preserves_exact_generated_seed(self):
        decisions = [{'source_variant': v, 'action': 'create', 'reuse_id': None,
                      'slug': slug, 'exact_setup_review_reference': 'Synthetic exact content',
                      'reviewed_extra_fields': {}, 'field_review_reference': None}
                     for v, slug in zip(op.VARIANTS, SLUGS)]
        manifest = op.prepare(retained_snapshot(), decisions, 'm11-canonical-seed-roundtrip')
        raw_manifest = (op.encode(manifest) + chr(10)).encode()
        raw_seed = op.seed(manifest).encode()
        with tempfile.TemporaryDirectory(prefix='m11_canonical_pin_') as directory:
            folder = Path(directory)
            op.write_new(folder / 'manifest.json', raw_manifest)
            op.write_new(folder / 'seed.sql', raw_seed)
            reloaded, reloaded_seed = op.pinned(folder / 'manifest.json', op.sha(raw_manifest),
                                                folder / 'seed.sql', op.sha(raw_seed))
        self.assertEqual(reloaded, manifest)
        self.assertEqual(reloaded_seed, raw_seed)
        reordered = copy.deepcopy(manifest)
        for operation in reordered['operations']:
            operation['fields'] = dict(reversed(list(operation['fields'].items())))
        self.assertEqual(op.seed(reordered).encode(), raw_seed)

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
        cls.local('docker', 'run', '-d', '--name', cls.container, '--network', 'none', '--pull=never',
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



RETAINED = op.ROOT / 'docs/checkpoints/m11_catalogue_operation/resumed_preflight_2026_11_04/evidence/operator-preflight.raw.json'
SLUGS = ('bilateral-chest-supported-dumbbell-row',
         'seated-supported-neutral-grip-dumbbell-shoulder-press',
         'two-dumbbell-reverse-lunge')


def retained_snapshot():
    raw = RETAINED.read_text()
    state = json.loads(raw)
    return {'kind': 'SYNTHETIC_LOCAL_FIXTURE', 'target_ref': op.TARGET,
            'provenance': 'Local replay of immutable retained rows; no current hosted claim',
            'operator_authorisation': {'principal': state['identity']['session_user'],
                                      'role': state['identity']['role'],
                                      'reference': 'Synthetic local guard proof only',
                                      'expires_at': (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()},
            'audit_reference': 'synthetic-retained-row-replay',
            'state': state, 'raw_state': raw}


@unittest.skipUnless(os.environ.get('M11_LOCAL_DB') == '1', 'Explicit disposable local DB proof only')
class RetainedInventory(unittest.TestCase):
    setUpClass = classmethod(LocalDatabase.setUpClass.__func__)
    tearDownClass = classmethod(LocalDatabase.tearDownClass.__func__)
    local = staticmethod(LocalDatabase.local)

    def setUp(self):
        LocalDatabase.setUp(self)
        self.retained = json.loads(RETAINED.read_text())
        self.db.run('DELETE FROM public.exercises_v2; INSERT INTO public.exercises_v2 '
                    'SELECT * FROM jsonb_populate_recordset(NULL::public.exercises_v2,'
                    + op.literal(self.retained['rows']) + ');')
        # Synthetic exact-ID consumer links: no genuine athlete rows are copied.
        self.db.run("ALTER TABLE public.session_block_exercises ADD COLUMN exercise_id text REFERENCES public.exercises_v2(exercise_id);"
                    "INSERT INTO public.session_block_exercises(id,retained,exercise_id) VALUES "
                    "('legacy-one','unchanged','EX-029'),('legacy-two','unchanged','EX-141');")
        self.snapshot = self.capture()
        self.decisions = [{'source_variant': variant, 'action': 'create', 'reuse_id': None,
                           'slug': slug, 'exact_setup_review_reference': 'SYNTHETIC rehearsal of founder-pinned exact content',
                           'reviewed_extra_fields': {}, 'field_review_reference': None}
                          for variant, slug in zip(op.VARIANTS, SLUGS)]
        self.manifest = op.prepare(self.snapshot, self.decisions, 'm11-retained-local-rehearsal')
        self.seed = op.seed(self.manifest).encode()

    def capture(self):
        raw, state = op.inspect_state(self.db)
        return {'kind': 'SYNTHETIC_LOCAL_FIXTURE', 'target_ref': op.TARGET,
                'provenance': 'Network-disabled disposable PostgreSQL; retained catalogue rows, synthetic consumers/identity/time',
                'operator_authorisation': {'principal': state['identity']['session_user'], 'role': state['identity']['role'],
                                          'reference': 'Local rehearsal only',
                                          'expires_at': (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()},
                'audit_reference': 'synthetic-retained-inventory-rehearsal',
                'state': state, 'raw_state': raw.decode()}

    def assert_no_creates(self):
        ids = {o['fields']['exercise_id'] for o in self.manifest['operations']}
        self.assertFalse(ids & {r['exercise_id'] for r in op.inspect_state(self.db)[1]['rows']})

    def test_retained_169_insert_retain_replay_reuse_preserves_duplicate_rows_and_consumers(self):
        self.assertEqual(self.snapshot['state']['rows'], self.retained['rows'])
        pair = [r for r in self.retained['rows'] if r['slug'] == 'bulgarian-split-squat']
        self.assertEqual({r['exercise_id'] for r in pair}, {'EX-029', 'EX-141'})
        self.assertNotIn('bulgarian-split-squat', SLUGS)
        with tempfile.TemporaryDirectory(prefix='m11_prepare_cli_') as directory:
            folder = Path(directory)
            op.write_new(folder / 'snapshot.json', (op.encode(self.snapshot) + chr(10)).encode())
            op.write_new(folder / 'decisions.json', (op.encode(self.decisions) + chr(10)).encode())
            process = subprocess.run([sys.executable, str(op.ROOT / 'tool/catalogue/m11_setup_operation.py'),
                                      'prepare', '--snapshot', str(folder / 'snapshot.json'),
                                      '--decisions', str(folder / 'decisions.json'), '--request-id',
                                      self.manifest['request_id'], '--out', str(folder / 'prepared')],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(process.returncode, 0, process.stderr.decode())
            pins = op.load(folder / 'prepared/SHA256.json')
            manifest, seed = op.pinned(folder / 'prepared/manifest.json', pins['manifest.json'],
                                       folder / 'prepared/seed.sql', pins['seed.sql'])
            self.assertEqual(manifest, self.manifest)
            self.assertEqual(seed, self.seed)
            self.manifest, self.seed = manifest, seed
        acknowledgement = op.apply(self.db, self.manifest, self.seed)
        self.assertEqual(acknowledgement['status'], 'APPLIED')
        after = json.loads(acknowledgement['after_raw'])
        self.assertEqual(len(after['rows']), 172)
        existing_ids = {r['exercise_id'] for r in self.retained['rows']}
        self.assertEqual([r for r in after['rows'] if r['exercise_id'] in existing_ids], self.retained['rows'])
        self.assertEqual(after['consumer_guard'], self.snapshot['state']['consumer_guard'])
        replay = op.apply(self.db, self.manifest, self.seed)
        self.assertEqual(replay['status'], 'EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED')
        reuse = copy.deepcopy(self.decisions)
        for d, o in zip(reuse, self.manifest['operations']):
            d.update(action='reuse', reuse_id=o['fields']['exercise_id'])
        reuse_manifest = op.prepare(self.capture(), reuse, 'm11-retained-unique-reuse')
        self.assertTrue(all(o['action'] == 'reuse' for o in reuse_manifest['operations']))
        self.assertEqual(op.apply(self.db, reuse_manifest, op.seed(reuse_manifest).encode())['status'],
                         'EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED')
        output = os.environ.get('M11_REHEARSAL_OUT')
        with tempfile.TemporaryDirectory(prefix='m11_retained_receipt_') as temporary:
            root = Path(output) if output else Path(temporary) / 'evidence'
            root.mkdir(exist_ok=False)
            receipt = op.retain(self.db, self.manifest, self.seed, acknowledgement, root / 'retained')
            self.assertFalse(receipt['hosted_retention'])
            op.write_new(root / 'snapshot.json', (op.encode(self.snapshot) + '\n').encode())
            op.write_new(root / 'decisions.json', (op.encode(self.decisions) + '\n').encode())
            op.write_new(root / 'replay.json', (op.encode(replay) + '\n').encode())
            summary = {'classification': 'SYNTHETIC_LOCAL_FIXTURE', 'input_retained_sha256': op.sha(RETAINED.read_bytes()),
                       'catalogue_rows_before': 169, 'catalogue_rows_after': 172,
                       'preexisting_rows_exact': True, 'duplicate_group_preserved': True,
                       'synthetic_consumer_links_and_guards_unchanged': True,
                       'apply': acknowledgement['status'], 'replay': replay['status'],
                       'all_unique_target_reuse': True, 'real_prepare_cli_and_pin_roundtrip': True, 'hosted_retention': False,
                       'manifest_sha256': op.sha((root / 'retained/manifest.json').read_bytes()),
                       'seed_sha256': op.sha(self.seed)}
            op.write_new(root / 'SUMMARY.json', (op.encode(summary) + '\n').encode())

    def test_create_target_slug_colliding_with_existing_duplicate_refuses(self):
        decisions = copy.deepcopy(self.decisions)
        decisions[0]['slug'] = 'bulgarian-split-squat'
        with self.assertRaisesRegex(ValueError, 'Allocated ID/slug collision'):
            op.prepare(self.snapshot, decisions, 'm11-target-duplicate-collision')
        self.assert_no_creates()

    def test_lookup_dependency_collision_including_trimmed_alias_refuses(self):
        for alias in (SLUGS[0], ' 	' + SLUGS[0] + '\n', '\ufeff ' + SLUGS[0] + '\ufeff'):
            with self.subTest(alias=repr(alias)):
                self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES ('EX-997',"
                            + op.sql_text(alias) + ');')
                with self.assertRaisesRegex(ValueError, 'Allocated ID/slug collision'):
                    op.prepare(self.capture(), self.decisions, 'm11-trimmed-target-collision')
                self.db.run("DELETE FROM public.exercises_v2 WHERE exercise_id='EX-997';")
        self.assert_no_creates()

    def test_exact_id_reuse_with_ambiguous_slug_dependency_refuses(self):
        op.apply(self.db, self.manifest, self.seed)
        reuse = copy.deepcopy(self.decisions)
        for d, o in zip(reuse, self.manifest['operations']):
            d.update(action='reuse', reuse_id=o['fields']['exercise_id'])
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,name,slug,published) VALUES "
                    "('EX-998','Unrelated fixture label'," + op.sql_text(' ' + SLUGS[0] + ' ') + ',true);')
        with self.assertRaisesRegex(ValueError, 'Ambiguous operation slug lookup'):
            op.prepare(self.capture(), reuse, 'm11-exact-id-ambiguous-lookup')

    def test_two_exact_setup_candidates_still_refuse_even_with_distinct_slugs(self):
        fields = self.manifest['operations'][0]['fields']
        for eid, slug in [('EX-997', 'fixture-exact-one'), ('EX-998', 'fixture-exact-two')]:
            row = {**fields, 'exercise_id': eid, 'slug': slug}
            self.db.run('INSERT INTO public.exercises_v2 SELECT * FROM jsonb_populate_record(NULL::public.exercises_v2,'
                        + op.literal(row) + ');')
        with self.assertRaisesRegex(ValueError, 'Ambiguous exact setup matches'):
            op.prepare(self.capture(), self.decisions, 'm11-ambiguous-exact-candidates')
        self.assert_no_creates()

    def test_changed_existing_duplicate_member_aborts_and_postcheck_refuses(self):
        self.db.run("UPDATE public.exercises_v2 SET equipment='Synthetic changed member' WHERE exercise_id='EX-141';")
        with self.assertRaisesRegex(ValueError, 'protected pre-existing catalogue state drift'):
            op.apply(self.db, self.manifest, self.seed)
        self.assert_no_creates()
        with self.assertRaisesRegex(ValueError, 'Pre-existing catalogue rows changed'):
            op.verify_post(self.manifest, self.capture()['state'])

    def test_added_duplicate_member_after_prepare_aborts_whole_batch(self):
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES ('EX-997','bulgarian-split-squat');")
        with self.assertRaisesRegex(ValueError, 'protected pre-existing catalogue state drift'):
            op.apply(self.db, self.manifest, self.seed)
        self.assert_no_creates()

    def test_target_lookup_alias_inserted_after_prepare_aborts_whole_batch(self):
        self.db.run("INSERT INTO public.exercises_v2(exercise_id,slug) VALUES ('EX-997',"
                    + op.sql_text(' ' + SLUGS[0] + '	') + ');')
        with self.assertRaisesRegex(ValueError, 'protected pre-existing catalogue state drift'):
            op.apply(self.db, self.manifest, self.seed)
        self.assert_no_creates()

    def test_replay_and_retention_refuse_changed_duplicate_member(self):
        acknowledgement = op.apply(self.db, self.manifest, self.seed)
        self.db.run("UPDATE public.exercises_v2 SET slug='synthetic-renamed' WHERE exercise_id='EX-029';")
        with self.assertRaises(ValueError):
            op.apply(self.db, self.manifest, self.seed)
        with tempfile.TemporaryDirectory(prefix='m11_changed_duplicate_') as directory:
            with self.assertRaisesRegex(ValueError, 'Pre-existing catalogue rows changed'):
                op.retain(self.db, self.manifest, self.seed, acknowledgement, Path(directory) / 'refused')

    def test_real_noninheriting_login_uses_only_explicit_existing_role(self):
        self.db.run('CREATE ROLE m11_local_operator LOGIN NOINHERIT; CREATE ROLE m11_local_owner NOLOGIN; '
                    'GRANT m11_local_owner TO m11_local_operator; '
                    'GRANT USAGE ON SCHEMA public TO m11_local_owner; '
                    'GRANT SELECT ON public.exercises_v2 TO m11_local_owner;')
        original_run = subprocess.run
        def local_transport(command, **kwargs):
            self.assertEqual(command[0], 'psql')
            actual = ['docker','exec','-i',self.container,'psql','-h','127.0.0.1','-U','m11_local_operator',
                      '-d','postgres','-X','-q','-A','-t','-v','ON_ERROR_STOP=1']
            result = original_run(actual, **kwargs)
            if result.returncode:
                raise ValueError('Disposable role fixture: ' + result.stderr.decode())
            return result
        with patch.object(op.subprocess, 'run', side_effect=local_transport):
            raw = op.Psql('SyntheticTransport', role='m11_local_owner').run(
                "SELECT jsonb_build_object('session_user',session_user,'role',current_user,"
                "'rows',(SELECT count(*) FROM public.exercises_v2));")
        self.assertEqual(json.loads(raw), {'session_user':'m11_local_operator','role':'m11_local_owner','rows':169})


if __name__ == '__main__': unittest.main()
