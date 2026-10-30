#!/usr/bin/env python3
"""Bounded Hybrid 10K source reconciliation. No database/network/publication path.

Immutable 28 October source + founder clarification -> review-only general draft.
Run from the repository root, with --check for byte-identical regeneration.
"""
import argparse
import collections
import copy
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import uuid

ROOT = Path(__file__).resolve().parents[3]
DEST = ROOT / 'docs/programmes/hybrid_10k/general_draft_2026_10_30'
OLD = ROOT / 'docs/programmes/hybrid_10k/lee_draft_2026_10_28'
BASE = '0f0c40dae54c87e7b3f739b205c0fe6b8edf847a'
WAVE = 'supabase/migrations/20260724140000_founder_exercise_library_wave1.sql'
WAVE_HASH = '22a2683b81d09e071b99adda3c120dff06cb6410fcc4a2b53029beffca73d0c8'
CLARIFICATION_HASH = '8e16f59f8963efbc0db40b0c4b0532dcc4104e52ca6af391a604fa17cb5a48eb'
CSV_PATH = Path('/Users/leewebber/Documents/COHORT PERFORMANCE/Cohort Field Manual/09 Exports/CSV/Cohort_Exercise_Database_V1.csv')
spec = importlib.util.spec_from_file_location('retained_source_audit', Path(__file__).with_name('audit_source.py'))
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def replacements(week, count, work_minutes, recovery_seconds, category):
    return {
        'title': {4: 'Consolidation threshold', 8: 'Peak 10K specificity',
                  9: 'Reduced-volume 10K specificity', 10: 'Taper sharpening'}[week],
        'kind': 'timed_quality',
        'steps': [
            {'action': 'Easy warm-up running', 'duration_minutes': 10, 'effort': 'EASY'},
            {'action': 'Relaxed acceleration', 'repetitions': 3, 'work_seconds': 20,
             'work_effort': 'RELAXED_ACCELERATION', 'recovery_seconds': 40,
             'recovery_effort': 'VERY_EASY', 'recovery_after_last': True},
            {'action': 'Threshold-labelled work' if category == 'threshold' else 'Estimated-current-10K work',
             'repetitions': count, 'work_minutes': work_minutes,
             'work_effort': 'THRESHOLD' if category == 'threshold' else 'TEN_K',
             'recovery_seconds': recovery_seconds, 'recovery_effort': 'VERY_EASY',
             'recovery_after_last': False},
            {'action': 'Very easy running or walking cooldown', 'duration_minutes': 5,
             'effort': 'VERY_EASY_RUN_OR_WALK'},
        ],
        'prescribed_total_running_minutes': None,
        'prescribed_programmed_duration_seconds': 780 + count * work_minutes * 60 + (count - 1) * recovery_seconds + 300,
        'work_distance_metres': None,
        'content_status': 'FOUNDER_SELECTED_REPLACEMENT_2026_10_30',
        'quality_category': category,
        'notes': ['Founder-selected timed replacement. Warm-up exactly 13 minutes; no recovery after final work repetition.',
                  'The 5-minute cooldown permits walking: it is included in programmed duration, but walking is not running volume.',
                  'No fixed pace for relaxed accelerations or easy recoveries. Explicit M2.3 source selection and acceptance required.',
                  'No extra mandatory walking phase is inserted before/after this exact replacement body.'],
    }


