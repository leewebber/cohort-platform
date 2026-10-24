-- PREPARED ONLY. NOT EXECUTED HOSTED. Do not run if any named table is absent.
-- Use READ_ONLY_PREFLIGHT.sql presence results first; adapt only through review for partial schema.
-- No athlete IDs, benchmark values, consent documents, source bodies or secrets returned.
\set ON_ERROR_STOP on
BEGIN READ ONLY;
SELECT exercise_id,definition_version,content_digest,
 encode(sha256(convert_to(publication::text,'UTF8')),'hex') AS publication_fingerprint,
 publication->'approved_binding_kinds' AS approved_binding_kinds,
 publication->>'published_at' AS published_at,captured_at,EXISTS(SELECT 1 FROM public.published_exercise_version_retirements r
  WHERE r.exercise_id=v.exercise_id AND r.definition_version=v.definition_version) AS retired
FROM public.published_exercise_definition_versions v ORDER BY exercise_id,definition_version;
SELECT kind,metric,
 encode(sha256(convert_to(rule_document::text,'UTF8')),'hex') AS rule_fingerprint,
 encode(sha256(convert_to(benchmark_document::text,'UTF8')),'hex') AS benchmark_fingerprint
FROM public.hyrox_prescription_dependencies ORDER BY kind;
-- Row counts only; fingerprint data only through the separately reviewed aggregate baseline.
SELECT 'published_exercise_definition_versions' AS relation,count(*) AS rows FROM public.published_exercise_definition_versions
UNION ALL SELECT 'published_exercise_version_retirements',count(*) FROM public.published_exercise_version_retirements
UNION ALL SELECT 'programme_v3_publication_artifacts',count(*) FROM public.programme_v3_publication_artifacts
UNION ALL SELECT 'cohort_v3_publication_claims',count(*) FROM public.cohort_v3_publication_claims
UNION ALL SELECT 'programme_v3_prescription_reviews',count(*) FROM public.programme_v3_prescription_reviews
UNION ALL SELECT 'programme_v3_prescription_consents',count(*) FROM public.programme_v3_prescription_consents
UNION ALL SELECT 'programme_occurrence_v3_prescription_snapshots',count(*) FROM public.programme_occurrence_v3_prescription_snapshots
UNION ALL SELECT 'hyrox_base_benchmark_revisions',count(*) FROM public.hyrox_base_benchmark_revisions
UNION ALL SELECT 'hyrox_base_benchmark_selections',count(*) FROM public.hyrox_base_benchmark_selections;
-- Stable, aggregate fingerprints only. Never return per-athlete row digests or documents.
SELECT 'programme_v3_publication_artifacts' AS relation,
 encode(sha256(convert_to(coalesce(string_agg(h,'' ORDER BY h),''),'UTF8')),'hex') AS rows_sha256
FROM (SELECT encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') AS h FROM public.programme_v3_publication_artifacts t) s
UNION ALL
SELECT 'programme_occurrence_v3_prescription_snapshots',
 encode(sha256(convert_to(coalesce(string_agg(h,'' ORDER BY h),''),'UTF8')),'hex')
FROM (SELECT encode(sha256(convert_to(to_jsonb(t)::text,'UTF8')),'hex') AS h FROM public.programme_occurrence_v3_prescription_snapshots t) s;
COMMIT;
