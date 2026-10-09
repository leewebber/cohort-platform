# Security remediation readiness — local backfill ACL fix

**Recorded:** 2026-10-09, Asia/Makassar.
**Status:** **LOCAL_ACL_FIX_PROVED_AWAITING_FOUNDER_REVIEW**.
The four-file hosted ACL blocker now has a locally proved additive fix. The final
five-file candidate still requires founder integration approval, fresh hosted
preflight and separate deployment approval. No hosted permissions or evidence
changed, and no integration, fetch/push, release or device operation occurred.

## Git and scope

Started clean on `codex/history-permission-completion-review` at
`1986ec12150032b3314a44fe7d1d9ba6f0f85f51`, equal to **cached** `origin/main`.
No remote refresh was authorised or performed. Local `refs/heads/main` remains
`eed04352e00f3d2605507ce8bf9711d2de8b4030`, an ancestor 104 commits behind;
this stale local ref was identified before editing and preserved. Consequently,
this task cannot claim that the local main branch is at the integrated tip.

Isolated branch: `codex/backfill-authenticated-acl`. Implementation/proof commit:
`6979e065f666421663e47f9c7bbcd4d45c2b5773`. Its documentation successor records
this handoff. Next integration range is
`1986ec12150032b3314a44fe7d1d9ba6f0f85f51..codex/backfill-authenticated-acl`:
**two ordered commits, zero merges**. The previously integrated nine-commit range
and its [review](../PERFORMANCE_TRACKING_PERMISSION_COMPLETION_INTEGRATION_REVIEW.md)
are preserved. Only one new production migration changes authority.

## Observed root cause and provenance limits

Exact callable signature:
`public.complete_backfilled_fixed_programme_occurrence(jsonb) RETURNS jsonb`.
Hosted owner is postgres; SQL SECURITY DEFINER and
`search_path=public, pg_temp` are unchanged. The function ACL contains EXECUTE for
postgres, authenticated and **service_role**, all with grantor postgres and no
grant option. Effective authenticated/service access is true; anon and PUBLIC
access are false. None of those three application roles has direct or effective
inherited memberships; service_role is not a superuser. Its BYPASSRLS flag does
not supply function EXECUTE authority.

The [original wrapper migration](../../../supabase/migrations/20260913120000_backfill_fixed_programme_session_results.sql)
revokes PUBLIC/anon and grants authenticated, but omits service_role revocation.
Current `pg_default_acl` entries for **postgres and supabase_admin**, public-schema
functions, grant EXECUTE to postgres, anon, authenticated and service_role.
There are no catalog global function-default entries in this snapshot.

**Observed:** the retained function-specific grant is direct from postgres, the
original ACL statements leave it intact, and current creation defaults supply it.
**Inference:** a historical creation-time default is the likely origin; catalog
inspection cannot rule out a later explicit GRANT or reconstruct the creation
transaction. Disposable replay under the observed postgres defaults independently
reproduces the exact three-principal ACL after the four integrated migrations.
No cross-athlete bypass is inferred from the extra service grant.

[Sanitized hosted investigation](./backfill-acl-investigation.json) records this
catalog evidence. The established Management API ran SELECT only with
`read_only=true`, role `supabase_read_only_user`, transaction_read_only **on**.
Target identity: Cohort Field Manual / `otnhhdxstdnwccehacku`, ACTIVE_HEALTHY;
ledger **117 / 20261005141000**, versions digest
`7f3ff7f48ac9ec7c3a728897854c847d`. No mutation RPC, role/JWT substitution or
restricted function execution occurred on hosted.

## Exact fix and effective contract

[20261009120000_backfill_authenticated_execute.sql](../../../supabase/migrations/20261009120000_backfill_authenticated_execute.sql)
revokes EXECUTE **only** from service_role on the exact jsonb signature. It neither
replaces the function nor grants anything. Authenticated access is retained.
An atomic assertion rejects effective anon/service access, PUBLIC/other explicit
principals, grant options or missing authenticated access; unexpected inherited
access stops the migration rather than changing memberships or widening grants.

