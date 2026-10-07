# First athlete History distance — security and real-source readiness audit

**Recorded:** 2026-10-07 (Asia/Makassar). **Verdict:**
**BLOCKED_FOR_AUTHENTICATED_DEVICE_VALIDATION**.
Read-only target inspection; remediation is proposed, not implemented.

## Boundary and target

Started clean on `codex/athlete-history-distance-slice` at
`b1d028fb33eb537391f307bb4eac22dddd98ebde`, equal to cached `origin/main`.
No fetch; this equality is local ref evidence. Created documentation branch
`codex/athlete-history-readiness-audit` from that exact commit. Prior implementation,
visual approval and verification remain in the [handoff](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_HANDOFF.md).
The [slice proposal](../architecture/Performance_Tracking_First_Athlete_History_Slice_Proposal_v1.md)
and founder-approved content recorded in the
[metric decision](../architecture/Performance_Tracking_First_Athlete_Metric_Decision_v1.md)
remain binding; the decision's dated proposal status is historical.

The established Supabase CLI account confirmed **Cohort Field Manual**,
`otnhhdxstdnwccehacku`, `eu-west-1`, PostgreSQL `17.6.1.155`,
**ACTIVE_HEALTHY before and after inspection**. SELECT ledger: **117** versions,
latest **20261005141000**. Only a disposable CLI workdir was linked; repository
`supabase/.temp` was not linked, edited or cleaned.

Database inspection ran as `postgres`; `transaction_read_only=off` is the
connection setting, not an enforced read-only session. Every submitted audit SQL
statement was SELECT. No SET ROLE, JWT claim override, athlete token acquisition,
athlete impersonation, restricted-function execution or validator bypass occurred.
Separate catalog/source queries are separate snapshots, not one shared transaction.
Output contains catalog definitions and aggregate counts, no personal identifiers,
session/block titles, notes or raw athlete values. No programme or assignment write.

## Exact access findings

Effective privileges were checked with `has_table_privilege`, column privileges,
schema privileges, `pg_class`, `pg_policies`, `pg_roles` and role memberships.
All listed tables are owned by `postgres`; FORCE RLS is false. `anon` and
`authenticated` are neither superusers nor BYPASSRLS roles and have no inherited
role memberships. Both have public-schema USAGE, neither has CREATE.
There are no column ACL exceptions on the six direct read relations: SELECT
grants cover every column, subject to enabled RLS.

Here `S/I/U/D` mean SELECT/INSERT/UPDATE/DELETE; `T/R/G/M` mean
TRUNCATE/REFERENCES/TRIGGER/MAINTAIN. These are effective database privileges,
not proof that every operation is exposed by the HTTP gateway.

| Relation | anon | authenticated | RLS / read boundary |
|---|---|---|---|
| `training_sessions` | S/I/U/D/T/R/G/M | S/T/R/G/M | **Disabled; no policies** |
| `training_session_records` | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; owner or active coach relationship |
| `training_block_results` | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; owned record parent or active coach relationship |
| `training_exercise_results` | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; block → record ownership or active coach relationship |
| `training_set_results` | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; exercise → block → record ownership or active coach relationship |
| `performance_result_corrections` | S/T/R/G/M | S/T/R/G/M | Enabled; authenticated owner SELECT only |
| `coach_athlete_relationships` (policy dependency) | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; authenticated coach or athlete endpoint SELECT only |
| `profiles` (client role resolution / relationship dependency) | S/I/U/D/T/R/G/M | S/I/U/D/T/R/G/M | Enabled; own or actively linked profile SELECT |

All observed policies are permissive, apply only to `authenticated`, and have
no PUBLIC/anon read branch. Their complete policy inventory is:

| Relation | Policy names and predicates |
|---|---|
| records | `performance_records_athlete_select`: `athlete_id = auth.uid()::text`; `performance_records_coach_select`: `cohort_coach_has_active_athlete(athlete_id)`; `performance_records_athlete_insert`: owner WITH CHECK; `performance_records_athlete_update`: owner and `status='in_progress'` USING, owner WITH CHECK |
| blocks | `performance_block_results_athlete_all`: parent record owner USING, parent owner plus in-progress record WITH CHECK; `performance_block_results_coach_select`: parent record with active coach relationship |
| exercises | `performance_exercise_results_athlete_all`: block → record owner USING, same plus in-progress record WITH CHECK; `performance_exercise_results_coach_select`: same parent chain with active coach relationship |
| sets | `performance_set_results_athlete_all`: exercise → block → record owner USING, same plus in-progress record WITH CHECK; `performance_set_results_coach_select`: same parent chain with active coach relationship |
| corrections | `performance_result_corrections_athlete_select`: `athlete_id = auth.uid()::text`; no other policies |
| relationships | `coach_athlete_relationships_coach_select`: `coach_id = auth.uid()`; `coach_athlete_relationships_athlete_select`: `athlete_id = auth.uid()`; no client write policies |
| profiles | `profiles_select_own`: `id = auth.uid()`; `profiles_select_linked_users`: own or active relationship joining the current user and profile in either direction; `profiles_insert_own` and `profiles_update_own`: own ID checks |

