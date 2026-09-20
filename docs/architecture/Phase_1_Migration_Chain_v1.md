# Phase 1 migration chain

**Local proof:** `./supabase/tests/run_local_db_gate.sh` (fresh `db reset` plus
repeat reset; never hosted).  
**Hosted Field Manual:** overdue recovery and Backfill migrations were applied
in an earlier authorised deploy. The closeout trigger and historical
reconciliation (`20260914120000`, `20260914121000`) are the authorised
lifecycle pair; apply only those two files, never the remainder of the
chain, on a production-equivalent upgrade.

Fresh local databases apply every file in `supabase/migrations/` by timestamp.
Upgrade from the closest production-equivalent schema is the hosted-faithful
baseline fixture
`supabase/tests/fixtures/local_test_baseline_prereq.sql` (schema-only, no
INSERT/COPY) followed by that same timestamped chain.

## Dogfood-critical migrations

| File | Purpose | Kind | Row writes at migrate? | Hosted (recorded) |
|------|---------|------|------------------------|-------------------|
| `20260801160000_complete_programme_session_and_advance.sql` | Complete + cursor | Replaces function | No | Yes (earlier Phase 1) |
| `20260813140000_atomic_programme_training_session_start.sql` | Idempotent start | Replaces function | No | Yes |
| `20260824120000_apollo_calendar_driven_schedule_slice_1.sql` | Occurrence calendar | Tables + functions | No | Yes |
| `20260904120000_correct_completed_performance_record.sql` | Corrections | Additive table + RPC | No | Yes |
| `20260905120000_interval_set_result_integrity.sql` | Interval ordinals | Trigger | No | Yes |
| `20260905180000_swap_future_fixed_programme_session_and_begin.sql` | Train today swap | Replaces functions | No | Yes |
| `20260906120000_bound_future_train_today_swap_horizon.sql` | 7-day bound | Replaces function | No | Yes |
| `20260906140000_ignore_completed_sessions_in_train_today_swap.sql` | Ignore closed sessions | Replaces function | No | Yes |
| `20260911120000_overdue_fixed_programme_recovery.sql` | Incomplete recovery | Replaces functions | No | Applied 2026-09-13 |
| `20260913120000_backfill_fixed_programme_session_results.sql` | Backfill provenance | Additive columns + RPC | No | Applied 2026-09-13 |
| `20260914120000_terminalize_training_session_from_completed_record.sql` | Parent session close | Trigger | No | Authorised hosted lifecycle pair |
| `20260914121000_reconcile_terminal_training_sessions_from_records.sql` | Historical parent close | Function + SELECT | Qualified parents only | Authorised hosted lifecycle pair |

Earlier catalogue, RLS, Apollo week protocols, and enrolment migrations remain
required dependencies. Rollback of function-body replacements is restore the
previous migration file; rollback of the new trigger is `DROP TRIGGER`.

Compatibility: the trigger only adds parent `completed` when evidence already
exists. Older app builds that still call `completeSession()` stay compatible.

## M9 Sprint 2 (local only, not Field Manual)

| File | Purpose | Kind | Row writes at migrate? | Hosted (recorded) |
|------|---------|------|------------------------|-------------------|
| `20260918120000_content_graph_core.sql` | Publishers, manifests, pin immutability | Additive | **No** (publisher bootstrap is manual) | No |
| `20260918120100_content_graph_publication.sql` | Graph publication RPC | Functions | No | No |
| `20260918120200_content_graph_read_models.sql` | Used-by views / impact / diff | Views + functions | No | No |
| `20260918120300_content_graph_rls.sql` | Graph RLS + capability keys | RLS | No | No |
| `20260918120400_content_graph_reconstruction.sql` | Reconstruction ledger | Additive | No | No |

Local gate coverage: Gates C–AU plus **AV**, **AW**, and **AX** (content-graph
persistence). Capability reporting remains `cohort_athlete_runtime_capabilities`
(schema_version 2 keys are additive).

## M10 Sprint 2 / privilege hardening

| File | Purpose | Kind | Row writes at migrate? | Hosted (recorded) |
|------|---------|------|------------------------|-------------------|
| `20260919120000_publisher_athlete_membership_core.sql` | Invitations, memberships, append-only events | Additive | **No** | Schema-only Field Manual |
| `20260919120100_publisher_athlete_membership_rpcs.sql` | Consent RPCs | Functions | No | Schema-only Field Manual |
| `20260919120200_publisher_athlete_roster_projection.sql` | Roster/inbox/audit reads | Views + functions | No | Schema-only Field Manual |
| `20260919120300_publisher_athlete_membership_rls.sql` | Membership RLS | RLS | No | Schema-only Field Manual |
| `20260919120400_publisher_athlete_membership_capabilities.sql` | Capability schema_version 3 | Functions | No | Schema-only Field Manual |
| `20260920120000_publisher_athlete_membership_privilege_hardening.sql` | Least-privilege ACLs | REVOKE/GRANT | **No** | Field Manual ledger 96 (2026-09-20) |

Local gate coverage adds **AY** (consent + ACL). Enrolment is never inferred
into membership. M10 infrastructure closeout:
[`../checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md`](../checkpoints/M10_ATHLETE_COACH_MANAGEMENT_CLOSEOUT.md).
