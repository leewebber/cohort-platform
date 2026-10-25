\set ON_ERROR_STOP on
DO $$ DECLARE before jsonb;after jsonb;v record;event jsonb;r jsonb;BEGIN
 SELECT jsonb_agg(jsonb_build_array(occurrence_id,snapshot) ORDER BY occurrence_id) INTO before FROM public.programme_occurrence_v3_prescription_snapshots WHERE athlete_id='bc310000-0000-4000-8000-000000000006';
 PERFORM public.local_hyrox_assert(jsonb_array_length(before)=48,'48 canonical started snapshots');
 PERFORM public.local_hyrox_assert((SELECT count(*) FROM public.training_session_records WHERE athlete_id='bc310000-0000-4000-8000-000000000006' AND status='completed')=48,'48 complete History records');
 SELECT * INTO v FROM public.published_exercise_definition_versions WHERE exercise_id=(SELECT document#>>'{label_bindings,running}' FROM public.local_hyrox_ops_data WHERE key='prepared');
 event:=jsonb_build_object('issuer','founder_exercise_publication_v1','event_id','bc310000-0000-4000-8000-000000000098','publication_event_id',v.publication->>'event_id','source_reference','LOCAL-REHEARSAL retirement after completion','retired_at','2026-10-25T00:01:00Z');
 PERFORM set_config('role','cohort_exercise_version_publisher',true);
 r:=public.retain_published_exercise_event_v1(v.canonical_text,v.publication,event);
 PERFORM set_config('role','none',true);
 PERFORM public.local_hyrox_assert(r->>'retired'='true','separate retirement retained');
 SELECT jsonb_agg(jsonb_build_array(occurrence_id,snapshot) ORDER BY occurrence_id) INTO after FROM public.programme_occurrence_v3_prescription_snapshots WHERE athlete_id='bc310000-0000-4000-8000-000000000006';
 PERFORM public.local_hyrox_assert(before=after,'historical snapshots unchanged after retirement');
 BEGIN UPDATE public.programme_occurrence_v3_prescription_snapshots SET snapshot='{}' WHERE athlete_id='bc310000-0000-4000-8000-000000000006';RAISE EXCEPTION 'snapshot mutated';EXCEPTION WHEN integrity_constraint_violation THEN NULL;END;
 BEGIN DELETE FROM public.programme_v3_publication_artifacts WHERE programme_version_id='bc310000-0000-4000-8000-000000000040';RAISE EXCEPTION 'artifact deleted';EXCEPTION WHEN integrity_constraint_violation THEN NULL;END;
END $$;
SELECT 'LOCAL_HYROX_48_HISTORY_IMMUTABILITY=PASS';
