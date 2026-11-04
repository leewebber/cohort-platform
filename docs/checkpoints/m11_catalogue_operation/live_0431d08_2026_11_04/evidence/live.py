from support import *
from datetime import timedelta
LABEL='m11_live_0431d08_20261104'
class BoundedOperator(TaskOperator):
    deadline=None
    def run(self,sql):
        assert self.deadline is not None and (self.deadline-now()).total_seconds()>90,'Insufficient native lifetime for bounded SQL/readback; no replacement'
        return super().run(sql)

def closeout(issued_or_attempted):
    result={'started_at':now().isoformat(),'replacement_issued':False,'temporary_login_use_stopped':True}
    try:
        secure=OUT/'secure'
        if secure.exists():
            for p in secure.iterdir():
                assert p.name in ['pgpass','pg_service.conf'],'Unexpected task secret material'
                p.unlink()
            secure.rmdir()
        result['temporary_material_removed']=not secure.exists()
        if not issued_or_attempted:
            result['revocation']='NO_CREDENTIAL_ATTEMPT'
        else:
            evidence,_=readonly("SELECT jsonb_build_object('roles',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',rolname,'valid_until',rolvaliduntil) ORDER BY rolname),'[]'::jsonb) FROM pg_roles WHERE rolname LIKE 'cli_login_%'),'backends',(SELECT coalesce(jsonb_agg(jsonb_build_object('user',usename,'application_name',application_name,'state',state) ORDER BY pid),'[]'::jsonb) FROM pg_stat_activity WHERE usename LIKE 'cli_login_%')) AS state;")
            result['precheck']=evidence;s=evidence['data'][0]['state']
            if not s['roles'] and not s['backends']:
                result['revoked_and_connections_closed']=True
                result['revocation']='ALREADY_ABSENT_NO_REISSUANCE'
            else:
                assert [r['name'] for r in s['roles']]==['cli_login_postgres'],'Other CLI role; no broad deletion'
                assert all(b['user']=='cli_login_postgres' and b['application_name']==LABEL for b in s['backends']),'Other operator session; do not affect it'
                data,meta,_=api('/cli/login-role','DELETE')
                result['supported_delete']={'data':data,'metadata':meta}
                post,_=readonly("SELECT jsonb_build_object('cli_roles',(SELECT count(*) FROM pg_roles WHERE rolname LIKE 'cli_login_%'),'cli_backends',(SELECT count(*) FROM pg_stat_activity WHERE usename LIKE 'cli_login_%')) AS state;")
                result['postcheck']=post
                result['revoked_and_connections_closed']=post['data'][0]['state']=={'cli_roles':0,'cli_backends':0}
    except Exception as error:
        result['failure']=str(error) if isinstance(error,(RuntimeError,AssertionError,ValueError)) else type(error).__name__
    finally:
        result['closed_at']=now().isoformat();result['temporary_material_remaining']=(OUT/'secure').exists()
        save('credential-closeout.json',result)
    return result

