# Performance Tracking C2 — coherent reader local handoff

> **Delivery pointer — 2026-10-06:** Both independent and combined C2
> infrastructure are deployed as recorded in the
> [combined deployment closeout](./PERFORMANCE_TRACKING_C2_PROGRAMME_ATTRIBUTION_HOSTED_DEPLOYMENT.md),
> integrated through `66e94e010cef40d1743694371bb59b0940b3eb72`. Readers remain
> unwired; the independent reader still refuses claims, and the combined reader
> requires retained artifacts. Legacy scope stays unproven. No hosted refresh.
> [C3 evaluation proposal](../architecture/Performance_Tracking_C3_Read_Only_Evaluation_Proposal_v1.md)
> is awaiting founder approval, with implementation unauthorised. Original
> closeout/blocked-authority wording below is historical, superseded only for
> the separately authorised combined authority and deployment.


**Recorded:** 2026-10-05

**Current status:** independent C2 is integrated through
`144ba110f8de938dc3fbd3e9cbb9a83fd21cf4ba`; its RPC migration is applied and
SELECT-verified on Cohort Field Manual, ledger 115. See
[deployment closeout](./PERFORMANCE_TRACKING_SPRINT_C2_HOSTED_DEPLOYMENT.md).
Programme attribution remains blocked; bridge/adapter remain unwired. Hosted
session SELECT exists with RLS disabled and was preserved; complete joined
witness/artifact delivery remains unimplemented. No further operation is implied.

**Status at original local closeout:** INDEPENDENT_HISTORY_READ_LOCAL_VERIFIED;
programme witness stopped for local access/artifact authority. The original
continuation evidence below remains historical; later explicit founder authority
superseded only its integration/deployment pauses.
[Subsequent independent-reader review](./PERFORMANCE_TRACKING_SPRINT_C2_REVIEW.md)
fixes claim fallback for invisible records and proves denied training_sessions
SELECT does not block independent reads. Its witness follow-up is proposal only;
original continuation evidence below is preserved.

**Branch:** `codex/performance-tracking-c2-history-adapter`

**Clean authorised start:** `5623a7975c583ef324ecc62d8ec7932bc60ea2fa`

**Cached origin/main integration base:** `72c1281f0966f2a6485873f6071b0e000ba1e000`
No fetch or hosted contact was performed in this continuation. All existing C1
and C2 commits remain unchanged ancestors. The final Git report supplies this
continuation's full SHA and the complete local integration range/count.

Binding: [approved architecture](../architecture/Programme_Performance_Metrics_Profile_Sprint_C_Proposal_v1.md),
[reviewed read proposal and findings](../architecture/Performance_Tracking_C2_Coherent_History_Read_Proposal_v1.md),
[preserved pure adapter handoff](./PERFORMANCE_TRACKING_SPRINT_C2_HANDOFF.md)
and [C1 review](./PERFORMANCE_TRACKING_SPRINT_C1_REVIEW.md).
The founder explicitly authorised local RPC, unwired bridge and disposable proof;
this supersedes the earlier database pause only within that bounded scope.

## Delivered independent read boundary

One additive [migration](../../supabase/migrations/20261005130000_performance_tracking_coherent_history_read.sql)
creates `read_performance_tracking_history_v1(uuid,jsonb default null)` as one
STABLE SECURITY INVOKER SQL statement, fixed `pg_catalog, pg_temp` search path
and schema-qualified existing relations. Athlete identity is auth.uid(), with an
explicit owned-record predicate even where coach RLS permits ordinary History.
Missing/inaccessible records share the same response. There are no write locks,
mutation calls, new ledger, table/column changes, backfill or existing grants/RLS
changes. Client EXECUTE is authenticated only; PUBLIC/anon/service_role are
revoked. Function-owner privileges remain normal PostgreSQL ownership.

The complete raw record/block/exercise/set rows and complete owner-readable audit
membership come from the same statement snapshot. Stable row-ID ordering is for
serialization, never chronology. The function returns explicit failure above
10,000 total child/audit rows or 4 MiB returned JSON; optional claims are capped
at 16 KiB and use closed identity/type rules. It never truncates collections.

The [strict reader](../../lib/application/performance_tracking/coherent_history_rpc_reader.dart)
validates envelope keys, counts, markers, UUID identities, ownership/parentage,
audit owner/session/record scope, actor stability and bounds. Typed failures
reach the existing adapter without being relabelled missing. The
[Supabase transport](../../lib/infrastructure/performance_tracking/supabase_history_tracking_rpc_client.dart)
makes exactly one RPC request, preserving the supplied claim and sending no
athlete identity. Both are explicitly constructed and have no production consumer.
Supported result shape/unit, evidence, chronology, audit consistency and source
staleness validation remains in the existing adapter. No measurement ledger,
calculation, scoring, storage, selection, UI, manual entry or ingestion exists.

