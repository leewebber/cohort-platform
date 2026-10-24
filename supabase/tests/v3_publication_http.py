"""Actual loopback HTTP/Auth/producer/admission/SQL proof. Every source/event,
identity, credential and capability membership here is a disposable fixture.
This implements a fixture upstream for the supported adapter contract, not a real
producer. Never target a linked project or output local credentials.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

workdir=Path(sys.argv[1]).resolve()
root=Path(sys.argv[2]).resolve()
pass_name=sys.argv[3]
assert workdir.name.startswith('sprint12_gate.') and pass_name in ('fresh','repeat')
container=os.environ['SPRINT12_DB_CONTAINER']; project=os.environ['SPRINT12_PROJECT_ID']
assert container=='supabase_db_'+project and project.startswith('s12g')
status=json.loads(subprocess.check_output(['supabase','status','-o','json','--workdir',str(workdir)],stderr=subprocess.DEVNULL))
api=status['API_URL']; assert urllib.parse.urlparse(api).hostname=='127.0.0.1' and api.startswith('http://')
secret=status['JWT_SECRET'].encode();anon=status['ANON_KEY'];service=status['SERVICE_ROLE_KEY']
fixture=json.loads((root/'server/trusted_plan_package_import/test/fixtures/authoritative_v3.json').read_text())
coach='bc230000-0000-4000-8000-000000000001';athlete='bc230000-0000-4000-8000-000000000002'
receive='/v1/founder/exercise-publication-events/receive'; publish='/v1/founder/plan-packages/publish-v3'
checks=0; upstream_calls=[]; events={}; processes=[]; logs=[]; auth_tokens={}
source_credential='disposable-source-'+str(uuid.uuid4())

def check(ok,label):
 global checks
 if not ok: raise AssertionError(label)
 checks+=1

def canon(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def digest(value):return hashlib.sha256(canon(value).encode()).hexdigest()
def b64(data):return base64.urlsafe_b64encode(data).rstrip(b'=').decode()
def token(subject=coach,role='authenticated'):
 if role=='authenticated' and subject in auth_tokens:return auth_tokens[subject]
 data=b64(b'{"alg":"HS256","typ":"JWT"}')+'.'+b64(json.dumps({'sub':subject,'role':role,'aud':'authenticated','exp':int(time.time())+3600}).encode())
 return data+'.'+b64(hmac.new(secret,data.encode(),hashlib.sha256).digest())
def sql(query):
 return subprocess.check_output(['docker','exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1','-c',query],text=True,stderr=subprocess.PIPE).strip()
def sqlfile(path):
 with open(path) as f:subprocess.run(['docker','exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],stdin=f,check=True,stdout=subprocess.DEVNULL)
def counts():
 return json.loads(sql("SELECT jsonb_build_object('versions',(SELECT count(*) FROM published_exercise_definition_versions),'retirements',(SELECT count(*) FROM published_exercise_version_retirements),'programmes',(SELECT count(*) FROM programme_v3_publication_artifacts),'claims',(SELECT count(*) FROM cohort_v3_publication_claims))"))
def snapshot_digest():
 return sql("SELECT md5(coalesce(string_agg(snapshot::text,'' ORDER BY occurrence_id),'')) FROM programme_occurrence_v3_prescription_snapshots")
def request(url,body=None,bearer=None,method='POST',headers=None):
 h={'content-type':'application/json',**(headers or {})}
 if bearer is not None:h['authorization']='Bearer '+bearer
 req=urllib.request.Request(url,data=None if body is None else json.dumps(body).encode(),headers=h,method=method)
 try:
  with urllib.request.urlopen(req,timeout=30) as r:
   data=r.read();return r.status,json.loads(data) if data else None
 except urllib.error.HTTPError as e:
  data=e.read()
  try:result=json.loads(data)
  except Exception:result=None
  return e.code,result

def add(kind,artifact,event_id=None,reference=None):
 event_id=event_id or str(uuid.uuid4())
 if reference is None:
  if kind=='programme_approved':reference='disposable-approved-programme'
  elif kind=='exercise_published':reference=artifact['publication']['source_reference']
  else:reference=artifact['retirement']['source_reference']
 events[event_id]={'contract':'cohort.trusted-publication-event.v1','event_id':event_id,'kind':kind,
  'approval':{'status':'approved','reference':reference},'artifact':artifact}
 return event_id

class Source(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  if self.headers.get('authorization')!='Bearer '+source_credential:
   self.send_response(403);self.end_headers();return
  event_id=self.path.removeprefix('/events/')
  upstream_calls.append(event_id)
  if not self.path.startswith('/events/') or event_id not in events:
   self.send_response(404);self.end_headers();return
  self.send_response(200);self.send_header('content-type','application/json');self.end_headers()
  self.wfile.write(json.dumps(events[event_id]).encode())

upstream=ThreadingHTTPServer(('127.0.0.1',0),Source)
threading.Thread(target=upstream.serve_forever,daemon=True).start()

def runtime(enabled=True,producer=None,source_token=None):
 with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 env={**os.environ,'SUPABASE_URL':api,'SUPABASE_ANON_KEY':anon,'SUPABASE_SERVICE_ROLE_KEY':service,
  'FOUNDER_EMAIL_ALLOWLIST':'http-fixture-founder@example.invalid','BIND_ADDRESS':'127.0.0.1','PORT':str(port),
  'TRUSTED_V3_PUBLICATION_ENABLED':str(enabled).lower(),
  'PUBLICATION_EVENT_SOURCE_URL':f'http://127.0.0.1:{upstream.server_port}/events/',
  'PUBLICATION_EVENT_SOURCE_TOKEN':source_token or source_credential,
  'EXERCISE_VERSION_PRODUCER_TOKEN':producer or token(role='cohort_exercise_version_publisher')}
 log=workdir/('runtime-'+pass_name+'-'+str(port)+'.log');f=log.open('w');logs.append(log)
 proc=subprocess.Popen([str(workdir/'trusted-plan-import')],env=env,stdout=f,stderr=f);f.close();processes.append(proc)
 url='http://127.0.0.1:'+str(port)
 deadline=time.monotonic()+15
 while time.monotonic()<deadline:
  if proc.poll() is not None:raise AssertionError('fixture runtime did not start')
  try:
   if request(url+'/healthz',method='GET')[0]==200:return url
  except (OSError,urllib.error.URLError):pass
  time.sleep(.03)
 raise AssertionError('fixture runtime health timeout')

def event_request(url,path,event_id,expected=200,bearer=None,extra=None):
 code,result=request(url+path,{'event_id':event_id,**(extra or {})},bearer or token())
 check(code==expected,'HTTP status '+path+' expected '+str(expected)+' got '+str(code))
 return result

try:
 sqlfile(root/'docs/checkpoints/hyrox_v3_http/POSTCHECK.sql')
 check(True,'exact wrapper body owner search-path and effective permissions')
 # Real local GoTrue account/session issuance; raw signed fixture JWTs without an
 # Auth session are intentionally insufficient for the HTTP Founder boundary.
 for alias,email in [(coach,'http-fixture-founder@example.invalid'),(athlete,'http-fixture-athlete@example.invalid')]:
  password='Disposable-'+str(uuid.uuid4())
  code,_=request(api+'/auth/v1/admin/users',{'email':email,'password':password,'email_confirm':True},service,headers={'apikey':anon})
  check(code in (200,201),'local Auth fixture created')
  code,session=request(api+'/auth/v1/token?grant_type=password',{'email':email,'password':password},headers={'apikey':anon})
  check(code==200 and isinstance(session.get('access_token'),str),'local Auth fixture session issued')
  auth_tokens[alias]=session['access_token']
 # No memberships are added by migration. This fixture alone simulates the separately
 # provisioned PostgREST producer. It is revoked below and the whole DB is disposable.
 check(sql("SELECT has_function_privilege('service_role','public.retain_published_exercise_event_v1(text,jsonb,jsonb)','EXECUTE')")=='f','no ordinary service producer grant')
 check(sql("SELECT count(*) FROM pg_auth_members WHERE roleid='cohort_exercise_version_publisher'::regrole AND (set_option OR inherit_option)")=='0','schema installs no usable producer membership')
 sql('GRANT cohort_exercise_version_publisher TO authenticator WITH INHERIT FALSE, SET TRUE')
 url=runtime();disabled=runtime(enabled=False)
 check(request(url+'/unknown',method='GET')[0]==404,'legacy unknown route')
 check(request(url+'/v1/founder/plan-packages/import',method='GET')[0]==405,'legacy method')
 check(request(url+'/v1/founder/plan-packages/import',{},None)[0]==401,'legacy authentication')
 dummy=str(uuid.uuid4());before=len(upstream_calls)
 event_request(disabled,receive,dummy,503)
 event_request(url,receive,dummy,403,bearer=token(athlete))
 event_request(url,receive,dummy,401,bearer=token()+'forged')
 check(request(url+receive,{'event_id':dummy},None)[0]==401,'missing bearer')
 check(request(url+receive,{'event_id':dummy},service)[0] in (401,503),'service JWT is not Founder user identity')
 check(len(upstream_calls)==before,'rejected caller never reaches producer')
 event_request(url,receive,dummy,422,extra={'approved':True,'canonical_text':'{}'})
 event_request(url,receive,dummy,409)

 # Real Auth and configured source resolution; missing retained definitions refuse first.
 package=copy.deepcopy(json.loads(fixture['payload']['package_canonical_json']))
 package['programme']['lineage_code']='HTTP-V3-DISPOSABLE'
 def programme_artifact(package,version_id):
  return {'source':canon(package),'canonical_sha256':digest(package),'programme_version_id':version_id,'owner_id':coach}
 http_version='bc240000-0000-4000-8000-000000000040'
 programme_event=add('programme_approved',programme_artifact(package,http_version))
 event_request(url,publish,programme_event,503)
 check(counts()['programmes']==0,'missing definitions never publish')
 exercises={}
 for d in fixture['bundle']['dependencies']:
  e=copy.deepcopy(d['exercise']);exercises[e['exercise_id']]=e
 exercise_events=[]
 for exercise in exercises.values():
  artifact={'canonical_text':exercise['canonical_text'],'publication':exercise['publication'],'retirement':None}
  e=add('exercise_published',artifact,exercise['publication']['event_id']);exercise_events.append(e)
  result=event_request(url,receive,e);check(result['status']=='retained' and result['retired'] is False,'retained trusted full definition')
 check(counts()['versions']==3,'three authoritative versions retained through HTTP')
 with ThreadPoolExecutor(max_workers=6) as pool:
  duplicate=list(pool.map(lambda _:request(url+receive,{'event_id':exercise_events[0]},token()),range(6)))
 check(all(c==200 for c,_ in duplicate) and counts()['versions']==3,'concurrent duplicate event is idempotent')

 # Run established canonical start/rollback/history proof, using definitions retained
 # through this HTTP path. Revoke fixture membership for the original security gate.
 inputs=workdir/'inputs.json';inputs.write_text(sql((root/'supabase/tests/sql/hyrox_authoritative_inputs.sql').read_text()))
 subprocess.run(['dart','--packages='+str(root/'server/trusted_plan_package_import/.dart_tool/package_config.json'),str(root/'server/trusted_plan_package_import/tool/authoritative_fixture.dart'),str(inputs),str(workdir/'payload.sql')],check=True)
 sqlfile(workdir/'payload.sql')
 sqlfile(root/'supabase/tests/sql/gate_v3_admission_consent_start.sql')
 sql('REVOKE cohort_exercise_version_publisher FROM authenticator')
 sqlfile(root/'supabase/tests/sql/gate_v3_security.sql')
 sqlfile(root/'supabase/tests/sql/gate_v3_rollback_history.sql')
 frozen=snapshot_digest()
 sql('GRANT cohort_exercise_version_publisher TO authenticator WITH INHERIT FALSE, SET TRUE')
 initial=counts()
 result=event_request(url,publish,programme_event);check(result['status']=='published','HTTP approved artifact publishes via existing SQL')
 result=event_request(url,publish,programme_event);check(result['status']=='already_published','HTTP publication retry uses exact version')
 check(counts()['programmes']==initial['programmes']+1 and counts()['claims']==0,'atomic private artifact and no transient claims')
 # Client cannot supply target/owner/version, even while authenticated Founder.
 event_request(url,publish,programme_event,422,extra={'owner_id':athlete})
 bad=copy.deepcopy(events[programme_event]['artifact']);bad['canonical_sha256']='a'*64
 event_request(url,publish,add('programme_approved',bad),422)
 check(counts()['programmes']==initial['programmes']+1,'wrong approved fingerprint cannot publish')
 event_request(url,receive,programme_event,422)

 # Authenticated upstream approval is necessary; client-shaped provenance is insufficient.
 for change in ('pending','wrong_id','wrong_issuer','missing_approval'):
  e=copy.deepcopy(events[exercise_events[0]]);eid=str(uuid.uuid4());e['event_id']=eid
  e['artifact']['publication']['event_id']=eid
  if change=='pending':e['approval']['status']='pending'
  if change=='wrong_id':e['event_id']=str(uuid.uuid4())
  if change=='wrong_issuer':e['artifact']['publication']['issuer']='client'
  if change=='missing_approval':del e['approval']
  events[eid]=e;event_request(url,receive,eid,409 if change=='pending' else 503)
 check(counts()['versions']==3,'forged/unapproved source records cannot retain')

 base=copy.deepcopy(events[exercise_events[0]]['artifact'])
 def version_artifact(version):
  a=copy.deepcopy(base);d=json.loads(a['canonical_text']);d['version']=version;a['canonical_text']=canon(d)
  a['publication']['event_id']=str(uuid.uuid4());a['publication']['source_reference']='disposable-publication-'+version
  return a
 # Conflict is not last-write-wins, including same event on another version.
 conflict=copy.deepcopy(base);d=json.loads(conflict['canonical_text']);d['canonical_name']='Conflicting fixture';conflict['canonical_text']=canon(d)
 event_request(url,receive,add('exercise_published',conflict,conflict['publication']['event_id']),409)
 # Restore source fixture record after deliberately presenting conflicting trusted data.
 events[exercise_events[0]]['artifact']=copy.deepcopy(base)
 reused=version_artifact('700');reused['publication']['event_id']=base['publication']['event_id']
 event_request(url,receive,add('exercise_published',reused,reused['publication']['event_id']),409)
 events[exercise_events[0]]['artifact']=copy.deepcopy(base)
 check(counts()['versions']==3,'conflicting event/version fully rolls back')

 # Out-of-order retirement carries the exact publication proof and full definition.
 retired=version_artifact('701');retirement_id=str(uuid.uuid4())
 retired['retirement']={'issuer':'founder_exercise_publication_v1','event_id':retirement_id,
  'publication_event_id':retired['publication']['event_id'],'source_reference':'disposable-retirement-701','retired_at':'2026-10-24T00:00:00Z'}
 result=event_request(url,receive,add('exercise_retired',retired,retirement_id))
 check(result['retired'] is True,'retirement before publication delivery retains both atomically')
 late=copy.deepcopy(retired);late['retirement']=None
 result=event_request(url,receive,add('exercise_published',late,late['publication']['event_id']))
 check(result['retired'] is True,'late publication never resurrects retained version')
 result=event_request(url,receive,retirement_id);check(result['retired'] is True,'retirement retry idempotent')
 conflict=copy.deepcopy(retired);conflict_id=str(uuid.uuid4());conflict['retirement']['event_id']=conflict_id
 event_request(url,receive,add('exercise_retired',conflict,conflict_id),409)
 check(counts()['retirements']==1,'conflicting retirement never overwrites')

 # Valid capture then invalid retirement must roll back the entire wrapper call.
 rollback=version_artifact('702');rid=str(uuid.uuid4())
 rollback['retirement']={'issuer':'founder_exercise_publication_v1','event_id':rid,
  'publication_event_id':rollback['publication']['event_id'],'source_reference':'disposable-invalid-retirement','retired_at':'2020-01-01T00:00:00Z'}
 before=counts();event_request(url,receive,add('exercise_retired',rollback,rid),422)
 check(counts()==before and sql("SELECT count(*) FROM published_exercise_definition_versions WHERE definition_version='702'")=='0','retirement failure rolls back newly retained definition')

 # Source authentication and actual database capability are independently required.
 wrong_source=runtime(source_token='not-the-source-credential')
 event_request(wrong_source,receive,exercise_events[0],503)
 no_capability=runtime(producer=token(role='authenticated'))
 event_request(no_capability,receive,exercise_events[0],503)
 check(counts()==before,'missing upstream auth/capability has no mutation or service fallback')
 direct={'p_canonical_text':'{}','p_publication':{},'p_retirement':None}
 for role,bearer in [('anon',anon),('authenticated',token()),('service_role',service)]:
  code,_=request(api+'/rest/v1/rpc/retain_published_exercise_event_v1',direct,bearer,headers={'apikey':anon})
  check(code in (401,403,404),'direct '+role+' cannot exercise publisher capability')
 sql('GRANT EXECUTE ON FUNCTION public.retain_published_exercise_event_v1(text,jsonb,jsonb) TO service_role')
 code,_=request(api+'/rest/v1/rpc/retain_published_exercise_event_v1',direct,service,headers={'apikey':anon})
 check(code==403,'even accidental service EXECUTE fails SQL capability guard')
 sql('REVOKE ALL ON FUNCTION public.retain_published_exercise_event_v1(text,jsonb,jsonb) FROM service_role')

 # Existing atomic v3 publisher rolls back partial publication when final artifact fails.
 sql("CREATE FUNCTION public.http_fixture_fault() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'disposable injected artifact failure'; END $$")
 sql('CREATE TRIGGER http_fixture_fault BEFORE INSERT ON programme_v3_publication_artifacts FOR EACH ROW EXECUTE FUNCTION public.http_fixture_fault()')
 second=copy.deepcopy(package);second['programme']['version_number']=2
 rollback_version='bc240000-0000-4000-8000-000000000041'
 second_event=add('programme_approved',programme_artifact(second,rollback_version))
 before=counts();event_request(url,publish,second_event,422)
 check(counts()==before and sql("SELECT count(*) FROM programme_versions WHERE id='"+rollback_version+"'")=='0','HTTP publication final-artifact failure rolls back version and claim')
 sql('DROP TRIGGER http_fixture_fault ON programme_v3_publication_artifacts');sql('DROP FUNCTION public.http_fixture_fault()')
 with ThreadPoolExecutor(max_workers=4) as pool:
  results=list(pool.map(lambda _:request(url+publish,{'event_id':second_event},token()),range(4)))
 check(all(c==200 for c,_ in results),'concurrent approved programme delivery succeeds idempotently')
 check(sum(r['status']=='published' for _,r in results)==1,'exactly one concurrent private publication')
 check(counts()['claims']==0,'no transient claim after concurrent publication')
 # Retiring retained history does not require a currently published identity.
 catalog_retired=version_artifact('703')
 pub_id=catalog_retired['publication']['event_id']
 event_request(url,receive,add('exercise_published',catalog_retired,pub_id))
 exercise_id=json.loads(catalog_retired['canonical_text'])['id']
 sql("UPDATE exercises_v2 SET published=false WHERE exercise_id='"+exercise_id+"'")
 catalog_rid=str(uuid.uuid4())
 catalog_retired['retirement']={'issuer':'founder_exercise_publication_v1','event_id':catalog_rid,
  'publication_event_id':pub_id,'source_reference':'disposable-retirement-after-identity-withdrawal','retired_at':'2026-10-24T00:00:00Z'}
 result=event_request(url,receive,add('exercise_retired',catalog_retired,catalog_rid))
 check(result['retired'] is True,'retained version can retire after catalogue identity withdrawal')
 # Restoration of fixture identity must not resurrect the retired version.
 sql("UPDATE exercises_v2 SET published=true WHERE exercise_id='"+exercise_id+"'")
 result=event_request(url,receive,pub_id)
 check(result['retired'] is True,'identity lifecycle change cannot resurrect version')
 check(snapshot_digest()==frozen,'all started/completed canonical snapshots remain byte-identical')
 sql('REVOKE cohort_exercise_version_publisher FROM authenticator')
 sqlfile(root/'docs/checkpoints/hyrox_authoritative_start/POSTCHECK.sql')
 sqlfile(root/'docs/checkpoints/hyrox_v3_http/POSTCHECK.sql')
 check(True,'exact wrapper postcheck after fixture provisioning removed')
 check(sql("SELECT count(*) FROM pg_auth_members WHERE roleid='cohort_exercise_version_publisher'::regrole AND (set_option OR inherit_option)")=='0','fixture producer membership removed')
 for log in logs:
  text=log.read_text()
  check(all(v not in text for v in [service,anon,source_credential,token(),canon(package)]),'runtime log contains no credentials or artifact body')
 print('LOCAL_FIXTURE_HTTP_AUTH_PRODUCER_SQL_'+pass_name.upper()+'=PASS assertions='+str(checks))
finally:
 for proc in processes:
  proc.terminate()
  try:proc.wait(timeout=10)
  except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=5)
 upstream.shutdown();upstream.server_close()