def row_evidence():
    raw = (ROOT / WAVE).read_bytes()
    assert sha(raw) == WAVE_HASH, 'Pinned trusted catalogue declaration changed'
    columns = ['exercise_id', 'name', 'slug', 'published', 'category', 'movement_pattern',
               'equipment', 'primary_muscles', 'primary_capability', 'loading_options', 'purpose']
    records = {}
    for line in raw.decode().splitlines():
        match = re.match(r"\s*\(('EX-\d+'.*)\)[,;]?\s*$", line)
        if not match:
            continue
        values = next(csv.reader([match[1]], quotechar="'", skipinitialspace=True))
        assert len(values) == len(columns)
        row = dict(zip(columns, values))
        row['published'] = row['published'] == 'true'
        if row['exercise_id'] in {'EX-073', 'EX-078', 'EX-095', 'EX-101', 'EX-116'}:
            assert row['published'] is True
            records[row['exercise_id']] = {
                'catalogue_row': row, 'row_sha256': sha(encode(row).encode()),
                'row_sql': line.strip(), 'source_path': WAVE, 'source_sha256': WAVE_HASH,
                'snapshot_git_revision': BASE,
                'classification': 'VERIFIED_LOCAL_V1_V2_REPOSITORY_ROW_DECLARATION',
                'canonical_definition_version': None, 'publication_event': None,
                'hosted_state': 'NOT_VERIFIED',
            }
    assert len(records) == 5
    # Retained historical export is evidence for candidates only, never a runtime seed.
    if CSV_PATH.exists():
        csv_bytes = CSV_PATH.read_bytes()
        selected = [r for r in csv.DictReader(csv_bytes.decode('utf-8-sig').splitlines())
                    if r['Exercise ID'] in {'EX-026', 'EX-037', 'EX-038', 'EX-044', 'EX-053'}]
        candidate_evidence = {'path': str(CSV_PATH), 'sha256': sha(csv_bytes), 'rows': selected,
                              'classification': 'HISTORICAL_EXPORT_CANDIDATE_EVIDENCE_ONLY',
                              'runtime_seed': False, 'canonical_definition_versions': None}
    else:
        # Reproduction needs only the already pinned candidate evidence, not external access.
        candidate_evidence = json.loads((DEST / 'IDENTITY_INTAKE.json').read_text())['candidate_export']
    return records, candidate_evidence


def variants(records):
    def item(key, label, state, identity=None, reason='', rejected=None):
        return {'variant_key': key, 'authored_variant': label, 'status': state,
                'verified_local_exercise_id': identity if state.startswith('VERIFIED') else None,
                'candidate_exercise_id': identity if state == 'CANDIDATE_ONLY' else None,
                'reason': reason, 'rejected_substitutions': rejected or [],
                'evidence': records.get(identity), 'canonical_definition_version': None,
                'publication_event': None}
    return [
        item('reverse_lunge_db', 'Dumbbell reverse lunge', 'MISSING_EXACT_LOCAL_ROW', reason='EX-026 export is bodyweight/None equipment.', rejected=['EX-025 walking lunge', 'EX-026 bodyweight reverse lunge']),
        item('pull_up_bodyweight', 'Bodyweight pull-up option', 'CANDIDATE_ONLY', 'EX-053', 'Approved bridge and historical export; exact source grip/branch and supplied runtime row remain unbound.'),
        item('pull_up_weighted', 'Weighted pull-up option', 'VERIFIED_LOCAL_OPTION_NOT_SELECTED', 'EX-095', 'Exact published local repository row; source allows added load but no option is selected for its slots.'),
        item('pull_up_foot_assisted', 'Secure foot-assisted pull-up option', 'MISSING_EXACT_LOCAL_ROW', reason='Do not map assistance to an unassisted or weighted identity.'),
        item('pull_up_machine_assisted', 'Machine-assisted pull-up option', 'MISSING_EXACT_LOCAL_ROW', reason='Separate from foot assistance; no exact retained runtime row.'),
        item('db_overhead_press', 'Dumbbell overhead press; comfortable range, neutral grip allowed', 'CANDIDATE_ONLY', 'EX-037', 'Historical DB strict-press lead; source does not fix standing/seated or demonstrate identity equivalence.', ['EX-088 barbell strict press', 'EX-036 dumbbell push press']),
        item('db_row_a', 'One-arm dumbbell row, Monday support unspecified', 'CANDIDATE_ONLY', 'EX-038', 'Historical single-arm DB/bench row; Monday support/setup remains unbound.'),
        item('db_row_b', 'One-arm dumbbell row, free hand supported on bench', 'CANDIDATE_ONLY', 'EX-038', 'Historical export is compatible evidence; no exact retained runtime catalogue row is promoted from that export.', ['EX-090 chest-supported bilateral row', 'EX-142 one-arm cable row']),
        item('db_lateral_raise', 'Controlled dumbbell lateral raise', 'CANDIDATE_ONLY', 'EX-044', 'Historical export specifies dumbbells; retain as a candidate, not a published definition version.', ['EX-138 cable lateral raise']),
        item('side_plank', 'Per-side bodyweight side plank', 'VERIFIED_LOCAL_MATCH', 'EX-116', 'Exact unilateral bodyweight/time row; no front-plank substitution.'),
        item('back_squat', 'Barbell back squat', 'VERIFIED_LOCAL_MATCH', 'EX-073', 'Exact barbell squat row and accepted explicit bridge.'),
        item('barbell_rdl', 'Barbell Romanian deadlift', 'VERIFIED_LOCAL_MATCH', 'EX-078', 'Exact barbell hinge row and accepted explicit bridge.'),
        item('flat_db_bench', 'Flat dumbbell bench press', 'MISSING_EXACT_LOCAL_ROW', reason='No exact local flat DB bench row found.', rejected=['EX-083 barbell bench', 'EX-084 incline DB press', 'EX-046 DB floor press']),
        item('db_farmer_carry', 'Two-dumbbell walking farmer carry', 'VERIFIED_LOCAL_MATCH', 'EX-101', 'Bilateral carry row explicitly permits dumbbells and time capture.'),
        item('single_leg_db_calf', 'Standing single-leg dumbbell calf raise', 'MISSING_EXACT_LOCAL_ROW', reason='No unilateral DB-specific row found.', rejected=['EX-125 bilateral standing machine/step calf raise', 'EX-126 seated calf raise']),
        item('reverse_crunch', 'Controlled reverse crunch / pelvic curl', 'MISSING_EXACT_LOCAL_ROW', reason='No exact retained reverse-crunch identity; no generic crunch substitute.'),
    ]


