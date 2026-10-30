-- REQUEST ONLY. Not executed by this task; no hosted contact is authorised here.
-- After separately explicit exact-target SELECT authority, the trusted catalogue
-- operator retains actual returned row bytes, source/target, capture time, digest.
-- No version column/event is invented; EX-090/037 still need exact setup evidence.
SELECT exercise_id, name, slug, published, category, movement_pattern,
       equipment, primary_muscles, primary_capability, loading_options, purpose
FROM public.exercises_v2
WHERE published IS TRUE
  AND exercise_id IN ('EX-037', 'EX-038', 'EX-044', 'EX-053', 'EX-090')
ORDER BY exercise_id;

-- Loaded reverse lunge has no verified ID to put in this request. Catalogue owner
-- must perform exact-variant discovery/deduplication; display-name hits are only
-- candidates, never an identity binding or permission to publish a new row.
