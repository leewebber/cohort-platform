#!/usr/bin/env python3
"""Offline review-source compiler. No network, runtime import, or publication authority.

Run python3 tool/hyrox_base/content_sources.py --write to regenerate, or --check.
The output is explicitly a review representation, never a Plan Package/session graph.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
REL = Path('docs/programmes/hyrox_base')
FORMAT = 'hyrox-base-review-source-v1'


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def interval(exercise, reps, seconds, recovery, effort, provenance='approved_brief'):
    # Between-only recovery is deliberately different from an EMOM rest station.
    return dict(kind='intervals', exercise=exercise, repetitions=reps,
                work_seconds=seconds, recovery_seconds=recovery,
                recovery_placement='between_only', recovery_effort='easy jogging' if exercise == 'running' else 'easy rowing',
                effort=effort, provenance=provenance,
                steps=[dict(id=f'{phase}-{i}', phase=phase, seconds=duration)
                       for i in range(1, reps + 1)
                       for phase, duration in ([('work', seconds), ('recovery', recovery)]
                                               if i < reps else [('work', seconds)])])


def strength(exercise, sets, reps, rir, per_side=False, rest=None, **extra):
    return dict(kind='strength', exercise=exercise, sets=sets, reps=reps, rir=rir,
                per_side=per_side, rest_seconds=rest,
                provenance='supporting_direction', **extra)


def approved_rows(root):
    """Read the actual immutable calculator table, not a second invented dose table."""
    code = (root / 'lib/domain/hyrox_base/base_personalisation.dart').read_text()
    matches = re.findall(r"BaseWeekRule\((\d[^\n]+?), '([^']+)'\)", code)
    rows = []
    for index, (numbers, rir) in enumerate(matches, 1):
        n = [int(x.strip()) for x in numbers.split(',')]
        if len(n) != 12:
            raise ValueError('Changed BaseWeekRule contract; inspect before compiling.')
        rows.append(dict(week=index, easy_minutes=n[:2], quality=n[2:4],
                         long_minutes=n[4:6], row=n[6:9], squat=n[9:] + [rir]))
    if len(rows) != 8:
        raise ValueError('Approved eight-week calculator table unavailable.')
    return rows


def compile_sources(spec, root):
    if set(spec) != {'format','base_commit','authority','approved_weeks','supporting_weeks','preparation','policies'}:
        raise ValueError('Unknown or missing review source field')
    if spec['format'] != FORMAT or spec['approved_weeks'] != approved_rows(root):
        raise ValueError('Approved run/row/squat doses disagree with existing calculator.')
    if [x['week'] for x in spec['supporting_weeks']] != list(range(1, 9)):
        raise ValueError('Supporting progression must cover exactly eight ordered weeks.')
    for row in spec['supporting_weeks']:
        if set(row) != {'week','rdl','lunge','upper','carry','plank','pallof','bike','ski_wall_ball'}:
            raise ValueError('Unknown or missing supporting progression field')
        for key in ['rdl','lunge']:
            if len(row[key]) != 3 or any(type(v) is not int or v <= 0 for v in row[key][:2]):
                raise ValueError('Invalid strength progression')
        for key in ['carry','plank','pallof','ski_wall_ball']:
            expected = 3 if key == 'ski_wall_ball' else 2
            if len(row[key]) != expected or any(type(v) is not int or v <= 0 for v in row[key]):
                raise ValueError('Invalid core/finisher progression')
        upper = row['upper']
        if set(upper) != {'sets','press','pull_up','row','rir'} or type(upper['sets']) is not int or upper['sets'] <= 0:
            raise ValueError('Invalid upper progression')
        for key in ['press','pull_up','row']:
            pair = upper[key]
            if len(pair) != 2 or any(type(v) is not int for v in pair) or not 0 < pair[0] <= pair[1]:
                raise ValueError('Invalid rep window')
        for rir in [row['rdl'][2],row['lunge'][2],upper['rir']]:
            if not isinstance(rir,str) or not re.fullmatch(r'[0-9](?:–[0-9])?',rir):
                raise ValueError('Invalid RIR range')
            if '–' in rir and int(rir[0]) > int(rir[-1]):
                raise ValueError('Reversed RIR range')
        bike = row['bike']
        if len(bike) != 5 or any(type(bike[i]) is not int or bike[i] <= 0 for i in [0,1,3,4]) or bike[0] % 2 or not 0 < bike[1] < 60 or not 0 < bike[4] <= 10 or bike[2] not in {'kettlebell_swing','two_dumbbell_devils_press'}:
            raise ValueError('Invalid alternating minute source')
        if row['ski_wall_ball'][1] >= 60:
            raise ValueError('Ski work must leave recovery in its minute')
    source_pins = {name: digest((root / REL / name).read_bytes())
                   for name in ['PROGRESSION.json', 'TRANSFER_BRIEF.txt', 'APPROVAL_2026_10_24.txt']}
    source_pins['approved_brief'] = digest((root / 'docs/checkpoints/hyrox_base_personalisation/FOUNDER_BRIEF.txt').read_bytes())
    sessions, schedule = [], []
    for a, s in zip(spec['approved_weeks'], spec['supporting_weeks']):
        w = a['week']
        for day, mode in enumerate(['gym_a', 'easy', 'gym_b', 'quality', 'gym_c', 'long', 'rest'], 1):
            sid = f'BASE-W{w:02}-{mode.upper()}'
            schedule.append(dict(week=w, day=day, type='rest' if day == 7 else 'training',
                                 source_id=None if day == 7 else sid))
            if day == 7:
                continue
            blocks, decisions, gaps, intents = [], [], [], []
            prep = spec['preparation'][mode]
            if mode.startswith('gym'):
                upper = s['upper']
                gym = mode[-1]
                if gym == 'a':
                    sets, reps, basis, rir = a['squat']
                    blocks.append(strength('back_squat', sets, [reps, reps], rir,
                                           five_rm_basis_points=basis))
                    blocks[-1]['provenance'] = 'approved_brief'
                    blocks[-1]['rest_seconds'] = [150,180]
                    intents.append(dict(kind='backSquat', parameters=dict(sets=sets, reps=reps,
                                        five_rm_basis_points=basis, rir=rir)))
                    pair = [('strict_overhead_press', 'press'), ('strict_pull_up', 'pull_up')]
                    csets, metres = s['carry']
                    core = dict(kind='carry', exercise='suitcase_carry', sets=csets,
                                distance_metres=metres, per_side=True,
                                load_direction='lighter' if w == 4 else 'optional increase' if w == 5 else 'not specified',
                                rest_seconds=[45,60], provenance='supporting_direction')
                    reps, mins, recovery = a['row']
                    finish = interval('rowing', reps, mins * 60, recovery, None)
                    intents.append(dict(kind='dedicatedRowIntervals', parameters=dict(
                        repetitions=reps, work_seconds=mins * 60, recovery_seconds=recovery)))
                elif gym == 'b':
                    sets, reps, rir = s['rdl']
                    blocks.append(strength('rdl', sets, [reps, reps], rir, rest=[120,180]))
                    pair = [('incline_dumbbell_press', 'press'), ('chest_supported_row', 'row')]
                    csets, seconds = s['plank']
                    core = dict(kind='hold', exercise='long_lever_plank', sets=csets,
                                seconds=seconds, lever_direction='optional longer lever' if w == 5 else 'not specified',
                                rest_seconds=[45,60], provenance='supporting_direction')
                    minutes, bike_seconds, movement, reps, rpe = s['bike']
                    finish = dict(kind='alternating_emom', minutes=minutes, interval_seconds=60,
                                  cycle_minutes=2, cycles=minutes // 2, rpe=[rpe,rpe], rpe_approximate=True,
                                  stations=[dict(exercise='assault_bike', work_seconds=bike_seconds),
                                            dict(exercise=movement, reps=reps,
                                                 load_direction='light' if w in [4,8] else 'effort/technique selected')],
                                  recovery='remainder_of_each_minute',
                                  load='effort/technique selected; record athlete scaling',
                                  provenance='supporting_direction')
                else:
                    sets, reps, rir = s['lunge']
                    blocks.append(strength('front_rack_reverse_lunge', sets, [reps,reps], rir,
                                           per_side=True, rest=[120,180]))
                    pair = [('dumbbell_shoulder_press', 'press'), ('split_stance_single_arm_cable_row', 'row')]
                    csets, reps = s['pallof']
                    core = dict(kind='strength', exercise='pallof_press', sets=csets,
                                reps=[reps,reps], per_side=True, extended_hold_seconds=2,
                                resistance_direction='lighter' if w == 4 else 'optional increase' if w == 5 else 'not specified',
                                rest_seconds=[45,60], provenance='supporting_direction')
                    rounds, ski_seconds, wb_reps = s['ski_wall_ball']
                    finish = dict(kind='three_minute_cycle', rounds=rounds, interval_seconds=60,
                                  minutes=rounds * 3, rpe=[6,6] if w in [4,8] else [6,7], rpe_approximate=w in [4,8],
                                  stations=[dict(exercise='ski_erg', work_seconds=ski_seconds),
                                            dict(exercise='wall_ball', reps=wb_reps,
                                                 load='selected race weight', height='race-standard target',
                                                 race_mapping=None), dict(kind='rest', seconds=60)],
                                  recovery='remainder_of_work_minutes_plus_full_third_minute_including_final_round',
                                  provenance='supporting_direction', race_requirement_provenance='explicit_founder_requirement')
                    decisions.append('D4')
                pair_exercises = [strength(e, upper['sets'], upper[k], upper['rir'],
                                          per_side=e.startswith('split_stance')) for e, k in pair]
                if gym == 'c' and w == 1:
                    pair_exercises[1]['reps'] = [10,10]
                blocks += [dict(kind='superset', exercises=pair_exercises,
                                rest_after_pair_seconds=[90,120] if gym == 'a' else [90,90],
                                transition_rest_seconds=None, provenance='supporting_direction'), core, finish]
                timing = dict(kind='partial', preparation_minutes=[12,15], cooldown_minutes=[5,5],
                              cooldown_approximate=True,
                              finisher_seconds=(finish['repetitions'] * finish['work_seconds'] +
                                                (finish['repetitions'] - 1) * finish['recovery_seconds'])
                              if gym == 'a' else finish['minutes'] * 60,
                              full_seconds=None,
                              unknown='rep/transition durations, ramp-ups, core rest placement')
                gaps = ['B2'] if gym == 'c' else []
            else:
                if mode == 'quality':
                    reps, mins = a['quality']
                    blocks = [interval('running', reps, mins * 60, 120, 'RPE about 7; repeatable')]
                    intents.append(dict(kind='runningIntervals', parameters=dict(
                        repetitions=reps, work_seconds=mins * 60, recovery_seconds=120)))
                    base_seconds = 600 + 3 * 20 + 2 * 40 + reps * mins * 60 + (reps - 1) * 120 + 300
                    timing = dict(kind='partial', known_seconds=[base_seconds+900, base_seconds+1200],
                                  full_seconds=None, unknown='dynamic preparation duration and transitions')
                    decisions.append('P2')
                else:
                    window = a[f'{mode}_minutes']
                    blocks = [dict(kind='continuous_duration_window', exercise='running',
                                   minutes=window, effort='conversational; RPE about 3–4',
                                   selection='athlete feel/recovery; no level band', provenance='approved_brief')]
                    timing = dict(kind='bounded', full_seconds=[(window[0]+prep['minutes'][0]+5)*60,
                                                               (window[1]+prep['minutes'][1]+5)*60])

                gaps = []
            cooldown = (dict(easy_running_minutes=[15,20], walking_minutes=5)
                        if mode == 'quality' else dict(minutes=5, mode='easy movement', approximate=True)
                        if mode.startswith('gym') else dict(walking_minutes=5))
            sessions.append(dict(source_id=sid, week=w, day=day, mode=mode,
                                 source_kind='review_only_unpublished', provenance=source_pins,
                                 shared_policy_refs=list(spec['policies']), shared_policies=spec['policies'],
                                 preparation=prep, blocks=blocks, cooldown=cooldown, timing=timing,
                                 binding_intents=intents,
                                 canonical_source=None, exact_exercise_versions=None,
                                 content_decisions=sorted(set(decisions)), technical_blockers=['T1','B3']+gaps,
                                 status='awaiting_specific_content_decision' if decisions else 'technically_blocked',
                                 source_status='working_prescription_complete',
                                 preparation_gaps=['P1'] if mode.startswith('gym') else ['P2'] if mode == 'quality' else [],
                                 capture_gaps=['C1'] if mode.startswith('gym') else [],
                                 binding_readiness='unresolved_published_versions',
                                 supporting_content_approval='prescription approved 2026-10-24; no unseen capture approval'))
    return dict(format=FORMAT, authority=spec['authority'], source_pins=source_pins,
                policies=spec['policies'], sessions=sessions, schedule=schedule)


def identities(bundle):
    result = set()
    def walk(v):
        if isinstance(v, dict):
            if 'exercise' in v:
                result.add(v['exercise'])
            # Preparation movement tuples are explicitly authored labels, not IDs.
            for key, child in v.items():
                if key == 'movements':
                    result.update(x[0] for x in child)
                walk(child)
        elif isinstance(v, list):
            for child in v:
                walk(child)
    walk(bundle)
    return sorted(result)


def compact(value):
    if isinstance(value, dict):
        parts = []
        for k,v in value.items():
            if k == 'rest_seconds' and v is None:
                parts.append('rest: not individually prescribed; use the after-pair rest')
                continue
            if k == 'transition_rest_seconds' and v is None:
                parts.append('transition rest: not separately prescribed')
                continue
            if k == 'steps':
                continue  # Repeated interval steps are described by reps/work/recovery above.
            if k == 'movements':
                text = ', '.join(f'{x[1]} {x[0].replace("_"," ")}{" / side" if x[2] else ""}' for x in v)
            elif k == 'exercise' and isinstance(v,str):
                text = v.replace('_',' ')
            else:
                text = compact(v)
            parts.append(f'{k.replace("_", " ")}: {text}')
        return '; '.join(parts)
    if isinstance(value, list):
        if len(value) == 2 and all(type(x) is int for x in value):
            return str(value[0]) if value[0] == value[1] else f'{value[0]}–{value[1]}'
        return ' / '.join(compact(v) for v in value)
    return 'UNRESOLVED' if value is None else str(value).lower() if isinstance(value, bool) else str(value)


def render_master(spec, bundle):
    lines = ['# HYROX Base master source specification', '',
             '2026-10-24. Working prescriptions approved with explicit corrections. Binding readiness, preparation detail and commercial publication remain separate.', '',
             '[Exact transfer](TRANSFER_BRIEF.txt) · [Progression input](PROGRESSION.json) · '
             '[Decisions and provenance](DECISIONS.md) · [Coverage](COVERAGE.md) · [Technical contract](CONTRACT.md) · [Capture/preparation audit](CAPTURE_AND_PREPARATION.md) · [Exercise candidates](EXERCISE_CANDIDATES.md)', '',
             'This document expands every authored day, including preparation and cooldown. '
             'W1 row/plank, long preparation and squat rest follow the new explicit decisions; source labels are not canonical identities. '
             'No Test Week, invented fixed loads, automatic increases or filler is added.', '']
    for k,v in spec['policies'].items():
        lines += [f'**{k.replace("_", " ").capitalize()}.** {v}', '']
    lines += ['## Established approved progression', '',
              '| Week | Easy min | Quality reps × min | Long min | Row reps × min / recovery s | Squat sets × reps / basis points of 5RM / RIR |',
              '|---|---|---|---|---|---|']
    for a in spec['approved_weeks']:
        lines.append(f'| {a["week"]} | {compact(a["easy_minutes"])} | {a["quality"][0]} × {a["quality"][1]} | {compact(a["long_minutes"])} | {a["row"][0]} × {a["row"][1]} / {a["row"][2]} | {a["squat"][0]} × {a["squat"][1]} / {a["squat"][2]} / {a["squat"][3]} |')
    lines += ['', '## Supporting progression transferred for review', '',
              'Supporting exercise doses/core/finishers are prescription-approved, with W1 single-arm cable row 3 × 10/side at 2 RIR and plank 3 × 20 s. Earlier alternatives remain in the provenance register.', '',
              '| Week | RDL sets/reps/RIR | Lunge sets/reps per leg/RIR | Upper | Carry sets/m per side | Plank sets/s | Pallof sets/reps per side | Bike min/s/movement/reps/RPE | Ski rounds/s/WB reps |',
              '|---|---|---|---|---|---|---|---|---|---|']
    for s in spec['supporting_weeks']:
        lines.append('| ' + ' | '.join([str(s['week'])]+[(' × '.join(str(v) for v in s[k]) if k in ['carry','plank','pallof'] else compact(s[k])) for k in ['rdl','lunge','upper','carry','plank','pallof','bike','ski_wall_ball']]) + ' |')
    for session in bundle['sessions']:
        lines += ['', f'## {session["source_id"]} — day {session["day"]}', '',
                  f'**Status:** {session["status"]}. Decisions: {(compact(session["content_decisions"]) or 'none')}. '
                  f'Technical blockers: {compact(session["technical_blockers"])}.', '',
                  '**Preparation:** ' + compact(session['preparation']) + '.', '']
        for i,b in enumerate(session['blocks'], 1):
            lines += [f'{i}. ' + compact(b) + '.']
        lines += ['', '**Cooldown:** ' + compact(session['cooldown']) + '.', '',
                  '**Timing:** ' + compact(session['timing']) + '.', '',
                  '**Other categories:** preparation gaps ' + (compact(session['preparation_gaps']) or 'none') + '; capture limits ' + (compact(session['capture_gaps']) or 'none') + '; binding readiness ' + session['binding_readiness'] + '.', '',
                  '**Personalisation intent:** ' + (compact(session['binding_intents']) or 'none') + '. '
                  'Exact canonical exercise versions and physical source bindings remain unresolved.']
    lines += ['', '## Rest schedule', '']
    lines += [f'- W{r["week"]} Sunday: rest; no training slot or source.' for r in bundle['schedule'] if r['type']=='rest']
    return ('\n'.join(lines)+'\n').encode()


def export_review(bundle):
    payload = encoded(bundle)
    return encoded(dict(format='hyrox-base-review-export-v1', sha256=digest(payload),
                        source=bundle, authority='review transport only; no approvals or canonical import'))


def import_review(raw):
    def unique(pairs):
        result = {}
        for k,v in pairs:
            if k in result:
                raise ValueError('Duplicate review export key')
            result[k] = v
        return result
    def invalid_constant(value):
        raise ValueError('Non-finite review export number')
    obj = json.loads(raw, object_pairs_hook=unique, parse_constant=invalid_constant)
    if set(obj) != {'format','sha256','source','authority'} or obj['format'] != 'hyrox-base-review-export-v1':
        raise ValueError('Unknown review export contract')
    if digest(encoded(obj['source'])) != obj['sha256']:
        raise ValueError('Review export digest mismatch')
    if not isinstance(obj['source'],dict) or obj['source'].get('format') != FORMAT:
        raise ValueError('Unknown source representation')
    return obj['source']


def canonical_compilation(bundle):
    # Do not call a provisional compiler with invented definitions/source UUIDs.
    # No input to this tool can establish published version/event authority.
    return dict(status='blocked_before_canonical_compilation', canonical_packages=0,
                reasons=['T1','B3'], source_count=len(bundle['sessions']),
                detail='No exact approved published ExerciseDefinition/event bundle or physical session revisions supplied; source lowering is independently implemented and fixture-tested; authority is not fabricated.')


def build_outputs(root):
    spec = json.loads((root / REL / 'PROGRESSION.json').read_bytes())
    bundle = compile_sources(spec, root)
    ids = identities(bundle)
    summary = dict(training_sessions=len(bundle['sessions']), rest_days=sum(d['type']=='rest' for d in bundle['schedule']),
                   review_sources=len(bundle['sessions']), authoritative_binding_ready=0, canonical_lowering_implemented=True,
                   binding_blockers_by_code={code:sum(code in s['technical_blockers'] for s in bundle['sessions']) for code in ['T1','B3','B2']},
                   capture_limit_sessions=sum(bool(s['capture_gaps']) for s in bundle['sessions']),
                   working_prescription_complete=sum(s['source_status']=='working_prescription_complete' for s in bundle['sessions']),
                   full_quantified_preparation_available=sum(not s['preparation_gaps'] for s in bundle['sessions']),
                   preparation_detail_gaps=sum(bool(s['preparation_gaps']) for s in bundle['sessions']),
                   all_sessions_have_T1=all('T1' in s['technical_blockers'] for s in bundle['sessions']))
    audit = dict(summary=summary, canonical_compilation=canonical_compilation(bundle),
                 identities=[dict(authored_label=i, exact_definition=None, exact_version=None,
                                  publication_event=None, digest=None, resolution='T1') for i in ids],
                 sessions=[{k:s[k] for k in ['source_id','status','source_status','content_decisions','preparation_gaps','capture_gaps','technical_blockers','binding_readiness','timing']} for s in bundle['sessions']])
    coverage = ['# 48-session completeness and timing audit', '', compact(summary), '',
                'Every training day has an independent, fully retained review source in [SESSIONS.json](SESSIONS.json) '
                'and a readable expansion in [MASTER.md](MASTER.md). All 48 main working prescriptions are source-complete and lower through the new canonical model adapter; full quantified preparation is separately incomplete on 32. '
                'All 48 lack exact published definition/version/event resolution (T1). The table reports every category independently; '
                'all categories remain visible. Working exercise prescriptions are approved; preparation gaps and capture limits confer no new prescription or result authority.', '',
                '| Source | Source status | Content/preparation gaps | Binding blockers | Capture limits | Timing |', '|---|---|---|---|---|---|']
    for s in bundle['sessions']:
        coverage.append('| '+' | '.join([s['source_id'],s['source_status'],compact(list(dict.fromkeys(s['content_decisions']+s['preparation_gaps']))),compact(s['technical_blockers']),compact(s['capture_gaps']),compact(s['timing'])])+' |')
    coverage += ['', 'Eight Sunday rest entries are in the 56-entry schedule. Test Week has no entries.', '',
                 'Long-run timing correction: every long run uses 5 minutes gentle walking/jogging and 5 minutes walking cooldown; an 80-minute main run totals 90 minutes. W6/W7 main remains 65–80. Quality totals exclude unquantified dynamic work; gym totals are partial. Source completeness, binding readiness and capture limits are independent categories.', '',
                 f'{len(ids)} distinct authored movement labels (including preparation) need exact resolution; see [AUDIT.json](AUDIT.json). '
                 'No claim that all labels need distinct new canonical identities is made.']
    candidates = exercise_candidates(bundle)
    outputs = {'EXERCISE_CANDIDATES.json':encoded(candidates), 'SESSIONS.json':encoded(bundle), 'AUDIT.json':encoded(audit),
               'MASTER.md':render_master(spec,bundle), 'COVERAGE.md':('\n'.join(coverage)+'\n').encode(),
               'REVIEW_EXPORT.json':export_review(bundle)}
    if import_review(outputs['REVIEW_EXPORT.json']) != bundle:
        raise ValueError('Review export changed source semantics')
    outputs['MANIFEST.json'] = encoded(dict(format=FORMAT, files={k:digest(v) for k,v in sorted(outputs.items())},
                                           inputs=bundle['source_pins']))
    return outputs



def exercise_candidates(bundle):
    known = {'back_squat':('EX-073','cohort.exercise.back_squat'),
      'rdl':('EX-078','cohort.exercise.romanian_deadlift'),
      'strict_overhead_press':('EX-088','cohort.exercise.strict_press'),
      'strict_pull_up':('EX-053','cohort.exercise.pull_up'),
      'running':('EX-129','cohort.exercise.running'),
      'rowing':('EX-049','cohort.exercise.rowing'),
      'ski_erg':('EX-050','cohort.exercise.ski_erg'),
      'wall_ball':('EX-052','cohort.exercise.wall_ball'),
      'dead_bug':('EX-022','cohort.exercise.dead_bug')}
    def dimensions(label):
        if label in {'running','rowing','ski_erg','assault_bike','easy_bike'}:
            return ['duration','distance','rpe']
        if label=='suitcase_carry': return ['load','distance','unilateral_side']
        if label=='long_lever_plank': return ['duration']
        if label=='wall_ball': return ['repetitions','load','height_or_target']
        return ['repetitions','load','rir']
    rows=[]
    for label in identities(bundle):
        ex, transitional=known.get(label,(None,None))
        variants={'front_rack_reverse_lunge':'Front-rack reverse lunge; front-rack implement/variant not selected by name similarity.',
          'split_stance_single_arm_cable_row':'Split-stance, single-arm cable row; per-side prescription.',
          'two_dumbbell_devils_press':"Two-dumbbell devil's press; no single-dumbbell substitution.",
          'long_lever_plank':'Long-lever plank; optional longer lever W5, not generic-plank authority.',
          'suitcase_carry':'Unilateral suitcase carry; not farmer carry.',
          'light_row':'Preparation row variant unspecified; do not infer cable/dumbbell or chest support.',
          'light_scapular_row':'Preparation scapular-row variant unspecified.',
          'reverse_lunge':'Preparation reverse lunge; do not map to walking lunge.',
          'wall_ball':'Wall ball at selected race weight/standard target; division mapping unresolved.'}
        erg = label in {'rowing','ski_erg','assault_bike','easy_bike'}
        bodyweight = label in {'bodyweight_squat','glute_bridge','dead_bug','long_lever_plank','wall_slide','strict_pull_up','unloaded_hip_hinge'}
        proposed_modality = 'erg' if erg else 'locomotion' if label=='running' else 'bodyweight' if bodyweight else 'strength'
        equipment_notes = {
          'back_squat':'Barbell/rack; no total-load increment is guessed.',
          'strict_overhead_press':'Barbell strict press is the existing EX-088 candidate; exact Base binding requires review.',
          'strict_pull_up':'Strict pull-up facility; no assisted or weighted substitution inferred.',
          'rdl':'Barbell EX-078 is an existing candidate; exact implement/variant still needs binding review.',
          'incline_dumbbell_press':'Dumbbells and incline bench.',
          'chest_supported_row':'Chest support; rowing implement is not selected by name similarity.',
          'front_rack_reverse_lunge':'Front-rack implement remains an explicit variant input.',
          'dumbbell_shoulder_press':'Dumbbells; no unprovided seated/standing restriction is added.',
          'split_stance_single_arm_cable_row':'Cable station; split stance and single arm are explicit.',
          'suitcase_carry':'Unilateral external load and measured carry space; no fixed kg.',
          'long_lever_plank':'Bodyweight long-lever position; no compulsory leverage change.',
          'pallof_press':'Resistance implement must be reviewed; cable/band equivalence is not granted.',
          'rowing':'Row erg; device/protocol semantics stay separate.',
          'ski_erg':'SkiErg device; banded patterns remain separate.',
          'assault_bike':'Authored assault bike; no equivalence to other bikes inferred.',
          'easy_bike':'Preparation bike variant requires review.',
          'kettlebell_swing':'Kettlebell; effort/technique-selected load.',
          'two_dumbbell_devils_press':'Two dumbbells; effort/technique-selected load.',
          'wall_ball':'Wall ball plus standard target; load/height await authoritative selected-division mapping.',
          'light_band_pull_apart':'Light band; no fixed resistance.',
          'light_row':'Exact preparation row/implement remains unspecified.',
          'light_scapular_row':'Exact scapular-row preparation variant remains unspecified.'
        }.get(label,'Exact authored preparation movement; no extra equipment or coaching standard invented.')
        rows.append(dict(candidate_key='base-candidate-'+label,authored_label=label,
          proposed_existing_canonical_id=ex,established_transitional_mapping=transitional,
          candidate_definition=dict(canonical_name=label.replace('_',' '),id=ex,
            version=None,lifecycle_status='draft',published_at=None,
            modality=proposed_modality,valid_prescription_dimensions=dimensions(label),
            valid_completed_performance_dimensions=[],
            variant=variants.get(label,'Exact authored variant; equipment/classification/valid dimensions require definition review.')),
          approval_required=['exact source-to-definition variant binding','complete definition/classification/equipment review',
            'producer-assigned current version and verified approval/publication event'],
          proposed_equipment_notes=equipment_notes, classification_status='PROPOSED_FOR_DEFINITION_REVIEW_NOT_APPROVED',
          publication_event=None,retained_digest=None,
          evidence='docs/architecture/Phase_3_1F_Part2_Founder_Approved_Canonical_Mappings_v1.md' if ex else 'No explicit accepted mapping supplied for this authored label.',
          meaning='Candidate only; neither an EX reservation nor published/historical definition authority.'))
    return dict(format='hyrox-base-exercise-candidates-v1',status='REQUIRES_EXISTING_TRUSTED_PRODUCER_REVIEW',
      local_authority_audit=dict(authoritative_real_exact_version_bundles=0,
        excluded_sources=['Historical 132-row catalogue export: identity/lifecycle only.',
          'Phase 3.2D movement-knowledge draft derivatives: no retained publication event.',
          'EX-900x/EX-900900 synthetic fixtures: software simulations only.'],
        boundary='PublishedExerciseVersionRetention and existing configured trusted event producer; never a new publication service.'),
      candidates=rows)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.write == args.check:
        parser.error('Choose exactly one of --write or --check')
    outputs = build_outputs(ROOT)
    for name,data in outputs.items():
        path = ROOT / REL / name
        if args.write:
            path.write_bytes(data)
        elif not path.is_file() or path.read_bytes() != data:
            raise SystemExit(f'Stale or missing review artifact: {path}')
    print(json.dumps(dict(artifacts=len(outputs), review_sources=48, rest_days=8,
                          canonical_packages=0, result='written' if args.write else 'exact')))


if __name__ == '__main__':
    main()
