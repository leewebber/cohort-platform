"""Disposable loopback API/security and deterministic PostgreSQL lock ordering proof.
No production identities, remote URL, credential output or client computation authority.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

workdir=Path(sys.argv[1]).resolve()
assert workdir.name.startswith('sprint12_gate.')
status=json.loads(subprocess.check_output(['supabase','status','-o','json','--workdir',str(workdir)],stderr=subprocess.DEVNULL))
api=status['API_URL']; assert urllib.parse.urlparse(api).hostname in ('127.0.0.1','localhost') and api.startswith('http://')
secret=status['JWT_SECRET'].encode();key=status['ANON_KEY']
container=os.environ['SPRINT12_DB_CONTAINER'];project=os.environ['SPRINT12_PROJECT_ID']
assert container=='supabase_db_'+project and project.startswith('s12g')
actor='bc230000-0000-4000-8000-000000000003'; foreign='bc230000-0000-4000-8000-000000000002'
version='bc230000-0000-4000-8000-000000000040';checks=0


def check(ok,label):
    global checks
    assert ok,label
    checks+=1


def b64(raw): return base64.urlsafe_b64encode(raw).rstrip(b'=').decode()


def token(subject,role):
    message=b64(b'{"alg":"HS256","typ":"JWT"}')+'.'+b64(json.dumps({'sub':subject,'role':role,'aud':'authenticated','exp':int(time.time())+900}).encode())
    return message+'.'+b64(hmac.new(secret,message.encode(),hashlib.sha256).digest())


def request(path,body=None,subject=None,role='authenticated',method='POST'):
    if subject is None:subject=actor
    req=urllib.request.Request(api+'/rest/v1/'+path,data=None if body is None else json.dumps(body).encode(),method=method,
        headers={'apikey':key,'Authorization':'Bearer '+token(subject,role),'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(req,timeout=30) as r:
            data=r.read();return r.status,json.loads(data) if data else None
    except urllib.error.HTTPError as error: return error.code,json.load(error)


def rpc(name,body,subject=None):
    code,result=request('rpc/'+name,body,subject)
    check(code==200,name+' transport')
    return result


def sql(query):
    return subprocess.check_output(['docker','exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1','-c',query],text=True).strip()


def payload_sql(payload):
    # Generated synthetic values only. Dollar quote is asserted absent from JSON.
    text=json.dumps(payload);assert '$gate$' not in text
    return '$gate$'+text+'$gate$::jsonb'


def held_transaction(label,query,role='authenticated'):
    assert role in ('authenticated','postgres')
    script=f"BEGIN; SET application_name='{label}'; SELECT set_config('request.jwt.claim.sub','{actor}',true); SET LOCAL ROLE {role}; {query}; SELECT pg_sleep(2); COMMIT;"
    process=subprocess.Popen(['docker','exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    process.stdin.write(script);process.stdin.close()
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        if sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{label}' AND wait_event='PgSleep'")=='1':return process
        if process.poll() is not None: raise AssertionError('held transaction failed: '+process.stderr.read())
        time.sleep(0.03)
    raise AssertionError('lock barrier not reached')


def finish(process):
    process.wait(timeout=15);check(process.returncode==0,'held transaction committed')
    return process.stdout.read()


def review(selection):
    r=rpc('review_hyrox_programme_prescription',{'payload':{'assignment_id':assignment,'programme_version_id':version,'selected_revisions':selection,'increment_grams':2500}})
    check(r['status']=='review','authoritative review');return r


def consent(review_result,expected,action='accept'):
    p={'command_id':str(uuid.uuid4()),'assignment_id':assignment,'programme_version_id':version,'action':action,
       'review_id':None if review_result is None else review_result['review_id'],'expected_consent_id':expected}
    return p


def record(metric,value,unit,previous=None):
    return {'command_id':str(uuid.uuid4()),'metric':metric,'value':value,'unit':unit,'test_date':'2026-10-23','source_type':'knownResult',
        'source_reference':'v3-api-'+metric,'previous_revision_id':previous,'correction_reason':None if previous is None else 'synthetic correction'}


assignment=json.loads(sql("SELECT document FROM v3_gate_data WHERE key='assignment-b'"))['id']
foreign_assignment=json.loads(sql("SELECT document FROM v3_gate_data WHERE key='assignment-a'"))['id']
occurrences=json.loads(sql(f"SELECT jsonb_agg(id ORDER BY session_order) FROM programme_schedule_occurrences WHERE assignment_id='{assignment}'"))

# All roles: private version publication is never a client/hash registration API.
for role in ('anon','authenticated','service_role'):
    code,_=request('rpc/retain_published_exercise_definition_v1',{'p_canonical_text':'{}','p_publication':{'issuer':'founder_exercise_publication_v1'}},role=role)
    check(code in (401,403,404),role+' cannot register arbitrary exercise versions')
    code,_=request('rpc/retire_published_exercise_version_v1',{'p_id':'EX-900900','p_version':'7','p_event':{}},role=role)
    check(code in (401,403,404),role+' cannot retire authoritative versions')
    for name,body in [('review_hyrox_programme_prescription',{'payload':{}}),('consent_hyrox_programme_prescription',{'payload':{}}),
                      ('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':str(uuid.uuid4())})]:
        if role=='authenticated':continue
        code,_=request('rpc/'+name,body,role=role);check(code in (401,403,404),role+' cannot act as athlete')
for table in ('published_exercise_definition_versions','published_exercise_version_retirements','hyrox_prescription_dependencies','programme_v3_publication_artifacts','cohort_v3_publication_claims'):
    for role in ('anon','authenticated','service_role'):
        code,_=request(table+'?select=*',role=role,method='GET');check(code in (401,403),'private source table '+role+'/'+table)
for table in ('programme_v3_prescription_reviews','programme_v3_prescription_consents','programme_occurrence_v3_prescription_snapshots'):
    for method in ('POST','PATCH','DELETE'):
        code,_=request(table+('?athlete_id=eq.'+actor if method!='POST' else ''),{'athlete_id':foreign} if method!='DELETE' else None,method=method)
        check(code in (401,403),'direct '+method+' denied '+table)
    code,rows=request(table+'?select=*&athlete_id=eq.'+foreign,method='GET');check(code==200 and rows==[],'cross-owner read '+table)
for supplied in ({'athlete_id':foreign},{'document':{}},{'calculated_prescription':{}},{'package_hash':'a'*64}):
    result=rpc('review_hyrox_programme_prescription',{'payload':{'assignment_id':assignment,'programme_version_id':version,'selected_revisions':{},'increment_grams':2500,**supplied}})
    check(result['status']=='refused','forged review payload')
code,_=request('rpc/review_hyrox_programme_prescription',{'payload':{'assignment_id':foreign_assignment,'programme_version_id':version,'selected_revisions':{},'increment_grams':2500}})
check(code==403,'foreign assignment review')
wrong=rpc('review_hyrox_programme_prescription',{'payload':{'assignment_id':assignment,'programme_version_id':str(uuid.uuid4()),'selected_revisions':{},'increment_grams':2500}})
check(wrong['status']=='refused','wrong programme version')

foreign_consent=json.loads(sql("SELECT document FROM v3_gate_data WHERE key='consent-a'"))['id']
check(rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':foreign_consent})['status']=='refused','wrong programme/assignment consent cannot start')
selected={}
for metric,value,unit in [('run10km','60','minutes'),('row2km','480','seconds'),('backSquat5rm','101.5625','kilograms')]:
    r=rpc('record_hyrox_base_benchmark',{'payload':record(metric,value,unit)});check(r['status']=='recorded','record '+metric);selected[metric]=r['revision_id']
r=review(selected); p=consent(r,None)
accepted=rpc('consent_hyrox_programme_prescription',{'payload':p});head=accepted['consent_id']
check(accepted['status']=='accepted','programme consent')
check(rpc('consent_hyrox_programme_prescription',{'payload':p})['status']=='replayed','consent retry')
with ThreadPoolExecutor(2) as pool:
    results=list(pool.map(lambda _:rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head}),range(2)))
check(sorted(r['status'] for r in results)==['created','resumed'],'duplicate canonical starts')
check(results[0]['bound_prescription_snapshot']==results[1]['bound_prescription_snapshot'],'same immutable snapshot')
first_snapshot=results[0]['bound_prescription_snapshot']
check(len(first_snapshot['prescriptions'])==3,'exact slot prescription scope')
check(any(p['binding']['kind']=='backSquat' and p['calculated']['grams']==80000 for p in first_snapshot['prescriptions']),'SQL nearest tie down')

# Evidence replacement commits before start: old accepted review cannot start.
replacement=record('run10km','65','minutes',selected['run10km'])
process=held_transaction('v3_correction_first','SELECT public.record_hyrox_base_benchmark('+payload_sql(replacement)+')')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
finish(process);check(r['status']=='refused','correction-first refuses stale prescription')
check(sql(f"SELECT count(*) FROM programme_slot_outcomes WHERE assignment_id='{assignment}' AND session_order=2")=='0','no partial outcome after refusal')
selected['run10km']=sql("SELECT revision_id FROM hyrox_base_benchmark_revisions WHERE command_id='"+replacement['command_id']+"'")
r=review(selected);accepted=rpc('consent_hyrox_programme_prescription',{'payload':consent(r,head)});head=accepted['consent_id']

# Withdrawal holds assignment lock first; waiting start refuses after commit.
withdraw=consent(None,head,'withdraw')
process=held_transaction('v3_withdraw_first','SELECT public.consent_hyrox_programme_prescription('+payload_sql(withdraw)+')')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
finish(process);check(r['status']=='refused','withdrawal-first refuses future start')
head=sql("SELECT consent_id FROM programme_v3_prescription_consents WHERE command_id='"+withdraw['command_id']+"'")
r=review(selected);accepted=rpc('consent_hyrox_programme_prescription',{'payload':consent(r,head)});head=accepted['consent_id']

# Start holds the canonical occurrence/assignment and benchmark locks first.
# Concurrent withdrawal waits, then cannot rewrite its committed snapshot.
process=held_transaction('v3_start_first',f"SELECT public.create_or_resume_fixed_programme_occurrence_session('{occurrences[1]}','{head}')->>'status'")
withdraw=consent(None,head,'withdraw')
r=rpc('consent_hyrox_programme_prescription',{'payload':withdraw})
finish(process);check(r['disposition']=='withdrawn','withdraw after start')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
check(r['status']=='resumed','retry preserves start after withdrawal')
second_snapshot=r['bound_prescription_snapshot'];check(second_snapshot['consent']['consent_id']==head,'snapshot retains accepted consent')
check(rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})['bound_prescription_snapshot']==first_snapshot,'earlier started snapshot unchanged')
check(first_snapshot['prescriptions']!=second_snapshot['prescriptions'],'future occurrence uses corrected consent only')

# FK and mutation constraints remain in force after concurrent starts.
check(sql(f"SELECT count(*) FROM programme_occurrence_v3_prescription_snapshots WHERE assignment_id='{assignment}'")=='2','exactly two snapshots')
# Separate synthetic owner: consent replacement and source lifecycle lock order.
actor='bc230000-0000-4000-8000-000000000004'
assignment=json.loads(sql("SELECT document FROM v3_gate_data WHERE key='assignment-c'"))['id']
occurrences=json.loads(sql(f"SELECT jsonb_agg(id ORDER BY session_order) FROM programme_schedule_occurrences WHERE assignment_id='{assignment}'"))
r=review({});accepted=rpc('consent_hyrox_programme_prescription',{'payload':consent(r,None)});head=accepted['consent_id']
r=review({});replacement=consent(r,head)
process=held_transaction('v3_consent_replacement_first','SELECT public.consent_hyrox_programme_prescription('+payload_sql(replacement)+')')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})
finish(process);check(r['status']=='refused','consent replacement wins before start')
head=sql("SELECT consent_id FROM programme_v3_prescription_consents WHERE command_id='"+replacement['command_id']+"'")
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})
check(r['status']=='created','new exact consent starts');old_c=r['bound_prescription_snapshot']
process=held_transaction('v3_source_retirement_first',"UPDATE public.exercises_v2 SET published=false WHERE exercise_id='EX-900900'",role='postgres')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
finish(process);check(r['status']=='refused','source retirement wins before start')
check(rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})['bound_prescription_snapshot']==old_c,'source retirement leaves historical snapshot intact')
sql("UPDATE public.exercises_v2 SET published=true WHERE exercise_id='EX-900900'")
process=held_transaction('v3_start_before_source_change',f"SELECT public.create_or_resume_fixed_programme_occurrence_session('{occurrences[1]}','{head}')->>'status'")
sql("UPDATE public.exercises_v2 SET published=false WHERE exercise_id='EX-900900'")
finish(process)
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
check(r['status']=='resumed','start wins before source retirement');frozen_c=r['bound_prescription_snapshot']
sql("UPDATE public.exercises_v2 SET published=true WHERE exercise_id='EX-900900'")
r=review({});accepted=rpc('consent_hyrox_programme_prescription',{'payload':consent(r,head)})
check(accepted['status']=='accepted','explicit later consent replacement')
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':accepted['consent_id']})
check(r['bound_prescription_snapshot']==frozen_c,'later replacement leaves started consent and target intact')
# Actual exact-version retirement boundary, independently of catalogue state.
actor='bc230000-0000-4000-8000-000000000005'
assignment=json.loads(sql("SELECT document FROM v3_gate_data WHERE key='assignment-d'"))['id']
occurrences=json.loads(sql(f"SELECT jsonb_agg(id ORDER BY session_order) FROM programme_schedule_occurrences WHERE assignment_id='{assignment}'"))
r=review({});accepted=rpc('consent_hyrox_programme_prescription',{'payload':consent(r,None)});head=accepted['consent_id']
process=held_transaction('v3_start_before_version_retire',f"SELECT public.create_or_resume_fixed_programme_occurrence_session('{occurrences[0]}','{head}')->>'status'")
event={'issuer':'founder_exercise_publication_v1','event_id':str(uuid.uuid4()),'publication_event_id':'bc230000-0000-4000-8000-000000000020',
       'source_reference':'disposable-exact-version-retirement','retired_at':'2026-10-23T00:01:00Z'}
retirement_query="SET ROLE cohort_exercise_version_publisher; SELECT public.retire_published_exercise_version_v1('EX-900900','7',"+payload_sql(event)+");"
subprocess.check_output(['docker','exec','-i',container,'psql','-X','-U','supabase_admin','-d','postgres','-At','-v','ON_ERROR_STOP=1','-c',retirement_query],text=True)
finish(process)
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})
check(r['status']=='resumed','start first retains exact version before retirement');version_frozen=r['bound_prescription_snapshot']
r=rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[1],'p_consent_id':head})
check(r['status']=='refused','retired exact version refuses eligible future start')
check(rpc('create_or_resume_fixed_programme_occurrence_session',{'p_occurrence_id':occurrences[0],'p_consent_id':head})['bound_prescription_snapshot']==version_frozen,'version retirement cannot rewrite started snapshot')
check(sql("SELECT count(*) FROM published_exercise_definition_versions WHERE exercise_id='EX-900900' AND definition_version='7'")=='1','published version retained for history')
sql("DO $$ BEGIN BEGIN DELETE FROM public.published_exercise_version_retirements; RAISE EXCEPTION 'retirement delete succeeded'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END; BEGIN UPDATE public.published_exercise_version_retirements SET event='{}'; RAISE EXCEPTION 'retirement update succeeded'; EXCEPTION WHEN integrity_constraint_violation THEN NULL; END; END $$;")
check(True,'retirement events immutable even to privileged mutation')
print(f'V3_LOOPBACK_API_SECURITY_CONCURRENCY=PASS ({checks} assertions; deterministic evidence/consent/source/version/start barriers)')
