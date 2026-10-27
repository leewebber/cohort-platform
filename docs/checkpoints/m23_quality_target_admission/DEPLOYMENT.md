# Proposed scoped quality-target deployment — not authorised or applied

No hosted contact or change is performed. A later approval must name the exact
hosted project/environment, approved file hashes/order and writer/client hold.
Current ledger, permissions and target readiness remain unverified.

## Exact prospective batch

Only if fresh preflight confirms these prerequisites are still missing, approve this
ordered batch (skip a prerequisite only after exact applied-hash verification):

| Order | Exact file | SHA-256 |
|---|---|---|
| 1 | [20261026110000_training_setup_private_alpha_acquisition.sql](../../../supabase/migrations/20261026110000_training_setup_private_alpha_acquisition.sql) | `59cb7a97e5c5bcd6e5bc230631a1c34942ce4cd7610aa253b1556510df7248f5` |
| 2 | [20261027120000_confirmed_running_zone_targets.sql](../../../supabase/migrations/20261027120000_confirmed_running_zone_targets.sql) | `26038e82bae21130982ccaed65be14ee49ad4581256f99476ccb5ba071b0de6a` |
| 3 | [20261027130000_alpha_quality_running_targets.sql](../../../supabase/migrations/20261027130000_alpha_quality_running_targets.sql) | `5c49656c6fa85f6ef0c4524491d61dc53ff42a0bb7e61bbfe33a24ab0dc3b520` |

**All are held/unapplied by this task.** Preserve the earlier
[M1.2 proposal](../m11_alpha_sources/DEPLOYMENT_PROPOSAL.md) and
[Zone 2 proposal](../m23_personalised_target_admission/DEPLOYMENT.md).
Do not run an all-pending schema push. Explicitly exclude the deferred
`20261026120000_durable_publication_approval_events.sql` and any unrelated migration;
no publisher role or HYROX producer is required/created by this target slice.

## Scope and consequences

M1.2 adds confirmed training setup and normal private-free acquisition authority.
Zone 2 adds current owner-confirmed inputs, the immutable per-occurrence target table
and start/result guards. Quality adds one empty owner current-input table, authenticated
confirm/review/source-selected-start APIs, closed calculation/date/start helpers and
the same generic-start bypass guard extended to `alpha_quality_pace_v1`. Quality uses
the existing freeze table/record trigger, original canonical start and function OIDs.

New marked-source starts require confirmed eligible input, explicit source review and
acceptance; old clients cannot supply the new quality source/review. Started/completed
snapshots remain immutable despite updates/withdrawal. Unmarked v1/v2/B2 paths retain
existing behaviour. Confirmed inputs create athlete data only when a future authorised
athlete uses these APIs; the schema batch itself has no seeds, grants of recipient
eligibility, account creation, publication, assignment or result backfill.

1. Fresh read-only preflight: exact project identity/ledger/file bytes; prerequisite
   schemas/functions/owners/OIDs/security/search paths/ACLs/RLS/default privileges;
   expected generic fixed-start definition used by the fail-closed migration patch;
   immutable snapshot/result triggers; `extensions.digest`; supported timezones;
   protected data counts/digests and unrelated pending migrations. Stop on drift.
2. Hold writers and new-source activation; confirm compatible-client release plan.
   Apply only the approved exact batch via normal scoped operations. Any mismatch
   in pending set/target/order/hash stops application; never bypass grants or guards.
3. Read-only postchecks: exact ledger additions; new tables empty; correct owner-RLS,
   no direct writes/helper EXECUTE/service fallback; authenticated public API grants;
   unchanged old function OIDs/ACLs/delegation; immutable snapshot/result guards;
   protected rows/digests/old permission facts unchanged; no unrelated schema applied.
4. Separately approve compatible-client distribution, genuine source/content review
   and publication, exact private recipients/acquisition and real-device input/start/
   restart/complete/correct/History acceptance. No real athlete writes in postchecks.

Do not undo by deleting accepted snapshots or athlete data. Once real starts exist,
any rollback/forward fix needs a plan that preserves original prescriptions/actuals.
Local proof in [HANDOFF](HANDOFF.md) / [VERIFICATION](VERIFICATION.json) grants no
hosted apply, real publication, accounts/assignments or distribution authority.
