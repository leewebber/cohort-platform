"""Prepare only documentation over the immutable e676e31 genuine source snapshot.

No network, credentials, source edits, new session identities or programme writes.
Default --check compares generated documents; --write refreshes only owned outputs.
"""
import argparse
import hashlib
import html
import json
import re
import tarfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = 'e676e31af15d9c5a31d573c8215ce008d1980526'
SOURCE = 'docs/programmes/hybrid_10k/performance_selected_2026_11_03/'
RETAINED = 'docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/'
OUT = 'docs/programmes/hybrid_10k/d8_review_2026_11_04/'
INPUT_PINS = {
  "docs/programmes/hybrid_10k/performance_selected_2026_11_03/SOURCE.json": "96db2300a2c84f38b745bbf9f04743f857a96b768b5a7a94ef1690428fb6a0b2",
  "docs/programmes/hybrid_10k/performance_selected_2026_11_03/RUNNING_BODIES.json": "38f9224913767959218b91468142cba498a772080a35fae52cf162468ca8ffef",
  "docs/programmes/hybrid_10k/performance_selected_2026_11_03/STRENGTH_REVIEW_GRAPHS.json": "399fcdcf618ee85d474e973d0a53a3a950f052740d7b539056df95ed1517342e",
  "docs/programmes/hybrid_10k/performance_selected_2026_11_03/TEN_WEEK_REVIEW.md": "fd854937ec93884834a80e56abbee87a394314cbc8bcc168d506c6b0c0d53adb",
  "docs/programmes/hybrid_10k/founder_selected_2026_10_30/TEN_WEEK_REVIEW.md": "f65358b81e3690938511ea5009bfcccbf20ae6593230118d8fbca828944e1a93",
  "docs/programmes/hybrid_10k/founder_selected_2026_10_30/FOUNDER_SELECTIONS.md": "dd7e08cc1b026b46307b42c491216543899879e202c3f665ce837f486bc0d6d8",
  "docs/programmes/hybrid_10k/founder_selected_2026_10_30/DOSE_CLARIFICATIONS.md": "e38cba504a1b40dcfe93e1fa72cee4b1804b0f4bee5078e7e240e41df9457b76",
  "docs/programmes/hybrid_10k/general_draft_2026_10_30/GENERAL_GUIDANCE.md": "1aabcb3034f88efb0d2a29e280ffc141b759371c9364c28015d2dc51c79370c3",
  "docs/programmes/hybrid_10k/RUNNING_SELECTION_2026_11_03.md": "84241df05b3e2967103942d3ff0eb6373c5678b5e240e3b4c9667f047f3256bd",
  "docs/checkpoints/m23_quality_target_admission/DECISIONS.md": "968ed2c3a84923a422a9f13797a282da454e5cde714315c856c97cf3144c1efa",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/SHA256.json": "1924011b127e85b7377166508ab516ccf613da22e9c02431b61b946dc1ff433f",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/admitted/canonical-source.tar": "c84060c5c5f97eaaf306006230cfc997a8132110012eec302a4e8b82a604d88a",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/admitted/workspace.json": "97da258a505a8fa78bfd354c247df0054fec4a8af5b3e462d0dfedd423d68de1",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/evidence/OPERATOR_TRUST.json": "cfb94cfa4ccb234740deca0943bf327e8898e4a8ef79318d34c05e1bf3b6c0bd",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/evidence/OPERATOR_AUDIT.json": "f23f77765d56f634fad466d094b7ecbfd4019324a375df07fe2e42e1ec060293",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/evidence/retained/receipt.json": "f7261883ef7da25d35f09889f2706c9bd3d26bc33a853d8a0ff358b24fb21b62",
  "docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/evidence/ADMISSION.json": "c0b75eb33380acb3ba0393474cc8b65fe7137584f8f223d8886356126015013a"
}
BINDINGS = {'chest_supported_db_row': 'EX-170', 'seated_supported_db_press': 'EX-171', 'reverse_lunge_db': 'EX-172'}

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def encoded(obj):
    return (json.dumps(obj, ensure_ascii=False, indent=2) + '\n').encode()

