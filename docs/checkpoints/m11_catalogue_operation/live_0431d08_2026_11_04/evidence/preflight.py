from support import *
import ssl,socket,struct,re
try:
 pkg=ROOT/'docs/checkpoints/m11_catalogue_operation/live_attempt_8618697_2026_11_04'
 pins=json.loads((pkg/'PACKAGE_SHA256.json').read_text())
 for path,digest in pins['repository_inputs_sha256'].items():
  assert op.sha((ROOT/path).read_bytes())==digest,'Reviewed package input drift: '+path
 assert op.sha(op.state_sql().encode())=='cca4ad67b6e43a3ff87f34cff7607ff80585772e0c93398c685449f114bec75d'
 assert op.approved_request()==json.loads((ROOT/'docs/checkpoints/m11_catalogue_operation/OPERATION_REQUEST.json').read_text())
 project,meta,_=api('')
 safe={k:project.get(k) for k in ['id','name','region','status']}
 save('project.json',{'project':safe,'metadata':meta})
 assert safe['id']==TARGET and safe['name']=='Cohort Field Manual' and safe['region']=='eu-west-1','Target identity drift'
 assert safe['status']=='ACTIVE_HEALTHY','Project not healthy; resume is not authorised'
 health,hm,_=api('/health?services=db&services=auth&services=rest&services=storage&services=realtime')
 save('health.json',{'data':health,'metadata':hm})
 assert len(health)==5 and all(x['healthy'] and x['status']=='ACTIVE_HEALTHY' for x in health),'Services not healthy'
 pool,pm,_=api('/config/database/pooler')
 safe_pool=[{k:e.get(k) for k in ['db_host','db_port','db_user','db_name','pool_mode','identifier','database_type']} for e in pool]
 save('pooler.json',{'data':safe_pool,'metadata':pm})
 assert len(pool)==1 and pool[0]['identifier']==TARGET and pool[0]['database_type']=='PRIMARY'
 assert pool[0]['db_host']=='aws-0-eu-west-1.pooler.supabase.com' and pool[0]['db_port']==6543
 planning,raw=readonly(op.state_sql().replace('(SELECT system_identifier::text FROM pg_control_system())','NULL'))
 op.write_new(OUT/'planning-preflight.raw.json',raw);save('planning-preflight.json',planning)
 state=next(iter(planning['data'][0].values()))
 old_path=ROOT/'docs/checkpoints/m11_catalogue_operation/resumed_preflight_2026_11_04/evidence/operator-preflight.raw.json'
 old=json.loads(old_path.read_text())
 equality={k:state[k]==old[k] for k in ['columns','constraints','indexes','rows','consumer_guard']}
 assert all(equality.values()),'Unexpected catalogue/schema/protected-consumer drift since retained genuine preflight'
 roles,_=readonly("SELECT jsonb_build_object('roles',(SELECT coalesce(jsonb_agg(rolname ORDER BY rolname),'[]'::jsonb) FROM pg_roles WHERE rolname LIKE 'cli_login_%'),'cli_backends',(SELECT count(*) FROM pg_stat_activity WHERE usename LIKE 'cli_login_%'),'catalogue_triggers',(SELECT coalesce(jsonb_agg(pg_get_triggerdef(oid) ORDER BY tgname),'[]'::jsonb) FROM pg_trigger WHERE tgrelid='public.exercises_v2'::regclass AND NOT tgisinternal),'catalogue_rules',(SELECT coalesce(jsonb_agg(definition ORDER BY rulename),'[]'::jsonb) FROM pg_rules WHERE schemaname='public' AND tablename='exercises_v2')) AS state;")
 save('prior-cli-roles-and-hooks.json',roles)
 rp=roles['data'][0]['state'];assert rp['roles']==[] and rp['cli_backends']==0,'Unexpected other CLI role/session'
 assert rp['catalogue_triggers']==[] and rp['catalogue_rules']==[],'Unexpected catalogue hook'
 decisions=json.loads((ROOT/'docs/checkpoints/m11_catalogue_operation/guard_compatibility_2026_11_04/DECISIONS.template.json').read_text())
 matches=[]
 for intent,decision in zip(op.approved_request()['operations'],decisions):
  content=intent['proposed_catalogue_content']
  fields={'name':content['name'],'equipment':', '.join(content['equipment']),'setup':content['setup_and_execution'],'execution':content['setup_and_execution'],'published':True}
  exact=[r['exercise_id'] for r in state['rows'] if all(r.get(k)==v for k,v in fields.items())]
  collision=[r['exercise_id'] for r in op.slug_lookup_matches(state['rows'],decision['slug'])]
  matches.append({'variant':intent['source_variant'],'exact_matches':exact,'slug_lookup_matches':collision})
 assert all(not x['exact_matches'] and not x['slug_lookup_matches'] for x in matches),'Unexpected target identity/collision; stop for reviewed resolution'
 # Public CA already retrieved from official Supabase source during previous task.
 source=Path('/private/tmp/m11_resume_catalogue_20261104/supabase-prod-ca-2021.crt')
 assert op.sha(source.read_bytes())=='700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7'
 op.write_new(OUT/'supabase-prod-ca-2021.crt',source.read_bytes())
 host=pool[0]['db_host'];port=pool[0]['db_port']
 sock=socket.create_connection((host,port),timeout=10);sock.sendall(struct.pack('!II',8,80877103));assert sock.recv(1)==b'S'
 context=ssl.create_default_context(cafile=str(OUT/'supabase-prod-ca-2021.crt'))
 with context.wrap_socket(sock,server_hostname=host) as tls:
  transport={'verify_full':True,'host':host,'port':port,'tls_version':tls.version(),'certificate_sha256':op.sha(tls.getpeercert(binary_form=True))}
 review={'status':'FRESH_PREFLIGHT_MATCHES_REVIEWED_SCOPE','catalogue_rows':len(state['rows']),'retained_baseline_sha256':op.sha(old_path.read_bytes()),'equality_to_retained_genuine':equality,'targets':matches,'tls':transport,'duplicate_rows_preserved':[r['exercise_id'] for r in state['rows'] if r['slug']=='bulgarian-split-squat'],'single_login_issued':False,'project_resumption_requested':False}
 save('reviewed-preflight.json',review)
 print(json.dumps({'project':safe,'all_five_services_healthy':True,'review':review},indent=2))
except Exception as e:
 reason=str(e) if isinstance(e,(RuntimeError,AssertionError,ValueError)) else type(e).__name__
 save('PREFLIGHT_STOP.json',{'reason':reason,'captured_at':now().isoformat(),'credential_requested':False,'hosted_writes':0,'resume_requested':False})
 print('M1.1 preflight stopped: '+reason);sys.exit(2)
