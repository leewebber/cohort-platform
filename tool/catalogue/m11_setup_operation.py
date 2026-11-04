#!/usr/bin/env python3
"""Exact three-record operator seed route. Offline by default; no credential port.

The CLI uses a separately provisioned libpq service reference, never a DSN/key.
It has no arbitrary SQL mode. All SQL is generated from strictly validated data.
An operator wrapper does not narrow its DB role's server privileges.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
WRITE_SET = ROOT / 'docs/checkpoints/m11_catalogue_setup_creation/WRITE_SET.json'
SOURCE = ROOT / 'docs/programmes/hybrid_10k/founder_selected_2026_10_30/SOURCE.json'
TARGET = 'otnhhdxstdnwccehacku'
SOURCE_SHA = 'f12b5df97f0a9dc813c9610021ee82233414d2e2b1e6187dd0ae09745e3ecdf5'
WRITE_SET_SHA = '7ebba83be9d35c26c73ad2202fd149f5909fa71619d3b1266e465b18b847a746'
PROTECTED = {'EX-026', 'EX-037', 'EX-090'}
VARIANTS = ('chest_supported_db_row', 'seated_supported_db_press', 'reverse_lunge_db')
CONSUMERS = ('performance_protocols', 'session_blocks', 'session_block_exercises',
             'training_sessions', 'programme_assignments')
MAX_INPUT = 8 * 1024 * 1024


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def reject(message):
    raise ValueError(message)


def keys(value, required):
    if not isinstance(value, dict) or set(value) != set(required):
        reject('Missing/unknown operation fields')
    return value


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            reject('Duplicate JSON field')
        result[key] = value
    return result


def load(path):
    raw = Path(path).read_bytes()
    if len(raw) > MAX_INPUT:
        reject('Input exceeds bounded operation limit')
    return json.loads(raw, object_pairs_hook=no_duplicates)


def write_new(path, raw):
    """Never replace retained evidence, including a previous failed operation."""
    with Path(path).open('xb') as handle:
        handle.write(raw)


def approved_request():
    if sha(WRITE_SET.read_bytes()) != WRITE_SET_SHA:
        reject('The exact approved write-set bytes changed')
    request = load(WRITE_SET)
    if request['target_ref'] != TARGET or tuple(o['source_variant'] for o in request['operations']) != VARIANTS:
        reject('The bounded founder write set changed')
    if sha(SOURCE.read_bytes()) != SOURCE_SHA or request['source']['sha256'] != SOURCE_SHA:
        reject('The selected source changed')
    if set(request['protected_records_no_updates_or_deletes']) != PROTECTED:
        reject('Protected catalogue identities changed')
    return {'kind': 'm11_exact_catalogue_operation_request_v1', 'target_ref': TARGET,
            'write_set_sha256': sha(WRITE_SET.read_bytes()), 'source_sha256': SOURCE_SHA,
            'operations': request['operations'], 'protected_ids': sorted(PROTECTED),
            'status': 'PREPARED_OFFLINE_CONNECTION_SCHEMA_AND_FRESH_INVENTORY_REQUIRED',
            'assigned_real_ids': [], 'seed': None, 'hosted_retention': False}


def state_sql():
    guards = ','.join(
        "'%s',(SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.%s t)" % (t, t)
        for t in CONSUMERS)
    return """SELECT jsonb_build_object(
      'identity',jsonb_build_object('database',current_database(),'role',current_user,
        'session_user',session_user,'system_identifier',(SELECT system_identifier::text FROM pg_control_system()),
        'server_addr',inet_server_addr()::text,'server_port',inet_server_port(),
        'ssl',(SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid())),
      'captured_at',clock_timestamp()::text,
      'columns',(SELECT jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,
        'nullable',is_nullable,'default',column_default) ORDER BY ordinal_position)
        FROM information_schema.columns WHERE table_schema='public' AND table_name='exercises_v2'),
      'constraints',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',conname,'definition',pg_get_constraintdef(oid)) ORDER BY conname),'[]'::jsonb)
        FROM pg_constraint WHERE conrelid='public.exercises_v2'::regclass),
      'indexes',(SELECT jsonb_agg(indexdef ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='exercises_v2'),
      'rows',(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY exercise_id),'[]'::jsonb) FROM public.exercises_v2 e),
      'consumer_guard',jsonb_build_object(%s));""" % guards


class Psql:
    def __init__(self, service, role=None):
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}', service or ''):
            reject('Use a separately provisioned libpq service name; connection strings are forbidden')
        if role is not None and not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]{0,62}', role):
            reject('Use only the reviewed operator role from the pinned manifest')
        self.service = service
        self.role = role

    def run(self, sql):
        # psqlrc is disabled. Credentials are resolved by normal libpq outside
        # this tool. Never return stderr, a connection string or secret values.
        command = ['psql', '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1',
                   '--dbname=service=' + self.service + ' sslmode=verify-full']
        # Supavisor may ignore startup role options. The normal CLI route uses
        # explicit SET ROLE through the already authorised existing membership.
        # The CLI caller derives this role only from the pinned manifest.
        if self.role is not None:
            sql = 'SET ROLE "' + self.role + '";\n' + sql
        try:
            result = subprocess.run(command, input=sql.encode(), stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, timeout=90, check=False)
        except (subprocess.TimeoutExpired, OSError):
            reject('UNKNOWN: connection/process outcome unavailable. Reconcile the same pinned operation; do not allocate new identities')
        if result.returncode:
            reject('REFUSED_OR_UNKNOWN: operator SQL failed. No retention claimed; preserve the operation and reconcile readback/audit')
        return result.stdout


def inspect_state(db):
    raw = db.run(state_sql())
    state = json.loads(raw, object_pairs_hook=no_duplicates)
    keys(state, ('identity', 'captured_at', 'columns', 'constraints', 'indexes', 'rows', 'consumer_guard'))
    return raw, state


def validate_snapshot(snapshot):
    keys(snapshot, ('kind', 'target_ref', 'provenance', 'operator_authorisation', 'audit_reference', 'state', 'raw_state'))
    if snapshot['kind'] not in ('AUTHENTICATED_OPERATOR_PREFLIGHT', 'SYNTHETIC_LOCAL_FIXTURE') or snapshot['target_ref'] != TARGET:
        reject('Unexpected snapshot target/classification')
    if not snapshot['operator_authorisation'] or not snapshot['audit_reference'] or not snapshot['provenance']:
        reject('Actual operator authorisation and capture/audit provenance are required')
    state = snapshot['state']
    if json.loads(snapshot['raw_state'], object_pairs_hook=no_duplicates) != state:
        reject('Raw authenticated preflight bytes differ from parsed state')
    auth = keys(snapshot['operator_authorisation'], ('principal', 'role', 'reference', 'expires_at'))
    if auth['principal'] != state['identity']['session_user'] or auth['role'] != state['identity']['role'] or not auth['reference']:
        reject('The authorised principal/effective role must match actual authentication')
    expiry = datetime.fromisoformat(auth['expires_at'])
    if expiry.tzinfo is None or expiry <= datetime.now(timezone.utc):
        reject('Operator apply authorisation has expired or has no timezone')
    keys(state, ('identity', 'captured_at', 'columns', 'constraints', 'indexes', 'rows', 'consumer_guard'))
    if set(state['consumer_guard']) != set(CONSUMERS):
        reject('The complete protected consumer scope is required')
    if not any(c['definition'] == 'PRIMARY KEY (exercise_id)' for c in state['constraints']):
        reject('Actual exercise identity primary key is required')
    columns = {c['name']: c for c in state['columns']}
    if not {'exercise_id', 'name', 'slug', 'published', 'equipment', 'setup', 'execution'} <= set(columns):
        reject('Schema cannot represent the approved exact setups; separate contract decision required')
    ids = [r['exercise_id'] for r in state['rows']]
    if len(ids) != len(set(ids)) or not PROTECTED <= set(ids):
        reject('Incomplete/duplicate inventory or protected rows absent')
    # Slug is a nullable legacy lookup label, not the primary identity. Existing
    # duplicate groups stay in the exact pinned inventory; prepare checks every
    # operation's lookup dependency instead of rewriting unrelated legacy rows.
    return columns


def slug_lookup_matches(rows, slug):
    """Collision detection only; never infer identity from a normalised label.

    The legacy importer trims slug references. Conservatively include Python
    whitespace and BOM edges, without lowercasing or fuzzy name matching.
    """
    def lookup_key(value):
        if not isinstance(value, str):
            return None
        previous = None
        while previous != value:
            previous, value = value, value.strip().strip('\ufeff')
        return value
    return [r for r in rows if lookup_key(r['slug']) == slug]


def prepare(snapshot, decisions, request_id):
    """Fresh target inventory supplies IDs. No stale 132-row next-ID guess."""
    request = approved_request()
    columns = validate_snapshot(snapshot)
    if not re.fullmatch(r'[A-Za-z0-9_-]{8,80}', request_id):
        reject('Choose a stable bounded operation request ID')
    if not isinstance(decisions, list) or len(decisions) != 3:
        reject('Exactly three explicit owner-reviewed decisions are required')
    state = snapshot['state']
    rows = state['rows']
    max_id = max((int(r['exercise_id'][3:]) for r in rows if re.fullmatch(r'EX-\d+', r['exercise_id'])), default=0)
    operations = []
    for intent, decision in zip(request['operations'], decisions):
        keys(decision, ('source_variant', 'action', 'reuse_id', 'slug', 'exact_setup_review_reference', 'reviewed_extra_fields', 'field_review_reference'))
        if decision['source_variant'] != intent['source_variant'] or not decision['exact_setup_review_reference']:
            reject('Exact setup/owner review is required; search/name similarity is not binding authority')
        if not isinstance(decision['slug'], str) or not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', decision['slug']):
            reject('Choose an explicit reviewed slug')
        slug_matches = slug_lookup_matches(rows, decision['slug'])
        content = intent['proposed_catalogue_content']
        fields = {'name': content['name'], 'equipment': ', '.join(content['equipment']),
                  'setup': content['setup_and_execution'], 'execution': content['setup_and_execution'],
                  'published': True}
        exact_matches = [r for r in rows if all(r.get(k) == v for k, v in fields.items())]
        if len(exact_matches) > 1:
            reject('Ambiguous exact setup matches')
        extra = decision['reviewed_extra_fields']
        if not isinstance(extra, dict) or any(k not in columns or k in fields or k in ('exercise_id', 'slug') for k in extra):
            reject('Unexpected/overriding reviewed catalogue field')
        if extra and not decision['field_review_reference']:
            reject('Unknown taxonomy/required fields need exact operator field review; never infer them from cues')
        fields.update(extra)
        if decision['action'] == 'reuse':
            found = [r for r in exact_matches if r['exercise_id'] == decision['reuse_id']]
            if len(found) != 1 or found[0]['exercise_id'] in PROTECTED:
                reject('Reuse must pin one exact verified distinct identity')
            row = found[0]
            if len(slug_matches) != 1 or slug_matches[0]['exercise_id'] != row['exercise_id']:
                reject('Ambiguous operation slug lookup; exact ID alone cannot authorise a shared lookup label')
            if any(row.get(k) != v for k, v in fields.items()) or row['slug'] != decision['slug']:
                reject('Reuse payload differs from reviewed identity')
            fields = row
        elif decision['action'] == 'create':
            if decision['reuse_id'] is not None or exact_matches:
                reject('An exact existing row must be explicitly reviewed; no duplicate allocation')
            max_id += 1
            fields.update(exercise_id=f'EX-{max_id:03d}', slug=decision['slug'])
            if slug_matches or any(r['exercise_id'] == fields['exercise_id'] for r in rows):
                reject('Allocated ID/slug collision')
            for c in columns.values():
                if c['nullable'] == 'NO' and c['default'] is None and c['name'] not in fields:
                    reject('Unknown required catalogue field needs exact review: ' + c['name'])
        else:
            reject('Only exact reuse or distinct creation is permitted')
        operations.append({'source_variant': intent['source_variant'], 'action': decision['action'],
                           'fields': fields, 'logging_contract': intent['programme_logging_contract'],
                           'exact_setup_review_reference': decision['exact_setup_review_reference'],
                           'field_review_reference': decision['field_review_reference']})
    if len({o['fields']['exercise_id'] for o in operations}) != 3 or len({o['fields']['slug'] for o in operations}) != 3:
        reject('Duplicate planned identities/slugs')
    return {'kind': 'm11_exact_catalogue_manifest_v1', 'target_ref': TARGET,
            'classification': snapshot['kind'], 'request_id': request_id,
            'operator_authorisation': snapshot['operator_authorisation'], 'audit_reference': snapshot['audit_reference'],
            'provenance': snapshot['provenance'], 'write_set_sha256': request['write_set_sha256'],
            'source_sha256': SOURCE_SHA, 'preflight': state, 'operations': operations,
            'preflight_raw': snapshot['raw_state'],
            'decisions': decisions, 'protected_ids': sorted(PROTECTED)}


def validate_manifest(manifest):
    keys(manifest, ('kind', 'target_ref', 'classification', 'request_id', 'operator_authorisation', 'audit_reference',
                    'provenance', 'write_set_sha256', 'source_sha256', 'preflight', 'preflight_raw', 'operations', 'decisions', 'protected_ids'))
    snapshot = {'kind': manifest['classification'], 'target_ref': manifest['target_ref'],
                'provenance': manifest['provenance'], 'operator_authorisation': manifest['operator_authorisation'],
                'audit_reference': manifest['audit_reference'], 'state': manifest['preflight'], 'raw_state': manifest['preflight_raw']}
    if prepare(snapshot, manifest['decisions'], manifest['request_id']) != manifest:
        reject('Manifest differs from the exact approved deterministic operation')


def literal(value):
    # SQL standard quoting, with standard_conforming_strings set explicitly.
    return "'" + encode(value).replace("'", "''") + "'::jsonb"


def seed(manifest):
    validate_manifest(manifest)
    pre = manifest['preflight']
    planned = [o for o in manifest['operations'] if o['action'] == 'create']
    ids = [o['fields']['exercise_id'] for o in planned]
    # All catalogue writers take RowExclusiveLock for INSERT; EXCLUSIVE conflicts
    # with it, including non-participating writers. Advisory locking is not used.
    checks = """
    IF (SELECT jsonb_build_object('database',current_database(),'role',current_user,
      'session_user',session_user,'system_identifier',(SELECT system_identifier::text FROM pg_control_system()),
      'server_addr',inet_server_addr()::text,'server_port',inet_server_port(),
      'ssl',(SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()))) IS DISTINCT FROM %s
      THEN RAISE EXCEPTION 'operator/target identity mismatch'; END IF;
    IF (SELECT jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable,'default',column_default) ORDER BY ordinal_position)
      FROM information_schema.columns WHERE table_schema='public' AND table_name='exercises_v2') IS DISTINCT FROM %s
      THEN RAISE EXCEPTION 'catalogue schema drift'; END IF;
    IF (SELECT coalesce(jsonb_agg(jsonb_build_object('name',conname,'definition',pg_get_constraintdef(oid)) ORDER BY conname),'[]'::jsonb)
      FROM pg_constraint WHERE conrelid='public.exercises_v2'::regclass) IS DISTINCT FROM %s
      THEN RAISE EXCEPTION 'constraint drift'; END IF;
    IF (SELECT jsonb_agg(indexdef ORDER BY indexname) FROM pg_indexes WHERE schemaname='public' AND tablename='exercises_v2') IS DISTINCT FROM %s
      THEN RAISE EXCEPTION 'index drift'; END IF;
    IF (SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY exercise_id),'[]'::jsonb) FROM public.exercises_v2 e
      WHERE NOT (exercise_id = ANY(ARRAY(SELECT jsonb_array_elements_text(%s))))) IS DISTINCT FROM %s
      THEN RAISE EXCEPTION 'protected pre-existing catalogue state drift'; END IF;
    """ % (literal(pre['identity']), literal(pre['columns']), literal(pre['constraints']), literal(pre['indexes']), literal(ids),
           literal([r for r in pre['rows'] if r['exercise_id'] not in ids]))
    # Snapshot all consumer digests in the same transaction, exclude concurrent
    # consumer writes while proving invariant (no athlete data is returned).
    for table in CONSUMERS:
        checks += "IF (SELECT jsonb_build_object('count',count(*),'digest',md5(coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text)::text,'null'))) FROM public.%s t) IS DISTINCT FROM %s THEN RAISE EXCEPTION 'protected consumer drift'; END IF;\n" % (table, literal(pre['consumer_guard'][table]))
    matches = []
    for op in planned:
        fields = op['fields']
        matches.append("(exercise_id = %s AND to_jsonb(e) @> %s)" % (sql_text(fields['exercise_id']), literal(fields)))
    predicate = ' OR '.join(matches) or 'false'
    insert = ''
    for op in planned:
        fields = op['fields']
        names = list(fields)
        if any(not re.fullmatch(r'[a-z_]+', k) for k in names):
            reject('Invalid catalogue column')
        insert += 'INSERT INTO public.exercises_v2 (%s) SELECT %s FROM jsonb_populate_record(NULL::public.exercises_v2,%s);\n' % (
            ','.join(names), ','.join(names), literal(fields))
    # No slug uniqueness assumption: explicitly recheck actual values under hold.
    collision = ' OR '.join('slug = %s' % sql_text(o['fields']['slug']) for o in planned) or 'false'
    delimiter = '$m11_' + sha(encode(manifest).encode()) + '$'
    generated = """BEGIN;
