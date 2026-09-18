# M9 migration and backfill plan

Sprint 1: **docs + local graph only**. No `supabase/migrations` file. No Field Manual apply.

After founder approval:

1. Additive migration creating publishers, optional FKs, graph manifest table, used-by views.
2. Backfill first-party:
   - Apollo lineage `APOLLO-BUILD-12-WEEK` and current published version
   - session revisions via `protocol_id`
   - `EX-*` from `session_block_exercises`
   - existing hashes copied, not recomputed unless verified equal
3. Unresolved: name-only steps, TMP prose, HYROX stub, missing hosted EX-001–072 in local DB — mark `legacy_unresolved`, never guess.
4. Repeat backfill must be idempotent.
5. Must not rewrite assignments, occurrences, or evidence.

Lee’s assignment and Apollo published hash stay untouched.
