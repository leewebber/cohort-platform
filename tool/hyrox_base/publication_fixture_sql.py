#!/usr/bin/env python3
"""Offline SQL fixture writer. No sockets, credentials, hosted inputs or authority."""
import argparse,json
from pathlib import Path

def quoted(value):
    return "'"+value.replace("'","''")+"'"
def j(value):return quoted(json.dumps(value,ensure_ascii=False,separators=(',',':')))+'::jsonb'
def write(directory):
    directory=directory.resolve()
    if not str(directory).startswith(('/private/tmp/','/private/var/folders/')):
        raise ValueError('Task-owned temporary fixture directory required')
    d=json.loads((directory/'prepared.json').read_text())
    if d['classification']!='LOCAL_REHEARSAL_ONLY_NOT_AUTHORITATIVE':raise ValueError('Fixture classification required')
    assert all(x['exercise_id'].startswith('EX-901') for x in d['definitions'])
    setup='''\\set ON_ERROR_STOP on
CREATE TABLE public.local_hyrox_ops_data(key text PRIMARY KEY,document jsonb NOT NULL);
CREATE TABLE public.local_hyrox_delivery_fixture(event_id uuid PRIMARY KEY,document jsonb NOT NULL,acknowledged boolean NOT NULL DEFAULT false);
REVOKE ALL ON public.local_hyrox_ops_data, public.local_hyrox_delivery_fixture FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO auth.users(id,aud,role,email,raw_app_meta_data,raw_user_meta_data) VALUES
('bc310000-0000-4000-8000-000000000001','authenticated','authenticated','local-hyrox-coach@example.invalid','{}','{}'),
('bc310000-0000-4000-8000-000000000006','authenticated','authenticated','local-hyrox-athlete@example.invalid','{}','{}'),
('bc310000-0000-4000-8000-000000000007','authenticated','authenticated','local-hyrox-other@example.invalid','{}','{}');
INSERT INTO public.profiles(id,display_name,is_coach,is_athlete) VALUES
('bc310000-0000-4000-8000-000000000001','LOCAL REHEARSAL coach',true,false),
('bc310000-0000-4000-8000-000000000006','LOCAL REHEARSAL athlete',false,true),
('bc310000-0000-4000-8000-000000000007','LOCAL REHEARSAL other',false,true);
INSERT INTO public.coach_athlete_relationships(coach_id,athlete_id,status) VALUES
('bc310000-0000-4000-8000-000000000001','bc310000-0000-4000-8000-000000000006','active'),
('bc310000-0000-4000-8000-000000000001','bc310000-0000-4000-8000-000000000007','active');
CREATE FUNCTION public.local_hyrox_assert(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'LOCAL_HYROX_REHEARSAL:%',label;END IF;END $$;
REVOKE ALL ON FUNCTION public.local_hyrox_assert(boolean,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.local_hyrox_register_source(p jsonb) RETURNS void LANGUAGE plpgsql AS $$
DECLARE existing jsonb; ref jsonb:=p-'blocks'; protocol text:=p->>'protocol_id';BEGIN
 IF protocol NOT LIKE 'LOCAL-HYROX-%' THEN RAISE EXCEPTION 'fixture namespace required';END IF;
 SELECT public.cohort_v3_session_source(ref) INTO existing;
 IF existing IS NOT NULL THEN
   IF existing IS DISTINCT FROM p THEN RAISE EXCEPTION 'local_source_exact_conflict';END IF;
   RETURN;
 END IF;
 IF EXISTS(SELECT 1 FROM public.performance_protocols WHERE protocol_id=protocol) THEN RAISE EXCEPTION 'local_source_identity_conflict';END IF;
 INSERT INTO public.session_lineages(id,display_name) VALUES((p->>'session_lineage_id')::uuid,'LOCAL REHEARSAL '||protocol);
 INSERT INTO public.performance_protocols(protocol_id,name,published,content_kind,authoring_scope,endorsement_status,session_lineage_id,revision_number,lifecycle_status,published_at,owner_id)
 VALUES(protocol,'LOCAL REHEARSAL '||protocol,'true','session','coach_private','coach_authored',(p->>'session_lineage_id')::uuid,(p->>'revision_number')::int,'published',now(),'bc310000-0000-4000-8000-000000000001');
 PERFORM public.cohort_insert_private_protocol_graph(protocol,jsonb_build_object('protocol_id',protocol,'blocks',p->'blocks'));
 IF public.cohort_v3_session_source(ref) IS DISTINCT FROM p THEN RAISE EXCEPTION 'local_source_exact_body_mismatch:%',protocol;END IF;
END $$;
REVOKE ALL ON FUNCTION public.local_hyrox_register_source(jsonb) FROM PUBLIC,anon,authenticated,service_role;
'''
    for x in d['definitions']:
        body=json.loads(x['canonical_text'])
        setup+=f"INSERT INTO public.exercises_v2(exercise_id,name,published) VALUES({quoted(x['exercise_id'])},{quoted(body['canonical_name'])},true);\n"
        setup+=f"INSERT INTO public.local_hyrox_delivery_fixture VALUES(({j(x)}#>>'{{publication,event_id}}')::uuid,{j(x)},false);\n"
    setup+='GRANT SELECT, UPDATE ON public.local_hyrox_delivery_fixture TO supabase_admin; GRANT EXECUTE ON FUNCTION public.local_hyrox_assert(boolean,text) TO supabase_admin;\n'
    setup+='INSERT INTO public.local_hyrox_ops_data VALUES(\'prepared\','+j(d)+');\n'
    (directory/'setup.sql').write_text(setup)
    # Each delivery/registration is a distinct transaction. Completed earlier stages
    # remain after later failure; no compensating deletion/retirement is invented.
    deliver='''\\set ON_ERROR_STOP on
DO $$ DECLARE item record; r jsonb;n int:=0;BEGIN
 FOR item IN SELECT * FROM public.local_hyrox_delivery_fixture ORDER BY event_id LIMIT 9 LOOP
   PERFORM set_config('role','cohort_exercise_version_publisher',true);
   r:=public.retain_published_exercise_event_v1(item.document->>'canonical_text',item.document->'publication',NULL);
   PERFORM set_config('role','none',true);
   PERFORM public.local_hyrox_assert(r->>'status'='retained','initial exercise retention');
 END LOOP;
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.published_exercise_definition_versions WHERE exercise_id LIKE 'EX-901%')=9,'nine commits survive later failed delivery');
 SELECT * INTO item FROM public.local_hyrox_delivery_fixture ORDER BY event_id OFFSET 9 LIMIT 1;
 BEGIN
   PERFORM set_config('role','cohort_exercise_version_publisher',true);
   r:=public.retain_published_exercise_event_v1(item.document->>'canonical_text',item.document->'publication','{}');
   RAISE EXCEPTION 'invalid retirement accepted';
 EXCEPTION WHEN invalid_parameter_value OR raise_exception THEN
   IF SQLERRM='invalid retirement accepted' THEN RAISE;END IF;
 END;
 PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.published_exercise_definition_versions WHERE exercise_id LIKE 'EX-901%')=9,'failed event rolls back only that event');
END $$;
DO $$ DECLARE item record;r jsonb;changed text;BEGIN
 FOR item IN SELECT * FROM public.local_hyrox_delivery_fixture ORDER BY event_id LOOP
   PERFORM set_config('role','cohort_exercise_version_publisher',true);
   r:=public.retain_published_exercise_event_v1(item.document->>'canonical_text',item.document->'publication',NULL);
   PERFORM set_config('role','none',true);
   PERFORM public.local_hyrox_assert(r->>'status'='retained','exact retry/recovery');
   UPDATE public.local_hyrox_delivery_fixture SET acknowledged=true WHERE event_id=item.event_id;
 END LOOP;
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.published_exercise_definition_versions WHERE exercise_id LIKE 'EX-901%')=27,'all 27 retained');
 PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.local_hyrox_delivery_fixture WHERE NOT acknowledged),'delivery recovery acknowledged');
 SELECT * INTO item FROM public.local_hyrox_delivery_fixture ORDER BY event_id LIMIT 1;
 changed:=public.cohort_tracking_canonical_text((item.document->>'canonical_text')::jsonb||'{"canonical_name":"CONFLICT"}');
 BEGIN
   PERFORM set_config('role','cohort_exercise_version_publisher',true);
   r:=public.retain_published_exercise_event_v1(changed,item.document->'publication',NULL);
   RAISE EXCEPTION 'version conflict accepted';
 EXCEPTION WHEN unique_violation THEN NULL;END;
 PERFORM set_config('role','none',true);
END $$;
SELECT 'LOCAL_HYROX_EXERCISE_DELIVERY_RECOVERY=PASS';
'''
    (directory/'deliver.sql').write_text(deliver)
    register='\\set ON_ERROR_STOP on\n'
    first=j(d['sources'][0]['source'])
    register+="""BEGIN;
CREATE FUNCTION public.local_hyrox_source_fault() RETURNS trigger LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'injected_local_source_failure';END $$;
CREATE TRIGGER local_hyrox_source_fault BEFORE INSERT ON public.session_block_exercises FOR EACH ROW EXECUTE FUNCTION public.local_hyrox_source_fault();
DO $$ BEGIN
 BEGIN PERFORM public.local_hyrox_register_source("""+first+""");RAISE EXCEPTION 'source injection did not fail';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'injected_local_source_failure' THEN RAISE;END IF;END;
 PERFORM public.local_hyrox_assert(NOT EXISTS(SELECT 1 FROM public.performance_protocols WHERE protocol_id LIKE 'LOCAL-HYROX-%'),'source transaction rolls parent/blocks back');
END $$;
ROLLBACK;
"""
    for r in d['sources']:register+='SELECT public.local_hyrox_register_source('+j(r['source'])+');\n'
    register+="SELECT 'LOCAL_HYROX_48_SOURCE_REGISTRATION=PASS';\n"
    (directory/'register.sql').write_text(register)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('directory',type=Path);args=parser.parse_args();write(args.directory)
