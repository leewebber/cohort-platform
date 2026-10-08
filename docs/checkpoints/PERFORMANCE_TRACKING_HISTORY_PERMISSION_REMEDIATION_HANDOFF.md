# History permission remediation — local candidate and blocking proof

> **Combined permission/completion review — 2026-10-08:**
> [Integration review](./PERFORMANCE_TRACKING_PERMISSION_COMPLETION_INTEGRATION_REVIEW.md) preserves all six commits through
> `680b3ba86eaf5ef4cd46765ae24be7b5a834867a` on
> `codex/history-permission-completion-review`. Separate local fixes close
> elevated child-ID collisions, mutable result identities and ownership/link
> races, including direct child parent locking. Final role/API/concurrency,
> fresh/repeat DB compatibility and structured-running gates pass; 242 focused
> Flutter tests, zero analysis issues and six safety groups pass.
> **REVIEWED_LOCALLY_AWAITING_FOUNDER_INTEGRATION_APPROVAL**. Nine ordered
> commits, zero merges; base/cached origin/main remains
> `b1d028fb33eb537391f307bb4eac22dddd98ebde`. Earlier dated results below
> remain historical. No fetch/push, hosted contact/apply, release activation,
> phone build/install or next slice. Stop for founder integration approval.

> **Completion ownership protection — locally proved, 2026-10-07:**
> [Completion handoff](./PERFORMANCE_TRACKING_COMPLETION_OWNERSHIP_PROTECTION_HANDOFF.md) preserves the audit, table remediation and blocked
> handoff from `ca3837946e526e29a0eb805665ec3e5aa0d29f1f` on
> `codex/completion-ownership-protection`; base/cached origin/main remains
> `b1d028fb33eb537391f307bb4eac22dddd98ebde`. Server ownership/exact-link
> guards and independent parent protection are implemented locally. The former
> completion-isolation failure and expanded actual-role/API proof pass; full DB
> replay/compatibility, structured-running gate, 317 focused Flutter tests,
> zero analysis issues and six safety groups pass. **AWAITING_FOUNDER_REVIEW**.
> Prior blocked results below are historical. Hosted application and device
> validation remain separately gated. No hosted contact/apply, push, release,
> phone build/install or next slice. Stop for founder review.

**Recorded:** 2026-10-07 (Asia/Makassar).
**Status:** **BLOCKED_AWAITING_FOUNDER_REVIEW**. Table remediation is locally
proved; complete server-side cross-athlete isolation is **not** proved and has a
confirmed failing case. Do not integrate/apply this candidate as release-ready.
No hosted contact occurred in this task.

## State and authorised boundary

Started clean at audit commit `1b85fe3b1a54b436ee6aa9cb68a09c5cecabf1ff`
on `codex/athlete-history-readiness-audit`. Preserved that commit and created
`codex/history-permission-remediation`. Integration base and unchanged cached
`origin/main`: `b1d028fb33eb537391f307bb4eac22dddd98ebde`; no fetch.
The [readiness audit and remediation proposal](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_READINESS_AUDIT.md)
remain immutable historical hosted evidence, not a fresh hosted verification.
The [first-slice handoff](./PERFORMANCE_TRACKING_FIRST_ATHLETE_HISTORY_HANDOFF.md),
[architecture freeze](../architecture/Canonical_Programme_Architecture_Freeze_v1.md),
[product plan](../planning/Athlete_Product_Completion_Plan_v1.md) and
[roadmap](../planning/Delivery_Roadmap_v1.md) governed the trace.

Scope is the eight audited relations plus the `training_sessions.id` identity
sequence needed by session creation. No unrelated schema hardening, RPC body or
RPC ACL change, evidence rewrite, programme/assignment change, release activation,
phone build/install, push or next-slice implementation. All test writes use
synthetic users in temporary local PostgreSQL 17/Supabase projects. Repository
`supabase/.temp` retains its exact pre-task file set and content digest.

## Consumer trace before choosing grants