## Stopped programme witness and artifact authority

Fresh disposable proof establishes `authenticated` lacks SELECT on
`public.training_sessions`; its RLS is disabled. No repository migration supplies
this SELECT. The test baseline deliberately excludes historical hosted GRANT ALL,
so this is a local authority gap, not a claim about today's hosted permissions.
The required actual session owner/protocol join is stopped, without definer
fallback, helper exposure, widened grants or RLS changes.

A supplied claim is never ignored. Missing retained History origin links return
`programme_scope_unproven`; contradictory assignment/session/protocol references
return `programme_scope_conflict`; otherwise the required unavailable join returns
`programme_authority_unavailable`. No verified programme witness is returned.
Full assignment/version/package/occurrence/outcome/session/protocol/block/running
joins and a valid programme witness are not implemented or proven by this gate.

Complete canonical package bytes are not retained in these tables; phase/session
keys from the original manifest are not persisted. No canonical artifact is
returned or admitted, and no package byte/hash validation is claimed. The bridge
rejects invented witness/artifact envelope fields. A future witness boundary must
provide a supported immutable hash-pinned artifact and independently validate it
through the existing compiler plus exact authored scope in the coherent frame.
It must not manufacture missing keys, use labels/ordinals or change packages.

The material remaining decision is a separately scoped session read-authority
and immutable artifact-source design. Do not grant blanket SELECT on an
RLS-disabled session table. Any column/row-isolation policy proposal needs its
own consumer/access review and founder authority. Hosted permission verification,
deployment, production wiring and broader tracking remain separate approvals.

## Verification

| Check | Result |
|---|---|
| `flutter --suppress-analytics test --no-pub test/performance_tracking/` | **113 passed**: preserved 87 plus 25 strict-bridge tests and one loopback HTTP transport test |
| Changed-file Dart analysis | **No issues found** across both application files changed, reader, infrastructure transport and both new tests |
| `./supabase/tests/run_c2_coherent_history_read_gate.sh` | **PASS**, fresh disposable replay of existing migrations plus the new migration |
| Migration preservation | Before/after fingerprint of all existing public relation ACL/RLS, policies and public function definitions unchanged |
| Ownership/scope | Two athlete fixtures isolated; coach can read ordinary History but cannot read another athlete through RPC; missing/non-visible identical; malformed/partial claims fail; retained contradictory vs absent links distinguished |
| Completeness/bounds | Complete 1,001-set tree beyond PostgREST max_rows; row/byte/claim bounds fail explicitly; raw skipped/missing facts retained |
| Corrections | Two real correction-function calls in one transaction preserve distinct IDs with tied timestamps and incomplete duration audit payloads |
| Concurrency | **Three two-session races passed**: uncommitted correction invisible; correction commits during barrier-held read, which retains complete previous frame; fresh read has matching new actual/audit; old multi-read mixture negative control differs |
| Safety gate | **6 groups passed, 0 failed** |
| Formatting/diff/links | Changed Dart formatted; shell syntax checked; Python gate compiled/executed; final diff and relative document links checked |

Analysis command: `dart --suppress-analytics analyze lib/application/performance_tracking lib/infrastructure/performance_tracking test/performance_tracking/coherent_history_rpc_reader_test.dart test/performance_tracking/supabase_history_tracking_rpc_client_test.dart`.
Safety command: `FLUTTER_SUPPRESS_ANALYTICS=true ./tool/testing/run_phase2_consolidation_safety_gate.sh`.
The loopback test uses only synthetic response/identity values, with no new
package dependency. No full Flutter suite was warranted: no production/runtime
consumer or cross-app permission change was made. The unchanged C1 canonical
package/B2 compatibility proof remains attributed to its committed handoff.

Migration SHA-256:
`1625ee58a2400946b0ac73ed2933e52ee3ef55fa7b40922cc0f70cd7459544cf`

Earlier fixture/monitor defects were corrected before the fresh final passing
gate. Test-only postgres monitoring refreshes pg_stat_activity snapshots; the
correction and all read RPCs execute as authenticated. No test adds application
SELECT/RLS grants. Disposable stacks are scoped and stopped after proof.

## Remaining limitations and stop

Completeness is over the existing owner-readable authority and canonical audit
write path; it does not prove detection of privileged out-of-band corruption or
future policy drift. The producer markers are obligations, not client-verifiable
certificates. Audits remain an unordered provenance set; incomplete payloads and
tied timestamps cannot prove historical inputs or a latest field revision.
Tracking and all result types remain unable to grant prescription eligibility.

No hosted state, real programme/profile/test, assignment, package hash, B2 policy,
frozen target or Cohort benchmark ingestion changed. `.env` and `supabase/.temp`
were untouched. No push, hosted apply, phone build or next slice was performed.
Stop for founder review before integration; resolve the stopped witness separately.