| Principal | Hosted before apply | Disposable final effective EXECUTE |
|---|---|---|
| authenticated | yes | yes |
| service_role | yes | no |
| anon | no | no |
| PUBLIC | no | no; actual PUBLIC-only test role also denied |
| postgres owner | yes | retained |

Final direct ACL: `{postgres=X/postgres,authenticated=X/postgres}`.
All function bodies, ownership, identities, exact link guards, RLS, parent/child
triggers, correction authority, table/sequence grants, defaults and memberships
are unchanged by this fifth migration.

## Verification

[Recorded verification markers](./VERIFICATION.txt) retain the successful local
commands and final proof results without synthetic result payloads.

- [Disposable gate](../../../supabase/tests/run_history_permission_remediation_gate.sh):
  **PASS**. Fresh baseline/full migration replay through file four reproduces the
  service grant; file five fixes it. Repeated ordered five-file replay passes and
  preserves every existing public-table row digest, function definition, other
  function ACL, policy and server table grant.
- Actual anon/service/PUBLIC-only role calls are denied. Authenticated partial
  backfill and second-device retry succeed. Existing start/resume, canonical and
  standalone completion, correction, C2/C3 decoding, coach boundaries, foreign
  child/parent denial and API checks pass. Five ownership/link barriers, late
  child denial and concurrent UUID collision proof pass.
- [Ordering controls](../../../supabase/tests/backfill_acl_ordering.py): **PASS**.
  CREATE OR REPLACE retains the corrected ACL. Exact-signature DROP/CREATE under
  the reproduced defaults restores service access; replay of the actual ACL-fix
  statements removes it. PUBLIC access, inherited authenticated access for
  service_role, and removed authenticated access each fail closed with unchanged
  functions/ACLs, defaults, memberships and nine-relation evidence digest.
- **Six safety groups pass, zero failures**. Changed Python AST, Bash syntax,
  SQL execution, local Markdown links and diff checks pass. No Dart source changed;
  the prior committed review's 242 focused Flutter tests and analysis are reused.
  Full Flutter/full compatibility suites were not repeated for this ACL-only fix.
- All **19 hosted counts/full-rowset MD5 invariants** match the prior readiness
  snapshot exactly, including a final independent read; [unchanged baseline](./protected-evidence-baseline.json).
  No raw athlete rows or personal identifiers are retained. Disposable stacks,
  backups and scratch files are removed; repository `supabase/.temp` is unchanged.

The first proof attempt failed only because its new synthetic PUBLIC probe lacked
local SET ROLE authority. The test-only membership was corrected inside a rolled
back transaction; the frozen final gate passed. No production permission was
widened to make a test pass.

## Recurrence and remaining boundary

Current public-function defaults for both observed creation owners remain a
**concrete recurrence risk for new or dropped/recreated public functions**.
CREATE OR REPLACE and the ordered pending sequence do not restore this grant.
Per-function explicit revocation/allowlisting and effective-role assertions are
required whenever this wrapper is recreated. The fifth file provides that repair
for the approved sequence; it does not promise safety after arbitrary later DDL.

A separate founder-reviewed remedy could inventory legitimate EXECUTE contracts
for public functions created by postgres/supabase_admin, then remove their
unneeded public-schema default application-role grants and require explicit
per-function grants. PostgreSQL's built-in global PUBLIC default must also be
assessed: per-schema revocation cannot subtract a global grant. Any global/default
change has wider creation impact and needs its own compatibility review. No such
change is implemented or authorised here. This recurrence risk is not an
unresolved blocker in the exact five-file sequence.

[Deployment/postcheck plan](./POSTCHECK_PLAN.md) lists five exact files/hashes,
ledger target **122 / 20261009120000**, fourteen prepared SELECT postchecks and
all nineteen protected invariants. The earlier four-file dry-run is historical;
a fresh five-file dry-run has **not** been run or claimed in this task. Stop for
founder review, then separately approve integration and hosted deployment.