| Consumer / authority | Demonstrated operation and retained boundary |
|---|---|
| [Session repository](../../lib/data/repositories/training_session_repository.dart) / player restore | `getSessionById`, own list and latest-protocol reads require owner SELECT. Unfiltered foreign-ID reads are denied by RLS. |
| Canonical Programme Athlete start/resume | [Atomic start](../../supabase/migrations/20260813140000_atomic_programme_training_session_start.sql) and fixed-occurrence server entrypoints validate caller/assignment/slot identity. Owner reads support restore; direct client session INSERT/UPDATE/DELETE stay denied. |
| [Execution/result store](../../lib/features/performance/repositories/supabase_performance_record_store.dart) | Record/block/exercise/set draft UPSERT needs SELECT/INSERT/UPDATE. Existing parent ownership and in-progress WITH CHECK apply; no child DELETE consumer was found. Terminal correction uses the existing owner-gated definer RPC. |
| [Programme completion coordinator](../../lib/features/performance/services/performance_record_save_coordinator.dart) | Canonical completion calls the server transaction. Its secondary direct parent UPDATE is caught after authoritative success; it is not a grant authority. The terminal-record trigger updates the parent inside canonical completion. The server ownership defect below blocks complete isolation. |
| Previous performance / restore | [Set repository](../../lib/data/repositories/training_session_set_repository.dart) embeds `training_sessions!inner`; interval/circuit restore and previous-performance paths also read the session repository. Owner SELECT preserves these joins. |
| History / distance discovery / C2 | Existing hydration reads records/children/corrections. [Distance composition](../../lib/features/performance_tracking/supabase_distance_history.dart) discovers exact owned terminal record metadata; independent C2 is owner-anchored and requires no session SELECT. Combined C2 remains owner-gated. |
| Existing coach authority | Active `coach_athlete_relationships` permits History record/child and linked-profile SELECT through existing policies. No operational coach consumer or existing policy establishes session-table access; no new session coach policy is introduced. Ended relationships remove History visibility. Coaches cannot forge relationships. C2 and correction audits remain owner-only. |
| Identity/dependency reads | Profile provisioning requires own INSERT/SELECT; existing own profile UPDATE is preserved. Relationships and correction audits are SELECT-only to authenticated clients. |
| Internal/service transactions | Postgres-owned SECURITY DEFINER start, fixed completion, backfill, correction and private publication retain existing functions/grants. Postgres/service-role table ACLs remain unchanged. Local baseline does not reproduce all hosted service-role grants; no new direct service grant is invented. |
| Dormant/developer operations | [Legacy launcher](../../lib/features/workout_player/services/workout_player_launcher.dart) direct create is used by unmounted `HomeTodaySessionSection` and staging-only launchers. The freeze excludes that runtime. Founder scoped reset/delete methods are developer cleanup, not ordinary athlete authority. Legacy non-programme terminal writes already lack the retired direct parent write path; they are not made functional by widening privileges. |

The [20260823120000 migration](../../supabase/migrations/20260823120000_allow_authenticated_assigned_session_start.sql)
explicitly retired authenticated session INSERT/UPDATE/DELETE in favour of
canonical RPCs. Client filtering was not used as permission evidence.

## Migration candidate: exact resulting access

[Migration](../../supabase/migrations/20261007120000_history_read_permission_remediation.sql):
`20261007120000_history_read_permission_remediation.sql`.
SHA-256: `7c5ce19e72ddd438acfe9db23a5b3c4abed65bdeb6db8faa82e8e7df70910ff7`.

| Relation | PUBLIC / anon | authenticated |
|---|---|---|
| `training_sessions` | none | SELECT |
| `training_session_records` | none | SELECT, INSERT, UPDATE |
| `training_block_results` | none | SELECT, INSERT, UPDATE |
| `training_exercise_results` | none | SELECT, INSERT, UPDATE |
| `training_set_results` | none | SELECT, INSERT, UPDATE |
| `performance_result_corrections` | none | SELECT |
| `coach_athlete_relationships` | none | SELECT |
| `profiles` | none | SELECT, INSERT, UPDATE |

No client DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN or grant options remain
on those tables. Separate client/PUBLIC column grants are also revoked.
`training_sessions_id_seq` has no PUBLIC/anon/authenticated SELECT/USAGE/UPDATE.
No blanket schema/sequence grants or default-privilege changes are used.

`training_sessions` enables RLS, FORCE RLS remains unchanged, and its only policy
is `training_sessions_athlete_select`: SELECT to authenticated, USING
`athlete_id = auth.uid()::text AND public.cohort_auth_is_athlete()`.
There are no client write or coach policies on this table. An unknown additional
session policy aborts the migration transaction; replay replaces only the known
policy. Existing policies on the other seven tables are unchanged and exactly
inventoried in the audit. In particular, child ALL policies cannot confer DELETE
without its table privilege, and existing coach read exceptions remain explicit.

## Blocking server ownership proof — no remediation implemented

[Failing proof](../../supabase/tests/sql/gate_history_permission_completion_owner.sql)
uses the real authenticated database role and a synthetic caller's valid owned
assignment/package/slot. Canonical start and repeated resume succeed and return
the same own session; direct owner restore succeeds and direct foreign session
SELECT returns zero rows. The proof then supplies a **different athlete's session
ID** to `complete_programme_session_and_advance` while retaining its own valid
assignment and completion identity.

The server transaction commits and changes the foreign parent session from
in-progress to completed. The probe reports only booleans:
`rpc_committed=t foreign_parent_changed=t`. Its entire transaction rolls back
on the deliberately failing isolation assertion; no probe rows persist.

Root cause: [canonical completion](../../supabase/migrations/20260801160000_complete_programme_session_and_advance.sql)
forces the record's athlete from `auth.uid()` and validates assignment ownership,
but does not validate the supplied `training_session_id` against that athlete
before inserting the terminal record. The
[terminal-parent trigger](../../supabase/migrations/20260914120000_terminalize_training_session_from_completed_record.sql)
updates the parent by ID without matching its athlete. The trigger is SECURITY
INVOKER, but inside the SECURITY DEFINER completion transaction it runs with the
server's authority. Enabling client RLS cannot constrain that server execution.
This is an existing server defect, separate from the newly repaired client ACLs.
Ordinary happy-path compatibility gates did not cover this substitution.

