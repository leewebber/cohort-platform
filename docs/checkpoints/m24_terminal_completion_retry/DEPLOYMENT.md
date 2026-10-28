# M2.4 terminal completion retry — proposed deployment only

2026-10-28 (Asia/Makassar). **LOCAL ONLY / UNDEPLOYED**. No hosted contact,
ledger query, schema apply, account, programme, assignment or athlete-data operation
was performed or authorised by this task.

| Order | Exact migration | SHA-256 |
|---|---|---|
| 1 | [20261028120000_terminal_completion_retry.sql](../../../supabase/migrations/20261028120000_terminal_completion_retry.sql) | `00c5f094d6c49716109fa67066d6d570e4af27ee24f0bd9b5237433e6d3a0ffa` |

This is one additive migration on the existing canonical completion/security
baseline, including `20260801160000_complete_programme_session_and_advance.sql`,
`20260905180000_swap_future_fixed_programme_session_and_begin.sql`,
`20261007130000_completion_ownership_and_parent_guard.sql`,
`20261008120000_completion_result_identity.sql` and
`20261008121000_completion_link_locking.sql`, in their existing order. The deployed
baseline and retained private function definitions must be checked afresh before
any later separately authorised apply. This is not an all-pending migration batch.

**Held M1.2, Zone 2, quality-target and deferred producer migrations are not
prerequisites.** A separate disposable baseline omits all four and passes B3
mapping/targets/actuals/correction compatibility and repeat-application evidence,
function OID/owner/ACL/definition preservation. Their repository bytes remain
unchanged; none was deployed. Retain their separate proposals and approvals.

The migration adds a nullable SHA-256 receipt to existing slot outcomes, a private
receipt guard/hash/replay helper, and replaces only the two guarded public
programme-completion wrappers. Existing request/parent/result guards, private
transaction bodies, correction, backfill, start, scheduling, RLS and grants remain.
No rows are seeded, backfilled, corrected, reassigned or deleted. Existing completed
outcomes keep null receipts and use retained exact identity/logical-key/actuals
fingerprint evidence. Stronger server-computed request digests apply prospectively;
no historical payload digest is fabricated. Receipt mutation is denied after commit.

Before a later apply: obtain explicit environment/file approval; verify target,
ledger and exact bytes, baseline function definitions/security/search paths/ACLs,
result/parent/child guards and outcome client privileges; record protected evidence
and public function OIDs. Apply only this file after its verified baseline. Then
independently check exact definitions/ACLs/OIDs, empty new column for historical
outcomes, unchanged evidence, and authorised acceptance proof. No blanket schema
push or client/service-role bypass. Client distribution and authenticated installed
device acceptance remain separate release operations.
