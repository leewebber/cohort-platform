import json,os,subprocess,urllib.request,urllib.error,hashlib,sys
from pathlib import Path
from datetime import datetime,timezone
OUT=Path('/private/tmp/m11_live_0431d08_20261104');ROOT=Path('/Users/leewebber/.codex/worktrees/m11-founder-authoring/cohort_platform');TARGET='otnhhdxstdnwccehacku'
sys.path.insert(0,str(ROOT/'tool/catalogue'))
import m11_setup_operation as op

def now():return datetime.now(timezone.utc)
def save(name,obj):
 with (OUT/name).open('x') as f:json.dump(obj,f,indent=2);f.write('\n')
def token():
 r=subprocess.run(['security','find-generic-password','-s','Supabase CLI','-w'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 if r.returncode:raise RuntimeError('Existing operational authentication unavailable')
 return r.stdout.decode().strip()
def api(path,method='GET',data=None):
 req=urllib.request.Request('https://api.supabase.com/v1/projects/'+TARGET+path,method=method,data=None if data is None else json.dumps(data).encode(),headers={'Authorization':'Bearer '+token(),'Content-Type':'application/json'})
 captured=now().isoformat()
 try:
  with urllib.request.urlopen(req,timeout=45) as r:
   raw=r.read();meta={'method':method,'path':path.split('?')[0],'http_status':r.status,'started_at':captured,'captured_at':now().isoformat(),'raw_sha256':hashlib.sha256(raw).hexdigest(),'request_id':r.headers.get('x-request-id') or r.headers.get('sb-request-id'),'cf_ray':r.headers.get('cf-ray')}
   with (OUT/'api-journal.jsonl').open('a') as f:f.write(json.dumps(meta)+'\n')
   return json.loads(raw) if raw.strip() else None,meta,raw
 except urllib.error.HTTPError as e:
  # Never print a response body: a login failure can contain a generated password.
  raise RuntimeError('Management endpoint refused HTTP '+str(e.code)) from None
 except Exception as e:raise RuntimeError('Management response failure: '+type(e).__name__) from None

def readonly(sql):
 d,m,raw=api('/database/query/read-only','POST',{'query':sql})
 return {'data':d,'metadata':m},raw

class TaskOperator(op.Psql):
    def run(self, sql):
        # Normal session metadata; Supavisor did not forward application_name.
        return super().run("SET application_name='m11_live_0431d08_20261104';\n" + sql)
