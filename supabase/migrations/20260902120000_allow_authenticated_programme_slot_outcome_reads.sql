-- Programme slot outcomes are an athlete-readable execution projection.
-- Existing RLS restricts authenticated reads to the owning athlete or an
-- actively related coach. Mutation remains owned by canonical RPCs.

GRANT SELECT ON TABLE public.programme_slot_outcomes TO authenticated;

REVOKE ALL ON TABLE public.programme_slot_outcomes FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.programme_slot_outcomes
  FROM authenticated;