def variant_key(label, day):
    return {'DB reverse lunge': 'reverse_lunge_db', 'Pull-up': 'pull_up_choice',
            'DB overhead press': 'db_overhead_press',
            'One-arm DB row': 'db_row_a' if day == 1 else 'db_row_b',
            'DB lateral raise': 'db_lateral_raise', 'Side plank': 'side_plank',
            'Barbell back squat': 'back_squat', 'Barbell Romanian deadlift': 'barbell_rdl',
            'DB bench press': 'flat_db_bench', 'DB farmer carry': 'db_farmer_carry',
            'Standing single-leg DB calf raise': 'single_leg_db_calf', 'Reverse crunch': 'reverse_crunch'}[label]


def prescription(exercise):
    raw = exercise['repetitions_or_duration']
    per_side = '/side' in raw or '/leg' in raw
    base = re.sub(r'/(side|leg)$', '', raw)
    if 'sec' in base:
        reps = {'type': 'duration', 'text': raw}
        number = re.fullmatch(r'(\d+) sec', base)
        if number:
            reps['duration_seconds'] = int(number[1])
    elif '–' in base or '-' in base:
        low, high = map(int, re.split('[–-]', base))
        reps = {'type': 'range', 'min_reps': low, 'max_reps': high}
    else:
        reps = {'type': 'exact', 'exact_reps': int(base)}
    label = exercise['exercise']
    tempo = ('~2 sec up, 1 sec top pause, ~2 sec down' if 'calf raise' in label else
             'Controlled both ways' if 'lateral raise' in label else
             'Normal walking; tall posture; no running' if 'carry' in label else
             'Hold position; stop before posture loss' if 'plank' in label else
             '~2 sec lowering; no forced pause; purposeful lift')
    out = {'sets': exercise['sets'], 'reps': reps, 'per_side': per_side,
           'tempo': tempo,
           'coach_cue': exercise['notes'],
           'authored_details': {'source_occurrence_id': exercise['exercise_occurrence_id'],
                                'source_repetitions_or_duration': raw,
                                'source_rir': exercise['rir'],
                                'source_tempo_reference': exercise['tempo'],
                                'source_rest_seconds': exercise['rest_seconds']}}
    if 'DB' in label or 'Barbell' in label or label == 'Pull-up':
        out['load'] = {'type': 'athleteSelected'}
    rest = list(map(int, re.split('[–-]', exercise['rest_seconds'])))
    out['rest_seconds' if len(rest) == 1 else 'rest_seconds_range'] = rest[0] if len(rest) == 1 else rest
    rir = exercise['rir']
    if rir.isdigit():
        out['rir_range'] = [int(rir), int(rir)]
    elif re.fullmatch(r'\d+[–-]\d+', rir):
        out['rir_range'] = list(map(int, re.split('[–-]', rir)))
    elif rir == 'at least 3':
        out['coach_cue'] += ' At least 3 RIR; no invented upper RIR bound.'
    elif rir != 'N/A':
        raise AssertionError('Unknown RIR expression')
    if 'DB' in exercise['exercise']:
        out['performance_capture'] = {'load_unit': 'kg', 'load_label': 'External load per dumbbell'}
    elif 'Barbell' in exercise['exercise']:
        out['performance_capture'] = {'load_unit': 'kg', 'load_label': 'Total barbell load'}
    return out