The child ALL policies also apply to SELECT. Coach policies OR with owner
policies; therefore direct metadata/child access is **not universally owner-only**.
That is the existing approved relationship boundary, not a new distance-feature
grant. `cohort_coach_has_active_athlete(text)` validates UUID text then delegates
to its UUID overload. The UUID overload is postgres-owned STABLE SECURITY DEFINER,
`search_path=public, pg_temp`, and requires a row with
`coach_id=auth.uid()`, the supplied athlete ID and `status='active'`.
Both overloads are executable by anon/authenticated; the text overload also has
PUBLIC EXECUTE. Neither returns records. There are **zero relationship rows**
at inspection, so that branch currently admits no linked athlete. It does not
check a profile coach flag; the retained relationship is its authority. RLS has
no client INSERT/UPDATE/DELETE relationship policy despite the broad grants.

The independent RPC `read_performance_tracking_history_v1(uuid,jsonb)` is
postgres-owned, SQL/STABLE, **SECURITY INVOKER**, with
`search_path=pg_catalog, pg_temp`. EXECUTE ACL is exactly postgres and
authenticated; anon and PUBLIC have no execution grant. Live body MD5
`0ced1cfb29b3393128fc96055bb9f810` matches the committed
[C2 migration](../../supabase/migrations/20261005130000_performance_tracking_coherent_history_read.sql).
It anchors `record_id=p_record_id AND athlete_id=auth.uid()::text`, then joins
blocks, exercises, sets and corrections through that record. A foreign ID and
an absent ID return the same `no_visible_record` envelope. Coach table visibility
does not broaden this explicit RPC owner predicate. No `training_sessions` read,
programme witness or restricted validator is used by this independent route.
`auth.uid()` and `auth.role()` are STABLE invoker functions reading request JWT
settings; their PUBLIC EXECUTE grants do not create an athlete identity.

### Exposure and required remediation

1. **Existing cross-athlete session exposure:** anon and authenticated can SELECT
   every `training_sessions` row/column at the database authorization layer.
   RLS is disabled, so there is no owner restriction. The table has **47 rows**,
   all with non-null athlete ownership; **one row** has notes/session-note data.
   Exposed column categories include owner identity, programme/protocol, dates,
   completion state, duration, notes and execution counts. An anonymous caller
   also has INSERT/UPDATE/DELETE grants without RLS. Trigger/constraint effects
   were not exercised, so successful writes are not claimed. This is stronger
   than the previously recorded authenticated SELECT discrepancy.
2. **Existing excessive privileges:** both client roles have TRUNCATE across
   all eight inspected relations, plus REFERENCES/TRIGGER/MAINTAIN. PostgreSQL
   [RLS does not constrain TRUNCATE or REFERENCES](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).
   Foreign keys can constrain a particular
   operation; they do not make these grants owner-scoped. HTTP reachability of
   these non-DML operations was not tested. This remains an integrity/security
   defect in the database privilege boundary even where ordinary RLS SELECT
   denies rows. No destructive proof was attempted.
3. **Propose a separately approved permission-remediation migration:** remove
   all anon privileges on `training_sessions`; remove client T/R/G/M on these
   eight relations; remove unnecessary anon History/dependency grants and
   retain only reviewed authenticated operations. Enable `training_sessions`
   RLS with authenticated owner SELECT tied to its `athlete_id` and `auth.uid()`;
   any coach read exception must be explicitly approved and relationship-gated.
   Review existing consumers/definer RPCs and required writes before finalising
   grants, preserving programme execution, correction and relationship authority.
   Preserve evidence and pins; no backfill, permissive ALL policy or broad SELECT
   substitute. No migration or policy implementation was created in this task.

### New-feature protection versus remaining proof gaps

The [composition](../../lib/features/performance_tracking/supabase_distance_history.dart)
requires matching active athlete and transport identities. Metadata reads select
record ID, owner, terminal state, performed date/precision and only the recorded
session-title scalar, with 25-row pages. Existing record RLS protects metadata
independently of the client's owner filter; an unlinked authenticated actor has
no foreign-record read policy and anon has no applicable record policy.
The new feature does not use the unsafe session grant. Its explicit C2 owner
anchor, strict decoder, exact parents, visit-scoped frames and auth-generation
invalidation protect its own route; they **cannot repair direct table access**.

Catalog inspection establishes database grant/policy semantics, not a successful
authenticated device or gateway exercise. No real anon/athlete/coach HTTP requests,
signed-claim binding tests, two-account negative reads or account-switch walkthrough
were performed. A postgres SELECT is not proof of client RLS enforcement.
Role-based runtime proof and exposed-schema/gateway behavior remain unverified.
Do not infer their safety from client filtering or zero current relationships.
The existing release guards and entry composition were not changed or enabled.

