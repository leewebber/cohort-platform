-- Founder-authorised bounded SELECT; Field Manual otnhhdxstdnwccehacku only.
-- Run only after a current ACTIVE_HEALTHY result with an existing credential.
-- Dedicated Management API read-only endpoint; no functions/RPCs or mutations.
-- Known ID leads plus bounded discovery for the two exact unresolved variants.
-- Discovery predicates select candidates only; display names do not bind identity.
SELECT e.exercise_id, e.name, e.slug, e.published, e.category,
       e.movement_pattern, e.equipment, e.unilateral, e.loading_options,
       e.purpose, e.setup, e.execution, e.coaching_cues, e.notes_internal
FROM public.exercises_v2 AS e
WHERE e.exercise_id IN ('EX-037', 'EX-038', 'EX-044', 'EX-053', 'EX-090')
   OR (
       lower(concat_ws(' ', e.name, e.slug)) LIKE '%lunge%'
       AND (
           lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%reverse%'
           OR lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%step back%'
           OR lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%step-back%'
       )
   )
   OR (
       lower(concat_ws(' ', e.name, e.slug, e.equipment::text)) LIKE '%dumbbell%'
       AND lower(concat_ws(' ', e.name, e.slug)) LIKE '%press%'
       AND (
           lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%seated%'
           OR lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%upright%'
           OR lower(concat_ws(' ', e.name, e.slug, e.setup::text, e.execution::text)) LIKE '%back support%'
       )
   )
ORDER BY e.exercise_id
LIMIT 20;