attempted=False
result={'status':'NOT_STARTED','catalogue_transaction_sent':False}
try:
    ready=json.loads((OUT/'OFFLINE_READY.json').read_text());assert ready['no_further_offline_repair_required']
    for path,h in ready['code_and_command_hashes'].items():assert op.sha(Path(path).read_bytes())==h,'Offline-ready package changed'
    assert op.approved_request()==json.loads((ROOT/'docs/checkpoints/m11_catalogue_operation/OPERATION_REQUEST.json').read_text())
    assert not (OUT/'login-attempt.json').exists(),'Single login attempt already consumed'
    review=json.loads((OUT/'reviewed-preflight.json').read_text());assert review['status']=='FRESH_PREFLIGHT_MATCHES_REVIEWED_SCOPE'
    project,_,_=api('');assert project['id']==TARGET and project['status']=='ACTIVE_HEALTHY','Target not healthy; no resume'
    started=now()
    save('login-attempt.json',{'started_at':started.isoformat(),'attempt':1,'scope':'Founder one fresh live attempt using corrected 0431d08 three-record package','replacement_authorised':False})
    attempted=True
    login,issuer,_=api('/cli/login-role','POST',{'read_only':False})
    assert isinstance(login,dict),'Unknown issuer response'
    save('login-issued.json',{'principal':login.get('role'),'ttl_seconds':login.get('ttl_seconds'),'request_started_at':started.isoformat(),'response_received_at':now().isoformat(),'metadata':issuer,'replacement_authorised':False})
    assert login['role']=='cli_login_postgres' and isinstance(login['password'],str) and isinstance(login['ttl_seconds'],int) and login['ttl_seconds']>0,'Unexpected issuer contract'
    secret=login.pop('password');assert '\n' not in secret and '\r' not in secret
    secure=OUT/'secure';secure.mkdir(mode=0o700)
    pool=json.loads((OUT/'pooler.json').read_text())['data'][0];host=pool['db_host'];port=pool['db_port'];user='cli_login_postgres.'+TARGET
    escaped=secret.replace('\\','\\\\').replace(':','\\:')
    fd=os.open(secure/'pgpass',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:f.write(str(host)+':'+str(port)+':postgres:'+user+':'+escaped+'\n')
    del secret,escaped,login
    fd=os.open(secure/'pg_service.conf',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:
        f.write('[M11Catalogue]\nhost='+host+'\nport='+str(port)+'\ndbname=postgres\nuser='+user+'\npassfile='+str(secure/'pgpass')+'\nsslmode=verify-full\nsslrootcert='+str(OUT/'supabase-prod-ca-2021.crt')+'\nconnect_timeout=10\n')
    os.environ['PGSERVICEFILE']=str(secure/'pg_service.conf');os.environ['PATH']='/opt/homebrew/opt/libpq/bin:'+os.environ['PATH']
    db=BoundedOperator('M11Catalogue',role='postgres')
    db.deadline=started+timedelta(seconds=min(1800,json.loads((OUT/'login-issued.json').read_text())['ttl_seconds']))
    role_query="SELECT jsonb_build_object('session_user',session_user,'role',current_user,'database',current_database(),'expiry',(SELECT rolvaliduntil FROM pg_roles WHERE rolname=session_user),'application_name',current_setting('application_name'),'memberships',(SELECT jsonb_agg(jsonb_build_object('role',r.rolname,'member',m.rolname,'admin',am.admin_option,'inherit',am.inherit_option,'set',am.set_option) ORDER BY r.rolname,m.rolname) FROM pg_auth_members am JOIN pg_roles r ON r.oid=am.roleid JOIN pg_roles m ON m.oid=am.member WHERE m.rolname LIKE 'cli_login_%'),'native_pgaudit_log',current_setting('pgaudit.log',true),'principal_attributes',(SELECT jsonb_build_object('login',rolcanlogin,'super',rolsuper,'inherit',rolinherit,'create_db',rolcreatedb,'create_role',rolcreaterole,'bypass_rls',rolbypassrls) FROM pg_roles WHERE rolname=session_user));"
    combined=db.run(role_query+'\n'+op.state_sql())
    lines=[x for x in combined.splitlines() if x.strip()]
    assert len(lines)==2,'Unexpected operator metadata/state response'
    role=json.loads(lines[0]);raw=lines[1]+b'\n';state=json.loads(raw)
    save('actual-login-and-role.json',role);op.write_new(OUT/'operator-preflight.raw.json',raw)
    assert role['session_user']=='cli_login_postgres' and role['role']=='postgres' and role['database']=='postgres' and role['application_name']==LABEL,'Unexpected operator identity/session'
    assert role['memberships']==[{'set':True,'role':'postgres','admin':False,'member':'cli_login_postgres','inherit':False}],'Unexpected existing-membership contract'
    assert role['principal_attributes']=={'login':True,'super':False,'inherit':False,'create_db':False,'create_role':False,'bypass_rls':False},'Unexpected temporary principal attributes'
    expiry=datetime.fromisoformat(role['expiry']);assert expiry.tzinfo and expiry>now(),'Invalid native expiry'
    db.deadline=min(started+timedelta(minutes=30),expiry)
    save('task-deadline.json',{'request_started_at':started.isoformat(),'actual_provider_expiry':expiry.isoformat(),'task_use_expires_at':db.deadline.isoformat()})
    planning=next(iter(json.loads((OUT/'planning-preflight.json').read_text())['data'][0].values()))
    assert all(state[k]==planning[k] for k in ['columns','constraints','indexes','rows','consumer_guard']),'Fresh preflight drift; no repair while clock runs'
    assert state['identity']['session_user']=='cli_login_postgres' and state['identity']['role']=='postgres'
    assert issuer['cf_ray'],'Missing issuer correlation'
    audit_reference='supabase-cli-login:'+issuer['cf_ray']+':'+LABEL
    snapshot={'kind':'AUTHENTICATED_OPERATOR_PREFLIGHT','target_ref':TARGET,'provenance':'Fresh exact-target authenticated normal operator connection, package 0431d08, verify-full client TLS; corroborated against fresh independent SELECT-only preflight','operator_authorisation':{'principal':'cli_login_postgres','role':'postgres','reference':'Current founder one fresh live attempt using 0431d08; only reviewed three records, readback/retention/closeout; no replacement','expires_at':db.deadline.isoformat()},'audit_reference':audit_reference,'state':state,'raw_state':raw.decode()}
    decisions=json.loads((ROOT/'docs/checkpoints/m11_catalogue_operation/guard_compatibility_2026_11_04/DECISIONS.template.json').read_text())
    for decision in decisions:
        decision['exact_setup_review_reference']='Founder exact WRITE_SET '+op.WRITE_SET_SHA+'; current full-inventory exact setup/lookup review; raw preflight SHA256 '+op.sha(raw)
    save('snapshot.json',snapshot);save('decisions.json',decisions)
    prepared=OUT/'prepared'
    cli=subprocess.run([sys.executable,str(ROOT/'tool/catalogue/m11_setup_operation.py'),'prepare','--snapshot',str(OUT/'snapshot.json'),'--decisions',str(OUT/'decisions.json'),'--request-id','m11-live-three-setups-0431d08-20261104','--out',str(prepared)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=15)
    assert cli.returncode==0,'Published prepare CLI refused; close out without repair'
    pins=json.loads((prepared/'SHA256.json').read_text())
    manifest,seed=op.pinned(prepared/'manifest.json',pins['manifest.json'],prepared/'seed.sql',pins['seed.sql'])
    assert manifest['classification']=='AUTHENTICATED_OPERATOR_PREFLIGHT' and manifest['target_ref']==TARGET
    assert len(manifest['operations'])==3 and all(o['action']=='create' for o in manifest['operations'])
    assert [o['source_variant'] for o in manifest['operations']]==list(op.VARIANTS)
    assert all(len(o['fields'])==7 for o in manifest['operations']),'Unexpected additional catalogue fields'
    assert set(o['fields']['exercise_id'] for o in manifest['operations']).isdisjoint({'EX-029','EX-141','EX-026','EX-037','EX-090'})
    save('APPLY_REVIEW.json',{'reviewed_at':now().isoformat(),'pins':pins,'target':TARGET,'request_id':manifest['request_id'],'principal':'cli_login_postgres','role':'postgres','remaining_native_seconds':(db.deadline-now()).total_seconds(),'operation_fields':[o['fields'] for o in manifest['operations']],'other_writes':[],'canonical_pin_roundtrip':True,'review_basis':'Fresh full expected-state/target-scoped checks and standing founder exact three-record authority; source values fixed by hash-pinned generator','unknown_outcome_recovery':'Same pinned IDs and independent readback; no blind replay or replacement allocation'})
    assert (db.deadline-now()).total_seconds()>90,'Insufficient native lifetime; no forced apply'
    save('apply-attempt.json',{'started_at':now().isoformat(),'pins':pins,'request_id':manifest['request_id'],'target':TARGET})
    result['catalogue_transaction_sent']='ATTEMPTED_OUTCOME_UNKNOWN_UNTIL_ACK'
    ack=op.apply(db,manifest,seed)
    op.write_new(OUT/'apply.json',(op.encode(ack)+'\n').encode())
    assert ack['status']=='APPLIED','Unexpected apply status; same-ID reconciliation only'
    result['catalogue_transaction_sent']=True
    receipt=op.retain(db,manifest,seed,ack,OUT/'retained')
    independent,read_raw=readonly(op.state_sql().replace('(SELECT system_identifier::text FROM pg_control_system())','NULL'))
    op.write_new(OUT/'independent-readback.raw.json',read_raw);save('independent-readback.json',independent)
    after=next(iter(independent['data'][0].values()));operator_after=json.loads((OUT/'retained/readback.raw.json').read_text())
    assert after['identity']['role']=='supabase_read_only_user'
    assert all(after[k]==operator_after[k] for k in ['columns','constraints','indexes','rows','consumer_guard']),'Independent readback differs'
    ids={o['fields']['exercise_id'] for o in manifest['operations']}
    assert [r for r in after['rows'] if r['exercise_id'] not in ids]==state['rows']
    assert len(after['rows'])==len(state['rows'])+3
    assert after['consumer_guard']==state['consumer_guard']
    receipt_sha=op.sha((OUT/'retained/receipt.json').read_bytes())
    audit={'classification':'GENUINE_OPERATOR_OPERATION_WITH_INDEPENDENT_AUTHENTICATED_READBACK','target_ref':TARGET,'request_id':manifest['request_id'],'audit_reference':audit_reference,'pins':pins,'operator_identity':state['identity'],'applied_state_captured_at':json.loads(ack['after_raw'])['captured_at'],'apply_status':ack['status'],'independent_metadata':independent['metadata'],'all_old_rows_exact':True,'all_consumer_guards_equal':True,'receipt_sha256':receipt_sha,'native_pgaudit_log':role['native_pgaudit_log'],'limits':'Trusted operator execution and independent SELECT-only readback; local hashes are not tamper-proof server logs, and no canonical definition/version/publication/audit event is fabricated'}
    save('OPERATOR_AUDIT.json',audit)
    save('OPERATOR_TRUST.json',{'source':'Current authorised operator/audit handoff with independent authenticated readback','receipt_sha256':receipt_sha,'audit_reference':audit_reference,'audit_sha256':op.sha((OUT/'OPERATOR_AUDIT.json').read_bytes())})
    result.update(status='APPLIED_AND_GENUINELY_RETAINED',catalogue_before=len(state['rows']),catalogue_after=len(after['rows']),result_rows=receipt['result_rows'],receipt_sha256=receipt_sha,audit_reference=audit_reference,protected_rows_and_consumers_unchanged=True)
except Exception as error:
    result['status']='STOPPED'
    result['reason']=str(error) if isinstance(error,(RuntimeError,AssertionError,ValueError)) else type(error).__name__
    result['apply_attempt_recorded']=(OUT/'apply-attempt.json').exists()
    result['acknowledgement_retained']=(OUT/'apply.json').exists()
    result['no_repair_replacement_or_blind_replay']=True
finally:
    result['closeout']=closeout(attempted)
    save('LIVE_RESULT.json',result)
    print(json.dumps(result,indent=2))
    if result['status']!='APPLIED_AND_GENUINELY_RETAINED' or not result['closeout'].get('revoked_and_connections_closed'):sys.exit(2)