def build():
    assert sha((OLD / 'SOURCE.md').read_bytes()) == 'd932e7103b03036e136249e0ab35d48378b0175c75feba84282386fc6ca00f40'
    assert sha((DEST / 'FOUNDER_CLARIFICATION.md').read_bytes()) == CLARIFICATION_HASH, 'Founder source selection changed; re-review the exact recipe'
    source = copy.deepcopy(json.loads((OLD / 'CALENDAR.json').read_text()))
    assert source == json.loads(legacy.build()['CALENDAR.json']), 'Retained source extraction changed'
    source.update(source_schema='hybrid10k-general-review/1', programme_id='HYBRID10K-GENERAL-DRAFT',
                  title='General Hybrid 10K PB programme — reconciled draft',
                  content_status='DRAFT_EXCEPT_FOUR_FOUNDER_SELECTED_RUN_REPLACEMENTS',
                  scope='Already-fit competent runner; Lee-specific adjustment remains separate',
                  in_programme_5k_test=False,
                  shared_rules_location='GENERAL_GUIDANCE.md and FOUNDER_CLARIFICATION.md in this source directory',
                  source_calendar_dates='Illustrative retained calendar, not assignment/start authority')
    selected = {4: (4, 5, 90, 'threshold'), 8: (3, 9, 120, '10k_specific'),
                9: (3, 6, 120, '10k_specific'), 10: (3, 2, 120, '10k_specific')}
    discrepancies = []
    for s in source['sessions']:
        s['content_status'] = 'RETAINED_PROPOSED_DETAILS_NOT_BLANKET_APPROVED'
        if s['type'] == 'running':
            # Remove personal travel/treadmill deployment assumptions from general notes.
            s['notes'] = [n for n in s['notes'] if 'Treadmill until' not in n]
        if s['day'] == 2 and s['week'] in selected:
            old_steps = copy.deepcopy(s['steps'])
            s.update(replacements(s['week'], *selected[s['week']]))
            discrepancies.append({'source_session_id': s['session_id'], 'previous_steps': old_steps,
                                  'resolution': 'EXPLICIT_FOUNDER_SELECTED_TIMED_REPLACEMENT',
                                  'programmed_seconds': s['prescribed_programmed_duration_seconds']})
        if s['week'] == 10 and s['day'] == 4:
            shoulder = copy.deepcopy(next(e for x in source['sessions'] if x['week'] == 10 and x['day'] == 1 for e in x.get('exercises', []) if e['exercise'] == 'DB overhead press'))
            row = copy.deepcopy(next(e for x in source['sessions'] if x['week'] == 9 and x['day'] == 4 for e in x.get('exercises', []) if e['exercise'] == 'One-arm DB row'))
            for index, e in enumerate([shoulder, row], 1):
                e.update(exercise_occurrence_id=f'W10-B-E{index:02}', sets=2, rir='at least 3')
                e['notes'] += ' Comfortable upper-body work only; at least 3 RIR; no lower-body lifting.'
            s.update(type='strength', title='Upper-body taper', exercises=[shoulder, row],
                     expected_duration_minutes=None, content_status='FOUNDER_SELECTED_STRUCTURE_DOSES_RETAINED',
                     instructions=['Upper-body preparation only; retain comfortable pressing/rowing, two sets each, at least 3 RIR. No lower-body lifting.',
                                   'Repetition ranges and 90-second rests retained from the existing press/Thursday row prescriptions; not new blanket approval.'])
            discrepancies.append({'source_session_id': s['session_id'], 'previous_type': 'rest',
                                  'resolution': 'UPPER_BODY_THURSDAY_RESTORED_2_SETS_EACH_MINIMUM_3_RIR'})
    for w in source['weeks']:
        if w['week'] == 1: w['focus'] = 'Retained proposed opening doses; general-plan suitability pending review'
        if w['week'] == 2: w['focus'] = 'Retained proposed opening progression; no personal travel variant'
        if w['week'] == 3: w['focus'] = 'First controlled threshold session'
        if w['week'] == 4: w['focus'] = 'Consolidation threshold; no in-programme 5K test'
    records, candidate_export = row_evidence()
    variant_records = variants(records)
    by_variant = {v['variant_key']: v for v in variant_records}
    bindings = []
    for s in source['sessions']:
        for e in s.get('exercises', []):
            key = variant_key(e['exercise'], s['day'])
            v = by_variant.get(key)
            identity = v['verified_local_exercise_id'] if v and v['status'] == 'VERIFIED_LOCAL_MATCH' else None
            bindings.append({'session_id': s['session_id'], 'source_occurrence_id': e['exercise_occurrence_id'],
                             'variant_key': key, 'exercise_id': identity,
                             'intake_status': 'VERIFIED_LOCAL_MATCH' if identity else 'UNRESOLVED_NO_SUBSTITUTION',
                             'prescription': prescription(e)})
    runs, audit_runs = [], []
    for s in source['sessions']:
        if s['type'] != 'running': continue
        phases = legacy.expand_run(s)
        fixed = sum(p['seconds'] or 0 for p in phases)
        distance = sum(p['metres'] or 0 for p in phases)
        walking_option = 300 if s['week'] in selected and s['day'] == 2 else 0
        if s.get('prescribed_programmed_duration_seconds') is not None:
            assert fixed == s['prescribed_programmed_duration_seconds']
        elif not distance:
            assert fixed == s['prescribed_total_running_minutes'] * 60
        steps = []
        for p in phases:
            action = p['action'].lower()
            role = ('warm_up' if 'warm-up' in action else 'cool_down' if 'cooldown' in action
                    else 'recovery' if p['effort'] in {'RECOVERY', 'VERY_EASY'} else 'work')
            if p['effort'] == 'EASY' and role == 'work':
                target = {'kind': 'heart_rate_zone_ref', 'zone_ref': 'athlete_confirmed_zone_2'}
            elif p['effort'] in {'THRESHOLD', 'TEN_K'}:
                target = {'kind': 'alpha_quality_pace_v1', 'category': 'threshold' if p['effort'] == 'THRESHOLD' else '10k_specific'}
            elif s['week'] in selected and s['day'] == 2:
                target = {'kind': 'none'}
            else:
                target = legacy.target(p['effort'])
            steps.append({'kind': 'atomic', 'step_id': p['step_id'], 'role': role,
                          'duration': {'kind': 'time', 'milliseconds': p['seconds'] * 1000} if p['seconds'] is not None else {'kind': 'distance', 'millimetres': p['metres'] * 1000},
                          'target': target, 'label': p['action'],
                          'notes': f"Authored effort: {p['effort']}. " + legacy.EFFORT_NOTES.get(p['effort'], '')})
        body = {'schema_version': 1, 'workout_id': s['session_id'], 'title': s['title'],
                'notes': 'General draft; primary EASY work uses confirmed Zone 2. Quality requires explicit M2.3 selection/review/acceptance. No automatic fallback. ' + ' '.join(s['notes']),
                'steps': steps}
        runs.append({'source_session_id': s['session_id'], 'source_week': s['week'], 'source_day': s['day'],
                     'fixed_seconds': fixed, 'distance_metres': distance,
                     'running_fixed_seconds_range': [fixed - walking_option, fixed],
                     'content_status': s['content_status'], 'workout': body})
        audit_runs.append({k: v for k, v in runs[-1].items() if k != 'workout'})
    counts = dict(collections.Counter(s['type'] for s in source['sessions']))
    assert counts == {'strength': 20, 'running': 40, 'rest': 10}
    assert len({s['session_id'] for s in source['sessions']}) == 70
    assert len({e['exercise_occurrence_id'] for s in source['sessions'] for e in s.get('exercises', [])}) == 124
    assert sum(r['distance_metres'] > 0 for r in runs) == 1
    assert runs[-1]['source_session_id'] == 'LW10K-W10-D07' and runs[-1]['distance_metres'] == 10000
    weeks = []
    for w in source['weeks']:
        rows = [r for r in runs if r['source_week'] == w['week']]
        weeks.append({**w, 'programmed_fixed_seconds': sum(r['fixed_seconds'] for r in rows),
                      'running_fixed_seconds_range': [sum(r['running_fixed_seconds_range'][i] for r in rows) for i in [0, 1]],
                      'distance_ended_metres': sum(r['distance_metres'] for r in rows)})
    schedule = copy.deepcopy(json.loads((OLD / 'SCHEDULE_CANDIDATE.json').read_text()))
    schedule['programme'].update(lineage_code='HYBRID10K-GENERAL-DRAFT', name=source['title'],
                                 description='Reconciled general draft; four explicitly founder-selected timed replacements, other detailed content pending approval.')
    new_id = 'LW10K-W10-D04'
    schedule['sessions'].append({'session_key': new_id, 'protocol_id': new_id + '-DRAFT-R1',
                                 'session_lineage_id': str(uuid.uuid5(uuid.NAMESPACE_URL, 'HYBRID10K-GENERAL-DRAFT/' + new_id)),
                                 'revision_number': 1, 'title': 'Upper-body taper'})
    for w in schedule['weeks']:
        w['title'] = source['weeks'][w['week_number'] - 1]['focus']
        for d in w['days']:
            s = next(s for s in source['sessions'] if s['week'] == w['week_number'] and s['day'] == d['day_order'])
            d['title'] = s['title']
            if w['week_number'] == 10 and d['day_order'] == 4:
                d.update(day_type='training', slots=[{'slot_key': new_id, 'session_order': 1, 'session_key': new_id,
                                                     'display_title': s['title'], 'progression': {'prescription_summary': 'Two comfortable sets each retained upper-body press/row, at least 3 RIR; no lower-body lifting.'}}])
            for slot in d['slots']:
                slot['display_title'] = s['title']
                if s['session_id'] != new_id:
                    slot['progression']['prescription_summary'] = 'Reconciled general draft; see current SOURCE.json, GENERAL_GUIDANCE.md and founder-selected replacements. No automatic progression.'
            for ref in schedule['sessions']:
                if ref['session_key'] == s['session_id']: ref['title'] = s['title']
    audit = {'status': 'RECONCILED_GENERAL_DRAFT_NOT_PUBLISHED', 'base': BASE,
             'founder_clarification_sha256': sha((DEST / 'FOUNDER_CLARIFICATION.md').read_bytes()),
             'original_source_sha256': sha((OLD / 'SOURCE.md').read_bytes()),
             'counts': counts, 'timed_runs': 39, 'distance_runs': 1,
             'strength_occurrences': len(bindings), 'strength_work_sets': sum(e['sets'] for s in source['sessions'] for e in s.get('exercises', [])),
             'locally_verified_bound_occurrences': sum(b['exercise_id'] is not None for b in bindings),
             'weeks': weeks, 'running_sessions': audit_runs, 'resolved_discrepancies': discrepancies,
             'rules': ['alpha_5k_8w_riegel_1_06_v1', 'alpha_manual_threshold_pm2_v1', 'authored_rpe_v1'],
             'explicit_scalar_rpe_fallbacks': [], 'automatic_fallback': False,
             'garmin_facts': {'watch': 'Forerunner 255', 'developer_application': 'NOT_SUBMITTED',
                              'firmware': None, 'connect_platform_version': None, 'hr_source': None,
                              'authority': 'Founder supplied 2026-10-30; no device/API verification'}}
    intake = {'scope': 'LOCAL_PRIVATE_V1_V2_IDENTITY_INTAKE_ONLY_NOT_V3_OR_HOSTED_AUTHORITY',
              'repository_rows': records, 'candidate_export': candidate_export,
              'variants': variant_records, 'occurrences': bindings,
              'verified_matches_do_not_create': ['canonical definition versions', 'publication events', 'current hosted state', 'content approval']}
    review = ['# General Hybrid 10K — reconciled ordered draft', '',
              'Four replacement runs are founder-selected. Remaining detailed prescriptions are not blanket approved.',
              'General fit-runner PB scope; Lee-specific return/travel variants remain separate in the immutable older source.', '',
              '| Week | Programmed minutes | Running-minute bounds | Distance work |', '|---|---:|---:|---:|']
    def minutes(seconds):
        return f'{seconds // 60}:{seconds % 60:02}'
    for w in weeks:
        suffix = ' + elapsed 10K' if w['distance_ended_metres'] else ''
        review.append(f"| {w['week']} | {minutes(w['programmed_fixed_seconds'])}{suffix} | {minutes(w['running_fixed_seconds_range'][0])}–{minutes(w['running_fixed_seconds_range'][1])}{suffix} | {w['distance_ended_metres']} m |")
    review += ['', 'The four selected runs include a 5-minute running-or-walking cooldown; walking is not counted as running volume. No pace-derived time replaces distance. Gym estimates and discretionary preparation/transitions do not establish exact weekly elapsed training time.', '']
    for s in source['sessions']:
        review += [f"## {s['session_id']} · week {s['week']} day {s['day']} · {s['title']}", '', f"Status: {s['content_status']}", '']
        if s['type'] == 'running':
            row = next(r for r in runs if r['source_session_id'] == s['session_id'])
            for i, p in enumerate(row['workout']['steps'], 1):
                dur = p['duration']; dose = f"{dur['milliseconds'] // 1000} sec" if dur['kind'] == 'time' else f"{dur['millimetres'] // 1000} m, distance ended"
                review.append(f"{i}. {p['step_id']} {p['label']} — {dose}; {json.dumps(p['target'], ensure_ascii=False)}. {p['notes']}")
            review += ['', f"Programmed duration: {minutes(row['fixed_seconds'])}" + (' + actual elapsed 10K.' if row['distance_metres'] else '.'), *s['notes']]
        elif s['type'] == 'strength':
            review += s['instructions']
            review += ['Preserve shared tempo, athlete-selected actual loads, per-side units and explicit acceptance of any progression. No prescribed actual load is manufactured.']
            position = 1
            for e in s['exercises']:
                binding = next(b for b in bindings if b['source_occurrence_id'] == e['exercise_occurrence_id'])
                for n in range(1, e['sets'] + 1):
                    review.append(f"{position}. {e['exercise_occurrence_id']} set {n}/{e['sets']}: {e['exercise']} — {e['repetitions_or_duration']}; RIR {e['rir']}; rest {e['rest_seconds']} sec between sets; {e['notes']} Identity: {binding['exercise_id'] or 'UNRESOLVED'} ({binding['variant_key']}).")
                    position += 1
            review += ['Gym total is an estimate/unknown, not a verified exact duration; ramp work, tempo and transitions are additional where authored.']
        else: review += s['instructions']
        review += ['']
    return {'SOURCE.json': encode(source), 'AUDIT.json': encode(audit), 'IDENTITY_INTAKE.json': encode(intake),
            'RUNNING_BODIES.json': encode(runs), 'SCHEDULE_CANDIDATE.json': encode(schedule),
            'ORDERED_REVIEW.md': '\n'.join(line.rstrip() for line in review)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, value in build().items():
        path = DEST / name
        if args.check:
            assert path.read_text() == value, f'Stale generated {name}'
        else:
            path.write_text(value)
    print('Reconciled 70 days: 40 runs (39 timed + final distance 10K), 20 strength, 10 rest; exact timing, variants and source provenance checked.')
