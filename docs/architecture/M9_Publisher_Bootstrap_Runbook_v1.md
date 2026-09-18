# M9 first-party publisher bootstrap (manual)

**Not a migration.** Not applied by `supabase db push`, `db reset`, or the
automatic timestamped chain. Schema deploy of `20260918120000`–`120400`
must leave `content_publishers` empty.

## Permission boundary

| Operation | File | Auto-applied? |
|-----------|------|----------------|
| Graph schema | `supabase/migrations/20260918120*.sql` | Yes, when those migrations are authorised |
| First-party `cohort_global` | `supabase/manual/content_graph_bootstrap_cohort_global.sql` | **No** |
| Reconstruction / publication | later authorised task | **No** |

Installing the manual file creates the function only. Calling it with an
explicit principal creates the publisher row. Approval of schema deploy does
not authorise this call.

## Review without executing

Read `supabase/manual/content_graph_bootstrap_cohort_global.sql`. There is no
uncommented DML. No Field Manual athlete or assignment UUID is present.

## Authorised apply (local or later hosted, only when separately approved)

```bash
# 1. Install the function (still zero publisher rows)
psql -v ON_ERROR_STOP=1 -f supabase/manual/content_graph_bootstrap_cohort_global.sql

# 2. Bootstrap with an explicit principal UUID (do not guess ownership)
psql -v ON_ERROR_STOP=1 -c \
  "SELECT public.content_graph_bootstrap_cohort_global('<principal-uuid>'::uuid);"
```

Expected statuses: `created`, `already_exists`, `conflict`, `unauthorised`.

The function:

- uses namespace `cohort_global` and stable id `00000000-0000-4000-8000-00000000c001`
- refuses a conflicting publisher on that namespace or id
- records the supplied principal separately
- does not publish a manifest
- does not reconstruct
- does not alter catalogue defaults
- does not repin assignments

Callers must be `service_role` / `postgres`. Authenticated athletes and
coaches cannot execute it.

## After schema-only, before this call

Publication returns `unauthorised` / `missing_publisher`. Capability
`content_graph_publish` is false. Athlete Home / Calendar / Progress / workout
do not require a publisher row.