def canonical(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()

def clock(ms):
    assert ms % 1000 == 0
    seconds = ms // 1000
    return f'{seconds // 60}:{seconds % 60:02d}'

def paragraph(text):
    # Preserve all existing renderer words/order, with explicit readable line breaks.
    return '\n\n'.join('<br>\n'.join(html.escape(line, quote=False) for line in part.splitlines()) for part in text.strip().split('\n\n'))

def prepare():
    for path, expected in INPUT_PINS.items():
        assert sha((ROOT / path).read_bytes()) == expected, f'Retained input changed: {path}'
    evidence = ROOT / RETAINED
    recorded = json.loads((evidence / 'SHA256.json').read_text())['files']
    for path, pin in recorded.items():
        assert sha((evidence / path).read_bytes()) == pin['sha256'], f'Retained evidence changed: {path}'
    trust = json.loads((evidence / 'evidence/OPERATOR_TRUST.json').read_text())
    assert trust['receipt_sha256'] == 'f7261883ef7da25d35f09889f2706c9bd3d26bc33a853d8a0ff358b24fb21b62'
    assert trust['audit_reference'] == 'supabase-cli-login:a5510f770d978a56-CGK:m11_live_0431d08_20261104'
    source = json.loads((ROOT / SOURCE / 'SOURCE.json').read_text())
    selected_strength = json.loads((ROOT / SOURCE / 'STRENGTH_REVIEW_GRAPHS.json').read_text())
    old_strength = {g['source_session_id']: g for g in selected_strength}
    workspace = json.loads((evidence / 'admitted/workspace.json').read_text())
    retained_roots = {r['protocol_id']: r for owner in workspace['owners'] for r in owner['revisions'] if r['origin']['kind'] == 'retained_source_snapshot_history_unknown'}
    with tarfile.open(evidence / 'admitted/canonical-source.tar') as tar:
        members = tar.getmembers()
        assert len({m.name for m in members}) == len(members)
        assert all(m.isfile() and not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members)
        files = {m.name: tar.extractfile(m).read() for m in members}
    idx = json.loads(files['source-index.json'])
    assert set(files) == set(idx['files_sha256']) | {'source-index.json'}
    for path, h in idx['files_sha256'].items():
        assert sha(files[path]) == h, f'Archive member changed: {path}'
    package = json.loads(files['programme.canonical.json'])
    assert sha(files['programme.canonical.json']) == idx['package_sha256']
    assert package['package_schema_version'] == 2
    assert package['programme']['duration_weeks'] == 10
    assert package['adaptation_permissions'] == []
    graph_entries = {s['session_key']: s for s in idx['sessions']}
    assert len(graph_entries) == len(idx['sessions']) == len(package['sessions']) == 60
    graph_by_key = {key: json.loads(files[entry['path']]) for key, entry in graph_entries.items()}
    assert json.loads(files['protocol-graphs.json']) == [graph_by_key[s['session_key']] for s in idx['sessions']]
    original_review = files['prescription-review.txt'].decode()
    split = re.split(r'(?m)^Week (\d+) day (\d+) · local version (\d+)\n', original_review)
    assert split[0] == '' and len(split) == 241
    rendered = {}
    for i in range(1, len(split), 4):
        week, day, version = map(int, split[i:i+3])
        assert (week, day) not in rendered
        rendered[(week, day)] = (version, split[i+3].strip())
    sessions = {(s['week'], s['day']): s for s in source['sessions']}
    assert len(sessions) == len(source['sessions']) == 70
    assert Counter(s['type'] for s in sessions.values()) == {'strength': 20, 'running': 40, 'rest': 10}
    outputs, rows, weekly = {}, [], []
    resolved = Counter()
    targets = Counter()
    work_occurrences = retained_ids = 0
    for w in package['weeks']:
        wn = w['week_number']
        assert len(w['days']) == 7
        focus = next(x['focus'] for x in source['weeks'] if x['week'] == wn)
        text = f'# Week {wn} — {focus}\n\n[Review overview](../REVIEW.md) · [Shared guidance and remaining D8 scope](../CONTENT_NOTES.md)\n\nAll prescriptions below are from the retained genuine archive. Source dates are illustrative; no assignment is made.\n\n'
        days, timed_ms, distance_m, work_sets = [], 0, 0, 0
        for day in w['days']:
            dn = day['day_order']
            s = sessions[(wn, dn)]
            reference = s['session_id']
            assert reference == f'LW10K-W{wn:02d}-D{dn:02d}'
            assert day['day_type'] == ('rest' if s['type'] == 'rest' else 'training')
            row = {'review_reference': reference, 'week': wn, 'day': dn, 'weekday': s['weekday'], 'title': s['title'], 'type': s['type'], 'illustrative_date': s['date'], 'source_instructions': s.get('instructions', []), 'review_path': f'weeks/week-{wn:02d}.md#{reference.lower()}'}
            body = f'<a id="{reference.lower()}"></a>\n\n## {s["weekday"]} — {s["title"]}\n\nReview reference: `{reference}`. Source date: {s["date"]} (illustrative).\n\n'
            for note in s.get('instructions', []):
                body += note + '\n\n'
            if s['type'] == 'rest':
                assert day['slots'] == [] and (wn, dn) not in rendered
                row.update(graph_path=None, graph_sha256=None, selected_revision=None)
                summary = 'Rest; no required training'
            else:
                assert len(day['slots']) == 1
                slot = day['slots'][0]
                assert slot['slot_key'] == reference
                key = slot['session_key']
                graph = graph_by_key[key]
                version, review = rendered[(wn, dn)]
                assert version == graph['revision_number']
                assert graph_entries[key]['source_sha256'] == sha(files[graph_entries[key]['path']])
                row.update(graph_path=graph_entries[key]['path'], graph_sha256=sha(files[graph_entries[key]['path']]), selected_revision=key, renderer_text_sha256=sha(review.encode()))
                if s['type'] == 'strength':
                    previous = json.loads(json.dumps(old_strength[reference]))
                    # The existing selected-source adapter carries SOURCE instructions
                    # into the first block's notes. Check that exact retained root,
                    # rather than treating its already-retained notes as new drift.
                    instructions = '\n'.join(s.get('instructions', []))
                    if instructions:
                        previous['blocks'][0]['coach_notes'] = instructions
                    root = retained_roots[previous['protocol_id']]
                    assert sha(root['source'].encode()) == root['sha256']
                    assert previous == json.loads(root['source']), f'Retained root differs: {reference}'
                    current = json.loads(json.dumps(graph))
                    for item in [previous, current]:
                        item.pop('protocol_id'); item.pop('revision_number')
                    for block in previous['blocks']:
                        for exercise in block['exercises']:
                            work_occurrences += 1
                            if exercise['exercise_id'] is None:
                                variant = exercise['variant_key']
                                exercise['exercise_id'] = BINDINGS[variant]
                                resolved[variant] += 1
                            else:
                                retained_ids += 1
                    assert current == previous, f'Unexpected prescription/source change: {reference}'
                    exercises = [e for b in graph['blocks'] for e in b['exercises']]
                    sets = sum(e['prescription']['sets'] for e in exercises)
                    work_sets += sets
                    row['exercise_bindings'] = [{'source_occurrence_id': e['source_occurrence_id'], 'variant': e['variant_key'], 'exercise_id': e['exercise_id'], 'prescription_sha256': sha(canonical(e['prescription']))} for e in exercises]
                    summary = f'{len(exercises)} exercises; {sets} working sets'
                    body += 'Working order is exactly the saved order. Per-side sets count once after both sides; preparation/ramp sets are additional and separately labelled.\n\n'
                else:
                    blocks = [b for b in graph['blocks'] if b.get('timer_config', {}).get('running_workout')]
                    assert len(blocks) == 1
                    steps = blocks[0]['timer_config']['running_workout']['steps']
                    assert steps == s['steps'], f'Selected running body differs: {reference}'
                    ms = sum(p['duration']['milliseconds'] for p in steps if p['duration']['kind'] == 'time')
                    assert all(p['duration']['millimetres'] % 1000 == 0 for p in steps if p['duration']['kind'] == 'distance')
                    metres = sum(p['duration']['millimetres'] // 1000 for p in steps if p['duration']['kind'] == 'distance')
                    timed_ms += ms; distance_m += metres
                    targets.update(json.dumps(p['target'], sort_keys=True) for p in steps)
                    row.update(timed_milliseconds=ms, distance_metres=metres, ordered_step_count=len(steps), steps_sha256=sha(canonical(steps)))
                    summary = clock(ms) + (' + 10,000 m (actual elapsed time)' if metres else '')
                body += f'Local saved version {version}; genuine source identity is indexed in [REVIEW_INDEX.json](../REVIEW_INDEX.json).\n\n'
                body += paragraph(review) + '\n\n'
            row['summary'] = summary
            rows.append(row)
            days.append((s, summary, body))
        text += '| Day | Session | Exact timed run total / working-set count |\n|---|---|---|\n'
        for s, summary, _ in days:
            text += f'| {s["weekday"]} | [{s["title"]}](#{s["session_id"].lower()}) | {summary} |\n'
        text += f'\nWeekly running: **{clock(timed_ms)} timed session minutes' + (' + 10,000 m test elapsed time' if distance_m else '') + f'**. Strength: **{work_sets} working sets** across two sessions. Timed running includes recoveries and any permitted walking, not pure running volume; no gym duration is inferred.\n\n'
        for _, _, body in days:
            text += body
        outputs[f'weeks/week-{wn:02d}.md'] = (text.rstrip() + '\n').encode()
        weekly.append({'week': wn, 'focus': focus, 'timed_milliseconds': timed_ms, 'distance_metres': distance_m, 'strength_working_sets': work_sets})
    assert len(rows) == 70 and len(rendered) == 60
    assert work_occurrences == 105 and retained_ids == 77
    assert resolved == {'chest_supported_db_row': 10, 'seated_supported_db_press': 10, 'reverse_lunge_db': 8}
    final = next(r for r in rows if r['review_reference'] == 'LW10K-W10-D07')
    assert final['timed_milliseconds'] == 1200000 and final['distance_metres'] == 10000
    assert sum(r.get('distance_metres', 0) for r in rows) == 10000
    outputs['REVIEW_INDEX.json'] = encoded({'kind': 'D8_REVIEW_INVENTORY_NOT_APPROVAL', 'base_commit': BASE, 'source_archive_sha256': INPUT_PINS[RETAINED + 'admitted/canonical-source.tar'], 'package_sha256': idx['package_sha256'], 'weekly': weekly, 'days': rows})
    return outputs, {'input_pins': INPUT_PINS, 'base_commit': BASE, 'days': 70, 'strength_sessions': 20, 'running_sessions': 40, 'rest_days': 10, 'strength_prescriptions_exact': work_occurrences, 'prior_identity_occurrences_unchanged': retained_ids, 'genuine_missing_bindings': dict(resolved), 'all_40_running_steps_exact': True, 'canonical_archive_and_all_member_hashes_verified': True, 'all_retained_checkpoint_hashes_verified': True, 'all_60_existing_renderer_segments_carried_verbatim_as_html_escaped_lines': True, 'final_test_distance_metres': final['distance_metres'], 'final_test_timed_milliseconds': final['timed_milliseconds'], 'weekly': weekly, 'review_status': 'PREPARED_AWAITING_FOUNDER_D8', 'publication': 'NOT_PERFORMED', 'Gate_A': 'OPEN'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    assert not (args.write and args.check)
    outputs, verification = prepare()
    verification['generated_files_sha256'] = {name: sha(raw) for name, raw in outputs.items()}
    outputs['evidence/GENERATION.json'] = encoded(verification)
    for name, raw in outputs.items():
        path = ROOT / OUT / name
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        else:
            assert path.read_bytes() == raw, f'Derived review changed: {name}'
    if not args.write:
        review_root = ROOT / OUT
        scope = json.loads((review_root / 'REVIEW_SCOPE.json').read_text())
        scope_hash = scope.pop('snapshot_sha256')
        assert sha(canonical(scope)) == scope_hash, 'Review scope digest differs'
        assert scope['input_sha256'] == INPUT_PINS and scope['base_commit'] == BASE
        assert set(scope['review_files_sha256']) == set(outputs) | {'REVIEW.md', 'CONTENT_NOTES.md'}
        for name, digest in scope['review_files_sha256'].items():
            assert sha((review_root / name).read_bytes()) == digest, f'Review content changed: {name}'
        decision = json.loads((review_root / 'DECISION.template.json').read_text())
        assert decision['review_snapshot_sha256'] == scope_hash
        assert decision['decision'] == 'PENDING' and decision['reviewer'] is None and decision['recorded_at'] is None
        verification['exact_review_scope_and_pending_template_verified'] = True
    print(json.dumps({k: v for k, v in verification.items() if k not in ['input_pins', 'generated_files_sha256', 'weekly']}, indent=2))

if __name__ == '__main__':
    main()
