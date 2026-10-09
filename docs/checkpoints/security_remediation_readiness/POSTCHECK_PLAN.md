# Five-file security remediation deployment and postcheck plan

**Prepared only. No authority to integrate, apply or change hosted permissions.**
The [local readiness report](./READINESS.md) resolves the former public backfill
ACL mismatch locally. Preserve the four integrated migration files byte for byte.

## Final timestamp order and SHA-256

| Order | Migration filename | SHA-256 |
|---|---|---|
| 1 | [20261007120000_history_read_permission_remediation.sql](../../../supabase/migrations/20261007120000_history_read_permission_remediation.sql) | `7c5ce19e72ddd438acfe9db23a5b3c4abed65bdeb6db8faa82e8e7df70910ff7` |
| 2 | [20261007130000_completion_ownership_and_parent_guard.sql](../../../supabase/migrations/20261007130000_completion_ownership_and_parent_guard.sql) | `d0a6a4b16a60376c3d7d97420b9e5e423efaf12d6d636b16064bfa7143fcbbe5` |
| 3 | [20261008120000_completion_result_identity.sql](../../../supabase/migrations/20261008120000_completion_result_identity.sql) | `604309505ca646801951d92fb6e305ae070bf1a6c1854338d633fc015f809320` |
| 4 | [20261008121000_completion_link_locking.sql](../../../supabase/migrations/20261008121000_completion_link_locking.sql) | `33712db05d2439b7c42729b8e5f57f66a6992ef3cf1ce26a807f5bb15cc4e8cd` |
| 5 | [20261009120000_backfill_authenticated_execute.sql](../../../supabase/migrations/20261009120000_backfill_authenticated_execute.sql) | `282e8b24ade00ac19370519e5b03b302d763209afe7d847f777e098ae934e976` |

The first four hashes independently match their committed integration review.
File five removes only the retained exact-signature service grant and asserts the
reviewed authenticated-only contract. It must follow the completion protections.

## Approval sequence and apply boundary

1. **Founder integration approval:** review the two local linear commits from
   `1986ec12150032b3314a44fe7d1d9ba6f0f85f51` through
   `codex/backfill-authenticated-acl`, zero merges. After approval, fetch origin
   and stop unless origin/main is the expected base (or already contains the
   exact approved range). Publish only a strict fast-forward of refs/heads/main;
   do not publish the feature branch/tags. Verify exact HEAD/origin equality,
   divergence 0/0 and clean state. The stale local main ref is not remote truth.
2. **Fresh read-only deployment preflight:** use a disposable linked workdir,
   copying committed config/migrations without repository `.temp`. Reconfirm
   Cohort Field Manual `otnhhdxstdnwccehacku`, ACTIVE_HEALTHY, ledger
   **117 / 20261005141000**, digest `7f3ff7f48ac9ec7c3a728897854c847d`.
   Recompute all five hashes and require dry-run to list **exactly five files in
   the order above**. Stop on drift; the former four-file dry-run is insufficient.
   Refresh affected catalog/default ACL/role/trigger/link prerequisites. File
   five deliberately aborts if PUBLIC/inheritance/other authority has drifted.
3. Compare all nineteen [protected baseline invariants](./protected-evidence-baseline.json)
   via [aggregate SELECT](./postchecks/protected-evidence.sql). Investigate every
   difference; do not replace expected digests to conceal it. Require a quiescent
   execution/save/correction window, including the five previously observed
   in-progress records. Do not alter their state to create that window.
4. **Separate founder deployment approval:** approve the integrated tip and this
   exact five-file/hash set after successful preflight. Only then apply the
   ordinary CLI pending migration batch from a newly disposable linked workdir.
   No `--include-all`, seed/role imports, ad hoc GRANTs or mutation RPCs. Each file
   commits separately; do not expose intermediate states. File one removes
   client parent writes before file two repairs the old invoker path; files
   three/four complete identity/locking protection, and file five completes the
   public backfill ACL contract. A partial batch remains blocked.

## Independent SELECT postchecks

All fourteen committed `postcheck-*.sql` files below are **prepared, not executed
on hosted**. Every returned contract boolean must be true (null is failure):

- [Ledger](./postchecks/postcheck-ledger.sql): **122 / 20261009120000**, all five versions present.
- [Exact backfill signature/ACL](./postchecks/postcheck-backfill-exact-acl.sql):
  one jsonb overload, owner postgres, unchanged SECURITY DEFINER/search_path/body;
  authenticated EXECUTE true, service/anon effective EXECUTE false, no PUBLIC,
  other explicit principal or grant option.
- [Public route ACLs](./postchecks/postcheck-public-function-acls.sql) and
  [private ACLs](./postchecks/postcheck-private-function-acls.sql): preserve all
  reviewed completion/correction and helper contracts, including zero private
  client/server execution. Public canonical/fixed/standalone retain demonstrated
  authenticated/service entry authority; backfill/correction remain authenticated only.
- [Function sources](./postchecks/postcheck-function-sources.sql),
  [security/search paths](./postchecks/postcheck-function-security.sql) and
  [unaffected functions](./postchecks/postcheck-unaffected-functions.sql): all
  existing owner/link/identity protections and unrelated bodies/ACLs unchanged.
- [Table ACLs](./postchecks/postcheck-table-acls.sql),
  [PUBLIC/column ACLs](./postchecks/postcheck-table-public-column-acls.sql),
  [sequence ACLs](./postchecks/postcheck-sequence-acls.sql),
  [session RLS](./postchecks/postcheck-session-rls.sql),
  [server grants](./postchecks/postcheck-preserved-server-table-grants.sql),
  [preserved policies](./postchecks/postcheck-preserved-policies.sql) and
  [new triggers](./postchecks/postcheck-new-triggers.sql): exact existing review,
  no table/sequence policy or server-authority broadening by the fifth file.

Run the aggregate evidence SELECT again: **all nineteen counts/digests must equal
the approved pre-apply snapshot**. Compare non-session policies, all existing
constraints/indexes, B3/interval trigger definitions/events/order/enabled state,
server table grants, role memberships and default function ACLs with preflight.
Only the reviewed parent/child guard additions and original four-file changes
are expected; the fifth migration changes only its one function ACL.

Run [retained-link consistency](./postchecks/retained-link-consistency.sql) and
[link health](./postchecks/link-health.sql): require zero owner/protocol/parent
contradictions and preserve legitimate parent-free History. Reuse local role,
API and concurrency proof; do not impersonate athletes or call completion RPCs
for hosted postchecks. Function defaults remain as investigated unless a future,
separately reviewed default-privilege task changes them.

Reconfirm ACTIVE_HEALTHY, the exact ledger and an **empty final dry-run**. Remove
disposable resources, verify repository `.temp` file set/hashes unchanged, and
report every check rather than treating a ledger entry as security proof.
Authenticated device validation, builds/install and release activation require
separate authority after hosted security verification; no next slice follows.
