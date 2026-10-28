#!/usr/bin/env python3
"""Independent Python inspection of the emitted field representation (NOT an SDK).

Public Garmin FIT Workout article and official profile 21.214.0, accessed 2026-10-28:
https://developer.garmin.com/fit/articles/file-types/workout.html
https://raw.githubusercontent.com/garmin/fit-javascript-sdk/refs/heads/main/src/profile.js
No converter imports; derives durations, repeats and target bounds from the frozen
resolved source using Fraction arithmetic, plus explicit known-vector assertions.
"""
import copy
import hashlib
import json
import sys
from fractions import Fraction


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                    separators=(',', ':')).encode()).hexdigest()


def verify(document):
    assert document['fixture_only'] is True
    export = document['export']
    assert document['export_digest'] == digest(export), 'export digest'
    scope = export['scope']
    prescription = export['prescription']
    accepted = prescription['accepted_snapshot']
    for key in ['athlete_id', 'assignment_id', 'programme_version_id', 'package_hash',
                'protocol_id', 'occurrence_id', 'training_session_id']:
        assert scope[key] == accepted[key], ('scope', key)
    assert digest(accepted) == export['accepted_snapshot_sha256'], 'accepted snapshot digest'
    assert digest(prescription['source_body']) == export['source_body_sha256'], 'source digest'
    assert prescription['source_body'] == accepted['blocks'][0]['workout']
    assert scope['block_id'] == accepted['blocks'][0]['block_id']
    fields = export['fit_fields']
    assert fields['binary_fit'] is False and fields['training_api_payload'] is False
    assert fields['workout']['sport'] == 1  # FIT sport.running
    rows = fields['workout_steps']
    assert len(rows) == fields['workout']['num_valid_steps']
    assert [row['message_index'] for row in rows] == list(range(len(rows)))
    roles = {'work': 0, 'rest': 1, 'warm_up': 2, 'cool_down': 3, 'recovery': 4}
    position = 0
    expanded = []
    expected_frames = []

    def atomic(step):
        nonlocal position
        row = rows[position]
        assert row['duration_type'] == 0  # time
        assert step['duration']['kind'] == 'time'
        assert Fraction(row['duration_value'], 1000) == Fraction(step['duration']['milliseconds'], 1000)
        assert 0 < row['duration_value'] < 0xffffffff
        assert row['duration_value'] % 1000 == 0
        assert row['intensity'] == roles[step['role']]
        assert row.get('wkt_step_name') == step.get('label')
        assert row.get('notes') == step.get('notes')
        target = step['target']
        assert row['target_value'] == 0  # custom target zone selector
        if target['kind'] == 'none':
            assert row['target_type'] == 2
            assert 'custom_target_value_low' not in row and 'custom_target_value_high' not in row
        elif target['kind'] == 'pace_range':
            assert row['target_type'] == 0
            speed_low = Fraction(1000000, target['high'])
            speed_high = Fraction(1000000, target['low'])
            raw_low = row['custom_target_value_low']
            raw_high = row['custom_target_value_high']
            assert 0 < raw_low < raw_high < 0xffffffff
            # FIT speed custom fields: scale 1000, m/s. Outward expansion <1 unit.
            assert 0 <= speed_low - Fraction(raw_low, 1000) < Fraction(1, 1000)
            assert 0 <= Fraction(raw_high, 1000) - speed_high < Fraction(1, 1000)
        elif target['kind'] == 'heart_rate_range':
            assert row['target_type'] == 1
            assert row['custom_target_value_low'] - 100 == target['low']
            assert row['custom_target_value_high'] - 100 == target['high']
            assert 1 <= target['low'] < target['high'] <= 250
        else:
            raise AssertionError('unsupported target was silently exported')
        index = position
        position += 1
        return index, row['duration_value']

    for node in prescription['resolved_body']['steps']:
        if node['kind'] == 'atomic':
            index, duration = atomic(node)
            expanded.append(duration)
            expected_frames.append({'step_id': node['step_id'], 'message_index': index})
        else:
            assert node['kind'] == 'repeat' and 1 <= node['count'] <= 32
            start = position
            children = [(child, atomic(child)) for child in node['steps']]
            marker = rows[position]
            assert marker == {'message_index': position, 'duration_type': 6,
                              'duration_value': start, 'target_type': 2,
                              'target_value': node['count']}
            position += 1
            for iteration in range(1, node['count'] + 1):
                for child, (index, duration) in children:
                    expanded.append(duration)
                    expected_frames.append({'step_id': child['step_id'], 'message_index': index,
                                            'group_id': node['group_id'], 'iteration': iteration})
    assert position == len(rows)
    assert len(expanded) <= 512
    assert sum(expanded) == fields['total_duration_milliseconds']
    assert expected_frames == fields['expanded_source_steps']
    # Separate hand-calculated synthetic golden vector, not custom encode/decode.
    assert [r['duration_value'] for r in rows] == [300000, 120000, 60000, 1, 300000]
    assert [r['duration_type'] for r in rows] == [0, 0, 0, 6, 0]
    assert rows[3]['target_value'] == 3 and len(expanded) == 8
    assert (rows[1]['custom_target_value_low'], rows[1]['custom_target_value_high']) == (3267, 3402)
    assert (rows[2]['custom_target_value_low'], rows[2]['custom_target_value_high']) == (230, 245)
    assert sum(expanded) == 1140000
    assert document['activity_fixture']['actuals']['timer_milliseconds'] == 1100000
    assert document['association_fixture'] == {
        'before_delivery': 'unmatched', 'after_delivery': 'documentedFitReferenceCandidate',
        'duplicate': True, 'after_explicit_fixture_confirmation': 'confirmedByAthlete',
        'authorises_programme_completion': False}
    return {'total_seconds': sum(expanded) // 1000, 'encoded_steps': len(rows),
            'expanded_phases': len(expanded), 'independent_sdk_parse': False}


def negative_controls(document):
    edits = [
        ('duration', lambda d: d['export']['fit_fields']['workout_steps'][1].update(duration_value=120)),
        ('repeat count', lambda d: d['export']['fit_fields']['workout_steps'][3].update(target_value=2)),
        ('repeat pointer', lambda d: d['export']['fit_fields']['workout_steps'][3].update(duration_value=0)),
        ('pace units', lambda d: d['export']['fit_fields']['workout_steps'][1].update(custom_target_value_low=294000)),
        ('pace bound', lambda d: d['export']['fit_fields']['workout_steps'][1].update(custom_target_value_high=3401)),
        ('BPM offset', lambda d: d['export']['fit_fields']['workout_steps'][2].update(custom_target_value_low=130)),
        ('owner', lambda d: d['export']['scope'].update(athlete_id='foreign')),
        ('target units', lambda d: d['export']['fit_fields']['workout_steps'][1].update(target_type=1)),
    ]
    for name, edit in edits:
        bad = copy.deepcopy(document)
        edit(bad)
        bad['export_digest'] = digest(bad['export'])  # Rehash to exercise field semantics.
        try:
            verify(bad)
        except AssertionError:
            continue
        raise AssertionError('independent check missed corrupt ' + name)
    return len(edits)


if __name__ == '__main__':
    data = json.loads(open(sys.argv[1], encoding='utf-8').read())
    result = verify(data)
    result['negative_controls_rejected'] = negative_controls(data)
    result['proof'] = 'independent documented-field inspection; not Garmin SDK/binary/transport proof'
    print(json.dumps(result, sort_keys=True))
