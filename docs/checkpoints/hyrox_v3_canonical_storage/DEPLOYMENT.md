# Deployment, preflight, postcheck and recovery — not authorised to execute hosted

2026-10-22. **LOCAL PREREQUISITES PROVED; NOT DEPLOYED; v3 remains unavailable.**

Ordered additive files (SHA-256 retained in [VERIFICATION](VERIFICATION.json)):

1. `20261022120000_hyrox_base_declared_evidence.sql`
2. `20261022121000_v3_unresolved_authority_guard.sql`

They do not enable v3 import. The second file intentionally refuses unresolved >=3
versions and canonical starts. No v3 artifact/consent/snapshot migration is prepared:
those require [the authority decision](AUTHORITY_DECISION.md).

## Required before any hosted operation

Separate founder deployment authority naming the exact target, operation and migration
bytes; fresh linked-project/remote identity, ledger, function-body/ACL/default-grant/RLS
inspection using the established hosted preflight process. No `.temp` was consulted or
modified here. The five earlier permission/ownership/identity/link/Backfill ACL files
(`20261007120000`, `07130000`, `08120000`, `08121000`, `09120000`) were locally proved
but remained unapplied in the last retained dated checkpoint. Their current hosted state
was **not inspected**; verify all prerequisites and approvals rather than assuming that
old record is current or including them implicitly in this deployment approval.

Run the read-only [PREFLIGHT.sql](PREFLIGHT.sql) against the explicitly verified target
only under fresh permission. It requires the five prerequisites, existing canonical
functions, required roles, and no PUBLIC/anon generic-start execution. Review exact
owners/body hashes/grants and current default privileges. The two new versions/tables
must be absent for an initial apply; partial/already-applied state requires inspection,
not manual ledger repair or blind rerun. Reconfirm no existing v3 pins need another
resume/retention policy; the guard refuses all unresolved v3 starts, including retries.
Unknown effective/inherited authority or schema drift stops deployment for review.

## Apply and postcheck (future separate authority)

Use normal repository migration tooling against the approved target, never a broad
unreviewed pending push. Each file is transactional. No real programme publication,
assignment, benchmark entry, consent or start is part of deployment. Validate exact
ordered ledger entries and [POSTCHECK.sql](POSTCHECK.sql), then compare retained old
canonical start body source and public grants with preflight. Private legacy bodies
must have no external execution. Existing generic-start service execution is preserved
where previously granted; the migration does not repair that existing public boundary.

Run reviewed SELECT-only compatibility/immutability/ACL checks. Confirm old v1/v2
artifact hashes, published source and existing snapshots unchanged; do not mutate real
athlete data to prove a postcheck. Keep existing application/server/compiler v3 refusal
and all release guards. Do not wire the new repository into a production screen merely
because the tables exist. Device/native verification and a separate client rollout
remain pending, as do broader Stage 2/Sprint C and four phone checks.

## Recovery design and local evidence

Prefer disabling the new RPC/client feature and retaining append-only data and guards.
Revoke the three new authenticated RPC EXECUTE grants under separately approved recovery
authority; this stops new commands while keeping owner reads/retained history available
as appropriate to the incident. Do not delete evidence, selections, migration ledger,
old snapshots or program versions. Do not remove the v3 guard as a shortcut to recovery.
An old client still uses unchanged canonical v1/v2 starts; no client update is required.

For an interrupted file, verify transaction/ledger state before retrying exact bytes.
For a later defective computation rule, add an explicitly versioned correction; never
rewrite accepted historical evidence or future started snapshots. Copied private old
start bodies remain available for inspected recovery, but restoring entry points requires
an explicit reviewed forward migration, source/ACL equality proof and all gates again.
No destructive down migration or production restore claim is made.

Locally, fresh/repeat complete replay, injected record/selection transaction rollback,
wrong-owner/revision/consent refusals, immutable row mutation refusal, composite FK
isolation and B2 snapshot rollback/concurrent duplicate starts are proved. Canonical v3
snapshot recovery/concurrency is **not** proved because that capability is not implemented.