**Specific next change proposed, not implemented:** founder-authorise a bounded
server ownership/link-validation slice. Lock and validate the supplied session
against `auth.uid()` before any terminal record/trigger/outcome mutation, including
existing-record and idempotent paths; require consistent assignment/slot/protocol
links from retained canonical authority. Reject missing/foreign/conflicting parent
links without mutation or distinguishable foreign metadata. Add an owner equality
condition to parent synchronisation as defence in depth while preserving trusted
server writes. Do not use FORCE RLS, client UPDATE grants or a permissive policy
as a substitute. Prove owned completion/replay, foreign parent substitution,
foreign reassignment of an own draft, fixed-occurrence delegation and all-or-nothing
rollback before reconsidering this candidate. No historical backfill or rewrite
is proposed.

## Current-task validation and limits

| Check | Observed result |
|---|---|
| [Dedicated disposable gate](../../supabase/tests/run_history_permission_remediation_gate.sh) | **Non-zero, BLOCKED** at canonical completion isolation. Preceding table/RPC/decoder sections pass; no overall PASS is claimed. |
| Exact role/ACL gate | 128 effective table privilege checks; client column/sequence/grant-option checks; 40 actual anon table read/write/destructive denials and anon C2 denial; actual authenticated own draft inserts/updates and cross-athlete denial; destructive client denial on all eight tables; coach active/ended relationship boundaries. Pass, repeated after replay/unknown-policy rejection. |
| Adverse hosted-permission reproduction | Synthetic fixtures recreate the audit's excessive anon/auth grants and disabled session RLS, plus PUBLIC/column/sequence drift. Applying the unchanged migration removes them. Pass. No production grants are added to make tests pass. |
| Replay and preservation | Migration applied twice after adverse input. Digests of every pre-existing public ordinary-table row set, all public function definitions/ACLs, other policy semantics and postgres/service table privileges stay unchanged. Pass. This proves disposable evidence preservation, not a hosted snapshot. |
| Unknown permissive policy | Migration rejects it atomically. The fixture-only policy is removed and exact ACL/preservation checks pass again. |
| Loopback PostgREST | Eight anonymous table reads denied; direct client session insert denied; both athletes' own reads succeed and foreign reads return empty; foreign discovery empty, linked coach read allowed; anon C2 denied. Pass with locally minted disposable identities only. |
| Actual C2/C3 decoder | Two complete synthetic kilometre block wires decode through actual C2 reader/adapter and approved distance closure with exact IDs/field path. Numeric zero remains present. Missing comparison family refuses the explicit pair. Pass. |
| Existing C2 gates | Independent and programme SQL gates, three correction races each and publication snapshot race pass. Independent reader is additionally proved with session SELECT temporarily revoked inside rollback. |
| Full disposable DB gate | `bash supabase/tests/run_local_db_gate.sh`: fresh and repeat reset, baseline fidelity, shared start/completion/fixed/backfill/correction/coach/assignment compatibility, concurrency and API controls pass. Historical session-no-RLS expectation is replaced by the intended owner-read expectation; unrelated baseline checks remain. Does not override the new failing security proof. |
| Affected Flutter regressions | **508 passed** across performance, tracking, distance feature, programme completion/integrity and completion-migration tests. No full Flutter suite: no production Dart changes. |
| Changed Dart analysis | Decoder proof: **zero issues**. |
| Safety | **Six groups pass**, zero failed. |
| Syntax/diff/links | Bash/Python syntax, local documentation links and `git diff --check` pass. |

All disposable projects/containers, task-created backup volumes, cache files and
logs are removed after verification. No repository `.temp` changes, hosted
connection/token acquisition, release configuration change or remote publication.
The prior audit's real-source aggregates remain historical: two complete owned
km observations, three absent values, no comparison context. Synthetic local
success does not establish real authenticated account/device availability.

## Review and approval boundary

Stop for founder review of this **blocked local candidate**, its consumer trace
and server-change proposal. Implementation/proof commit:
`ee06faa6a227dd53996342b191908e59d3e818b3`.
The linear integration range is
`b1d028fb33eb537391f307bb4eac22dddd98ebde..codex/history-permission-remediation`:
the preserved audit, this implementation/proof commit, and its handoff commit.
The exclusive new implementation range starts at audit
`1b85fe3b1a54b436ee6aa9cb68a09c5cecabf1ff`. Exact final tip is reported with
repository state; neither integration nor push is approved.

Next authority needed is the specific local server ownership/link-validation
slice above. Local remediation completion/integration then needs founder review.
Hosted preflight/application/postchecks require separate explicit approval and
fresh target identity/health/ACL review. Authenticated device validation remains
blocked until the hosted security boundary is repaired and independently proved;
phone build/install and release guards remain separately unauthorised.
