# M9 content-graph persistence v1

**Status:** Local Sprint 2 implementation. **Not applied to Field Manual.**  
**Does not rewrite:** authored programme content, Plan Package v1, assignment
pins, or Phase 1 catalogue enrolment.

## Preflight (current production authorities)

| Concept | Existing authority | Sprint 2 action |
|---------|-------------------|-----------------|
| Programme lineage | `programme_lineages` | Reuse |
| Programme version | `programme_versions` | Additive `supersedes_version_id` only |
| Session revision | `performance_protocols.protocol_id` | Reuse |
| Authored block | `session_blocks` | Reuse |
| Canonical exercise | `exercises_v2.exercise_id` | Reuse; **no** FK from `session_block_exercises` |
| Placement | `programme_version_session_slots` | Reuse |
| Publisher/owner | `library_scope` / `owner_type` / `owner_id` | Additive `content_publishers` + principals (namespace lifecycle was missing) |
| Assignment pin | `programme_assignments.programme_version_id` | Trigger forbids in-place repin |
| Package hash | `programme_versions.package_content_hash` | Compared on publish; not recomputed in SQL |

M9.2/M9.4 used-by remains the indexed `session_block_exercises.exercise_id`
path. Sprint 2 adds invoker views on top of those rows.

No Phase 1 table was renamed.

## Authority hierarchy

**Authoritative:** authored programme rows, session revisions, authored
blocks, `EX-*` identities, compiler inputs (Plan Package v1 + supplemental
SQL).  
**Derived:** Plan Package bytes, content-graph manifest v1, used-by views,
version-diff, impact counts.

A graph write never updates those authoritative tables.

## Hash identity

Computed in the Dart compiler (`ContentGraphBinding`). The database verifies:

- SHA-256 hex shape
- composite identity =
  `sha256(canonical JSON of compiler_version, graph_format_version, source_package_hash, supplemental_relationship_hash)`
- one published manifest per `(programme_version_id, format, compiler)`
- unique `composite_identity`
- published rows immutable

Excluded from structural identity: row UUIDs, timestamps, assignment counts,
catalogue flags, assignment lifecycle.

## Publication transaction

`publish_content_graph_manifest(jsonb)` returns typed statuses:

`published` · `already_published` · `hash_mismatch` · `unsupported_format` ·
`unresolved_reference` · `conflicting_identity` · `unauthorised` ·
`missing_publisher`

It does not change catalogue default or assignment pins. Schema-only
deployment creates **zero** publisher rows. First-party `cohort_global` is
created only by the separately authorised operation in
`supabase/manual/content_graph_bootstrap_cohort_global.sql` (see
[M9_Publisher_Bootstrap_Runbook_v1.md](./M9_Publisher_Bootstrap_Runbook_v1.md)).
Until that bootstrap, publication fails closed (`missing_publisher` /
`unauthorised`). Capabilities may report `content_graph_read` (schema present)
while `content_graph_publish` remains false.

## Assignment pinning

Catalogue enrolment still selects the authorised default once and stores
`programme_version_id`. Later publish/default/retire cannot UPDATE that
column. Materialisation continues to use the pin.

## RLS matrix

| Actor | Read graph | Publish | Impact counts | Direct manifest write |
|-------|------------|---------|---------------|------------------------|
| Unauthenticated | deny | deny | deny | deny |
| Athlete | assigned published or catalogue-eligible only | deny | deny | deny |
| Catalogue consumer | same as catalogue-eligible programme versions | deny | deny | deny |
| Publisher principal | own active namespace (draft + published) | owned active namespace via RPC | owned namespace | deny (RPC only) |
| Other publisher | no private-namespace rows unless catalogue-visible | deny | deny | deny |
| Coach | own `coach_private` via existing `dev_coach_readable`; not all published catalogue | deny | deny | deny |
| Inactive principal | no namespace path | deny | deny | deny |
| service_role | yes | yes | yes | bypass RLS; still immutable trigger |

`content_graph_is_service_role` uses request GUC/JWT, not `current_user`, so
SECURITY DEFINER impact/diff cannot treat table-owner `postgres` as trusted.

Retired/archived versions remain readable for a pinned assignment.

## Capabilities

`cohort_athlete_runtime_capabilities` schema_version 2 adds:

- `content_graph_read`
- `content_graph_publish`
- `content_graph_impact`

Missing RPC → existing client treats the probe as unavailable (build 7
compatible). No startup crash.

## Migrations

| File | Role |
|------|------|
| `20260918120000_content_graph_core.sql` | publishers, principals, manifests, pin + immutability triggers |
| `20260918120100_content_graph_publication.sql` | publication RPC |
| `20260918120200_content_graph_read_models.sql` | used-by views, impact, diff |
| `20260918120300_content_graph_rls.sql` | RLS/grants, capability keys |
| `20260918120400_content_graph_reconstruction.sql` | local reconstruction ledger |

Recovery: drop the five objects in reverse order after founder-approved
rollback. Do not drop Phase 1 tables. Restore pin trigger drop only if a
later audited repin RPC is authorised.

## Local verification

`./supabase/tests/run_local_db_gate.sh` Gate AX. Flutter
`test/content_graph/content_graph_persistence_test.dart`.
