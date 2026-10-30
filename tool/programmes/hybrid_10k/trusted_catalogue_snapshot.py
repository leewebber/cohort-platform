"""Validate this founder-authorised bounded snapshot; never fetch or publish.

This is caller-supplied legacy v1/v2 catalogue evidence, not a global catalogue
seed, identity bridge mutation or canonical ExerciseDefinition version producer.
"""
import hashlib
import json
from pathlib import Path

DIRECT_MATCHES = {'pull_up_bodyweight': 'EX-053', 'db_lateral_raise': 'EX-044',
                  'bench_supported_db_row': 'EX-038'}
DIRECTORY = Path('docs/checkpoints/m11_trusted_catalogue_lookup')
PINS = {
    'PROJECT_STATUS.json': 'f7d10058eeab9d0acc110b718c640670ad95d0dd77fffe951ca057fbb5a8c274',
    'LOOKUP_RECEIPT.json': '8ab1b898c2103a1c83836a1f1c0e9b9e0329b5a66502b530aab8a5f9023a0872',
    'CATALOGUE_SELECT.sql': '98952f4893bb1a733785c44df85f0fc8176326ddb8f0228b9c5a5032a9cd46aa',
    'CATALOGUE_ROWS.raw.json': '434bb9d83b109571ae136353b61fd78ca172aeb3409668ba908d09790690ef8c',
}
REF = 'otnhhdxstdnwccehacku'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def load_snapshot(root):
    folder = root / DIRECTORY
    for name, expected in PINS.items():
        if digest((folder / name).read_bytes()) != expected:
            raise ValueError('trusted_snapshot_integrity_mismatch:' + name)
    status = json.loads((folder / 'PROJECT_STATUS.json').read_bytes())
    receipt = json.loads((folder / 'LOOKUP_RECEIPT.json').read_bytes())
    raw = json.loads((folder / 'CATALOGUE_ROWS.raw.json').read_bytes())
    if (status['project']['ref'] != REF or status['project']['status'] != 'ACTIVE_HEALTHY'
            or status['http_status'] != 200 or not status['configured_target_matches']):
        raise ValueError('trusted_snapshot_project_mismatch')
    if (receipt['target_ref'] != REF or receipt['result'] != 'BOUNDED_SELECT_SUCCEEDED'
            or receipt['operation'] != f'POST /v1/projects/{REF}/database/query/read-only'
            or receipt['http_status'] != 201 or receipt['row_cap_reached']
            or receipt['raw_response_sha256'] != PINS['CATALOGUE_ROWS.raw.json']
            or receipt['sql_sha256'] != PINS['CATALOGUE_SELECT.sql']
            or receipt['status_evidence_sha256'] != PINS['PROJECT_STATUS.json']):
        raise ValueError('trusted_snapshot_query_provenance_mismatch')
    rows = {r['exercise_id']: r for r in raw}
    if len(raw) != 6 or len(rows) != 6 or set(rows) != {'EX-026','EX-037','EX-038','EX-044','EX-053','EX-090'}:
        raise ValueError('trusted_snapshot_scope_mismatch')
    # Curated matches require actual equipment/pattern/cue evidence and publication,
    # not normalised display-name discovery. NULL source fields remain NULL.
    expectations = {
        'EX-053': ('Pull Up', 'Vertical Pull', {'Pull-up Bar'}, 'dead hang'),
        'EX-044': ('Lateral Raise', 'Vertical Push', {'One Dumbbell','Two Dumbbells'}, 'control down'),
        'EX-038': ('Single-Arm Dumbbell Row', 'Horizontal Pull', {'One Dumbbell','Bench'}, 'control the lower'),
    }
    for identity, (name, pattern, equipment, cue) in expectations.items():
        row = rows[identity]
        if (row['published'] is not True or row['name'] != name
                or row['movement_pattern'] != pattern
                or {s.strip() for s in row['equipment'].split(',')} != equipment
                or cue not in row['coaching_cues'].lower()):
            raise ValueError('trusted_snapshot_exact_match_mismatch:' + identity)
    return rows, receipt


def row_evidence(root):
    rows, receipt = load_snapshot(root)
    return {
        identity: {
            'catalogue_row': rows[identity],
            'row_sha256': digest(json.dumps(rows[identity], sort_keys=True, ensure_ascii=False,
                                           separators=(',', ':')).encode()),
            'classification': 'AUTHENTICATED_BOUNDED_LEGACY_ROW_SNAPSHOT',
            'source_path': str(DIRECTORY / 'CATALOGUE_ROWS.raw.json'),
            'source_sha256': PINS['CATALOGUE_ROWS.raw.json'],
            'lookup_receipt_path': str(DIRECTORY / 'LOOKUP_RECEIPT.json'),
            'lookup_receipt_sha256': PINS['LOOKUP_RECEIPT.json'],
            'target_ref': REF, 'observed_at_utc': receipt['captured_at_utc'],
            'published_state_observed': rows[identity]['published'],
            'canonical_definition_version': None, 'publication_event': None,
            'global_catalogue_seed': False,
        }
        for identity in DIRECT_MATCHES.values()
    }