SET LOCAL standard_conforming_strings = on;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';
LOCK TABLE public.exercises_v2 IN EXCLUSIVE MODE;
%s
DO %s
DECLARE existing_count integer; exact_count integer;
BEGIN
%s
SELECT count(*) INTO existing_count FROM public.exercises_v2 WHERE exercise_id = ANY(ARRAY(SELECT jsonb_array_elements_text(%s)));
SELECT count(*) INTO exact_count FROM public.exercises_v2 e WHERE %s;
IF existing_count = 0 THEN
  IF EXISTS(SELECT 1 FROM public.exercises_v2 WHERE %s) THEN RAISE EXCEPTION 'slug collision'; END IF;
  %s
ELSIF existing_count <> %d OR exact_count <> %d THEN
  RAISE EXCEPTION 'partial/mismatched operation; reconcile same IDs';
END IF;
SET CONSTRAINTS ALL IMMEDIATE;
%s
IF (SELECT count(*) FROM public.exercises_v2 e WHERE %s) <> %d THEN RAISE EXCEPTION 'postcondition failed'; END IF;
END %s;
%s
COMMIT;
""" % ('\n'.join('LOCK TABLE public.%s IN SHARE MODE;' % t for t in sorted(CONSUMERS)),
         delimiter, checks, literal(ids), predicate, collision, insert, len(planned), len(planned), checks, predicate, len(planned), delimiter, state_sql())
    if generated.count(delimiter) != 2:
        reject('Unsafe operation delimiter')
    return generated


def sql_text(value):
    if not isinstance(value, str) or '\x00' in value or len(value) > 10000:
        reject('Invalid bounded SQL text value')
    return "'" + value.replace("'", "''") + "'"


def pinned(manifest_path, manifest_sha, seed_path, seed_sha):
    raw_manifest, raw_seed = Path(manifest_path).read_bytes(), Path(seed_path).read_bytes()
    if sha(raw_manifest) != manifest_sha or sha(raw_seed) != seed_sha:
        reject('Reviewed operation digest mismatch')
    manifest = load(manifest_path)
    validate_manifest(manifest)
    if seed(manifest).encode() != raw_seed:
        reject('Seed is not the exact data-only operation generated from the manifest')
    if raw_manifest != (encode(manifest) + '\n').encode():
        reject('Use the exact canonical manifest bytes produced by prepare')
    return manifest, raw_seed


def apply(db, manifest, raw_seed):
    validate_manifest(manifest)
    before_raw, before = inspect_state(db)
    if before['identity'] != manifest['preflight']['identity']:
        reject('Actual authenticated database/role/server differs before apply')
    raw = db.run(raw_seed.decode())
    after = json.loads(raw, object_pairs_hook=no_duplicates)
    verify_post(manifest, after)
    created = [o['fields']['exercise_id'] for o in manifest['operations'] if o['action'] == 'create']
    before_ids = {r['exercise_id'] for r in before['rows']}
    return {'status': 'EXACT_STATE_REPLAY_NOOP_AUDIT_REQUIRED' if set(created) <= before_ids else 'APPLIED',
            'before_raw': before_raw.decode(), 'after_raw': raw.decode(),
            'request_id': manifest['request_id'], 'audit_reference': manifest['audit_reference']}


def verify_post(manifest, after):
    pre = manifest['preflight']
    if after['identity'] != pre['identity'] or any(after[k] != pre[k] for k in ('columns', 'constraints', 'indexes', 'consumer_guard')):
        reject('Postcheck identity/schema/protected consumer mismatch')
    creates = [o for o in manifest['operations'] if o['action'] == 'create']
    ids = {o['fields']['exercise_id'] for o in creates}
    if [r for r in after['rows'] if r['exercise_id'] not in ids] != [r for r in pre['rows'] if r['exercise_id'] not in ids]:
        reject('Pre-existing catalogue rows changed')
    for op in manifest['operations']:
        found = [r for r in after['rows'] if r['exercise_id'] == op['fields']['exercise_id']]
        if len(found) != 1 or any(found[0].get(k) != v for k, v in op['fields'].items()):
            reject('Exact setup payload readback mismatch')
    if len(after['rows']) != len(pre['rows']) + len(creates):
        reject('Unexpected catalogue delta')


def retain(db, manifest, raw_seed, apply_receipt, directory):
    keys(apply_receipt, ('status', 'before_raw', 'after_raw', 'request_id', 'audit_reference'))
    if apply_receipt['request_id'] != manifest['request_id'] or apply_receipt['audit_reference'] != manifest['audit_reference']:
        reject('Apply receipt is for another operation')
    applied = json.loads(apply_receipt['after_raw'], object_pairs_hook=no_duplicates)
    verify_post(manifest, applied)
    raw, readback = inspect_state(db)
    verify_post(manifest, readback)
    # DB-generated/default/NULL fields must also match exact independent readback.
    if applied['rows'] != readback['rows']:
        reject('Independent raw row readback changed')
    out = Path(directory)
    out.mkdir(exist_ok=False)
    files = {'manifest.json': (encode(manifest) + '\n').encode(), 'seed.sql': raw_seed,
             'preflight.raw.json': manifest['preflight_raw'].encode(),
             'apply.json': (encode(apply_receipt) + '\n').encode(), 'readback.raw.json': raw}
    for name, body in files.items():
        write_new(out / name, body)
    receipt = {'kind': 'm11_catalogue_retention_receipt_v1', 'target_ref': TARGET,
               'classification': manifest['classification'], 'request_id': manifest['request_id'],
               'audit_reference': manifest['audit_reference'], 'identity': readback['identity'],
               'captured_at': readback['captured_at'], 'source_sha256': SOURCE_SHA,
               'query_sha256': sha(state_sql().encode()),
               'write_set_sha256': manifest['write_set_sha256'],
               'files_sha256': {n: sha(b) for n, b in files.items()},
               'rows_sha256': sha(encode(readback['rows']).encode()),
               'result_rows': {o['source_variant']: next(r for r in readback['rows'] if r['exercise_id'] == o['fields']['exercise_id']) for o in manifest['operations']},
               'hosted_retention': manifest['classification'] == 'AUTHENTICATED_OPERATOR_PREFLIGHT',
               'authority': 'Operator audit plus independent authenticated readback required; local file hashes alone are not tamper-proof hosted provenance'}
    write_new(out / 'receipt.json', (encode(receipt) + '\n').encode())
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('prepare', 'apply', 'verify-retain'))
    parser.add_argument('--out', required=True)
    parser.add_argument('--snapshot')
    parser.add_argument('--decisions')
    parser.add_argument('--request-id')
    parser.add_argument('--manifest')
    parser.add_argument('--manifest-sha256')
    parser.add_argument('--seed')
    parser.add_argument('--seed-sha256')
    parser.add_argument('--service', help='Provisioned libpq service alias, never a DSN/password')
    parser.add_argument('--expected-target')
    parser.add_argument('--apply-receipt')
    args = parser.parse_args()
    if args.command == 'prepare':
        if not args.snapshot:
            write_new(args.out, (encode(approved_request()) + '\n').encode())
            return
        manifest = prepare(load(args.snapshot), load(args.decisions), args.request_id)
        out = Path(args.out)
        out.mkdir(exist_ok=False)
        write_new(out / 'manifest.json', (encode(manifest) + '\n').encode())
        write_new(out / 'seed.sql', seed(manifest).encode())
        write_new(out / 'SHA256.json', (encode({n: sha((out / n).read_bytes()) for n in ('manifest.json', 'seed.sql')}) + '\n').encode())
        return
    if args.expected_target != TARGET or not args.service:
        reject('Separately authorised exact target and normal operator service connection required')
    manifest, raw_seed = pinned(args.manifest, args.manifest_sha256, args.seed, args.seed_sha256)
    if manifest['classification'] != 'AUTHENTICATED_OPERATOR_PREFLIGHT':
        reject('Synthetic rehearsal manifests cannot execute through the operational CLI')
    db = Psql(args.service, role=manifest['operator_authorisation']['role'])
    if args.command == 'apply':
        # Refuse an existing receipt path before the DB transaction.
        if Path(args.out).exists(): reject('Preserve prior receipt; use a new acknowledgement file for this same pinned operation')
        receipt = apply(db, manifest, raw_seed)
        write_new(args.out, (encode(receipt) + '\n').encode())
    else:
        retain(db, manifest, raw_seed, load(args.apply_receipt), args.out)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, TypeError, KeyError, OSError) as error:
        # Errors contain bounded validation text only, never psql stderr/env.
        print('M1.1 refused: ' + (str(error) if isinstance(error, ValueError) else type(error).__name__), file=sys.stderr)
        sys.exit(2)
