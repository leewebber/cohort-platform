-- PREPARED ONLY. Run only after presence of all eleven new tables is proved.
-- The three reviewed calculation dependency rows are the only allowed seeds.
SELECT 'hyrox_base_benchmark_revisions' AS relation,count(*) AS rows FROM public.hyrox_base_benchmark_revisions
UNION ALL SELECT 'hyrox_base_benchmark_selections',count(*) FROM public.hyrox_base_benchmark_selections
UNION ALL SELECT 'published_exercise_definition_versions',count(*) FROM public.published_exercise_definition_versions
UNION ALL SELECT 'published_exercise_version_retirements',count(*) FROM public.published_exercise_version_retirements
UNION ALL SELECT 'hyrox_prescription_dependencies',count(*) FROM public.hyrox_prescription_dependencies
UNION ALL SELECT 'programme_v3_publication_artifacts',count(*) FROM public.programme_v3_publication_artifacts
UNION ALL SELECT 'cohort_v3_publication_claims',count(*) FROM public.cohort_v3_publication_claims
UNION ALL SELECT 'programme_v3_prescription_reviews',count(*) FROM public.programme_v3_prescription_reviews
UNION ALL SELECT 'programme_v3_prescription_consents',count(*) FROM public.programme_v3_prescription_consents
UNION ALL SELECT 'programme_occurrence_v3_prescription_snapshots',count(*) FROM public.programme_occurrence_v3_prescription_snapshots
UNION ALL SELECT 'programme_occurrence_duration_choices',count(*) FROM public.programme_occurrence_duration_choices;
