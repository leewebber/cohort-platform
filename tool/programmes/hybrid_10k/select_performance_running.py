#!/usr/bin/env python3
"""Selected running reference -> existing native source/graphs/review. Offline only.

The founder reference is the sole running input. Archived source supplies only
unchanged strength/evidence, programme layout and immutable provenance.
"""
import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'docs/programmes/hybrid_10k'
ARCHIVE = BASE / 'founder_selected_2026_10_30'
DEST = BASE / 'performance_selected_2026_11_03'
REFERENCE = BASE / 'HYBRID_10K_PERFORMANCE_RUNNING_REFERENCE_v1.md'
SELECTION = BASE / 'RUNNING_SELECTION_2026_11_03.md'

def sha(b): return hashlib.sha256(b).hexdigest()
def encode(x): return json.dumps(x, ensure_ascii=False, indent=2) + '\n'
def load(name): return json.loads((ARCHIVE / name).read_text())
def clock(n): return f'{n//60}:{n%60:02}'
def one(pattern, text):
    m = re.search(pattern, text, re.S)
    if not m: raise ValueError('Reference field missing: '+pattern)
    return m

def build():
    text = REFERENCE.read_text()
    # Parse actual supplied values, never a second per-week dose table.
    weekly_text = text.split('WEEKLY SESSIONS\n',1)[1].split('EASY SESSION STRUCTURE',1)[0]
    weeks = {int(m.group(1)):m.group(2) for m in re.finditer(r'Week (\d+)[^\n]*\n(.*?)(?=\nWeek \d+|\Z)', weekly_text, re.S)}
    assert set(weeks)==set(range(1,11))
    warm = text.split('COMMON TUESDAY STRUCTURE',1)[1].split('WEEKLY SESSIONS',1)[0]
    wu = int(one(r'- (\d+) seconds easy',warm)[1])
    acc, acc_rec = map(int, one(r'(\d+) seconds relaxed acceleration\.\n(\d+) seconds very easy',warm).groups())
    assert 'Three repetitions' in warm and 'no recovery after the final' in warm
    cooldown = int(one(r'Cooldown:\n- (\d+) seconds',warm)[1])
    easy = text.split('EASY SESSION STRUCTURE',1)[1].split('STRIDE SESSIONS',1)[0]
    easy_wu=int(one(r'- (\d+) sec very easy warm-up',easy)[1]); easy_co=int(one(r'- (\d+) sec very easy cooldown',easy)[1])
    stride = text.split('STRIDE SESSIONS',1)[1].split('FINAL TEST',1)[0]
    stride_blocks={}
    for key,part in [(3,stride.split('W3 and W5 Friday',1)[1].split('W10 Friday',1)[0]),(10,stride.split('W10 Friday',1)[1])]:
        a=int(one(r'- (\d+) sec very easy warm-up',part)[1]); main=int(one(r'- ([\d,]+) sec',part.split('warm-up.',1)[1])[1].replace(',',''))
        count,work,rec=map(int,one(r'- (\d+) × \((\d+) sec relaxed stride \+ (\d+) sec very easy\)',part).groups())
        co=int(one(r'- (\d+) sec easy cooldown',part)[1])
        assert 'including the last' in part
        stride_blocks[key]=(a,main,count,work,rec,co)
    final=text.split('The later ChatGPT performance draft proposed:',1)[1].split('The selected attachment',1)[0]
    assert '- 10 min easy.' in final and '3 × (20 sec relaxed acceleration + 40 sec easy)' in final and '- 2 min easy walking/jogging' in final and '- 10,000 m test.' in final and '- 5 min easy walking/jogging.' in final
    source=load('SOURCE.json'); schedule=load('SCHEDULE_CANDIDATE.json')
    source.update(title='General Hybrid 10K PB — selected performance running and strength', authority_source='RUNNING_SELECTION_2026_11_03.md + HYBRID_10K_PERFORMANCE_RUNNING_REFERENCE_v1.md; strength unchanged', publication_approved=False, content_status='RUNNING_SELECTED_STRENGTH_SELECTED_FULL_D8_PENDING')
    source['shared_rules_location']='RUNNING_SELECTION_2026_11_03.md; exact M2.3 rules unchanged'
    focuses=['Performance foundation','Threshold build','Threshold build','Consolidation','Threshold development','10K specificity plus short-5K Friday','Standard build; not consolidation','Peak Tuesday specificity; lighter Friday','Reduce fatigue','Taper and distance-ended 10K test']
    for w in source['weeks']: w['focus']=focuses[w['week']-1]
    runs=[]
    for s in source['sessions']:
        if s['type']!='running': continue
        w,d=s['week'],s['day']; content=weeks[w]; steps=[]
        def phase(role, seconds, label, target='none', notes='', distance=False):
            t={'kind':'none'} if target=='none' else {'kind':'heart_rate_zone_ref','zone_ref':'athlete_confirmed_zone_2'} if target=='zone2' else {'kind':'alpha_quality_pace_v1','category':target}
            steps.append({'kind':'atomic','step_id':f"{s['session_id']}-PERF-P{len(steps)+1:02}",'role':role,'duration':{'kind':'distance','millimetres':10000000} if distance else {'kind':'time','milliseconds':seconds*1000},'target':t,'label':label,'notes':notes})
        def cycles(n,work,rec,label,target='none',after=False):
            for i in range(n):
                phase('work',work,label,target,'Relaxed and controlled, not a sprint.' if target=='none' else 'Use the athlete’s separately reviewed and accepted personalised target.')
                if i<n-1 or after: phase('recovery',rec,'Very easy recovery' if target=='none' else 'Easy recovery',notes='Very easy running.' if target=='none' else 'Easy effort.')
        if d==2:
            n,work,rec=map(int,one(r'Tuesday: (\d+) × (\d+) sec.*?;\s*(\d+) sec easy between',content).groups())
            target='threshold' if 'sec threshold;' in content else '10k_specific'
            title='Consolidation threshold' if w==4 else 'Threshold intervals' if target=='threshold' else 'Peak 10K specificity' if w==8 else 'Taper sharpening' if w==10 else '10K intervals'
            phase('warm_up',wu,'Easy warm-up',notes='Easy running.')
            cycles(3,acc,acc_rec,'Relaxed acceleration',after=True)
            cycles(n,work,rec,'Threshold running' if target=='threshold' else '10K pace running',target)
            phase('cool_down',cooldown,'Very easy cooldown',notes='Very easy running or walking; walking is included in session time.')
        elif d==5 and w in [3,5,10]:
            a,main,n,work,rec,co=stride_blocks[10 if w==10 else 3]
            title='Easy run with relaxed strides'
            phase('warm_up',a,'Very easy warm-up',notes='Very easy running.')
            phase('work',main,'Easy running' if w==10 else 'Zone 2 running','none' if w==10 else 'zone2',notes='Easy running.' if w==10 else 'Use the athlete-confirmed numerical Zone 2 range.')
            cycles(n,work,rec,'Relaxed stride',after=True)
            phase('cool_down',co,'Easy cooldown',notes='Easy running.')
        elif d==5 and w in [6,7,8,9]:
            a=int(one(r'Friday:\n- (\d+) sec easy warm-up',content)[1]);co=int(one(r'- (\d+) sec easy cooldown',content)[1])
            n,work,rec=map(int,one(r'- (\d+) × (\d+) sec at approved short-5K pace;\n(\d+) sec easy BETWEEN',content).groups())
            title='Short-5K intervals — lighter Friday' if w==8 else 'Short-5K intervals'
            phase('warm_up',a,'Easy warm-up',notes='Easy running.')
            cycles(n,work,rec,'Short-5K pace running','short_5k')
            phase('cool_down',co,'Easy cooldown',notes='Easy running.')
        elif d==7 and w==10:
            title='10K final assessment'
            phase('warm_up',600,'Easy warm-up',notes='Easy running.')
            cycles(3,20,40,'Relaxed acceleration',after=True)
            phase('recovery',120,'Easy settling',notes='Easy walking or jogging before the test.')
            phase('work',0,'10,000 m test',notes='Distance-ended test; confirm actual external distance.',distance=True)
            phase('cool_down',300,'Easy cooldown',notes='Easy walking or jogging. No additional walks or drills are appended.')
        else:
            day={3:'Wednesday',5:'Friday',7:'Sunday'}[d]
            minutes=int(one(day+r': (\d+)-minute Zone 2 session',content)[1])
            title='Long Zone 2 run' if d==7 else 'Zone 2 run'
            phase('warm_up',easy_wu,'Very easy warm-up',notes='Very easy running.')
            phase('work',minutes*60-easy_wu-easy_co,'Zone 2 running','zone2',notes='Use the athlete-confirmed numerical Zone 2 range.')
            phase('cool_down',easy_co,'Very easy cooldown',notes='Very easy running; walking permitted.')
        seconds=sum(x['duration'].get('milliseconds',0) for x in steps)//1000
        distance=sum(x['duration'].get('millimetres',0) for x in steps)//1000
        s.update(title=title,kind='distance_test' if distance else 'timed_quality' if d==2 or d==5 and w in FRI_QUALITY else 'easy_strides' if d==5 and w in [3,5,10] else 'easy',steps=steps,notes=[],content_status='FOUNDER_SELECTED_RUNNING_2026_11_03',prescribed_total_running_minutes=None,prescribed_programmed_duration_seconds=seconds,work_distance_metres=distance or None)
        for k in ['quality_category','reference_conflict','superseded_steps']:s.pop(k,None)
        runs.append({'source_session_id':s['session_id'],'source_week':w,'source_day':d,'fixed_seconds':seconds,'distance_metres':distance,'content_status':'FOUNDER_SELECTED_RUNNING_2026_11_03_FULL_D8_PENDING','workout':{'schema_version':1,'workout_id':s['session_id']+'-PERF-V1','title':title,'notes':'','steps':steps}})
    schedule['programme'].update(name=source['title'],description='Selected 3 November performance running and unchanged strength. Full D8 pending; unpublished.',coaching_intent='General ten-week 10K PB programme for a fit, competent runner')
    for r in schedule['sessions']:
        s=next(s for s in source['sessions'] if s['session_id']==r['session_key'])
        if s['type']=='running':
            r.update(protocol_id=s['session_id']+'-PERFORMANCE-20261103-R2',revision_number=2,title=s['title'])
    for w in schedule['weeks']:
        w['title']=focuses[w['week_number']-1]
        for d in w['days']:
            for slot in d['slots']:
                s=next(s for s in source['sessions'] if s['session_id']==slot['session_key'])
                if s['type']=='running':
                    d['title']=s['title'];slot['display_title']=s['title'];slot['progression']['prescription_summary']=clock(s['prescribed_programmed_duration_seconds'])+(' + actual 10K time' if s['work_distance_metres'] else '')+'; exact selected performance reference; no automatic progression.'
    weekly=[{'week':w,'timed_seconds':sum(r['fixed_seconds'] for r in runs if r['source_week']==w),'distance_metres':sum(r['distance_metres'] for r in runs if r['source_week']==w)} for w in range(1,11)]
    supplied=[int(m)*60+int(s) for m,s in re.findall(r'W\d+: (\d+):(\d+)',text.split('CHECKED WEEKLY SESSION-TIME TOTALS',1)[1])]
    assert [w['timed_seconds'] for w in weekly[:9]]==supplied[:9]
    assert weekly[-1]['timed_seconds']-1200==supplied[-1]
    assert len(runs)==40 and len(source['sessions'])==70
    audit={'running_reference_sha256':sha(REFERENCE.read_bytes()),'selection_sha256':sha(SELECTION.read_bytes()),'archived_source_sha256':sha((ARCHIVE/'SOURCE.json').read_bytes()),'runs':40,'strength_sessions':20,'rest_days':10,'weekly':weekly,'strength_preserved_byte_exact':True,'catalogue_evidence_preserved_byte_exact':True,'missing_catalogue_occurrences':28,'full_D8':False,'published':False}
    result={'SOURCE.json':encode(source),'RUNNING_BODIES.json':encode(runs),'SCHEDULE_CANDIDATE.json':encode(schedule),'AUDIT.json':encode(audit), 'STRENGTH_REVIEW_GRAPHS.json':(ARCHIVE/'STRENGTH_REVIEW_GRAPHS.json').read_text(),'IDENTITY_INTAKE.json':(ARCHIVE/'IDENTITY_INTAKE.json').read_text()}
    lines=['# General Hybrid 10K PB — active selected performance source','','Running prescriptions selected 2026-11-03. Strength is unchanged. Full D8, founder usability, catalogue retention and Gate A remain open. No publication/assignment authority.','','All session time includes prescribed timed preparation/recoveries/cooldown; permitted walking is not running volume. No external walks/drills are added to running.','']
    archived_review=(ARCHIVE/'TEN_WEEK_REVIEW.md').read_text()
    lines += [archived_review[archived_review.index('## Exact strength setup, preparation and logging'):archived_review.index('## Controlling targets')].strip(), '',
              archived_review[archived_review.index('## Approved personalised quality-target rules'):archived_review.index('## Progression, fatigue and taper boundaries')].strip(), '',
              '## Catalogue and approval boundary', '',
              'All 20 complete strength sessions remain blocked by 28 occurrences across the three missing exact library setups. Strength/evidence bytes are unchanged; no catalogue identities, publication or assignment are fabricated. Full D8 and usability acceptance remain pending.', '']
    strengths={g['source_session_id']:g for g in load('STRENGTH_REVIEW_GRAPHS.json')}
    for w in range(1,11):
        lines += [f'## Week {w} — {focuses[w-1]}',f"Timed session total: {clock(weekly[w-1]['timed_seconds'])}"+(' + actual 10K elapsed time.' if w==10 else '.'),'']
        for s in [s for s in source['sessions'] if s['week']==w]:
            lines += [f"### {s['weekday']} — {s['title']}",'']
            if s['type']=='rest': lines+=['Rest.',''];continue
            if s['type']=='strength':
                for block in strengths[s['session_id']]['blocks']:
                    if block['content']:lines.append(block['content'])
                    for e in block['exercises']:
                        p=e['prescription'];lines += [f"- **{e['display_label_override']}**: {p['sets']} × {p['authored_details']['source_repetitions_or_duration']}; RIR {p['authored_details']['source_rir']}; rest {p['authored_details']['source_rest_seconds']} sec. {p.get('coach_cue','')} Tempo: {p.get('tempo','')}"]
                lines+=[''];continue
            for i,x in enumerate(s['steps'],1):
                amount=clock(x['duration']['milliseconds']//1000) if x['duration']['kind']=='time' else '10,000 m (distance ended)'
                t=x['target'];target='Athlete-confirmed Zone 2' if t['kind']=='heart_rate_zone_ref' else 'Personalised '+{'threshold':'threshold','10k_specific':'current 10K','short_5k':'short-5K'}[t['category']] if t['kind']=='alpha_quality_pace_v1' else 'Authored effort, no fixed pace/HR'
                lines.append(f"{i}. **{x['label']} — {amount}**. {target}. {x['notes']}")
            lines += ['',f"Total {clock(s['prescribed_programmed_duration_seconds'])}"+(' + actual 10K elapsed time.' if s['work_distance_metres'] else '.'),'']
    result['TEN_WEEK_REVIEW.md']='\n'.join(lines).rstrip()+'\n'
    return result

FRI_QUALITY={6,7,8,9}
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args()
    data=build();DEST.mkdir(exist_ok=True)
    for name,content in data.items():
        if args.check: assert (DEST/name).read_text()==content,name
        else:(DEST/name).write_text(content)
    print('PASS: selected reference regeneration'+(' matches' if args.check else ' written'))