## Real-source feasibility

Counts below cover terminal records (`completed`, `partially_completed`,
`abandoned`) whose owner matches `profiles.id::text` with `is_athlete=true`.
They are target-wide aggregates, **not proof that a particular active athlete has
both observations**, nor that these records constitute standardised tests.

| Aggregate | Count |
|---|---:|
| All History records / all terminal records | 24 / 19 |
| Profile-athlete-owned terminal records / blocks of all types | 16 / 35 |
| Owned distance/endurance candidates / distinct candidate records | 5 / 3 |
| Complete kilometre observations / distinct records containing them | **2 / 2** |
| Complete metre observations / other-unit candidates | 0 / 0 |
| Explicit km / metre / missing-unit candidates | 5 / 0 / 0 |
| Absent distance values / completed candidates lacking distance | **3 / 3** |
| Partial / skipped / not-started distance candidates | 0 / 0 / 0 |
| Malformed numeric/type/completion/binding/chronology shapes | 0 |
| Candidates with retained comparison context / complete km with context | **0 / 0** |
| Current correction audit rows in the owned terminal frames | 0 |

All five candidates are completed `endurance` blocks with object result data,
matching `resultType`, explicit `distanceUnit='km'` and boolean `completed=true`.
Two have nonnegative numeric `result_data.distance`; three lack a value. Absent
values must remain unavailable, never zero. No conversion or inferred unit is
needed. Three additional terminal records have no matching profile owner and
non-UUID owner strings; their two distance/endurance candidates are excluded.
The broader unfiltered inventory has three complete km observations, four absent
values and one not-started candidate; it is **not** the real owned availability
count. None of the 35 owned terminal blocks has an in-progress/skipped/not-started
state, so this target snapshot supplies no such device evidence. Partial/skipped
feature behavior remains prior synthetic/regression evidence, not a live result.

Exact record/block-result IDs are native UUID primary keys; child foreign keys
retain block → record, exercise → block and set → exercise parents. All five
candidate `source_block_id` values are nonempty and agree exactly with
`block_snapshot.sourceBlockId`. The
[controller](../../lib/features/performance_tracking/distance_history_controller.dart)
can enumerate them and require explicit selection of
`['result_data','distance']`; titles are display only. There are no duplicate-title
candidate groups in this snapshot, so real duplicate-title UX is not validated.

The live RPC body matches the
[strict reader](../../lib/application/performance_tracking/coherent_history_rpc_reader.dart)
envelope contract. Aggregate construction of its record-local tree shape found
all **16** owned terminal frames below its **10,000-child/audit-row** and **4 MiB**
bounds: maxima **60 rows / 35,644 bytes**. Session references were positive when
present; candidate chronology and numeric representations passed structural
inspection; there are no correction rows to decode. The
[projection](../../lib/application/performance_tracking/history_tracking_projection.dart)
supports these native shapes and complete-only kilometre extraction.
This establishes structural feasibility without hydrated defaults, title matching
or fabricated context. It is **not an actual authenticated RPC/decoder run**;
transport JSON decoding and active-account visibility remain device-validation
gates after security remediation. No local uncertainty required a test run.

No owned candidate retains `block_snapshot.comparisonFamily`. Independent
observations need no such context, but actual C3 must refuse their comparison.
Neither selected record identity nor a matching title supplies missing context.
No family, modality, route, equipment or prescription eligibility was fabricated;
no arithmetic, programme attribution or historical reconstruction is available.

## Next action and approval boundary

**Do not proceed to authenticated device validation on this target yet.**
Next action: founder approval for a bounded permission-remediation proposal with
exact target, operation matrix, owner/approved coach policies, consumer impact,
negative-role proof plan and evidence-preservation checks. Implementation,
migration/apply and hosted postchecks each need explicit authority; this audit
approves none of them. Re-audit grants/RLS and prove the permitted runtime role
boundary afterward. Only then seek separate authenticated device-validation
authority (owned entry, fresh discovery/RPC decoding, unavailable values, context
refusal and account isolation). Phone build/install and release remain separate.

## Verification and preservation

Reviewed local production entry/composition, controller, strict C2 reader,
projection, snapshot/result serialization and auth identity; binding checkpoint,
architecture freeze and athlete product sequence remain unchanged. Catalog
inspection covered direct read relations and policy dependencies, all policies,
effective grants/columns, roles, helper/RPC definitions and parent constraints.
Source SQL returned aggregates only. Historical 323-test/analysis/safety evidence
is attributed to the handoff and was not rerun. No tests, build, migration, hosted
data write, permission remediation, release-guard change, fetch, push or next
slice. Local Markdown links and diff checks passed for the audit/handoff updates;
disposable inspection files were removed and repository `supabase/.temp` file set
and content hashes were verified unchanged. Final local commit/state is reported
after committing, without inventing a self-referential hash in this document.
